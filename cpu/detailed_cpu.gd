class_name DetailedCpu
extends RefCounted

## 詳細シミュレーション（要件定義 §81）。
##
## 完全な Board State（[PuzzleSession]）を持ち、探索で置き場所を決めて実際に置く。
## 反応遅延・PPS・Misdrop も通るので、Strength の違いが挙動に出る。
##
## Battle Layer から見た口は Lightweight と同じ（Attack を出し、Garbage を受ける）。

var _profile: CpuProfile
var _session: PuzzleSession
var _search: PlacementSearch
var _timing: CpuTiming
var _misdrop: Misdrop
var _metrics: BoardMetrics = BoardMetrics.new()


func _init(profile: CpuProfile, session: PuzzleSession, cpu_seed: int = 0) -> void:
	_profile = profile if profile != null else CpuProfile.create_default()
	_session = session
	_search = PlacementSearch.new(_profile, cpu_seed)
	_timing = CpuTiming.new(_profile)
	_misdrop = Misdrop.new(_profile, cpu_seed + 1)


## 紐付いた Game Core の進行を返す。
func get_session() -> PuzzleSession:
	return _session


## 現在の指標を返す（Lightweight と同じ形）。
func get_indicators() -> CpuIndicators:
	var indicators: CpuIndicators = CpuIndicators.from_board(_session.get_board(), _metrics)
	indicators.skill = CpuIndicators.estimate_skill(_profile)
	indicators.incoming_garbage = _session.get_garbage_queue().get_pending_lines()
	indicators.attack_rate = CpuIndicators.estimate_attack_rate(_profile)
	indicators.defense_rate = CpuIndicators.estimate_defense_rate(_profile)
	return indicators


## 反応が必要な出来事が起きたことを伝える。
func notify_event() -> void:
	_timing.notify_event()


## Garbage を受け取る。受信は反応の対象。
func receive_garbage(line_count: int) -> void:
	_session.receive_garbage_lines(line_count)
	notify_event()


## Top Out しているかを返す。
func is_over() -> bool:
	return _session.is_over()


## 時間を進める。置くべきタイミングになったら 1 手置く。
func update(delta_sec: float) -> void:
	_session.update(delta_sec)
	if _session.is_over():
		return

	if _timing.update(delta_sec):
		place_once()
		_timing.notify_placed()


## 探索で決めた場所へ 1 手置く。置けたら true。
func place_once() -> bool:
	var active: ActivePiece = _session.get_active_piece()
	if not active.is_active():
		return false

	var best: Placement = _search.search(
		_session.get_board(), active.type, _session.get_next_types(2), _get_hold_type()
	)
	if best == null:
		return false

	var chosen: Placement = _misdrop.apply(_session.get_board(), best)

	# 最終的な判断（Misdrop で取り違えた後）に従って Hold する。
	if chosen.uses_hold and _session.get_hold_slot().can_hold():
		_session.hold()
		active = _session.get_active_piece()

	# Hold の取り違えで、選んだ配置が今の Piece のものでなくなった場合は探し直す。
	# 取り違えの結果として出てきた Piece なので、Misdrop はもう掛けない。
	if chosen.piece_type != active.type:
		chosen = _search.search(_session.get_board(), active.type, _session.get_next_types(2))
		if chosen == null:
			return false

	active.rotation = chosen.rotation
	active.position = chosen.position
	_session.hard_drop()
	return true


# Hold したときに出てくる Piece の種類。Hold できなければ -1（候補に入れない）。
# Hold が空なら NEXT の先頭が出てくる（[PlacementSearch] はこの判断を呼び出し側に任せている）。
func _get_hold_type() -> int:
	var hold_slot: HoldSlot = _session.get_hold_slot()
	if not hold_slot.can_hold():
		return -1
	if not hold_slot.is_empty():
		return hold_slot.get_held_type()
	var next_types: Array[int] = _session.get_next_types(1)
	return next_types[0] if not next_types.is_empty() else -1
