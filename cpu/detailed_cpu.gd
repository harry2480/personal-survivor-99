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
	indicators.skill = clampf(_profile.strength / 100.0, 0.0, 2.0)
	indicators.incoming_garbage = _session.get_garbage_queue().get_pending_lines()
	indicators.attack_rate = _profile.pieces_per_second * indicators.skill * 0.25
	indicators.defense_rate = (
		_profile.pieces_per_second * clampf(_profile.garbage_skill, 0.0, 1.0) * 0.5
	)
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
		_session.get_board(), active.type, _session.get_next_types(2)
	)
	if best == null:
		return false

	var chosen: Placement = _misdrop.apply(_session.get_board(), best)

	# Hold の取り違えは種類が変わるので、Hold を使って出し直す。
	if chosen.uses_hold != best.uses_hold and _session.get_hold_slot().can_hold():
		_session.hold()
		return true

	active.rotation = chosen.rotation
	active.position = chosen.position
	_session.hard_drop()
	return true
