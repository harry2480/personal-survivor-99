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
## 出所は [signal PuzzleSession.garbage_event_applied] から受け取る。Router 側で
## 送信の控えを持つと、相殺で消えた Garbage を控えから消せず、出所がずれる。

## Attack が Garbage として送られた。
signal garbage_routed(source_player_id: int, target_player_id: int, line_count: int)

## Garbage が盤面へ適用された。
signal garbage_received(victim_player_id: int, source_player_id: int, line_count: int)

var _manager: BattleManager
var _balance: GameBalance
var _attribution: KoAttribution = KoAttribution.new()
var _next_attack_id: int = 0
# 接続した Session と Callable の組。解除するときに同じ Callable が要る（bind すると別物になる）。
var _connections: Array = []


func _init(manager: BattleManager, balance: GameBalance = null) -> void:
	_manager = manager
	_balance = balance if balance != null else GameBalance.create_default()
	_connect_players()


## KO の帰属記録を返す。
func get_attribution() -> KoAttribution:
	return _attribution


## 購読を解除して参照を切る。
##
## Router は各 Player の signal を購読し、Player 側は Callable として Router を
## 参照する。RefCounted 同士のこの循環は自動では解放されないため、Battle を
## 捨てるときに明示的に切る（Phase 7 の連戦と Phase 10 のリーク検証の前提）。
## [method reset] と違い、接続し直さない。
func dispose() -> void:
	_disconnect_players()
	_attribution.clear()
	_next_attack_id = 0


## 帰属の記録と Attack ID を初期状態へ戻し、現在の Player へ接続し直す。
##
## [method BattleManager.setup] をやり直すと Session が作り直されるので、
## その後に呼ぶ。古い Session との接続はここで解除する。
func reset() -> void:
	_disconnect_players()
	_attribution.clear()
	_next_attack_id = 0
	_connect_players()


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

	# 活性時刻は受け手の Session の時計で決める。適用の判定（GarbageQueue.apply_ready）が
	# その時計で行われるため。Manager の時計とは、Session を個別に進めるとずれる。
	_next_attack_id += 1
	var event: GarbageEvent = GarbageEvent.create(
		source.player_id,
		target.player_id,
		line_count,
		target.session.get_game_time_sec(),
		_balance.garbage_delay_sec,
		attack_type,
		_next_attack_id
	)

	target.session.receive_garbage(event)
	garbage_routed.emit(source.player_id, target.player_id, line_count)
	return true


func _connect_players() -> void:
	for player in _manager.get_players():
		if player.session == null:
			continue
		var on_attack: Callable = _on_attack_generated.bind(player.player_id)
		var on_applied: Callable = _on_garbage_event_applied.bind(player.player_id)
		player.session.attack_generated.connect(on_attack)
		player.session.garbage_event_applied.connect(on_applied)
		_connections.append([player.session, on_attack, on_applied])


func _disconnect_players() -> void:
	for entry in _connections:
		var session: PuzzleSession = entry[0]
		if session.attack_generated.is_connected(entry[1]):
			session.attack_generated.disconnect(entry[1])
		if session.garbage_event_applied.is_connected(entry[2]):
			session.garbage_event_applied.disconnect(entry[2])
	_connections.clear()


func _on_attack_generated(amount: int, context: AttackContext, source_player_id: int) -> void:
	route(source_player_id, amount, context.clear_type)


func _on_garbage_event_applied(
	source_player_id: int, line_count: int, victim_player_id: int
) -> void:
	# 送り元のない Garbage（テスト・単体プレイ用）は攻撃者として記録しない。
	if source_player_id < 0:
		return
	_attribution.record_application(
		victim_player_id, source_player_id, _manager.get_elapsed_sec(), line_count
	)
	garbage_received.emit(victim_player_id, source_player_id, line_count)
