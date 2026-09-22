class_name AutoShift
extends RefCounted

## 横移動の長押し処理（DAS / ARR。要件定義 §31）。
##
## 押した瞬間に 1 マス動き、[member GameRules.das_sec] だけ押し続けると反復が始まり、
## 以降は [member GameRules.arr_sec] ごとに 1 マスずつ動く。
##
## [member GameRules.arr_sec] が 0 のときは「壁まで一気に移動」を意味する。
## 無限ループを避けるため、1 回の [method update] が返す歩数には上限がある
## （盤面の幅を超えて動く必要はない）。
##
## 実時間は見ない。delta は外から与えられる（要件定義 §17）。

## 押されている方向。
enum Direction { NONE, LEFT, RIGHT }

## ARR が 0 のときに 1 回で返す歩数。盤面の幅ぶん動かせば必ず壁に着く。
const INSTANT_STEPS: int = Board.WIDTH

var _rules: GameRules
var _direction: Direction = Direction.NONE
var _timer_sec: float = 0.0
var _das_charged: bool = false


func _init(rules: GameRules = null) -> void:
	_rules = rules if rules != null else GameRules.create_default()


## いま押されている方向を返す。
func get_direction() -> Direction:
	return _direction


## DAS が溜まり、反復に入っているかを返す。
func is_repeating() -> bool:
	return _das_charged


## 方向キーを押す。押した瞬間に動かすべき歩数（1）を返す。
##
## 既に同じ方向を押している場合は 0 を返す（押し直しとして扱わない）。
## 逆方向を押した場合は、そちらへ切り替えて DAS を溜め直す。
func press(direction: Direction) -> int:
	if direction == Direction.NONE:
		release_all()
		return 0
	if direction == _direction:
		return 0

	_direction = direction
	_timer_sec = 0.0
	_das_charged = false
	return 1


## 方向キーを離す。押していた方向と違うなら何もしない。
func release(direction: Direction) -> void:
	if direction == _direction:
		release_all()


## すべての方向キーを離した状態にする。
func release_all() -> void:
	_direction = Direction.NONE
	_timer_sec = 0.0
	_das_charged = false


## 時間を進め、この間に動かすべき歩数を返す。
func update(delta_sec: float) -> int:
	if _direction == Direction.NONE:
		return 0

	_timer_sec += maxf(0.0, delta_sec)

	# DAS 到達と同時に 1 マス目を出す。以降は ARR ごとに 1 マスずつ。
	var charged_now: bool = false
	if not _das_charged:
		if _timer_sec + GameRules.ACCUMULATION_EPSILON < _rules.das_sec:
			return 0
		_das_charged = true
		_timer_sec -= _rules.das_sec
		charged_now = true

	if _rules.arr_sec <= 0.0:
		# 瞬時移動。歩数に上限があるので、ここで止まらなくなることはない。
		_timer_sec = 0.0
		return INSTANT_STEPS

	var steps: int = int((_timer_sec + GameRules.ACCUMULATION_EPSILON) / _rules.arr_sec)
	_timer_sec -= float(steps) * _rules.arr_sec
	return steps + 1 if charged_now else steps


## 押されている方向を x 方向の符号（-1 / 0 / +1）で返す。
func get_step_x() -> int:
	match _direction:
		Direction.LEFT:
			return -1
		Direction.RIGHT:
			return 1
	return 0
