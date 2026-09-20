class_name DynamicDifficulty
extends Resource

## 成績に応じた難易度の自動調整（要件定義 §76）。
##
## **既定は OFF**。ON にしても効くのは**次の Battle の設定だけ**で、
## 試合途中の CPU は一切触らない（要件定義 §75 / §76 / #44 の制約）。
##
## 調整に使うのは Win Rate / Average Rank / KO Count / Survival Time の 4 つ
## （要件定義 §76）。どれをどれだけ効かせるかは、この Resource のデータで決める。


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

	var delta: float = (outcome.win_rate - target_win_rate) * 2.0 * max_step
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
	next.minimum_strength += shift
	next.maximum_strength += shift
	next.fixed_strength = plan_next_strength(next.fixed_strength, outcome)
	return next
