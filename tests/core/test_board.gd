extends GutTest

## Board の Unit テスト。Scene Tree も実時間も使わず、ロジックを直接呼ぶ。

var board: Board


func before_each() -> void:
	board = Board.new()


# --- 定数と領域の分離 ------------------------------------------------------


func test_visible_area_is_10x20() -> void:
	assert_eq(Board.WIDTH, 10, "表示領域の幅は 10")
	assert_eq(Board.VISIBLE_HEIGHT, 20, "表示領域の高さは 20")


func test_internal_area_includes_spawn_buffer() -> void:
	assert_eq(Board.TOTAL_HEIGHT, 40, "内部領域の高さは 40")
	assert_gt(Board.TOTAL_HEIGHT, Board.VISIBLE_HEIGHT, "内部領域は表示領域より高い")


func test_buffer_height_is_derived_from_total_and_visible() -> void:
	# 内部行数を変えたときに Buffer が自動で追従することを保証する。
	assert_eq(
		Board.BUFFER_HEIGHT, Board.TOTAL_HEIGHT - Board.VISIBLE_HEIGHT, "Spawn Buffer は内部領域と表示領域の差"
	)
	assert_eq(Board.VISIBLE_TOP_Y, Board.BUFFER_HEIGHT, "表示領域は Buffer の直下から始まる")


# --- 初期化とクリア --------------------------------------------------------


func test_new_board_is_empty() -> void:
	for y in range(Board.TOTAL_HEIGHT):
		assert_true(board.is_row_empty(y), "初期化直後は y=%d が空" % y)


func test_clear_empties_every_cell() -> void:
	board.set_cell(0, 0, 3)
	board.set_cell(9, 39, 3)

	board.clear()

	assert_true(board.is_cell_empty(0, 0), "Buffer 最上段が空に戻る")
	assert_true(board.is_cell_empty(9, 39), "最下段が空に戻る")


# --- セルの取得・設定と範囲外 ----------------------------------------------


func test_set_and_get_cell() -> void:
	assert_true(board.set_cell(4, 25, 6), "範囲内への書き込みは成功する")
	assert_eq(board.get_cell(4, 25), 6, "書き込んだ値が読める")
	assert_false(board.is_cell_empty(4, 25), "書き込んだセルは空ではない")


func test_get_cell_outside_returns_empty_without_crashing() -> void:
	var outside: Array = [
		[-1, 0], [Board.WIDTH, 0], [0, -1], [0, Board.TOTAL_HEIGHT], [-5, -5], [999, 999]
	]
	for point in outside:
		var x: int = point[0]
		var y: int = point[1]
		assert_eq(board.get_cell(x, y), Board.EMPTY, "範囲外 (%d, %d) は EMPTY" % [x, y])
		assert_true(board.is_cell_empty(x, y), "範囲外 (%d, %d) は空扱い" % [x, y])


func test_set_cell_outside_is_rejected() -> void:
	assert_false(board.set_cell(-1, 0, 1), "左端の外は書き込めない")
	assert_false(board.set_cell(Board.WIDTH, 0, 1), "右端の外は書き込めない")
	assert_false(board.set_cell(0, -1, 1), "上端の外は書き込めない")
	assert_false(board.set_cell(0, Board.TOTAL_HEIGHT, 1), "下端の外は書き込めない")


func test_is_inside_boundaries() -> void:
	assert_true(board.is_inside(0, 0), "左上隅は内側")
	assert_true(board.is_inside(Board.WIDTH - 1, Board.TOTAL_HEIGHT - 1), "右下隅は内側")
	assert_false(board.is_inside(Board.WIDTH, Board.TOTAL_HEIGHT - 1), "右端の 1 つ外は外側")
	assert_false(board.is_inside(0, Board.TOTAL_HEIGHT), "下端の 1 つ外は外側")


# --- 内部領域と表示領域の境界 ----------------------------------------------


func test_visible_row_boundary() -> void:
	assert_false(board.is_visible_row(Board.VISIBLE_TOP_Y - 1), "Buffer 最下段は表示領域ではない")
	assert_true(board.is_visible_row(Board.VISIBLE_TOP_Y), "表示領域の先頭行は表示される")
	assert_true(board.is_visible_row(Board.TOTAL_HEIGHT - 1), "最下段は表示される")
	assert_false(board.is_visible_row(Board.TOTAL_HEIGHT), "内部領域の外は表示領域ではない")


func test_buffer_rows_are_not_visible() -> void:
	for y in range(Board.BUFFER_HEIGHT):
		assert_false(board.is_visible_row(y), "y=%d は Spawn Buffer なので表示されない" % y)


func test_cells_in_buffer_are_usable_but_not_visible() -> void:
	var buffer_y: int = Board.VISIBLE_TOP_Y - 1

	assert_true(board.set_cell(3, buffer_y, 2), "Buffer にも書き込める")
	assert_eq(board.get_cell(3, buffer_y), 2, "Buffer の値が読める")
	assert_false(board.is_visible_row(buffer_y), "ただし表示領域には含まれない")


func test_visible_to_strings_returns_only_visible_rows() -> void:
	board.set_cell(0, Board.VISIBLE_TOP_Y - 1, 1)
	board.set_cell(0, Board.VISIBLE_TOP_Y, 1)

	var visible: PackedStringArray = board.visible_to_strings()

	assert_eq(visible.size(), Board.VISIBLE_HEIGHT, "表示領域の行数だけ返る")
	assert_eq(visible[0], "#.........", "先頭行は表示領域の先頭（Buffer の行ではない）")


# --- 行の判定 --------------------------------------------------------------


func test_is_row_filled() -> void:
	var y: int = Board.TOTAL_HEIGHT - 1
	for x in range(Board.WIDTH - 1):
		board.set_cell(x, y, 1)
	assert_false(board.is_row_filled(y), "1 マス空いていれば埋まっていない")

	board.set_cell(Board.WIDTH - 1, y, 1)
	assert_true(board.is_row_filled(y), "全マス埋まれば埋まっている")


func test_row_checks_outside_do_not_crash() -> void:
	assert_false(board.is_row_filled(-1), "範囲外の行は埋まっていない扱い")
	assert_false(board.is_row_filled(Board.TOTAL_HEIGHT), "範囲外の行は埋まっていない扱い")
	assert_true(board.is_row_empty(-1), "範囲外の行は空扱い")
	assert_true(board.is_row_empty(Board.TOTAL_HEIGHT), "範囲外の行は空扱い")


func test_get_filled_rows_is_sorted_top_to_bottom() -> void:
	var bottom: int = Board.TOTAL_HEIGHT - 1
	_fill_row(bottom)
	_fill_row(bottom - 2)

	assert_eq(board.get_filled_rows(), [bottom - 2, bottom] as Array[int], "上から順に返る")


# --- 行削除と上詰め --------------------------------------------------------


func test_clear_rows_shifts_upper_rows_down() -> void:
	# 上から「残る行 / 消える行 / 残る行」を置き、真ん中だけ消す。
	var top_y: int = Board.TOTAL_HEIGHT - 3
	var before: PackedStringArray = PackedStringArray(["#.........", "##########", ".........#"])
	board.fill_from_strings(before, top_y)

	var removed: int = board.clear_rows([top_y + 1])

	assert_eq(removed, 1, "1 行削除された")
	assert_eq(
		board.to_strings(top_y, 3),
		PackedStringArray(["..........", "#.........", ".........#"]),
		"消えた行の上が 1 行分下がり、最上段が空になる"
	)


func test_clear_rows_accepts_unordered_duplicated_and_outside_values() -> void:
	var bottom: int = Board.TOTAL_HEIGHT - 1
	_fill_row(bottom)
	_fill_row(bottom - 1)

	var removed: int = board.clear_rows([bottom, bottom - 1, bottom, -1, Board.TOTAL_HEIGHT])

	assert_eq(removed, 2, "重複と範囲外は無視して 2 行だけ削除する")
	assert_true(board.is_row_empty(bottom), "削除後は空になる")


func test_clear_rows_with_no_valid_target_changes_nothing() -> void:
	var bottom: int = Board.TOTAL_HEIGHT - 1
	board.set_cell(0, bottom, 5)

	var removed: int = board.clear_rows([-1, Board.TOTAL_HEIGHT, 999])

	assert_eq(removed, 0, "削除対象がなければ 0")
	assert_eq(board.get_cell(0, bottom), 5, "盤面は変化しない")


func test_clear_filled_rows_removes_only_filled_rows() -> void:
	var bottom: int = Board.TOTAL_HEIGHT - 1
	_fill_row(bottom)
	board.set_cell(0, bottom - 1, 1)

	var cleared: Array[int] = board.clear_filled_rows()

	assert_eq(cleared, [bottom] as Array[int], "埋まっていた行だけ返る")
	assert_eq(board.get_cell(0, bottom), 1, "上にあった行が下がってくる")
	assert_true(board.is_row_empty(bottom - 1), "元の位置は空になる")


func test_clear_filled_rows_on_empty_board_returns_nothing() -> void:
	assert_eq(board.clear_filled_rows(), [] as Array[int], "空の盤面では何も消えない")


func test_clearing_four_rows_at_once() -> void:
	var bottom: int = Board.TOTAL_HEIGHT - 1
	for offset in range(4):
		_fill_row(bottom - offset)
	board.set_cell(2, bottom - 4, 7)

	var cleared: Array[int] = board.clear_filled_rows()

	assert_eq(cleared.size(), 4, "4 行同時に消える")
	assert_eq(board.get_cell(2, bottom), 7, "上の 1 行が 4 行分下がる")


# --- 文字列ヘルパー --------------------------------------------------------


func test_fill_from_strings_and_to_strings_round_trip() -> void:
	var rows: PackedStringArray = PackedStringArray(["#.#.#.#.#.", "..........", "##########"])
	var top_y: int = Board.VISIBLE_TOP_Y

	board.fill_from_strings(rows, top_y)

	assert_eq(board.to_strings(top_y, rows.size()), rows, "書いた形がそのまま読み出せる")


func test_fill_from_strings_ignores_cells_outside_the_board() -> void:
	board.fill_from_strings(PackedStringArray(["##############"]), Board.TOTAL_HEIGHT - 1)

	assert_true(board.is_row_filled(Board.TOTAL_HEIGHT - 1), "幅を超えた分は捨てて 1 行だけ埋まる")


# --- 決定論 ----------------------------------------------------------------


func test_same_operations_produce_same_board() -> void:
	var other: Board = Board.new()
	var operations: Array = [[0, 39, 1], [1, 39, 2], [5, 30, 3], [9, 20, 4]]

	for op in operations:
		board.set_cell(op[0], op[1], op[2])
		other.set_cell(op[0], op[1], op[2])

	assert_eq(
		board.to_strings(0, Board.TOTAL_HEIGHT),
		other.to_strings(0, Board.TOTAL_HEIGHT),
		"同じ操作列からは同じ盤面になる"
	)


func _fill_row(y: int) -> void:
	for x in range(Board.WIDTH):
		board.set_cell(x, y, 1)
