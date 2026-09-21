class_name CpuBenchmark
extends RefCounted

## Strength ごとの強さを測る（要件定義 §86 / §115）。
##
## CPU 同士を [CpuBattleRunner] で何試合か戦わせ、**Strength ごとの勝率・
## 平均 Rank・平均 Attack 量**を出す。Strength Mapping（要件定義 §78）を
## 調整したときに、「上げたら本当に強くなったか」を数字で確かめるための道具。
##
## 1 試合につき、指定した Strength を 1 体ずつ並べる。Seed は試合ごとにずらす
## ので、同じ [param benchmark_seed] からは同じ結果が出る（要件定義 §110）。
##
## 実行時間が長くなるため、通常の CI の必須 check には含めない（#45 の制約）。
## 実行は `scripts/benchmark-cpu-strength.sh`。

## 1 試合の上限時間（秒）。
const DEFAULT_TIME_LIMIT_SEC: float = 180.0


## Strength 1 つぶんの集計。
class StrengthResult:
	extends RefCounted

	## 測った Strength。
	var strength: float = 0.0

	## 参加した試合数。
	var battles: int = 0

	## 優勝した回数。
	var wins: int = 0

	## 順位の合計。平均を出すのに使う。
	var rank_total: int = 0

	## 送った Garbage 行数の合計。
	var attack_total: int = 0

	## 生存時間の合計（秒）。
	var survival_total: float = 0.0

	## 勝率（0.0〜1.0）。
	func get_win_rate() -> float:
		return float(wins) / float(battles) if battles > 0 else 0.0

	## 平均 Rank（1 が優勝）。
	func get_average_rank() -> float:
		return float(rank_total) / float(battles) if battles > 0 else 0.0

	## 1 試合あたりの平均 Attack 行数。
	func get_average_attack() -> float:
		return float(attack_total) / float(battles) if battles > 0 else 0.0

	## 平均生存時間（秒）。
	func get_average_survival_sec() -> float:
		return survival_total / float(battles) if battles > 0 else 0.0


var _mapping: CpuStrengthMapping
var _preset: CpuPreset.Preset = CpuPreset.Preset.CUSTOM
var _time_limit_sec: float = DEFAULT_TIME_LIMIT_SEC


func _init(mapping: CpuStrengthMapping = null) -> void:
	_mapping = mapping if mapping != null else CpuStrengthMapping.create_default()


## 既定で測る Strength（要件定義 §59 の目安 + Extreme 超え）。
##
## [PackedFloat32Array] は定数にできないため static 関数で返す。
static func default_strengths() -> PackedFloat32Array:
	return PackedFloat32Array([10.0, 30.0, 50.0, 70.0, 85.0, 100.0, 150.0])


## 1 試合の上限時間を設定する。
func set_time_limit_sec(seconds: float) -> void:
	_time_limit_sec = maxf(1.0, seconds)


## 作る CPU の性格を設定する（Machine / Human-like の比較に使う）。
func set_preset(preset: CpuPreset.Preset) -> void:
	_preset = preset


## Strength ごとに [param battles] 試合ずつ戦わせ、集計を返す。
##
## 返る配列は [param strengths] と同じ並び。
func run_strength_sweep(
	strengths: PackedFloat32Array = default_strengths(), battles: int = 3, benchmark_seed: int = 0
) -> Array[StrengthResult]:
	var results: Array[StrengthResult] = []
	for strength in strengths:
		var result := StrengthResult.new()
		result.strength = strength
		results.append(result)

	if strengths.size() < 2 or battles <= 0:
		return results

	for battle_index in range(battles):
		_run_battle(strengths, results, benchmark_seed + battle_index * 104_729)

	return results


## 集計を表にして返す（CLI 表示用）。
static func format_report(results: Array[StrengthResult]) -> String:
	var lines: Array[String] = [
		"| Strength | 試合 | 勝率 | 平均 Rank | 平均 Attack | 平均生存 (秒) |", "|---|---|---|---|---|---|"
	]
	for result in results:
		lines.append(
			(
				"| %.0f | %d | %.0f%% | %.2f | %.1f | %.1f |"
				% [
					result.strength,
					result.battles,
					result.get_win_rate() * 100.0,
					result.get_average_rank(),
					result.get_average_attack(),
					result.get_average_survival_sec()
				]
			)
		)
	return "\n".join(lines)


func _run_battle(
	strengths: PackedFloat32Array, results: Array[StrengthResult], battle_seed: int
) -> void:
	var runner := CpuBattleRunner.new(strengths.size(), null, _mapping, battle_seed)
	# Strength は 1 体ずつ違うので、分布ではなく席ごとに割り当てる。
	# Player ID と strengths の添字が対応する。
	var profiles: Array[CpuProfile] = []
	for strength in strengths:
		profiles.append(CpuPreset.create_profile_at(_preset, strength, _mapping))
	runner.assign_profiles(profiles)

	runner.run(_time_limit_sec)

	for result in runner.get_results():
		var index: int = result.player_id
		if index < 0 or index >= results.size():
			continue
		var summary: StrengthResult = results[index]
		summary.battles += 1
		summary.rank_total += result.rank
		summary.attack_total += result.attack_sent
		summary.survival_total += result.survival_sec
		if result.rank == RankingSystem.WINNER_RANK:
			summary.wins += 1

	runner.dispose()
