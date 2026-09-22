extends GutTest

## 衝突判定の Unit テスト。

var board: Board


func before_each() -> void:
	board = Board.new()


func test_piece_fits_on_an_empty_board() -> void:
	for type in Piece.get_all_types():
		var origin: Vector2i = Piece.get_spawn_position(type)
		assert_true(
			Collision.can_place(board, type, Piece.SPAWN_ROTATION, origin),
			"%s は空の盤面の出現位置に置ける" % Piece.get_letter(type)
		)


func test_get_cells_returns_absolute_positions() -> void:
	var origin := Vector2i(4, 30)

	var cells: Array[Vector2i] = Collision.get_cells(Piece.Type.O, Piece.Rotation.SPAWN, origin)

	assert_eq(
		cells,
		[Vector2i(4, 30), Vector2i(5, 30), Vector2i(4, 31), Vector2i(5, 31)] as Array[Vector2i],
		"オフセットに位置を足した絶対座標が返る"
	)


# --- 壁・床・上端 ----------------------------------------------------------


func test_blocked_by_left_wall() -> void:
	# O は Box の左端から埋まっているので、x=-1 で左壁を越える。
	assert_true(Collision.can_place(board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(0, 30)))
	assert_false(
		Collision.can_place(board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(-1, 30)),
		"左壁の外には置けない"
	)


func test_blocked_by_right_wall() -> void:
	var rightmost: int = Board.WIDTH - 2
	assert_true(
		Collision.can_place(board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(rightmost, 30))
	)
	assert_false(
		Collision.can_place(board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(rightmost + 1, 30)),
		"右壁の外には置けない"
	)


func test_blocked_by_floor() -> void:
	var bottom_origin: int = Board.TOTAL_HEIGHT - 2
	assert_true(
		Collision.can_place(board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(4, bottom_origin)),
		"床のすぐ上には置ける"
	)
	assert_false(
		Collision.can_place(
			board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(4, bottom_origin + 1)
		),
		"床より下には置けない"
	)


func test_blocked_above_the_internal_top() -> void:
	assert_true(
		Collision.can_place(board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(4, 0)),
		"内部領域の最上段には置ける"
	)
	assert_false(
		Collision.can_place(board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(4, -1)),
		"内部領域の上端より上には置けない"
	)


func test_blocked_by_existing_block() -> void:
	board.set_cell(5, 31, Piece.Type.T)

	assert_false(
		Collision.can_place(board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(4, 30)),
		"既にブロックがあるマスには重ねられない"
	)
	assert_true(
		Collision.can_place(board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(0, 30)),
		"ぶつからない位置には置ける"
	)


# --- 接地 ------------------------------------------------------------------


func test_is_on_ground_at_the_floor() -> void:
	var bottom_origin: int = Board.TOTAL_HEIGHT - 2

	assert_true(
		Collision.is_on_ground(
			board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(4, bottom_origin)
		),
		"床に接していれば接地"
	)
	assert_false(
		Collision.is_on_ground(
			board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(4, bottom_origin - 1)
		),
		"1 マス上なら接地していない"
	)


func test_is_on_ground_on_top_of_a_block() -> void:
	board.set_cell(4, 35, Piece.Type.I)

	assert_true(
		Collision.is_on_ground(board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(4, 33)),
		"ブロックの上でも接地"
	)


# --- 書き込み --------------------------------------------------------------


func test_place_writes_the_piece_type_into_the_board() -> void:
	var origin := Vector2i(4, 30)

	assert_true(Collision.place(board, Piece.Type.S, Piece.Rotation.SPAWN, origin), "置ける")

	for cell in Collision.get_cells(Piece.Type.S, Piece.Rotation.SPAWN, origin):
		assert_eq(board.get_cell(cell.x, cell.y), Piece.Type.S as int, "セルに種類が書かれる")


func test_place_does_nothing_when_blocked() -> void:
	board.set_cell(5, 31, Piece.Type.T)

	assert_false(Collision.place(board, Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(4, 30)))

	assert_true(board.is_cell_empty(4, 30), "失敗時は 1 マスも書き込まない")
	assert_eq(board.get_cell(5, 31), Piece.Type.T as int, "既存のブロックも変えない")
