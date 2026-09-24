class_name KoRule
extends RefCounted

## KO の帰属を決めるルール（要件定義 §56）。
##
## 「KO 判定方法は Battle Rule として交換可能とする」という要件があるため、
## 判定をこのクラスに閉じ、継承して差し替えられるようにしている。
##
## 既定は「直近の有効な攻撃者に帰属させる」。しきい値以内に Garbage を適用した
## 攻撃者がいなければ、誰にも帰属させない（自滅扱い）。

## 直近の有効な攻撃者とみなす時間（秒）の既定値。
const DEFAULT_WINDOW_SEC: float = 5.0

var _window_sec: float = DEFAULT_WINDOW_SEC


func _init(window_sec: float = DEFAULT_WINDOW_SEC) -> void:
	_window_sec = maxf(0.0, window_sec)


## 判定に使う時間のしきい値を返す。
func get_window_sec() -> float:
	return _window_sec


## KO を誰の手柄にするかを返す。誰にも帰属しない場合は -1。
func determine_attacker(attribution: KoAttribution, victim_id: int, current_time: float) -> int:
	if attribution == null:
		return -1
	return attribution.get_last_effective_attacker(victim_id, current_time, _window_sec)
