extends GutTest

## Attack Calculator の Unit テスト（要件定義 §38）。
##
## 実装計画 Phase 2 の完了条件「主要 Pattern の Attack を自動 Test 可能」を満たす。

var balance: GameBalance
var calculator: AttackCalculator


func before_each() -> void:
	balance = GameBalance.create_default()
	calculator = AttackCalculator.new(balance)


func _context(
	clear_type: LineClear.Type,
	line_count: int,
	t_spin: TSpinDetector.Result = TSpinDetector.Result.NONE,
	combo: int = 1,
	b2b: bool = false,
	perfect: bool = false
) -> AttackContext:
	var context := AttackContext.new()
	context.clear_type = clear_type
	context.line_count = line_count
	context.t_spin = t_spin
	context.combo_count = combo
	context.b2b_active = b2b
	context.perfect_clear = perfect
	return context


# --- 基本の Clear ----------------------------------------------------------


func test_no_clear_produces_no_attack() -> void:
	assert_eq(calculator.calculate(_context(LineClear.Type.NONE, 0)), 0, "消えていなければ 0")


func test_null_context_is_safe() -> void:
	assert_eq(calculator.calculate(null), 0, "null でも落ちない")


func test_line_clear_attacks() -> void:
	var expected: Dictionary = {
		LineClear.Type.SINGLE: 0,
		LineClear.Type.DOUBLE: 1,
		LineClear.Type.TRIPLE: 2,
		LineClear.Type.QUAD: 4,
	}
	for clear_type in expected:
		var attack: int = calculator.calculate(_context(clear_type, int(clear_type)))
		assert_eq(attack, expected[clear_type], "%s の Attack" % LineClear.get_type_name(clear_type))


# --- T-Spin ----------------------------------------------------------------


func test_t_spin_attacks() -> void:
	var expected: Dictionary = {
		LineClear.Type.SINGLE: 2,
		LineClear.Type.DOUBLE: 4,
		LineClear.Type.TRIPLE: 6,
	}
	for clear_type in expected:
		var attack: int = calculator.calculate(
			_context(clear_type, int(clear_type), TSpinDetector.Result.FULL)
		)
		assert_eq(
			attack, expected[clear_type], "T-Spin %s の Attack" % LineClear.get_type_name(clear_type)
		)


func test_t_spin_mini_uses_its_own_table() -> void:
	var full: int = calculator.calculate(
		_context(LineClear.Type.SINGLE, 1, TSpinDetector.Result.FULL)
	)
	var mini: int = calculator.calculate(
		_context(LineClear.Type.SINGLE, 1, TSpinDetector.Result.MINI)
	)

	assert_gt(full, mini, "Mini は通常の T-Spin より弱い")
	assert_eq(mini, 0, "既定の Mini Single は 0")


# --- Combo -----------------------------------------------------------------


func test_combo_adds_attack_by_stage() -> void:
	var previous: int = -1
	for combo in range(1, 12):
		var attack: int = calculator.calculate(
			_context(LineClear.Type.SINGLE, 1, TSpinDetector.Result.NONE, combo)
		)
		assert_true(attack >= previous, "Combo が進むほど下がらない（combo=%d）" % combo)
		previous = attack

	assert_gt(
		calculator.calculate(_context(LineClear.Type.SINGLE, 1, TSpinDetector.Result.NONE, 5)),
		calculator.calculate(_context(LineClear.Type.SINGLE, 1, TSpinDetector.Result.NONE, 1)),
		"5 連は 1 連より強い"
	)


func test_combo_beyond_the_table_stops_growing() -> void:
	var at_table_end: int = calculator.calculate(
		_context(
			LineClear.Type.SINGLE, 1, TSpinDetector.Result.NONE, balance.combo_attack_table.size()
		)
	)
	var far_beyond: int = calculator.calculate(
		_context(LineClear.Type.SINGLE, 1, TSpinDetector.Result.NONE, 999)
	)

	assert_eq(far_beyond, at_table_end, "表を超えたら頭打ちになる")


# --- Back-to-Back ----------------------------------------------------------


func test_b2b_adds_a_bonus() -> void:
	var without: int = calculator.calculate(_context(LineClear.Type.QUAD, 4))
	var with_b2b: int = calculator.calculate(
		_context(LineClear.Type.QUAD, 4, TSpinDetector.Result.NONE, 1, true)
	)

	assert_eq(with_b2b - without, balance.b2b_bonus, "設定した B2B ボーナスが乗る")


# --- Perfect Clear ---------------------------------------------------------


func test_perfect_clear_replaces_the_attack_by_default() -> void:
	var normal: int = calculator.calculate(_context(LineClear.Type.SINGLE, 1))
	var perfect: int = calculator.calculate(
		_context(LineClear.Type.SINGLE, 1, TSpinDetector.Result.NONE, 1, false, true)
	)

	assert_eq(perfect, balance.perfect_clear_attack_table[LineClear.Type.SINGLE], "置き換わる")
	assert_gt(perfect, normal, "通常より強い")


func test_perfect_clear_can_be_additive() -> void:
	balance.perfect_clear_replaces_attack = false
	var normal: int = calculator.calculate(_context(LineClear.Type.QUAD, 4))

	var perfect: int = calculator.calculate(
		_context(LineClear.Type.QUAD, 4, TSpinDetector.Result.NONE, 1, false, true)
	)

	assert_eq(
		perfect, normal + balance.perfect_clear_attack_table[LineClear.Type.QUAD], "設定で加算に切り替えられる"
	)


# --- 数値が外部設定であること ----------------------------------------------


func test_every_value_comes_from_the_balance_data() -> void:
	balance.line_attack_table = PackedInt32Array([0, 100, 200, 300, 400])
	balance.b2b_bonus = 50
	balance.combo_attack_table = PackedInt32Array([0, 7])

	var attack: int = calculator.calculate(
		_context(LineClear.Type.DOUBLE, 2, TSpinDetector.Result.NONE, 2, true)
	)

	assert_eq(attack, 200 + 50 + 7, "すべて設定値から組み立てられる")


func test_explain_breaks_down_the_calculation() -> void:
	var breakdown: Dictionary = calculator.explain(
		_context(LineClear.Type.QUAD, 4, TSpinDetector.Result.NONE, 3, true)
	)

	assert_eq(breakdown["base"], 4, "Base")
	assert_eq(breakdown["b2b"], balance.b2b_bonus, "B2B")
	assert_eq(breakdown["combo"], balance.get_combo_attack(3), "Combo")
	assert_eq(
		breakdown["total"], breakdown["base"] + breakdown["b2b"] + breakdown["combo"], "合計が一致"
	)


# --- Multiplier / Multiple Attackers ---------------------------------------


func test_multiplier_scales_the_attack() -> void:
	assert_eq(AttackCalculator.apply_multipliers(10, 2.0), 20, "2 倍")
	assert_eq(AttackCalculator.apply_multipliers(10, 1.0), 10, "等倍")
	assert_eq(AttackCalculator.apply_multipliers(10, 0.5), 5, "0.5 倍")


func test_multiplier_truncates_and_never_goes_negative() -> void:
	assert_eq(AttackCalculator.apply_multipliers(3, 1.5), 4, "小数は切り捨て")
	assert_eq(AttackCalculator.apply_multipliers(10, -1.0), 0, "負の倍率は 0 扱い")
	assert_eq(AttackCalculator.apply_multipliers(0, 5.0), 0, "元が 0 なら 0")


func test_multiple_attackers_bonus_is_added() -> void:
	assert_eq(AttackCalculator.apply_multipliers(10, 1.0, 3), 13, "人数補正が加算される")
	assert_eq(AttackCalculator.apply_multipliers(1, 1.0, -5), 0, "下限は 0")
