extends GutTest

## 7-Bag Randomizer の Unit テスト。Seed を固定して再現性を確かめる。

const SEED_A: int = 20260919
const SEED_B: int = 987654321


func _draw(randomizer: PieceRandomizer, count: int) -> Array[int]:
	var drawn: Array[int] = []
	for _i in range(count):
		drawn.append(randomizer.next())
	return drawn


func _sorted(values: Array[int]) -> Array[int]:
	var copy: Array[int] = values.duplicate()
	copy.sort()
	return copy


# --- Bag の性質 ------------------------------------------------------------


func test_one_bag_contains_each_type_exactly_once() -> void:
	var randomizer := PieceRandomizer.new(SEED_A)

	var bag: Array[int] = _draw(randomizer, Piece.TYPE_COUNT)

	assert_eq(_sorted(bag), Piece.get_all_types(), "1 Bag に 7 種が 1 個ずつ入る")


func test_every_bag_contains_each_type_exactly_once() -> void:
	var randomizer := PieceRandomizer.new(SEED_A)

	for bag_index in range(20):
		var bag: Array[int] = _draw(randomizer, Piece.TYPE_COUNT)
		assert_eq(_sorted(bag), Piece.get_all_types(), "%d 番目の Bag にも 7 種が 1 個ずつ" % bag_index)


func test_bag_is_shuffled() -> void:
	# Seed を変えても常に定義順のままなら Shuffle が効いていない。
	var shuffled_count: int = 0
	for offset in range(30):
		var randomizer := PieceRandomizer.new(SEED_A + offset)
		if _draw(randomizer, Piece.TYPE_COUNT) != Piece.get_all_types():
			shuffled_count += 1

	assert_gt(shuffled_count, 25, "ほとんどの Seed で定義順とは異なる並びになる")


func test_remaining_in_bag_decreases_and_refills() -> void:
	var randomizer := PieceRandomizer.new(SEED_A)
	assert_eq(randomizer.get_remaining_in_bag(), 0, "払い出す前は空")

	randomizer.next()
	assert_eq(randomizer.get_remaining_in_bag(), Piece.TYPE_COUNT - 1, "1 個払い出すと 6 個残る")

	_draw(randomizer, Piece.TYPE_COUNT - 1)
	assert_eq(randomizer.get_remaining_in_bag(), 0, "Bag を使い切ると 0 になる")

	randomizer.next()
	assert_eq(randomizer.get_remaining_in_bag(), Piece.TYPE_COUNT - 1, "次の Bag が補充される")


# --- Seed と再現性 ---------------------------------------------------------


func test_same_seed_produces_same_sequence() -> void:
	var first := PieceRandomizer.new(SEED_A)
	var second := PieceRandomizer.new(SEED_A)

	assert_eq(_draw(first, 70), _draw(second, 70), "同じ Seed からは同じ列が出る")


func test_different_seed_produces_different_sequence() -> void:
	var first := PieceRandomizer.new(SEED_A)
	var second := PieceRandomizer.new(SEED_B)

	assert_ne(_draw(first, 70), _draw(second, 70), "Seed が違えば列も変わる")


func test_reset_restores_the_sequence() -> void:
	var randomizer := PieceRandomizer.new(SEED_A)
	var expected: Array[int] = _draw(randomizer, 21)

	randomizer.reset(SEED_A)

	assert_eq(_draw(randomizer, 21), expected, "同じ Seed で reset すると最初から同じ列になる")
	assert_eq(randomizer.get_seed(), SEED_A, "Seed を取得できる")


func test_reset_discards_the_current_bag() -> void:
	var randomizer := PieceRandomizer.new(SEED_A)
	randomizer.next()

	randomizer.reset(SEED_A)

	assert_eq(randomizer.get_remaining_in_bag(), 0, "reset で Bag の残りを捨てる")


func test_sequence_does_not_depend_on_global_random_state() -> void:
	# グローバル乱数を進めても払い出しが変わらないこと（要件定義 §110）。
	seed(1)
	randi()
	var first := PieceRandomizer.new(SEED_A)
	var first_sequence: Array[int] = _draw(first, 35)

	seed(999999)
	for _i in range(100):
		randi()
	var second := PieceRandomizer.new(SEED_A)

	assert_eq(_draw(second, 35), first_sequence, "グローバル乱数の状態に影響されない")


func test_two_randomizers_do_not_share_state() -> void:
	var first := PieceRandomizer.new(SEED_A)
	var second := PieceRandomizer.new(SEED_A)

	_draw(first, 13)

	assert_eq(_draw(second, 7), _draw(PieceRandomizer.new(SEED_A), 7), "他方の消費に影響されない")


# --- 先読み ----------------------------------------------------------------


func test_peek_matches_the_following_draws() -> void:
	var randomizer := PieceRandomizer.new(SEED_A)

	var peeked: Array[int] = randomizer.peek(10)

	assert_eq(peeked.size(), 10, "要求した数だけ先読みできる")
	assert_eq(_draw(randomizer, 10), peeked, "先読みした内容がそのまま払い出される")


func test_peek_does_not_consume() -> void:
	var randomizer := PieceRandomizer.new(SEED_A)

	randomizer.peek(5)

	assert_eq(randomizer.get_remaining_in_bag(), Piece.TYPE_COUNT, "先読みでは払い出さない")


func test_peek_across_bag_boundary() -> void:
	var randomizer := PieceRandomizer.new(SEED_A)

	var peeked: Array[int] = randomizer.peek(Piece.TYPE_COUNT * 3)

	assert_eq(peeked.size(), Piece.TYPE_COUNT * 3, "Bag をまたいで先読みできる")
	assert_eq(_draw(randomizer, Piece.TYPE_COUNT * 3), peeked, "またいだ先も順序が一致する")
