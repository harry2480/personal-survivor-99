extends GutTest

## Detailed / Lightweight の切り替えの Unit テスト（要件定義 §80〜§83）。

const SEED: int = 20260920

var manager: BattleManager
var mapping: CpuStrengthMapping
var cpus: CpuManager


func before_each() -> void:
	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	manager = BattleManager.new(rules)
	manager.setup(1, 6, SEED)
	mapping = CpuStrengthMapping.create_default()
	cpus = CpuManager.new(manager, SEED, 2)
	cpus.register_all(mapping, 60.0)


func _cpu_ids() -> Array[int]:
	return cpus.get_registered_ids()


# --- 登録 ------------------------------------------------------------------


func test_only_cpu_players_are_registered() -> void:
	assert_eq(_cpu_ids().size(), 6, "CPU の数だけ登録される")
	assert_false(0 in _cpu_ids(), "Human は登録しない")


func test_everyone_starts_lightweight() -> void:
	for player_id in _cpu_ids():
		assert_eq(cpus.get_mode(player_id), CpuManager.Mode.LIGHTWEIGHT, "既定は Lightweight")
	assert_eq(cpus.get_detailed_count(), 0, "Detailed は 0 体")


# --- Lightweight（要件定義 §82） --------------------------------------------


func test_lightweight_holds_the_required_indicators() -> void:
	var indicators: CpuIndicators = cpus.get_indicators(1)

	assert_true(indicators.stack_height >= 0, "stack_height")
	assert_true(indicators.holes >= 0, "holes")
	assert_true(indicators.roughness >= 0, "roughness")
	assert_gt(indicators.attack_rate, 0.0, "attack_rate")
	assert_gt(indicators.defense_rate, 0.0, "defense_rate")
	assert_gt(indicators.skill, 0.0, "skill")
	assert_true(indicators.incoming_garbage >= 0, "incoming_garbage")
	assert_not_null(indicators.danger_level, "danger_level")


func test_lightweight_updates_on_a_fixed_interval() -> void:
	var lightweight := LightweightCpu.new(mapping.create_profile(60.0), SEED)

	# 更新周期に満たない間は更新しない。
	for _frame in range(29):
		lightweight.update(1.0 / 60.0)
	assert_eq(lightweight.get_update_count(), 0, "周期前は更新しない")

	lightweight.update(1.0 / 60.0)
	assert_eq(lightweight.get_update_count(), 1, "周期で 1 回更新する")


func test_lightweight_update_count_does_not_depend_on_frame_rate() -> void:
	var at_60fps := LightweightCpu.new(mapping.create_profile(60.0), SEED)
	var at_30fps := LightweightCpu.new(mapping.create_profile(60.0), SEED)

	for _frame in range(120):
		at_60fps.update(1.0 / 60.0)
	for _frame in range(60):
		at_30fps.update(1.0 / 30.0)

	assert_eq(at_60fps.get_update_count(), at_30fps.get_update_count(), "2 秒で同じ更新回数")


func test_lightweight_receives_garbage() -> void:
	cpus.receive_garbage(1, 4)

	assert_eq(cpus.get_indicators(1).incoming_garbage, 4, "受信待ちが増える")


func test_lightweight_generates_attacks_over_time() -> void:
	var lightweight := LightweightCpu.new(mapping.create_profile(100.0), SEED)

	var total: int = 0
	for _frame in range(600):
		total += lightweight.update(1.0 / 60.0)

	assert_gt(total, 0, "10 秒のうちに Attack を出す")


func test_stronger_lightweight_attacks_more() -> void:
	var weak := LightweightCpu.new(mapping.create_profile(20.0), SEED)
	var strong := LightweightCpu.new(mapping.create_profile(100.0), SEED)

	var weak_total: int = 0
	var strong_total: int = 0
	for _frame in range(600):
		weak_total += weak.update(1.0 / 60.0)
		strong_total += strong.update(1.0 / 60.0)

	assert_gt(strong_total, weak_total, "強いほど多く出す（弱 %d / 強 %d）" % [weak_total, strong_total])


# --- Detailed（要件定義 §81） -----------------------------------------------


func test_promotion_attaches_a_board_state() -> void:
	assert_true(cpus.promote(1, "test"), "昇格できる")

	assert_eq(cpus.get_mode(1), CpuManager.Mode.DETAILED, "Detailed になる")
	assert_not_null(manager.get_player(1).get_board(), "Board State を持つ")


func test_detailed_places_pieces_over_time() -> void:
	cpus.promote(1, "test")
	var before: int = _count_filled(manager.get_player(1).get_board())

	for _frame in range(180):
		cpus.update(1.0 / 60.0)

	assert_gt(_count_filled(manager.get_player(1).get_board()), before, "実際に積み上がる")


# --- 切り替えの連続性（#42 の完了条件） -------------------------------------


func test_demotion_keeps_the_indicators_continuous() -> void:
	cpus.promote(1, "test")
	for _frame in range(180):
		cpus.update(1.0 / 60.0)
	var before: CpuIndicators = cpus.get_indicators(1)

	cpus.demote(1, "test")
	var after: CpuIndicators = cpus.get_indicators(1)

	assert_true(
		after.is_close_to(before),
		(
			"降格で指標が飛ばない（高さ %d→%d / 穴 %d→%d）"
			% [before.stack_height, after.stack_height, before.holes, after.holes]
		)
	)


func test_promotion_keeps_the_indicators_continuous() -> void:
	# Lightweight 側の状態を進めてから昇格する。
	for _frame in range(600):
		cpus.update(1.0 / 60.0)
	cpus.receive_garbage(1, 6)
	for _frame in range(120):
		cpus.update(1.0 / 60.0)
	var before: CpuIndicators = cpus.get_indicators(1)

	cpus.promote(1, "test")
	var after: CpuIndicators = cpus.get_indicators(1)

	assert_true(
		after.is_close_to(before),
		(
			"昇格で指標が飛ばない（高さ %d→%d / 穴 %d→%d）"
			% [before.stack_height, after.stack_height, before.holes, after.holes]
		)
	)


func test_round_trip_keeps_the_indicators_continuous() -> void:
	cpus.promote(1, "test")
	for _frame in range(120):
		cpus.update(1.0 / 60.0)
	var before: CpuIndicators = cpus.get_indicators(1)

	cpus.demote(1, "test")
	cpus.promote(1, "test")
	var after: CpuIndicators = cpus.get_indicators(1)

	assert_true(after.is_close_to(before), "往復しても指標が飛ばない")


# --- 上限と候補の選定（要件定義 §81 / §83） ---------------------------------


func test_detailed_count_never_exceeds_the_limit() -> void:
	cpus.set_detailed_limit(3)

	cpus.refresh_modes()

	assert_true(cpus.get_detailed_count() <= 3, "上限を超えない")


func test_limit_zero_keeps_everyone_lightweight() -> void:
	cpus.set_detailed_limit(0)

	cpus.refresh_modes()

	assert_eq(cpus.get_detailed_count(), 0, "上限 0 なら全員 Lightweight")


func test_the_human_target_is_promoted_first() -> void:
	manager.get_player(0).current_target = 4
	cpus.set_detailed_limit(1)

	cpus.refresh_modes()

	assert_eq(cpus.get_mode(4), CpuManager.Mode.DETAILED, "Human が狙っている CPU が優先される")


func test_the_focused_player_is_promoted() -> void:
	cpus.set_focus_player(5)
	cpus.set_detailed_limit(1)

	cpus.refresh_modes()

	assert_eq(cpus.get_mode(5), CpuManager.Mode.DETAILED, "UI 注目対象が優先される")


func test_dangerous_cpus_are_preferred() -> void:
	manager.get_player(3).danger_level = DangerLevel.Level.CRITICAL
	cpus.set_detailed_limit(1)

	cpus.refresh_modes()

	assert_eq(cpus.get_mode(3), CpuManager.Mode.DETAILED, "危険な CPU が優先される")


func test_dead_players_are_not_candidates() -> void:
	manager.eliminate_player(1)

	assert_false(1 in cpus.select_detailed_candidates(), "脱落者は候補に入らない")


func test_candidate_order_is_deterministic() -> void:
	manager.get_player(2).danger_level = DangerLevel.Level.DANGER
	manager.get_player(3).danger_level = DangerLevel.Level.DANGER

	var first: Array[int] = cpus.select_detailed_candidates()
	for _attempt in range(5):
		assert_eq(cpus.select_detailed_candidates(), first, "同じ状況からは同じ順序")


# --- ログ（要件定義 §112） --------------------------------------------------


func test_mode_change_is_reported() -> void:
	watch_signals(cpus)

	cpus.promote(1, "test")

	assert_signal_emitted(cpus, "cpu_mode_change", "方式の変化が通知される")


func test_no_signal_without_a_change() -> void:
	cpus.promote(1, "test")
	watch_signals(cpus)

	cpus.promote(1, "test")

	assert_signal_not_emitted(cpus, "cpu_mode_change", "変わらなければ通知しない")


func _count_filled(board: Board) -> int:
	var count: int = 0
	for y in range(Board.TOTAL_HEIGHT):
		for x in range(Board.WIDTH):
			if not board.is_cell_empty(x, y):
				count += 1
	return count
