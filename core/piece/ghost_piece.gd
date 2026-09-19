class_name GhostPiece
extends RefCounted

## Ghost Piece（要件定義 §26）。
##
## Hard Drop したときの着地点を求めるだけで、Board も Piece も変更しない。
## Collision には影響しない（あくまで導出値）。
##
## 状態を持たないので全て static。


## Hard Drop したときの着地位置（Bounding Box 左上）を返す。
##
## 現在位置に置けない場合は、現在位置をそのまま返す。
static func get_landing_position(
	board: Board, type: Piece.Type, rotation: Piece.Rotation, origin: Vector2i
) -> Vector2i:
	if not Collision.can_place(board, type, rotation, origin):
		return origin

	var landing: Vector2i = origin
	while Collision.can_place(board, type, rotation, landing + Vector2i.DOWN):
		landing += Vector2i.DOWN
	return landing


## 着地までに落ちるマス数を返す。
static func get_drop_distance(
	board: Board, type: Piece.Type, rotation: Piece.Rotation, origin: Vector2i
) -> int:
	return get_landing_position(board, type, rotation, origin).y - origin.y


## 着地位置で Piece が占めるマスを返す。描画に使う。
static func get_landing_cells(
	board: Board, type: Piece.Type, rotation: Piece.Rotation, origin: Vector2i
) -> Array[Vector2i]:
	var landing: Vector2i = get_landing_position(board, type, rotation, origin)
	return Collision.get_cells(type, rotation, landing)
