extends GutTest

## CPU Benchmark の Unit テスト（要件定義 §86 / §115）。
##
## Strength を上げたら本当に成績が上がるか、同じ Seed で同じ結果になるかを見る。
## 実行時間を抑えるため、試合数と上限時間はテスト用に小さくする。

const SEED: int = 20260922
const BATTLES: int = 2
const TIME_LIMIT_SEC: float = 60.0

var strengths: PackedFloat32Array = PackedFloat32Array([20.0, 50.0, 80.0, 110.0])
var benchmark: CpuBenchmark


func before_each() -> void:
	benchmark = CpuBenchmark.new()
	benchmark.set_time_limit_sec(TIME_LIMIT_SEC)


func _sweep(benchmark_seed: int = SEED) -> Array[CpuBenchmark.StrengthResult]:
	return benchmark.run_strength_sweep(strengths, BATTLES, benchmark_seed)


func test_every_strength_is_measured() -> void:
	var results: Array[CpuBenchmark.StrengthResult] = _sweep()

	assert_eq(results.size(), strengths.size(), "指定した Strength のぶんだけ返る")
	for index in range(results.size()):
		assert_eq(results[index].strength, strengths[index], "並びは指定どおり")
		assert_eq(results[index].battles, BATTLES, "全員が全試合に参加する")


func test_results_report_win_rate_rank_and_attack() -> void:
	# #45 の完了条件「Strength ごとの勝率・平均 Rank・Attack 量を出力できる」。
	var results: Array[CpuBenchmark.StrengthResult] = _sweep()

	var total_wins: int = 0
	for result in results:
		assert_between(result.get_win_rate(), 0.0, 1.0, "勝率は 0〜1")
		assert_between(result.get_average_rank(), 1.0, float(results.size()), "平均 Rank は順位の範囲")
		assert_gte(result.get_average_attack(), 0.0, "平均 Attack が出る")
		assert_gt(result.get_average_survival_sec(), 0.0, "平均生存時間が出る")
		total_wins += result.wins

	assert_eq(total_wins, BATTLES, "各試合に優勝者が 1 人ずついる")


func test_stronger_cpus_rank_higher() -> void:
	var results: Array[CpuBenchmark.StrengthResult] = _sweep()

	var weakest: CpuBenchmark.StrengthResult = results[0]
	var strongest: CpuBenchmark.StrengthResult = results[results.size() - 1]

	assert_lt(strongest.get_average_rank(), weakest.get_average_rank(), "強いほど平均 Rank が上になる")
	assert_gt(
		strongest.get_average_survival_sec(), weakest.get_average_survival_sec(), "強いほど長く生き残る"
	)


func test_benchmark_is_reproducible() -> void:
	var first: Array[CpuBenchmark.StrengthResult] = _sweep()
	var second: Array[CpuBenchmark.StrengthResult] = _sweep()

	for index in range(first.size()):
		assert_eq(first[index].wins, second[index].wins, "同じ Seed なら勝敗も同じ")
		assert_eq(first[index].rank_total, second[index].rank_total, "順位も同じ")
		assert_eq(first[index].attack_total, second[index].attack_total, "Attack 量も同じ")


func test_different_seed_changes_the_result() -> void:
	var first: Array[CpuBenchmark.StrengthResult] = _sweep()
	var second: Array[CpuBenchmark.StrengthResult] = _sweep(SEED + 1)

	# 順位は Strength の順にそろいやすい（強さがそのまま順位に出るのは正しい）。
	# Seed が効いていることは、試合の中身（Attack 量・生存時間）で見る。
	var differs: bool = false
	for index in range(first.size()):
		if first[index].attack_total != second[index].attack_total:
			differs = true
		if not is_equal_approx(first[index].survival_total, second[index].survival_total):
			differs = true

	assert_true(differs, "Seed が違えば試合の中身も変わる")


func test_report_is_a_table() -> void:
	var report: String = CpuBenchmark.format_report(_sweep())

	assert_true(report.begins_with("| Strength |"), "表の見出しから始まる")
	assert_eq(report.split("\n").size(), strengths.size() + 2, "見出し + 区切り + Strength の行数")


func test_empty_input_is_safe() -> void:
	assert_eq(
		benchmark.run_strength_sweep(PackedFloat32Array(), BATTLES, SEED).size(),
		0,
		"Strength が無ければ空で返る"
	)
	assert_eq(benchmark.run_strength_sweep(strengths, 0, SEED)[0].battles, 0, "試合数 0 でも落ちない")
