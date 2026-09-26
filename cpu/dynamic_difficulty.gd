class_name DynamicDifficulty
extends Resource

## 成績に応じた難易度の自動調整（要件定義 §76）。
##
## **既定は OFF**。ON にしても効くのは**次の Battle の設定だけ**で、
## 試合途中の CPU は一切触らない（要件定義 §75 / §76 / #44 の制約）。
##
## 調整に使えるのは Win Rate / Average Rank / KO Count / Survival Time の 4 つ
## （要件定義 §76）。どれをどれだけ効かせるかは、この Resource の重みで決める。
## 既定は Win Rate だけを効かせ、残り 3 つの重みは 0。


## Player 側の成績（要件定義 §76）。
class Outcome:
	extends RefCounted

	## 勝率（0.0〜1.0）。
	var win_rate: float = 0.0

	## 平均順位（1 が最上位）。
	var average_rank: float = 0.0

	## 1 試合あたりの平均 KO 数。
	var ko_count: float = 0.0

	## 平均生存時間（秒）。
	var survival_sec: float = 0.0

	static func create(
		rate: float, rank: float, kos: float = 0.0, survival: float = 0.0
	) -> Outcome:
		var outcome := Outcome.new()
		outcome.win_rate = rate
		outcome.average_rank = rank
		outcome.ko_count = kos
		outcome.survival_sec = survival
		return outcome


## 自動調整を使うか。既定は OFF（要件定義 §76）。
@export var enabled: bool = false

## Player の勝率がこの値を上回ったら CPU を強くする。
@export_range(0.0, 1.0, 0.01) var target_win_rate: float = 0.5

## Player の平均順位がこの値より上（数字が小さい）なら CPU を強くする。
@export_range(1.0, 99.0, 0.5, "or_greater") var target_average_rank: float = 50.0

## Player の 1 試合あたりの KO 数がこの値を上回ったら CPU を強くする。
@export_range(0.0, 20.0, 0.1, "or_greater") var target_ko_count: float = 1.0

## Player の平均生存時間（秒）がこの値を上回ったら CPU を強くする。
@export_range(0.0, 1800.0, 1.0, "or_greater") var target_survival_sec: float = 180.0

# --- 各成績の効かせ方（要件定義 §76） ---------------------------------------
# 各成績は「目標からどれだけ離れたか」を目標値で割って揃え、重みを掛けて足す。
# 0 にした成績は調整に使わない。

## Win Rate の重み。
@export_range(0.0, 2.0, 0.05, "or_greater") var win_rate_weight: float = 1.0

## Average Rank の重み。
@export_range(0.0, 2.0, 0.05, "or_greater") var average_rank_weight: float = 0.0

## KO Count の重み。
@export_range(0.0, 2.0, 0.05, "or_greater") var ko_count_weight: float = 0.0

## Survival Time の重み。
@export_range(0.0, 2.0, 0.05, "or_greater") var survival_time_weight: float = 0.0

## 1 回の調整で動かす Strength の上限。
@export_range(0.0, 50.0, 1.0) var max_step: float = 5.0

## 調整後の Strength の下限。
@export_range(0.0, 200.0, 1.0, "or_greater") var minimum_strength: float = 30.0

## 調整後の Strength の上限。
@export_range(0.0, 200.0, 1.0, "or_greater") var maximum_strength: float = 150.0


## 既定の設定（OFF）を作る。
static func create_default() -> DynamicDifficulty:
	return DynamicDifficulty.new()


## 自動調整が有効かを返す。
func is_enabled() -> bool:
	return enabled


## **次の Battle** に使う平均 Strength を返す（要件定義 §76）。
##
## OFF のときは [param current_strength] をそのまま返す。試合途中に呼ぶための
## API ではない（§75 / §76）。呼ぶのは Battle と Battle の間だけ。
func plan_next_strength(current_strength: float, outcome: Outcome) -> float:
	if not enabled or outcome == null:
		return current_strength

	var delta: float = _score(outcome) * 2.0 * max_step
	var adjusted: float = current_strength + clampf(delta, -max_step, max_step)
	return clampf(adjusted, minimum_strength, maximum_strength)


## **次の Battle** に使う分布を返す（要件定義 §76）。
##
## 元の [param distribution] は書き換えず、調整後の複製を返す。OFF のときは
## 値の同じ複製がそのまま返る。
func plan_next_distribution(distribution: CpuDistribution, outcome: Outcome) -> CpuDistribution:
	var next: CpuDistribution = distribution.duplicate()
	if not enabled or outcome == null:
		return next

	var shift: float = plan_next_strength(next.average_strength, outcome) - next.average_strength
	next.average_strength += shift
	# 両端も調整の範囲に収める。同じ範囲で挟むので、最小 ≤ 最大の順は崩れない。
	next.minimum_strength = clampf(
		next.minimum_strength + shift, minimum_strength, maximum_strength
	)
	next.maximum_strength = clampf(
		next.maximum_strength + shift, minimum_strength, maximum_strength
	)
	next.fixed_strength = plan_next_strength(next.fixed_strength, outcome)
	return next


# Player が「強すぎる」ほど正、「弱すぎる」ほど負になる値を返す。
#
# 各成績を目標値で割って揃えてから重みを掛ける。Win Rate は 0.0〜1.0 なので
# そのまま差を使う（既定の重み 1.0 で、勝率 100% なら +0.5）。
func _score(outcome: Outcome) -> float:
	var score: float = (outcome.win_rate - target_win_rate) * win_rate_weight
	# 順位は数字が小さいほど良いので、目標との差の向きを逆にする。
	score -= _relative(outcome.average_rank, target_average_rank) * average_rank_weight
	score += _relative(outcome.ko_count, target_ko_count) * ko_count_weight
	score += _relative(outcome.survival_sec, target_survival_sec) * survival_time_weight
	return score


# (value - target) を target で割った値。target が 0 以下なら差をそのまま返す。
static func _relative(value: float, target: float) -> float:
	if target <= 0.0:
		return value - target
	return (value - target) / target
