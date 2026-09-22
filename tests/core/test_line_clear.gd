extends GutTest

## Line Clear の Unit テスト（要件定義 §32）。

var board: Board


func before_each() -> void:
	board = Board.new()


func _fill_rows(count: int) -> void:
	for offset in range(count):
		var y: int = Board.TOTAL_HEIGHT - 1 - offset
		for x in range(Board.WIDTH):
			board.set_cell(x, y, Piece.Type.I)


# --- 種別判定 --------------------------------------------------------------


func test_clear_types() -> void:
	assert_eq(LineClear.get_type(0), LineClear.Type.NONE, "0 行は NONE")
	assert_eq(LineClear.get_type(1), LineClear.Type.SINGLE, "1 行は Single")
	assert_eq(LineClear.get_type(2), LineClear.Type.DOUBLE, "2 行は Double")
	assert_eq(LineClear.get_type(3), LineClear.Type.TRIPLE, "3 行は Triple")
	assert_eq(LineClear.get_type(4), LineClear.Type.QUAD, "4 行は Quad")


func test_negative_and_excessive_counts_are_clamped() -> void:
	assert_eq(LineClear.get_type(-1), LineClear.Type.NONE, "負の行数は NONE")
	assert_eq(LineClear.get_type(10), LineClear.Type.QUAD, "4 行を超えても Quad")


func test_type_names() -> void:
	assert_eq(LineClear.get_type_name(LineClear.Type.QUAD), "QUAD", "種別名が取れる")


# --- 実行 ------------------------------------------------------------------


func test_single_clear() -> void:
	_fill_rows(1)

	var result: LineClearResult = LineClear.execute(board)

	assert_eq(result.line_count, 1, "1 行消える")
	assert_eq(result.type, LineClear.Type.SINGLE, "Single と判定される")
	assert_true(result.has_cleared(), "消えたことが分かる")
	assert_true(board.is_row_empty(Board.TOTAL_HEIGHT - 1), "最下段が空になる")


func test_double_triple_and_quad() -> void:
	var expected: Dictionary = {
		2: LineClear.Type.DOUBLE,
		3: LineClear.Type.TRIPLE,
		4: LineClear.Type.QUAD,
	}
	for count in expected:
		board.clear()
		_fill_rows(count)

		var result: LineClearResult = LineClear.execute(board)

		assert_eq(result.line_count, count, "%d 行消える" % count)
		assert_eq(result.type, expected[count], "%d 行の種別" % count)


func test_no_clear_returns_none() -> void:
	board.set_cell(0, Board.TOTAL_HEIGHT - 1, Piece.Type.I)

	var result: LineClearResult = LineClear.execute(board)

	assert_eq(result.line_count, 0, "何も消えない")
	assert_eq(result.type, LineClear.Type.NONE, "NONE")
	assert_false(result.has_cleared(), "消えていない")


func test_cleared_rows_are_reported_top_to_bottom() -> void:
	_fill_rows(3)

	var result: LineClearResult = LineClear.execute(board)

	assert_eq(
		result.cleared_rows,
		[Board.TOTAL_HEIGHT - 3, Board.TOTAL_HEIGHT - 2, Board.TOTAL_HEIGHT - 1] as Array[int],
		"上から順に返る"
	)


func test_rows_above_shift_down() -> void:
	_fill_rows(2)
	board.set_cell(3, Board.TOTAL_HEIGHT - 3, Piece.Type.T)

	LineClear.execute(board)

	assert_eq(board.get_cell(3, Board.TOTAL_HEIGHT - 1), Piece.Type.T as int, "上の行が下まで落ちる")
	assert_true(board.is_row_empty(Board.TOTAL_HEIGHT - 3), "元の位置は空になる")


func test_non_adjacent_rows_clear_together() -> void:
	for x in range(Board.WIDTH):
		board.set_cell(x, Board.TOTAL_HEIGHT - 1, Piece.Type.I)
		board.set_cell(x, Board.TOTAL_HEIGHT - 3, Piece.Type.I)
	board.set_cell(0, Board.TOTAL_HEIGHT - 2, Piece.Type.T)

	var result: LineClearResult = LineClear.execute(board)

	assert_eq(result.line_count, 2, "離れた 2 行が同時に消える")
	assert_eq(board.get_cell(0, Board.TOTAL_HEIGHT - 1), Piece.Type.T as int, "間の行が下がる")


func test_find_filled_rows_does_not_clear() -> void:
	_fill_rows(2)

	var rows: Array[int] = LineClear.find_filled_rows(board)

	assert_eq(rows.size(), 2, "消える行が分かる")
	assert_true(board.is_row_filled(Board.TOTAL_HEIGHT - 1), "調べただけでは消えない")
