class_name KoSystem
extends RefCounted

## 脱落と KO の帰属（要件定義 §54 / §56 / §57）。
##
## Top Out した Player を脱落させ、KO の原因になった攻撃者に手柄（ko_count と
## Attack Points）を与える。誰の手柄にするかは [KoRule] が決めるので、判定方法を
## 差し替えられる。
##
## 脱落後は Simulation / Attack / Target の対象から外れる。対象外にする処理自体は
## [BattleManager]（Simulation）と [TargetManager]（Target）と [GarbageRouter]
## （Attack）がそれぞれ持っており、ここでは alive を落とすことで一括して効かせる。

## Player が KO された。攻撃者がいない場合は -1（自滅）。
signal player_ko(victim_player_id: int, attacker_player_id: int)

## 順位が確定した。
signal rank_changed(player_id: int, rank: int)

var _manager: BattleManager
var _balance: GameBalance
var _rule: KoRule
var _attribution: KoAttribution
var _ranking: RankingSystem
var _multiplier: MultiplierSystem


func _init(
	manager: BattleManager,
	attribution: KoAttribution,
	balance: GameBalance = null,
	rule: KoRule = null
) -> void:
	_manager = manager
	_attribution = attribution
	_balance = balance if balance != null else GameBalance.create_default()
	_rule = rule if rule != null else KoRule.new(_balance.ko_attribution_window_sec)
	_ranking = RankingSystem.new()
	_multiplier = MultiplierSystem.new(_balance)

	_manager.player_eliminated.connect(_on_player_eliminated)
	_manager.battle_finished.connect(_on_battle_finished)


## 購読を解除して参照を切る（[method GarbageRouter.dispose] と同じ理由）。
func dispose() -> void:
	if _manager.player_eliminated.is_connected(_on_player_eliminated):
		_manager.player_eliminated.disconnect(_on_player_eliminated)
	if _manager.battle_finished.is_connected(_on_battle_finished):
		_manager.battle_finished.disconnect(_on_battle_finished)


## 順位の管理を返す。
func get_ranking() -> RankingSystem:
	return _ranking


## Attack Multiplier の管理を返す。
func get_multiplier_system() -> MultiplierSystem:
	return _multiplier


## KO の帰属判定を差し替える（要件定義 §56）。
func set_rule(rule: KoRule) -> void:
	if rule != null:
		_rule = rule


## 現在の判定ルールを返す。
func get_rule() -> KoRule:
	return _rule


func _on_player_eliminated(victim_player_id: int, rank: int) -> void:
	_ranking.record_elimination(victim_player_id, _manager.get_alive_count())
	rank_changed.emit(victim_player_id, rank)

	var attacker_id: int = _rule.determine_attacker(
		_attribution, victim_player_id, _manager.get_elapsed_sec()
	)
	# 攻撃者が先に脱落していても、帰属した KO は戦績に残す。
	# 脱落者は Attack を送れないので、Attack Points が増えても影響しない。
	var attacker: BattlePlayerState = _manager.get_player(attacker_id)
	if attacker != null:
		attacker.ko_count += 1
		_multiplier.add_attack_points(attacker, _balance.ko_attack_points)

	# 購読者が通知中に戦績を読んでも最新になるよう、更新の後に通知する。
	player_ko.emit(victim_player_id, attacker_id)


func _on_battle_finished(winner_player_id: int) -> void:
	var winner: BattlePlayerState = _manager.get_player(winner_player_id)
	if winner == null:
		return

	_ranking.record_winner(winner_player_id)
	rank_changed.emit(winner_player_id, RankingSystem.WINNER_RANK)
