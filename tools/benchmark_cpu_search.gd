extends SceneTree

## CPU の配置探索にかかる時間を計測する。
##
## Search Depth の上限（[constant PlacementSearch.MAX_SEARCH_DEPTH]）を、
## 根拠のある数字にするための計測。scripts/benchmark-cpu.sh から実行する。
##
## 判断の基準は要件定義 §84「CPU 思考が Human Input を遅延させない」。
## 99 体が 1 フレーム（60fps = 16.6ms）の中で思考しきれるかを見る。

const SEED: int = 20260920
const PLAYERS: int = 99
const FRAME_BUDGET_MS: float = 1000.0 / 60.0

## 1 段階あたりの計測回数。深いほど 1 回が重いので減らす。
const SAMPLES_BY_LOOKAHEAD: Array[int] = [50, 20, 20, 20]

## これを超えたら以降の段階は測らない。測るだけで数分かかるため。
const ABORT_ABOVE_MS: float = 500.0

## CPU 1 体が 1 秒間に置く Piece の数（想定）。
const PIECES_PER_SECOND: float = 2.0


func _init() -> void:
	print("Search Depth の計測（1 手あたりの平均。段階ごとに回数を変えている）")
	print("1 フレームの予算: %.2f ms（60fps）" % FRAME_BUDGET_MS)
	print("")
	print("| Lookahead | 深さ | 1 手 (ms) | 99 体が同時 (ms) | 99 体 × 2 手/秒 (ms/秒) |")
	print("|---|---|---|---|---|")

	for lookahead in range(0, SAMPLES_BY_LOOKAHEAD.size()):
		if not _measure(lookahead):
			print("| %d | - | 計測打ち切り（1 手 %.0f ms 超）| - | - |" % [lookahead, ABORT_ABOVE_MS])
			break

	print("")
	print("MAX_SEARCH_DEPTH = %d" % PlacementSearch.MAX_SEARCH_DEPTH)
	print("")
	print("「99 体が同時」は全員が同じフレームで考えた場合の最悪値。")
	print("実際は Piece ごとに考えるため、右端の「ms/秒」が実効的な負荷に近い。")
	print("更新の分散は Phase 7（#47）で行う。")
	quit(0)


func _measure(lookahead: int) -> bool:
	var profile := CpuProfile.create_default()
	profile.lookahead = lookahead
	var search := PlacementSearch.new(profile, SEED)
	var randomizer := PieceRandomizer.new(SEED)
	var board: Board = _make_board()

	var next_types: Array[int] = randomizer.peek(4)
	var samples: int = SAMPLES_BY_LOOKAHEAD[lookahead]
	var start: int = Time.get_ticks_usec()
	for _sample in range(samples):
		search.search(board, Piece.Type.T, next_types)
	var elapsed_us: int = Time.get_ticks_usec() - start

	var per_search_ms: float = float(elapsed_us) / float(samples) / 1000.0
	var all_players_ms: float = per_search_ms * float(PLAYERS)

	# CPU は毎フレームではなく Piece ごとに考える。実際の負荷はこちらに近い。
	var per_second_ms: float = per_search_ms * float(PLAYERS) * PIECES_PER_SECOND
	print(
		(
			"| %d | %d | %.3f | %.1f | %.1f |"
			% [
				lookahead,
				search.get_effective_depth(),
				per_search_ms,
				all_players_ms,
				per_second_ms
			]
		)
	)
	return per_search_ms <= ABORT_ABOVE_MS


# そこそこ積み上がった盤面。空盤面より候補も分岐も多く、重い側の条件になる。
func _make_board() -> Board:
	var board := Board.new()
	var heights: PackedInt32Array = PackedInt32Array([4, 6, 3, 7, 5, 2, 8, 4, 6, 3])
	for x in range(Board.WIDTH):
		for offset in range(heights[x]):
			board.set_cell(x, Board.TOTAL_HEIGHT - 1 - offset, Piece.Type.I)
	return board
