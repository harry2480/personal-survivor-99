class_name RotationSystem
extends RefCounted

## SRS 系の回転と Wall Kick（要件定義 §25）。
##
## Kick Table は外から注入する。I Piece 用とその他用を分けて持てるので、
## 回転系を変えたい場合は表だけを差し替えればよい（[SrsKickTables] も参照）。
##
## Game Core Layer に属するため、UI / Audio / Input / Scene / FileSystem に依存しない
## （要件定義 §17）。同じ入力からは必ず同じ結果になる。

## 回転方向。
enum Direction { CLOCKWISE, COUNTER_CLOCKWISE }

var _standard_table: KickTable
var _i_table: KickTable


## Kick Table を指定して初期化する。省略すると標準 SRS の表を使う。
func _init(standard_table: KickTable = null, i_table: KickTable = null) -> void:
	_standard_table = standard_table if standard_table != null else SrsKickTables.create_standard()
	_i_table = i_table if i_table != null else SrsKickTables.create_i()


## Piece の種類に対して使う Kick Table を返す。
func get_kick_table(type: Piece.Type) -> KickTable:
	return _i_table if type == Piece.Type.I else _standard_table


## 回転後の回転状態を返す。Board との衝突は見ない。
static func get_next_rotation(rotation: Piece.Rotation, direction: Direction) -> Piece.Rotation:
	var step: int = 1 if direction == Direction.CLOCKWISE else -1
	return posmod(rotation + step, Piece.ROTATION_COUNT) as Piece.Rotation


## 回転を試す。
##
## Kick Table のオフセットを順に試し、最初に収まったものを採用する。
## どれも収まらなければ失敗し、位置も回転状態も変わらない。
func rotate(
	board: Board, type: Piece.Type, rotation: Piece.Rotation, origin: Vector2i, direction: Direction
) -> RotationResult:
	var next_rotation: Piece.Rotation = get_next_rotation(rotation, direction)
	var offsets: PackedVector2Array = get_kick_table(type).get_offsets(rotation, next_rotation)

	for index in range(offsets.size()):
		var offset: Vector2i = Vector2i(offsets[index])
		var candidate: Vector2i = origin + offset
		if Collision.can_place(board, type, next_rotation, candidate):
			return RotationResult.create_success(candidate, next_rotation, index, offset)

	return RotationResult.create_failure(origin, rotation)


## 回転を試し、結果を [Vector3i] で返す（割り当てなし）。
##
## [code](x, y, 回転状態)[/code] を返す。失敗した場合は [code]z[/code] が -1。
## CPU の配置探索（#39）が 1 手あたり数千回呼ぶため、[RotationResult] を作らずに
## 済ませる入口を用意している。ゲーム側は [method rotate] を使う。
func try_rotate(
	board: Board, type: Piece.Type, rotation: Piece.Rotation, origin: Vector2i, direction: Direction
) -> Vector3i:
	var next_rotation: Piece.Rotation = get_next_rotation(rotation, direction)
	var offsets: PackedVector2Array = get_kick_table(type).get_offsets(rotation, next_rotation)

	for index in range(offsets.size()):
		var candidate: Vector2i = origin + Vector2i(offsets[index])
		if Collision.can_place(board, type, next_rotation, candidate):
			return Vector3i(candidate.x, candidate.y, next_rotation)

	return Vector3i(0, 0, -1)


## 時計回りに回す。
func rotate_clockwise(
	board: Board, type: Piece.Type, rotation: Piece.Rotation, origin: Vector2i
) -> RotationResult:
	return rotate(board, type, rotation, origin, Direction.CLOCKWISE)


## 反時計回りに回す。
func rotate_counter_clockwise(
	board: Board, type: Piece.Type, rotation: Piece.Rotation, origin: Vector2i
) -> RotationResult:
	return rotate(board, type, rotation, origin, Direction.COUNTER_CLOCKWISE)
