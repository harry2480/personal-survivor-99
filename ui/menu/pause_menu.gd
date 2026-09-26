class_name PauseMenu
extends VBoxContainer

## Pause メニュー（要件定義 §96）。
##
## 項目は Resume / Restart / Settings / Quit to Menu の 4 つ。
##
## この画面は**選ばれたことを伝えるだけ**で、止める・やり直す・戻るの実処理は
## Battle 画面と [SceneRouter] が行う。Presentation の中で責務を分けておく。

## 項目が選ばれた。
signal action_selected(action: Action)

## 選べる項目（要件定義 §96）。
enum Action { RESUME, RESTART, SETTINGS, QUIT_TO_MENU }

## 項目の表示名。
const ACTION_LABELS: Dictionary = {
	Action.RESUME: "RESUME",
	Action.RESTART: "RESTART",
	Action.SETTINGS: "SETTINGS",
	Action.QUIT_TO_MENU: "QUIT TO MENU",
}

var _buttons: Dictionary = {}


func _ready() -> void:
	if _buttons.is_empty():
		build()


## 中身を組み立てる。
func build() -> void:
	var title := Label.new()
	title.text = "PAUSED"
	add_child(title)

	for action in [Action.RESUME, Action.RESTART, Action.SETTINGS, Action.QUIT_TO_MENU]:
		var button := Button.new()
		button.text = ACTION_LABELS[action]
		button.pressed.connect(func() -> void: action_selected.emit(action))
		add_child(button)
		_buttons[action] = button


## 項目のボタンを返す。無ければ [code]null[/code]。
func get_button(action: Action) -> Button:
	return _buttons.get(action, null)


## 並んでいる項目を返す。
func get_actions() -> Array[int]:
	var actions: Array[int] = []
	for action in _buttons:
		actions.append(action)
	return actions


## 項目を選ぶ（テストと Controller 用）。
func select(action: Action) -> void:
	if _buttons.has(action):
		action_selected.emit(action)
