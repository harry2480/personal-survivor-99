extends GutTest

## SRS Rotation と Wall Kick の Unit テスト。

var board: Board
var rotation_system: RotationSystem


func before_each() -> void:
	board = Board.new()
	rotation_system = RotationSystem.new()


func _fill_row_except(y: int, open_x: int) -> void:
	for x in range(Board.WIDTH):
		if x != open_x:
			board.set_cell(x, y, Piece.Type.I)


# --- 回転状態の遷移 --------------------------------------------------------


func test_clockwise_cycles_through_all_rotations() -> void:
	var rotation: int = Piece.Rotation.SPAWN
	var visited: Array[int] = [rotation]

	for _i in range(3):
		rotation = RotationSystem.get_next_rotation(rotation, RotationSystem.Direction.CLOCKWISE)
		visited.append(rotation)

	assert_eq(
		visited,
		(
			[Piece.Rotation.SPAWN, Piece.Rotation.RIGHT, Piece.Rotation.TWO, Piece.Rotation.LEFT]
			as Array[int]
		),
		"時計回りは SPAWN → RIGHT → TWO → LEFT"
	)


func test_counter_clockwise_cycles_backwards() -> void:
	var rotation: int = RotationSystem.get_next_rotation(
		Piece.Rotation.SPAWN, RotationSystem.Direction.COUNTER_CLOCKWISE
	)

	assert_eq(rotation, Piece.Rotation.LEFT, "反時計回りは SPAWN → LEFT")


func test_four_clockwise_rotations_return_to_the_start() -> void:
	for type in Piece.get_all_types():
		var origin := Vector2i(3, 20)
		var rotation: int = Piece.Rotation.SPAWN

		for _i in range(4):
			var result: RotationResult = rotation_system.rotate_clockwise(
				board, type, rotation, origin
			)
			assert_true(result.success, "%s は開けた場所で回せる" % Piece.get_letter(type))
			origin = result.position
			rotation = result.rotation

		assert_eq(rotation, Piece.Rotation.SPAWN as int, "%s は 4 回で元の向き" % Piece.get_letter(type))
		assert_eq(origin, Vector2i(3, 20), "%s は 4 回で元の位置" % Piece.get_letter(type))


func test_four_counter_clockwise_rotations_return_to_the_start() -> void:
	for type in Piece.get_all_types():
		var origin := Vector2i(3, 20)
		var rotation: int = Piece.Rotation.SPAWN

		for _i in range(4):
			var result: RotationResult = rotation_system.rotate_counter_clockwise(
				board, type, rotation, origin
			)
			assert_true(result.success, "%s は開けた場所で逆回しできる" % Piece.get_letter(type))
			origin = result.position
			rotation = result.rotation

		assert_eq(rotation, Piece.Rotation.SPAWN as int, "%s は 4 回で元の向き" % Piece.get_letter(type))
		assert_eq(origin, Vector2i(3, 20), "%s は 4 回で元の位置" % Piece.get_letter(type))


func test_rotation_without_obstacles_uses_no_kick() -> void:
	var result: RotationResult = rotation_system.rotate_clockwise(
		board, Piece.Type.T, Piece.Rotation.SPAWN, Vector2i(3, 20)
	)

	assert_true(result.success, "開けた場所では回せる")
	assert_eq(result.kick_index, 0, "移動なし（表の 0 番目）で収まる")
	assert_eq(result.kick_offset, Vector2i.ZERO, "位置は動かない")
	assert_false(result.used_kick(), "Wall Kick は働いていない")


# --- Wall Kick -------------------------------------------------------------


func test_floor_kick_lifts_the_piece() -> void:
	# 床に接した T を時計回りに回すと、下がはみ出すので 1 マス持ち上げて収まる。
	var origin := Vector2i(3, Board.TOTAL_HEIGHT - 2)
	assert_true(
		Collision.can_place(board, Piece.Type.T, Piece.Rotation.SPAWN, origin), "前提: 床に接している"
	)

	var result: RotationResult = rotation_system.rotate_clockwise(
		board, Piece.Type.T, Piece.Rotation.SPAWN, origin
	)

	assert_true(result.success, "Wall Kick で回転できる")
	assert_true(result.used_kick(), "Kick が働いた")
	assert_eq(result.kick_index, 2, "表の 2 番目のオフセットが採用される")
	assert_eq(result.kick_offset, Vector2i(-1, -1), "左へ 1、上へ 1")
	assert_true(
		Collision.can_place(board, Piece.Type.T, result.rotation, result.position), "回転後の位置に実際に置ける"
	)


func test_i_piece_kicks_off_the_left_wall() -> void:
	# 左壁に張り付いた縦向きの I。横向きにすると壁を越えるので右へ 2 ずれる。
	var origin := Vector2i(-2, 30)
	assert_true(
		Collision.can_place(board, Piece.Type.I, Piece.Rotation.RIGHT, origin), "前提: 左壁に接した縦向きの I"
	)

	var result: RotationResult = rotation_system.rotate_clockwise(
		board, Piece.Type.I, Piece.Rotation.RIGHT, origin
	)

	assert_true(result.success, "I は壁から離れて回転できる")
	assert_eq(result.kick_offset, Vector2i(2, 0), "I 専用の表にある +2 の Kick が使われる")
	assert_eq(result.position.x, 0, "左端に収まる")
	assert_true(
		Collision.can_place(board, Piece.Type.I, result.rotation, result.position), "回転後の位置に実際に置ける"
	)


func test_rotation_fails_inside_a_one_wide_well() -> void:
	# 1 マス幅の縦穴に縦向きの I。どの Kick でも横向きにはなれない。
	for y in range(Board.TOTAL_HEIGHT - 4, Board.TOTAL_HEIGHT):
		_fill_row_except(y, 4)
	var origin := Vector2i(2, Board.TOTAL_HEIGHT - 4)
	assert_true(
		Collision.can_place(board, Piece.Type.I, Piece.Rotation.RIGHT, origin), "前提: 穴に収まっている"
	)

	var result: RotationResult = rotation_system.rotate_clockwise(
		board, Piece.Type.I, Piece.Rotation.RIGHT, origin
	)

	assert_false(result.success, "回転できない")
	assert_eq(result.position, origin, "失敗しても位置は変わらない")
	assert_eq(result.rotation, Piece.Rotation.RIGHT as int, "失敗しても向きは変わらない")
	assert_eq(result.kick_index, -1, "採用された Kick はない")


# --- Kick Table の分離と差し替え --------------------------------------------


func test_i_piece_uses_a_separate_table() -> void:
	var i_table: KickTable = rotation_system.get_kick_table(Piece.Type.I)
	var standard_table: KickTable = rotation_system.get_kick_table(Piece.Type.T)

	assert_ne(i_table, standard_table, "I とその他で別の表を使う")
	assert_ne(
		i_table.get_offsets(Piece.Rotation.SPAWN, Piece.Rotation.RIGHT),
		standard_table.get_offsets(Piece.Rotation.SPAWN, Piece.Rotation.RIGHT),
		"表の中身も異なる"
	)


func test_standard_table_offsets_match_published_srs() -> void:
	# 公開されている SRS の表（y が上が正）を Board の座標系（y が下が正）へ直した値。
	# 転記ミスや符号の反転漏れをここで止める。
	var table: KickTable = SrsKickTables.create_standard()

	assert_eq(
		table.get_offsets(Piece.Rotation.SPAWN, Piece.Rotation.RIGHT),
		PackedVector2Array(
			[Vector2(0, 0), Vector2(-1, 0), Vector2(-1, -1), Vector2(0, 2), Vector2(-1, 2)]
		),
		"JLSTZ の 0→R"
	)
	assert_eq(
		table.get_offsets(Piece.Rotation.RIGHT, Piece.Rotation.SPAWN),
		PackedVector2Array(
			[Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, -2), Vector2(1, -2)]
		),
		"JLSTZ の R→0"
	)
	assert_eq(
		table.get_offsets(Piece.Rotation.TWO, Piece.Rotation.LEFT),
		PackedVector2Array(
			[Vector2(0, 0), Vector2(1, 0), Vector2(1, -1), Vector2(0, 2), Vector2(1, 2)]
		),
		"JLSTZ の 2→L"
	)


func test_i_table_offsets_match_published_srs() -> void:
	var table: KickTable = SrsKickTables.create_i()

	assert_eq(
		table.get_offsets(Piece.Rotation.SPAWN, Piece.Rotation.RIGHT),
		PackedVector2Array(
			[Vector2(0, 0), Vector2(-2, 0), Vector2(1, 0), Vector2(-2, 1), Vector2(1, -2)]
		),
		"I の 0→R"
	)
	assert_eq(
		table.get_offsets(Piece.Rotation.RIGHT, Piece.Rotation.TWO),
		PackedVector2Array(
			[Vector2(0, 0), Vector2(-1, 0), Vector2(2, 0), Vector2(-1, -2), Vector2(2, 1)]
		),
		"I の R→2"
	)
	assert_eq(
		table.get_offsets(Piece.Rotation.LEFT, Piece.Rotation.SPAWN),
		PackedVector2Array(
			[Vector2(0, 0), Vector2(1, 0), Vector2(-2, 0), Vector2(1, 2), Vector2(-2, -1)]
		),
		"I の L→0"
	)


func test_every_kick_offset_is_used_in_board_coordinates() -> void:
	# y を反転し忘れると、上方向の Kick が下方向になって壁抜けの挙動が変わる。
	# 少なくとも 1 つは「上へ動かす」オフセットが存在することを確かめる。
	var table: KickTable = SrsKickTables.create_standard()
	var has_upward: bool = false
	for offset in table.get_offsets(Piece.Rotation.SPAWN, Piece.Rotation.RIGHT):
		if offset.y < 0:
			has_upward = true

	assert_true(has_upward, "0→R には上へ持ち上げる Kick がある")


func test_standard_tables_define_every_quarter_turn() -> void:
	assert_true(SrsKickTables.create_standard().has_all_quarter_turns(), "標準表に 8 遷移がある")
	assert_true(SrsKickTables.create_i().has_all_quarter_turns(), "I 用の表に 8 遷移がある")


func test_kick_table_can_be_replaced() -> void:
	# Kick なし（移動なしのみ）の表に差し替えると、床際の回転は失敗するようになる。
	var no_kick := KickTable.new()
	no_kick.table_name = "No Kick"
	var transitions: Array[PackedVector2Array] = []
	transitions.resize(Piece.ROTATION_COUNT * Piece.ROTATION_COUNT)
	for index in range(transitions.size()):
		transitions[index] = PackedVector2Array([Vector2.ZERO])
	no_kick.offsets_by_transition = transitions

	var without_kick := RotationSystem.new(no_kick, no_kick)
	var origin := Vector2i(3, Board.TOTAL_HEIGHT - 2)

	var result: RotationResult = without_kick.rotate_clockwise(
		board, Piece.Type.T, Piece.Rotation.SPAWN, origin
	)

	assert_false(result.success, "差し替えた表が使われている")


func test_unknown_transition_falls_back_to_no_movement() -> void:
	var empty_table := KickTable.new()

	var offsets: PackedVector2Array = empty_table.get_offsets(
		Piece.Rotation.SPAWN, Piece.Rotation.RIGHT
	)

	assert_eq(offsets, PackedVector2Array([Vector2.ZERO]), "定義がなければ移動なしだけを試す")


# --- 決定論 ----------------------------------------------------------------


func test_same_input_produces_the_same_result() -> void:
	var origin := Vector2i(3, Board.TOTAL_HEIGHT - 2)

	var first: RotationResult = rotation_system.rotate_clockwise(
		board, Piece.Type.T, Piece.Rotation.SPAWN, origin
	)
	var second: RotationResult = RotationSystem.new().rotate_clockwise(
		board, Piece.Type.T, Piece.Rotation.SPAWN, origin
	)

	assert_eq(first.success, second.success, "成否が同じ")
	assert_eq(first.position, second.position, "位置が同じ")
	assert_eq(first.rotation, second.rotation, "向きが同じ")
	assert_eq(first.kick_index, second.kick_index, "採用された Kick も同じ")
