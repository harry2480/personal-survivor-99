extends GutTest

## Controller Mapping の確認（要件定義 §14）。
##
## 実機での操作確認は自動化できないため、ここでは「割り当てが正しく登録されて
## いるか」と「Dead Zone を設定値として扱えるか」までを見る。

const CONTROLLER_COMMANDS: Array[int] = [
	GameCommand.Command.MOVE_LEFT,
	GameCommand.Command.MOVE_RIGHT,
	GameCommand.Command.SOFT_DROP,
	GameCommand.Command.HARD_DROP,
	GameCommand.Command.ROTATE_LEFT,
	GameCommand.Command.ROTATE_RIGHT,
	GameCommand.Command.HOLD,
	GameCommand.Command.PAUSE,
]


func _joypad_events(action_name: String) -> Array:
	var found: Array = []
	for event in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			found.append(event)
	return found


func test_every_play_command_has_a_controller_binding() -> void:
	# Keyboard なしでプレイできることの前提（Phase 3 完了条件）。
	for command in CONTROLLER_COMMANDS:
		var action_name: String = GameCommand.get_action_name(command)
		assert_gt(_joypad_events(action_name).size(), 0, "%s に Controller 割り当てがある" % action_name)


func test_keyboard_bindings_are_kept() -> void:
	for command in GameCommand.get_all_commands():
		var action_name: String = GameCommand.get_action_name(command)
		var has_key: bool = false
		for event in InputMap.action_get_events(action_name):
			if event is InputEventKey:
				has_key = true
		assert_true(has_key, "%s の Keyboard 割り当ては残っている" % action_name)


func test_standard_mapping_follows_the_requirement() -> void:
	var expected: Dictionary = {
		"move_left": JOY_BUTTON_DPAD_LEFT,
		"move_right": JOY_BUTTON_DPAD_RIGHT,
		"soft_drop": JOY_BUTTON_DPAD_DOWN,
		"hard_drop": JOY_BUTTON_DPAD_UP,
		"rotate_right": JOY_BUTTON_A,
		"rotate_left": JOY_BUTTON_B,
		"pause": JOY_BUTTON_START,
	}
	for action_name in expected:
		var buttons: Array = []
		for event in _joypad_events(action_name):
			if event is InputEventJoypadButton:
				buttons.append(event.button_index)
		assert_true(expected[action_name] in buttons, "%s の割り当てが §14 どおり" % action_name)


func test_hold_accepts_both_shoulders() -> void:
	var buttons: Array = []
	for event in _joypad_events("hold"):
		if event is InputEventJoypadButton:
			buttons.append(event.button_index)

	assert_true(JOY_BUTTON_LEFT_SHOULDER in buttons, "L で Hold できる")
	assert_true(JOY_BUTTON_RIGHT_SHOULDER in buttons, "R で Hold できる")


func test_target_commands_use_the_right_stick() -> void:
	for action_name in ["target_random", "target_ko", "target_badge", "target_counter"]:
		var axes: Array = []
		for event in _joypad_events(action_name):
			if event is InputEventJoypadMotion:
				axes.append(event.axis)
		assert_true(
			JOY_AXIS_RIGHT_X in axes or JOY_AXIS_RIGHT_Y in axes,
			"%s は Right Stick に割り当てられている" % action_name
		)


func test_dead_zone_is_configurable() -> void:
	var original: float = InputMap.action_get_deadzone("move_left")

	InputManager.apply_dead_zone(0.25)
	assert_almost_eq(InputMap.action_get_deadzone("move_left"), 0.25, 0.001, "設定値が反映される")

	InputManager.apply_dead_zone(original)
	assert_almost_eq(InputMap.action_get_deadzone("move_left"), original, 0.001, "元に戻せる")


func test_dead_zone_is_clamped() -> void:
	var original: float = InputMap.action_get_deadzone("move_left")

	InputManager.apply_dead_zone(5.0)
	assert_lt(InputMap.action_get_deadzone("move_left"), 1.0, "1.0 未満に丸める")

	InputManager.apply_dead_zone(-1.0)
	assert_eq(InputMap.action_get_deadzone("move_left"), 0.0, "負の値は 0 に丸める")

	InputManager.apply_dead_zone(original)


func test_dead_zone_comes_from_the_rules() -> void:
	var rules := GameRules.create_default()

	assert_true(rules.stick_dead_zone > 0.0, "既定値が入っている")
	assert_eq(rules.apply_user_settings({"stick_dead_zone": 0.3}), 1, "ユーザー設定で変えられる")
	assert_eq(rules.stick_dead_zone, 0.3, "反映される")
	assert_eq(rules.apply_user_settings({"stick_dead_zone": 1.5}), 0, "1.0 以上は採用しない")
