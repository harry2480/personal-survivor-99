class_name TargetManager
extends RefCounted

## 攻撃先の選択（要件定義 §47〜§53）。
##
## **Target 安全性を最優先で満たす**（要件定義 §53）。99 人戦では Target 周りが
## Crash 要因になりやすいため、候補の絞り込みをすべて 1 箇所へ通す。
## [br]・自分を狙わない
## [br]・Dead Player を狙わない
## [br]・Target 消失時に Crash しない
## [br]・残り 1 人なら Target 処理を止める
## [br]・Invalid ID を安全に処理する
##
## 選択は Seed 付きの [RandomNumberGenerator] で行うので再現できる（要件定義 §110）。
## グローバル乱数は使わない。

## Target が変わった（要件定義 §108）。
signal target_changed(player_id: int, previous_target: int, current_target: int)

var _manager: BattleManager
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _counter_tie_break: TargetMode.CounterTieBreak = TargetMode.CounterTieBreak.MOST_DANGEROUS
var _manual_targets: Dictionary = {}


func _init(manager: BattleManager, target_seed: int = 0) -> void:
	_manager = manager
	_rng.seed = target_seed


## Seed を指定して選択をやり直せるようにする。
func reset(target_seed: int) -> void:
	_rng.seed = target_seed
	_manual_targets.clear()


## Counter Target の候補が複数いる場合の選び方を設定する（要件定義 §51）。
func set_counter_tie_break(tie_break: TargetMode.CounterTieBreak) -> void:
	_counter_tie_break = tie_break


## 現在の Counter Target の選び方を返す。
func get_counter_tie_break() -> TargetMode.CounterTieBreak:
	return _counter_tie_break


## Manual Target を指定する（要件定義 §52）。
##
## 自分自身・脱落済み・存在しない ID は受け付けない。
## [constant TargetMode.NO_TARGET] を渡すと Auto へ戻る。
func set_manual_target(player_id: int, target_id: int) -> bool:
	var player: BattlePlayerState = _manager.get_player(player_id)
	if player == null:
		return false

	if target_id == TargetMode.NO_TARGET:
		_manual_targets.erase(player_id)
		return true

	if not _is_valid_target(player, target_id):
		return false

	_manual_targets[player_id] = target_id
	return true


## Manual Target を解除し、Auto へ戻す。
func clear_manual_target(player_id: int) -> void:
	_manual_targets.erase(player_id)


## Manual Target が指定されているかを返す。
func has_manual_target(player_id: int) -> bool:
	return _manual_targets.has(player_id)


## Manual Target の指定先を返す。無ければ [constant TargetMode.NO_TARGET]。
func get_manual_target(player_id: int) -> int:
	return _manual_targets.get(player_id, TargetMode.NO_TARGET)


## Target を選び直し、[member BattlePlayerState.current_target] へ反映する。
##
## 選んだ Player ID を返す。候補がいなければ [constant TargetMode.NO_TARGET]。
func update_target(player_id: int) -> int:
	var player: BattlePlayerState = _manager.get_player(player_id)
	if player == null:
		return TargetMode.NO_TARGET

	var next_target: int = select_target(player)
	if next_target == player.current_target:
		return next_target

	var previous: int = player.current_target
	player.current_target = next_target
	target_changed.emit(player.player_id, previous, next_target)
	return next_target


## 全 Player の Target を選び直す。
func update_all_targets() -> void:
	for player in _manager.get_alive_players():
		update_target(player.player_id)


## Target を選ぶ。[member BattlePlayerState.current_target] は変更しない。
func select_target(player: BattlePlayerState) -> int:
	# 安全性の条件（要件定義 §53）をここで先に通す。
	if not _can_select(player):
		return TargetMode.NO_TARGET

	# Manual は Auto より優先。指定先が脱落していれば Auto へ戻る（§52）。
	var manual: int = _resolve_manual_target(player)
	if manual != TargetMode.NO_TARGET:
		return manual

	var candidates: Array[BattlePlayerState] = get_candidates(player)
	if candidates.is_empty():
		return TargetMode.NO_TARGET

	return _select_by_mode(player, candidates)


# 選択そのものを行える状態かを返す（要件定義 §53）。
# 残り 1 人なら Target 処理を止める。
func _can_select(player: BattlePlayerState) -> bool:
	if player == null or not player.alive:
		return false
	return _manager.get_alive_count() > 1


# Manual 指定があれば返す。指定先が無効なら解除して NO_TARGET を返す（§52）。
func _resolve_manual_target(player: BattlePlayerState) -> int:
	var manual: int = get_manual_target(player.player_id)
	if manual == TargetMode.NO_TARGET:
		return TargetMode.NO_TARGET
	if _is_valid_target(player, manual):
		return manual

	clear_manual_target(player.player_id)
	return TargetMode.NO_TARGET


func _select_by_mode(player: BattlePlayerState, candidates: Array[BattlePlayerState]) -> int:
	match player.target_mode:
		TargetMode.Mode.KO:
			return _select_most_dangerous(candidates)
		TargetMode.Mode.BADGE:
			return _select_most_badges(candidates)
		TargetMode.Mode.COUNTER:
			return _select_counter(player, candidates)
	return _select_random(candidates)


## 攻撃対象になりうる Player を返す（要件定義 §53）。
##
## 自分自身と脱落済み Player は必ず除外する。
func get_candidates(player: BattlePlayerState) -> Array[BattlePlayerState]:
	var candidates: Array[BattlePlayerState] = []
	if player == null:
		return candidates

	for other in _manager.get_players():
		if other.player_id == player.player_id:
			continue
		if not other.is_targetable():
			continue
		candidates.append(other)
	return candidates


## 指定した Player を狙っている Player を返す（Counter Target 用）。
func get_attackers_of(player_id: int) -> Array[BattlePlayerState]:
	var attackers: Array[BattlePlayerState] = []
	for other in _manager.get_alive_players():
		if other.player_id != player_id and other.current_target == player_id:
			attackers.append(other)
	return attackers


# Target として妥当かを返す。自分自身・脱落済み・存在しない ID を弾く（§53）。
func _is_valid_target(player: BattlePlayerState, target_id: int) -> bool:
	if target_id == player.player_id:
		return false

	var target: BattlePlayerState = _manager.get_player(target_id)
	return target != null and target.is_targetable()


func _select_random(candidates: Array[BattlePlayerState]) -> int:
	return candidates[_rng.randi_range(0, candidates.size() - 1)].player_id


func _select_most_dangerous(candidates: Array[BattlePlayerState]) -> int:
	var best: BattlePlayerState = candidates[0]
	for candidate in candidates:
		if candidate.danger_level > best.danger_level:
			best = candidate
		elif candidate.danger_level == best.danger_level and candidate.player_id < best.player_id:
			# 同じ危険度なら ID の小さい方。選択を決定論的にするため。
			best = candidate
	return best.player_id


func _select_most_badges(candidates: Array[BattlePlayerState]) -> int:
	var best: BattlePlayerState = candidates[0]
	for candidate in candidates:
		if candidate.attack_points > best.attack_points:
			best = candidate
		elif candidate.attack_points == best.attack_points and candidate.player_id < best.player_id:
			best = candidate
	return best.player_id


func _select_counter(player: BattlePlayerState, candidates: Array[BattlePlayerState]) -> int:
	var attackers: Array[BattlePlayerState] = []
	for candidate in candidates:
		if candidate.current_target == player.player_id:
			attackers.append(candidate)

	# 誰にも狙われていなければ Random へ落とす。
	if attackers.is_empty():
		return _select_random(candidates)

	match _counter_tie_break:
		TargetMode.CounterTieBreak.MOST_DANGEROUS:
			return _select_most_dangerous(attackers)
		TargetMode.CounterTieBreak.LOWEST_ID:
			return _select_lowest_id(attackers)
	return _select_random(attackers)


func _select_lowest_id(candidates: Array[BattlePlayerState]) -> int:
	var best: BattlePlayerState = candidates[0]
	for candidate in candidates:
		if candidate.player_id < best.player_id:
			best = candidate
	return best.player_id
