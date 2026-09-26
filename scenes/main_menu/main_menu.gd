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

var _difficulty_panel: CpuDifficultyPanel
var _player_count_spin: SpinBox
var _play_button: Button
var _settings_button: Button
var _quit_button: Button


func _ready() -> void:
	var root := VBoxContainer.new()
	root.name = "Menu"
	root.position = Vector2(80.0, 60.0)
	add_child(root)

	var title := Label.new()
	title.text = "PROJECT 99"
	root.add_child(title)

	root.add_child(_build_player_count_row())

	_difficulty_panel = CpuDifficultyPanel.new()
	_difficulty_panel.name = "CpuDifficultyPanel"
	root.add_child(_difficulty_panel)

	_play_button = _add_button(root, "PLAY", _on_play_pressed)
	_settings_button = _add_button(root, "SETTINGS", _on_settings_pressed)
	_quit_button = _add_button(root, "QUIT", _on_quit_pressed)

	_load_from_router()


func _unhandled_input(event: InputEvent) -> void:
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
	_player_count_spin = SpinBox.new()
	_player_count_spin.min_value = 2
	_player_count_spin.max_value = 99
	_player_count_spin.step = 1
	_player_count_spin.value = 99
	row.add_child(label)
	row.add_child(_player_count_spin)
	return row


func _add_button(parent: Control, text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
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
	# Settings 画面の中身は #52。ここでは遷移だけ用意しておく。
	get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
