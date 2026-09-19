extends Node

## Game State と Scene 遷移を一元管理する Autoload。
## 要件定義 §107 Scene構成 / §109 Game State に対応する。
##
## Game Core（core/）はこの Node を参照しない。Scene 遷移は Presentation の責務とする。

signal state_changed(previous: GameState.State, current: GameState.State)

const SCENE_PATHS: Dictionary = {
	GameState.State.MAIN_MENU: "res://scenes/main_menu/main_menu.tscn",
	GameState.State.PLAYING: "res://scenes/battle/battle.tscn",
	GameState.State.RESULT: "res://scenes/result/result.tscn",
}

var current_state: GameState.State = GameState.State.BOOT


## 状態を遷移させ、対応する Scene があれば切り替える。
func change_state(next_state: GameState.State) -> void:
	if next_state == current_state:
		return

	var previous: GameState.State = current_state
	current_state = next_state
	state_changed.emit(previous, current_state)

	if not SCENE_PATHS.has(next_state):
		return

	# 呼び出し元の _ready() 中に切り替えると SceneTree が子の追加中で落ちるため、
	# 実際の切り替えは常にフレーム終端まで遅延させる。
	_change_scene.call_deferred(SCENE_PATHS[next_state])


func _change_scene(path: String) -> void:
	var error: Error = get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("Scene の切り替えに失敗しました: %s (error=%d)" % [path, error])
