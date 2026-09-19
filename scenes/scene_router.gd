extends Node

## Game State と Scene 遷移を一元管理する Autoload。
## 要件定義 §107 Scene構成 / §109 Game State に対応する。
##
## Game Core（core/）はこの Node を参照しない。Scene 遷移は Presentation の責務とする。

## 状態が変わった直後に発火する。実際の Scene 切り替えはこの後フレーム終端で行われる。
signal state_changed(previous: GameState.State, current: GameState.State)

## 状態に対応する Scene。ここに無い状態（LOADING / PAUSED / FINISHED）は
## Scene を切り替えず、現在の Scene の上で扱う。
const SCENE_PATHS: Dictionary = {
	GameState.State.MAIN_MENU: "res://scenes/main_menu/main_menu.tscn",
	# Phase 1 の間は動作確認用の単体プレイ画面を使う。
	# Battle Scene（scenes/battle/）へ戻すのは Phase 8（#48〜#50）。
	GameState.State.PLAYING: "res://scenes/solo/solo_play.tscn",
	GameState.State.RESULT: "res://scenes/result/result.tscn",
}

var current_state: GameState.State = GameState.State.BOOT

var _current_scene_path: String = ""


## 状態を遷移させ、対応する Scene があれば切り替える。
func change_state(next_state: GameState.State) -> void:
	if next_state == current_state:
		return

	var previous: GameState.State = current_state
	current_state = next_state
	state_changed.emit(previous, current_state)

	if not SCENE_PATHS.has(next_state):
		return

	var path: String = SCENE_PATHS[next_state]

	# 同じ Scene への遷移では読み込み直さない。
	# これが無いと PLAYING → PAUSED → PLAYING で Battle が最初からやり直しになる。
	if path == _current_scene_path:
		return

	var previous_scene_path: String = _current_scene_path
	_current_scene_path = path

	# 呼び出し元の _ready() 中に切り替えると SceneTree が子の追加中で落ちるため、
	# 実際の切り替えは常にフレーム終端まで遅延させる。
	_change_scene.call_deferred(path, next_state, previous, previous_scene_path)


## 遅延実行される実際の Scene 切り替え。失敗した場合は状態を呼び出し前へ戻す。
func _change_scene(
	path: String,
	attempted_state: GameState.State,
	previous_state: GameState.State,
	previous_scene_path: String,
) -> void:
	var error: Error = get_tree().change_scene_to_file(path)
	if error == OK:
		return

	# 状態を戻さないと current_state だけが先に進み、同じ状態への再試行が
	# change_state() 冒頭の同値判定で無視されて復帰できなくなる。
	push_error("Scene の切り替えに失敗しました: %s (error=%d)" % [path, error])

	# 遅延中に別の遷移が走っていた場合は、そちらを優先して巻き戻さない。
	if current_state != attempted_state:
		return

	current_state = previous_state
	_current_scene_path = previous_scene_path
	state_changed.emit(attempted_state, previous_state)
