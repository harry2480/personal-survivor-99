class_name GarbageRouter
extends RefCounted

## Player 間で Attack を Garbage として送受信する（要件定義 §40〜§42 / §56）。
##
## Game Core の Garbage 処理を**再実装しない**。[PuzzleSession] が自分の Incoming と
## 相殺したうえで余剰を [signal PuzzleSession.attack_generated] として出すので、
## Router はそれを Target の [PuzzleSession] へ渡すだけ。
## 相殺の順序（生成 → 相殺 → 送信）は Game Core 側で守られている。
##
## Garbage が盤面へ適用されたら [KoAttribution] に記録し、KO の原因になった
## 攻撃者を後から特定できるようにする（要件定義 §56）。

## Attack が Garbage として送られた。
signal garbage_routed(source_player_id: int, target_player_id: int, line_count: int)

## Garbage が盤面へ適用された。
signal garbage_received(victim_player_id: int, source_player_id: int, line_count: int)

var _manager: BattleManager
var _balance: GameBalance
var _attribution: KoAttribution = KoAttribution.new()
var _next_attack_id: int = 0
# 各 Player へ「いま届こうとしている Garbage」の出所。適用時の記録に使う。
var _pending_sources: Dictionary = {}


func _init(manager: BattleManager, balance: GameBalance = null) -> void:
	_manager = manager
	_balance = balance if balance != null else GameBalance.create_default()
	_connect_players()


## KO の帰属記録を返す。
func get_attribution() -> KoAttribution:
	return _attribution


## 記録と受け渡し待ちの状態を捨てる。
func reset() -> void:
	_attribution.clear()
	_pending_sources.clear()
	_next_attack_id = 0


## 送信元から Target へ Garbage を送る。
##
## Target がいない、または行数が 0 のときは何もしない。
func route(source_player_id: int, line_count: int, attack_type: LineClear.Type) -> bool:
	if line_count <= 0:
		return false

	var source: BattlePlayerState = _manager.get_player(source_player_id)
	if source == null or not source.alive:
		return false

	var target: BattlePlayerState = _manager.get_player(source.current_target)
	if target == null or not target.is_targetable() or target.player_id == source.player_id:
		return false

	_next_attack_id += 1
	var event: GarbageEvent = GarbageEvent.create(
		source.player_id,
		target.player_id,
		line_count,
		_manager.get_elapsed_sec(),
		_balance.garbage_delay_sec,
		attack_type,
		_next_attack_id
	)

	_remember_source(target.player_id, source.player_id, line_count)
	target.session.receive_garbage(event)
	garbage_routed.emit(source.player_id, target.player_id, line_count)
	return true


# 適用時に「誰から来たか」を復元するための控え。
func _remember_source(victim_id: int, source_id: int, line_count: int) -> void:
	var pending: Array = _pending_sources.get(victim_id, [])
	pending.append([source_id, line_count])
	_pending_sources[victim_id] = pending


func _connect_players() -> void:
	for player in _manager.get_players():
		if player.session == null:
			continue
		player.session.attack_generated.connect(_on_attack_generated.bind(player.player_id))
		player.session.garbage_applied.connect(_on_garbage_applied.bind(player.player_id))


func _on_attack_generated(amount: int, context: AttackContext, source_player_id: int) -> void:
	route(source_player_id, amount, context.clear_type)


func _on_garbage_applied(line_count: int, victim_player_id: int) -> void:
	var applied_time: float = _manager.get_elapsed_sec()
	var remaining: int = line_count
	var pending: Array = _pending_sources.get(victim_player_id, [])

	# 古い順に、適用された行数ぶんだけ出所を割り当てる。
	while remaining > 0 and not pending.is_empty():
		var entry: Array = pending[0]
		var source_id: int = entry[0]
		var lines: int = mini(entry[1], remaining)

		_attribution.record_application(victim_player_id, source_id, applied_time, lines)
		garbage_received.emit(victim_player_id, source_id, lines)

		remaining -= lines
		entry[1] -= lines
		if entry[1] <= 0:
			pending.pop_front()

	_pending_sources[victim_player_id] = pending
