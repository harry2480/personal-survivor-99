extends GutTest

## Danger Level の Unit テスト（要件定義 §92）。

var board: Board


func before_each() -> void:
	board = Board.new()


func _stack_to(height: int) -> void:
	for offset in range(height):
		board.set_cell(0, Board.TOTAL_HEIGHT - 1 - offset, Piece.Type.I)


func test_empty_board_is_safe() -> void:
	assert_eq(DangerLevel.get_stack_height(board), 0, "高さ 0")
	assert_eq(DangerLevel.get_ratio(board), 0.0, "比率 0")
	assert_eq(DangerLevel.get_level(board), DangerLevel.Level.SAFE, "SAFE")


func test_stack_height_counts_from_the_topmost_block() -> void:
	_stack_to(5)

	assert_eq(DangerLevel.get_stack_height(board), 5, "積み上がった高さが取れる")


func test_holes_do_not_reduce_the_height() -> void:
	board.set_cell(0, Board.TOTAL_HEIGHT - 10, Piece.Type.I)

	assert_eq(DangerLevel.get_stack_height(board), 10, "一番上のブロックまでで測る")


func test_levels_follow_the_ratio() -> void:
	var cases: Dictionary = {
		4: DangerLevel.Level.SAFE,
		10: DangerLevel.Level.WARNING,
		14: DangerLevel.Level.DANGER,
		18: DangerLevel.Level.CRITICAL,
	}
	for height in cases:
		board.clear()
		_stack_to(height)
		assert_eq(
			DangerLevel.get_level(board),
			cases[height],
			"高さ %d の段階（比率 %.2f）" % [height, DangerLevel.get_ratio(board)]
		)


func test_ratio_is_clamped_above_the_visible_area() -> void:
	_stack_to(Board.TOTAL_HEIGHT)

	assert_eq(DangerLevel.get_ratio(board), 1.0, "表示領域を超えても 1.0 で頭打ち")
	assert_eq(DangerLevel.get_level(board), DangerLevel.Level.CRITICAL, "CRITICAL")


func test_player_state_computes_the_level_from_its_board() -> void:
	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	var session := PuzzleSession.new(rules)
	session.start(1)
	var state: BattlePlayerState = BattlePlayerState.create(0, PlayerType.Type.CPU)
	state.attach_session(session)

	assert_eq(state.refresh_danger_level(), DangerLevel.Level.SAFE, "初期状態は SAFE")

	for offset in range(18):
		session.get_board().set_cell(0, Board.TOTAL_HEIGHT - 1 - offset, Piece.Type.I)

	assert_eq(state.refresh_danger_level(), DangerLevel.Level.CRITICAL, "積み上がると CRITICAL")
	assert_eq(state.danger_level, DangerLevel.Level.CRITICAL, "状態にも保持される")


func test_state_without_a_board_is_safe() -> void:
	var state: BattlePlayerState = BattlePlayerState.create(0, PlayerType.Type.CPU)

	assert_eq(state.refresh_danger_level(), DangerLevel.Level.SAFE, "盤面がなければ SAFE")
	assert_eq(state.refresh_incoming_garbage(), 0, "Incoming も 0")


func test_level_names() -> void:
	assert_eq(DangerLevel.get_level_name(DangerLevel.Level.CRITICAL), "CRITICAL", "名前が取れる")
