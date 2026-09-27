extends Control

## Settings 画面の骨格。設定項目と永続化は Phase 9（#52）で実装する。
##
## [SceneRouter] が今の画面（Main Menu / Pause 中の Battle）の上に重ねて開く。
## 閉じるのも [SceneRouter] を通し、Game State は変えない（要件定義 §107 / §109）。

## 閉じるときに使う Action。
const CLOSE_ACTION: StringName = &"ui_cancel"


func _ready() -> void:
	var root := VBoxContainer.new()
	root.name = "Menu"
	root.position = Vector2(80.0, 60.0)
	add_child(root)

	var title := Label.new()
	title.text = "SETTINGS"
	root.add_child(title)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "BACK"
	back.pressed.connect(close)
	root.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(CLOSE_ACTION, false, true):
		get_viewport().set_input_as_handled()
		close()


## 閉じて元の画面へ戻る。
func close() -> void:
	SceneRouter.close_settings()
