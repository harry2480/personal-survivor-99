class_name Collision
extends RefCounted

## Piece と Board の衝突判定。
##
## 「その位置・その回転で Piece を置けるか」だけを答える。落下も回転も行わない。
## Game Core Layer に属するため、UI / Audio / Input / Scene / FileSystem に依存しない
## （要件定義 §17）。状態を持たないので全て static。


## Piece が占める Board 上の絶対座標を返す。
##
## [param origin] は Bounding Box 左上の Board 座標。
static func get_cells(
	type: Piece.Type, rotation: Piece.Rotation, origin: Vector2i
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for offset in Piece.get_cells(type, rotation):
		cells.append(origin + offset)
	return cells


## その位置・回転で Piece を置けるかを返す。
##
## 置けないのは次のいずれか。
## [br]・左右の壁の外
## [br]・床より下
## [br]・内部領域の上端より上
## [br]・既にブロックがあるマス
static func can_place(
	board: Board, type: Piece.Type, rotation: Piece.Rotation, origin: Vector2i
) -> bool:
	# 盤外か既にブロックがあるかを 1 回で見る。1 手の探索で数万回走るため
	# （#39 の計測）、ここでの呼び出し回数を抑えている。
	for offset in Piece.get_cells(type, rotation):
		if not board.is_cell_free(origin.x + offset.x, origin.y + offset.y):
			return false

	return true


## Piece が接地している（1 マス下へ動かせない）かを返す。
static func is_on_ground(
	board: Board, type: Piece.Type, rotation: Piece.Rotation, origin: Vector2i
) -> bool:
	return not can_place(board, type, rotation, origin + Vector2i.DOWN)


## Piece を Board へ書き込む。置けない場合は何もせず false を返す。
static func place(
	board: Board, type: Piece.Type, rotation: Piece.Rotation, origin: Vector2i
) -> bool:
	if not can_place(board, type, rotation, origin):
		return false
	for cell in get_cells(type, rotation, origin):
		board.set_cell(cell.x, cell.y, type)
	return true
