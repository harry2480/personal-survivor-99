extends GutTest

## Ghost Piece の Unit テスト（要件定義 §26）。

var board: Board


func before_each() -> void:
	board = Board.new()


func _fill_row(y: int) -> void:
	for x in range(Board.WIDTH):
		board.set_cell(x, y, Piece.Type.I)


func test_lands_on_the_floor_of_an_empty_board() -> void:
	var origin := Vector2i(4, 5)

	var landing: Vector2i = GhostPiece.get_landing_position(
		board, Piece.Type.O, Piece.Rotation.SPAWN, origin
	)

	assert_eq(landing, Vector2i(4, Board.TOTAL_HEIGHT - 2), "床まで落ちる")
	assert_eq(landing.x, origin.x, "横位置は変わらない")


func test_lands_on_top_of_existing_blocks() -> void:
	_fill_row(Board.TOTAL_HEIGHT - 1)
	_fill_row(Board.TOTAL_HEIGHT - 2)

	var landing: Vector2i = GhostPiece.get_landing_position(
		board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(4, 5)
	)

	assert_eq(landing.y, Board.TOTAL_HEIGHT - 4, "積まれたブロックの上に乗る")


func test_landing_position_can_actually_hold_the_piece() -> void:
	board.set_cell(4, 30, Piece.Type.T)

	for type in Piece.get_all_types():
		var origin := Vector2i(3, 5)
		var landing: Vector2i = GhostPiece.get_landing_position(
			board, type, Piece.SPAWN_ROTATION, origin
		)

		assert_true(
			Collision.can_place(board, type, Piece.SPAWN_ROTATION, landing),
			"%s の着地点には実際に置ける" % Piece.get_letter(type)
		)
		assert_false(
			Collision.can_place(board, type, Piece.SPAWN_ROTATION, landing + Vector2i.DOWN),
			"%s の着地点より下へは進めない" % Piece.get_letter(type)
		)


func test_drop_distance() -> void:
	var origin := Vector2i(4, 10)

	var distance: int = GhostPiece.get_drop_distance(
		board, Piece.Type.O, Piece.Rotation.SPAWN, origin
	)

	assert_eq(distance, Board.TOTAL_HEIGHT - 2 - 10, "落ちるマス数が返る")


func test_drop_distance_is_zero_when_already_on_the_ground() -> void:
	var origin := Vector2i(4, Board.TOTAL_HEIGHT - 2)

	assert_eq(
		GhostPiece.get_drop_distance(board, Piece.Type.O, Piece.Rotation.SPAWN, origin),
		0,
		"接地していれば 0"
	)


func test_landing_cells_are_absolute_positions() -> void:
	var cells: Array[Vector2i] = GhostPiece.get_landing_cells(
		board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(4, 5)
	)

	var bottom: int = Board.TOTAL_HEIGHT - 1
	assert_eq(
		cells,
		(
			[
				Vector2i(4, bottom - 1),
				Vector2i(5, bottom - 1),
				Vector2i(4, bottom),
				Vector2i(5, bottom)
			]
			as Array[Vector2i]
		),
		"着地点で占めるマスが返る"
	)


func test_does_not_modify_the_board() -> void:
	var before: PackedStringArray = board.to_strings(0, Board.TOTAL_HEIGHT)

	GhostPiece.get_landing_position(board, Piece.Type.T, Piece.Rotation.SPAWN, Vector2i(3, 5))
	GhostPiece.get_landing_cells(board, Piece.Type.T, Piece.Rotation.SPAWN, Vector2i(3, 5))

	assert_eq(board.to_strings(0, Board.TOTAL_HEIGHT), before, "Board を変更しない")


func test_invalid_start_position_returns_the_same_position() -> void:
	# 既にブロックと重なっている位置。落下させずにそのまま返す。
	board.set_cell(4, 30, Piece.Type.T)
	var origin := Vector2i(4, 30)

	assert_eq(
		GhostPiece.get_landing_position(board, Piece.Type.O, Piece.Rotation.SPAWN, origin),
		origin,
		"置けない位置なら動かさない"
	)


func test_landing_inside_a_well() -> void:
	# 右端に 1 マス幅の縦穴を作り、縦向きの I がそこまで落ちることを見る。
	for y in range(Board.TOTAL_HEIGHT - 4, Board.TOTAL_HEIGHT):
		for x in range(Board.WIDTH - 1):
			board.set_cell(x, y, Piece.Type.I)

	var landing: Vector2i = GhostPiece.get_landing_position(
		board, Piece.Type.I, Piece.Rotation.RIGHT, Vector2i(7, 0)
	)

	assert_eq(landing.y, Board.TOTAL_HEIGHT - 4, "穴の底まで落ちる")
