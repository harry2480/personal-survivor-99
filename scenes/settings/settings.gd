extends Control

## Settings 画面（要件定義 §97 / §98）。
##
## Gameplay / Audio / Video / Input の 4 つを触れるようにする。値は
## [UserSettings] が持ち、保存は [SettingsStore]、反映は [SettingsApplier]。
## この画面は**並べて受け取るだけ**にしてある。
##
## 変更は即座に反映し、画面を閉じるときに保存する（要件定義 §98）。

## CPU 難易度の設定も同じ画面から触れる（要件定義 §97 の Gameplay）。
var _difficulty_panel: CpuDifficultyPanel
var _store := SettingsStore.new()
var _settings: UserSettings
var _controls: Dictionary = {}


func _ready() -> void:
	_settings = _store.load_settings()

	var root := VBoxContainer.new()
	root.name = "Settings"
	root.position = Vector2(60.0, 40.0)
	add_child(root)

	var title := Label.new()
	title.text = "SETTINGS"
	root.add_child(title)

	_build_gameplay(root)
	_build_audio(root)
	_build_video(root)
	_build_input(root)

	var back := Button.new()
	back.text = "BACK"
	back.pressed.connect(close)
	root.add_child(back)

	SettingsApplier.apply_all(_settings)


func _exit_tree() -> void:
	save()


## 表示している設定を返す。
func get_settings() -> UserSettings:
	return _settings


## 保存先を返す。
func get_store() -> SettingsStore:
	return _store


## 設定項目の入力欄を返す。無ければ [code]null[/code]。
func get_control(key: String) -> Control:
	return _controls.get(key, null)


## 設定を保存する（要件定義 §98）。
func save() -> bool:
	if _settings == null:
		return false
	_settings.cpu_settings = _difficulty_panel.get_settings()
	# 画面を閉じたあとも同じ内容を使えるよう、Router 側も更新しておく。
	SceneRouter.set_user_settings(_settings)
	return _store.save_settings(_settings)


## 保存して Main Menu へ戻る。
func close() -> void:
	save()
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")


func _build_gameplay(root: Control) -> void:
	root.add_child(_section_label("GAMEPLAY"))
	_add_slider(root, "das_sec", "DAS", 0.0, 0.5, 0.001, _settings.das_sec)
	_add_slider(root, "arr_sec", "ARR", 0.0, 0.2, 0.001, _settings.arr_sec)
	_add_slider(
		root, "soft_drop_multiplier", "SOFT DROP", 1.0, 100.0, 0.5, _settings.soft_drop_multiplier
	)
	_add_check(root, "ghost_enabled", "GHOST", _settings.ghost_enabled)

	_difficulty_panel = CpuDifficultyPanel.new()
	_difficulty_panel.name = "CpuDifficultyPanel"
	root.add_child(_difficulty_panel)
	if _settings.cpu_settings != null:
		_difficulty_panel.set_settings(_settings.cpu_settings)


func _build_audio(root: Control) -> void:
	root.add_child(_section_label("AUDIO"))
	_add_slider(root, "master_volume", "MASTER", 0.0, 1.0, 0.01, _settings.master_volume)
	_add_slider(root, "bgm_volume", "BGM", 0.0, 1.0, 0.01, _settings.bgm_volume)
	_add_slider(root, "se_volume", "SE", 0.0, 1.0, 0.01, _settings.se_volume)


func _build_video(root: Control) -> void:
	root.add_child(_section_label("VIDEO"))
	_add_check(root, "fullscreen", "FULLSCREEN", _settings.fullscreen)
	_add_check(root, "vsync_enabled", "VSYNC", _settings.vsync_enabled)
	_add_slider(root, "fps_limit", "FPS LIMIT", 0.0, 240.0, 1.0, float(_settings.fps_limit))


func _build_input(root: Control) -> void:
	root.add_child(_section_label("INPUT"))
	_add_slider(root, "stick_dead_zone", "DEAD ZONE", 0.0, 1.0, 0.01, _settings.stick_dead_zone)

	# Keyboard / Controller の割り当ては、いまの内容を読み出して持たせておく。
	# 個別の割り当て直し UI（1 キーずつ取り直す）は Accessibility（§128）の範囲。
	if _settings.keyboard_bindings.is_empty():
		_settings.keyboard_bindings = SettingsApplier.read_keyboard_bindings()
	if _settings.controller_bindings.is_empty():
		_settings.controller_bindings = SettingsApplier.read_controller_bindings()

	var label := Label.new()
	label.text = (
		"KEYBOARD %d / CONTROLLER %d"
		% [_settings.keyboard_bindings.size(), _settings.controller_bindings.size()]
	)
	root.add_child(label)


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _add_slider(
	root: Control,
	key: String,
	title: String,
	minimum: float,
	maximum: float,
	step: float,
	value: float
) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.value_changed.connect(func(new_value: float) -> void: _on_value_changed(key, new_value))
	row.add_child(label)
	row.add_child(slider)
	root.add_child(row)
	_controls[key] = slider


func _add_check(root: Control, key: String, title: String, value: bool) -> void:
	var check := CheckButton.new()
	check.text = title
	check.button_pressed = value
	check.toggled.connect(func(pressed: bool) -> void: _on_value_changed(key, pressed))
	root.add_child(check)
	_controls[key] = check


func _on_value_changed(key: String, value: Variant) -> void:
	if key == "fps_limit":
		_settings.fps_limit = int(value)
	else:
		_settings.set(key, value)

	# 変えたらその場で効かせる（要件定義 §97）。
	SettingsApplier.apply_all(_settings)
