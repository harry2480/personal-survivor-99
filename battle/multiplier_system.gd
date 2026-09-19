class_name MultiplierSystem
extends RefCounted

## Attack Multiplier（要件定義 §57）。
##
## KO 等で得た Attack Points が閾値を超えると Multiplier Stage が上がり、
## Attack 倍率が上がる。閾値と倍率は [GameBalance] のデータで定義する。

## Stage が上がった / 下がった。
signal multiplier_changed(player_id: int, stage: int, multiplier: float)

var _balance: GameBalance


func _init(balance: GameBalance = null) -> void:
	_balance = balance if balance != null else GameBalance.create_default()


## Attack Points を加算し、Stage と倍率を反映する。
func add_attack_points(player: BattlePlayerState, points: int) -> void:
	if player == null or points == 0:
		return

	player.attack_points = maxi(0, player.attack_points + points)
	refresh(player)


## 現在の Attack Points から Stage と倍率を計算し直す。
func refresh(player: BattlePlayerState) -> void:
	if player == null:
		return

	var stage: int = _balance.get_multiplier_stage(player.attack_points)
	var multiplier: float = _balance.get_multiplier_value(stage)
	if is_equal_approx(multiplier, player.attack_multiplier):
		return

	player.attack_multiplier = multiplier
	multiplier_changed.emit(player.player_id, stage, multiplier)


## Player の現在の Stage を返す。
func get_stage(player: BattlePlayerState) -> int:
	return _balance.get_multiplier_stage(player.attack_points) if player != null else 0


## 倍率を適用した Attack を返す（要件定義 §38 の後半）。
static func apply(attack: int, player: BattlePlayerState, attackers_bonus: int = 0) -> int:
	var multiplier: float = player.attack_multiplier if player != null else 1.0
	return AttackCalculator.apply_multipliers(attack, multiplier, attackers_bonus)
