class_name CpuBattleRunner
extends RefCounted

## Battle を headless で回す（要件定義 §73〜§75 / §115 / §116）。
##
## Strength の配り方（[CpuDistribution]）が結果にどう出るかを見るための仕組み。
## Survivor Scaling の確認（要件定義 §75）、CPU Benchmark（#45）、
## Player 数のスケーリング検証（#46）が使う。
##
## [param human_count] を指定すると Human も混ぜられる（要件定義 §44）。Human の
## 盤面は [PuzzleSession] そのままなので、呼び出し側が操作を与える。
##
## Simulation は **Lightweight 固定**（要件定義 §82）。盤面を持たずに指標だけを
## 進めるので、99 体でも現実的な時間で最後まで回せる。Detailed を混ぜた実戦の
## 更新分散は Phase 7（#47）の担当。
##
## Attack は「送り手 → Target → 受け手」を [TargetManager] と [KoAttribution] を
## 通して流す。Battle Layer の判定（Target 安全性・KO 帰属・Ranking）を
## 再実装しないための形（要件定義 §53 / §56）。

## CPU が脱落した。
signal cpu_eliminated(player_id: int, rank: int)

## 1 フレームぶんの時間（秒）。
const DEFAULT_FRAME_DELTA: float = 1.0 / 60.0

## 1 試合の上限時間（秒）。ここで決着しなければ時間切れとして畳む。
const DEFAULT_TIME_LIMIT_SEC: float = 300.0


## Player 1 人ぶんの結果。
class Result:
	extends RefCounted

	## Player ID。
	var player_id: int = -1

	## この CPU の Strength。
	var strength: float = 0.0

	## 確定した順位（1 が優勝）。
	var rank: int = 0

	## 送った Garbage 行数の合計。
	var attack_sent: int = 0

	## 奪った KO の数。
	var ko_count: int = 0

	## 生存していた時間（秒）。
	var survival_sec: float = 0.0


## 1 フレームの処理時間の記録（要件定義 §102 / §105）。
class FrameStats:
	extends RefCounted

	## 進めたフレーム数。
	var frames: int = 0

	## 1 フレームの平均処理時間（ミリ秒）。
	var average_msec: float = 0.0

	## 1 フレームの最大処理時間（ミリ秒）。
	var max_msec: float = 0.0

	## 平均から見込める FPS。描画を含まない Simulation だけの値。
	var estimated_fps: float = 0.0


var _manager: BattleManager
var _targets: TargetManager
var _cpus: CpuManager
var _attribution: KoAttribution = KoAttribution.new()
var _ko: KoSystem
var _balance: GameBalance
var _strengths: Dictionary = {}
var _attack_sent: Dictionary = {}
var _survival_sec: Dictionary = {}
var _elapsed_sec: float = 0.0
var _timed_out: bool = false
var _combat_eliminations: int = 0

# 受け手ごとの、まだ盤面へ積まれていない Garbage。[送り手 ID, 行数] を届いた順に並べる。
var _pending_garbage: Dictionary = {}
var _on_eliminated: Callable
var _human_connections: Array = []
var _scheduler: CpuScheduler = null
var _frame_count: int = 0
var _frame_usec_total: int = 0
var _frame_usec_max: int = 0


func _init(
	cpu_count: int,
	distribution: CpuDistribution = null,
	mapping: CpuStrengthMapping = null,
	battle_seed: int = 0,
	human_count: int = 0,
	human_rules: GameRules = null
) -> void:
	var rules := GameRules.create_default()
	# Lightweight の CPU は盤面を動かさない。放っておいた盤面が勝手に
	# 積み上がらないよう、Gravity を止める。
	rules.gravity_cells_per_second = 0.0
	_balance = GameBalance.create_default()

	_manager = BattleManager.new(rules, _balance)
	_manager.setup(human_count, cpu_count, battle_seed)
	_targets = TargetManager.new(_manager, battle_seed)
	_ko = KoSystem.new(_manager, _attribution, _balance)
	_cpus = CpuManager.new(_manager, battle_seed, 0)

	_on_eliminated = _record_elimination
	_manager.player_eliminated.connect(_on_eliminated)

	_register_cpus(cpu_count, distribution, mapping, battle_seed)
	# Human は普通のルール（Gravity あり）で遊ぶ。CPU 側の都合で止めた
	# Gravity を人間へ持ち込まない。
	if human_count > 0:
		_apply_human_rules(human_rules if human_rules != null else GameRules.create_default())
	_connect_humans()
	_targets.update_all_targets()


## 購読を解除して参照の循環を切る。捨てる前に必ず呼ぶ。
func dispose() -> void:
	if _manager.player_eliminated.is_connected(_on_eliminated):
		_manager.player_eliminated.disconnect(_on_eliminated)
	for entry in _human_connections:
		var session: PuzzleSession = entry[0]
		session.attack_generated.disconnect(entry[1])
	_human_connections.clear()
	_ko.dispose()


## Battle の進行管理を返す。
func get_manager() -> BattleManager:
	return _manager


## CPU の管理を返す。
func get_cpu_manager() -> CpuManager:
	return _cpus


## Target の管理を返す。
func get_target_manager() -> TargetManager:
	return _targets


## KO と順位の管理を返す。
func get_ko_system() -> KoSystem:
	return _ko


## 経過時間（秒）を返す。
func get_elapsed_sec() -> float:
	return _elapsed_sec


## 時間切れで畳んだかを返す。
func is_timed_out() -> bool:
	return _timed_out


## Top Out で脱落した CPU の数を返す（時間切れで畳んだぶんは含まない）。
func get_combat_elimination_count() -> int:
	return _combat_eliminations


## Player の Strength を返す。
func get_strength(player_id: int) -> float:
	return _strengths.get(player_id, 0.0)


## CPU へ [CpuProfile] を 1 体ずつ割り当て直す（Benchmark 用。要件定義 §115）。
##
## 分布ではなく「この Strength をこの席に」と決めたいときに使う。
## Battle を進める前に呼ぶこと。
func assign_profiles(profiles: Array[CpuProfile]) -> void:
	var index: int = 0
	for player in _manager.get_players():
		if player.player_type != PlayerType.Type.CPU or index >= profiles.size():
			continue
		_cpus.register(player.player_id, profiles[index])
		_strengths[player.player_id] = profiles[index].strength
		index += 1


## 決着まで進める。決着したら [code]true[/code]。
##
## [param time_limit_sec] を超えたら、盤面が悪い順に畳んで順位を確定させる。
## 実力が拮抗すると Garbage を相殺し合って決着しないため、上限を必ず設ける。
## 何人が実際に Top Out したかは [method get_combat_elimination_count] で分かる。
##
## [param delta_sec] が 0 以下だと時間が進まず上限に届かないので、何もせず返す。
func run(
	time_limit_sec: float = DEFAULT_TIME_LIMIT_SEC, delta_sec: float = DEFAULT_FRAME_DELTA
) -> bool:
	if delta_sec <= 0.0:
		return _manager.is_finished()

	while _elapsed_sec < time_limit_sec and not _manager.is_finished():
		step(delta_sec)

	if not _manager.is_finished():
		# 分散の途中で終わると CPU ごとに進んだ時間がばらつくので、渡しきる。
		if _scheduler != null:
			_dispatch_attacks(_scheduler.flush())
			_attribute_applied_garbage()
			_eliminate_topped_out()
		if not _manager.is_finished():
			_timed_out = true
			_finish_by_standing()
	return _manager.is_finished()


## 1 フレームぶん進める。
##
## 1 フレームにかかった実時間も測る（#46 の完了条件）。
func step(delta_sec: float) -> void:
	if _manager.is_finished():
		return

	var started_usec: int = Time.get_ticks_usec()

	_elapsed_sec += maxf(0.0, delta_sec)
	_manager.update(delta_sec)

	var attacks: Dictionary = (
		_scheduler.update(delta_sec) if _scheduler != null else _cpus.update(delta_sec)
	)
	_attribute_applied_garbage()

	# BattleManager.update() は盤面から危険度を計算し直す。Runner の盤面は動かないので、
	# Lightweight の指標を写してから Target を選ぶ（Danger / Counter が正しく効くように）。
	_sync_battle_state()
	_targets.update_all_targets()

	_dispatch_attacks(attacks)

	_sync_battle_state()
	_eliminate_topped_out()

	var elapsed_usec: int = Time.get_ticks_usec() - started_usec
	_record_frame_time(elapsed_usec)
	if _scheduler != null:
		_scheduler.observe_frame_time(float(elapsed_usec) / 1000.0)


## 1 フレームの処理時間の記録を返す（要件定義 §102 / §105）。
##
## FPS 換算は上限を 1000 で止める。それより上は測っても意味がないため。
func get_frame_stats() -> FrameStats:
	var stats := FrameStats.new()
	stats.frames = _frame_count
	stats.max_msec = float(_frame_usec_max) / 1000.0
	if _frame_count > 0:
		stats.average_msec = float(_frame_usec_total) / float(_frame_count) / 1000.0
	stats.estimated_fps = (
		1000.0 if stats.average_msec <= 0.0 else minf(1000.0, 1000.0 / stats.average_msec)
	)
	return stats


## CPU の更新を分散する（要件定義 §104 / #47）。
##
## 有効にすると、毎フレーム全体を動かす代わりに [CpuScheduler] が組に分けて回す。
func enable_scheduling(policy: CpuSchedulePolicy = null) -> CpuScheduler:
	_scheduler = CpuScheduler.new(_cpus, policy)
	return _scheduler


## 使っている [CpuScheduler] を返す。分散していなければ [code]null[/code]。
func get_scheduler() -> CpuScheduler:
	return _scheduler


## Detailed で動いている CPU の数を返す（要件定義 §81）。
func get_detailed_count() -> int:
	return _cpus.get_detailed_count()


## Human の Player を返す（操作を与えるのは呼び出し側）。
func get_human_players() -> Array[BattlePlayerState]:
	var humans: Array[BattlePlayerState] = []
	for player in _manager.get_players():
		if player.is_human():
			humans.append(player)
	return humans


## 結果を順位の昇順で返す。
func get_results() -> Array[Result]:
	var results: Array[Result] = []
	for player in _manager.get_players():
		var result := Result.new()
		result.player_id = player.player_id
		result.strength = get_strength(player.player_id)
		result.rank = player.rank
		result.attack_sent = _attack_sent.get(player.player_id, 0)
		result.ko_count = player.ko_count
		result.survival_sec = _survival_sec.get(player.player_id, _elapsed_sec)
		results.append(result)

	results.sort_custom(func(left: Result, right: Result) -> bool: return left.rank < right.rank)
	return results


func _register_cpus(
	cpu_count: int, distribution: CpuDistribution, mapping: CpuStrengthMapping, battle_seed: int
) -> void:
	var settings: CpuDistribution = (
		distribution if distribution != null else CpuDistribution.create_default()
	)
	var profiles: Array[CpuProfile] = settings.create_profiles(cpu_count, mapping, battle_seed)

	var index: int = 0
	for player in _manager.get_players():
		if player.player_type != PlayerType.Type.CPU or index >= profiles.size():
			continue
		var profile: CpuProfile = profiles[index]
		_cpus.register(player.player_id, profile)
		_strengths[player.player_id] = profile.strength
		index += 1


# Lightweight の指標を Battle Layer 側の状態へ写す。
#
# Target の選択（Danger / Counter）と UI が読むのは Battle 側の値なので、
# 盤面を持たない CPU でも同じ形で見えるようにしておく。
func _sync_battle_state() -> void:
	for player in _manager.get_alive_players():
		# Human は盤面を持っているので [BattleManager] の更新が正しい。
		if player.is_human():
			continue
		var indicators: CpuIndicators = _cpus.get_indicators(player.player_id)
		player.danger_level = indicators.danger_level
		player.incoming_garbage = indicators.incoming_garbage


# Human の盤面を、人間向けのルールで作り直す。
func _apply_human_rules(rules: GameRules) -> void:
	for player in _manager.get_players():
		if not player.is_human():
			continue
		var player_seed: int = _manager.get_seed_for(player.player_id)
		var session := PuzzleSession.new(rules, PieceRandomizer.new(player_seed), _balance)
		session.start(player_seed)
		player.attach_session(session)


# Human の盤面が出した Attack も同じ経路へ載せる（要件定義 §40）。
func _connect_humans() -> void:
	for player in _manager.get_players():
		if not player.is_human() or player.session == null:
			continue
		var on_attack: Callable = _on_human_attack.bind(player.player_id)
		player.session.attack_generated.connect(on_attack)
		_human_connections.append([player.session, on_attack])


func _on_human_attack(amount: int, _context: AttackContext, source_id: int) -> void:
	_send_attack(source_id, amount)


func _record_frame_time(elapsed_usec: int) -> void:
	_frame_count += 1
	_frame_usec_total += elapsed_usec
	_frame_usec_max = maxi(_frame_usec_max, elapsed_usec)


func _dispatch_attacks(attacks: Dictionary) -> void:
	for source_id in attacks:
		_send_attack(source_id, attacks[source_id])


func _send_attack(source_id: int, line_count: int) -> void:
	if line_count <= 0:
		return

	var source: BattlePlayerState = _manager.get_player(source_id)
	if source == null or not source.alive:
		return

	var target: BattlePlayerState = _manager.get_player(source.current_target)
	if target == null or not target.is_targetable() or target.player_id == source_id:
		return

	# Attack Multiplier は Battle Layer の規則（要件定義 §57）。CPU 側で
	# 作り直さず、Battle が持っている倍率をそのまま掛ける。
	var sent: int = MultiplierSystem.apply(line_count, source)

	if target.is_human():
		# Human の盤面へ積まれる時点は Runner から見えないので、送った時点で記録する。
		target.session.receive_garbage_lines(sent, source_id)
		_attribution.record_application(target.player_id, source_id, _elapsed_sec, sent)
	elif _cpus.get_mode(target.player_id) == CpuManager.Mode.DETAILED:
		# Detailed も盤面を持つので、Human と同じく送った時点で記録する。
		_cpus.receive_garbage(target.player_id, sent)
		_attribution.record_application(target.player_id, source_id, _elapsed_sec, sent)
	else:
		_cpus.receive_garbage(target.player_id, sent)
		# KO の帰属は、盤面へ実際に積まれた時点で記録する（_attribute_applied_garbage）。
		var queue: Array = _pending_garbage.get(target.player_id, [])
		queue.append([source_id, sent])
		_pending_garbage[target.player_id] = queue
	_attack_sent[source_id] = _attack_sent.get(source_id, 0) + sent


# この更新で盤面へ積まれた Garbage だけを KO 帰属に記録する（要件定義 §56）。
#
# 防御で捌いた行は古い順に消し、残りを送り手ごとにまとめて記録する。
# 送っただけで積まれていない Attack や、捌かれて消えた Attack には KO を付けない。
func _attribute_applied_garbage() -> void:
	for victim_id in _pending_garbage:
		var queue: Array = _pending_garbage[victim_id]
		var result: Vector2i = _cpus.take_garbage_result(victim_id)
		_consume_garbage(queue, result.x, -1)
		_consume_garbage(queue, result.y, victim_id)


# queue の先頭から line_count 行を取り除く。victim_id が 0 以上なら、取り除いた行を
# 送り手ごとに KO 帰属へ記録する。
func _consume_garbage(queue: Array, line_count: int, victim_id: int) -> void:
	var remaining: int = line_count
	while remaining > 0 and not queue.is_empty():
		var entry: Array = queue[0]
		var lines: int = mini(remaining, entry[1])
		if victim_id >= 0:
			_attribution.record_application(victim_id, entry[0], _elapsed_sec, lines)
		entry[1] -= lines
		remaining -= lines
		if entry[1] <= 0:
			queue.pop_front()


func _eliminate_topped_out() -> void:
	for player in _manager.get_alive_players():
		# 同時に Top Out しても、Battle が終わった後の脱落は成立しない（勝者は残る）。
		if _manager.is_finished():
			return
		# Human は盤面を持っているので [BattleManager] が落とす。
		if player.is_human():
			continue
		if not _cpus.is_over(player.player_id):
			continue
		_manager.eliminate_player(player.player_id)
		if not player.alive:
			_combat_eliminations += 1


# 時間切れのときに、盤面が悪い順へ畳んで順位を確定させる。
#
# 畳んだ脱落は Top Out ではないので KO にしない。KoSystem は脱落の理由を
# 区別せず直近の攻撃者に KO を付けるため、先に攻撃の履歴を消しておく。
func _finish_by_standing() -> void:
	_attribution.clear()
	_pending_garbage.clear()
	while _manager.get_alive_count() > 1:
		var worst_id: int = _find_worst_standing()
		if worst_id < 0:
			return
		_manager.eliminate_player(worst_id)


func _find_worst_standing() -> int:
	var worst_id: int = -1
	var worst_score: int = 0

	for player in _manager.get_alive_players():
		# 高く積んでいるほど、穴が多いほど先に落ちたとみなす。
		#
		# Strength は見ない。Benchmark の結果が「強いほど上位」に寄るのは
		# 戦った結果であるべきで、畳み方で作ってはいけない。
		var indicators: CpuIndicators = (
			CpuIndicators.from_board(player.get_board())
			if player.is_human()
			else _cpus.get_indicators(player.player_id)
		)
		var score: int = indicators.stack_height * 100 + indicators.holes * 10
		if worst_id < 0 or score > worst_score:
			worst_id = player.player_id
			worst_score = score

	return worst_id


func _record_elimination(player_id: int, rank: int) -> void:
	_survival_sec[player_id] = _elapsed_sec
	cpu_eliminated.emit(player_id, rank)
