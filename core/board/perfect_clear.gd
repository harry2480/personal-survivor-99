class_name PerfectClear
extends RefCounted

## Perfect Clear の判定（要件定義 §36）。
##
## Line Clear の処理が終わった時点で盤面が空なら成立する。判定するだけで、
## Board も Attack も変更しない。
##
## 状態を持たないので全て static。


## Line Clear 処理後の盤面が空かを返す。
##
## [param line_count] が 0 のときは成立しない。もともと空だった盤面へ Piece を
## 置かずに通っただけ、という状況を Perfect Clear にしないため。
static func is_achieved(board: Board, line_count: int) -> bool:
	if line_count <= 0:
		return false
	return is_board_empty(board)


## 盤面が空かを返す。
static func is_board_empty(board: Board) -> bool:
	for y in range(Board.TOTAL_HEIGHT):
		if not board.is_row_empty(y):
			return false
	return true
