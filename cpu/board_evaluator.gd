class_name BoardEvaluator
extends RefCounted

## 盤面の良し悪しを数値にする（要件定義 §68）。
##
## [BoardMetrics] が測った指標に [CpuProfile] の重みを掛けて足すだけ。**同じ盤面
## からは必ず同じ値**になる（乱数も時刻も見ない）。
##
## Battle Layer にも UI にも依存しない（#38 の制約）。99 体ぶんを繰り返し呼ぶため、
## [BoardMetrics] を 1 つ使い回して割り当てを抑える。

var _profile: CpuProfile
var _metrics: BoardMetrics = BoardMetrics.new()


func _init(profile: CpuProfile = null) -> void:
	_profile = profile if profile != null else CpuProfile.create_default()


## 使っている Profile を返す。
func get_profile() -> CpuProfile:
	return _profile


## Profile を差し替える。
func set_profile(profile: CpuProfile) -> void:
	if profile != null:
		_profile = profile


## 直前に測った指標を返す（内部バッファなので書き換えない）。
func get_metrics() -> BoardMetrics:
	return _metrics


## 盤面を評価する。値が大きいほど良い盤面。
func evaluate(board: Board) -> float:
	_metrics.measure(board)
	return evaluate_metrics(_metrics)


## 測り終えた指標から評価値を出す。
func evaluate_metrics(metrics: BoardMetrics) -> float:
	var score: float = 0.0

	# 穴を避ける軸。
	score += _profile.hole_avoidance * _profile.weight_holes * float(metrics.holes)
	score += _profile.hole_avoidance * _profile.weight_hole_depth * float(metrics.hole_depth)

	# 表面をきれいに保つ軸。
	score += _profile.surface_management * _profile.weight_bumpiness * float(metrics.bumpiness)
	score += _profile.surface_management * _profile.weight_wells * float(metrics.wells)
	score += (
		_profile.surface_management
		* _profile.weight_row_transitions
		* float(metrics.row_transitions)
	)
	score += (
		_profile.surface_management
		* _profile.weight_column_transitions
		* float(metrics.column_transitions)
	)

	# Garbage をさばく軸。
	score += (
		_profile.garbage_management
		* _profile.weight_blocked_garbage
		* float(metrics.blocked_garbage_rows)
	)

	# 立て直しの軸。
	score += (
		_profile.recovery_ability
		* _profile.weight_aggregate_height
		* float(metrics.aggregate_height)
	)
	score += _profile.recovery_ability * _profile.weight_max_height * float(metrics.max_height)
	score += _profile.recovery_ability * _profile.weight_danger * metrics.danger_ratio

	# 揃った行は軸に掛けない。どの性格の CPU でも同じ価値にするため。
	score += _profile.weight_completed_lines * float(metrics.completed_lines)

	return score
