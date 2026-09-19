extends GutTest

## T-Spin 判定の Unit テスト（要件定義 §33）。

const SRS_KICK_COUNT: int = 5

var board: Board
var detector: TSpinDetector


func before_each() -> void:
	board = Board.new()
	detector = TSpinDetector.new()


func _context(
	rotation: int, position: Vector2i, was_rotation: bool = true, kick_index: int = 0
) -> TSpinContext:
	return TSpinContext.create(
		board, Piece.Type.T, rotation, position, was_rotation, kick_index, SRS_KICK_COUNT
	)


func _fill(cells: Array) -> void:
	for cell in cells:
		board.set_cell(cell[0], cell[1], Piece.Type.I)


# --- 前提条件 --------------------------------------------------------------


func test_non_t_piece_is_never_a_t_spin() -> void:
	var context := TSpinContext.create(
		board, Piece.Type.S, Piece.Rotation.SPAWN, Vector2i(3, 30), true, 0, SRS_KICK_COUNT
	)

	assert_eq(detector.detect(context), TSpinDetector.Result.NONE, "T 以外は対象外")


func test_landing_without_rotation_is_not_a_t_spin() -> void:
	# 四隅が埋まっていても、直前の操作が回転でなければ成立しない。
	var origin := Vector2i(3, 30)
	_fill([[3, 30], [5, 30], [3, 32], [5, 32]])

	var context := _context(Piece.Rotation.SPAWN, origin, false)

	assert_eq(detector.detect(context), TSpinDetector.Result.NONE, "回転以外での着地は非 T-Spin")


func test_two_corners_is_not_enough() -> void:
	var origin := Vector2i(3, 30)
	_fill([[3, 32], [5, 32]])

	assert_eq(
		detector.detect(_context(Piece.Rotation.SPAWN, origin)),
		TSpinDetector.Result.NONE,
		"隅が 2 つでは成立しない"
	)


func test_null_context_is_safe() -> void:
	assert_eq(detector.detect(null), TSpinDetector.Result.NONE, "null でも落ちない")


# --- T-Spin / Mini の区別 --------------------------------------------------


func test_full_t_spin_when_both_front_corners_are_filled() -> void:
	# T が下を向いている（TWO）ときの正面は下側の 2 隅。
	var origin := Vector2i(3, 30)
	_fill([[3, 32], [5, 32], [3, 30]])

	var result: TSpinDetector.Result = detector.detect(_context(Piece.Rotation.TWO, origin))

	assert_eq(result, TSpinDetector.Result.FULL, "正面 2 隅が埋まっていれば T-Spin")


func test_mini_when_only_one_front_corner_is_filled() -> void:
	# 正面（下側）は片方だけ、背面（上側）は両方埋まっている。
	var origin := Vector2i(3, 30)
	_fill([[3, 32], [3, 30], [5, 30]])

	var result: TSpinDetector.Result = detector.detect(_context(Piece.Rotation.TWO, origin))

	assert_eq(result, TSpinDetector.Result.MINI, "正面が片側だけなら Mini")


func test_last_kick_promotes_mini_to_full() -> void:
	var origin := Vector2i(3, 30)
	_fill([[3, 32], [3, 30], [5, 30]])

	var result: TSpinDetector.Result = detector.detect(
		_context(Piece.Rotation.TWO, origin, true, SRS_KICK_COUNT - 1)
	)

	assert_eq(result, TSpinDetector.Result.FULL, "Kick Table の最後で収まったら Mini にしない")


func test_front_corners_follow_the_rotation() -> void:
	var origin := Vector2i(3, 30)
	# 右向き（RIGHT）の正面は右側の 2 隅。右側 2 つ + 左上を埋める。
	_fill([[5, 30], [5, 32], [3, 30]])

	assert_eq(
		detector.detect(_context(Piece.Rotation.RIGHT, origin)),
		TSpinDetector.Result.FULL,
		"右向きなら右の 2 隅が正面"
	)
	assert_eq(
		detector.detect(_context(Piece.Rotation.LEFT, origin)),
		TSpinDetector.Result.MINI,
		"同じ盤面でも左向きなら正面が片側だけ"
	)


# --- 壁・床の扱い ----------------------------------------------------------


func test_walls_count_as_filled_corners() -> void:
	# 左端に寄せると、左側の 2 隅が盤外になる。
	var origin := Vector2i(-1, 30)
	_fill([[1, 32]])

	assert_eq(
		detector.count_occupied_corners(_context(Piece.Rotation.LEFT, origin)), 3, "盤外の隅は埋まっている扱い"
	)
	assert_eq(
		detector.detect(_context(Piece.Rotation.LEFT, origin)),
		TSpinDetector.Result.FULL,
		"左向きなら左の 2 隅（壁）が正面"
	)


func test_floor_counts_as_filled_corners() -> void:
	var origin := Vector2i(3, Board.TOTAL_HEIGHT - 2)
	_fill([[3, Board.TOTAL_HEIGHT - 2]])

	assert_eq(
		detector.count_occupied_corners(_context(Piece.Rotation.TWO, origin)), 3, "床の下も埋まっている扱い"
	)


# --- 代表的な形 ------------------------------------------------------------


func test_t_spin_double_shape() -> void:
	# 典型的な T-Spin Double。下向きの T が窪みへ収まり、2 行が揃う。
	#   ##.#######
	#   ##...#####
	#   ###.######
	var bottom: int = Board.TOTAL_HEIGHT - 1
	board.fill_from_strings(
		PackedStringArray(["##.#######", "##...#####", "###.######"]), bottom - 2
	)
	var origin := Vector2i(2, bottom - 2)
	var context := _context(Piece.Rotation.TWO, origin)

	assert_true(Collision.can_place(board, Piece.Type.T, Piece.Rotation.TWO, origin), "前提: 窪みへ収まる")
	assert_eq(detector.count_occupied_corners(context), 3, "隅は 3 つ埋まっている（3 つ以上で成立）")
	assert_eq(detector.count_occupied_front_corners(context), 2, "正面の 2 隅が埋まっている")
	assert_eq(detector.detect(context), TSpinDetector.Result.FULL, "T-Spin として判定される")

	Collision.place(board, Piece.Type.T, Piece.Rotation.TWO, origin)
	var cleared: LineClearResult = LineClear.execute(board)

	assert_eq(cleared.type, LineClear.Type.DOUBLE, "実際に 2 行消えて T-Spin Double になる")


func test_result_names() -> void:
	assert_eq(TSpinDetector.get_result_name(TSpinDetector.Result.FULL), "FULL", "名前が取れる")
	assert_eq(TSpinDetector.get_result_name(TSpinDetector.Result.MINI), "MINI", "名前が取れる")


# --- 決定論 ----------------------------------------------------------------


func test_same_context_produces_the_same_result() -> void:
	var origin := Vector2i(3, 30)
	_fill([[3, 32], [5, 32], [3, 30]])
	var context := _context(Piece.Rotation.TWO, origin)

	assert_eq(detector.detect(context), TSpinDetector.new().detect(context), "同じ入力から同じ結果")
