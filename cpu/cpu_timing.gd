class_name CpuTiming
extends RefCounted

## CPU の反応遅延と操作速度（要件定義 §65 / §66）。
##
## **反応遅延**は、Garbage の受信や Target の変更に気づくまでの時間。気づくまでは
## 次の配置へ進まない。**PPS** は 1 秒あたりに置く Piece 数で、配置の間隔を決める。
##
## 時間は外から与えられる delta で進める（#41 の制約）。実時間も乱数も見ないので、
## 同じ delta 列からは同じタイミングになる。

var _profile: CpuProfile
var _place_timer_sec: float = 0.0
var _reaction_timer_sec: float = 0.0


func _init(profile: CpuProfile = null) -> void:
	_profile = profile if profile != null else CpuProfile.create_default()


## 使っている Profile を返す。
func get_profile() -> CpuProfile:
	return _profile


## 配置の間隔（秒）を返す。
func get_place_interval_sec() -> float:
	return 1.0 / maxf(0.01, _profile.pieces_per_second)


## 反応待ちの残り時間（秒）を返す。
func get_reaction_remaining_sec() -> float:
	return _reaction_timer_sec


## 反応待ち中かを返す。
func is_reacting() -> bool:
	return _reaction_timer_sec > GameRules.ACCUMULATION_EPSILON


## 次の配置までの残り時間（秒）を返す。
func get_place_remaining_sec() -> float:
	return maxf(0.0, get_place_interval_sec() - _place_timer_sec)


## 反応が必要な出来事が起きたことを伝える（Garbage 受信・Target 変更など）。
##
## 反応遅延ぶんだけ、次の配置が待たされる。
func notify_event() -> void:
	_reaction_timer_sec = maxf(_reaction_timer_sec, _profile.reaction_time_sec)


## 時間を進め、Piece を置くべきかを返す。
##
## 反応待ちの間は配置の時間を溜めない。「驚いて手が止まる」挙動にするため。
func update(delta_sec: float) -> bool:
	var step: float = maxf(0.0, delta_sec)

	if is_reacting():
		_reaction_timer_sec -= step
		if _reaction_timer_sec > GameRules.ACCUMULATION_EPSILON:
			return false
		# 反応し終えた余りは配置の時間へ回す。
		step = -_reaction_timer_sec
		_reaction_timer_sec = 0.0

	_place_timer_sec += step
	var interval: float = get_place_interval_sec()
	if _place_timer_sec + GameRules.ACCUMULATION_EPSILON < interval:
		return false

	_place_timer_sec -= interval
	return true


## 配置直後に呼ぶ。溜まった時間を捨てる。
func notify_placed() -> void:
	_place_timer_sec = 0.0


## 状態を初期化する。
func reset() -> void:
	_place_timer_sec = 0.0
	_reaction_timer_sec = 0.0
