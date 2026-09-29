extends GutTest

## 画面の文言が日本語で出ることの確認（スタイルガイド §7）。
##
## 文言は英語のキーで組み立て、locale/ja.po で日本語にする。ここでは
## 画面に出るキーに訳が抜けていないかを見る。

const RESULT_SCRIPT := preload("res://scenes/result/result.gd")

var _original_locale: String


func before_each() -> void:
	_original_locale = TranslationServer.get_locale()
	SettingsApplier.apply_locale()


func after_each() -> void:
	TranslationServer.set_locale(_original_locale)


func _assert_translated(keys: Array, context: StringName = &"") -> void:
	for key in keys:
		var text: String = TranslationServer.translate(key, context)
		assert_ne(text, key, "%s に日本語の訳がある" % key)


func test_locale_is_japanese() -> void:
	assert_eq(TranslationServer.get_locale(), "ja", "起動時に日本語にする")


func test_menu_and_settings_are_translated() -> void:
	_assert_translated(
		[
			"PLAYERS",
			"PLAY",
			"SETTINGS",
			"QUIT",
			"BACK",
			"GAMEPLAY",
			"DAS",
			"ARR",
			"SOFT DROP SPEED",
			"GHOST",
			"AUDIO",
			"MASTER",
			"BGM",
			"SE",
			"VIDEO",
			"FULLSCREEN",
			"VSYNC",
			"FPS LIMIT",
			"OFF",
			"INPUT",
			"DEAD ZONE",
			"KEYBOARD %d / CONTROLLER %d",
			"CPU Difficulty",
			"Advanced",
			"Strength",
			"Min Strength",
			"Max Strength",
			"Variation",
		]
	)


func test_cpu_names_are_translated() -> void:
	_assert_translated(CpuSettings.ADVANCED_KEYS)
	var presets: Array = []
	for preset in CpuPreset.Preset.values():
		presets.append(CpuPreset.get_preset_name(preset))
	_assert_translated(presets)


func test_battle_screen_is_translated() -> void:
	_assert_translated(BattleHud.ROW_LABELS.values())
	var phases: Array = []
	for phase in BattlePhase.Phase.values():
		phases.append(BattlePhase.get_phase_name(phase))
	_assert_translated(phases)
	_assert_translated(["HOLD", "NEXT"])


func test_target_modes_are_translated_with_context() -> void:
	var modes: Array = []
	for mode in TargetMode.Mode.values():
		modes.append(TargetMode.get_mode_name(mode))
	_assert_translated(modes, &"target_mode")
	# 同じ "KO" でも、HUD の行は KO 数、Target Mode は KO 狙い。
	assert_ne(
		TranslationServer.translate("KO", &"target_mode"),
		TranslationServer.translate("KO"),
		"文脈で訳し分ける"
	)


func test_controls_guide_is_translated() -> void:
	var labels: Array = []
	for row in ControlsGuide.ROWS:
		labels.append(row["label"])
	_assert_translated(labels)
	_assert_translated(
		ControlsGuide.HEADERS.filter(func(header: String) -> bool: return header != "")
	)


func test_pause_and_result_are_translated() -> void:
	_assert_translated(PauseMenu.ACTION_LABELS.values())
	_assert_translated(RESULT_SCRIPT.ROW_LABELS.values())
	_assert_translated(["PAUSED", "VICTORY", "RESULT", "BACK TO MENU", "%.1f s"])
	_assert_translated(["TOTAL  GAMES %d / WINS %d / TOP10 %d / AVG RANK %.1f / KO %d"])
