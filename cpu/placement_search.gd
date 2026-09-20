class_name PlacementSearch
extends RefCounted

## 配置候補の列挙と選択（要件定義 §62〜§64）。
##
## **到達可能性は実際の操作で判定する**（#39 の制約）。Spawn 位置から
## 「左右移動・回転（Wall Kick 込み）・1 マス落下」を繰り返して届く状態だけを
## 候補にするため、幅優先探索で到達集合を作る。回転は Phase 1 の
## [RotationSystem] をそのまま使うので、T-Spin の入り口になる置き方も拾える。
##
## Lookahead は NEXT を何手先まで見るかで、[member CpuProfile.lookahead] が
## 決める。探索の深さには**絶対上限**があり、Profile がそれを超えて要求しても
## 打ち切る（#39 の完了条件）。
##
## 選択は Seed 付きの [RandomNumberGenerator]。Placement Quality を下げると
## 上位候補から準ランダムに選ぶようになる（要件定義 §62）。

## 1 手ぶんの探索で調べる状態数の上限。
##
## 盤面は 10 × 40、回転は 4 通りなので、到達しうる状態は最大でも 1600。
## 打ち切りが働くのは異常時だけで、通常の探索は上限に届かない。
const MAX_VISITED_STATES: int = Board.WIDTH * Board.TOTAL_HEIGHT * Piece.ROTATION_COUNT

## 探索の深さの絶対上限（現在 Piece + 先読み）。
##
## `scripts/benchmark-cpu.sh` の計測に基づく。Profile がこれを超える Lookahead を
## 要求しても、ここで打ち切る（#39 の完了条件）。
##
## 計測結果（Apple Silicon / Godot 4.7.2 / 積み上がった盤面）:
## [codeblock]
## 深さ 1 →    6.0 ms / 手
## 深さ 2 →   55   ms / 手
## 深さ 3 → 3225   ms / 手   ← 1 手に 3 秒。実用にならない
## [/codeblock]
##
## 深さ 3 は Beam を掛けても深さ 2 の 58 倍になる。上限を 2 に置く。
##
## 深さ 1 でも 99 体ぶんを同じフレームで走らせると 1 フレームの予算
## （60fps = 16.7 ms）を大きく超える。CPU は Piece ごとにしか考えないので
## 実効的な負荷はもっと低いが、更新の分散（Phase 7 / #47）と
## Lightweight CPU（#42）が前提になる。
const MAX_SEARCH_DEPTH: int = 2

# 状態を int へ畳むための下駄と幅。Bounding Box の左上は盤外（負の x）にもなる。
const _STATE_OFFSET: int = 8
const _STATE_SPAN: int = Board.WIDTH + _STATE_OFFSET * 2

const _MOVES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
const _DIRECTIONS: Array[int] = [
	RotationSystem.Direction.CLOCKWISE, RotationSystem.Direction.COUNTER_CLOCKWISE
]

var _profile: CpuProfile
var _evaluator: BoardEvaluator
var _rotation: RotationSystem = RotationSystem.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _scratch_board: Board = Board.new()


func _init(profile: CpuProfile = null, search_seed: int = 0) -> void:
	_profile = profile if profile != null else CpuProfile.create_default()
	_evaluator = BoardEvaluator.new(_profile)
	_rng.seed = search_seed


## Seed を指定して選択をやり直せるようにする。
func reset(search_seed: int) -> void:
	_rng.seed = search_seed


## 使っている Profile を返す。
func get_profile() -> CpuProfile:
	return _profile


## 実際に使う探索の深さを返す（Profile の値を絶対上限で打ち切ったもの）。
func get_effective_depth() -> int:
	return clampi(1 + _profile.lookahead, 1, MAX_SEARCH_DEPTH)


## Spawn から到達できる配置をすべて返す。
##
## 返るのは「そこで固定できる（接地している）」状態だけ。
##
## 1 手あたり数千回の判定になるため、状態は int へ畳んで [Dictionary] に入れ、
## 展開も配列を作らずに行う。[RotationResult] も作らない。
func find_reachable_placements(board: Board, piece_type: int) -> Array[Placement]:
	var placements: Array[Placement] = []
	var spawn_position: Vector2i = Piece.get_spawn_position(piece_type)
	if not Collision.can_place(board, piece_type, Piece.SPAWN_ROTATION, spawn_position):
		return placements

	var visited: Dictionary = {}
	var queue: Array[int] = []
	var head: int = 0

	var start_state: int = _encode(spawn_position.x, spawn_position.y, Piece.SPAWN_ROTATION)
	visited[start_state] = true
	queue.append(start_state)

	while head < queue.size() and visited.size() < MAX_VISITED_STATES:
		var state: int = queue[head]
		head += 1

		var rotation: int = state & 3
		var packed: int = state >> 2
		var x: int = (packed % _STATE_SPAN) - _STATE_OFFSET
		var y: int = (packed / _STATE_SPAN) - _STATE_OFFSET
		var position := Vector2i(x, y)

		if Collision.is_on_ground(board, piece_type, rotation, position):
			placements.append(Placement.create(piece_type, rotation, position))

		_push_moves(board, piece_type, position, rotation, visited, queue)
		_push_rotations(board, piece_type, position, rotation, visited, queue)

	return placements


## 現在 Piece（と Hold）について、最良の配置を返す。
##
## [param next_types] は NEXT の並び。Lookahead の手数ぶんだけ使う。
## 候補がなければ [code]null[/code]。
func search(
	board: Board, current_type: int, next_types: Array[int] = [], hold_type: int = -1
) -> Placement:
	var candidates: Array[Placement] = _collect_candidates(board, current_type, hold_type)
	if candidates.is_empty():
		return null

	_score_all(board, candidates, next_types)
	return _choose(candidates)


## 候補を評価値の高い順に並べて返す。デバッグと検証用。
func rank_candidates(
	board: Board, current_type: int, next_types: Array[int] = [], hold_type: int = -1
) -> Array[Placement]:
	var candidates: Array[Placement] = _collect_candidates(board, current_type, hold_type)
	_score_all(board, candidates, next_types)
	candidates.sort_custom(_compare_by_score)
	return candidates


# 候補に評価値を入れる。
#
# 深く読むのは上位 [member CpuProfile.beam_width] 件だけ。到達できる配置は 40 前後
# あり、全部を深く読むと 1 手に数十 ms かかるため（計測: scripts/benchmark-cpu.sh）。
func _score_all(board: Board, candidates: Array[Placement], next_types: Array[int]) -> void:
	for placement in candidates:
		placement.score = _score_placement(board, placement, next_types, 0)

	var depth: int = get_effective_depth()
	if depth <= 1 or next_types.is_empty():
		return

	candidates.sort_custom(_compare_by_score)
	var beam: int = clampi(_profile.beam_width, 1, candidates.size())
	for index in range(beam):
		candidates[index].score = _score_placement(board, candidates[index], next_types, depth - 1)


func _collect_candidates(board: Board, current_type: int, hold_type: int) -> Array[Placement]:
	var candidates: Array[Placement] = find_reachable_placements(board, current_type)

	# Hold を使う選択肢も候補に入れる。空なら NEXT の先頭が出てくるが、
	# その判断は呼び出し側（#42 の CPU）が持つので、ここでは種類が分かる場合だけ扱う。
	if hold_type >= 0 and hold_type != current_type:
		for placement in find_reachable_placements(board, hold_type):
			placement.uses_hold = true
			candidates.append(placement)

	return candidates


# 1 手先までの評価。depth が残っていれば NEXT を置いた先も見る。
func _score_placement(
	board: Board, placement: Placement, next_types: Array[int], remaining_depth: int
) -> float:
	# 先読みの再帰では盤面を持ち回るため、深さ 0 のときだけ使い回しの Board を使う。
	var next_board: Board = _scratch_board if remaining_depth <= 0 else Board.new()
	next_board.copy_from(board)
	Collision.place(next_board, placement.piece_type, placement.rotation, placement.position)
	LineClear.execute(next_board)

	var score: float = _evaluator.evaluate(next_board)
	if remaining_depth <= 0 or next_types.is_empty():
		return score

	# 先読み: 次の Piece を最良に置いたときの評価を足す。
	var lookahead_type: int = next_types[0]
	var rest: Array[int] = next_types.slice(1)
	var best_next: float = -INF
	for next_placement in find_reachable_placements(next_board, lookahead_type):
		best_next = maxf(
			best_next, _score_placement(next_board, next_placement, rest, remaining_depth - 1)
		)

	return score if best_next == -INF else (score + best_next) * 0.5


# Placement Quality に応じて候補を選ぶ（要件定義 §62）。
# 1.0 で常に最良、下げるほど上位候補から準ランダムに選ぶ。
func _choose(candidates: Array[Placement]) -> Placement:
	candidates.sort_custom(_compare_by_score)

	var quality: float = clampf(_profile.placement_quality, 0.0, 1.0)
	if is_equal_approx(quality, 1.0) or candidates.size() == 1:
		return candidates[0]

	# 品質が低いほど、選択肢に含める候補の幅が広がる。
	var pool_size: int = maxi(1, int(round(float(candidates.size()) * (1.0 - quality))))
	pool_size = mini(pool_size, candidates.size())
	return candidates[_rng.randi_range(0, pool_size - 1)]


static func _compare_by_score(left: Placement, right: Placement) -> bool:
	if not is_equal_approx(left.score, right.score):
		return left.score > right.score

	# 同点は決定論的に並べる。Seed が同じなら結果も同じにするため。
	if left.rotation != right.rotation:
		return left.rotation < right.rotation
	if left.position.x != right.position.x:
		return left.position.x < right.position.x
	return left.position.y < right.position.y


func _push_moves(
	board: Board,
	piece_type: int,
	position: Vector2i,
	rotation: int,
	visited: Dictionary,
	queue: Array[int]
) -> void:
	for step in _MOVES:
		var moved: Vector2i = position + step
		if not Collision.can_place(board, piece_type, rotation, moved):
			continue
		var state: int = _encode(moved.x, moved.y, rotation)
		if not visited.has(state):
			visited[state] = true
			queue.append(state)


func _push_rotations(
	board: Board,
	piece_type: int,
	position: Vector2i,
	rotation: int,
	visited: Dictionary,
	queue: Array[int]
) -> void:
	for direction in _DIRECTIONS:
		var rotated: Vector3i = _rotation.try_rotate(
			board, piece_type, rotation, position, direction
		)
		if rotated.z < 0:
			continue
		var state: int = _encode(rotated.x, rotated.y, rotated.z)
		if not visited.has(state):
			visited[state] = true
			queue.append(state)


# 状態を 1 つの int へ畳む。x は負にもなるため下駄を履かせる。
static func _encode(x: int, y: int, rotation: int) -> int:
	return (((y + _STATE_OFFSET) * _STATE_SPAN + (x + _STATE_OFFSET)) << 2) | rotation
