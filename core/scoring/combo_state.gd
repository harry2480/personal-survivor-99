class_name ComboState
extends RefCounted

## Combo（連続 Line Clear 数。要件定義 §34）。
##
## Line Clear を伴う Lock が続く限り数が増え、Line Clear なしで Lock した時点で
## 終了する。Attack への換算は [GameBalance] が持つ Combo Table の役目（#30）。
##
## 状態を持つだけで、時刻も乱数も見ない。

var _count: int = 0
var _best_count: int = 0


## 現在の連続 Line Clear 数を返す。Clear していなければ 0。
func get_count() -> int:
	return _count


## Combo が続いているか（2 連以上）を返す。
func is_active() -> bool:
	return _count >= 2


## このゲームでの最大 Combo を返す。
func get_best_count() -> int:
	return _best_count


## Piece が Lock されたときに呼ぶ。
##
## [param line_count] が 0 なら Combo は終了する。
func on_piece_locked(line_count: int) -> void:
	if line_count <= 0:
		_count = 0
		return

	_count += 1
	_best_count = maxi(_best_count, _count)


## 状態を初期化する。
func reset() -> void:
	_count = 0
	_best_count = 0
