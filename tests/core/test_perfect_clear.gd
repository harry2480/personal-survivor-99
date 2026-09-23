extends GutTest

## Perfect Clear の Unit テスト（要件定義 §36）。

var board: Board


func before_each() -> void:
	board = Board.new()


func test_empty_board_after_a_clear_is_a_perfect_clear() -> void:
	assert_true(PerfectClear.is_achieved(board, 1), "Clear 後に空なら成立")


func test_remaining_blocks_prevent_it() -> void:
	board.set_cell(0, Board.TOTAL_HEIGHT - 1, Piece.Type.I)

	assert_false(PerfectClear.is_achieved(board, 1), "1 マスでも残っていれば不成立")


func test_blocks_in_the_spawn_buffer_prevent_it() -> void:
	board.set_cell(4, 0, Piece.Type.I)

	assert_false(PerfectClear.is_achieved(board, 1), "内部領域の上部に残っていても不成立")


func test_no_clear_is_never_a_perfect_clear() -> void:
	assert_false(PerfectClear.is_achieved(board, 0), "行が消えていなければ不成立")


func test_is_board_empty() -> void:
	assert_true(PerfectClear.is_board_empty(board), "初期状態は空")

	board.set_cell(5, 20, Piece.Type.T)

	assert_false(PerfectClear.is_board_empty(board), "1 マスでも埋まっていれば空ではない")


func test_clearing_the_last_line_produces_a_perfect_clear() -> void:
	# 最下段 1 行だけを埋めて消す。
	for x in range(Board.WIDTH):
		board.set_cell(x, Board.TOTAL_HEIGHT - 1, Piece.Type.I)

	var result: LineClearResult = LineClear.execute(board)

	assert_true(PerfectClear.is_achieved(board, result.line_count), "実際の Clear 経路で成立する")
