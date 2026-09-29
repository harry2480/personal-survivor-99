extends Control

## Main Menu（要件定義 §94 / §95）。
##
## 最低限の項目は Play / Settings / Quit。Play を押す前に、難易度と人数を
## この画面で決められる（Game Start Flow）。
##
## ログインやネット接続は要求しない（要件定義 §95）。
##
## 決めた内容は [BattleSetup] として [SceneRouter] へ預け、Battle 画面が
## それを読んで始める。

## Play を押したときに使う Action。
const START_ACTION: StringName = &"ui_accept"

## 寸法を読む Theme の型（assets/themes/menu_theme.tres）。
const LAYOUT_TYPE: StringName = &"MenuLayout"

var _difficulty_panel: CpuDifficultyPanel
var _player_count_spin: SpinBox
var _play_button: Button
var _settings_button: Button
var _quit_button: Button


func _ready() -> void:
	# 画面の中央に置く。子は Menu の 1 つだけにしておく（Settings はこの横に重なる）。
	var center := CenterContainer.new()
	center.name = "Menu"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var root := VBoxContainer.new()
	root.theme_type_variation = &"MenuStack"
	center.add_child(root)

	var title := Label.new()
	title.text = "PROJECT 99"
	title.theme_type_variation = &"TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	root.add_child(_build_player_count_row())

	_difficulty_panel = CpuDifficultyPanel.new()
	_difficulty_panel.name = "CpuDifficultyPanel"
	root.add_child(_difficulty_panel)

	_play_button = _add_button(root, "PLAY", _on_play_pressed)
	_settings_button = _add_button(root, "SETTINGS", _on_settings_pressed)
	_quit_button = _add_button(root, "QUIT", _on_quit_pressed)

	_load_from_router()
	_play_button.grab_focus.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	# Settings を開いている間は、下の Main Menu で Play を始めない。
	if SceneRouter.is_settings_open():
		return
	if event.is_action_pressed(START_ACTION, false, true):
		get_viewport().set_input_as_handled()
		_on_play_pressed()


## この画面で決めた内容を返す（要件定義 §95）。
func build_setup() -> BattleSetup:
	var setup: BattleSetup = SceneRouter.get_battle_setup()
	setup.player_count = int(_player_count_spin.value)
	setup.cpu_settings = _difficulty_panel.get_settings()
	return setup


## 難易度の選択部分を返す。
func get_difficulty_panel() -> CpuDifficultyPanel:
	return _difficulty_panel


## Play を押したときと同じ流れを起こす（テストと Controller 用）。
func press_play() -> void:
	_on_play_pressed()


func _build_player_count_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "PLAYERS"
	label.custom_minimum_size.x = get_theme_constant(&"label_width", LAYOUT_TYPE)
	_player_count_spin = SpinBox.new()
	_player_count_spin.min_value = 2
	_player_count_spin.max_value = 99
	_player_count_spin.step = 1
	_player_count_spin.value = 99
	_player_count_spin.custom_minimum_size.x = get_theme_constant(&"control_width", LAYOUT_TYPE)
	row.add_child(label)
	row.add_child(_player_count_spin)
	return row


func _add_button(parent: Control, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.x = get_theme_constant(&"button_width", LAYOUT_TYPE)
	button.pressed.connect(handler)
	parent.add_child(button)
	return button


func _load_from_router() -> void:
	var setup: BattleSetup = SceneRouter.get_battle_setup()
	_player_count_spin.value = setup.player_count
	if setup.cpu_settings != null:
		_difficulty_panel.set_settings(setup.cpu_settings)


func _on_play_pressed() -> void:
	SceneRouter.start_battle(build_setup())


func _on_settings_pressed() -> void:
	# 状態は MAIN_MENU のまま、この画面の上に重ねる。
	var overlay: Node = SceneRouter.open_settings(self)
	# Settings で変えた CPU 難易度を、閉じたあとの表示へ反映する。
	if overlay != null and not overlay.tree_exited.is_connected(_on_settings_closed):
		overlay.tree_exited.connect(_on_settings_closed)


func _on_settings_closed() -> void:
	if is_inside_tree():
		_load_from_router()
		# 閉じたあとフォーカスが無いと、Keyboard / Controller で操作できなくなる。
		_settings_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()
