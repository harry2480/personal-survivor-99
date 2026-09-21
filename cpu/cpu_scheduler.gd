class_name CpuScheduler
extends RefCounted

## CPU 更新の分散と、負荷時の段階的な削減（要件定義 §84 / §104）。
##
## 99 体を毎フレーム全部動かすと 1 フレームの処理時間が偏る（#46 の計測）。
## ここでは **CPU を [member CpuSchedulePolicy.slice_count] 組に分け、
## フレームごとに 1 組ずつ動かす**。
##
## 分散しても **1 体に渡す時間の合計は変わらない**。前回その CPU を動かして
## からの経過時間をまとめて渡すので、Battle の時間整合性（Garbage の活性時刻・
## Reaction Time）は壊れない（#47 の制約）。
##
## [codeblock]
## Frame N    : CPU 0, 4, 8 …   （delta を 4 フレームぶんまとめて渡す）
## Frame N+1  : CPU 1, 5, 9 …
## [/codeblock]
##
## 負荷が高いときは [CpuSchedulePolicy] に従って削る。削るのは **CPU の
## 思考の深さと Detailed の数だけ**で、Human Input・Game Core・Battle State は
## 触らない（要件定義 §84）。

## 削る段階が変わった。
signal degradation_changed(previous: CpuSchedulePolicy.Level, current: CpuSchedulePolicy.Level)

var _cpus: CpuManager
var _policy: CpuSchedulePolicy
var _order: Array[int] = []
var _last_update_sec: Dictionary = {}
var _total_sec: float = 0.0
var _frame_index: int = 0
var _last_update_count: int = 0
var _frame_msec_samples: Array[float] = []
var _level: CpuSchedulePolicy.Level = CpuSchedulePolicy.Level.NONE
var _below_frames: int = 0
var _above_frames: int = 0
var _original_lookahead: Dictionary = {}
var _original_beam_width: Dictionary = {}
var _original_detailed_limit: int = 0


func _init(cpus: CpuManager, policy: CpuSchedulePolicy = null) -> void:
	_cpus = cpus
	_policy = policy if policy != null else CpuSchedulePolicy.create_default()
	_original_detailed_limit = _cpus.get_detailed_limit()
	refresh_order()


## 対象の CPU を取り直す（登録や脱落のあとに呼ぶ）。
func refresh_order() -> void:
	_order = _cpus.get_registered_ids()
	_order.sort()
	for player_id in _order:
		if not _last_update_sec.has(player_id):
			_last_update_sec[player_id] = _total_sec
			_original_lookahead[player_id] = _cpus.get_profile(player_id).lookahead
			_original_beam_width[player_id] = _cpus.get_profile(player_id).beam_width


## 使っている設定を返す。
func get_policy() -> CpuSchedulePolicy:
	return _policy


## 現在の削減段階を返す。
func get_level() -> CpuSchedulePolicy.Level:
	return _level


## 直近のフレームで動かした CPU の数を返す。
func get_last_update_count() -> int:
	return _last_update_count


## その CPU に渡した時間の合計（秒）を返す。時間整合性の検証に使う。
func get_simulated_sec(player_id: int) -> float:
	return _last_update_sec.get(player_id, 0.0)


## その CPU にまだ渡していない時間（秒）を返す。
##
## 「渡した時間 + 渡していない時間」は、必ず Battle の経過時間と一致する。
func get_pending_sec(player_id: int) -> float:
	return _total_sec - _last_update_sec.get(player_id, _total_sec)


## 1 フレームぶん進める。動かした CPU が出した Attack 行数を ID 付きで返す。
##
## 動かすのはこのフレームの組だけ。動かさなかった CPU のぶんの時間は溜めておき、
## 次にその CPU を動かすときにまとめて渡す。
func update(delta_sec: float) -> Dictionary:
	var attacks: Dictionary = {}
	var slices: int = maxi(1, _policy.slice_count)
	var slice_index: int = _frame_index % slices

	_total_sec += maxf(0.0, delta_sec)
	_last_update_count = 0

	# このフレームの組だけを見る。触らない CPU には一切手を出さないので、
	# 1 フレームのコストが人数ではなく「組の大きさ」で決まる。
	var index: int = slice_index
	while index < _order.size():
		var player_id: int = _order[index]
		var elapsed: float = _total_sec - _last_update_sec.get(player_id, _total_sec)
		_last_update_sec[player_id] = _total_sec
		_last_update_count += 1

		var attack: int = _cpus.update_player(player_id, elapsed)
		if attack > 0:
			attacks[player_id] = attack
		index += slices

	_frame_index += 1
	return attacks


## 残っている時間をすべて渡しきる（Battle を畳む前に呼ぶ）。
##
## 分散の途中で終わると、CPU ごとに進んだ時間がばらつく。それを揃える。
func flush() -> Dictionary:
	var attacks: Dictionary = {}
	for player_id in _order:
		var elapsed: float = _total_sec - _last_update_sec.get(player_id, _total_sec)
		if elapsed <= 0.0:
			continue
		_last_update_sec[player_id] = _total_sec
		var attack: int = _cpus.update_player(player_id, elapsed)
		if attack > 0:
			attacks[player_id] = attack
	return attacks


## 1 フレームの処理時間（ミリ秒）を伝える。
##
## 平均が [member CpuSchedulePolicy.degrade_fps] を下回る状態が続けば 1 段削り、
## [member CpuSchedulePolicy.restore_fps] を上回る状態が続けば 1 段戻す。
func observe_frame_time(frame_msec: float) -> void:
	_frame_msec_samples.append(maxf(0.0, frame_msec))
	while _frame_msec_samples.size() > _policy.sample_frames:
		_frame_msec_samples.pop_front()

	var fps: float = CpuSchedulePolicy.to_fps(get_average_frame_msec())
	if fps < _policy.degrade_fps:
		_below_frames += 1
		_above_frames = 0
	elif fps > _policy.restore_fps:
		_above_frames += 1
		_below_frames = 0
	else:
		_below_frames = 0
		_above_frames = 0

	if _below_frames >= _policy.sustained_frames:
		_below_frames = 0
		set_level(mini(_level + 1, CpuSchedulePolicy.Level.DETAILED) as CpuSchedulePolicy.Level)
	elif _above_frames >= _policy.sustained_frames:
		_above_frames = 0
		set_level(maxi(_level - 1, CpuSchedulePolicy.Level.NONE) as CpuSchedulePolicy.Level)


## 直近の窓での平均 Frame Time（ミリ秒）を返す。
func get_average_frame_msec() -> float:
	if _frame_msec_samples.is_empty():
		return 0.0
	var total: float = 0.0
	for sample in _frame_msec_samples:
		total += sample
	return total / float(_frame_msec_samples.size())


## 削減段階を設定する（要件定義 §84）。
##
## 段階ごとに、CPU の思考の深さと Detailed の数だけを動かす。
func set_level(level: CpuSchedulePolicy.Level) -> void:
	if level == _level:
		return

	var previous: CpuSchedulePolicy.Level = _level
	_level = level
	_apply_level()
	degradation_changed.emit(previous, _level)


func _apply_level() -> void:
	for player_id in _order:
		var profile: CpuProfile = _cpus.get_profile(player_id)
		if profile == null:
			continue

		# Lookahead（Search Depth）から削る。ここが一番重い（#39 の計測）。
		profile.lookahead = (
			0 if _level >= CpuSchedulePolicy.Level.LOOKAHEAD else _original_lookahead[player_id]
		)

		# 次に Beam Width。読む候補の数を絞る。
		var beam: int = _original_beam_width[player_id]
		if _level >= CpuSchedulePolicy.Level.BEAM:
			beam = maxi(1, int(round(float(beam) * _policy.beam_scale)))
		profile.beam_width = beam

	# 最後に Detailed の数。ここまで来ると見た目も変わる。
	_cpus.set_detailed_limit(
		(
			_policy.degraded_detailed_limit
			if _level >= CpuSchedulePolicy.Level.DETAILED
			else _original_detailed_limit
		)
	)
