class_name BattleManager
extends RefCounted

## Battle 全体の進行管理（要件定義 §18 / §44）。
##
## Player の生成・ID 付与・生存人数・Battle Phase をここで一元管理する。
## Game Core（[PuzzleSession]）は各 Player が持ち、Battle Layer からは公開 API
## 経由でしか触らない（要件定義 §18）。
##
## Presentation は知らない。画面は signal と参照 API から状態を読むだけにする。

## Player が脱落した。
signal player_eliminated(player_id: int, rank: int)

## Battle の段階が変わった（要件定義 §93）。
signal phase_changed(previous: BattlePhase.Phase, current: BattlePhase.Phase)

## Battle が終了した。勝者がいなければ -1。
signal battle_finished(winner_player_id: int)

var _rules: GameRules
var _balance: GameBalance
var _players: Array[BattlePlayerState] = []
var _players_by_id: Dictionary = {}
var _next_player_id: int = 0
var _phase: BattlePhase.Phase = BattlePhase.Phase.OPENING
var _finished: bool = false
var _battle_seed: int = 0
var _elapsed_sec: float = 0.0


func _init(rules: GameRules = null, balance: GameBalance = null) -> void:
	_rules = rules if rules != null else GameRules.create_default()
	_balance = balance if balance != null else GameBalance.create_default()


## Battle を構成する。Human と CPU の人数を指定する（要件定義 §44）。
##
## Seed を指定すると Piece 列が再現できる。Player ごとに Seed をずらすので、
## 全員が同じ並びになることはない。
func setup(human_count: int, cpu_count: int, battle_seed: int = 0) -> void:
	_players.clear()
	_players_by_id.clear()
	_next_player_id = 0
	_finished = false
	_battle_seed = battle_seed
	_elapsed_sec = 0.0

	for _i in range(maxi(0, human_count)):
		add_player(PlayerType.Type.LOCAL_HUMAN)
	for _i in range(maxi(0, cpu_count)):
		add_player(PlayerType.Type.CPU)

	_phase = BattlePhase.from_alive_count(get_alive_count())
	# 0 人・1 人で始めた Battle は、この時点で決着している。
	_check_finished()


## Player を 1 人追加し、一意の ID を付けて返す。
func add_player(type: PlayerType.Type) -> BattlePlayerState:
	var state: BattlePlayerState = BattlePlayerState.create(_next_player_id, type)
	_next_player_id += 1

	# Detailed Simulation 対象として Game Core を紐付ける。
	# Lightweight 化（Phase 5 / #42）はここを差し替える。
	var session := PuzzleSession.new(
		_rules, PieceRandomizer.new(_seed_for(state.player_id)), _balance
	)
	session.start(_seed_for(state.player_id))
	state.attach_session(session)

	_players.append(state)
	_players_by_id[state.player_id] = state
	return state


## 全 Player を返す。
func get_players() -> Array[BattlePlayerState]:
	return _players


## ID から Player を返す。見つからなければ null（Invalid ID を安全に扱う）。
func get_player(player_id: int) -> BattlePlayerState:
	return _players_by_id.get(player_id, null)


## 生存している Player を返す。
func get_alive_players() -> Array[BattlePlayerState]:
	var alive: Array[BattlePlayerState] = []
	for player in _players:
		if player.alive:
			alive.append(player)
	return alive


## 生存人数を返す。
func get_alive_count() -> int:
	var count: int = 0
	for player in _players:
		if player.alive:
			count += 1
	return count


## Player の総数を返す。
func get_player_count() -> int:
	return _players.size()


## 現在の Battle 段階を返す。
func get_phase() -> BattlePhase.Phase:
	return _phase


## Battle が終了しているかを返す。
func is_finished() -> bool:
	return _finished


## Battle の Seed を返す。
func get_battle_seed() -> int:
	return _battle_seed


## Battle 開始からの経過時間（秒）を返す。
##
## KO の帰属判定（適用時刻と判定時刻）がこの時刻を基準にする。
## Garbage の活性時刻は受け手の Session の時計で決める（[GarbageRouter]）。
func get_elapsed_sec() -> float:
	return _elapsed_sec


## 全 Player の時間を進め、Danger Level と Incoming を更新する。
func update(delta_sec: float) -> void:
	if _finished:
		return

	_elapsed_sec += maxf(0.0, delta_sec)

	for player in _players:
		# 同じ update 内の同時 Top Out で Battle が終わったら、勝者を脱落させない。
		if _finished:
			break
		if not player.alive or player.session == null:
			continue

		player.session.update(delta_sec)
		player.refresh_danger_level()
		player.refresh_incoming_garbage()

		if player.session.is_over():
			eliminate_player(player.player_id)


## Player を脱落させる（要件定義 §54）。
##
## 脱落時の生存人数がそのまま順位になる（要件定義 §55）。
## 既に脱落している Player と Invalid ID、Battle 終了後の呼び出しは無視する。
func eliminate_player(player_id: int) -> void:
	if _finished:
		return
	var player: BattlePlayerState = get_player(player_id)
	if player == null or not player.alive:
		return

	player.alive = false
	player.rank = get_alive_count() + 1
	player_eliminated.emit(player.player_id, player.rank)

	_refresh_phase()
	_check_finished()


func _seed_for(player_id: int) -> int:
	# Player ごとに Seed をずらす。Battle Seed を決めれば全体が再現できる。
	return _battle_seed + player_id * 7919


func _refresh_phase() -> void:
	var next_phase: BattlePhase.Phase = BattlePhase.from_alive_count(get_alive_count())
	if next_phase == _phase:
		return

	var previous: BattlePhase.Phase = _phase
	_phase = next_phase
	phase_changed.emit(previous, _phase)


func _check_finished() -> void:
	if _finished or get_alive_count() > 1:
		return

	_finished = true
	var survivors: Array[BattlePlayerState] = get_alive_players()
	if survivors.is_empty():
		battle_finished.emit(-1)
		return

	var winner: BattlePlayerState = survivors[0]
	winner.rank = 1
	battle_finished.emit(winner.player_id)
