extends GutTest

## Board Evaluation の Unit テスト（要件定義 §68）。

var board: Board
var profile: CpuProfile
var evaluator: BoardEvaluator


func before_each() -> void:
	board = Board.new()
	profile = CpuProfile.create_default()
	evaluator = BoardEvaluator.new(profile)


func _fill_row_except(y: int, open_x: int, value: int = Piece.Type.I) -> void:
	for x in range(Board.WIDTH):
		if x != open_x:
			board.set_cell(x, y, value)


func _flat_stack(height: int) -> void:
	for offset in range(height):
		for x in range(Board.WIDTH):
			board.set_cell(x, Board.TOTAL_HEIGHT - 1 - offset, Piece.Type.I)


# --- 指標の測定 ------------------------------------------------------------


func test_empty_board_has_no_metrics() -> void:
	var metrics := BoardMetrics.new()

	metrics.measure(board)

	assert_eq(metrics.aggregate_height, 0, "高さ 0")
	assert_eq(metrics.max_height, 0, "最大高さ 0")
	assert_eq(metrics.holes, 0, "穴なし")
	assert_eq(metrics.bumpiness, 0, "凸凹なし")
	assert_eq(metrics.completed_lines, 0, "揃った行なし")


func test_holes_are_counted() -> void:
	board.set_cell(0, Board.TOTAL_HEIGHT - 3, Piece.Type.I)
	var metrics := BoardMetrics.new()

	metrics.measure(board)

	assert_eq(metrics.holes, 2, "ブロックの下の空きが穴になる")
	assert_eq(metrics.hole_depth, 3, "穴の深さも積み上がる")


func test_bumpiness_measures_the_surface() -> void:
	board.set_cell(0, Board.TOTAL_HEIGHT - 1, Piece.Type.I)
	board.set_cell(1, Board.TOTAL_HEIGHT - 5, Piece.Type.I)
	var metrics := BoardMetrics.new()

	metrics.measure(board)

	assert_gt(metrics.bumpiness, 0, "段差があれば凸凹が増える")


func test_completed_lines_are_counted() -> void:
	_flat_stack(2)
	var metrics := BoardMetrics.new()

	metrics.measure(board)

	assert_eq(metrics.completed_lines, 2, "揃った行を数える")


func test_heights_are_reported_per_column() -> void:
	board.set_cell(3, Board.TOTAL_HEIGHT - 4, Piece.Type.I)
	var metrics := BoardMetrics.new()

	metrics.measure(board)

	assert_eq(metrics.get_heights()[3], 4, "その列の高さ")
	assert_eq(metrics.get_heights()[0], 0, "何もない列は 0")
	assert_eq(metrics.max_height, 4, "一番高い列")


func test_measuring_twice_does_not_accumulate() -> void:
	board.set_cell(0, Board.TOTAL_HEIGHT - 3, Piece.Type.I)
	var metrics := BoardMetrics.new()

	metrics.measure(board)
	var first_holes: int = metrics.holes
	metrics.measure(board)

	assert_eq(metrics.holes, first_holes, "使い回しても値が積み上がらない")


# --- 評価値 ----------------------------------------------------------------


func test_holes_lower_the_score() -> void:
	var before: float = evaluator.evaluate(board)

	board.set_cell(0, Board.TOTAL_HEIGHT - 3, Piece.Type.I)
	var after: float = evaluator.evaluate(board)

	assert_lt(after, before, "穴が増えると評価が下がる")


func test_more_holes_lower_the_score_further() -> void:
	board.set_cell(0, Board.TOTAL_HEIGHT - 3, Piece.Type.I)
	var one_hole: float = evaluator.evaluate(board)

	board.set_cell(5, Board.TOTAL_HEIGHT - 3, Piece.Type.I)
	var two_holes: float = evaluator.evaluate(board)

	assert_lt(two_holes, one_hole, "穴が多いほど評価が下がる")


func test_flat_surface_scores_higher_than_a_jagged_one() -> void:
	var jagged := Board.new()
	for x in range(Board.WIDTH):
		var height: int = 6 if x % 2 == 0 else 1
		for offset in range(height):
			jagged.set_cell(x, Board.TOTAL_HEIGHT - 1 - offset, Piece.Type.I)

	var flat := Board.new()
	for x in range(Board.WIDTH):
		for offset in range(3):
			flat.set_cell(x, Board.TOTAL_HEIGHT - 1 - offset, Piece.Type.I)

	assert_gt(evaluator.evaluate(flat), evaluator.evaluate(jagged), "平坦な盤面が高評価")


func test_higher_stack_scores_lower() -> void:
	_flat_stack(2)
	var low: float = evaluator.evaluate(board)

	board.clear()
	_flat_stack(12)
	var high: float = evaluator.evaluate(board)

	assert_lt(high, low, "積み上がるほど評価が下がる")


func test_receiving_garbage_lowers_the_score() -> void:
	var before: float = evaluator.evaluate(board)

	GarbageQueue.push_lines(board, PackedInt32Array([3, 3, 3]))
	var after: float = evaluator.evaluate(board)

	assert_lt(after, before, "Garbage を受けると評価が下がる")


func test_blocked_garbage_lowers_the_score() -> void:
	GarbageQueue.push_lines(board, PackedInt32Array([3]))
	var accessible: float = evaluator.evaluate(board)

	# Garbage の穴の上に蓋をする。
	board.set_cell(3, Board.TOTAL_HEIGHT - 2, Piece.Type.T)
	var blocked: float = evaluator.evaluate(board)

	assert_lt(blocked, accessible, "穴が塞がれると掘り返しにくく、評価が下がる")


# --- 重みが分離されていること（#38 の完了条件） -----------------------------


func test_hole_avoidance_axis_changes_only_hole_related_terms() -> void:
	board.set_cell(0, Board.TOTAL_HEIGHT - 3, Piece.Type.I)
	var baseline: float = evaluator.evaluate(board)

	profile.hole_avoidance = 2.0
	var stricter: float = evaluator.evaluate(board)

	assert_lt(stricter, baseline, "穴に厳しい Profile では評価が下がる")


func test_surface_management_axis_is_separate() -> void:
	board.set_cell(0, Board.TOTAL_HEIGHT - 1, Piece.Type.I)
	board.set_cell(9, Board.TOTAL_HEIGHT - 6, Piece.Type.I)
	var baseline: float = evaluator.evaluate(board)

	profile.surface_management = 2.0
	var stricter: float = evaluator.evaluate(board)

	assert_lt(stricter, baseline, "表面に厳しい Profile では評価が下がる")


func test_garbage_management_axis_is_separate() -> void:
	GarbageQueue.push_lines(board, PackedInt32Array([3]))
	board.set_cell(3, Board.TOTAL_HEIGHT - 2, Piece.Type.T)
	var baseline: float = evaluator.evaluate(board)

	profile.garbage_management = 2.0
	var stricter: float = evaluator.evaluate(board)

	assert_lt(stricter, baseline, "Garbage に厳しい Profile では評価が下がる")


func test_recovery_ability_axis_is_separate() -> void:
	_flat_stack(14)
	var baseline: float = evaluator.evaluate(board)

	profile.recovery_ability = 2.0
	var stricter: float = evaluator.evaluate(board)

	assert_lt(stricter, baseline, "高さに厳しい Profile では評価が下がる")


func test_axes_do_not_affect_completed_lines() -> void:
	# 揃った行の価値はどの軸にも掛からない。それだけを見るため、他の重みを 0 にする。
	profile.weight_aggregate_height = 0.0
	profile.weight_max_height = 0.0
	profile.weight_holes = 0.0
	profile.weight_hole_depth = 0.0
	profile.weight_bumpiness = 0.0
	profile.weight_wells = 0.0
	profile.weight_row_transitions = 0.0
	profile.weight_column_transitions = 0.0
	profile.weight_blocked_garbage = 0.0
	profile.weight_danger = 0.0
	_flat_stack(1)
	var baseline: float = evaluator.evaluate(board)
	assert_almost_eq(baseline, profile.weight_completed_lines, 0.0001, "前提: 揃った行の分だけ")

	profile.hole_avoidance = 3.0
	profile.surface_management = 3.0
	profile.garbage_management = 3.0
	profile.recovery_ability = 3.0

	assert_almost_eq(evaluator.evaluate(board), baseline, 0.0001, "揃った行の価値は軸に依らない")


func test_weights_are_data_driven() -> void:
	board.set_cell(0, Board.TOTAL_HEIGHT - 3, Piece.Type.I)
	var baseline: float = evaluator.evaluate(board)

	profile.weight_holes = 0.0
	profile.weight_hole_depth = 0.0

	assert_gt(evaluator.evaluate(board), baseline, "重みを 0 にすると穴が効かなくなる")


func test_profile_can_be_replaced() -> void:
	var other := CpuProfile.create_default()
	other.weight_holes = 0.0

	evaluator.set_profile(other)

	assert_eq(evaluator.get_profile(), other, "差し替えられる")


# --- 決定論 ----------------------------------------------------------------


func test_same_board_always_scores_the_same() -> void:
	board.set_cell(0, Board.TOTAL_HEIGHT - 3, Piece.Type.I)
	GarbageQueue.push_lines(board, PackedInt32Array([5, 5]))

	var first: float = evaluator.evaluate(board)
	for _attempt in range(10):
		assert_eq(evaluator.evaluate(board), first, "何度測っても同じ評価値")

	assert_eq(BoardEvaluator.new(profile).evaluate(board), first, "別のインスタンスでも同じ")
