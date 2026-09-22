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
