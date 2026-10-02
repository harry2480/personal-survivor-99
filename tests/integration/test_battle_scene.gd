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


func test_commands_do_not_move_the_board_while_paused() -> void:
	var scene: Node = _new_battle_scene()
	await wait_frames(3)

	var input: InputManager = scene.get_node("InputManager")
	input.command_pressed.emit(GameCommand.Command.PAUSE)
	var locked: Array = []
	scene.get_viewer().session.piece_locked.connect(func(type: int) -> void: locked.append(type))

	input.command_pressed.emit(GameCommand.Command.HARD_DROP)
	input.command_pressed.emit(GameCommand.Command.HOLD)

	assert_true(scene.is_paused(), "PAUSE で止まる")
	assert_eq(locked.size(), 0, "止めている間は Hard Drop しない（要件定義 §96）")
	assert_true(scene.get_viewer().session.get_hold_slot().is_empty(), "Hold もしない")

	input.command_pressed.emit(GameCommand.Command.PAUSE)
	input.command_pressed.emit(GameCommand.Command.HARD_DROP)

	assert_false(scene.is_paused(), "もう一度 PAUSE で戻る")
	assert_eq(locked.size(), 1, "戻せば操作できる")


func test_selecting_the_current_target_shows_the_manual_mode() -> void:
	var scene: Node = _new_battle_scene()
	await wait_frames(3)

	# 今の Target をそのまま選ぶと、Target は変わらず target_changed も出ない。
	var current: int = scene.get_viewer().current_target
	assert_gte(current, 0, "開始時点で Target が決まっている")
	scene.get_node("OpponentGrid").opponent_selected.emit(current)

	var hud: BattleHud = scene.get_node("BattleHud")
	assert_eq(
		hud.get_value("target_mode"),
		TargetMode.get_mode_name(TargetMode.Mode.MANUAL),
		"選んだ時点で Manual と表示する（要件定義 §52）"
	)


func test_selected_target_takes_effect_before_the_next_step() -> void:
	var scene: Node = _new_battle_scene()
	await wait_frames(3)

	# 止めておけば step() は走らない。選んだ直後の攻撃が新しい相手へ向かうかを見る。
	scene.set_paused(true)
	var viewer: BattlePlayerState = scene.get_viewer()
	var grid: OpponentGrid = scene.get_node("OpponentGrid")
	var target_id: int = -1
	for tile in grid.get_tiles():
		if tile.player_id != viewer.current_target:
			target_id = tile.player_id
			break
	grid.opponent_selected.emit(target_id)

	assert_eq(viewer.current_target, target_id, "選んだ時点で Target が切り替わる（要件定義 §52）")
	assert_eq(scene.get_node("BattleHud").get_value("target"), "P%d" % target_id, "HUD も選んだ相手を出す")


func test_defeat_sound_plays_once_when_the_viewer_loses() -> void:
	# 自分の KO で Defeat が鳴る。決着の処理で重ねて鳴らさない（#53）。
	SceneRouter.current_state = GameState.State.PLAYING
	var scene: Node = _new_battle_scene()
	await wait_frames(3)
	var audio: AudioManager = scene.get_audio_manager()

	scene.get_runner().get_manager().eliminate_player(scene.VIEWER_ID)
	audio._process(AudioManager.THROTTLE_SEC * 2.0)
	scene._on_battle_finished()

	assert_eq(audio.get_played_count(AudioManager.Event.DEFEAT), 1, "Defeat は 1 回だけ")
	assert_eq(audio.get_played_count(AudioManager.Event.VICTORY), 0, "負けたら Victory は鳴らない")
	SceneRouter.current_state = GameState.State.MAIN_MENU


func test_views_fit_in_the_screen() -> void:
	var scene: Node = _new_battle_scene()
	await wait_frames(3)

	var screen := Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width")),
		float(ProjectSettings.get_setting("display/window/size/viewport_height"))
	)
	for view_name in ["PlayerBoardPanel", "BattleHud", "ControlsGuide", "DebugOverlay"]:
		var view: Control = scene.get_node(view_name)
		var bottom_right: Vector2 = view.position + view.size
		assert_lte(bottom_right.x, screen.x, "%s の右端が画面の中に収まる" % view_name)
		assert_lte(bottom_right.y, screen.y, "%s の下端が画面の中に収まる" % view_name)


func test_player_board_is_below_the_opponent_grid() -> void:
	var scene: Node = _new_battle_scene()
	await wait_frames(3)

	var grid: OpponentGrid = scene.get_node("OpponentGrid")
	var rows: int = ceili(float(grid.get_tiles().size()) / float(OpponentGrid.COLUMNS))
	var grid_bottom: float = (
		grid.position.y + float(rows) * (OpponentGrid.TILE_SIZE.y + OpponentGrid.TILE_MARGIN)
	)
	var panel: Control = scene.get_node("PlayerBoardPanel")
	assert_gte(panel.position.y, grid_bottom, "自分の盤面が相手一覧に重ならない")
