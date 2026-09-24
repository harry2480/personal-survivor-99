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


func _init(manager: BattleManager, balance: GameBalance = null) -> void:
	_manager = manager
	_balance = balance if balance != null else GameBalance.create_default()
	_connect_players()


## KO の帰属記録を返す。
func get_attribution() -> KoAttribution:
	return _attribution


## 帰属の記録と Attack ID を初期状態へ戻す。
func reset() -> void:
	_attribution.clear()
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

	target.session.receive_garbage(event)
	garbage_routed.emit(source.player_id, target.player_id, line_count)
	return true


func _connect_players() -> void:
	for player in _manager.get_players():
		if player.session == null:
			continue
		player.session.attack_generated.connect(_on_attack_generated.bind(player.player_id))
		player.session.garbage_event_applied.connect(
			_on_garbage_event_applied.bind(player.player_id)
		)


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
