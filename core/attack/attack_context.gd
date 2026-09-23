class_name AttackContext
extends RefCounted

## Attack 計算の入力（要件定義 §38）。
##
## Battle Layer を知らない純粋な値の入れ物。誰に送るか・いつ届くかは
## Battle Layer（Phase 4）の責務で、ここには持ち込まない。

## Clear 種別。
var clear_type: LineClear.Type = LineClear.Type.NONE

## 消えた行数。
var line_count: int = 0

## T-Spin 判定の結果。
var t_spin: TSpinDetector.Result = TSpinDetector.Result.NONE

## 連続 Line Clear 数（1 回目の Clear なら 1）。
var combo_count: int = 0

## Back-to-Back の効果が乗る状態か。
var b2b_active: bool = false

## Perfect Clear が成立したか。
var perfect_clear: bool = false


static func create(
	result: LineClearResult, scoring: ScoringState, is_perfect_clear: bool = false
) -> AttackContext:
	var context := AttackContext.new()
	context.clear_type = result.type
	context.line_count = result.line_count
	context.t_spin = scoring.get_last_t_spin()
	context.combo_count = scoring.get_combo_count()
	context.b2b_active = scoring.is_b2b_active()
	context.perfect_clear = is_perfect_clear
	return context


## Attack が発生しうる状況かを返す。
func has_clear() -> bool:
	return line_count > 0
