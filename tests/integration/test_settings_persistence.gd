extends GutTest

## 設定の保存・読み込みと反映の確認（要件定義 §97 / §98）。
##
## 保存方式が 1 つに統一されていること、壊れたファイルでも既定値で起動すること、
## 設定がゲーム側へ効くことを見る（#52 の完了条件）。

const SETTINGS_SCENE := preload("res://scenes/settings/settings.tscn")
const TEST_DIR: String = "user://test_settings/"

var store: SettingsStore


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	store = SettingsStore.new(TEST_DIR)
	store.delete_document(SettingsStore.SETTINGS_DOCUMENT)
	store.delete_document(SettingsStore.STATISTICS_DOCUMENT)


func after_each() -> void:
	store.delete_document(SettingsStore.SETTINGS_DOCUMENT)
	store.delete_document(SettingsStore.STATISTICS_DOCUMENT)


func _write_raw(document: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(store.get_path(document), FileAccess.WRITE)
	file.store_string(text)
	file.close()


# --- 保存方式の統一（要件定義 §98） -----------------------------------------


func test_everything_is_saved_as_json_under_user() -> void:
	assert_true(store.get_path(SettingsStore.SETTINGS_DOCUMENT).begins_with(TEST_DIR), "user:// 配下")
	assert_true(store.get_path(SettingsStore.SETTINGS_DOCUMENT).ends_with(".json"), "JSON で保存")
	assert_true(store.get_path(SettingsStore.STATISTICS_DOCUMENT).ends_with(".json"), "統計も同じ形式")


func test_statistics_use_the_same_store() -> void:
	# Statistics（#54）も同じ入り口を通る（要件定義 §98 / §99）。
	assert_true(store.save_document(SettingsStore.STATISTICS_DOCUMENT, {"games_played": 3}), "書ける")

	var loaded: Dictionary = store.load_document(SettingsStore.STATISTICS_DOCUMENT)

	assert_eq(loaded.get("games_played"), 3, "読み戻せる")


func test_settings_round_trip() -> void:
	var settings := UserSettings.create_default()
	settings.das_sec = 0.1
	settings.arr_sec = 0.02
	settings.master_volume = 0.42
	settings.fullscreen = true
	settings.fps_limit = 120
	settings.stick_dead_zone = 0.35
	settings.keyboard_bindings = {"hard_drop": KEY_SPACE}

	assert_true(store.save_settings(settings), "保存できる")
	var loaded: UserSettings = store.load_settings()

	assert_almost_eq(loaded.das_sec, 0.1, 0.0001, "DAS")
	assert_almost_eq(loaded.arr_sec, 0.02, 0.0001, "ARR")
	assert_almost_eq(loaded.master_volume, 0.42, 0.0001, "Master 音量")
	assert_true(loaded.fullscreen, "Fullscreen")
	assert_eq(loaded.fps_limit, 120, "FPS 上限")
	assert_almost_eq(loaded.stick_dead_zone, 0.35, 0.0001, "Dead Zone")
	assert_eq(loaded.keyboard_bindings.get("hard_drop"), KEY_SPACE, "Keyboard 割り当て")


func test_cpu_settings_are_saved_too() -> void:
	var settings := UserSettings.create_default()
	settings.cpu_settings.select_preset(CpuPreset.Preset.CUSTOM)
	settings.cpu_settings.set_strength(150.0)
	settings.cpu_settings.advanced_enabled = true
	settings.cpu_settings.set_advanced_override("misdrop_rate", 0.0)

	store.save_settings(settings)
	var loaded: UserSettings = store.load_settings()

	assert_eq(loaded.cpu_settings.strength, 150.0, "Strength が残る（要件定義 §98）")
	assert_true(loaded.cpu_settings.advanced_enabled, "Advanced の状態も残る")
	assert_eq(loaded.cpu_settings.advanced_overrides.get("misdrop_rate"), 0.0, "個別調整も残る")


# --- 壊れていても落ちない（#52 の完了条件） ---------------------------------


func test_missing_file_falls_back_to_defaults() -> void:
	var loaded: UserSettings = store.load_settings()
	var defaults := UserSettings.create_default()

	assert_eq(loaded.das_sec, defaults.das_sec, "ファイルが無ければ既定値")


func test_broken_json_falls_back_to_defaults() -> void:
	_write_raw(SettingsStore.SETTINGS_DOCUMENT, "{ これは JSON では")

	var loaded: UserSettings = store.load_settings()

	assert_eq(loaded.das_sec, UserSettings.create_default().das_sec, "壊れていても既定値で起動する")


func test_partial_file_keeps_the_other_defaults() -> void:
	_write_raw(SettingsStore.SETTINGS_DOCUMENT, '{"gameplay": {"das_sec": 0.2}}')

	var loaded: UserSettings = store.load_settings()

	assert_almost_eq(loaded.das_sec, 0.2, 0.0001, "書いてある値は読む")
	assert_eq(loaded.arr_sec, UserSettings.create_default().arr_sec, "欠けている値は既定値")


func test_wrong_types_are_ignored() -> void:
	_write_raw(
		SettingsStore.SETTINGS_DOCUMENT,
		'{"gameplay": {"das_sec": "はやい"}, "audio": {"master": true}}'
	)

	var loaded: UserSettings = store.load_settings()
	var defaults := UserSettings.create_default()

	assert_eq(loaded.das_sec, defaults.das_sec, "型が違う値は無視する")
	assert_eq(loaded.master_volume, defaults.master_volume, "音量も既定値のまま")


func test_out_of_range_values_are_clamped() -> void:
	_write_raw(SettingsStore.SETTINGS_DOCUMENT, '{"audio": {"master": 99.0}}')

	assert_lte(store.load_settings().master_volume, 1.0, "範囲外は収める")


# --- ゲーム側への反映（#52 の完了条件） -------------------------------------


func test_gameplay_settings_reach_the_game_rules() -> void:
	var settings := UserSettings.create_default()
	settings.das_sec = 0.09
	settings.arr_sec = 0.01
	settings.soft_drop_multiplier = 40.0

	var rules := GameRules.create_default()
	var applied: int = SettingsApplier.apply_gameplay(settings, rules)

	assert_gte(applied, 3, "DAS / ARR / Soft Drop が反映される")
	assert_almost_eq(rules.das_sec, 0.09, 0.0001, "DAS が効く")
	assert_almost_eq(rules.arr_sec, 0.01, 0.0001, "ARR が効く")
	assert_almost_eq(rules.soft_drop_multiplier, 40.0, 0.0001, "Soft Drop が効く")


func test_das_and_arr_change_the_actual_movement() -> void:
	# 設定が「実際の操作に効く」ことを、Game Core を動かして確かめる。
	var settings := UserSettings.create_default()
	settings.das_sec = 0.0
	settings.arr_sec = 0.0

	var rules := GameRules.create_default()
	SettingsApplier.apply_gameplay(settings, rules)
	rules.gravity_cells_per_second = 0.0

	var session := PuzzleSession.new(rules, PieceRandomizer.new(1))
	session.start(1)
	var before: int = session.get_active_piece().position.x

	session.press_move(AutoShift.Direction.LEFT)
	session.update(1.0 / 60.0)

	assert_lt(session.get_active_piece().position.x, before, "DAS 0 なら押した瞬間から動く")


func test_dead_zone_is_applied_to_the_input() -> void:
	var settings := UserSettings.create_default()
	settings.stick_dead_zone = 0.42

	SettingsApplier.apply_input(settings)

	for command in GameCommand.get_all_commands():
		var action_name: String = GameCommand.get_action_name(command)
		assert_almost_eq(
			InputMap.action_get_deadzone(action_name), 0.42, 0.0001, "%s に効く" % action_name
		)

	# 他のテストへ影響しないよう、既定へ戻す。
	InputMap.load_from_project_settings()


func test_keyboard_binding_is_applied_to_the_input_map() -> void:
	var settings := UserSettings.create_default()
	settings.keyboard_bindings = {"hold": KEY_V}

	SettingsApplier.apply_input(settings)

	var keycodes: Array[int] = []
	for event in InputMap.action_get_events("hold"):
		if event is InputEventKey:
			keycodes.append(int(event.physical_keycode))
	assert_true(KEY_V in keycodes, "割り当て直した key が効く")

	# 他のテストへ影響しないよう、既定へ戻す。
	InputMap.load_from_project_settings()


# --- Settings 画面（要件定義 §97） ------------------------------------------


func test_settings_screen_shows_every_section() -> void:
	var screen: Control = SETTINGS_SCENE.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)

	for key in [
		"das_sec",
		"arr_sec",
		"soft_drop_multiplier",
		"ghost_enabled",
		"master_volume",
		"bgm_volume",
		"se_volume",
		"fullscreen",
		"vsync_enabled",
		"fps_limit",
		"stick_dead_zone"
	]:
		assert_not_null(screen.get_control(key), "%s を設定できる" % key)

	assert_not_null(screen.get_node_or_null("Settings/CpuDifficultyPanel"), "CPU 難易度も設定できる")


func test_settings_screen_saves_on_close() -> void:
	var screen: Control = SETTINGS_SCENE.instantiate()
	add_child_autofree(screen)
	await wait_frames(2)

	screen.get_settings().master_volume = 0.11
	assert_true(screen.save(), "保存できる")

	var reloaded: UserSettings = screen.get_store().load_settings()
	assert_almost_eq(reloaded.master_volume, 0.11, 0.0001, "保存した値が残る")
