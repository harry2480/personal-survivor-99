extends GutTest

## Battle 画面が実際に動くことの確認（要件定義 §87 / §107）。
##
## CI の起動検証は Boot → MainMenu までしか進まないため、この画面は自動では
## 一度も実行されない。ここで Scene を組み立てて数フレーム進め、
## Board / Opponent Grid / HUD が揃って動くことを確かめる。

const BATTLE := preload("res://scenes/battle/battle.tscn")


func _new_battle_scene() -> Node:
	var scene: Node = BATTLE.instantiate()
	add_child_autofree(scene)
	return scene


func test_scene_builds_every_view() -> void:
	var scene: Node = _new_battle_scene()
	await wait_frames(3)

	assert_not_null(scene.get_node_or_null("PlayerBoardPanel"), "自分の盤面がある（#48）")
	assert_not_null(scene.get_node_or_null("OpponentGrid"), "対戦相手の一覧がある（#49）")
	assert_not_null(scene.get_node_or_null("BattleHud"), "HUD がある（#50）")
	assert_not_null(scene.get_node_or_null("InputManager"), "Input がある（§11）")


func test_battle_starts_with_the_standard_player_count() -> void:
	var scene: Node = _new_battle_scene()
	await wait_frames(3)

	# 要件定義 §44: Human × 1 + CPU × 98。
	var manager: BattleManager = scene.get_runner().get_manager()
	assert_eq(manager.get_player_count(), 99, "99 人で始まる")
	assert_eq(scene.get_viewer().player_type, PlayerType.Type.LOCAL_HUMAN, "自分は Human")


func test_hud_shows_the_battle_state() -> void:
	var scene: Node = _new_battle_scene()
	await wait_frames(3)

	var hud: BattleHud = scene.get_node("BattleHud")
	assert_eq(hud.get_value("remaining"), "99", "残り人数が出る")
	assert_ne(hud.get_value("rank"), "", "順位が出る")


func test_opponent_grid_shows_the_other_players() -> void:
	var scene: Node = _new_battle_scene()
	await wait_frames(3)

	var grid: OpponentGrid = scene.get_node("OpponentGrid")
	assert_eq(grid.get_tiles().size(), 98, "自分を除く 98 面が並ぶ")


func test_battle_advances_over_frames() -> void:
	var scene: Node = _new_battle_scene()
	await wait_frames(10)

	assert_gt(scene.get_runner().get_elapsed_sec(), 0.0, "時間が進む")
	assert_gt(scene.get_runner().get_frame_stats().frames, 0, "フレームが進む")


func test_pause_stops_the_battle() -> void:
	var scene: Node = _new_battle_scene()
	await wait_frames(3)

	scene.set_paused(true)
	var elapsed: float = scene.get_runner().get_elapsed_sec()
	await wait_frames(5)

	assert_true(scene.is_paused(), "Pause 中")
	assert_eq(scene.get_runner().get_elapsed_sec(), elapsed, "止めている間は進まない")

	scene.set_paused(false)
	await wait_frames(3)

	assert_gt(scene.get_runner().get_elapsed_sec(), elapsed, "戻せば進む")


func test_selecting_an_opponent_sets_the_manual_target() -> void:
	var scene: Node = _new_battle_scene()
	await wait_frames(3)

	var grid: OpponentGrid = scene.get_node("OpponentGrid")
	var target_id: int = grid.get_tiles()[5].player_id
	grid.opponent_selected.emit(target_id)

	assert_eq(
		scene.get_runner().get_target_manager().get_manual_target(0),
		target_id,
		"選んだ相手が Manual Target になる（要件定義 §52）"
	)
