class_name Gravity
extends RefCounted

## 時間ベースの落下（要件定義 §29）。
##
## 経過時間を溜めて「何マス落とすべきか」を返す。FPS が変動しても、同じ実時間で
## 同じマス数だけ落ちる。端数は次回へ持ち越すので、細かい delta を何度も与えても
## 落下量は変わらない。
##
## 実時間は見ない。delta は外から与えられる（要件定義 §17）。

var _cells_per_second: float = 0.0
var _accumulated_cells: float = 0.0


func _init(cells_per_second: float = 1.0) -> void:
	set_speed(cells_per_second)


## 落下速度（1 秒あたりのマス数）を設定する。溜まっている端数は保持する。
func set_speed(cells_per_second: float) -> void:
	_cells_per_second = maxf(0.0, cells_per_second)


## 現在の落下速度を返す。
func get_speed() -> float:
	return _cells_per_second


## 時間を進め、落とすべきマス数を返す。端数は次回へ持ち越す。
func advance(delta_sec: float) -> int:
	if delta_sec <= 0.0 or _cells_per_second <= 0.0:
		return 0

	_accumulated_cells += _cells_per_second * delta_sec

	# 誤差でちょうど 1 マスに届かないことがあるため、許容差を足してから切り捨てる。
	# これがないと、同じ実時間でも delta の刻み方で落下量が 1 マスずれる。
	var cells: int = int(_accumulated_cells + GameRules.ACCUMULATION_EPSILON)

	# 許容差で繰り上げたぶんは、わずかに負の端数として残る。0 で丸めて捨てると
	# 刻むたびに許容差ぶんを得することになり、delta の分け方で落下量が変わる。
	# 次回へ繰り越して返す（借りたぶんを返す）。
	_accumulated_cells -= float(cells)
	return cells


## 溜まっている端数を返す（1.0 未満。許容差で繰り上げた直後はわずかに負になる）。
func get_accumulated_cells() -> float:
	return _accumulated_cells


## 溜まっている端数を捨てる。Piece が切り替わったときに呼ぶ。
func reset() -> void:
	_accumulated_cells = 0.0
