extends GutTest

## 自分の盤面表示の確認（要件定義 §19 / §88 / §92）。
##
## 見るのは 3 つ。
## [br]・§88 の 5 つ（Fixed Blocks / Active Piece / Ghost / Incoming / Danger）が出ること
## [br]・Danger を **UI 側で判定していない**こと（Battle Layer の値をそのまま映す）
## [br]・UI が Game Core の状態を**書き換えない**こと

const PANEL := preload("res://ui/board/player_board_panel.tscn")
const SEED: int = 20260922

var panel: PlayerBoardPanel
var view: PlayerBoardView
var session: PuzzleSession
var player: BattlePlayerState


func before_each() -> void:
	panel = PANEL.instantiate()
	add_child_autofree(panel)
	view = panel.get_board_view()

	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	session = PuzzleSession.new(rules, PieceRandomizer.new(SEED))
	session.start(SEED)

	player = BattlePlayerState.create(0, PlayerType.Type.LOCAL_HUMAN)
	player.attach_session(session)
	panel.bind(session, player)


func after_each() -> void:
	panel.unbind()


func _fill_bottom_row(value: int = Piece.Type.I) -> void:
	for x in range(Board.WIDTH - 1):
		session.get_board().set_cell(x, Board.TOTAL_HEIGHT - 1, value)


## Active Piece を見えている領域まで下ろす。
##
## Spawn 直後の Piece は Spawn Buffer（見えない領域）にいるため、そのままでは
## 表示に出ない。
func _move_piece_into_view() -> void:
	session.get_active_piece().position += Vector2i(0, Board.BUFFER_HEIGHT)
	view.refresh()


# --- Fixed Blocks（要件定義 §88） -------------------------------------------


func test_fixed_blocks_are_shown() -> void:
	_fill_bottom_row()
	session.hard_drop()  # Lock で「読み直しが要る」と分かる（Signal 経由）。
	view.refresh()

	for x in range(Board.WIDTH - 1):
		assert_eq(view.get_cell(x, Board.VISIBLE_HEIGHT - 1), Piece.Type.I, "置いたブロックが出る")
	assert_eq(view.get_cell(Board.WIDTH - 1, Board.VISIBLE_HEIGHT - 1), Board.EMPTY, "空きは空き")


func test_restarting_the_session_clears_the_shown_blocks() -> void:
	# 同じ Session を start() で再開すると盤面は消える。Lock も Line Clear も起きないが、
	# 表示も読み直して前の盤面を残さない。
	_fill_bottom_row()
	session.hard_drop()
	view.refresh()
	assert_ne(view.get_cell(0, Board.VISIBLE_HEIGHT - 1), Board.EMPTY, "再開前は置いたブロックが見える")

	session.start(SEED)
	view.refresh()

	for x in range(Board.WIDTH):
		assert_eq(view.get_cell(x, Board.VISIBLE_HEIGHT - 1), Board.EMPTY, "再開後は列 %d が空" % x)


func test_garbage_rows_are_shown() -> void:
	# Garbage は Delay 経過後、次の Lock で盤面へ入る（要件定義 §40〜§41）。
	session.receive_garbage_lines(3)
	session.update(2.0)
	session.hard_drop()
	view.refresh()

	var filled: int = 0
	for x in range(Board.WIDTH):
		if view.get_cell(x, Board.VISIBLE_HEIGHT - 1) == GarbageQueue.GARBAGE_CELL:
			filled += 1
	assert_eq(filled, Board.WIDTH - 1, "Garbage 行は穴 1 つを残して埋まる")


func test_garbage_has_its_own_color() -> void:
	# Garbage は Piece の種類（0〜6）より大きい値で盤面へ入る。色を Piece の配列から
	# そのまま引くと範囲外参照になるため、専用色を返すことを確かめる。
	var palette := BoardPalette.create_default()
	assert_gte(GarbageQueue.GARBAGE_CELL, palette.piece_colors.size(), "前提: Garbage は Piece の色の範囲外")

	assert_eq(
		palette.get_cell_color(GarbageQueue.GARBAGE_CELL), palette.garbage_color, "Garbage は専用色で出る"
	)
	for type in range(palette.piece_colors.size()):
		assert_eq(palette.get_cell_color(type), palette.piece_colors[type], "Piece の色は変わらない")
	assert_eq(palette.get_cell_color(Board.EMPTY), palette.empty_color, "空きマスの色も変わらない")


# --- Active Piece と Ghost（要件定義 §88） ----------------------------------


func test_active_piece_and_ghost_are_shown() -> void:
	_move_piece_into_view()

	assert_eq(view.get_active_cells().size(), Piece.CELL_COUNT, "Active Piece の 4 マスが出る")
	assert_eq(view.get_ghost_cells().size(), Piece.CELL_COUNT, "Ghost の 4 マスが出る")


func test_a_piece_in_the_spawn_buffer_is_not_drawn() -> void:
	# Spawn 直後は見えない領域にいる。見えているぶんだけ出す。
	view.refresh()

	assert_eq(view.get_active_cells().size(), 0, "Spawn Buffer のマスは出さない")
	assert_eq(view.get_ghost_cells().size(), Piece.CELL_COUNT, "Ghost は盤面の底に出る")


func test_ghost_sits_at_the_landing_position() -> void:
	view.refresh()

	var lowest_ghost_y: int = 0
	for cell in view.get_ghost_cells():
		lowest_ghost_y = maxi(lowest_ghost_y, cell.y)

	assert_eq(lowest_ghost_y, Board.VISIBLE_HEIGHT - 1, "Ghost は落ちきった位置に出る")


func test_active_piece_follows_the_session() -> void:
	_move_piece_into_view()
	var before: Array[Vector2i] = view.get_active_cells().duplicate()

	session.get_active_piece().position += Vector2i(1, 0)
	view.refresh()

	assert_ne(view.get_active_cells(), before, "Piece が動けば表示も動く")


# --- Incoming Garbage（要件定義 §88 / §91） ---------------------------------


func test_incoming_garbage_comes_from_the_battle_layer() -> void:
	player.incoming_garbage = 4

	view.refresh()

	assert_eq(view.get_incoming_lines(), 4, "Battle Layer の Incoming をそのまま出す")


# --- Danger State（要件定義 §92） -------------------------------------------


func test_danger_state_comes_from_the_battle_layer() -> void:
	player.danger_level = DangerLevel.Level.CRITICAL

	view.refresh()

	assert_eq(view.get_danger_level(), DangerLevel.Level.CRITICAL, "Battle Layer の値を映す")


func test_ui_does_not_judge_danger_by_itself() -> void:
	# 盤面は危険だが、Battle Layer は SAFE と言っている状況を作る。
	# UI が独自判定していれば CRITICAL になってしまう（要件定義 §92 違反）。
	for y in range(Board.VISIBLE_TOP_Y, Board.TOTAL_HEIGHT):
		for x in range(Board.WIDTH - 1):
			session.get_board().set_cell(x, y, Piece.Type.I)
	player.danger_level = DangerLevel.Level.SAFE

	view.refresh()

	assert_eq(view.get_danger_level(), DangerLevel.Level.SAFE, "UI 側で Danger を判定しない")


func test_view_does_not_judge_danger_without_the_battle_layer() -> void:
	# Battle Layer の状態を渡されていなければ、盤面が埋まっていても UI は判定しない（§92）。
	panel.bind(session, null)
	for y in range(Board.VISIBLE_TOP_Y, Board.TOTAL_HEIGHT):
		for x in range(Board.WIDTH - 1):
			session.get_board().set_cell(x, y, Piece.Type.I)

	view.refresh()

	assert_eq(view.get_danger_level(), DangerLevel.Level.SAFE, "UI は盤面から判定しない")


# --- Hold / NEXT（要件定義 §88 / §90） --------------------------------------


func test_next_shows_at_least_five_pieces() -> void:
	panel.refresh()

	assert_gte(panel.get_next_view().get_types().size(), 5, "NEXT は最低 5 個（#48 の完了条件）")
	assert_eq(panel.get_next_view().get_types(), session.get_next_types(5), "並びは Game Core のまま")


func test_hold_shows_the_held_piece() -> void:
	var current: int = session.get_active_piece().type
	session.hold()
	panel.refresh()

	assert_eq(panel.get_hold_view().get_types(), [current] as Array[int], "Hold した Piece が出る")
	assert_true(panel.get_hold_view().is_dimmed(), "もう一度は使えないので薄く出す")


func test_hold_is_empty_at_the_start() -> void:
	panel.refresh()

	assert_eq(panel.get_hold_view().get_types().size(), 0, "最初の Hold は空")


# --- Game Core を書き換えない（要件定義 §19） -------------------------------


func test_view_never_changes_the_game_core() -> void:
	_fill_bottom_row()
	session.hard_drop()
	var before: PackedStringArray = session.get_board().to_strings(
		Board.VISIBLE_TOP_Y, Board.VISIBLE_HEIGHT
	)
	var before_piece: Vector2i = session.get_active_piece().position
	var before_next: Array[int] = session.get_next_types(5)

	for _frame in range(10):
		panel.refresh()
		view.refresh()

	assert_eq(
		session.get_board().to_strings(Board.VISIBLE_TOP_Y, Board.VISIBLE_HEIGHT),
		before,
		"盤面を書き換えない"
	)
	assert_eq(session.get_active_piece().position, before_piece, "Piece を動かさない")
	assert_eq(session.get_next_types(5), before_next, "NEXT を消費しない")


# --- 更新の仕方（要件定義 §108） --------------------------------------------


func test_fixed_blocks_are_read_only_when_they_change() -> void:
	# Signal で変化を知る作り。盤面を直接いじっても、Signal が出るまでは読み直さない。
	view.refresh()
	session.get_board().set_cell(0, Board.TOTAL_HEIGHT - 1, Piece.Type.Z)

	view.refresh()
	assert_eq(view.get_cell(0, Board.VISIBLE_HEIGHT - 1), Board.EMPTY, "毎フレーム全走査しない")

	session.hard_drop()
	view.refresh()
	assert_eq(view.get_cell(0, Board.VISIBLE_HEIGHT - 1), Piece.Type.Z, "Lock で読み直す")
