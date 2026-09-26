extends GutTest

## 単体プレイ画面が実際に動くことの確認。
##
## CI の起動検証は Boot → MainMenu までしか進まないため、この画面は自動では
## 一度も実行されない。ここで Scene を組み立てて数フレーム進め、実行時エラーが
## 出ないことを確かめる。

const SOLO_PLAY := preload("res://scenes/solo/solo_play.tscn")


func test_scene_starts_and_runs() -> void:
	var scene: Node = SOLO_PLAY.instantiate()

	add_child_autofree(scene)
	await wait_frames(5)

	assert_not_null(scene.get_node_or_null("InputManager"), "InputManager が組み込まれる")
	assert_true(scene.is_inside_tree(), "Scene が動いている")


func test_input_actions_are_registered() -> void:
	# 要件定義 §15 の Keyboard Mapping が project.godot に入っていること。
	assert_true(InputManager.has_all_actions(), "全コマンドの Input Action がある")

	for command in GameCommand.get_all_commands():
		var action_name: String = GameCommand.get_action_name(command)
		assert_true(InputMap.has_action(action_name), "%s が登録されている" % action_name)
		assert_gt(
			InputMap.action_get_events(action_name).size(), 0, "%s にキーが割り当てられている" % action_name
		)


func test_paused_screen_ignores_gameplay_commands() -> void:
	# set_process() を止めても InputManager は入力を受け続けるため、Pause 中の
	# コマンドが Session へ届かないことを確かめる。
	var scene: Node = SOLO_PLAY.instantiate()
	add_child_autofree(scene)
	await wait_frames(2)

	scene._on_command_pressed(GameCommand.Command.PAUSE)

	var piece: ActivePiece = scene._session.get_active_piece()
	var before: Vector2i = piece.position
	scene._on_command_pressed(GameCommand.Command.MOVE_LEFT)
	scene._on_command_pressed(GameCommand.Command.HARD_DROP)

	assert_eq(scene._session.get_active_piece().position, before, "Pause 中は Piece が動かない")
	assert_false(scene._session.is_over(), "Pause 中の Hard Drop で進行しない")


func test_topped_out_screen_cannot_be_resumed_by_pause() -> void:
	# TOP OUT 後に PAUSE を押しても再開しないことを確かめる。
	var scene: Node = SOLO_PLAY.instantiate()
	add_child_autofree(scene)
	await wait_frames(2)

	scene._on_topped_out()
	scene._on_command_pressed(GameCommand.Command.PAUSE)

	assert_eq(scene._state, scene.ScreenState.TOPPED_OUT, "TOP OUT のまま維持される")
