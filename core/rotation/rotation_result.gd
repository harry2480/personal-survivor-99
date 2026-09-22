class_name RotationResult
extends RefCounted

## 回転を試した結果。
##
## 成否だけでなく「どの Kick が採用されたか」を残す。T-Spin 判定（Phase 2 / #29）は
## 「最後の操作が回転だったか」と「何番目の Kick で収まったか」を根拠にするため、
## 判定 Module を後から独立して載せられるようにしておく。

## 回転が成立したか。
var success: bool = false

## 回転後の Bounding Box 左上座標。失敗した場合は元の座標。
var position: Vector2i = Vector2i.ZERO

## 回転後の回転状態。失敗した場合は元の回転状態。
var rotation: Piece.Rotation = Piece.Rotation.SPAWN

## 採用された Kick が Kick Table の何番目だったか。失敗した場合は -1。
##
## 0 は「移動なしで収まった」。1 以上は Wall Kick が働いたことを意味する。
var kick_index: int = -1

## 採用された Kick のオフセット。失敗した場合は [constant Vector2i.ZERO]。
var kick_offset: Vector2i = Vector2i.ZERO


static func create_success(
	new_position: Vector2i, new_rotation: Piece.Rotation, index: int, offset: Vector2i
) -> RotationResult:
	var result := RotationResult.new()
	result.success = true
	result.position = new_position
	result.rotation = new_rotation
	result.kick_index = index
	result.kick_offset = offset
	return result


static func create_failure(
	position_before: Vector2i, rotation_before: Piece.Rotation
) -> RotationResult:
	var result := RotationResult.new()
	result.success = false
	result.position = position_before
	result.rotation = rotation_before
	return result


## Wall Kick が働いたか（移動なしで収まった場合は false）。
func used_kick() -> bool:
	return success and kick_index > 0
