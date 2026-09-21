extends GutTest

## CPU 難易度 UI の確認（要件定義 §77 / §79）。
##
## 「通常は Strength だけ指定すれば済み、Advanced を開いたときだけ §61 の
## 各パラメータが出る」ことと、**標準最高難易度を超える CPU を UI から
## 設定できる**こと（MVP 受入条件 24）を見る。

const PANEL := preload("res://ui/menu/cpu_difficulty_panel.tscn")

var panel: CpuDifficultyPanel
var changes: Array = []


func before_each() -> void:
	panel = PANEL.instantiate()
	add_child_autofree(panel)
	changes = []
	panel.settings_changed.connect(func(settings: CpuSettings) -> void: changes.append(settings))


func _preset_names() -> Array:
	var names: Array = []
	for preset in panel.get_preset_items():
		names.append(CpuPreset.get_preset_name(preset))
	return names


func _select_preset(preset: CpuPreset.Preset) -> void:
	assert_true(panel.choose_preset(preset), "%s を選べる" % CpuPreset.get_preset_name(preset))


# --- Difficulty UI（要件定義 §79） ------------------------------------------


func test_preset_list_matches_the_requirement() -> void:
	assert_eq(
		_preset_names(),
		["EASY", "NORMAL", "HARD", "VERY_HARD", "EXTREME", "CUSTOM"],
		"通常は Easy / Normal / Hard / Very Hard / Extreme / Custom"
	)


func test_machine_appears_only_in_developer_mode() -> void:
	assert_false("MACHINE" in _preset_names(), "通常 UI に Machine は出さない（§71）")

	panel.set_developer_mode(true)

	assert_true("MACHINE" in _preset_names(), "Developer Mode では Machine を選べる")
	assert_true("HUMAN_LIKE" in _preset_names(), "Human-like も選べる（§72）")


func test_selecting_a_preset_sets_the_strength() -> void:
	_select_preset(CpuPreset.Preset.HARD)

	assert_eq(panel.get_settings().preset, CpuPreset.Preset.HARD, "Preset が変わる")
	assert_eq(
		panel.get_settings().strength,
		CpuPreset.get_strength(CpuPreset.Preset.HARD),
		"Strength も Preset の値になる"
	)
	assert_eq(changes.size(), 1, "設定が変わったことを 1 回通知する")


func test_custom_controls_appear_only_for_custom() -> void:
	_select_preset(CpuPreset.Preset.NORMAL)
	assert_false(panel.is_custom_section_visible(), "Preset を選ぶだけなら Strength 欄は出さない")

	_select_preset(CpuPreset.Preset.CUSTOM)
	assert_true(panel.is_custom_section_visible(), "Custom では Strength / Min / Max / Variation を出す")


func test_custom_sets_strength_and_distribution() -> void:
	_select_preset(CpuPreset.Preset.CUSTOM)

	panel.set_strength_value(85.0)
	panel.set_distribution_values(60.0, 110.0, 15.0)

	# 要件定義 §79 の Custom の例（Strength 85 / Min 60 / Max 110 / Variation 15）。
	var settings: CpuSettings = panel.get_settings()
	assert_eq(settings.strength, 85.0, "Strength")
	assert_eq(settings.distribution.minimum_strength, 60.0, "Min Strength")
	assert_eq(settings.distribution.maximum_strength, 110.0, "Max Strength")
	assert_eq(settings.distribution.strength_variance, 15.0, "Variation")


# --- Advanced Settings（要件定義 §78） --------------------------------------


func test_advanced_is_hidden_by_default() -> void:
	assert_false(panel.is_advanced_open(), "通常時は Advanced を隠す")
	assert_false(panel.get_settings().advanced_enabled, "既定では個別調整を使わない")


func test_advanced_exposes_every_parameter() -> void:
	panel.set_advanced_open(true)

	assert_true(panel.is_advanced_open(), "展開すると出てくる")
	for key in CpuSettings.ADVANCED_KEYS:
		assert_true(panel.has_advanced_control(key), "%s を個別に編集できる（§61）" % key)


func test_advanced_overrides_reach_the_profile() -> void:
	panel.set_advanced_open(true)
	panel.set_advanced_value("misdrop_rate", 0.0)
	panel.set_advanced_value("beam_width", 20.0)

	var profile: CpuProfile = panel.get_settings().build_profile()

	assert_eq(profile.misdrop_rate, 0.0, "上書きした値が Profile に乗る")
	assert_eq(profile.beam_width, 20, "整数のパラメータは整数で入る")


func test_advanced_lookahead_stops_at_the_search_limit() -> void:
	panel.set_advanced_open(true)
	panel.set_advanced_value("lookahead", 5.0)

	# 探索の絶対上限を超える Lookahead は UI からも指定できない（要件定義 §63）。
	assert_eq(
		panel.get_settings().build_profile().lookahead,
		PlacementSearch.MAX_SEARCH_DEPTH - 1,
		"上限で頭打ちになる"
	)


func test_closing_advanced_falls_back_to_the_strength_only_profile() -> void:
	panel.set_advanced_open(true)
	panel.set_advanced_value("pieces_per_second", 0.0)
	panel.set_advanced_open(false)

	var profile: CpuProfile = panel.get_settings().build_profile()

	assert_gt(profile.pieces_per_second, 0.0, "閉じれば Strength からの値に戻る")


# --- 標準最高難易度を超える設定（MVP 受入条件 24） --------------------------


func test_custom_can_exceed_the_standard_maximum() -> void:
	_select_preset(CpuPreset.Preset.CUSTOM)
	panel.set_strength_value(150.0)

	var settings: CpuSettings = panel.get_settings()
	assert_eq(settings.strength, 150.0, "UI から Strength 150 を設定できる")
	assert_true(settings.is_above_standard_maximum(), "標準最高難易度を超えている")
	assert_gt(
		settings.build_profile().pieces_per_second,
		CpuPreset.create_profile(CpuPreset.Preset.EXTREME).pieces_per_second,
		"Extreme より高性能な CPU になる"
	)


func test_strength_slider_allows_over_100() -> void:
	assert_gt(panel.get_strength_maximum(), 100.0, "スライダーの上限が 100 で止まらない")
	assert_eq(panel.get_strength_maximum(), CpuPreset.MAX_CUSTOM_STRENGTH, "上限は Custom の上限と同じ")


func test_settings_build_a_distribution_for_the_battle() -> void:
	_select_preset(CpuPreset.Preset.CUSTOM)
	panel.set_strength_value(120.0)
	panel.set_distribution_values(90.0, 150.0, 10.0)

	var distribution: CpuDistribution = panel.get_settings().build_distribution()

	assert_eq(distribution.average_strength, 120.0, "平均は指定した Strength")
	assert_eq(distribution.minimum_strength, 90.0, "Min はそのまま")
	assert_eq(distribution.maximum_strength, 150.0, "Max はそのまま")
	for strength in distribution.generate(20, 1):
		assert_between(strength, 90.0, 150.0, "分布が Min 〜 Max に収まる")
