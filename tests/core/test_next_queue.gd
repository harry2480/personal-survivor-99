extends GutTest

## NEXT Queue の Unit テスト（要件定義 §23）。

const SEED: int = 20260920

var queue: NextQueue


func before_each() -> void:
	queue = NextQueue.new(PieceRandomizer.new(SEED))


func test_keeps_more_than_the_visible_count() -> void:
	assert_gt(queue.get_capacity(), NextQueue.MINIMUM_VISIBLE, "内部は表示分より多く持つ")
	assert_eq(queue.size(), queue.get_capacity(), "最初から満たされている")


func test_peek_returns_at_least_five() -> void:
	var visible: Array[int] = queue.peek()

	assert_eq(visible.size(), NextQueue.MINIMUM_VISIBLE, "既定で 5 個返る")


func test_peek_does_not_consume() -> void:
	var before: Array[int] = queue.peek(5)

	assert_eq(queue.peek(5), before, "覗いても中身は変わらない")
	assert_eq(queue.size(), queue.get_capacity(), "個数も変わらない")


func test_pop_returns_the_front_and_refills() -> void:
	var expected: Array[int] = queue.peek(2)

	var popped: int = queue.pop()

	assert_eq(popped, expected[0], "先頭が出てくる")
	assert_eq(queue.peek(1)[0], expected[1], "次が先頭になる")
	assert_eq(queue.size(), queue.get_capacity(), "取り出した分は補充される")


func test_peek_beyond_capacity_extends_the_queue() -> void:
	var many: Array[int] = queue.peek(20)

	assert_eq(many.size(), 20, "容量を超えても先読みできる")
	assert_eq(queue.peek(20), many, "2 回目も同じ並び")


func test_sequence_matches_the_randomizer_order() -> void:
	var reference := PieceRandomizer.new(SEED)
	var expected: Array[int] = []
	for _i in range(20):
		expected.append(reference.next())

	var actual: Array[int] = []
	for _i in range(20):
		actual.append(queue.pop())

	assert_eq(actual, expected, "Randomizer の並びがそのまま出てくる")


func test_same_seed_produces_the_same_queue() -> void:
	var other := NextQueue.new(PieceRandomizer.new(SEED))

	assert_eq(queue.peek(15), other.peek(15), "同じ Seed からは同じ並び")


func test_reset_restarts_the_sequence() -> void:
	var expected: Array[int] = queue.peek(10)
	queue.pop()
	queue.pop()

	queue.reset(SEED)

	assert_eq(queue.peek(10), expected, "同じ Seed で作り直すと最初から同じ並び")


func test_capacity_is_never_below_the_visible_count() -> void:
	var small := NextQueue.new(PieceRandomizer.new(SEED), 1)

	assert_eq(small.get_capacity(), NextQueue.MINIMUM_VISIBLE, "表示分は必ず確保する")
