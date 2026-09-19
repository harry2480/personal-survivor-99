extends Control

## Main Menu の骨格。項目と遷移は Phase 9（#51）で実装する。
##
## Phase 1 の間は、動作確認用の単体プレイ画面（scenes/solo/）へ入るための
## 入口だけを置いている。ここは #51 で正式なメニューに置き換わる。

const START_ACTION: StringName = &"ui_accept"

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.text = (
		"Project 99 — Phase 1 動作確認\n\n"
		+ "Enter / Space でプレイ開始\n\n"
		+ "← →: 移動    ↓: Soft Drop    Space: Hard Drop\n"
		+ "Z / X: 回転    C: Hold    Esc: Pause"
	)
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.position = Vector2(80, 80)
	add_child(_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(START_ACTION, false, true):
		get_viewport().set_input_as_handled()
		SceneRouter.change_state(GameState.State.PLAYING)
