extends Node2D

## Phase 1 の動作確認用の最小画面。
##
## 「Keyboard で通常 Puzzle として遊べる」ことを実際に確かめるためだけの画面で、
## 本番の Battle UI（Phase 8 / #48〜#50）とは別物。Theme もアニメーションも使わず、
## Board の状態をそのまま描くだけにしている。
##
## Presentation Layer なので、Game Core の内部状態を直接書き換えない（要件定義 §19）。
## 操作は [InputManager] が返す [enum GameCommand.Command] だけを見る（§11）。

const CELL_SIZE: int = 24
const BOARD_ORIGIN := Vector2(40, 40)
const PREVIEW_ORIGIN := Vector2(40 + 10 * CELL_SIZE + 24, 40)
const HOLD_ORIGIN := Vector2(40 + 10 * CELL_SIZE + 24, 40 + 9 * CELL_SIZE)

const PIECE_COLORS: PackedColorArray = [
	Color("00bcd4"),  # I
	Color("3f51b5"),  # J
	Color("ff9800"),  # L
	Color("ffeb3b"),  # O
	Color("4caf50"),  # S
	Color("9c27b0"),  # T
	Color("f44336"),  # Z
]
const EMPTY_COLOR := Color("161821")
const GRID_COLOR := Color("2a2d3a")
const GHOST_ALPHA: float = 0.28

var _session: PuzzleSession
var _input: InputManager
var _status_label: Label


func _ready() -> void:
	_input = InputManager.new()
	_input.name = "InputManager"
	add_child(_input)
	_input.command_pressed.connect(_on_command_pressed)
	_input.command_released.connect(_on_command_released)

	_status_label = Label.new()
	_status_label.position = Vector2(40, 40 + 20 * CELL_SIZE + 12)
	add_child(_status_label)

	_session = PuzzleSession.new(_load_rules())
	_session.lines_cleared.connect(_on_lines_cleared)
	_session.topped_out.connect(_on_topped_out)
	_session.start(randi())

	_update_status("")


func _process(delta: float) -> void:
	_session.update(delta)
	queue_redraw()


func _draw() -> void:
	_draw_board()
	_draw_ghost()
	_draw_active_piece()
	_draw_next()
	_draw_hold()


# --- 入力 ------------------------------------------------------------------


func _on_command_pressed(command: GameCommand.Command) -> void:
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
		GameCommand.Command.PAUSE:
			_toggle_pause()


func _on_command_released(command: GameCommand.Command) -> void:
	match command:
		GameCommand.Command.MOVE_LEFT:
			_session.release_move(AutoShift.Direction.LEFT)
		GameCommand.Command.MOVE_RIGHT:
			_session.release_move(AutoShift.Direction.RIGHT)
		GameCommand.Command.SOFT_DROP:
			_session.set_soft_dropping(false)


func _toggle_pause() -> void:
	# Phase 1 では Scene を切り替えず、この画面の中で止めるだけにする。
	set_process(not is_processing())
	_input.release_all()
	_update_status("PAUSED" if not is_processing() else "")


# --- 進行 ------------------------------------------------------------------


func _on_lines_cleared(result: LineClearResult) -> void:
	_update_status(LineClear.get_type_name(result.type))


func _on_topped_out() -> void:
	set_process(false)
	_update_status("TOP OUT")


func _update_status(message: String) -> void:
	var lines: int = _session.get_cleared_lines_total() if _session != null else 0
	_status_label.text = "Lines: %d    %s" % [lines, message]


# --- 描画 ------------------------------------------------------------------


func _cell_rect(x: int, y: int, origin: Vector2) -> Rect2:
	return Rect2(origin + Vector2(x * CELL_SIZE, y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))


func _draw_board() -> void:
	var board: Board = _session.get_board()
	for row in range(Board.VISIBLE_HEIGHT):
		for x in range(Board.WIDTH):
			var value: int = board.get_cell(x, Board.VISIBLE_TOP_Y + row)
			var rect: Rect2 = _cell_rect(x, row, BOARD_ORIGIN)
			draw_rect(rect, EMPTY_COLOR if value == Board.EMPTY else PIECE_COLORS[value])
			draw_rect(rect, GRID_COLOR, false, 1.0)


func _draw_ghost() -> void:
	var piece: ActivePiece = _session.get_active_piece()
	if not piece.is_active():
		return

	var landing: Vector2i = _session.get_ghost_position()
	var color: Color = PIECE_COLORS[piece.type]
	color.a = GHOST_ALPHA
	for cell in Collision.get_cells(piece.type, piece.rotation, landing):
		_draw_board_cell(cell, color)


func _draw_active_piece() -> void:
	var piece: ActivePiece = _session.get_active_piece()
	if not piece.is_active():
		return

	for cell in piece.get_cells():
		_draw_board_cell(cell, PIECE_COLORS[piece.type])


func _draw_board_cell(cell: Vector2i, color: Color) -> void:
	var row: int = cell.y - Board.VISIBLE_TOP_Y
	if row < 0 or row >= Board.VISIBLE_HEIGHT:
		return
	draw_rect(_cell_rect(cell.x, row, BOARD_ORIGIN), color)


func _draw_next() -> void:
	var types: Array[int] = _session.get_next_types()
	for index in range(types.size()):
		var origin: Vector2 = PREVIEW_ORIGIN + Vector2(0, index * 3 * CELL_SIZE)
		_draw_piece_preview(types[index], origin)


func _draw_hold() -> void:
	var held: int = _session.get_held_type()
	if held == HoldSlot.EMPTY:
		return
	var color: Color = PIECE_COLORS[held]
	if not _session.can_hold():
		color = color.darkened(0.5)
	_draw_piece_preview(held, HOLD_ORIGIN, color)


func _draw_piece_preview(
	type: int, origin: Vector2, override_color: Color = Color.TRANSPARENT
) -> void:
	var color: Color = PIECE_COLORS[type] if override_color.a == 0.0 else override_color
	for offset in Piece.get_cells(type, Piece.SPAWN_ROTATION):
		draw_rect(_cell_rect(offset.x, offset.y, origin), color)


func _load_rules() -> GameRules:
	# Presentation Layer が読み込んで Game Core へ渡す（Game Core は FileSystem を
	# 知らない。要件定義 §17）。
	var rules: Resource = load("res://config/game_rules.tres")
	if rules is GameRules:
		return rules as GameRules
	return GameRules.create_default()
