extends GutTest

## Result 画面 / Statistics / Debug Overlay / Logging の確認
## （要件定義 §99 / §112 / §113、MVP 受入条件 21）。

const RESULT_SCENE := preload("res://scenes/result/result.tscn")
const TEST_DIR: String = "user://test_statistics/"
const SEED: int = 20260922

var store: SettingsStore


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	store = SettingsStore.new(TEST_DIR)
	store.delete_document(SettingsStore.STATISTICS_DOCUMENT)


func after_each() -> void:
	store.delete_document(SettingsStore.STATISTICS_DOCUMENT)


func _outcome(rank: int, ko: int = 0, lines: int = 0) -> BattleOutcome:
	var outcome := BattleOutcome.create_empty()
	outcome.rank = rank
	outcome.player_count = 99
	outcome.ko_count = ko
	outcome.cleared_lines = lines
	outcome.duration_sec = 120.0
	return outcome


# --- Statistics の集計（要件定義 §99） --------------------------------------


func test_every_required_statistic_exists() -> void:
	var keys: Array = Statistics.create_empty().to_dictionary().keys()

	for key in [
		"games_played",
		"wins",
		"top_ten_count",
		"rank_total",
		"total_ko",
		"best_ko",
		"total_lines",
		"quad_count",
		"t_spin_count",
		"perfect_clear_count",
		"play_time_sec",
		"highest_cpu_strength_defeated"
	]:
		assert_true(key in keys, "%s を記録する" % key)


func test_recording_a_battle_updates_the_totals() -> void:
	var stats := Statistics.create_empty()

	stats.record_battle(_outcome(1, 5, 40))

	assert_eq(stats.games_played, 1, "試合数")
	assert_eq(stats.wins, 1, "優勝数")
	assert_eq(stats.top_ten_count, 1, "Top 10")
	assert_eq(stats.total_ko, 5, "KO 合計")
	assert_eq(stats.best_ko, 5, "最高 KO")
	assert_eq(stats.total_lines, 40, "消した行")
	assert_almost_eq(stats.play_time_sec, 120.0, 0.001, "遊んだ時間")


func test_average_rank_is_computed() -> void:
	var stats := Statistics.create_empty()

	stats.record_battle(_outcome(1))
	stats.record_battle(_outcome(3))

	assert_almost_eq(stats.get_average_rank(), 2.0, 0.001, "平均順位")
	assert_almost_eq(stats.get_win_rate(), 0.5, 0.001, "勝率")


func test_best_ko_keeps_the_maximum() -> void:
	var stats := Statistics.create_empty()

	stats.record_battle(_outcome(5, 7))
	stats.record_battle(_outcome(2, 3))

	assert_eq(stats.best_ko, 7, "最高 KO は下がらない")
	assert_eq(stats.total_ko, 10, "合計は足される")


func test_rank_outside_the_top_ten_is_not_counted() -> void:
	var stats := Statistics.create_empty()

	stats.record_battle(_outcome(11))

	assert_eq(stats.top_ten_count, 0, "11 位は Top 10 に数えない")
	assert_eq(stats.games_played, 1, "試合数には数える")


func test_highest_cpu_strength_keeps_the_maximum() -> void:
	var stats := Statistics.create_empty()
	var first: BattleOutcome = _outcome(1)
	first.highest_cpu_strength_defeated = 120.0
	var second: BattleOutcome = _outcome(1)
	second.highest_cpu_strength_defeated = 80.0

	stats.record_battle(first)
	stats.record_battle(second)

	assert_eq(stats.highest_cpu_strength_defeated, 120.0, "いちばん強い相手が残る")


func test_unfinished_battles_are_not_recorded() -> void:
	var stats := Statistics.create_empty()

	stats.record_battle(_outcome(0))
	stats.record_battle(null)

	assert_eq(stats.games_played, 0, "順位が決まっていない結果は数えない")


# --- 保存（要件定義 §98 / §99） ---------------------------------------------


func test_statistics_use_the_same_store_as_settings() -> void:
	var stats := Statistics.create_empty()
	stats.record_battle(_outcome(2, 4, 30))

	assert_true(stats.save_to(store), "保存できる")
	var loaded: Statistics = Statistics.load_from(store)

	assert_eq(loaded.games_played, 1, "試合数が残る")
	assert_eq(loaded.total_ko, 4, "KO が残る")
	assert_eq(loaded.total_lines, 30, "消した行が残る")


func test_missing_statistics_start_from_zero() -> void:
	assert_eq(Statistics.load_from(store).games_played, 0, "無ければ 0 から")


func test_broken_statistics_start_from_zero() -> void:
	var file: FileAccess = FileAccess.open(
		store.get_path(SettingsStore.STATISTICS_DOCUMENT), FileAccess.WRITE
	)
	file.store_string("{壊れている")
	file.close()

	assert_eq(Statistics.load_from(store).games_played, 0, "壊れていても落ちない")


# --- Result 画面（MVP 受入条件 21） -----------------------------------------


func test_result_screen_shows_the_outcome() -> void:
	var outcome: BattleOutcome = _outcome(7, 3, 55)
	SceneRouter.current_state = GameState.State.MAIN_MENU
	SceneRouter.start_battle()
	SceneRouter.finish_battle(outcome)

	var screen: Control = RESULT_SCENE.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)

	assert_eq(screen.get_value("rank"), "#7 / 99", "Rank が出る")
	assert_eq(screen.get_value("ko"), "3", "KO 数が出る")
	assert_eq(screen.get_value("lines"), "55", "消した行数が出る")
	assert_ne(screen.get_value("duration"), "", "Battle 時間が出る")

	SceneRouter.current_state = GameState.State.MAIN_MENU


func test_result_screen_records_the_battle() -> void:
	SceneRouter.current_state = GameState.State.MAIN_MENU
	SceneRouter.start_battle()
	SceneRouter.finish_battle(_outcome(1, 2, 10))

	var screen: Control = RESULT_SCENE.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)

	assert_gte(screen.get_statistics().games_played, 1, "通算へ足し込まれる")

	SceneRouter.current_state = GameState.State.MAIN_MENU


# --- Debug Overlay（要件定義 §113） -----------------------------------------


func test_debug_overlay_shows_every_required_row() -> void:
	var overlay := DebugOverlay.new()
	add_child_autofree(overlay)

	for key in [
		"fps",
		"frame_time",
		"alive",
		"detailed_cpu",
		"lightweight_cpu",
		"average_strength",
		"highest_strength",
		"memory",
		"active_garbage",
		"seed",
		"game_time"
	]:
		assert_true(key in DebugOverlay.ROW_KEYS, "%s を出す" % key)
		assert_ne(overlay.get_value(key), "", "%s の行がある" % key)


func test_debug_overlay_reads_the_battle() -> void:
	var overlay := DebugOverlay.new()
	add_child_autofree(overlay)
	var runner := CpuBattleRunner.new(9, CpuDistribution.create_default(), null, SEED, 1)

	overlay.bind(runner)
	overlay.refresh()

	assert_eq(overlay.get_value("alive"), "10 / 10", "生存人数が出る")
	assert_eq(overlay.get_value("seed"), str(SEED), "Seed が出る")
	assert_eq(overlay.get_value("lightweight_cpu"), "9", "Lightweight の数が出る")
	assert_ne(overlay.get_value("average_strength"), "-", "平均 Strength が出る")

	runner.dispose()


func test_debug_overlay_defaults_to_the_build_type() -> void:
	# Release Build では既定 OFF（#54 の完了条件）。
	var overlay := DebugOverlay.new()
	add_child_autofree(overlay)

	assert_eq(overlay.is_shown(), OS.is_debug_build(), "Development でだけ既定 ON")

	overlay.set_shown(false)
	assert_false(overlay.is_shown(), "切り替えられる")


# --- Logging（要件定義 §112） -----------------------------------------------


func test_logger_records_the_required_events() -> void:
	var manager := BattleManager.new()
	manager.setup(1, 3, SEED)
	var router := GarbageRouter.new(manager)
	var ko := KoSystem.new(manager, router.get_attribution())
	var targets := TargetManager.new(manager, SEED)

	var logger := BattleLogger.new()
	logger.set_enabled(true)
	logger.bind(manager, ko, targets, router)

	targets.set_manual_target(0, 2)
	targets.update_all_targets()
	manager.eliminate_player(1)

	var text: String = "\n".join(logger.get_lines())
	assert_true(text.contains("battle_start"), "Battle Start を記録する")
	assert_true(text.contains("target_change"), "Target Change を記録する")
	assert_true(text.contains("ko"), "KO を記録する")

	logger.unbind()
	router.dispose()
	ko.dispose()


func test_logger_is_silent_when_disabled() -> void:
	var logger := BattleLogger.new()
	logger.set_enabled(false)

	logger.log_event("battle_start", "players=99")

	assert_eq(logger.get_lines().size(), 0, "Release では記録しない")


func test_logger_keeps_a_bounded_history() -> void:
	var logger := BattleLogger.new()
	logger.set_enabled(true)

	for index in range(BattleLogger.MAX_LINES + 50):
		logger.log_event("garbage_send", str(index))

	assert_eq(logger.get_lines().size(), BattleLogger.MAX_LINES, "古い行から捨てる")
