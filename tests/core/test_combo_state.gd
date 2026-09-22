extends GutTest

## Combo の Unit テスト（要件定義 §34）。

var combo: ComboState


func before_each() -> void:
	combo = ComboState.new()


func test_starts_at_zero() -> void:
	assert_eq(combo.get_count(), 0, "最初は 0")
	assert_false(combo.is_active(), "Combo していない")


func test_clear_increments_the_count() -> void:
	combo.on_piece_locked(1)

	assert_eq(combo.get_count(), 1, "1 回目の Clear")
	assert_false(combo.is_active(), "1 回では Combo ではない")


func test_consecutive_clears_continue_the_combo() -> void:
	for expected in range(1, 6):
		combo.on_piece_locked(2)
		assert_eq(combo.get_count(), expected, "%d 連続" % expected)

	assert_true(combo.is_active(), "2 連以上で Combo 中")


func test_lock_without_clear_ends_the_combo() -> void:
	combo.on_piece_locked(1)
	combo.on_piece_locked(1)
	assert_eq(combo.get_count(), 2, "前提: 2 連続している")

	combo.on_piece_locked(0)

	assert_eq(combo.get_count(), 0, "Line Clear なしの Lock で終了する")
	assert_false(combo.is_active(), "Combo が切れる")


func test_combo_restarts_after_ending() -> void:
	combo.on_piece_locked(1)
	combo.on_piece_locked(0)

	combo.on_piece_locked(1)

	assert_eq(combo.get_count(), 1, "また 1 から数え直す")


func test_line_count_does_not_affect_the_increment() -> void:
	combo.on_piece_locked(4)
	combo.on_piece_locked(1)

	assert_eq(combo.get_count(), 2, "消した行数ではなく回数で数える")


func test_best_count_is_kept() -> void:
	for _i in range(5):
		combo.on_piece_locked(1)
	combo.on_piece_locked(0)
	combo.on_piece_locked(1)

	assert_eq(combo.get_best_count(), 5, "最大 Combo を覚えている")
	assert_eq(combo.get_count(), 1, "現在の Combo とは別")


func test_reset_clears_everything() -> void:
	for _i in range(3):
		combo.on_piece_locked(1)

	combo.reset()

	assert_eq(combo.get_count(), 0, "現在の Combo が消える")
	assert_eq(combo.get_best_count(), 0, "最大 Combo も消える")
