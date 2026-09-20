extends GutTest

## 配置探索の Unit テスト（要件定義 §62〜§64）。

const SEED: int = 20260920

var board: Board
var profile: CpuProfile
var search: PlacementSearch


func before_each() -> void:
	board = Board.new()
	profile = CpuProfile.create_default()
	search = PlacementSearch.new(profile, SEED)


func _stack(heights: Array) -> void:
	for x in range(mini(heights.size(), Board.WIDTH)):
		for offset in range(heights[x]):
			board.set_cell(x, Board.TOTAL_HEIGHT - 1 - offset, Piece.Type.I)


# --- 到達可能性 ------------------------------------------------------------


func test_finds_placements_on_an_empty_board() -> void:
	var placements: Array[Placement] = search.find_reachable_placements(board, Piece.Type.T)

	assert_gt(placements.size(), 0, "候補が見つかる")


func test_every_placement_is_actually_placeable_and_grounded() -> void:
	_stack([4, 6, 3, 7, 5, 2, 8, 4, 6, 3])

	for type in Piece.get_all_types():
		for placement in search.find_reachable_placements(board, type):
			assert_true(
				Collision.can_place(board, type, placement.rotation, placement.position),
				"%s の候補は実際に置ける" % Piece.get_letter(type)
			)
			assert_true(
				Collision.is_on_ground(board, type, placement.rotation, placement.position),
				"%s の候補は接地している" % Piece.get_letter(type)
			)


func test_placements_are_unique() -> void:
	_stack([2, 5, 1, 3, 4, 2, 6, 1, 3, 2])

	var placements: Array[Placement] = search.find_reachable_placements(board, Piece.Type.S)
	var seen: Dictionary = {}
	for placement in placements:
		var key := Vector3i(placement.position.x, placement.position.y, placement.rotation)
		assert_false(seen.has(key), "同じ置き方が重複しない")
		seen[key] = true


func test_i_piece_reaches_both_walls() -> void:
	var xs: Dictionary = {}
	for placement in search.find_reachable_placements(board, Piece.Type.I):
		for cell in Collision.get_cells(Piece.Type.I, placement.rotation, placement.position):
			xs[cell.x] = true

	assert_true(xs.has(0), "左端まで届く")
	assert_true(xs.has(Board.WIDTH - 1), "右端まで届く")


func test_rotation_only_reachable_spots_are_included() -> void:
	# 1 マス幅の縦穴。縦向きでしか入らないので、回転を使わないと候補に出ない。
	for y in range(Board.TOTAL_HEIGHT - 4, Board.TOTAL_HEIGHT):
		for x in range(Board.WIDTH):
			if x != 0:
				board.set_cell(x, y, Piece.Type.I)

	var found_vertical: bool = false
	for placement in search.find_reachable_placements(board, Piece.Type.I):
		if placement.position.y >= Board.TOTAL_HEIGHT - 4:
			found_vertical = true

	assert_true(found_vertical, "回転しないと入れない場所も候補に出る")


func test_no_placements_when_the_spawn_is_blocked() -> void:
	for y in range(Board.VISIBLE_TOP_Y - 2, Board.VISIBLE_TOP_Y):
		for x in range(Board.WIDTH):
			board.set_cell(x, y, Piece.Type.I)

	assert_eq(search.find_reachable_placements(board, Piece.Type.T).size(), 0, "出現できなければ候補なし")


# --- 選択 ------------------------------------------------------------------


func test_search_returns_the_best_candidate() -> void:
	var best: Placement = search.search(board, Piece.Type.I)

	assert_not_null(best, "候補が返る")
	assert_true(best.is_valid(), "有効な候補")
	assert_eq(best.piece_type, Piece.Type.I as int, "指定した Piece の置き方")


func test_search_returns_null_without_candidates() -> void:
	for y in range(Board.VISIBLE_TOP_Y - 2, Board.VISIBLE_TOP_Y):
		for x in range(Board.WIDTH):
			board.set_cell(x, y, Piece.Type.I)

	assert_null(search.search(board, Piece.Type.T), "置けなければ null")


func test_best_candidate_avoids_making_holes() -> void:
	# 右端だけ深い盤面。縦 I を落とせば穴を作らずに埋まる。
	_stack([6, 6, 6, 6, 6, 6, 6, 6, 6, 2])

	var best: Placement = search.search(board, Piece.Type.I)
	var after: Board = board.clone()
	Collision.place(after, best.piece_type, best.rotation, best.position)

	var metrics := BoardMetrics.new()
	metrics.measure(after)
	var before_metrics := BoardMetrics.new()
	before_metrics.measure(board)

	assert_eq(metrics.holes, before_metrics.holes, "穴を増やさない置き方を選ぶ")


func test_hold_candidates_are_included() -> void:
	var candidates: Array[Placement] = search.rank_candidates(board, Piece.Type.S, [], Piece.Type.I)

	var has_hold: bool = false
	for placement in candidates:
		if placement.uses_hold:
			has_hold = true
			assert_eq(placement.piece_type, Piece.Type.I as int, "Hold の Piece が使われる")

	assert_true(has_hold, "Hold を使う候補も並ぶ")


# --- Search Depth / Lookahead（要件定義 §63 / §64） -------------------------


func test_depth_follows_the_profile() -> void:
	profile.lookahead = 0
	assert_eq(search.get_effective_depth(), 1, "先読みなしなら深さ 1")

	profile.lookahead = 1
	assert_eq(search.get_effective_depth(), 2, "1 手先読みなら深さ 2")


func test_depth_never_exceeds_the_absolute_limit() -> void:
	for lookahead in range(0, 6):
		profile.lookahead = lookahead
		assert_true(
			search.get_effective_depth() <= PlacementSearch.MAX_SEARCH_DEPTH,
			"Profile が %d を要求しても上限を超えない" % lookahead
		)


func test_lookahead_changes_the_evaluation() -> void:
	# 先読みの有無で候補の評価が変わること（深さが実際に効いていること）。
	_stack([5, 5, 5, 5, 5, 5, 5, 5, 5, 1])
	var next_types: Array[int] = [Piece.Type.I, Piece.Type.O]

	profile.lookahead = 0
	var shallow: Array[Placement] = search.rank_candidates(board, Piece.Type.S, next_types)

	profile.lookahead = 1
	var deep: Array[Placement] = search.rank_candidates(board, Piece.Type.S, next_types)

	assert_ne(shallow[0].score, deep[0].score, "先読みすると評価値が変わる")


func test_lookahead_does_not_break_validity() -> void:
	_stack([3, 1, 4, 2, 5, 3, 1, 4, 2, 3])
	profile.lookahead = 1

	var best: Placement = search.search(board, Piece.Type.T, [Piece.Type.I, Piece.Type.J])

	assert_true(
		Collision.can_place(board, best.piece_type, best.rotation, best.position),
		"先読みしても現在の盤面に置ける候補が返る"
	)


# --- Placement Quality（要件定義 §62） --------------------------------------


func test_quality_one_always_picks_the_best() -> void:
	_stack([3, 1, 4, 2, 5, 3, 1, 4, 2, 3])
	profile.placement_quality = 1.0

	var first: Placement = search.search(board, Piece.Type.T)
	for _attempt in range(10):
		assert_true(search.search(board, Piece.Type.T).equals(first), "常に同じ最良候補")


func test_lower_quality_varies_the_choice() -> void:
	_stack([3, 1, 4, 2, 5, 3, 1, 4, 2, 3])
	profile.placement_quality = 0.2

	var seen: Dictionary = {}
	for _attempt in range(30):
		var placement: Placement = search.search(board, Piece.Type.T)
		seen[Vector3i(placement.position.x, placement.position.y, placement.rotation)] = true

	assert_gt(seen.size(), 1, "品質を下げるとばらつく")


func test_lower_quality_is_still_reproducible() -> void:
	_stack([3, 1, 4, 2, 5, 3, 1, 4, 2, 3])
	profile.placement_quality = 0.3

	var first: Array[Vector3i] = []
	for _attempt in range(10):
		var placement: Placement = search.search(board, Piece.Type.T)
		first.append(Vector3i(placement.position.x, placement.position.y, placement.rotation))

	search.reset(SEED)
	for index in range(10):
		var placement: Placement = search.search(board, Piece.Type.T)
		assert_eq(
			Vector3i(placement.position.x, placement.position.y, placement.rotation),
			first[index],
			"同じ Seed からは同じ選択列"
		)


func test_quality_choice_stays_within_the_candidates() -> void:
	_stack([3, 1, 4, 2, 5, 3, 1, 4, 2, 3])
	profile.placement_quality = 0.0

	for _attempt in range(20):
		var placement: Placement = search.search(board, Piece.Type.T)
		assert_true(
			Collision.can_place(
				board, placement.piece_type, placement.rotation, placement.position
			),
			"品質 0 でも置ける候補しか返らない"
		)
