class_name CpuBattleRunner
extends RefCounted

## CPU 同士の Battle を headless で回す（要件定義 §73〜§75 / §115）。
##
## Strength の配り方（[CpuDistribution]）が結果にどう出るかを見るための仕組み。
## Survivor Scaling の確認（要件定義 §75）と CPU Benchmark（#45）が使う。
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
var _on_eliminated: Callable


func _init(
	cpu_count: int,
	distribution: CpuDistribution = null,
	mapping: CpuStrengthMapping = null,
	battle_seed: int = 0
) -> void:
	var rules := GameRules.create_default()
	# Lightweight の CPU は盤面を動かさない。放っておいた盤面が勝手に
	# 積み上がらないよう、Gravity を止める。
	rules.gravity_cells_per_second = 0.0
	_balance = GameBalance.create_default()

	_manager = BattleManager.new(rules, _balance)
	_manager.setup(0, cpu_count, battle_seed)
	_targets = TargetManager.new(_manager, battle_seed)
	_ko = KoSystem.new(_manager, _attribution, _balance)
	_cpus = CpuManager.new(_manager, battle_seed, 0)

	_on_eliminated = _record_elimination
	_manager.player_eliminated.connect(_on_eliminated)

	_register_cpus(cpu_count, distribution, mapping, battle_seed)
	_targets.update_all_targets()


## 購読を解除して参照の循環を切る。捨てる前に必ず呼ぶ。
func dispose() -> void:
	if _manager.player_eliminated.is_connected(_on_eliminated):
		_manager.player_eliminated.disconnect(_on_eliminated)
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
		_timed_out = true
		_finish_by_standing()
	return _manager.is_finished()


## 1 フレームぶん進める。
func step(delta_sec: float) -> void:
	if _manager.is_finished():
		return

	_elapsed_sec += maxf(0.0, delta_sec)
	_manager.update(delta_sec)
	_targets.update_all_targets()

	var attacks: Dictionary = _cpus.update(delta_sec)
	for source_id in attacks:
		_send_attack(source_id, attacks[source_id])

	_sync_battle_state()
	_eliminate_topped_out()


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
		var indicators: CpuIndicators = _cpus.get_indicators(player.player_id)
		player.danger_level = indicators.danger_level
		player.incoming_garbage = indicators.incoming_garbage


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

	_cpus.receive_garbage(target.player_id, sent)
	_attribution.record_application(target.player_id, source_id, _elapsed_sec, sent)
	_attack_sent[source_id] = _attack_sent.get(source_id, 0) + sent


func _eliminate_topped_out() -> void:
	for player in _manager.get_alive_players():
		if _cpus.is_over(player.player_id):
			_combat_eliminations += 1
			_manager.eliminate_player(player.player_id)


# 時間切れのときに、盤面が悪い順へ畳んで順位を確定させる。
#
# 畳んだ脱落は Top Out ではないので KO にしない。KoSystem は脱落の理由を
# 区別せず直近の攻撃者に KO を付けるため、先に攻撃の履歴を消しておく。
func _finish_by_standing() -> void:
	_attribution.clear()
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
		var indicators: CpuIndicators = _cpus.get_indicators(player.player_id)
		var score: int = indicators.stack_height * 100 + indicators.holes * 10
		if worst_id < 0 or score > worst_score:
			worst_id = player.player_id
			worst_score = score

	return worst_id


func _record_elimination(player_id: int, rank: int) -> void:
	_survival_sec[player_id] = _elapsed_sec
	cpu_eliminated.emit(player_id, rank)
