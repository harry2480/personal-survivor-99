extends GutTest

## 99 人戦の Strength 分布と Fixed Strength Mode の Unit テスト
## （要件定義 §73〜§76）。
##
## 分布が Seed で再現されること、試合途中に CPU が強くならないこと
## （Dynamic Difficulty は既定 OFF）、弱い CPU から先に脱落することを見る。

const SEED: int = 20260921
const CPU_COUNT: int = 12
const BATTLE_LIMIT_SEC: float = 120.0

## 誰も Top Out しないうちに時間切れにするための上限（秒）。
const SHORT_LIMIT_SEC: float = 10.0

var mapping: CpuStrengthMapping
var runners: Array = []


func before_each() -> void:
	mapping = CpuStrengthMapping.create_default()


func after_each() -> void:
	for runner in runners:
		runner.dispose()
	runners.clear()


func _new_runner(distribution: CpuDistribution, cpu_count: int = CPU_COUNT) -> CpuBattleRunner:
	var runner := CpuBattleRunner.new(cpu_count, distribution, mapping, SEED)
	runners.append(runner)
	return runner


func _spread_distribution() -> CpuDistribution:
	var distribution := CpuDistribution.create_default()
	distribution.average_strength = 70.0
	distribution.minimum_strength = 30.0
	distribution.maximum_strength = 110.0
	distribution.strength_variance = 25.0
	return distribution


func _average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total: float = 0.0
	for value in values:
		total += value
	return total / float(values.size())


# --- 分布（要件定義 §73） ---------------------------------------------------


func test_distribution_stays_between_minimum_and_maximum() -> void:
	var distribution: CpuDistribution = _spread_distribution()

	for strength in distribution.generate(99, SEED):
		assert_between(
			strength, distribution.minimum_strength, distribution.maximum_strength, "Min 〜 Max に収まる"
		)


func test_distribution_centers_on_the_average() -> void:
	var distribution: CpuDistribution = _spread_distribution()

	var strengths: PackedFloat32Array = distribution.generate(99, SEED)
	var average: float = _average(Array(strengths))

	assert_almost_eq(average, distribution.average_strength, 8.0, "平均は指定値の近くになる")


func test_variance_controls_the_spread() -> void:
	var wide: CpuDistribution = _spread_distribution()
	var narrow: CpuDistribution = _spread_distribution()
	narrow.strength_variance = 0.0

	var wide_values: PackedFloat32Array = wide.generate(50, SEED)
	var narrow_values: PackedFloat32Array = narrow.generate(50, SEED)

	assert_gt(Array(wide_values).max() - Array(wide_values).min(), 10.0, "Variance を上げると散らばる")
	assert_eq(Array(narrow_values).max(), Array(narrow_values).min(), "Variance 0 なら全員が平均値")


func test_average_over_100_is_allowed() -> void:
	var distribution: CpuDistribution = _spread_distribution()
	distribution.average_strength = 130.0
	distribution.minimum_strength = 110.0
	distribution.maximum_strength = 150.0

	for strength in distribution.generate(20, SEED):
		assert_gte(strength, 110.0, "100 を超える分布も作れる（§59）")


# --- Fixed Strength Mode（要件定義 §74） ------------------------------------


func test_fixed_strength_mode_gives_everyone_the_same_strength() -> void:
	for value in [100.0, 150.0]:
		var distribution: CpuDistribution = CpuDistribution.create_fixed(value)
		for strength in distribution.generate(99, SEED):
			assert_eq(strength, value, "全 CPU が Strength %.0f" % value)


func test_fixed_strength_ignores_variance() -> void:
	var distribution: CpuDistribution = CpuDistribution.create_fixed(100.0)
	distribution.strength_variance = 40.0

	var strengths: PackedFloat32Array = distribution.generate(30, SEED)

	assert_eq(Array(strengths).max(), Array(strengths).min(), "Fixed ならばらつかない")


# --- 再現性（要件定義 §110） -------------------------------------------------


func test_same_seed_reproduces_the_same_distribution() -> void:
	var distribution: CpuDistribution = _spread_distribution()

	assert_eq(distribution.generate(99, SEED), distribution.generate(99, SEED), "同じ Seed なら同じ分布")


func test_different_seed_changes_the_distribution() -> void:
	var distribution: CpuDistribution = _spread_distribution()

	assert_ne(
		distribution.generate(99, SEED), distribution.generate(99, SEED + 1), "Seed が違えば分布も変わる"
	)


func test_profiles_follow_the_generated_strengths() -> void:
	var distribution: CpuDistribution = _spread_distribution()

	var strengths: PackedFloat32Array = distribution.generate(CPU_COUNT, SEED)
	var profiles: Array[CpuProfile] = distribution.create_profiles(CPU_COUNT, mapping, SEED)

	assert_eq(profiles.size(), CPU_COUNT, "人数ぶんの Profile が返る")
	for index in range(CPU_COUNT):
		assert_eq(profiles[index].strength, strengths[index], "Profile の Strength が一致する")


func test_preset_changes_the_character_without_changing_strength() -> void:
	var distribution: CpuDistribution = CpuDistribution.create_fixed(120.0)
	distribution.preset = CpuPreset.Preset.HUMAN_LIKE

	var profiles: Array[CpuProfile] = distribution.create_profiles(3, mapping, SEED)

	for profile in profiles:
		assert_eq(profile.strength, 120.0, "Strength は指定どおり")
		assert_lte(profile.pieces_per_second, mapping.human_max_pieces_per_second, "PPS 上限は残る")


func test_cpu_manager_registers_the_whole_distribution() -> void:
	var manager := BattleManager.new()
	manager.setup(1, CPU_COUNT, SEED)
	var cpus := CpuManager.new(manager, SEED, 0)

	cpus.register_all_from_distribution(_spread_distribution(), mapping, SEED)

	var registered: Array[int] = cpus.get_registered_ids()
	assert_eq(registered.size(), CPU_COUNT, "CPU の数だけ登録される")
	var strengths: PackedFloat32Array = _spread_distribution().generate(CPU_COUNT, SEED)
	for index in range(CPU_COUNT):
		var profile: CpuProfile = cpus.get_profile(registered[index])
		assert_eq(profile.strength, strengths[index], "分布のとおりに配られる")


# --- Dynamic Difficulty（要件定義 §76） -------------------------------------


func test_dynamic_difficulty_is_off_by_default() -> void:
	var dynamic := DynamicDifficulty.create_default()

	assert_false(dynamic.is_enabled(), "既定は OFF（§76）")


func test_disabled_dynamic_difficulty_changes_nothing() -> void:
	var dynamic := DynamicDifficulty.create_default()
	var outcome: DynamicDifficulty.Outcome = DynamicDifficulty.Outcome.create(1.0, 1.0, 5.0, 300.0)

	assert_eq(dynamic.plan_next_strength(75.0, outcome), 75.0, "OFF なら Strength は動かない")

	var distribution: CpuDistribution = _spread_distribution()
	var next: CpuDistribution = dynamic.plan_next_distribution(distribution, outcome)
	assert_eq(next.average_strength, distribution.average_strength, "分布も動かない")


func test_enabled_dynamic_difficulty_adjusts_the_next_battle() -> void:
	var dynamic := DynamicDifficulty.create_default()
	dynamic.enabled = true

	var winning: DynamicDifficulty.Outcome = DynamicDifficulty.Outcome.create(1.0, 1.0)
	var losing: DynamicDifficulty.Outcome = DynamicDifficulty.Outcome.create(0.0, 50.0)

	assert_gt(dynamic.plan_next_strength(75.0, winning), 75.0, "勝ちすぎたら次は強くする")
	assert_lt(dynamic.plan_next_strength(75.0, losing), 75.0, "負け続けたら次は弱くする")
	assert_almost_eq(
		dynamic.plan_next_strength(75.0, winning), 75.0 + dynamic.max_step, 0.01, "1 回の幅は上限まで"
	)


func test_dynamic_difficulty_does_not_touch_the_original_distribution() -> void:
	var dynamic := DynamicDifficulty.create_default()
	dynamic.enabled = true
	var distribution: CpuDistribution = _spread_distribution()
	var before: float = distribution.average_strength

	dynamic.plan_next_distribution(distribution, DynamicDifficulty.Outcome.create(1.0, 1.0))

	assert_eq(distribution.average_strength, before, "元の分布は書き換えない")


func test_default_weights_only_use_the_win_rate() -> void:
	var dynamic := DynamicDifficulty.create_default()
	dynamic.enabled = true

	var top: DynamicDifficulty.Outcome = DynamicDifficulty.Outcome.create(0.5, 1.0, 10.0, 600.0)
	var bottom: DynamicDifficulty.Outcome = DynamicDifficulty.Outcome.create(0.5, 99.0, 0.0, 10.0)

	assert_eq(
		dynamic.plan_next_strength(75.0, top),
		dynamic.plan_next_strength(75.0, bottom),
		"既定では勝率が同じなら順位・KO・生存時間に関わらず同じ"
	)


func test_every_outcome_can_drive_the_adjustment() -> void:
	# 要件定義 §76: Win Rate / Average Rank / KO Count / Survival Time から調整できる。
	var even: DynamicDifficulty.Outcome = DynamicDifficulty.Outcome.create(0.5, 50.0, 1.0, 180.0)
	var cases: Dictionary = {
		"average_rank_weight": DynamicDifficulty.Outcome.create(0.5, 10.0, 1.0, 180.0),
		"ko_count_weight": DynamicDifficulty.Outcome.create(0.5, 50.0, 3.0, 180.0),
		"survival_time_weight": DynamicDifficulty.Outcome.create(0.5, 50.0, 1.0, 360.0),
	}

	for weight in cases:
		var dynamic := DynamicDifficulty.create_default()
		dynamic.enabled = true
		dynamic.win_rate_weight = 0.0
		dynamic.set(weight, 1.0)

		assert_eq(dynamic.plan_next_strength(75.0, even), 75.0, "%s: 目標どおりなら動かない" % weight)
		assert_gt(dynamic.plan_next_strength(75.0, cases[weight]), 75.0, "%s: 良い成績なら強くする" % weight)


func test_next_distribution_stays_within_the_adjustable_range() -> void:
	var dynamic := DynamicDifficulty.create_default()
	dynamic.enabled = true
	var winning: DynamicDifficulty.Outcome = DynamicDifficulty.Outcome.create(1.0, 1.0)

	# 勝ち続けて何度も強くしても、分布の両端が調整の範囲を越えない。
	var distribution: CpuDistribution = CpuDistribution.create_default()
	for _battle in range(20):
		distribution = dynamic.plan_next_distribution(distribution, winning)

	assert_lte(distribution.maximum_strength, dynamic.maximum_strength, "最大は範囲の上限まで")
	assert_lte(distribution.minimum_strength, distribution.maximum_strength, "最小 ≤ 最大は崩れない")
	assert_true(distribution.is_valid(), "分布として正しい形のまま")


func test_cpu_strength_never_changes_during_a_battle() -> void:
	# 要件定義 §75: 試合途中に CPU を不自然に強化しない。
	var runner: CpuBattleRunner = _new_runner(_spread_distribution())
	var cpus: CpuManager = runner.get_cpu_manager()

	var before: Dictionary = {}
	for player_id in cpus.get_registered_ids():
		var profile: CpuProfile = cpus.get_profile(player_id)
		before[player_id] = [profile.strength, profile.pieces_per_second, profile.placement_quality]

	runner.run(BATTLE_LIMIT_SEC)

	for player_id in cpus.get_registered_ids():
		var profile: CpuProfile = cpus.get_profile(player_id)
		assert_eq(
			[profile.strength, profile.pieces_per_second, profile.placement_quality],
			before[player_id],
			"Player %d のパラメータが試合中に変わらない" % player_id
		)


# --- Survivor Scaling（要件定義 §75） ---------------------------------------


func test_cpus_cannot_dig_faster_than_they_are_attacked() -> void:
	# 同じ強さの相手から受ける Attack より速く掘れると、誰も脱落しない（#44）。
	for strength in [30.0, 50.0, 70.0, 90.0, 110.0]:
		var profile: CpuProfile = mapping.create_profile(strength)
		var dig_rate: float = CpuIndicators.estimate_skill(profile) * profile.dig_rate_factor
		assert_lt(
			dig_rate,
			CpuIndicators.estimate_attack_rate(profile),
			"Strength %.0f: 掘る速さが受ける Attack を下回る" % strength
		)


func test_battle_finishes_and_ranks_everyone() -> void:
	var runner: CpuBattleRunner = _new_runner(_spread_distribution())

	var finished: bool = runner.run(BATTLE_LIMIT_SEC)

	assert_true(finished, "CPU だけの Battle が決着する")
	assert_gte(
		runner.get_combat_elimination_count(),
		CPU_COUNT / 2,
		"半数以上は Garbage を受けて実際に脱落する（時間切れの畳み込みではない）"
	)
	var ranks: Array[int] = []
	for result in runner.get_results():
		assert_gt(result.rank, 0, "全員の Rank が確定する")
		ranks.append(result.rank)
	ranks.sort()
	assert_eq(ranks[0], 1, "優勝が 1 人いる")
	assert_eq(ranks[ranks.size() - 1], CPU_COUNT, "最下位まで並ぶ")


func test_strong_cpus_survive_longer_than_weak_ones() -> void:
	var runner: CpuBattleRunner = _new_runner(_spread_distribution())
	runner.run(BATTLE_LIMIT_SEC)

	var results: Array[CpuBattleRunner.Result] = runner.get_results()
	var half: int = results.size() / 2
	var survivors: Array = []
	var eliminated_first: Array = []
	for index in range(results.size()):
		if index < half:
			survivors.append(results[index].strength)
		else:
			eliminated_first.append(results[index].strength)

	assert_gt(_average(survivors), _average(eliminated_first), "終盤に残るのは強い CPU（Survivor Scaling）")


func test_fixed_strength_battle_also_finishes() -> void:
	# 全員同じ強さでも決着する（Challenge / Benchmark 用途。要件定義 §74）。
	var runner: CpuBattleRunner = _new_runner(CpuDistribution.create_fixed(100.0))

	assert_true(runner.run(BATTLE_LIMIT_SEC), "Fixed Strength でも順位が付く")


func test_run_ignores_a_non_positive_frame_delta() -> void:
	# 時間が進まないと上限に届かず、戻ってこなくなる。
	var runner: CpuBattleRunner = _new_runner(_spread_distribution())

	assert_false(runner.run(BATTLE_LIMIT_SEC, 0.0), "0 秒刻みでは進めない")
	assert_false(runner.run(BATTLE_LIMIT_SEC, -1.0), "負の刻みでも進めない")
	assert_eq(runner.get_elapsed_sec(), 0.0, "時間は進んでいない")


func test_players_folded_at_the_time_limit_are_not_counted_as_kos() -> void:
	# Attack は飛び交っているが、誰も Top Out しないうちに時間切れにする。
	var runner: CpuBattleRunner = _new_runner(_spread_distribution())
	runner.run(SHORT_LIMIT_SEC)

	var sent: int = 0
	var kos: int = 0
	for result in runner.get_results():
		sent += result.attack_sent
		kos += result.ko_count

	assert_true(runner.is_timed_out(), "時間切れで畳んでいる")
	assert_gt(sent, 0, "Attack は送られている")
	assert_eq(kos, runner.get_combat_elimination_count(), "KO は実際に Top Out させたぶんだけ（畳んだぶんは数えない）")


func test_battle_is_reproducible() -> void:
	var first: CpuBattleRunner = _new_runner(_spread_distribution())
	first.run(BATTLE_LIMIT_SEC)
	var second: CpuBattleRunner = _new_runner(_spread_distribution())
	second.run(BATTLE_LIMIT_SEC)

	var first_ranks: Array = []
	var second_ranks: Array = []
	for result in first.get_results():
		first_ranks.append([result.player_id, result.rank])
	for result in second.get_results():
		second_ranks.append([result.player_id, result.rank])

	assert_eq(first_ranks, second_ranks, "同じ Seed からは同じ決着になる")
