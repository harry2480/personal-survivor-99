extends GutTest

## バランスデータの Unit テスト（要件定義 §39）。

var balance: GameBalance


func before_each() -> void:
	balance = GameBalance.create_default()


func test_default_b2b_targets_quad() -> void:
	assert_true(balance.is_b2b_clear(LineClear.Type.QUAD), "既定では Quad が対象")
	assert_false(balance.is_b2b_clear(LineClear.Type.SINGLE), "Single は対象外")
	assert_false(balance.is_b2b_clear(LineClear.Type.DOUBLE), "Double は対象外")
	assert_false(balance.is_b2b_clear(LineClear.Type.TRIPLE), "Triple は対象外")


func test_no_clear_is_never_a_b2b_target() -> void:
	assert_false(balance.is_b2b_clear(LineClear.Type.NONE), "Clear していなければ対象外")
	assert_false(balance.is_b2b_clear(LineClear.Type.NONE, true), "T-Spin でも Clear なしは対象外")


func test_b2b_targets_are_data_driven() -> void:
	balance.b2b_clear_types = [LineClear.Type.DOUBLE, LineClear.Type.TRIPLE]

	assert_true(balance.is_b2b_clear(LineClear.Type.DOUBLE), "設定した種別が対象になる")
	assert_false(balance.is_b2b_clear(LineClear.Type.QUAD), "設定から外れた種別は対象外")


func test_combo_table_is_data_driven() -> void:
	balance.combo_attack_table = PackedInt32Array([0, 5, 10])

	assert_eq(balance.get_combo_attack(1), 0, "1 連目")
	assert_eq(balance.get_combo_attack(2), 5, "2 連目")
	assert_eq(balance.get_combo_attack(3), 10, "3 連目")


func test_combo_beyond_the_table_uses_the_last_value() -> void:
	balance.combo_attack_table = PackedInt32Array([0, 5, 10])

	assert_eq(balance.get_combo_attack(99), 10, "表を超えたら最後の値")


func test_combo_zero_or_negative_gives_nothing() -> void:
	assert_eq(balance.get_combo_attack(0), 0, "Combo していなければ 0")
	assert_eq(balance.get_combo_attack(-1), 0, "負の値でも 0")


func test_empty_combo_table_gives_nothing() -> void:
	balance.combo_attack_table = PackedInt32Array()

	assert_eq(balance.get_combo_attack(5), 0, "表が空なら 0")
