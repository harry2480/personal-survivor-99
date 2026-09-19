extends GutTest

## Hold 枠の Unit テスト（要件定義 §24）。

var hold: HoldSlot


func before_each() -> void:
	hold = HoldSlot.new()


func test_starts_empty_and_usable() -> void:
	assert_true(hold.is_empty(), "最初は空")
	assert_eq(hold.get_held_type(), HoldSlot.EMPTY, "中身はない")
	assert_true(hold.can_hold(), "最初から使える")


func test_first_hold_stores_the_piece_and_returns_empty() -> void:
	var released: int = hold.swap(Piece.Type.T)

	assert_eq(released, HoldSlot.EMPTY, "空だったので出す Piece はない")
	assert_eq(hold.get_held_type(), Piece.Type.T as int, "預かった")
	assert_false(hold.is_empty(), "空ではなくなる")


func test_second_hold_swaps_the_pieces() -> void:
	hold.swap(Piece.Type.T)
	hold.on_piece_locked()

	var released: int = hold.swap(Piece.Type.I)

	assert_eq(released, Piece.Type.T as int, "預けていた Piece が出てくる")
	assert_eq(hold.get_held_type(), Piece.Type.I as int, "新しい Piece を預かる")


func test_hold_can_be_used_only_once_per_piece() -> void:
	hold.swap(Piece.Type.T)

	assert_false(hold.can_hold(), "同じ Piece の操作中は再使用できない")
	assert_eq(hold.swap(Piece.Type.I), HoldSlot.EMPTY, "2 回目は何も返さない")
	assert_eq(hold.get_held_type(), Piece.Type.T as int, "中身も入れ替わらない")


func test_hold_becomes_available_after_lock() -> void:
	hold.swap(Piece.Type.T)

	hold.on_piece_locked()

	assert_true(hold.can_hold(), "Lock 後に再使用できる")


func test_lock_does_not_empty_the_slot() -> void:
	hold.swap(Piece.Type.T)

	hold.on_piece_locked()

	assert_eq(hold.get_held_type(), Piece.Type.T as int, "Lock しても預けた Piece は残る")


func test_clear_resets_everything() -> void:
	hold.swap(Piece.Type.T)

	hold.clear()

	assert_true(hold.is_empty(), "中身が消える")
	assert_true(hold.can_hold(), "使用状態も戻る")


func test_repeated_hold_and_lock_keeps_swapping() -> void:
	var order: Array[int] = [Piece.Type.T, Piece.Type.I, Piece.Type.O, Piece.Type.S]
	var released: Array[int] = []

	for type in order:
		released.append(hold.swap(type))
		hold.on_piece_locked()

	assert_eq(
		released,
		[HoldSlot.EMPTY, Piece.Type.T, Piece.Type.I, Piece.Type.O] as Array[int],
		"1 つずつ遅れて出てくる"
	)
	assert_eq(hold.get_held_type(), Piece.Type.S as int, "最後の Piece が残る")
