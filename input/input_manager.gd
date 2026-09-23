class_name InputManager
extends Node

## Input Action を [enum GameCommand.Command] へ変換する（要件定義 §11）。
##
## ゲームロジックはこの Node の signal と問い合わせだけを見る。物理キーや
## ボタン番号はここから先へ出さない。Controller 対応（Phase 3）と Remapping
## （Phase 9）も、ここと InputMap の設定だけで完結させる。

## コマンドが押された。
signal command_pressed(command: GameCommand.Command)

## コマンドが離された。
signal command_released(command: GameCommand.Command)

var _pressed: Dictionary = {}


func _notification(what: int) -> void:
	# Window から外れると、押しっぱなしのキーの解放イベントが来ないことがある。
	# そのまま放置すると移動や Soft Drop が続くため、ここで解除して signal を出す。
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		release_all()


func _unhandled_input(event: InputEvent) -> void:
	for command in GameCommand.get_all_commands():
		var action_name: String = GameCommand.get_action_name(command)
		if not InputMap.has_action(action_name):
			continue

		if event.is_action_pressed(action_name, false, true):
			_set_pressed(command, true)
			get_viewport().set_input_as_handled()
		elif event.is_action_released(action_name, true):
			_set_pressed(command, false)
			get_viewport().set_input_as_handled()


## コマンドが押されているかを返す。
func is_pressed(command: GameCommand.Command) -> bool:
	return _pressed.get(command, false)


## 押されている状態をすべて解除する。Pause やフォーカス喪失で使う。
func release_all() -> void:
	for command in _pressed.keys():
		if _pressed[command]:
			_set_pressed(command, false)


## Input Action がすべて登録されているかを返す。起動時の検証に使う。
static func has_all_actions() -> bool:
	for command in GameCommand.get_all_commands():
		if not InputMap.has_action(GameCommand.get_action_name(command)):
			return false
	return true


func _set_pressed(command: GameCommand.Command, pressed: bool) -> void:
	if _pressed.get(command, false) == pressed:
		return

	_pressed[command] = pressed
	if pressed:
		command_pressed.emit(command)
	else:
		command_released.emit(command)
