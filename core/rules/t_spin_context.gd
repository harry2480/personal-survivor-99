class_name TSpinContext
extends RefCounted

## T-Spin 判定に渡す情報（要件定義 §33）。
##
## 判定 Module を差し替えられるよう、必要な情報をこの 1 つにまとめて渡す。
## Module 側は Board と Piece の状態だけを見て、進行や Scoring を知らない。

## 判定対象の盤面。Piece を置く前の状態を渡す。
var board: Board

## Piece の種類（[enum Piece.Type]）。
var piece_type: int = -1

## Lock 時点の回転状態（[enum Piece.Rotation]）。
var rotation: int = Piece.Rotation.SPAWN

## Lock 時点の Bounding Box 左上座標。
var position: Vector2i = Vector2i.ZERO

## 直前の操作が回転だったか。移動や落下で着地した場合は false。
var last_action_was_rotation: bool = false

## 直前の回転で採用された Kick の index。Kick なしなら 0、回転していなければ -1。
var kick_index: int = -1

## 直前の回転で使われた Kick Table のオフセット数。
##
## 「最後の Kick が採用されたか」を判定するために使う。SRS は 5 個。
var kick_table_size: int = 0


static func create(
	board_state: Board,
	piece_type_value: int,
	rotation_value: int,
	position_value: Vector2i,
	was_rotation: bool,
	kick_index_value: int,
	kick_table_size_value: int
) -> TSpinContext:
	var context := TSpinContext.new()
	context.board = board_state
	context.piece_type = piece_type_value
	context.rotation = rotation_value
	context.position = position_value
	context.last_action_was_rotation = was_rotation
	context.kick_index = kick_index_value
	context.kick_table_size = kick_table_size_value
	return context


## 直前の回転で、Kick Table の最後のオフセットが採用されたかを返す。
##
## SRS では、この Kick で収まった回転は Mini ではなく通常の T-Spin として扱う。
func used_last_kick() -> bool:
	return kick_table_size > 0 and kick_index == kick_table_size - 1
