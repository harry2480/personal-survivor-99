extends GutTest

## Soft Drop / Hard Drop の Unit テスト（要件定義 §27 / §28）。

var rules: GameRules
var board: Board
var drop: DropSystem


func before_each() -> void:
	rules = GameRules.create_default()
	rules.gravity_cells_per_second = 1.0
	rules.soft_drop_multiplier = 20.0
	board = Board.new()
	drop = DropSystem.new(rules)


# --- Soft Drop -------------------------------------------------------------


func test_normal_speed_comes_from_the_rules() -> void:
	assert_false(drop.is_soft_dropping(), "最初は Soft Drop していない")
	assert_eq(drop.get_current_speed(), rules.gravity_cells_per_second, "通常速度")
	assert_eq(drop.advance(1.0), 1, "1 秒で 1 マス")


func test_soft_drop_accelerates_by_the_multiplier() -> void:
	drop.set_soft_dropping(true)

	assert_eq(drop.get_current_speed(), 20.0, "倍率が掛かる")
	assert_eq(drop.advance(1.0), 20, "1 秒で 20 マス")


func test_multiplier_is_configurable() -> void:
	rules.soft_drop_multiplier = 5.0
	drop.set_soft_dropping(true)

	assert_eq(drop.advance(1.0), 5, "設定した倍率で落ちる")


func test_releasing_soft_drop_returns_to_normal_speed() -> void:
	drop.set_soft_dropping(true)
	drop.set_soft_dropping(false)

	assert_eq(drop.get_current_speed(), rules.gravity_cells_per_second, "通常速度に戻る")
	assert_eq(drop.advance(1.0), 1, "落下量も戻る")


func test_setting_the_same_state_twice_is_harmless() -> void:
	drop.set_soft_dropping(true)
	drop.advance(0.02)

	drop.set_soft_dropping(true)

	assert_eq(drop.get_current_speed(), 20.0, "状態は変わらない")


func test_start_new_piece_clears_the_remainder() -> void:
	drop.advance(0.9)

	drop.start_new_piece()

	assert_eq(drop.advance(0.5), 0, "溜まっていた端数が消える")


func test_refresh_speed_picks_up_rule_changes() -> void:
	rules.gravity_cells_per_second = 10.0

	drop.refresh_speed()

	assert_eq(drop.advance(1.0), 10, "変更後の速度で落ちる")


# --- Hard Drop -------------------------------------------------------------


func test_hard_drop_moves_to_the_landing_position() -> void:
	var piece := ActivePiece.new(Piece.Type.O)
	piece.position = Vector2i(4, 10)

	var distance: int = DropSystem.hard_drop(board, piece)

	assert_eq(piece.position, Vector2i(4, Board.TOTAL_HEIGHT - 2), "床まで移動する")
	assert_eq(distance, Board.TOTAL_HEIGHT - 2 - 10, "落ちたマス数が返る")


func test_hard_drop_lands_on_existing_blocks() -> void:
	for x in range(Board.WIDTH):
		board.set_cell(x, Board.TOTAL_HEIGHT - 1, Piece.Type.I)
	var piece := ActivePiece.new(Piece.Type.O)
	piece.position = Vector2i(4, 10)

	DropSystem.hard_drop(board, piece)

	assert_eq(piece.position.y, Board.TOTAL_HEIGHT - 3, "積まれたブロックの上で止まる")


func test_hard_drop_on_the_ground_moves_nothing() -> void:
	var piece := ActivePiece.new(Piece.Type.O)
	piece.position = Vector2i(4, Board.TOTAL_HEIGHT - 2)

	assert_eq(DropSystem.hard_drop(board, piece), 0, "接地していれば 0 マス")
	assert_eq(piece.position, Vector2i(4, Board.TOTAL_HEIGHT - 2), "位置も変わらない")


func test_hard_drop_does_not_write_to_the_board() -> void:
	var before: PackedStringArray = board.to_strings(0, Board.TOTAL_HEIGHT)
	var piece := ActivePiece.new(Piece.Type.T)

	DropSystem.hard_drop(board, piece)

	assert_eq(board.to_strings(0, Board.TOTAL_HEIGHT), before, "Board は変更しない")


func test_hard_drop_result_can_actually_be_placed() -> void:
	for type in Piece.get_all_types():
		var piece := ActivePiece.new(type)

		DropSystem.hard_drop(board, piece)

		assert_true(piece.can_place(board), "%s は着地点に置ける" % Piece.get_letter(type))
		assert_true(piece.is_on_ground(board), "%s は着地点で接地する" % Piece.get_letter(type))


func test_hard_drop_locks_immediately_by_default() -> void:
	assert_true(drop.locks_after_hard_drop(), "既定では直後に Lock する")


func test_hard_drop_lock_can_be_disabled() -> void:
	rules.hard_drop_locks_immediately = false

	assert_false(drop.locks_after_hard_drop(), "設定で切り替えられる")


# --- ユーザー設定の上書き ---------------------------------------------------


func test_user_settings_override_the_balance_data() -> void:
	var applied: int = rules.apply_user_settings(
		{"das_sec": 0.1, "arr_sec": 0.0, "soft_drop_multiplier": 40.0}
	)

	assert_eq(applied, 3, "3 件とも上書きされる")
	assert_eq(rules.das_sec, 0.1, "DAS が変わる")
	assert_eq(rules.arr_sec, 0.0, "ARR が変わる")
	assert_eq(rules.soft_drop_multiplier, 40.0, "Soft Drop 倍率が変わる")


func test_user_settings_ignore_unknown_and_invalid_values() -> void:
	var before_das: float = rules.das_sec

	var applied: int = rules.apply_user_settings(
		{"unknown_key": 1.0, "das_sec": "fast", "arr_sec": -1.0, "soft_drop_multiplier": 0.0}
	)

	assert_eq(applied, 0, "どれも採用しない")
	assert_eq(rules.das_sec, before_das, "不正な値では上書きしない")


func test_user_settings_accept_integers() -> void:
	rules.apply_user_settings({"soft_drop_multiplier": 30})

	assert_eq(rules.soft_drop_multiplier, 30.0, "整数でも受け付ける")
