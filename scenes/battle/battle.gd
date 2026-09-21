extends Node2D

## Battle 画面（要件定義 §87 / §107）。
##
## 組み立てだけを行う。ここが Battle Layer と View の橋渡しをする唯一の窓口で、
## 各 View は渡された状態を読んで自分の描画を更新する（フロントエンド
## アーキテクチャの Battle Scene 構成）。
##
## [codeblock]
## Battle
## ├── OpponentGrid       … 対戦相手の一覧（#49）
## ├── PlayerBoardPanel   … 自分の盤面 + Hold / NEXT（#48）
## ├── BattleHud          … 状況表示（#50）
## └── InputManager       … Input Action → Game Command（§11）
## [/codeblock]
##
## Battle の進行そのものは [CpuBattleRunner] が持つ。Presentation では
## Game Core の内部状態を直接書き換えない（要件定義 §19）。

## 既定の Player 数（要件定義 §44）。
const PLAYER_COUNT: int = 99

## 自分の Player ID。
const VIEWER_ID: int = 0

## 配色の置き場所。
const PALETTE_PATH: String = "res://assets/themes/board_palette.tres"

## 画面の余白（ピクセル）。
const MARGIN := Vector2(24.0, 24.0)

var _runner: CpuBattleRunner
var _input: InputManager
var _board_panel: PlayerBoardPanel
var _opponent_grid: OpponentGrid
var _hud: BattleHud
var _paused: bool = false


func _ready() -> void:
	_runner = _create_runner()
	_build_views()
	_build_input()


func _process(delta: float) -> void:
	if _paused or _runner == null:
		return

	_runner.step(delta)
	if _runner.get_manager().is_finished():
		set_process(false)


func _exit_tree() -> void:
	if _runner != null:
		_runner.dispose()
		_runner = null


## Battle の進行を返す（Debug Overlay と Result 画面のため）。
func get_runner() -> CpuBattleRunner:
	return _runner


## 自分の Player を返す。
func get_viewer() -> BattlePlayerState:
	return _runner.get_manager().get_player(VIEWER_ID) if _runner != null else null


## 一時停止を切り替える（要件定義 §96。Pause メニューは Phase 9 / #51）。
func set_paused(paused: bool) -> void:
	_paused = paused
	if _input != null:
		_input.release_all()


## 一時停止中かを返す。
func is_paused() -> bool:
	return _paused


func _create_runner() -> CpuBattleRunner:
	var distribution: Resource = load("res://config/cpu_distribution.tres")
	var mapping: Resource = load("res://config/cpu_strength_mapping.tres")
	var runner := CpuBattleRunner.new(
		PLAYER_COUNT - 1,
		distribution if distribution is CpuDistribution else null,
		mapping if mapping is CpuStrengthMapping else null,
		randi(),
		1
	)

	# CPU の更新は分散する（要件定義 §104 / #47）。
	var policy: Resource = load("res://config/cpu_scheduling.tres")
	runner.enable_scheduling(policy if policy is CpuSchedulePolicy else null)
	return runner


func _build_views() -> void:
	var palette: Resource = load(PALETTE_PATH)
	var manager: BattleManager = _runner.get_manager()
	var viewer: BattlePlayerState = manager.get_player(VIEWER_ID)

	_opponent_grid = OpponentGrid.new()
	_opponent_grid.name = "OpponentGrid"
	_opponent_grid.position = MARGIN
	add_child(_opponent_grid)
	_opponent_grid.bind(manager, VIEWER_ID, _runner.get_cpu_manager())
	# 選択は Battle Layer へ渡すだけ（要件定義 §52 / §53）。
	_opponent_grid.opponent_selected.connect(_on_opponent_selected)

	_board_panel = PlayerBoardPanel.new()
	_board_panel.name = "PlayerBoardPanel"
	_board_panel.position = MARGIN + Vector2(0.0, 360.0)
	add_child(_board_panel)
	_board_panel.bind(viewer.session, viewer)

	_hud = BattleHud.new()
	_hud.name = "BattleHud"
	_hud.position = MARGIN + Vector2(560.0, 360.0)
	add_child(_hud)
	_hud.bind(manager, VIEWER_ID, _runner.get_ko_system(), _runner.get_target_manager())

	if palette is BoardPalette:
		_board_panel.set_palette(palette)
		_opponent_grid.set_palette(palette)


func _build_input() -> void:
	_input = InputManager.new()
	_input.name = "InputManager"
	add_child(_input)
	_input.command_pressed.connect(_on_command_pressed)
	_input.command_released.connect(_on_command_released)


func _on_opponent_selected(player_id: int) -> void:
	# Target にするかどうかは Battle Layer が決める（要件定義 §53）。
	_runner.get_target_manager().set_manual_target(VIEWER_ID, player_id)


func _on_command_pressed(command: GameCommand.Command) -> void:
	var session: PuzzleSession = _viewer_session()
	if session == null:
		return

	match command:
		GameCommand.Command.MOVE_LEFT:
			session.press_move(AutoShift.Direction.LEFT)
		GameCommand.Command.MOVE_RIGHT:
			session.press_move(AutoShift.Direction.RIGHT)
		GameCommand.Command.SOFT_DROP:
			session.set_soft_dropping(true)
		GameCommand.Command.HARD_DROP:
			session.hard_drop()
		GameCommand.Command.ROTATE_LEFT:
			session.rotate(RotationSystem.Direction.COUNTER_CLOCKWISE)
		GameCommand.Command.ROTATE_RIGHT:
			session.rotate(RotationSystem.Direction.CLOCKWISE)
		GameCommand.Command.HOLD:
			session.hold()
		GameCommand.Command.PAUSE:
			set_paused(not _paused)


func _on_command_released(command: GameCommand.Command) -> void:
	var session: PuzzleSession = _viewer_session()
	if session == null:
		return

	match command:
		GameCommand.Command.MOVE_LEFT:
			session.release_move(AutoShift.Direction.LEFT)
		GameCommand.Command.MOVE_RIGHT:
			session.release_move(AutoShift.Direction.RIGHT)
		GameCommand.Command.SOFT_DROP:
			session.set_soft_dropping(false)


func _viewer_session() -> PuzzleSession:
	var viewer: BattlePlayerState = get_viewer()
	if viewer == null or not viewer.alive:
		return null
	return viewer.session
