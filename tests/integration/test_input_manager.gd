extends GutTest

## Input Action → Game Command の変換（要件定義 §11）の確認。
##
## [InputManager] は Scene Tree に入れて使う Node なので、ここ（integration）で見る。
## 実機の Controller を挿す確認は自動化できないため、接続・切断は通知を直接渡す。

var manager: InputManager
var pressed: Array = []
var released: Array = []


func before_each() -> void:
	manager = InputManager.new()
	add_child_autofree(manager)
	pressed = []
	released = []
	manager.command_pressed.connect(func(command: int) -> void: pressed.append(command))
	manager.command_released.connect(func(command: int) -> void: released.append(command))


func _action_event(command: GameCommand.Command, is_pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = GameCommand.get_action_name(command)
	event.pressed = is_pressed
	return event


# --- GameCommand ------------------------------------------------------------


func test_action_names_round_trip() -> void:
	for command in GameCommand.get_all_commands():
		var action_name: String = GameCommand.get_action_name(command)
		assert_eq(GameCommand.from_action_name(action_name), command, "%s から戻せる" % action_name)


func test_unknown_action_name_is_rejected() -> void:
	assert_eq(GameCommand.from_action_name("no_such_action"), -1, "知らない Action は -1")


func test_only_target_commands_switch_the_target() -> void:
	var target_commands: Array[int] = [
		GameCommand.Command.TARGET_RANDOM,
		GameCommand.Command.TARGET_KO,
		GameCommand.Command.TARGET_BADGE,
		GameCommand.Command.TARGET_COUNTER,
	]
	for command in GameCommand.get_all_commands():
		assert_eq(
			GameCommand.is_target_command(command),
			command in target_commands,
			"%s" % GameCommand.get_action_name(command)
		)


# --- InputManager -----------------------------------------------------------


func test_every_command_has_an_input_action() -> void:
	assert_true(InputManager.has_all_actions(), "project.godot に全コマンドの Action がある")


func test_press_and_release_become_commands() -> void:
	manager._unhandled_input(_action_event(GameCommand.Command.MOVE_LEFT, true))

	assert_true(manager.is_pressed(GameCommand.Command.MOVE_LEFT), "押されている")
	assert_eq(pressed, [GameCommand.Command.MOVE_LEFT], "押したことを知らせる")

	manager._unhandled_input(_action_event(GameCommand.Command.MOVE_LEFT, false))

	assert_false(manager.is_pressed(GameCommand.Command.MOVE_LEFT), "離された")
	assert_eq(released, [GameCommand.Command.MOVE_LEFT], "離したことを知らせる")


func test_repeated_press_is_reported_once() -> void:
	manager._unhandled_input(_action_event(GameCommand.Command.HARD_DROP, true))
	manager._unhandled_input(_action_event(GameCommand.Command.HARD_DROP, true))

	assert_eq(pressed.size(), 1, "押しっぱなしの間は 1 回だけ")


func test_release_all_clears_held_commands() -> void:
	manager._unhandled_input(_action_event(GameCommand.Command.MOVE_LEFT, true))
	manager._unhandled_input(_action_event(GameCommand.Command.SOFT_DROP, true))

	manager.release_all()

	assert_false(manager.is_pressed(GameCommand.Command.MOVE_LEFT), "移動を解除する")
	assert_false(manager.is_pressed(GameCommand.Command.SOFT_DROP), "Soft Drop を解除する")
	assert_eq(released.size(), 2, "解除したことを知らせる")


func test_focus_out_releases_held_commands() -> void:
	# Window から外れると解放イベントが来ないことがある。押しっぱなしを残さない。
	manager._unhandled_input(_action_event(GameCommand.Command.MOVE_RIGHT, true))

	manager.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)

	assert_false(manager.is_pressed(GameCommand.Command.MOVE_RIGHT), "フォーカスが外れたら解除する")


func test_controller_connection_is_tracked() -> void:
	var connected: Array = []
	var disconnected: Array = []
	manager.device_connected.connect(func(id: int, _name: String) -> void: connected.append(id))
	manager.device_disconnected.connect(
		func(id: int, _name: String) -> void: disconnected.append(id)
	)

	manager._on_joy_connection_changed(7, true)

	assert_true(manager.has_connected_device(), "接続を覚える")
	assert_true(7 in manager.get_connected_devices(), "接続した ID を返す")
	assert_eq(connected, [7], "接続を知らせる")

	manager._unhandled_input(_action_event(GameCommand.Command.MOVE_LEFT, true))
	manager._on_joy_connection_changed(7, false)

	assert_false(7 in manager.get_connected_devices(), "切断した ID は外す")
	assert_eq(disconnected, [7], "切断を知らせる")
	assert_false(manager.is_pressed(GameCommand.Command.MOVE_LEFT), "切断したら押しっぱなしを解除する")
