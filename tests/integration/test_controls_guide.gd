extends GutTest

## 操作方法の表示と、Keyboard / Pro コントローラーの両対応の確認（要件定義 §12〜§15）。
##
## 表示は InputMap から作るので、ここでは「全操作に両方の割り当てがあるか」と
## 「Pro コントローラーの刻印で読めるか」を見る。実機での操作確認は手動（§136）。

const BATTLE := preload("res://scenes/battle/battle.tscn")

var _original_locale: String


# 表示名は翻訳されるので、英語のキーで比べるテストは英語に固定する。
func before_each() -> void:
	_original_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_each() -> void:
	TranslationServer.set_locale(_original_locale)


func test_every_row_has_keyboard_and_controller() -> void:
	for row in ControlsGuide.ROWS:
		var actions: Array = ControlsGuide.get_row_actions(row)
		assert_ne(
			ControlsGuide.describe_actions(actions, false),
			ControlsGuide.UNBOUND_TEXT,
			"%s を Keyboard で操作できる" % row["label"]
		)
		assert_ne(
			ControlsGuide.describe_actions(actions, true),
			ControlsGuide.UNBOUND_TEXT,
			"%s を Pro コントローラーで操作できる" % row["label"]
		)


func test_keyboard_names_follow_the_mapping() -> void:
	# 要件定義 §15 の初期設定。
	var move: Array = [GameCommand.Command.MOVE_LEFT, GameCommand.Command.MOVE_RIGHT]
	assert_eq(ControlsGuide.describe(move, false), "Left / Right", "移動は矢印キー")
	assert_eq(
		ControlsGuide.describe([GameCommand.Command.HARD_DROP], false), "Space", "Hard Drop は Space"
	)
	assert_eq(ControlsGuide.describe([GameCommand.Command.HOLD], false), "C", "Hold は C")


func test_controller_names_use_switch_labels() -> void:
	# 要件定義 §14 の初期案。Godot の下のボタン（番号 0）は Switch の B。
	var rotate: Array = [GameCommand.Command.ROTATE_LEFT, GameCommand.Command.ROTATE_RIGHT]
	assert_eq(ControlsGuide.describe(rotate, true), "B / A", "左回転は B、右回転は A")
	assert_eq(ControlsGuide.describe([GameCommand.Command.HOLD], true), "L / R", "Hold は L と R")
	assert_eq(ControlsGuide.describe([GameCommand.Command.PAUSE], true), "+", "Pause は +")
	assert_eq(
		ControlsGuide.describe([GameCommand.Command.HARD_DROP], true),
		"D-Pad Up",
		"Hard Drop は十字キーの上"
	)


func test_names_are_shown_in_japanese() -> void:
	TranslationServer.set_locale(SettingsApplier.GAME_LOCALE)
	var move: Array = [GameCommand.Command.MOVE_LEFT, GameCommand.Command.MOVE_RIGHT]
	assert_eq(ControlsGuide.describe(move, false), "← / →", "矢印キーは記号で出す")
	assert_eq(ControlsGuide.describe([GameCommand.Command.HARD_DROP], false), "スペース", "Space は日本語")
	assert_eq(ControlsGuide.describe(move, true), "十字キー← / 十字キー→", "十字キーは日本語")
	assert_eq(
		ControlsGuide.describe([GameCommand.Command.TARGET_RANDOM], true), "右スティック→", "スティックも日本語"
	)


func test_menu_can_be_confirmed_with_a_controller() -> void:
	# Godot の既定の ui_accept / ui_cancel には Controller の割り当てが無い。
	# Switch の慣習どおり A で決定、B で戻る。
	assert_eq(ControlsGuide.describe_actions(["ui_accept"], true), "A", "決定は A")
	assert_eq(ControlsGuide.describe_actions(["ui_cancel"], true), "B", "戻るは B")
	assert_string_contains(
		ControlsGuide.describe_actions(["ui_accept"], false), "Enter", "Keyboard の決定は Enter"
	)


func test_refresh_does_not_duplicate_rows() -> void:
	var guide := ControlsGuide.new()
	add_child_autofree(guide)
	var cells: int = guide.get_child_count()

	guide.refresh()
	guide.refresh()

	assert_eq(guide.get_child_count(), cells, "読み直しても行は増えない")


func test_guide_lists_every_row() -> void:
	var guide := ControlsGuide.new()
	add_child_autofree(guide)

	var expected_cells: int = (ControlsGuide.ROWS.size() + 1) * ControlsGuide.HEADERS.size()
	assert_eq(guide.get_child_count(), expected_cells, "見出しと全操作の行が並ぶ")


func test_battle_shows_the_guide() -> void:
	var battle: Node = BATTLE.instantiate()
	add_child_autofree(battle)
	await wait_frames(3)

	assert_not_null(battle.get_node_or_null("ControlsGuide"), "Battle 画面に操作方法が出る")


func test_pause_menu_can_be_used_without_a_mouse() -> void:
	var battle: Node = BATTLE.instantiate()
	add_child_autofree(battle)
	await wait_frames(3)

	battle.set_paused(true)
	await wait_frames(1)

	assert_eq(
		battle.get_viewport().gui_get_focus_owner(),
		battle.get_pause_menu().get_button(PauseMenu.Action.RESUME),
		"開いたら RESUME を選んだ状態になる"
	)


func test_pause_menu_regains_focus_after_settings() -> void:
	var battle: Node = BATTLE.instantiate()
	add_child_autofree(battle)
	await wait_frames(3)

	battle.set_paused(true)
	battle.get_pause_menu().select(PauseMenu.Action.SETTINGS)
	await wait_frames(1)
	SceneRouter.close_settings()
	await wait_frames(2)

	assert_eq(
		battle.get_viewport().gui_get_focus_owner(),
		battle.get_pause_menu().get_button(PauseMenu.Action.RESUME),
		"Settings から戻っても RESUME を選んだ状態になる"
	)


func test_hidden_pause_menu_does_not_keep_the_focus() -> void:
	# 開いた同じフレームで閉じても、見えないボタンにフォーカスを残さない。
	var battle: Node = BATTLE.instantiate()
	add_child_autofree(battle)
	await wait_frames(3)

	battle.set_paused(true)
	battle.set_paused(false)
	await wait_frames(2)

	assert_null(battle.get_viewport().gui_get_focus_owner(), "閉じたらフォーカスは無い")
