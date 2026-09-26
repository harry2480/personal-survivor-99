extends Node2D

## Keyboard / Controller での単体プレイ画面。
##
## 描画は Battle UI と同じ [PlayerBoardPanel]（#48）に任せ、この画面は
## **入力と進行**だけを持つ。Phase 1 ではここに独自の描画を持っていたが、
## 本番の Board View ができたので二重に持たない。
##
## Presentation Layer なので、Game Core の内部状態を直接書き換えない（要件定義 §19）。
## 操作は [InputManager] が返す [enum GameCommand.Command] だけを見る（§11）。

## 画面の進行状態。
##
## set_process() だけで止めると、_process() は止まっても InputManager は入力を
## 受け続け、Pause 中や TOP OUT 後も Session を操作できてしまう。
enum ScreenState { PLAYING, PAUSED, TOPPED_OUT }

## 画面の左上からの余白（ピクセル）。
const MARGIN := Vector2(40, 40)

## 配色の置き場所（要件定義 §38 / §119）。
const PALETTE_PATH: String = "res://assets/themes/board_palette.tres"

var _session: PuzzleSession
var _input: InputManager
var _status_label: Label
var _board_panel: PlayerBoardPanel
var _player: BattlePlayerState
var _state: ScreenState = ScreenState.PLAYING


func _ready() -> void:
	_input = InputManager.new()
	_input.name = "InputManager"
	add_child(_input)
	_input.command_pressed.connect(_on_command_pressed)
	_input.command_released.connect(_on_command_released)

	var rules: GameRules = _load_rules()
	InputManager.apply_dead_zone(InputManager.DEFAULT_DEAD_ZONE)

	_session = PuzzleSession.new(rules)
	_session.lines_cleared.connect(_on_lines_cleared)
	_session.topped_out.connect(_on_topped_out)
	_session.start(randi())

	_board_panel = PlayerBoardPanel.new()
	_board_panel.name = "PlayerBoardPanel"
	_board_panel.position = MARGIN
	add_child(_board_panel)
	var palette: Resource = load(PALETTE_PATH)
	if palette is BoardPalette:
		_board_panel.set_palette(palette)
	# Danger の判定は Battle Layer が持つ（要件定義 §92）。Battle がいない単体プレイでも
	# BattlePlayerState に判定させ、Board View にはその値を渡す。
	_player = BattlePlayerState.create(0, PlayerType.Type.LOCAL_HUMAN)
	_player.attach_session(_session)
	_refresh_player_state()
	_board_panel.bind(_session, _player)

	_status_label = Label.new()
	_status_label.position = (
		MARGIN + Vector2(0.0, float(Board.VISIBLE_HEIGHT * PlayerBoardView.CELL_SIZE) + 32.0)
	)
	add_child(_status_label)

	_update_status("")


func _process(delta: float) -> void:
	if _state != ScreenState.PLAYING:
		return
	_session.update(delta)
	_refresh_player_state()


# Danger と Incoming を Battle Layer の判定で更新する。
func _refresh_player_state() -> void:
	_player.refresh_danger_level()
	_player.refresh_incoming_garbage()


# --- 入力 ------------------------------------------------------------------


func _on_command_pressed(command: GameCommand.Command) -> void:
	if _state == ScreenState.TOPPED_OUT:
		return
	if command == GameCommand.Command.PAUSE:
		_toggle_pause()
		return
	if _state == ScreenState.PAUSED:
		return

	match command:
		GameCommand.Command.MOVE_LEFT:
			_session.press_move(AutoShift.Direction.LEFT)
		GameCommand.Command.MOVE_RIGHT:
			_session.press_move(AutoShift.Direction.RIGHT)
		GameCommand.Command.SOFT_DROP:
			_session.set_soft_dropping(true)
		GameCommand.Command.HARD_DROP:
			_session.hard_drop()
		GameCommand.Command.ROTATE_LEFT:
			_session.rotate(RotationSystem.Direction.COUNTER_CLOCKWISE)
		GameCommand.Command.ROTATE_RIGHT:
			_session.rotate(RotationSystem.Direction.CLOCKWISE)
		GameCommand.Command.HOLD:
			_session.hold()


func _on_command_released(command: GameCommand.Command) -> void:
	# 解除は状態を問わず通す。Pause 時の release_all() を無視すると、再開時に
	# 押しっぱなし扱いが残る。
	match command:
		GameCommand.Command.MOVE_LEFT:
			_session.release_move(AutoShift.Direction.LEFT)
		GameCommand.Command.MOVE_RIGHT:
			_session.release_move(AutoShift.Direction.RIGHT)
		GameCommand.Command.SOFT_DROP:
			_session.set_soft_dropping(false)


func _toggle_pause() -> void:
	# Phase 1 では Scene を切り替えず、この画面の中で止めるだけにする。
	match _state:
		ScreenState.PLAYING:
			_state = ScreenState.PAUSED
		ScreenState.PAUSED:
			_state = ScreenState.PLAYING
		_:
			return

	_input.release_all()
	_update_status("PAUSED" if _state == ScreenState.PAUSED else "")


# --- 進行 ------------------------------------------------------------------


func _on_lines_cleared(result: LineClearResult) -> void:
	_update_status(LineClear.get_type_name(result.type))


func _on_topped_out() -> void:
	_state = ScreenState.TOPPED_OUT
	_input.release_all()
	_update_status("TOP OUT")


func _update_status(message: String) -> void:
	var lines: int = _session.get_scoring().get_cleared_lines_total() if _session != null else 0
	_status_label.text = "Lines: %d    %s" % [lines, message]


func _load_rules() -> GameRules:
	# Presentation Layer が読み込んで Game Core へ渡す（Game Core は FileSystem を
	# 知らない。要件定義 §17）。
	# load() は Resource をキャッシュして共有するため、複製してから渡す。
	# 複製しないと apply_user_settings() の書き換えが全読み込み先へ波及する。
	var rules: Resource = load("res://config/game_rules.tres")
	if rules is GameRules:
		return rules.duplicate() as GameRules
	return GameRules.create_default()
