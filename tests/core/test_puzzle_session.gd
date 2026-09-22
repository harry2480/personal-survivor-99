extends GutTest

## パズル進行の Unit テスト。実時間も Scene Tree も使わない。

const SEED: int = 20260920

var rules: GameRules
var session: PuzzleSession


func before_each() -> void:
	rules = GameRules.create_default()
	rules.gravity_cells_per_second = 0.0  # テスト中に勝手に落ちないようにする
	rules.lock_delay_sec = 0.5
	session = PuzzleSession.new(rules, PieceRandomizer.new(SEED))
	session.start(SEED)


func _fill_row_except(y: int, open_x: int) -> void:
	for x in range(Board.WIDTH):
		if x != open_x:
			session.get_board().set_cell(x, y, Piece.Type.I)


# --- 開始と出現 ------------------------------------------------------------


func test_starts_with_an_active_piece() -> void:
	assert_true(session.get_active_piece().is_active(), "Piece が出ている")
	assert_false(session.is_over(), "まだ終わっていない")
	assert_eq(session.get_cleared_lines_total(), 0, "消した行は 0")


func test_next_queue_is_visible() -> void:
	assert_eq(session.get_next_types().size(), NextQueue.MINIMUM_VISIBLE, "NEXT が 5 個見える")


func test_same_seed_produces_the_same_piece_order() -> void:
	var other := PuzzleSession.new(rules, PieceRandomizer.new(SEED))
	other.start(SEED)

	assert_eq(session.get_active_piece().type, other.get_active_piece().type, "最初の Piece が同じ")
	assert_eq(session.get_next_types(7), other.get_next_types(7), "NEXT も同じ")


# --- 落下と Lock -----------------------------------------------------------


func test_gravity_moves_the_piece_down() -> void:
	rules.gravity_cells_per_second = 1.0
	session = PuzzleSession.new(rules, PieceRandomizer.new(SEED))
	session.start(SEED)
	var before: int = session.get_active_piece().position.y

	session.update(1.0)

	assert_eq(session.get_active_piece().position.y, before + 1, "1 秒で 1 マス落ちる")


func test_hard_drop_locks_the_piece_and_spawns_the_next() -> void:
	var dropped_type: int = session.get_active_piece().type
	var expected_next: int = session.get_next_types(1)[0]

	var distance: int = session.hard_drop()

	assert_gt(distance, 0, "落ちた")
	assert_eq(session.get_active_piece().type, expected_next, "次の Piece が出ている")
	assert_gt(_count_filled_cells(), 0, "Board に書き込まれた")
	assert_eq(_dominant_locked_type(), dropped_type, "落とした Piece の種類で埋まる")


func test_lock_delay_locks_after_the_configured_time() -> void:
	session.hard_drop()  # 1 つ目を置いて 2 つ目に移る
	var piece_before: ActivePiece = session.get_active_piece()
	DropSystem.hard_drop(session.get_board(), piece_before)
	var type_before: int = piece_before.type

	session.update(0.4)
	assert_eq(session.get_active_piece().type, type_before, "猶予中は Lock しない")

	session.update(0.2)
	assert_ne(session.get_active_piece().type, -1, "Lock 後は次の Piece が出ている")


# --- 操作 ------------------------------------------------------------------


func test_move_shifts_the_piece() -> void:
	var before: int = session.get_active_piece().position.x

	session.press_move(AutoShift.Direction.LEFT)

	assert_eq(session.get_active_piece().position.x, before - 1, "押した瞬間に 1 マス動く")


func test_move_stops_at_the_wall() -> void:
	session.press_move(AutoShift.Direction.LEFT)
	for _i in range(40):
		session.update(1.0)

	assert_true(session.get_active_piece().can_place(session.get_board()), "壁を越えない")


func test_rotate_changes_the_rotation() -> void:
	var before: int = session.get_active_piece().rotation

	var rotated: bool = session.rotate(RotationSystem.Direction.CLOCKWISE)

	assert_true(rotated, "開けた場所では回せる")
	assert_ne(session.get_active_piece().rotation, before, "向きが変わる")


func test_hold_swaps_the_piece() -> void:
	var first: int = session.get_active_piece().type
	var expected_next: int = session.get_next_types(1)[0]

	assert_true(session.hold(), "Hold できる")

	assert_eq(session.get_held_type(), first, "預けられる")
	assert_eq(session.get_active_piece().type, expected_next, "NEXT から出てくる")
	assert_false(session.can_hold(), "同じ Piece 中は再使用できない")


func test_hold_returns_the_stored_piece_at_spawn_state() -> void:
	var first: int = session.get_active_piece().type
	session.hold()
	session.rotate(RotationSystem.Direction.CLOCKWISE)
	session.hard_drop()  # Lock して Hold を使えるようにする

	var second: int = session.get_active_piece().type
	session.hold()

	assert_eq(session.get_active_piece().type, first, "預けた Piece が戻る")
	assert_eq(session.get_active_piece().rotation, Piece.SPAWN_ROTATION as int, "初期回転で戻る")
	assert_eq(session.get_active_piece().position, Piece.get_spawn_position(first), "Spawn 位置で戻る")
	assert_eq(session.get_held_type(), second, "入れ替わる")


func test_ghost_position_is_below_the_piece() -> void:
	var piece: ActivePiece = session.get_active_piece()

	var ghost: Vector2i = session.get_ghost_position()

	assert_eq(ghost.x, piece.position.x, "横位置は同じ")
	assert_gt(ghost.y, piece.position.y, "下にある")


# --- Line Clear ------------------------------------------------------------


func test_line_clear_is_reported_and_counted() -> void:
	# 最下段を 1 マスだけ空けて、そこへ縦向きの I を落とす。
	_fill_row_except(Board.TOTAL_HEIGHT - 1, 0)
	var piece: ActivePiece = session.get_active_piece()
	piece.spawn(Piece.Type.I)
	piece.rotation = Piece.Rotation.RIGHT
	piece.position = Vector2i(-2, 0)

	watch_signals(session)
	session.hard_drop()

	assert_signal_emitted(session, "lines_cleared", "Line Clear が通知される")
	assert_eq(session.get_cleared_lines_total(), 1, "消した行が数えられる")
	assert_false(session.get_board().is_row_filled(Board.TOTAL_HEIGHT - 1), "埋まっていた行が消えた")
	# I の残り 3 マスが 1 段ずつ下がってくるので、最下段は空にはならない。
	assert_eq(session.get_board().get_cell(0, Board.TOTAL_HEIGHT - 1), Piece.Type.I as int, "上が詰まる")


# --- Top Out ---------------------------------------------------------------


func _block_spawn_area() -> void:
	# Spawn 位置（x=3..6）を塞ぐ。行を埋め切ると Line Clear で消えてしまうため、
	# 左端の 1 列だけ空けておく。
	var board: Board = session.get_board()
	for y in range(Board.VISIBLE_TOP_Y - 2, Board.VISIBLE_TOP_Y):
		for x in range(1, Board.WIDTH):
			board.set_cell(x, y, Piece.Type.I)


func test_top_out_when_the_spawn_position_is_blocked() -> void:
	_block_spawn_area()

	watch_signals(session)
	session.hard_drop()

	assert_signal_emitted(session, "topped_out", "Top Out が通知される")
	assert_true(session.is_over(), "ゲームが終わる")
	assert_false(session.get_active_piece().is_active(), "操作対象がなくなる")


func test_commands_are_ignored_after_top_out() -> void:
	_block_spawn_area()
	session.hard_drop()

	assert_eq(session.hard_drop(), 0, "Hard Drop が効かない")
	assert_false(session.rotate(RotationSystem.Direction.CLOCKWISE), "回転も効かない")
	assert_false(session.hold(), "Hold も効かない")

	session.update(10.0)
	assert_true(session.is_over(), "終了状態のまま")


# --- 決定論 ----------------------------------------------------------------


func test_same_commands_produce_the_same_board() -> void:
	var other := PuzzleSession.new(GameRules.create_default(), PieceRandomizer.new(SEED))
	other.start(SEED)
	session = PuzzleSession.new(GameRules.create_default(), PieceRandomizer.new(SEED))
	session.start(SEED)

	for index in range(20):
		for target in [session, other]:
			if index % 3 == 0:
				target.rotate(RotationSystem.Direction.CLOCKWISE)
			if index % 2 == 0:
				target.press_move(AutoShift.Direction.LEFT)
			target.hard_drop()
			target.update(1.0 / 60.0)

	assert_eq(
		session.get_board().to_strings(0, Board.TOTAL_HEIGHT),
		other.get_board().to_strings(0, Board.TOTAL_HEIGHT),
		"同じ Seed・同じ操作列からは同じ盤面になる"
	)


func _count_filled_cells() -> int:
	var count: int = 0
	var board: Board = session.get_board()
	for y in range(Board.TOTAL_HEIGHT):
		for x in range(Board.WIDTH):
			if not board.is_cell_empty(x, y):
				count += 1
	return count


func _dominant_locked_type() -> int:
	var board: Board = session.get_board()
	for y in range(Board.TOTAL_HEIGHT - 1, -1, -1):
		for x in range(Board.WIDTH):
			var value: int = board.get_cell(x, y)
			if value != Board.EMPTY:
				return value
	return -1


# --- T-Spin 判定 Module への受け渡し ----------------------------------------


class RecordingDetector:
	extends TSpinDetector

	var last_context: TSpinContext

	func detect(context: TSpinContext) -> Result:
		last_context = context
		return super.detect(context)


func test_rotation_is_reported_to_the_t_spin_module() -> void:
	var detector := RecordingDetector.new()
	session.set_t_spin_detector(detector)

	session.rotate(RotationSystem.Direction.CLOCKWISE)
	session.hard_drop()

	assert_not_null(detector.last_context, "判定 Module が呼ばれる")
	assert_not_null(detector.last_context.board, "盤面が渡される")
	assert_true(detector.last_context.piece_type >= 0, "Piece の種類が渡される")


func test_module_receives_the_rotation_flag_and_kick_index() -> void:
	var detector := RecordingDetector.new()
	session.set_t_spin_detector(detector)
	var piece: ActivePiece = session.get_active_piece()
	piece.spawn(Piece.Type.T)
	piece.position = Vector2i(3, Board.TOTAL_HEIGHT - 2)  # 床に接した状態

	# 床際で回転すると Wall Kick が働く（表の 2 番目）。
	assert_true(session.rotate(RotationSystem.Direction.CLOCKWISE), "前提: 回転できる")
	session.hard_drop()

	assert_true(detector.last_context.last_action_was_rotation, "直前の操作が回転だと伝わる")
	assert_eq(detector.last_context.kick_index, 2, "採用された Kick の index が伝わる")
	assert_eq(detector.last_context.kick_table_size, 5, "Kick Table の長さも伝わる")
	assert_eq(detector.last_context.piece_type, Piece.Type.T as int, "Piece の種類が伝わる")


func test_moving_after_rotating_clears_the_rotation_flag() -> void:
	var detector := RecordingDetector.new()
	session.set_t_spin_detector(detector)

	session.rotate(RotationSystem.Direction.CLOCKWISE)
	session.press_move(AutoShift.Direction.LEFT)
	session.hard_drop()

	assert_false(detector.last_context.last_action_was_rotation, "移動すると回転扱いではなくなる")


func test_falling_after_rotating_clears_the_rotation_flag() -> void:
	rules.gravity_cells_per_second = 5.0
	session = PuzzleSession.new(rules, PieceRandomizer.new(SEED))
	session.start(SEED)
	var detector := RecordingDetector.new()
	session.set_t_spin_detector(detector)

	session.rotate(RotationSystem.Direction.CLOCKWISE)
	session.update(1.0)
	session.hard_drop()

	assert_false(detector.last_context.last_action_was_rotation, "落下でも回転扱いではなくなる")
