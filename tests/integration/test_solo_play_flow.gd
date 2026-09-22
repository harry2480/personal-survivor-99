extends GutTest

## Phase 1 の完了条件「Piece 落下から Line Clear までが遊べる」を、
## 操作列だけで再現する統合テスト。Scene も実時間も使わない。

const SEED: int = 20260920


func _make_session() -> PuzzleSession:
	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	var session := PuzzleSession.new(rules, PieceRandomizer.new(SEED))
	session.start(SEED)
	return session


# 押しっぱなしは 1 回しか動かないため、1 マスごとに押して離す。
func _tap_move(session: PuzzleSession, direction: AutoShift.Direction, times: int) -> void:
	for _step in range(times):
		session.press_move(direction)
		session.release_move(direction)


# 最初に I が出る Seed を探す。Randomizer は決定論的なので毎回同じ Seed が見つかる。
func _find_seed_starting_with_i() -> int:
	for candidate in range(1, 200):
		if PieceRandomizer.new(candidate).next() == Piece.Type.I:
			return candidate
	return -1


func test_playing_clears_a_line() -> void:
	# 最下段を左端 1 列だけ空け、縦向きの I を左端へ落として行を揃える。
	# 盤面の準備以外は公開コマンド（回転・移動・Hard Drop）だけで操作する。
	var i_seed: int = _find_seed_starting_with_i()
	assert_gt(i_seed, 0, "前提: I から始まる Seed が見つかる")

	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	var session := PuzzleSession.new(rules, PieceRandomizer.new(i_seed))
	session.start(i_seed)
	assert_eq(session.get_active_piece().type, Piece.Type.I as int, "前提: I が出ている")

	var board: Board = session.get_board()
	for x in range(1, Board.WIDTH):
		board.set_cell(x, Board.TOTAL_HEIGHT - 1, Piece.Type.I)

	session.rotate(RotationSystem.Direction.CLOCKWISE)
	_tap_move(session, AutoShift.Direction.LEFT, Board.WIDTH)
	session.hard_drop()

	assert_eq(session.get_cleared_lines_total(), 1, "左端が埋まって 1 行消える")
	assert_false(board.is_row_filled(Board.TOTAL_HEIGHT - 1), "揃った行は残らない")
	assert_false(session.is_over(), "Top Out していない")


func test_playing_many_pieces_keeps_the_board_consistent() -> void:
	var session: PuzzleSession = _make_session()

	for index in range(60):
		if session.is_over():
			break
		if index % 4 == 0:
			session.rotate(RotationSystem.Direction.CLOCKWISE)
		if index % 5 == 0:
			session.hold()
		_tap_move(
			session, AutoShift.Direction.LEFT if index % 2 == 0 else AutoShift.Direction.RIGHT, 3
		)
		session.hard_drop()

		var board: Board = session.get_board()
		for y in range(Board.TOTAL_HEIGHT):
			assert_false(board.is_row_filled(y), "揃った行は残らない（index=%d）" % index)


func test_gravity_only_play_reaches_a_lock() -> void:
	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 20.0
	rules.lock_delay_sec = 0.1
	var session := PuzzleSession.new(rules, PieceRandomizer.new(SEED))
	session.start(SEED)
	var first_type: int = session.get_active_piece().type

	# 60fps 相当で 3 秒ぶん進める。落下 → 接地 → Lock → 次の Piece まで届く。
	for _frame in range(180):
		session.update(1.0 / 60.0)

	assert_ne(session.get_active_piece().type, -1, "次の Piece が出ている")
	assert_gt(_count_filled_cells(session.get_board()), 0, "Lock されて盤面に積まれた")
	assert_false(session.is_over(), "Top Out していない")
	assert_true(first_type >= 0, "最初の Piece が存在していた")


func test_top_out_ends_the_session() -> void:
	var session: PuzzleSession = _make_session()

	# 同じ列に置き続ければ、いずれ Spawn 位置まで積み上がる。
	for _index in range(80):
		if session.is_over():
			break
		_tap_move(session, AutoShift.Direction.LEFT, Board.WIDTH)
		session.hard_drop()

	assert_true(session.is_over(), "積み上がれば Top Out する")


func _count_filled_cells(board: Board) -> int:
	var count: int = 0
	for y in range(Board.TOTAL_HEIGHT):
		for x in range(Board.WIDTH):
			if not board.is_cell_empty(x, y):
				count += 1
	return count
