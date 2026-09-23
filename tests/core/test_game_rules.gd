extends GutTest

## [GameRules] のユーザー設定反映（要件定義 §97）。


func test_soft_drop_multiplier_below_one_is_rejected() -> void:
	# 1.0 未満だと Soft Drop で通常落下より遅くなる（要件定義 §27）。
	var rules := GameRules.create_default()
	var before: float = rules.soft_drop_multiplier

	var applied: int = rules.apply_user_settings({"soft_drop_multiplier": 0.5})

	assert_eq(applied, 0, "採用されない")
	assert_eq(rules.soft_drop_multiplier, before, "既定値のまま")


func test_soft_drop_multiplier_of_one_is_accepted() -> void:
	var rules := GameRules.create_default()

	var applied: int = rules.apply_user_settings({"soft_drop_multiplier": 1.0})

	assert_eq(applied, 1, "下限ちょうどは採用する")
	assert_eq(rules.soft_drop_multiplier, 1.0, "設定が反映される")


func test_soft_drop_speed_is_not_slower_than_gravity() -> void:
	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 2.0

	rules.apply_user_settings({"soft_drop_multiplier": 0.25})

	assert_gte(rules.get_soft_drop_speed(), rules.gravity_cells_per_second, "Soft Drop は遅くならない")
