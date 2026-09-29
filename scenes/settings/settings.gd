extends Control

## Settings 画面（要件定義 §97 / §98）。
##
## Gameplay / Audio / Video / Input の 4 つを触れるようにする。値は
## [UserSettings] が持ち、保存は [SettingsStore]、反映は [SettingsApplier]。
## この画面は**並べて受け取るだけ**にしてある。
##
## 変更は即座に反映し、画面を閉じるときに保存する（要件定義 §98）。
##
## [SceneRouter] が今の画面（Main Menu / Pause 中の Battle）の上に重ねて開く。
## 閉じるのも [SceneRouter] を通し、Game State は変えない（要件定義 §107 / §109）。

## 閉じるときに使う Action。
const CLOSE_ACTION: StringName = &"ui_cancel"

## 変えたときに Audio を反映する項目。
const AUDIO_KEYS: Array[String] = ["master_volume", "bgm_volume", "se_volume"]

## 変えたときに Video を反映する項目。
const VIDEO_KEYS: Array[String] = ["fullscreen", "vsync_enabled", "fps_limit"]

## 変えたときに Input を反映する項目。
const INPUT_KEYS: Array[String] = ["stick_dead_zone"]

## 寸法を読む Theme の型（assets/themes/menu_theme.tres）。
## 項目名と入力欄の幅を揃えておかないと、HSlider が幅 0 に潰れる。
const LAYOUT_TYPE: StringName = &"MenuLayout"

## FPS LIMIT が 0 のとき（上限なし）に出す表示。
const FPS_UNLIMITED_TEXT: String = "OFF"

## CPU 難易度の設定も同じ画面から触れる（要件定義 §97 の Gameplay）。
var _difficulty_panel: CpuDifficultyPanel
var _store: SettingsStore
var _settings: UserSettings
var _controls: Dictionary = {}


func _ready() -> void:
	_store = SceneRouter.settings_store
	_settings = _store.load_settings()

	# 下の画面が透けないよう、また下のボタンを押せないように背景で覆う。
	var background := Panel.new()
	background.name = "Background"
	background.theme_type_variation = &"OverlayBackground"
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	# Advanced を開くと縦に伸びるので、はみ出したらスクロールできるようにする。
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Keyboard / Controller で下の項目へ移ったとき、画面外へ出ないようにする。
	scroll.follow_focus = true
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var root := VBoxContainer.new()
	root.name = "Settings"
	root.theme_type_variation = &"MenuStack"
	center.add_child(root)

	var title := Label.new()
	title.text = "SETTINGS"
	title.theme_type_variation = &"HeaderLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var columns := HBoxContainer.new()
	columns.theme_type_variation = &"MenuColumns"
	root.add_child(columns)

	var left := VBoxContainer.new()
	columns.add_child(left)
	_build_gameplay(left)

	var right := VBoxContainer.new()
	columns.add_child(right)
	_build_audio(right)
	_build_video(right)
	_build_input(right)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "BACK"
	back.custom_minimum_size.x = _layout(&"control_width")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	root.add_child(back)
	back.grab_focus.call_deferred()


func _exit_tree() -> void:
	save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(CLOSE_ACTION, false, true):
		get_viewport().set_input_as_handled()
		close()


## 表示している設定を返す。
func get_settings() -> UserSettings:
	return _settings


## 保存先を返す。
func get_store() -> SettingsStore:
	return _store


## CPU 難易度の選択部分を返す。
func get_difficulty_panel() -> CpuDifficultyPanel:
	return _difficulty_panel


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


## 保存して元の画面へ戻る。
func close() -> void:
	save()
	SceneRouter.close_settings()


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

	# Keyboard / Controller の割り当ては、件数を出すだけ。
	# 個別の割り当て直し UI（1 キーずつ取り直す）は Accessibility（§128）の範囲。
	#
	# 読み出した割り当ては _settings へ入れない。読み出しは Action ごとに 1 つだけ
	# なので、保存して反映し直すと 2 つ目以降（hold の Button 10 など）が消える。
	var keyboard: Dictionary = (
		_settings.keyboard_bindings
		if not _settings.keyboard_bindings.is_empty()
		else SettingsApplier.read_keyboard_bindings()
	)
	var controller: Dictionary = (
		_settings.controller_bindings
		if not _settings.controller_bindings.is_empty()
		else SettingsApplier.read_controller_bindings()
	)

	var label := Label.new()
	label.text = "KEYBOARD %d / CONTROLLER %d" % [keyboard.size(), controller.size()]
	root.add_child(label)


func _section_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"SectionLabel"
	return label


func _row(title: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = _layout(&"label_width")
	row.add_child(label)
	row.add_child(control)
	return row


func _add_slider(
	root: Control,
	key: String,
	title: String,
	minimum: float,
	maximum: float,
	step: float,
	value: float
) -> void:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = _layout(&"control_width")
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# 今の値が見えないと調整できないので、横に数値を出す。
	var value_label := Label.new()
	value_label.custom_minimum_size.x = _layout(&"value_width")
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = _format_value(key, value, step)

	slider.value_changed.connect(
		func(new_value: float) -> void:
			value_label.text = _format_value(key, new_value, step)
			_on_value_changed(key, new_value)
	)
	var row: HBoxContainer = _row(title, slider)
	row.add_child(value_label)
	root.add_child(row)
	_controls[key] = slider


func _add_check(root: Control, key: String, title: String, value: bool) -> void:
	var check := CheckButton.new()
	check.button_pressed = value
	check.custom_minimum_size.x = _layout(&"control_width")
	check.toggled.connect(func(pressed: bool) -> void: _on_value_changed(key, pressed))
	root.add_child(_row(title, check))
	_controls[key] = check


func _layout(constant_name: StringName) -> int:
	return get_theme_constant(constant_name, LAYOUT_TYPE)


func _format_value(key: String, value: float, step: float) -> String:
	if key == "fps_limit" and is_zero_approx(value):
		return FPS_UNLIMITED_TEXT
	if step >= 1.0:
		return "%d" % int(value)
	if step >= 0.1:
		return "%.1f" % value
	if step >= 0.01:
		return "%.2f" % value
	return "%.3f" % value


func _on_value_changed(key: String, value: Variant) -> void:
	if key == "fps_limit":
		_settings.fps_limit = int(value)
	else:
		_settings.set(key, value)

	# 変えたらその場で効かせる（要件定義 §97）。変えた項目の分だけ反映する。
	# まとめて反映すると、音量を触るだけでウィンドウの大きさが戻ってしまう。
	if key in AUDIO_KEYS:
		SettingsApplier.apply_audio(_settings)
	elif key in VIDEO_KEYS:
		SettingsApplier.apply_video(_settings)
	elif key in INPUT_KEYS:
		SettingsApplier.apply_input(_settings)
	# Gameplay（DAS / ARR / Soft Drop / Ghost）は Battle が開始時と Settings を閉じたときに読む。
