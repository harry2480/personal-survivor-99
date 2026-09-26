class_name PlayerBoardView
extends Control

## 自分の盤面の表示（要件定義 §88 / §91 / §92）。
##
## 画面で最も視認性が高い場所。表示するのは Fixed Blocks / Active Piece /
## Ghost / Incoming Garbage / Danger State の 5 つ（§88）。
##
## **Game Core の状態は読むだけ**で、書き換えない（要件定義 §19）。
## **Danger State も自分で判定しない**。Battle Layer が持つ
## [member BattlePlayerState.danger_level] をそのまま映す（要件定義 §92）。
##
## 更新は 2 段階に分けている。固定ブロックは Signal（Lock / Line Clear /
## Garbage 適用）で変わったときだけ読み直し、動いている Piece と Ghost だけ
## 毎フレーム読む。毎フレーム盤面全体を走査しない（要件定義 §108）。

## 1 マスの大きさ（ピクセル）。
const CELL_SIZE: int = 24

## Danger の縁の太さ（ピクセル）。
const DANGER_BORDER: int = 4

## Incoming Garbage の目盛りの幅（ピクセル）。
const INCOMING_BAR_WIDTH: int = 10

var _palette: BoardPalette = BoardPalette.create_default()
var _session: PuzzleSession = null
var _player: BattlePlayerState = null
var _cells: PackedInt32Array = PackedInt32Array()
var _active_cells: Array[Vector2i] = []
var _ghost_cells: Array[Vector2i] = []
var _active_type: int = -1
var _danger_level: DangerLevel.Level = DangerLevel.Level.SAFE
var _incoming_lines: int = 0
var _connections: Array = []
var _cells_dirty: bool = true


func _ready() -> void:
	custom_minimum_size = Vector2(
		float(Board.WIDTH * CELL_SIZE + INCOMING_BAR_WIDTH), float(Board.VISIBLE_HEIGHT * CELL_SIZE)
	)
	_cells.resize(Board.WIDTH * Board.VISIBLE_HEIGHT)
	_cells.fill(Board.EMPTY)


func _process(_delta: float) -> void:
	refresh()


func _exit_tree() -> void:
	unbind()


## 表示する Game Core と Battle の状態を結び付ける。
##
## [param player] は Danger State と Incoming の出どころ（Battle Layer）。
func bind(session: PuzzleSession, player: BattlePlayerState = null) -> void:
	unbind()
	_session = session
	_player = player
	if _session == null:
		return

	# 盤面が変わる場面だけ購読する（毎フレームの全走査を避ける。§108）。
	var on_locked: Callable = func(_type: int) -> void: _cells_dirty = true
	var on_cleared: Callable = func(_result: LineClearResult) -> void: _cells_dirty = true
	var on_garbage: Callable = func(_lines: int) -> void: _cells_dirty = true
	# 同じ Session の再開（start()）は盤面を消すが、Lock も Line Clear も起こさない。
	var on_started: Callable = func() -> void: _cells_dirty = true
	_session.piece_locked.connect(on_locked)
	_session.lines_cleared.connect(on_cleared)
	_session.garbage_applied.connect(on_garbage)
	_session.started.connect(on_started)
	_connections = [on_locked, on_cleared, on_garbage, on_started]

	_cells_dirty = true
	refresh()


## 結び付けを解く。参照の循環を残さない。
func unbind() -> void:
	if _session != null and _connections.size() == 4:
		_session.piece_locked.disconnect(_connections[0])
		_session.lines_cleared.disconnect(_connections[1])
		_session.garbage_applied.disconnect(_connections[2])
		_session.started.disconnect(_connections[3])
	_connections.clear()
	_session = null
	_player = null


## 配色を差し替える。
func set_palette(palette: BoardPalette) -> void:
	if palette == null:
		return
	_palette = palette
	queue_redraw()


## 使っている配色を返す。
func get_palette() -> BoardPalette:
	return _palette


## 表示用の状態を読み直す。
##
## 固定ブロックは変化があったときだけ読み直す。動いている Piece と Ghost、
## Incoming、Danger は毎回読む（どれも軽い）。
func refresh() -> void:
	if _session == null:
		return

	if _cells_dirty:
		_read_cells()
		_cells_dirty = false

	_read_active_piece()
	_incoming_lines = _read_incoming()
	_danger_level = _read_danger()
	queue_redraw()


## 表示している固定ブロックの値を返す（見えている領域の座標）。
func get_cell(x: int, y: int) -> int:
	if x < 0 or x >= Board.WIDTH or y < 0 or y >= Board.VISIBLE_HEIGHT:
		return Board.EMPTY
	return _cells[y * Board.WIDTH + x]


## 表示している Active Piece のマスを返す（見えている領域の座標）。
func get_active_cells() -> Array[Vector2i]:
	return _active_cells


## 表示している Ghost のマスを返す（見えている領域の座標）。
func get_ghost_cells() -> Array[Vector2i]:
	return _ghost_cells


## 表示している Danger State を返す（要件定義 §92）。
func get_danger_level() -> DangerLevel.Level:
	return _danger_level


## 表示している Incoming Garbage の行数を返す。
func get_incoming_lines() -> int:
	return _incoming_lines


func _draw() -> void:
	_draw_cells()
	_draw_piece(_ghost_cells, _palette.get_ghost_color(_active_type))
	_draw_piece(_active_cells, _palette.get_cell_color(_active_type))
	_draw_incoming()
	_draw_danger()


func _draw_cells() -> void:
	for y in range(Board.VISIBLE_HEIGHT):
		for x in range(Board.WIDTH):
			var rect := Rect2(
				Vector2(float(x * CELL_SIZE), float(y * CELL_SIZE)),
				Vector2(float(CELL_SIZE), float(CELL_SIZE))
			)
			draw_rect(rect, _palette.get_cell_color(get_cell(x, y)))
			draw_rect(rect, _palette.grid_color, false, 1.0)


func _draw_piece(cells: Array[Vector2i], color: Color) -> void:
	for cell in cells:
		draw_rect(
			Rect2(
				Vector2(float(cell.x * CELL_SIZE), float(cell.y * CELL_SIZE)),
				Vector2(float(CELL_SIZE), float(CELL_SIZE))
			),
			color
		)


func _draw_incoming() -> void:
	# 盤面の右脇に、受信待ちの行数を積み上げて出す（要件定義 §91 の 2 番目）。
	var board_width: float = float(Board.WIDTH * CELL_SIZE)
	var board_height: float = float(Board.VISIBLE_HEIGHT * CELL_SIZE)
	draw_rect(
		Rect2(Vector2(board_width, 0.0), Vector2(float(INCOMING_BAR_WIDTH), board_height)),
		_palette.incoming_background_color
	)

	if _incoming_lines <= 0:
		return

	var filled: float = float(mini(_incoming_lines, Board.VISIBLE_HEIGHT) * CELL_SIZE)
	draw_rect(
		Rect2(
			Vector2(board_width, board_height - filled), Vector2(float(INCOMING_BAR_WIDTH), filled)
		),
		_palette.incoming_color
	)


func _draw_danger() -> void:
	if _danger_level == DangerLevel.Level.SAFE:
		return
	draw_rect(
		Rect2(
			Vector2.ZERO,
			Vector2(
				float(Board.WIDTH * CELL_SIZE + INCOMING_BAR_WIDTH),
				float(Board.VISIBLE_HEIGHT * CELL_SIZE)
			)
		),
		_palette.get_danger_color(_danger_level),
		false,
		float(DANGER_BORDER)
	)


func _read_cells() -> void:
	var board: Board = _session.get_board()
	for y in range(Board.VISIBLE_HEIGHT):
		var board_y: int = Board.VISIBLE_TOP_Y + y
		for x in range(Board.WIDTH):
			_cells[y * Board.WIDTH + x] = board.get_cell(x, board_y)


func _read_active_piece() -> void:
	_active_cells.clear()
	_ghost_cells.clear()

	var piece: ActivePiece = _session.get_active_piece()
	if not piece.is_active():
		_active_type = -1
		return

	_active_type = piece.type
	var offsets: Array[Vector2i] = Piece.get_cells(piece.type, piece.rotation)
	var ghost_position: Vector2i = _session.get_ghost_position()

	for offset in offsets:
		_append_visible(_active_cells, piece.position + offset)
		_append_visible(_ghost_cells, ghost_position + offset)


func _append_visible(cells: Array[Vector2i], cell: Vector2i) -> void:
	var y: int = cell.y - Board.VISIBLE_TOP_Y
	if y < 0 or y >= Board.VISIBLE_HEIGHT or cell.x < 0 or cell.x >= Board.WIDTH:
		return
	cells.append(Vector2i(cell.x, y))


# Incoming は Battle Layer の値を優先する。単体プレイでは Game Core から読む。
func _read_incoming() -> int:
	if _player != null:
		return _player.incoming_garbage
	return _session.get_garbage_queue().get_pending_lines()


# Danger は Battle Layer の判定をそのまま映す（要件定義 §92）。
#
# Battle がいない単体プレイのときだけ、Game Core の盤面から求める。
func _read_danger() -> DangerLevel.Level:
	if _player != null:
		return _player.danger_level
	return DangerLevel.get_level(_session.get_board())
