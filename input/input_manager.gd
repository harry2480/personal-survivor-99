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

## Controller が接続された（Device Detection。要件定義 §13）。
signal device_connected(device_id: int, device_name: String)

## Controller が切断された。切断後の扱いは #33 で詰める。
signal device_disconnected(device_id: int, device_name: String)

var _pressed: Dictionary = {}
var _device_names: Dictionary = {}


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for device_id in Input.get_connected_joypads():
		_device_names[device_id] = Input.get_joy_name(device_id)


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

		# exact_match は指定しない。Input Action に修飾キーを設定していないため、
		# ← を押したまま Shift を足して離すと、release 側だけ完全一致に失敗して
		# 押しっぱなし扱いが残る（要件定義 §15 の Keyboard Mapping は修飾キーなし）。
		if event.is_action_pressed(action_name, false):
			_set_pressed(command, true)
			get_viewport().set_input_as_handled()
		elif event.is_action_released(action_name):
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


## Stick 入力のしきい値（Dead Zone）を全 Action へ適用する（要件定義 §14）。
##
## 値は [GameRules] から来る。Controller の個体差を吸収するため、実行時に
## 変更できるようにしている。
static func apply_dead_zone(dead_zone: float) -> void:
	var value: float = clampf(dead_zone, 0.0, 0.99)
	for command in GameCommand.get_all_commands():
		var action_name: String = GameCommand.get_action_name(command)
		if InputMap.has_action(action_name):
			InputMap.action_set_deadzone(action_name, value)


## 接続されている Controller の ID を返す。
func get_connected_devices() -> Array[int]:
	var devices: Array[int] = []
	for device_id in _device_names:
		devices.append(device_id)
	return devices


## Controller が 1 台でも接続されているかを返す。
func has_connected_device() -> bool:
	return not _device_names.is_empty()


## Input Action がすべて登録されているかを返す。起動時の検証に使う。
static func has_all_actions() -> bool:
	for command in GameCommand.get_all_commands():
		if not InputMap.has_action(GameCommand.get_action_name(command)):
			return false
	return true


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		var device_name: String = Input.get_joy_name(device_id)
		_device_names[device_id] = device_name
		device_connected.emit(device_id, device_name)
		return

	var previous_name: String = _device_names.get(device_id, "")
	_device_names.erase(device_id)
	# 押されたままのコマンドを残すと、切断後に動き続けてしまう。
	release_all()
	device_disconnected.emit(device_id, previous_name)


func _set_pressed(command: GameCommand.Command, pressed: bool) -> void:
	if _pressed.get(command, false) == pressed:
		return

	_pressed[command] = pressed
	if pressed:
		command_pressed.emit(command)
	else:
		command_released.emit(command)
