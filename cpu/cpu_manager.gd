class_name CpuManager
extends RefCounted

## Detailed / Lightweight の切り替え（要件定義 §80 / §83）。
##
## 99 体すべてを詳細に動かすと負荷が持たないため（`tools/README.md` の計測）、
## 注目される CPU だけ Detailed にして、残りは Lightweight で回す Hybrid 方式。
##
## **切り替えで指標が飛ばないようにする**（要件定義 §83 / #42 の完了条件）。
## 降格時は盤面から指標を作り、昇格時は指標に合う盤面を組み立てる。

## 方式が変わった。Development Build ではログにも出す（要件定義 §112）。
signal cpu_mode_change(player_id: int, previous: Mode, current: Mode, reason: String)

## Simulation の方式。
enum Mode { LIGHTWEIGHT, DETAILED }

## 同時に Detailed にできる CPU の数の既定値。
const DEFAULT_DETAILED_LIMIT: int = 8

var _manager: BattleManager
var _profiles: Dictionary = {}
var _modes: Dictionary = {}
var _detailed: Dictionary = {}
var _lightweight: Dictionary = {}
var _detailed_limit: int = DEFAULT_DETAILED_LIMIT
var _focus_player_id: int = -1
var _seed: int = 0


func _init(
	manager: BattleManager, cpu_seed: int = 0, detailed_limit: int = DEFAULT_DETAILED_LIMIT
) -> void:
	_manager = manager
	_seed = cpu_seed
	_detailed_limit = maxi(0, detailed_limit)


## CPU を登録する。既定は Lightweight。
func register(player_id: int, profile: CpuProfile) -> void:
	_profiles[player_id] = profile
	_modes[player_id] = Mode.LIGHTWEIGHT
	_lightweight[player_id] = LightweightCpu.new(profile, _seed + player_id)


## Battle の全 CPU を同じ Strength で登録する。
func register_all(mapping: CpuStrengthMapping, strength: float) -> void:
	for player in _manager.get_players():
		if player.player_type == PlayerType.Type.CPU:
			register(player.player_id, mapping.create_profile(strength))


## Battle の全 CPU を Strength の分布に従って登録する（要件定義 §73 / §74）。
##
## 同じ [param distribution_seed] からは同じ配り方になる（#44 の完了条件）。
func register_all_from_distribution(
	distribution: CpuDistribution, mapping: CpuStrengthMapping = null, distribution_seed: int = 0
) -> void:
	var cpu_ids: Array[int] = []
	for player in _manager.get_players():
		if player.player_type == PlayerType.Type.CPU:
			cpu_ids.append(player.player_id)

	var profiles: Array[CpuProfile] = distribution.create_profiles(
		cpu_ids.size(), mapping, distribution_seed
	)
	for index in range(cpu_ids.size()):
		register(cpu_ids[index], profiles[index])


## 登録されている [CpuProfile] を返す。未登録なら [code]null[/code]。
func get_profile(player_id: int) -> CpuProfile:
	return _profiles.get(player_id, null)


## その CPU が Top Out しているかを返す。方式によらず同じ口で答える。
func is_over(player_id: int) -> bool:
	if get_mode(player_id) == Mode.DETAILED:
		return _detailed[player_id].is_over()
	if _lightweight.has(player_id):
		return _lightweight[player_id].is_over()
	return false


## 同時に Detailed にできる数を設定する。
func set_detailed_limit(limit: int) -> void:
	_detailed_limit = maxi(0, limit)


## 同時に Detailed にできる数を返す。
func get_detailed_limit() -> int:
	return _detailed_limit


## UI が注目している CPU を設定する（Detailed 化の候補になる）。
func set_focus_player(player_id: int) -> void:
	_focus_player_id = player_id


## 現在の方式を返す。
func get_mode(player_id: int) -> Mode:
	return _modes.get(player_id, Mode.LIGHTWEIGHT)


## Detailed で動いている CPU の数を返す。
func get_detailed_count() -> int:
	return _detailed.size()


## 登録済みの CPU の ID を返す。
func get_registered_ids() -> Array[int]:
	var ids: Array[int] = []
	for player_id in _profiles:
		ids.append(player_id)
	return ids


## 現在の指標を返す。方式によらず同じ形で返る。
func get_indicators(player_id: int) -> CpuIndicators:
	if get_mode(player_id) == Mode.DETAILED:
		return _detailed[player_id].get_indicators()
	if _lightweight.has(player_id):
		return _lightweight[player_id].get_indicators()
	return CpuIndicators.new()


## 前回取り出してから処理した Garbage 行数を返して 0 に戻す。
##
## x が防御で捌いた行数、y が盤面へ積んだ行数。KO の帰属は y だけを対象にする。
## Lightweight だけが対象。Detailed は盤面を持つので、ここでは (0, 0) を返す。
func take_garbage_result(player_id: int) -> Vector2i:
	if get_mode(player_id) == Mode.LIGHTWEIGHT and _lightweight.has(player_id):
		var cpu: LightweightCpu = _lightweight[player_id]
		return Vector2i(cpu.take_cleared_garbage(), cpu.take_applied_garbage())
	return Vector2i.ZERO


## Detailed 化すべき候補を、優先度の高い順に返す（要件定義 §81）。
##
## 候補は「Human の Target」「Human を Target 中」「UI 注目対象」「危険な CPU」
## 「終盤の生存者」。
func select_detailed_candidates() -> Array[int]:
	var scored: Array = []
	for player_id in _profiles:
		var player: BattlePlayerState = _manager.get_player(player_id)
		if player == null or not player.alive:
			continue
		scored.append([player_id, _score_candidate(player)])

	scored.sort_custom(
		func(left: Array, right: Array) -> bool:
			if left[1] != right[1]:
				return left[1] > right[1]
			return left[0] < right[0]
	)

	var ids: Array[int] = []
	for entry in scored:
		ids.append(entry[0])
	return ids


## 候補に基づいて Detailed / Lightweight を割り当て直す。
func refresh_modes() -> void:
	var candidates: Array[int] = select_detailed_candidates()
	var wanted: Dictionary = {}
	for index in range(mini(_detailed_limit, candidates.size())):
		wanted[candidates[index]] = true

	for player_id in _profiles:
		var should_be_detailed: bool = wanted.has(player_id)
		var is_detailed: bool = get_mode(player_id) == Mode.DETAILED
		if should_be_detailed and not is_detailed:
			promote(player_id, "candidate")
		elif not should_be_detailed and is_detailed:
			demote(player_id, "over_limit")


## Lightweight から Detailed へ上げる（要件定義 §83）。
##
## 指標に合う盤面を組み立ててから切り替えるので、見た目の状態が飛ばない。
func promote(player_id: int, reason: String = "") -> bool:
	if not _profiles.has(player_id) or get_mode(player_id) == Mode.DETAILED:
		return false

	var player: BattlePlayerState = _manager.get_player(player_id)
	if player == null or player.session == null:
		return false

	var indicators: CpuIndicators = get_indicators(player_id)
	_apply_indicators_to_board(player.session.get_board(), indicators)

	# Lightweight が受けて、まだ捌いていない Garbage を Game Core の Queue へ渡す。
	# Queue は前回の降格時の中身が残っているので（その行数は指標へ移してある）、
	# 先に空にしてから入れる。二重に数えないため。
	player.session.get_garbage_queue().clear()
	if indicators.incoming_garbage > 0:
		player.session.receive_garbage_lines(indicators.incoming_garbage)

	_detailed[player_id] = DetailedCpu.new(_profiles[player_id], player.session, _seed + player_id)
	_lightweight.erase(player_id)
	_set_mode(player_id, Mode.DETAILED, reason)
	return true


## Detailed から Lightweight へ下げる（要件定義 §83）。
##
## 盤面から指標を作ってから切り替えるので、指標が飛ばない。
func demote(player_id: int, reason: String = "") -> bool:
	if not _profiles.has(player_id) or get_mode(player_id) == Mode.LIGHTWEIGHT:
		return false

	var indicators: CpuIndicators = get_indicators(player_id)
	var lightweight := LightweightCpu.new(_profiles[player_id], _seed + player_id)
	lightweight.adopt(indicators)

	_lightweight[player_id] = lightweight
	_detailed.erase(player_id)
	_set_mode(player_id, Mode.LIGHTWEIGHT, reason)
	return true


## 全 CPU の時間を進める。Lightweight が出した Attack 行数を ID 付きで返す。
func update(delta_sec: float) -> Dictionary:
	var attacks: Dictionary = {}

	for player_id in _detailed:
		_detailed[player_id].update(delta_sec)

	for player_id in _lightweight:
		var attack: int = _lightweight[player_id].update(delta_sec)
		if attack > 0:
			attacks[player_id] = attack

	return attacks


## CPU 1 体だけ時間を進める（更新の分散。要件定義 §104）。
##
## 出した Attack 行数を返す。分散しても**渡した時間の合計は変わらない**ので、
## Battle の時間整合性は保たれる（#47 の制約）。
func update_player(player_id: int, delta_sec: float) -> int:
	if get_mode(player_id) == Mode.DETAILED:
		_detailed[player_id].update(delta_sec)
		return 0
	if _lightweight.has(player_id):
		return _lightweight[player_id].update(delta_sec)
	return 0


## Garbage を渡す。方式によらず同じ口で受ける（#42 の制約）。
func receive_garbage(player_id: int, line_count: int) -> void:
	if get_mode(player_id) == Mode.DETAILED:
		_detailed[player_id].receive_garbage(line_count)
	elif _lightweight.has(player_id):
		_lightweight[player_id].receive_garbage(line_count)


func _set_mode(player_id: int, mode: Mode, reason: String) -> void:
	var previous: Mode = get_mode(player_id)
	if previous == mode:
		return

	_modes[player_id] = mode
	cpu_mode_change.emit(player_id, previous, mode, reason)

	# Development Build でのみログへ出す（要件定義 §112）。
	if OS.is_debug_build():
		print(
			(
				"cpu_mode_change player=%d %s -> %s reason=%s"
				% [player_id, Mode.keys()[previous], Mode.keys()[mode], reason]
			)
		)


func _score_candidate(player: BattlePlayerState) -> int:
	var score: int = 0

	# UI が注目している CPU。
	if player.player_id == _focus_player_id:
		score += 100

	# Human が狙っている CPU と、Human を狙っている CPU。
	for other in _manager.get_alive_players():
		if not other.is_human():
			continue
		if other.current_target == player.player_id:
			score += 50
		if player.current_target == other.player_id:
			score += 40

	# 危険な CPU。決着が近いので見えるようにしておく。
	score += int(player.danger_level) * 10

	# 終盤の生存者。
	if _manager.get_alive_count() <= 10:
		score += 20

	return score


# 指標に合う盤面を組み立てる。高さと穴の数を合わせ、切り替えで指標が飛ばないようにする。
static func _apply_indicators_to_board(board: Board, indicators: CpuIndicators) -> void:
	if board == null:
		return

	board.clear()
	var height: int = clampi(indicators.stack_height, 0, Board.VISIBLE_HEIGHT)
	if height <= 0:
		return

	for offset in range(height):
		var y: int = Board.TOTAL_HEIGHT - 1 - offset
		for x in range(Board.WIDTH):
			board.set_cell(x, y, GarbageQueue.GARBAGE_CELL)

	# 一番上の行に隙間を開けて、揃った行として消えないようにする。
	board.set_cell(0, Board.TOTAL_HEIGHT - height, Board.EMPTY)

	# 穴を、上から蓋をする形で作る。
	var holes: int = mini(indicators.holes, Board.WIDTH - 1)
	for index in range(holes):
		var x: int = index + 1
		if height >= 2:
			board.set_cell(x, Board.TOTAL_HEIGHT - 1, Board.EMPTY)
