class_name Placement
extends RefCounted

## 配置候補 1 つ（要件定義 §62〜§64）。
##
## 「どの向きで、どこに置くか」と、その結果の評価値を持つ。Hold を使う候補か
## どうかも持つので、呼び出し側は Hold の判断を別に持たなくて済む。

## 置く Piece の種類。
var piece_type: int = -1

## 置くときの回転状態。
var rotation: int = Piece.Rotation.SPAWN

## 置く位置（Bounding Box 左上）。
var position: Vector2i = Vector2i.ZERO

## この候補を選ぶために Hold を使うか。
var uses_hold: bool = false

## 評価値。大きいほど良い。
var score: float = -INF


static func create(
	type: int, rotation_value: int, position_value: Vector2i, hold: bool = false
) -> Placement:
	var placement := Placement.new()
	placement.piece_type = type
	placement.rotation = rotation_value
	placement.position = position_value
	placement.uses_hold = hold
	return placement


## 有効な候補かを返す。
func is_valid() -> bool:
	return piece_type >= 0


## 同じ置き方かを返す。
func equals(other: Placement) -> bool:
	if other == null:
		return false
	return (
		piece_type == other.piece_type
		and rotation == other.rotation
		and position == other.position
		and uses_hold == other.uses_hold
	)
