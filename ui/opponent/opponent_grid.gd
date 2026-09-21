class_name OpponentGrid
extends Control

## 対戦相手の一覧（要件定義 §89 / §91）。
##
## 最大 98 面を並べ、1 面につき Alive / Dead・Target・Danger・Attack Power・
## Attacker（自分を攻撃中）を出す。
##
## **98 面を個別 Node で持たない。**1 つの [CanvasItem] にまとめて描く
## （#49 の制約）。Node を 98 個持つと Scene Tree の更新だけで負荷になる。
##
## 盤面の中身は簡略化する（要件定義 §89）。積み上がりの高さを塗るだけで、
## マス単位では描かない。Main Board の視認性を優先するため（§91）。
##
## 状態の読み直しは [constant REFRESH_INTERVAL_SEC] ごと。毎フレーム 98 人ぶんを
## 走査しない（要件定義 §108）。

## 対戦相手が選ばれた（Manual Target の候補。要件定義 §52）。
##
## 実際に Target にするかは Battle Layer（[TargetManager]）が決める。
signal opponent_selected(player_id: int)

## 1 面の大きさ（ピクセル）。
const TILE_SIZE := Vector2(28.0, 44.0)

## 面と面の間隔（ピクセル）。
const TILE_MARGIN: float = 2.0

## 横に並べる数。98 面を 14 × 7 で置く。
const COLUMNS: int = 14

## 状態を読み直す周期（秒）。
const REFRESH_INTERVAL_SEC: float = 0.1


## 1 面ぶんの表示状態。
class Tile:
	extends RefCounted

	## 対戦相手の Player ID。
	var player_id: int = -1

	## 生きているか。
	var alive: bool = true

	## 積み上がりの割合（0.0〜1.0）。
	var fill_ratio: float = 0.0

	## 盤面の危険度。
	var danger_level: DangerLevel.Level = DangerLevel.Level.SAFE

	## 自分がこの相手を狙っているか。
	var is_target: bool = false

	## この相手が自分を狙っているか（Attacker）。
	var is_attacker: bool = false

	## この相手の Attack 倍率（Attack Power）。
	var attack_multiplier: float = 1.0


var _palette: BoardPalette = BoardPalette.create_default()
var _manager: BattleManager = null
var _cpus: CpuManager = null
var _viewer_id: int = -1
var _tiles: Array[Tile] = []
var _elapsed_sec: float = 0.0
var _refresh_count: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_elapsed_sec += delta
	if _elapsed_sec < REFRESH_INTERVAL_SEC:
		return
	_elapsed_sec = 0.0
	refresh()


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var player_id: int = get_player_id_at(event.position)
	if player_id >= 0:
		opponent_selected.emit(player_id)


## 表示する Battle を結び付ける。
##
## [param viewer_id] は「自分」の Player ID。Target / Attacker の向きの基準になる。
func bind(manager: BattleManager, viewer_id: int, cpus: CpuManager = null) -> void:
	_manager = manager
	_viewer_id = viewer_id
	_cpus = cpus
	_rebuild_tiles()
	refresh()


## 結び付けを解く。
func unbind() -> void:
	_manager = null
	_cpus = null
	_tiles.clear()
	queue_redraw()


## 配色を差し替える。
func set_palette(palette: BoardPalette) -> void:
	if palette == null:
		return
	_palette = palette
	queue_redraw()


## 並んでいる面を返す。
func get_tiles() -> Array[Tile]:
	return _tiles


## Player ID から面を返す。無ければ [code]null[/code]。
func get_tile(player_id: int) -> Tile:
	for tile in _tiles:
		if tile.player_id == player_id:
			return tile
	return null


## これまでに状態を読み直した回数を返す。周期の検証に使う。
func get_refresh_count() -> int:
	return _refresh_count


## 座標にある対戦相手の Player ID を返す。無ければ -1。
func get_player_id_at(position: Vector2) -> int:
	# 負の座標は int() が 0 側へ丸まるため、先に弾く。
	if position.x < 0.0 or position.y < 0.0:
		return -1

	var column: int = int(position.x / (TILE_SIZE.x + TILE_MARGIN))
	var row: int = int(position.y / (TILE_SIZE.y + TILE_MARGIN))
	if column >= COLUMNS:
		return -1

	var index: int = row * COLUMNS + column
	if index < 0 or index >= _tiles.size():
		return -1
	return _tiles[index].player_id


## 表示している状態を読み直す。
func refresh() -> void:
	if _manager == null:
		return

	for tile in _tiles:
		var player: BattlePlayerState = _manager.get_player(tile.player_id)
		if player == null:
			continue

		tile.alive = player.alive
		tile.danger_level = player.danger_level
		tile.attack_multiplier = player.attack_multiplier
		tile.fill_ratio = _read_fill_ratio(player)

		# Target と Attacker は Battle Layer が決めた向きをそのまま出す。
		var viewer: BattlePlayerState = _manager.get_player(_viewer_id)
		tile.is_target = viewer != null and viewer.current_target == tile.player_id
		tile.is_attacker = player.current_target == _viewer_id

	_refresh_count += 1
	queue_redraw()


func _draw() -> void:
	for index in range(_tiles.size()):
		_draw_tile(index, _tiles[index])


func _draw_tile(index: int, tile: Tile) -> void:
	var origin := Vector2(
		float(index % COLUMNS) * (TILE_SIZE.x + TILE_MARGIN),
		float(index / COLUMNS) * (TILE_SIZE.y + TILE_MARGIN)
	)
	var rect := Rect2(origin, TILE_SIZE)

	# 盤面は簡略化して「積み上がりの高さ」だけを塗る（要件定義 §89）。
	draw_rect(rect, _palette.empty_color)
	if tile.alive:
		var filled: float = TILE_SIZE.y * clampf(tile.fill_ratio, 0.0, 1.0)
		draw_rect(
			Rect2(origin + Vector2(0.0, TILE_SIZE.y - filled), Vector2(TILE_SIZE.x, filled)),
			_stack_color(tile)
		)
	else:
		# Dead は塗りつぶして「もういない」ことを出す。
		draw_rect(rect, _palette.grid_color)
		draw_line(origin, origin + TILE_SIZE, _palette.garbage_color, 1.0)
		draw_line(
			origin + Vector2(0.0, TILE_SIZE.y),
			origin + Vector2(TILE_SIZE.x, 0.0),
			_palette.garbage_color,
			1.0
		)

	# Attack Power は上端の目盛りで出す。
	if tile.alive and tile.attack_multiplier > 1.0:
		var power: float = clampf((tile.attack_multiplier - 1.0) / 1.0, 0.0, 1.0)
		draw_rect(Rect2(origin, Vector2(TILE_SIZE.x * power, 2.0)), _palette.incoming_color)

	_draw_marks(origin, rect, tile)


func _draw_marks(origin: Vector2, rect: Rect2, tile: Tile) -> void:
	# Target は太い枠、Attacker は下端の帯で出す。見分けが付くように形を変える。
	if tile.is_target:
		draw_rect(rect, _palette.incoming_color, false, 2.0)
	elif tile.danger_level != DangerLevel.Level.SAFE:
		draw_rect(rect, _palette.get_danger_color(tile.danger_level), false, 1.0)
	else:
		draw_rect(rect, _palette.grid_color, false, 1.0)

	if tile.is_attacker:
		draw_rect(
			Rect2(origin + Vector2(0.0, TILE_SIZE.y - 3.0), Vector2(TILE_SIZE.x, 3.0)),
			_palette.piece_colors[Piece.Type.Z]
		)


func _stack_color(tile: Tile) -> Color:
	if tile.danger_level == DangerLevel.Level.SAFE:
		return _palette.garbage_color
	return _palette.get_danger_color(tile.danger_level)


func _rebuild_tiles() -> void:
	_tiles.clear()
	if _manager == null:
		return

	for player in _manager.get_players():
		if player.player_id == _viewer_id:
			continue
		var tile := Tile.new()
		tile.player_id = player.player_id
		_tiles.append(tile)


# 積み上がりの割合を読む。盤面がある相手は盤面から、Lightweight は指標から。
func _read_fill_ratio(player: BattlePlayerState) -> float:
	if _cpus != null and not player.is_human():
		var indicators: CpuIndicators = _cpus.get_indicators(player.player_id)
		return clampf(float(indicators.stack_height) / float(Board.VISIBLE_HEIGHT), 0.0, 1.0)

	var board: Board = player.get_board()
	if board == null:
		return 0.0
	return DangerLevel.get_ratio(board)
