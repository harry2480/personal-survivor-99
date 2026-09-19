class_name ActivePiece
extends RefCounted

## いま操作している Piece の状態（種類・回転・位置）。
##
## Hold から戻ってきた Piece も NEXT から出てきた Piece も [method spawn] を通す。
## そうすることで「初期 Rotation / Spawn Position に戻す」を 1 箇所に集約できる
## （要件定義 §24）。
##
## Board も Randomizer も持たない。判定は [Collision]、落下は [Gravity] の担当。

## Piece の種類（[enum Piece.Type]）。
var type: int = -1

## 現在の回転状態（[enum Piece.Rotation]）。
var rotation: int = Piece.Rotation.SPAWN

## Bounding Box 左上の Board 座標。
var position: Vector2i = Vector2i.ZERO


func _init(spawn_type: int = -1) -> void:
	if spawn_type >= 0:
		spawn(spawn_type)


## 指定した種類で出現させる。回転と位置は必ず初期値に戻る。
func spawn(spawn_type: int) -> void:
	type = spawn_type
	rotation = Piece.SPAWN_ROTATION
	position = Piece.get_spawn_position(spawn_type)


## 操作対象の Piece があるかを返す。
func is_active() -> bool:
	return type >= 0


## 操作対象を空にする。
func clear() -> void:
	type = -1
	rotation = Piece.SPAWN_ROTATION
	position = Vector2i.ZERO


## Piece が占める Board 上の絶対座標を返す。
func get_cells() -> Array[Vector2i]:
	return Collision.get_cells(type, rotation, position)


## Piece が占める一番下のマスの y を返す。
func get_lowest_y() -> int:
	var lowest: int = position.y
	for offset in Piece.get_cells(type, rotation):
		lowest = maxi(lowest, position.y + offset.y)
	return lowest


## 現在の位置・回転で Board に置けるかを返す。
func can_place(board: Board) -> bool:
	return Collision.can_place(board, type, rotation, position)


## 接地しているかを返す。
func is_on_ground(board: Board) -> bool:
	return Collision.is_on_ground(board, type, rotation, position)
