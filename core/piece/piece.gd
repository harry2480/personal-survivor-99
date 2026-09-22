class_name Piece
extends RefCounted

## Piece の形状定義（要件定義 §21）。
##
## 形状は「Bounding Box 内の 4 マスのオフセット」として持つ。Box の大きさは
## I が 4×4、O が 2×2、それ以外が 3×3 で、SRS の回転と Wall Kick（#23）が
## この Box を前提にしている。
##
## オフセットは Box の左上を原点とし、[code]x[/code] は右、[code]y[/code] は下が正。
## Board と同じ向きなので、Board 上の座標は「Piece の位置 + オフセット」で求まる。
##
## Game Core Layer に属するため、UI / Audio / Input / Scene / FileSystem に依存しない
## （要件定義 §17）。状態を持たない定義テーブルなので、すべて static。

## Piece の種類。値は Board のセル値としてそのまま使う（[constant Board.EMPTY] は負値）。
enum Type { I, J, L, O, S, T, Z }

## 回転状態。SRS の 0 / R / 2 / L に対応する。
enum Rotation { SPAWN, RIGHT, TWO, LEFT }

## Piece の種類数。
const TYPE_COUNT: int = 7

## 回転状態の数。
const ROTATION_COUNT: int = 4

## 1 つの Piece が占めるマス数。
const CELL_COUNT: int = 4

## 出現時の回転状態。
const SPAWN_ROTATION: Rotation = Rotation.SPAWN

## 種類を表す 1 文字。ログとテストの可読性のために使う。
const LETTERS: PackedStringArray = ["I", "J", "L", "O", "S", "T", "Z"]

# Bounding Box の一辺。SRS の Wall Kick がこの大きさを前提にする。
const _BOX_SIZES: PackedInt32Array = [4, 3, 3, 2, 3, 3, 3]

# 出現位置（Bounding Box 左上の Board 座標）の x。
# 3 幅の Piece は x=3..5、I は x=3..6、O は x=4..5 を占める。
const _SPAWN_X: PackedInt32Array = [3, 3, 3, 4, 3, 3, 3]

# 形状テーブル。[type][rotation] で 4 マスのオフセットを引く。
# 型付き配列として保持したいので、static var として 1 度だけ組み立てる。
static var _shapes: Array[Array] = _build_shapes()


## Bounding Box 左上を原点とした、4 マスのオフセットを返す。
##
## 返る配列は共有された定義そのもの。呼び出し側で書き換えてはいけない。
static func get_cells(type: Type, rotation: Rotation) -> Array[Vector2i]:
	return _shapes[type][rotation]


## Bounding Box の一辺の長さを返す（I は 4、O は 2、それ以外は 3）。
static func get_box_size(type: Type) -> int:
	return _BOX_SIZES[type]


## 出現位置を返す。Bounding Box の左上に対応する Board 座標。
##
## 出現直後は Spawn Buffer に収まり、表示領域には出ていない状態になる。
## そこから Gravity で表示領域へ落ちてくる。
static func get_spawn_position(type: Type) -> Vector2i:
	# 形状が占める最下行が、表示領域のすぐ上（Buffer の最下段）に来るようにする。
	var lowest: int = _get_lowest_cell_y(type, SPAWN_ROTATION)
	return Vector2i(_SPAWN_X[type], Board.VISIBLE_TOP_Y - 1 - lowest)


## 種類を 1 文字で返す。
static func get_letter(type: Type) -> String:
	return LETTERS[type]


## 1 文字から種類を返す。該当しない場合は -1。
static func from_letter(letter: String) -> int:
	return LETTERS.find(letter.to_upper())


## 全種類を定義順（I J L O S T Z）で返す。
static func get_all_types() -> Array[int]:
	var types: Array[int] = []
	for type in range(TYPE_COUNT):
		types.append(type)
	return types


static func _get_lowest_cell_y(type: Type, rotation: Rotation) -> int:
	var lowest: int = 0
	for cell in get_cells(type, rotation):
		lowest = maxi(lowest, cell.y)
	return lowest


static func _build_shapes() -> Array[Array]:
	# 各行は SPAWN / RIGHT / TWO / LEFT の順。図は Bounding Box をそのまま表す。
	return [
		# I: 4×4
		#  ....      ..#.      ....      .#..
		#  ####      ..#.      ....      .#..
		#  ....      ..#.      ####      .#..
		#  ....      ..#.      ....      .#..
		_rotations(
			[[0, 1], [1, 1], [2, 1], [3, 1]],
			[[2, 0], [2, 1], [2, 2], [2, 3]],
			[[0, 2], [1, 2], [2, 2], [3, 2]],
			[[1, 0], [1, 1], [1, 2], [1, 3]]
		),
		# J: 3×3
		#  #..       .##       ...       .#.
		#  ###       .#.       ###       .#.
		#  ...       .#.       ..#       ##.
		_rotations(
			[[0, 0], [0, 1], [1, 1], [2, 1]],
			[[1, 0], [2, 0], [1, 1], [1, 2]],
			[[0, 1], [1, 1], [2, 1], [2, 2]],
			[[1, 0], [1, 1], [0, 2], [1, 2]]
		),
		# L: 3×3
		#  ..#       .#.       ...       ##.
		#  ###       .#.       ###       .#.
		#  ...       .##       #..       .#.
		_rotations(
			[[2, 0], [0, 1], [1, 1], [2, 1]],
			[[1, 0], [1, 1], [1, 2], [2, 2]],
			[[0, 1], [1, 1], [2, 1], [0, 2]],
			[[0, 0], [1, 0], [1, 1], [1, 2]]
		),
		# O: 2×2（回転しても形が変わらない）
		#  ##        ##        ##        ##
		#  ##        ##        ##        ##
		_rotations(
			[[0, 0], [1, 0], [0, 1], [1, 1]],
			[[0, 0], [1, 0], [0, 1], [1, 1]],
			[[0, 0], [1, 0], [0, 1], [1, 1]],
			[[0, 0], [1, 0], [0, 1], [1, 1]]
		),
		# S: 3×3
		#  .##       .#.       ...       #..
		#  ##.       .##       .##       ##.
		#  ...       ..#       ##.       .#.
		_rotations(
			[[1, 0], [2, 0], [0, 1], [1, 1]],
			[[1, 0], [1, 1], [2, 1], [2, 2]],
			[[1, 1], [2, 1], [0, 2], [1, 2]],
			[[0, 0], [0, 1], [1, 1], [1, 2]]
		),
		# T: 3×3
		#  .#.       .#.       ...       .#.
		#  ###       .##       ###       ##.
		#  ...       .#.       .#.       .#.
		_rotations(
			[[1, 0], [0, 1], [1, 1], [2, 1]],
			[[1, 0], [1, 1], [2, 1], [1, 2]],
			[[0, 1], [1, 1], [2, 1], [1, 2]],
			[[1, 0], [0, 1], [1, 1], [1, 2]]
		),
		# Z: 3×3
		#  ##.       ..#       ...       .#.
		#  .##       .##       ##.       ##.
		#  ...       .#.       .##       #..
		_rotations(
			[[0, 0], [1, 0], [1, 1], [2, 1]],
			[[2, 0], [1, 1], [2, 1], [1, 2]],
			[[0, 1], [1, 1], [1, 2], [2, 2]],
			[[1, 0], [0, 1], [1, 1], [0, 2]]
		),
	]


static func _rotations(spawn: Array, right: Array, two: Array, left: Array) -> Array[Array]:
	var rotations: Array[Array] = []
	for cells in [spawn, right, two, left]:
		rotations.append(_to_offsets(cells))
	return rotations


static func _to_offsets(cells: Array) -> Array[Vector2i]:
	var offsets: Array[Vector2i] = []
	for cell in cells:
		offsets.append(Vector2i(cell[0], cell[1]))
	return offsets
