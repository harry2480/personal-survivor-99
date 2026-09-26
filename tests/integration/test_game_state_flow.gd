extends GutTest

## Game State の遷移と Game Start Flow の確認（要件定義 §94 〜 §96 / §109）。
##
## Boot → Main Menu → Battle → Pause → Restart / Quit to Menu を通し、
## 繰り返しても状態が壊れないことを見る（#51 の完了条件）。

const MAIN_MENU := preload("res://scenes/main_menu/main_menu.tscn")


func before_each() -> void:
	# 他のテストの影響を受けないよう、毎回 Main Menu の状態から始める。
	SceneRouter.current_state = GameState.State.MAIN_MENU
	SceneRouter.set_battle_setup(BattleSetup.create_default())


func after_each() -> void:
	SceneRouter.current_state = GameState.State.MAIN_MENU


# --- 状態遷移（要件定義 §109） ----------------------------------------------


func test_allowed_transitions_follow_the_requirement() -> void:
	SceneRouter.current_state = GameState.State.BOOT
	assert_true(SceneRouter.can_change_state(GameState.State.MAIN_MENU), "BOOT → MAIN_MENU")

	SceneRouter.current_state = GameState.State.PLAYING
	assert_true(SceneRouter.can_change_state(GameState.State.PAUSED), "PLAYING → PAUSED")
	assert_true(SceneRouter.can_change_state(GameState.State.FINISHED), "PLAYING → FINISHED")

	SceneRouter.current_state = GameState.State.FINISHED
	assert_true(SceneRouter.can_change_state(GameState.State.RESULT), "FINISHED → RESULT")

	SceneRouter.current_state = GameState.State.RESULT
	assert_true(SceneRouter.can_change_state(GameState.State.MAIN_MENU), "RESULT → MAIN_MENU")


func test_invalid_transitions_are_rejected() -> void:
	SceneRouter.current_state = GameState.State.BOOT

	assert_false(SceneRouter.can_change_state(GameState.State.PLAYING), "BOOT から直接は始めない")
	assert_false(SceneRouter.can_change_state(GameState.State.RESULT), "BOOT から Result へは行かない")


func test_rejected_transition_keeps_the_current_state() -> void:
	SceneRouter.current_state = GameState.State.BOOT

	SceneRouter.change_state(GameState.State.RESULT)

	assert_eq(SceneRouter.current_state, GameState.State.BOOT, "通らない遷移では状態が動かない")


func test_state_changed_is_emitted() -> void:
	var changes: Array = []
	var listener: Callable = func(previous: int, current: int) -> void:
		changes.append([previous, current])
	SceneRouter.state_changed.connect(listener)

	SceneRouter.change_state(GameState.State.LOADING)
	SceneRouter.state_changed.disconnect(listener)

	assert_eq(changes, [[GameState.State.MAIN_MENU, GameState.State.LOADING]], "遷移が 1 回通知される")


# --- Game Start Flow（要件定義 §95） ----------------------------------------


func test_starting_a_battle_goes_through_loading() -> void:
	var seen: Array[int] = []
	var listener: Callable = func(_previous: int, current: int) -> void: seen.append(current)
	SceneRouter.state_changed.connect(listener)

	SceneRouter.start_battle()
	SceneRouter.state_changed.disconnect(listener)

	assert_eq(seen, [GameState.State.LOADING, GameState.State.PLAYING], "LOADING を挟んで始まる")


func test_starting_a_battle_fixes_the_seed() -> void:
	SceneRouter.start_battle()

	assert_ne(SceneRouter.get_battle_setup().battle_seed, 0, "Seed が決まる（要件定義 §110）")


func test_menu_hands_over_the_chosen_settings() -> void:
	var menu: Control = MAIN_MENU.instantiate()
	add_child_autofree(menu)
	menu.get_difficulty_panel().choose_preset(CpuPreset.Preset.HARD)

	var setup: BattleSetup = menu.build_setup()

	assert_eq(setup.cpu_settings.preset, CpuPreset.Preset.HARD, "選んだ難易度が渡る")
	assert_eq(setup.player_count, 99, "人数も渡る（既定は 99 人）")


func test_player_count_reaches_the_battle_setup() -> void:
	var setup: BattleSetup = BattleSetup.create_default()
	setup.player_count = 10

	assert_eq(setup.get_cpu_count(), 9, "Human 1 人を除いた数が CPU の人数")


# --- Pause（要件定義 §96） --------------------------------------------------


func test_pause_and_resume_move_the_state() -> void:
	SceneRouter.start_battle()

	SceneRouter.set_battle_paused(true)
	assert_eq(SceneRouter.current_state, GameState.State.PAUSED, "Pause で PAUSED へ")

	SceneRouter.set_battle_paused(false)
	assert_eq(SceneRouter.current_state, GameState.State.PLAYING, "Resume で PLAYING へ戻る")


func test_pause_menu_has_every_item() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)

	for action in [
		PauseMenu.Action.RESUME,
		PauseMenu.Action.RESTART,
		PauseMenu.Action.SETTINGS,
		PauseMenu.Action.QUIT_TO_MENU
	]:
		assert_not_null(menu.get_button(action), "%s がある" % PauseMenu.ACTION_LABELS[action])


func test_pause_menu_reports_the_selection() -> void:
	var menu := PauseMenu.new()
	add_child_autofree(menu)
	var selected: Array[int] = []
	menu.action_selected.connect(func(action: int) -> void: selected.append(action))

	menu.select(PauseMenu.Action.RESTART)

	assert_eq(selected, [PauseMenu.Action.RESTART] as Array[int], "選ばれた項目を伝える")


# --- Restart / Quit to Menu（要件定義 §96） ---------------------------------


func test_restart_draws_a_new_seed() -> void:
	SceneRouter.start_battle()
	var first_seed: int = SceneRouter.get_battle_setup().battle_seed

	SceneRouter.restart_battle()

	assert_eq(SceneRouter.current_state, GameState.State.PLAYING, "PLAYING に戻る")
	assert_ne(SceneRouter.get_battle_setup().battle_seed, first_seed, "Seed を引き直す")


func test_quit_to_menu_returns_to_the_menu() -> void:
	SceneRouter.start_battle()

	SceneRouter.quit_to_menu()

	assert_eq(SceneRouter.current_state, GameState.State.MAIN_MENU, "Main Menu へ戻る")
	assert_eq(SceneRouter.get_battle_setup().battle_seed, 0, "次は Seed を引き直す")


func test_repeating_start_and_quit_keeps_the_state_sane() -> void:
	for _round in range(5):
		SceneRouter.start_battle()
		assert_eq(SceneRouter.current_state, GameState.State.PLAYING, "始まる")

		SceneRouter.set_battle_paused(true)
		SceneRouter.set_battle_paused(false)

		SceneRouter.quit_to_menu()
		assert_eq(SceneRouter.current_state, GameState.State.MAIN_MENU, "戻る")

	assert_eq(SceneRouter.get_battle_setup().player_count, 99, "設定は保たれる")


func test_finishing_a_battle_reaches_the_result() -> void:
	SceneRouter.start_battle()

	SceneRouter.finish_battle()

	assert_eq(SceneRouter.current_state, GameState.State.RESULT, "決着したら Result へ")
