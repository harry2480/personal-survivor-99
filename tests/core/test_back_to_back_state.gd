extends GutTest

## Back-to-Back の Unit テスト（要件定義 §35）。

var balance: GameBalance
var b2b: BackToBackState


func before_each() -> void:
	balance = GameBalance.create_default()
	b2b = BackToBackState.new(balance)


func test_starts_inactive() -> void:
	assert_eq(b2b.get_chain(), 0, "最初は 0")
	assert_false(b2b.is_active(), "効果は乗らない")


func test_target_clear_extends_the_chain() -> void:
	b2b.on_piece_locked(LineClear.Type.QUAD, 4)
	assert_eq(b2b.get_chain(), 1, "1 回目")
	assert_false(b2b.is_active(), "1 回目では効果が乗らない")

	b2b.on_piece_locked(LineClear.Type.QUAD, 4)
	assert_eq(b2b.get_chain(), 2, "2 回目")
	assert_true(b2b.is_active(), "2 回目から効果が乗る")


func test_non_target_clear_breaks_the_chain() -> void:
	b2b.on_piece_locked(LineClear.Type.QUAD, 4)
	b2b.on_piece_locked(LineClear.Type.QUAD, 4)
	assert_true(b2b.is_active(), "前提: 継続している")

	b2b.on_piece_locked(LineClear.Type.SINGLE, 1)

	assert_eq(b2b.get_chain(), 0, "対象外の Clear で途切れる")
	assert_false(b2b.is_active(), "効果が切れる")


func test_lock_without_clear_keeps_the_chain() -> void:
	# Combo との違い。Line Clear なしの Lock では B2B は途切れない（§35）。
	b2b.on_piece_locked(LineClear.Type.QUAD, 4)
	b2b.on_piece_locked(LineClear.Type.QUAD, 4)

	b2b.on_piece_locked(LineClear.Type.NONE, 0)

	assert_eq(b2b.get_chain(), 2, "維持される")
	assert_true(b2b.is_active(), "効果も維持される")


func test_target_types_come_from_the_balance_data() -> void:
	balance.b2b_clear_types = [LineClear.Type.TRIPLE]

	b2b.on_piece_locked(LineClear.Type.TRIPLE, 3)
	assert_eq(b2b.get_chain(), 1, "設定した種別が対象になる")

	b2b.on_piece_locked(LineClear.Type.QUAD, 4)
	assert_eq(b2b.get_chain(), 0, "設定から外れた種別は対象外")


func test_t_spin_can_be_included() -> void:
	# T-Spin 判定そのものは #29。ここでは対象に含める設定だけを見る。
	b2b.on_piece_locked(LineClear.Type.SINGLE, 1, true)

	assert_eq(b2b.get_chain(), 1, "T-Spin は対象に含まれる")


func test_t_spin_can_be_excluded() -> void:
	balance.b2b_includes_t_spin = false

	b2b.on_piece_locked(LineClear.Type.SINGLE, 1, true)

	assert_eq(b2b.get_chain(), 0, "設定で外せる")


func test_best_chain_is_kept() -> void:
	for _i in range(4):
		b2b.on_piece_locked(LineClear.Type.QUAD, 4)
	b2b.on_piece_locked(LineClear.Type.SINGLE, 1)

	assert_eq(b2b.get_best_chain(), 4, "最長の鎖を覚えている")
	assert_eq(b2b.get_chain(), 0, "現在の鎖とは別")


func test_reset_clears_everything() -> void:
	b2b.on_piece_locked(LineClear.Type.QUAD, 4)

	b2b.reset()

	assert_eq(b2b.get_chain(), 0, "鎖が消える")
	assert_eq(b2b.get_best_chain(), 0, "最長も消える")
