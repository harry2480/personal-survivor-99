extends GutTest

## 操作中の Piece 状態の Unit テスト。

var board: Board


func before_each() -> void:
	board = Board.new()


func test_spawn_sets_the_initial_rotation_and_position() -> void:
	for type in Piece.get_all_types():
		var piece := ActivePiece.new(type)

		assert_eq(piece.type, type, "%s が入る" % Piece.get_letter(type))
		assert_eq(piece.rotation, Piece.SPAWN_ROTATION as int, "初期回転になる")
		assert_eq(piece.position, Piece.get_spawn_position(type), "Spawn 位置になる")


func test_spawn_resets_a_moved_and_rotated_piece() -> void:
	# Hold から戻ってきた Piece が初期状態に戻ることの担保（要件定義 §24）。
	var piece := ActivePiece.new(Piece.Type.T)
	piece.rotation = Piece.Rotation.TWO
	piece.position = Vector2i(0, 35)

	piece.spawn(Piece.Type.T)

	assert_eq(piece.rotation, Piece.SPAWN_ROTATION as int, "回転が初期化される")
	assert_eq(piece.position, Piece.get_spawn_position(Piece.Type.T), "位置が初期化される")


func test_hold_return_goes_through_spawn() -> void:
	var hold := HoldSlot.new()
	var piece := ActivePiece.new(Piece.Type.T)
	piece.rotation = Piece.Rotation.LEFT
	piece.position = Vector2i(1, 30)

	# 1 回目: T を預けて I を出す
	hold.swap(piece.type)
	piece.spawn(Piece.Type.I)
	hold.on_piece_locked()

	# 2 回目: I を預けて T が戻ってくる
	piece.rotation = Piece.Rotation.TWO
	piece.position = Vector2i(8, 20)
	var released: int = hold.swap(piece.type)
	piece.spawn(released)

	assert_eq(piece.type, Piece.Type.T as int, "預けていた T が戻る")
	assert_eq(piece.rotation, Piece.SPAWN_ROTATION as int, "初期回転で戻る")
	assert_eq(piece.position, Piece.get_spawn_position(Piece.Type.T), "Spawn 位置で戻る")


func test_is_active_and_clear() -> void:
	var piece := ActivePiece.new()
	assert_false(piece.is_active(), "何も出していなければ非アクティブ")

	piece.spawn(Piece.Type.S)
	assert_true(piece.is_active(), "出現後はアクティブ")

	piece.clear()
	assert_false(piece.is_active(), "クリアすると非アクティブ")


func test_get_cells_matches_collision() -> void:
	var piece := ActivePiece.new(Piece.Type.L)
	piece.position = Vector2i(3, 20)

	assert_eq(
		piece.get_cells(),
		Collision.get_cells(Piece.Type.L, Piece.Rotation.SPAWN, Vector2i(3, 20)),
		"Collision と同じ座標を返す"
	)


func test_get_lowest_y() -> void:
	var piece := ActivePiece.new(Piece.Type.T)
	piece.position = Vector2i(3, 20)

	assert_eq(piece.get_lowest_y(), 21, "T の SPAWN は下端が 1 マス下")


func test_can_place_and_is_on_ground() -> void:
	var piece := ActivePiece.new(Piece.Type.O)
	piece.position = Vector2i(4, Board.TOTAL_HEIGHT - 2)

	assert_true(piece.can_place(board), "床の上には置ける")
	assert_true(piece.is_on_ground(board), "接地している")

	piece.position = Vector2i(4, Board.TOTAL_HEIGHT - 3)
	assert_false(piece.is_on_ground(board), "1 マス上なら接地していない")
