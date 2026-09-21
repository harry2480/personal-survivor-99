class_name SettingsApplier
extends RefCounted

## 設定をゲーム側へ反映する（要件定義 §97 / §128 / §129）。
##
## [UserSettings] は値を持つだけ、[SettingsStore] は保存するだけ。**効かせる**のが
## ここ。Gameplay / Audio / Video / Input の 4 つを、それぞれの持ち主へ渡す。
##
## [br]・Gameplay … [GameRules]（Game Core が読む値）
## [br]・Audio    … [AudioServer] の Bus 音量
## [br]・Video    … [DisplayServer] と [Engine]
## [br]・Input    … [InputMap] と Dead Zone
##
## Game Core は FileSystem も DisplayServer も知らない（要件定義 §17）。
## 読み込みと反映は Presentation の担当なので、ここに置く。

## Bus の名前（要件定義 §100 / #53 で使う）。
const BGM_BUS: String = "BGM"

## SE の Bus の名前。
const SE_BUS: String = "SE"


## すべて反映する。
static func apply_all(settings: UserSettings) -> void:
	if settings == null:
		return
	apply_audio(settings)
	apply_video(settings)
	apply_input(settings)


## Gameplay を [GameRules] へ反映する（要件定義 §97）。
##
## 反映した項目数を返す。
static func apply_gameplay(settings: UserSettings, rules: GameRules) -> int:
	if settings == null or rules == null:
		return 0
	return rules.apply_user_settings(settings.to_game_rules_dictionary())


## Audio の音量を反映する（要件定義 §97 / §100）。
##
## BGM / SE の Bus が無い環境（Bus Layout を置く前）では Master だけ効かせる。
static func apply_audio(settings: UserSettings) -> void:
	if settings == null:
		return
	_set_bus_volume("Master", settings.master_volume)
	_set_bus_volume(BGM_BUS, settings.bgm_volume)
	_set_bus_volume(SE_BUS, settings.se_volume)


## Video を反映する（要件定義 §97 / §129）。
static func apply_video(settings: UserSettings) -> void:
	if settings == null or DisplayServer.get_name() == "headless":
		return

	DisplayServer.window_set_mode(
		(
			DisplayServer.WINDOW_MODE_FULLSCREEN
			if settings.fullscreen
			else DisplayServer.WINDOW_MODE_WINDOWED
		)
	)
	if not settings.fullscreen:
		DisplayServer.window_set_size(settings.window_size)

	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if settings.vsync_enabled else DisplayServer.VSYNC_DISABLED
	)
	Engine.max_fps = settings.fps_limit


## Input を反映する（要件定義 §97 / §128）。
##
## 割り当てがある Action だけ差し替える。無い Action は project.godot の
## 既定（要件定義 §14 / §15）のまま残す。
static func apply_input(settings: UserSettings) -> void:
	if settings == null:
		return

	for action in settings.keyboard_bindings:
		_replace_event(str(action), settings.keyboard_bindings[action], true)
	for action in settings.controller_bindings:
		_replace_event(str(action), settings.controller_bindings[action], false)

	InputManager.apply_dead_zone(settings.stick_dead_zone)


## 現在の Keyboard 割り当てを読み出す（Settings 画面の表示用）。
static func read_keyboard_bindings() -> Dictionary:
	var bindings: Dictionary = {}
	for command in GameCommand.get_all_commands():
		var action_name: String = GameCommand.get_action_name(command)
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				bindings[action_name] = int(event.physical_keycode)
				break
	return bindings


## 現在の Controller 割り当てを読み出す（Settings 画面の表示用）。
static func read_controller_bindings() -> Dictionary:
	var bindings: Dictionary = {}
	for command in GameCommand.get_all_commands():
		var action_name: String = GameCommand.get_action_name(command)
		for event in InputMap.action_get_events(action_name):
			if event is InputEventJoypadButton:
				bindings[action_name] = int(event.button_index)
				break
	return bindings


static func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(index, volume <= 0.0)


# その Action の Keyboard / Controller の割り当てを 1 つだけ差し替える。
static func _replace_event(action_name: String, value: Variant, keyboard: bool) -> void:
	if not InputMap.has_action(action_name) or not (value is float or value is int):
		return

	for event in InputMap.action_get_events(action_name):
		var matches: bool = event is InputEventKey if keyboard else event is InputEventJoypadButton
		if matches:
			InputMap.action_erase_event(action_name, event)

	if keyboard:
		var key := InputEventKey.new()
		key.physical_keycode = int(value)
		InputMap.action_add_event(action_name, key)
		return

	var button := InputEventJoypadButton.new()
	button.button_index = int(value) as JoyButton
	InputMap.action_add_event(action_name, button)
