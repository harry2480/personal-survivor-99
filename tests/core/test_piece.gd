extends GutTest

## Piece の形状定義の Unit テスト。


func test_all_types_are_defined() -> void:
	assert_eq(Piece.TYPE_COUNT, 7, "Piece は 7 種（要件定義 §21）")
	assert_eq(Piece.get_all_types().size(), 7, "全種類が列挙できる")
	assert_eq(
		Piece.LETTERS, PackedStringArray(["I", "J", "L", "O", "S", "T", "Z"]), "定義順は I J L O S T Z"
	)


func test_every_type_and_rotation_has_four_cells() -> void:
	for type in Piece.get_all_types():
		for rotation in range(Piece.ROTATION_COUNT):
			var cells: Array[Vector2i] = Piece.get_cells(type, rotation)
			assert_eq(
				cells.size(),
				Piece.CELL_COUNT,
				"%s の rotation=%d は 4 マス" % [Piece.get_letter(type), rotation]
			)


func test_cells_have_no_duplicates() -> void:
	for type in Piece.get_all_types():
		for rotation in range(Piece.ROTATION_COUNT):
			var cells: Array[Vector2i] = Piece.get_cells(type, rotation)
			var unique: Dictionary = {}
			for cell in cells:
				unique[cell] = true
			assert_eq(
				unique.size(),
				Piece.CELL_COUNT,
				"%s の rotation=%d に重複マスがない" % [Piece.get_letter(type), rotation]
			)


func test_cells_fit_inside_bounding_box() -> void:
	for type in Piece.get_all_types():
		var box: int = Piece.get_box_size(type)
		for rotation in range(Piece.ROTATION_COUNT):
			for cell in Piece.get_cells(type, rotation):
				var inside: bool = cell.x >= 0 and cell.x < box and cell.y >= 0 and cell.y < box
				assert_true(
					inside,
					(
						"%s rotation=%d の %s が %d×%d の Box に収まる"
						% [Piece.get_letter(type), rotation, cell, box, box]
					)
				)


func test_box_sizes_follow_srs() -> void:
	assert_eq(Piece.get_box_size(Piece.Type.I), 4, "I は 4×4")
	assert_eq(Piece.get_box_size(Piece.Type.O), 2, "O は 2×2")
	for type in [Piece.Type.J, Piece.Type.L, Piece.Type.S, Piece.Type.T, Piece.Type.Z]:
		assert_eq(Piece.get_box_size(type), 3, "%s は 3×3" % Piece.get_letter(type))


func test_o_piece_does_not_change_when_rotated() -> void:
	var spawn: Array[Vector2i] = Piece.get_cells(Piece.Type.O, Piece.Rotation.SPAWN)
	for rotation in range(Piece.ROTATION_COUNT):
		assert_eq(Piece.get_cells(Piece.Type.O, rotation), spawn, "O は回転しても形が変わらない")


func test_spawn_shapes_match_srs() -> void:
	var expected: Dictionary = {
		Piece.Type.I: [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1)],
		Piece.Type.J: [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		Piece.Type.L: [Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		Piece.Type.O: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
		Piece.Type.S: [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
		Piece.Type.T: [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		Piece.Type.Z: [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
	}
	for type in expected:
		assert_eq(
			Piece.get_cells(type, Piece.Rotation.SPAWN),
			expected[type],
			"%s の出現形状が SRS と一致する" % Piece.get_letter(type)
		)


# --- 出現位置 --------------------------------------------------------------


func test_spawn_rotation_is_spawn_state() -> void:
	assert_eq(Piece.SPAWN_ROTATION, Piece.Rotation.SPAWN, "出現時の回転状態は SPAWN")


func test_spawn_position_is_inside_the_board() -> void:
	for type in Piece.get_all_types():
		var origin: Vector2i = Piece.get_spawn_position(type)
		for cell in Piece.get_cells(type, Piece.SPAWN_ROTATION):
			var x: int = origin.x + cell.x
			var y: int = origin.y + cell.y
			assert_true(x >= 0 and x < Board.WIDTH, "%s の出現位置が幅に収まる" % Piece.get_letter(type))
			assert_true(y >= 0, "%s の出現位置が上端より下" % Piece.get_letter(type))


func test_spawn_position_is_just_above_the_visible_area() -> void:
	for type in Piece.get_all_types():
		var origin: Vector2i = Piece.get_spawn_position(type)
		var lowest_y: int = 0
		for cell in Piece.get_cells(type, Piece.SPAWN_ROTATION):
			lowest_y = maxi(lowest_y, origin.y + cell.y)
		assert_eq(
			lowest_y,
			Board.VISIBLE_TOP_Y - 1,
			"%s は Spawn Buffer の最下段に出現する" % Piece.get_letter(type)
		)


func test_spawn_columns_follow_the_guideline() -> void:
	var expected_columns: Dictionary = {
		Piece.Type.I: [3, 6],
		Piece.Type.J: [3, 5],
		Piece.Type.L: [3, 5],
		Piece.Type.O: [4, 5],
		Piece.Type.S: [3, 5],
		Piece.Type.T: [3, 5],
		Piece.Type.Z: [3, 5],
	}
	for type in expected_columns:
		var origin: Vector2i = Piece.get_spawn_position(type)
		var min_x: int = Board.WIDTH
		var max_x: int = 0
		for cell in Piece.get_cells(type, Piece.SPAWN_ROTATION):
			min_x = mini(min_x, origin.x + cell.x)
			max_x = maxi(max_x, origin.x + cell.x)
		assert_eq([min_x, max_x], expected_columns[type], "%s の出現列" % Piece.get_letter(type))


# --- 文字表現 --------------------------------------------------------------


func test_letter_round_trip() -> void:
	for type in Piece.get_all_types():
		assert_eq(Piece.from_letter(Piece.get_letter(type)), type, "1 文字と種類が往復する")


func test_from_letter_accepts_lowercase_and_rejects_unknown() -> void:
	assert_eq(Piece.from_letter("t"), Piece.Type.T, "小文字も受ける")
	assert_eq(Piece.from_letter("X"), -1, "未知の文字は -1")
