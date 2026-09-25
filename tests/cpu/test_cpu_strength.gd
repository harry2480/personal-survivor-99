extends GutTest

## Strength から各パラメータへの変換の Unit テスト（要件定義 §59 / §60 / §78）。

const SEEDS: Array[int] = [20260920, 7, 4242]
const PIECES_PER_RUN: int = 15

var mapping: CpuStrengthMapping


func before_each() -> void:
	mapping = CpuStrengthMapping.create_default()


# --- 変換表 ----------------------------------------------------------------


func test_default_mapping_is_valid() -> void:
	assert_true(mapping.is_valid(), "節点が昇順に並んでいる")


func test_all_parameters_are_derived_from_strength() -> void:
	var profile: CpuProfile = mapping.create_profile(50.0)

	assert_eq(profile.strength, 50.0, "変換元の Strength が残る")
	assert_gt(profile.reaction_time_sec, 0.0, "Reaction Time")
	assert_gt(profile.pieces_per_second, 0.0, "PPS")
	assert_gt(profile.misdrop_rate, 0.0, "Misdrop Rate")
	assert_gt(profile.placement_quality, 0.0, "Placement Quality")
	assert_gt(profile.technique_usage, 0.0, "Technique Usage")
	assert_gt(profile.garbage_skill, 0.0, "Garbage Skill")
	assert_gt(profile.target_skill, 0.0, "Target Skill")


func test_higher_strength_improves_every_parameter() -> void:
	var weak: CpuProfile = mapping.create_profile(20.0)
	var strong: CpuProfile = mapping.create_profile(90.0)

	assert_lt(strong.reaction_time_sec, weak.reaction_time_sec, "反応が速くなる")
	assert_gt(strong.pieces_per_second, weak.pieces_per_second, "操作が速くなる")
	assert_lt(strong.misdrop_rate, weak.misdrop_rate, "ミスが減る")
	assert_gt(strong.placement_quality, weak.placement_quality, "配置が良くなる")
	assert_true(strong.lookahead >= weak.lookahead, "先読みが減らない")
	assert_gt(strong.technique_usage, weak.technique_usage, "テクニックを使う")
	assert_gt(strong.garbage_skill, weak.garbage_skill, "Garbage がうまくなる")
	assert_gt(strong.target_skill, weak.target_skill, "Target がうまくなる")
	assert_gt(strong.garbage_management, weak.garbage_management, "Garbage 行を嫌う")
	assert_gt(strong.recovery_ability, weak.recovery_ability, "危険な盤面から立て直す")


func test_parameters_change_monotonically() -> void:
	var previous: CpuProfile = mapping.create_profile(0.0)
	for strength in range(10, 101, 10):
		var current: CpuProfile = mapping.create_profile(float(strength))
		assert_true(
			current.reaction_time_sec <= previous.reaction_time_sec,
			"Strength %d で反応が遅くならない" % strength
		)
		assert_true(
			current.pieces_per_second >= previous.pieces_per_second,
			"Strength %d で操作が遅くならない" % strength
		)
		assert_true(
			current.misdrop_rate <= previous.misdrop_rate, "Strength %d でミスが増えない" % strength
		)
		for property in [
			"placement_quality",
			"lookahead",
			"technique_usage",
			"garbage_skill",
			"target_skill",
			"hole_avoidance",
			"surface_management",
			"garbage_management",
			"recovery_ability",
		]:
			assert_true(
				current.get(property) >= previous.get(property),
				"Strength %d で %s が下がらない" % [strength, property]
			)
		previous = current


func test_strength_is_not_capped_at_one_hundred() -> void:
	# 要件定義 §59: 内部的に 100 を絶対上限としない。
	var at_hundred: CpuProfile = mapping.create_profile(100.0)
	var beyond: CpuProfile = mapping.create_profile(150.0)

	assert_gt(beyond.pieces_per_second, at_hundred.pieces_per_second, "100 を超えても速くなる")
	assert_eq(beyond.misdrop_rate, 0.0, "ミスは 0 で頭打ち")
	assert_eq(beyond.reaction_time_sec, 0.0, "反応も 0 で頭打ち")
	assert_eq(beyond.placement_quality, 1.0, "品質も 1.0 で頭打ち")


func test_low_strength_is_handled() -> void:
	var profile: CpuProfile = mapping.create_profile(0.0)

	assert_gt(profile.pieces_per_second, 0.0, "0 でも動ける速度を持つ")
	assert_true(profile.misdrop_rate <= 1.0, "ミス率が 1.0 を超えない")


func test_table_is_data_driven() -> void:
	mapping.pieces_per_second = PackedFloat32Array([10.0, 10.0, 10.0, 10.0, 10.0, 10.0])

	assert_eq(mapping.create_profile(10.0).pieces_per_second, 10.0, "表を差し替えると結果も変わる")
	assert_eq(mapping.create_profile(90.0).pieces_per_second, 10.0, "どの Strength でも表どおり")


func test_interpolates_between_points() -> void:
	# 節点 30 と 50 の中間（40）は、その間の値になる。
	var middle: CpuProfile = mapping.create_profile(40.0)
	var lower: CpuProfile = mapping.create_profile(30.0)
	var upper: CpuProfile = mapping.create_profile(50.0)

	assert_true(
		(
			middle.pieces_per_second > lower.pieces_per_second
			and middle.pieces_per_second < upper.pieces_per_second
		),
		"節点の間は補間される"
	)


func test_invalid_table_is_detected() -> void:
	mapping.strength_points = PackedFloat32Array([50.0, 10.0])

	assert_false(mapping.is_valid(), "昇順でない表は不正")


func test_table_with_a_missing_value_is_invalid() -> void:
	mapping.pieces_per_second = PackedFloat32Array([0.8, 1.5, 2.5])

	assert_false(mapping.is_valid(), "節点と値の数が合わない表は不正")


func test_config_file_matches_the_script_defaults() -> void:
	# config/ の表はゲームが読み込む実データ。形が崩れていないこと。
	var loaded: CpuStrengthMapping = load("res://config/cpu_strength_mapping.tres")

	assert_not_null(loaded, "読み込める")
	assert_true(loaded.is_valid(), "節点と値の数がそろっている")
	# 既定値はスクリプトと .tres の 2 か所にある。片方だけ直すとずれるので突き合わせる。
	assert_eq(loaded.strength_points, mapping.strength_points, "節点がスクリプトの既定値と一致する")
	var loaded_tables: Array[PackedFloat32Array] = loaded._get_tables()
	var default_tables: Array[PackedFloat32Array] = mapping._get_tables()
	for index in range(default_tables.size()):
		assert_eq(loaded_tables[index], default_tables[index], "表 %d がスクリプトの既定値と一致する" % index)


# --- Preset（要件定義 §60） -------------------------------------------------


func test_presets_map_to_strength() -> void:
	var order: Array[int] = [
		CpuPreset.Preset.EASY,
		CpuPreset.Preset.NORMAL,
		CpuPreset.Preset.HARD,
		CpuPreset.Preset.VERY_HARD,
		CpuPreset.Preset.EXTREME,
	]
	var previous: float = -1.0
	for preset in order:
		var strength: float = CpuPreset.get_strength(preset)
		assert_gt(strength, previous, "%s は前より強い" % CpuPreset.get_preset_name(preset))
		previous = strength


func test_preset_creates_a_profile() -> void:
	var profile: CpuProfile = CpuPreset.create_profile(CpuPreset.Preset.HARD, mapping)

	assert_eq(profile.strength, CpuPreset.get_strength(CpuPreset.Preset.HARD), "Alias として働く")


func test_machine_preset_exceeds_one_hundred() -> void:
	assert_gt(CpuPreset.get_strength(CpuPreset.Preset.MACHINE), 100.0, "Machine は 100 を超える")
	assert_false(CpuPreset.is_user_preset(CpuPreset.Preset.MACHINE), "通常の難易度 UI には出さない")


func test_user_presets_are_listed() -> void:
	assert_eq(
		CpuPreset.USER_PRESETS.size(), 6, "Easy / Normal / Hard / Very Hard / Extreme / Custom"
	)


# --- Strength と実力の相関（Phase 5 完了条件） ------------------------------


func _run_solo(profile: CpuProfile, run_seed: int) -> Dictionary:
	# CPU が探索で選んだ場所へ置き続ける。強さの違いだけが結果に出る。
	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	var session := PuzzleSession.new(rules, PieceRandomizer.new(run_seed))
	session.start(run_seed)
	var search := PlacementSearch.new(profile, run_seed)

	var placed: int = 0
	for _piece in range(PIECES_PER_RUN):
		if session.is_over():
			break

		var active: ActivePiece = session.get_active_piece()
		var best: Placement = search.search(
			session.get_board(), active.type, session.get_next_types(2)
		)
		if best == null:
			break

		active.rotation = best.rotation
		active.position = best.position
		session.hard_drop()
		placed += 1

	return {
		"lines": session.get_scoring().get_cleared_lines_total(),
		"placed": placed,
		"survived": not session.is_over(),
	}


func _average_lines(strength: float) -> float:
	var profile: CpuProfile = mapping.create_profile(strength)
	var total: int = 0
	for run_seed in SEEDS:
		total += int(_run_solo(profile, run_seed)["lines"])
	return float(total) / float(SEEDS.size())


func test_higher_strength_clears_more_lines() -> void:
	# Phase 5 の完了条件「Strength を上げると評価指標が単調に改善する」。
	# 試行はすべて Seed 固定。強さ以外の条件は揃えている。
	var weak: float = _average_lines(10.0)
	var strong: float = _average_lines(100.0)

	assert_gt(strong, weak, "強い CPU の方が多く消す（弱 %.1f 行 / 強 %.1f 行）" % [weak, strong])


func test_line_clearing_improves_across_the_range() -> void:
	var results: Array[float] = []
	for strength in [10.0, 40.0, 70.0, 100.0]:
		results.append(_average_lines(strength))

	assert_gt(results[results.size() - 1], results[0], "端から端で改善する: %s" % str(results))
	assert_true(results[results.size() - 1] >= results[1], "中間より上位が下回らない: %s" % str(results))


func test_strongest_cpu_survives() -> void:
	var profile: CpuProfile = mapping.create_profile(100.0)

	for run_seed in SEEDS:
		assert_true(
			bool(_run_solo(profile, run_seed)["survived"]), "最高強度は %d 手で倒れない" % PIECES_PER_RUN
		)
