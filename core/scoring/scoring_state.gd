class_name ScoringState
extends RefCounted

## Attack の入力になる状態をまとめたもの（要件定義 §34 / §35 / §33）。
##
## Combo・Back-to-Back・直前の T-Spin 判定は、どれも「Lock の結果」から決まり、
## Attack 計算（#30）がまとめて参照する。別々に持ち回ると進行側の口が増えるため、
## 1 つにまとめて扱う。

var _combo: ComboState
var _b2b: BackToBackState
var _last_t_spin: TSpinDetector.Result = TSpinDetector.Result.NONE


func _init(balance: GameBalance = null) -> void:
	_combo = ComboState.new()
	_b2b = BackToBackState.new(balance)


## Piece が Lock されたときに呼ぶ。
##
## Combo は Line Clear なしの Lock で終了するが、B2B は維持される（§34 / §35）。
func on_piece_locked(result: LineClearResult, t_spin: TSpinDetector.Result) -> void:
	_last_t_spin = t_spin
	_combo.on_piece_locked(result.line_count)
	_b2b.on_piece_locked(result.type, result.line_count, t_spin != TSpinDetector.Result.NONE)


## 現在の連続 Line Clear 数。
func get_combo_count() -> int:
	return _combo.get_count()


## 現在の Back-to-Back の鎖の長さ。
func get_b2b_chain() -> int:
	return _b2b.get_chain()


## Back-to-Back の効果が乗る状態か。
func is_b2b_active() -> bool:
	return _b2b.is_active()


## 直前の Lock の T-Spin 判定結果。
func get_last_t_spin() -> TSpinDetector.Result:
	return _last_t_spin


## 直前の Lock が T-Spin だったか。
func was_t_spin() -> bool:
	return _last_t_spin != TSpinDetector.Result.NONE


## 状態を初期化する。
func reset() -> void:
	_combo.reset()
	_b2b.reset()
	_last_t_spin = TSpinDetector.Result.NONE
