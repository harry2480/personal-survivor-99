class_name BoardMetrics
extends RefCounted

## 盤面から評価の材料になる指標を測る（要件定義 §68）。
##
## 重みは持たない。**測るだけ**で、良し悪しの判断は [BoardEvaluator] の役目。
## 指標と重みを分けておくと、Profile ごとに重みだけを差し替えられる。
##
## 99 体ぶんを毎フレーム呼ぶため、**1 インスタンスを使い回して割り当てを抑える**
## 設計にしている（#38 の制約）。[method measure] は内部バッファを再利用する。

## 各列の積み上げ高さの合計。
var aggregate_height: int = 0

## 一番高い列の高さ。
var max_height: int = 0

## 塞がれた空きマスの数。
var holes: int = 0

## 穴の上に何マス積まれているかの合計。
var hole_depth: int = 0

## 隣り合う列の高さの差の合計（表面の凸凹）。
var bumpiness: int = 0

## 深い溝（両隣より 2 マス以上低い列）の深さの合計。
var wells: int = 0

## 行方向の「埋まり／空き」の切り替わり回数。
var row_transitions: int = 0

## 列方向の「埋まり／空き」の切り替わり回数。
var column_transitions: int = 0

## 揃っている行の数。
var completed_lines: int = 0

## 穴が塞がれた Garbage 行の数。少ないほど掘り返しやすい。
var blocked_garbage_rows: int = 0

## 盤面の危険度（0.0〜1.0）。
var danger_ratio: float = 0.0

var _heights: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_heights.resize(Board.WIDTH)


## 盤面を測り直す。結果は各プロパティへ入る。
func measure(board: Board) -> void:
	_reset()
	_measure_columns(board)
	_measure_rows(board)
	danger_ratio = DangerLevel.get_ratio(board)


## 各列の高さを返す（内部バッファなので書き換えない）。
func get_heights() -> PackedInt32Array:
	return _heights


func _reset() -> void:
	aggregate_height = 0
	max_height = 0
	holes = 0
	hole_depth = 0
	bumpiness = 0
	wells = 0
	row_transitions = 0
	column_transitions = 0
	completed_lines = 0
	blocked_garbage_rows = 0
	danger_ratio = 0.0


func _measure_columns(board: Board) -> void:
	for x in range(Board.WIDTH):
		var top_y: int = Board.TOTAL_HEIGHT
		var column_holes: int = 0
		var column_hole_depth: int = 0
		var previous_filled: bool = true  # 盤面の下端の外は埋まり扱い

		for y in range(Board.TOTAL_HEIGHT):
			var filled: bool = not board.is_cell_empty(x, y)
			if filled and top_y == Board.TOTAL_HEIGHT:
				top_y = y
			if not filled and top_y != Board.TOTAL_HEIGHT:
				column_holes += 1
				column_hole_depth += y - top_y
			if filled != previous_filled:
				column_transitions += 1
			previous_filled = filled

		if not previous_filled:
			column_transitions += 1

		var height: int = Board.TOTAL_HEIGHT - top_y
		_heights[x] = height
		aggregate_height += height
		max_height = maxi(max_height, height)
		holes += column_holes
		hole_depth += column_hole_depth

	_measure_surface()


func _measure_surface() -> void:
	for x in range(Board.WIDTH - 1):
		bumpiness += absi(_heights[x] - _heights[x + 1])

	for x in range(Board.WIDTH):
		var left: int = _heights[x - 1] if x > 0 else Board.TOTAL_HEIGHT
		var right: int = _heights[x + 1] if x < Board.WIDTH - 1 else Board.TOTAL_HEIGHT
		var depth: int = mini(left, right) - _heights[x]
		if depth >= 2:
			wells += depth


func _measure_rows(board: Board) -> void:
	for y in range(Board.TOTAL_HEIGHT):
		var filled_cells: int = 0
		var previous_filled: bool = true  # 左右の壁は埋まり扱い
		var garbage_hole_x: int = -1

		for x in range(Board.WIDTH):
			var value: int = board.get_cell(x, y)
			var filled: bool = value != Board.EMPTY
			if filled:
				filled_cells += 1
			elif value == Board.EMPTY:
				garbage_hole_x = x
			if filled != previous_filled:
				row_transitions += 1
			previous_filled = filled

		if not previous_filled:
			row_transitions += 1

		if filled_cells == Board.WIDTH:
			completed_lines += 1
		elif _is_garbage_row(board, y) and garbage_hole_x >= 0:
			if not board.is_cell_empty(garbage_hole_x, y - 1):
				blocked_garbage_rows += 1


static func _is_garbage_row(board: Board, y: int) -> bool:
	for x in range(Board.WIDTH):
		if board.get_cell(x, y) == GarbageQueue.GARBAGE_CELL:
			return true
	return false
