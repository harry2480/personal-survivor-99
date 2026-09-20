class_name LightweightCpu
extends RefCounted

## 軽量シミュレーション（要件定義 §82）。
##
## 盤面を持たず、指標だけを**一定周期で**更新する。99 体ぶんを現実的な負荷で
## 動かすための仕組み（要件定義 §80）。
##
## Battle Layer から見た口は Detailed と同じ（Attack を出し、Garbage を受ける）。
## 中で何をしているかは Battle Layer が知らなくてよい（#42 の制約）。

## 指標を更新する周期（秒）。
const UPDATE_INTERVAL_SEC: float = 0.5

## 腕前 1.0 の CPU が 1 秒あたりに掘れる行数。
##
## Attack（`pps × skill × 0.25`）より少し速い程度に置く。ここを大きくすると
## 受けた Garbage をいくらでも掘り返せてしまい、**誰も脱落しない**（#44 で
## CPU 同士の Battle が決着しなかった原因）。
const DIG_LINES_PER_SECOND: float = 1.0

var _profile: CpuProfile
var _indicators: CpuIndicators = CpuIndicators.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _timer_sec: float = 0.0
var _pending_attack: float = 0.0
var _pending_defense: float = 0.0
var _pending_dig: float = 0.0
var _update_count: int = 0


func _init(profile: CpuProfile = null, cpu_seed: int = 0) -> void:
	_profile = profile if profile != null else CpuProfile.create_default()
	_rng.seed = cpu_seed
	_indicators.skill = CpuIndicators.estimate_skill(_profile)
	_indicators.attack_rate = CpuIndicators.estimate_attack_rate(_profile)
	_indicators.defense_rate = CpuIndicators.estimate_defense_rate(_profile)


## 現在の指標を返す。
func get_indicators() -> CpuIndicators:
	return _indicators


## 指標を外から与える（Detailed から降格してきたときに使う）。
func adopt(indicators: CpuIndicators) -> void:
	_indicators.copy_from(indicators)
	_indicators.skill = CpuIndicators.estimate_skill(_profile)
	_indicators.attack_rate = CpuIndicators.estimate_attack_rate(_profile)
	_indicators.defense_rate = CpuIndicators.estimate_defense_rate(_profile)


## これまでに指標を更新した回数を返す。周期の検証に使う。
func get_update_count() -> int:
	return _update_count


## 時間を進め、この間に出した Attack 行数を返す。
##
## 更新は [constant UPDATE_INTERVAL_SEC] ごと。間のフレームでは何もしない。
func update(delta_sec: float) -> int:
	_timer_sec += maxf(0.0, delta_sec)
	if _timer_sec + GameRules.ACCUMULATION_EPSILON < UPDATE_INTERVAL_SEC:
		return 0

	var steps: int = int((_timer_sec + GameRules.ACCUMULATION_EPSILON) / UPDATE_INTERVAL_SEC)
	_timer_sec -= float(steps) * UPDATE_INTERVAL_SEC

	var attack: int = 0
	for _step in range(steps):
		attack += _step_once()
	_update_count += steps
	return attack


## Garbage を受け取る。
func receive_garbage(line_count: int) -> void:
	_indicators.incoming_garbage += maxi(0, line_count)
	_refresh_danger()


## Top Out しているかを返す。
func is_over() -> bool:
	return _indicators.stack_height >= Board.VISIBLE_HEIGHT


func _step_once() -> int:
	# 受けた Garbage を腕前に応じて捌く。捌けなかったぶんが積み上がる。
	# 1 周期ぶんの防御量は 1 行に満たないことが多いので、Attack と同じく端数を溜める。
	# 使わなかった丸ごとの行は捨てる（平時に溜め込んで、後でまとめて捌かないため）。
	_pending_defense += _indicators.defense_rate * UPDATE_INTERVAL_SEC
	var cleared: int = mini(_indicators.incoming_garbage, int(_pending_defense))
	_pending_defense = fmod(_pending_defense - float(cleared), 1.0)
	_indicators.incoming_garbage -= cleared
	_indicators.stack_height += _indicators.incoming_garbage
	_indicators.incoming_garbage = 0

	# 自分でも少しずつ掘る。腕前が高いほど速い。端数は次の周期へ持ち越す。
	_pending_dig += _indicators.skill * DIG_LINES_PER_SECOND * UPDATE_INTERVAL_SEC
	var dug: int = int(_pending_dig)
	_pending_dig -= float(dug)
	_indicators.stack_height = maxi(0, _indicators.stack_height - dug)
	_indicators.holes = maxi(0, _indicators.holes + (1 if _rng.randf() > _indicators.skill else -1))
	_indicators.roughness = clampi(
		_indicators.roughness + _rng.randi_range(-1, 1), 0, Board.VISIBLE_HEIGHT
	)
	_refresh_danger()

	# Attack は見込み値を溜めて、1 行ぶん溜まったら出す。
	_pending_attack += _indicators.attack_rate * UPDATE_INTERVAL_SEC
	var attack: int = int(_pending_attack)
	_pending_attack -= float(attack)
	return attack


func _refresh_danger() -> void:
	var ratio: float = clampf(
		float(_indicators.stack_height) / float(Board.VISIBLE_HEIGHT), 0.0, 1.0
	)
	if ratio >= DangerLevel.CRITICAL_RATIO:
		_indicators.danger_level = DangerLevel.Level.CRITICAL
	elif ratio >= DangerLevel.DANGER_RATIO:
		_indicators.danger_level = DangerLevel.Level.DANGER
	elif ratio >= DangerLevel.WARNING_RATIO:
		_indicators.danger_level = DangerLevel.Level.WARNING
	else:
		_indicators.danger_level = DangerLevel.Level.SAFE
