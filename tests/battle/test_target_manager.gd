extends GutTest

## Target 選択の Unit テスト（要件定義 §47〜§53）。
##
## 安全性 5 条件（§53）を先に確かめる。99 人戦の Crash 要因になりやすいため。

const SEED: int = 20260920

var manager: BattleManager
var targets: TargetManager


func before_each() -> void:
	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	manager = BattleManager.new(rules)
	manager.setup(1, 4, SEED)
	targets = TargetManager.new(manager, SEED)


func _player(player_id: int) -> BattlePlayerState:
	return manager.get_player(player_id)


func _set_mode(player_id: int, mode: TargetMode.Mode) -> void:
	_player(player_id).target_mode = mode


# --- Target 安全性（要件定義 §53） ------------------------------------------


func test_never_targets_itself() -> void:
	for mode in TargetMode.AUTO_MODES:
		for player in manager.get_players():
			player.target_mode = mode
			for _attempt in range(20):
				assert_ne(
					targets.select_target(player),
					player.player_id,
					"%s で自分を狙わない" % TargetMode.get_mode_name(mode)
				)


func test_never_targets_a_dead_player() -> void:
	manager.eliminate_player(2)
	manager.eliminate_player(3)

	for mode in TargetMode.AUTO_MODES:
		_set_mode(0, mode)
		for _attempt in range(30):
			var target: int = targets.select_target(_player(0))
			assert_true(_player(target).alive, "脱落した Player を狙わない")


func test_losing_the_target_does_not_crash() -> void:
	_set_mode(0, TargetMode.Mode.RANDOM)
	targets.update_target(0)
	var target_id: int = _player(0).current_target
	assert_ne(target_id, TargetMode.NO_TARGET, "前提: Target がいる")

	manager.eliminate_player(target_id)

	var next_target: int = targets.update_target(0)
	assert_ne(next_target, target_id, "Target が切り替わる")
	assert_true(_player(next_target).alive, "生きている相手になる")


func test_stops_targeting_when_one_player_remains() -> void:
	for player_id in [1, 2, 3, 4]:
		manager.eliminate_player(player_id)

	assert_eq(targets.select_target(_player(0)), TargetMode.NO_TARGET, "残り 1 人なら Target なし")
	assert_eq(targets.update_target(0), TargetMode.NO_TARGET, "反映しても Target なし")


func test_invalid_id_is_handled_safely() -> void:
	assert_eq(targets.update_target(999), TargetMode.NO_TARGET, "存在しない ID は安全に処理する")
	assert_eq(targets.select_target(null), TargetMode.NO_TARGET, "null でも落ちない")
	assert_false(targets.set_manual_target(999, 1), "存在しない ID の Manual 指定は拒否する")
	assert_false(targets.set_manual_target(0, 999), "存在しない相手の指定も拒否する")


func test_dead_player_does_not_pick_a_target() -> void:
	manager.eliminate_player(0)

	assert_eq(targets.select_target(_player(0)), TargetMode.NO_TARGET, "脱落者は Target を持たない")


# --- Auto Target Mode ------------------------------------------------------


func test_random_target_varies() -> void:
	_set_mode(0, TargetMode.Mode.RANDOM)
	var seen: Dictionary = {}

	for _attempt in range(50):
		seen[targets.select_target(_player(0))] = true

	assert_gt(seen.size(), 1, "毎回同じ相手にはならない")


func test_random_target_is_reproducible() -> void:
	_set_mode(0, TargetMode.Mode.RANDOM)
	var first: Array[int] = []
	for _attempt in range(20):
		first.append(targets.select_target(_player(0)))

	targets.reset(SEED)
	var second: Array[int] = []
	for _attempt in range(20):
		second.append(targets.select_target(_player(0)))

	assert_eq(first, second, "同じ Seed からは同じ選択列")


func test_ko_target_prefers_the_most_dangerous() -> void:
	_set_mode(0, TargetMode.Mode.KO)
	_player(1).danger_level = DangerLevel.Level.WARNING
	_player(3).danger_level = DangerLevel.Level.CRITICAL
	_player(4).danger_level = DangerLevel.Level.DANGER

	assert_eq(targets.select_target(_player(0)), 3, "一番危ない Player を狙う")


func test_badge_target_prefers_the_most_points() -> void:
	_set_mode(0, TargetMode.Mode.BADGE)
	_player(1).attack_points = 5
	_player(2).attack_points = 20
	_player(4).attack_points = 12

	assert_eq(targets.select_target(_player(0)), 2, "Attack Points が多い Player を狙う")


func test_counter_target_prefers_attackers() -> void:
	_set_mode(0, TargetMode.Mode.COUNTER)
	_player(3).current_target = 0

	assert_eq(targets.select_target(_player(0)), 3, "自分を狙っている Player を狙い返す")


func test_counter_target_falls_back_when_nobody_attacks() -> void:
	_set_mode(0, TargetMode.Mode.COUNTER)

	var target: int = targets.select_target(_player(0))

	assert_ne(target, TargetMode.NO_TARGET, "狙われていなければ他から選ぶ")
	assert_ne(target, 0, "自分は選ばない")


func test_counter_tie_break_is_configurable() -> void:
	_set_mode(0, TargetMode.Mode.COUNTER)
	_player(2).current_target = 0
	_player(4).current_target = 0
	_player(2).danger_level = DangerLevel.Level.SAFE
	_player(4).danger_level = DangerLevel.Level.CRITICAL

	targets.set_counter_tie_break(TargetMode.CounterTieBreak.MOST_DANGEROUS)
	assert_eq(targets.select_target(_player(0)), 4, "危険な方を選ぶ")

	targets.set_counter_tie_break(TargetMode.CounterTieBreak.LOWEST_ID)
	assert_eq(targets.select_target(_player(0)), 2, "ID の小さい方を選ぶ")


# --- Manual Target（要件定義 §52） ------------------------------------------


func test_manual_target_overrides_auto() -> void:
	_set_mode(0, TargetMode.Mode.KO)
	_player(1).danger_level = DangerLevel.Level.CRITICAL

	assert_true(targets.set_manual_target(0, 4), "指定できる")

	assert_eq(targets.select_target(_player(0)), 4, "Auto より優先される")


func test_manual_target_rejects_self() -> void:
	assert_false(targets.set_manual_target(0, 0), "自分は指定できない")


func test_manual_target_rejects_dead_players() -> void:
	manager.eliminate_player(2)

	assert_false(targets.set_manual_target(0, 2), "脱落者は指定できない")


func test_manual_target_falls_back_to_auto_when_the_target_dies() -> void:
	_set_mode(0, TargetMode.Mode.RANDOM)
	targets.set_manual_target(0, 3)
	assert_eq(targets.select_target(_player(0)), 3, "前提: Manual が効いている")

	manager.eliminate_player(3)

	var target: int = targets.select_target(_player(0))
	assert_ne(target, 3, "脱落した指定先は使わない")
	assert_false(targets.has_manual_target(0), "Manual 指定が解除される")


func test_manual_target_can_be_cleared() -> void:
	targets.set_manual_target(0, 2)

	assert_true(targets.set_manual_target(0, TargetMode.NO_TARGET), "解除できる")
	assert_false(targets.has_manual_target(0), "Auto へ戻る")


# --- Event（要件定義 §108） -------------------------------------------------


func test_target_changed_is_emitted() -> void:
	_set_mode(0, TargetMode.Mode.RANDOM)
	watch_signals(targets)

	targets.update_target(0)

	assert_signal_emitted(targets, "target_changed", "Target の変化が通知される")


func test_target_changed_is_not_emitted_when_unchanged() -> void:
	targets.set_manual_target(0, 2)
	targets.update_target(0)
	watch_signals(targets)

	targets.update_target(0)

	assert_signal_not_emitted(targets, "target_changed", "変わらなければ通知しない")


func test_update_all_targets_covers_alive_players() -> void:
	targets.update_all_targets()

	for player in manager.get_alive_players():
		assert_ne(player.current_target, TargetMode.NO_TARGET, "全員に Target が付く")
		assert_ne(player.current_target, player.player_id, "自分は狙わない")
