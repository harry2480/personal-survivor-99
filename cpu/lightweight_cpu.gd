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

var _profile: CpuProfile
var _indicators: CpuIndicators = CpuIndicators.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _timer_sec: float = 0.0
var _pending_attack: float = 0.0
var _update_count: int = 0


func _init(profile: CpuProfile = null, cpu_seed: int = 0) -> void:
	_profile = profile if profile != null else CpuProfile.create_default()
	_rng.seed = cpu_seed
	_indicators.skill = clampf(_profile.strength / 100.0, 0.0, 2.0)
	_indicators.attack_rate = _estimate_attack_rate()
	_indicators.defense_rate = _estimate_defense_rate()


## 現在の指標を返す。
func get_indicators() -> CpuIndicators:
	return _indicators


## 指標を外から与える（Detailed から降格してきたときに使う）。
func adopt(indicators: CpuIndicators) -> void:
	_indicators.copy_from(indicators)
	_indicators.skill = clampf(_profile.strength / 100.0, 0.0, 2.0)
	_indicators.attack_rate = _estimate_attack_rate()
	_indicators.defense_rate = _estimate_defense_rate()


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
	var cleared: int = mini(
		_indicators.incoming_garbage, int(_indicators.defense_rate * UPDATE_INTERVAL_SEC)
	)
	_indicators.incoming_garbage -= cleared
	_indicators.stack_height += _indicators.incoming_garbage
	_indicators.incoming_garbage = 0

	# 自分でも少しずつ掘る。腕前が高いほど下がる。
	_indicators.stack_height = maxi(
		0, _indicators.stack_height - int(round(_indicators.skill * 2.0))
	)
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


# 腕前と PPS から、1 秒あたりに出す Attack 行数を見積もる。
func _estimate_attack_rate() -> float:
	return _profile.pieces_per_second * _indicators.skill * 0.25


# 腕前と PPS から、1 秒あたりに捌ける Garbage 行数を見積もる。
func _estimate_defense_rate() -> float:
	return _profile.pieces_per_second * clampf(_profile.garbage_skill, 0.0, 1.0) * 0.5
