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


func test_garbage_cells_are_drawn_with_a_dedicated_color() -> void:
	# Garbage は Piece の種類（0〜6）より大きい値で盤面へ入るため、PIECE_COLORS を
	# そのまま引くと範囲外参照になる。表示領域に Garbage が来ても引けることを確かめる。
	var scene: Node = SOLO_PLAY.instantiate()
	add_child_autofree(scene)
	await wait_frames(2)

	assert_gte(
		GarbageQueue.GARBAGE_CELL, scene.PIECE_COLORS.size(), "前提: Garbage は PIECE_COLORS の範囲外"
	)

	var session: PuzzleSession = scene._session
	session.receive_garbage_lines(2)
	# Delay が経過するまで進めてから Lock すると、Garbage が盤面へ入る。
	for _frame in range(120):
		session.update(1.0 / 60.0)
	session.hard_drop()

	var board: Board = session.get_board()
	var has_garbage: bool = false
	for row in range(Board.VISIBLE_HEIGHT):
		for x in range(Board.WIDTH):
			var value: int = board.get_cell(x, Board.VISIBLE_TOP_Y + row)
			if value == GarbageQueue.GARBAGE_CELL:
				has_garbage = true
			# 範囲外参照があれば、ここで実行時エラーになる。
			scene._cell_color(value)

	assert_true(has_garbage, "Garbage が表示領域に入る")
	assert_eq(scene._cell_color(GarbageQueue.GARBAGE_CELL), scene.GARBAGE_COLOR, "Garbage は専用色")
	assert_eq(scene._cell_color(Board.EMPTY), scene.EMPTY_COLOR, "空セルは変わらず空の色")
	assert_eq(scene._cell_color(Piece.Type.T), scene.PIECE_COLORS[Piece.Type.T], "Piece の色は変わらない")
