class_name LineClear
extends RefCounted

## Line Clear の判定と実行（要件定義 §32）。
##
## 消えた行数から種別（Single / Double / Triple / Quad）を決める。UI 上の表示名称は
## 独自名称に変更できるが、それは Presentation の責務（要件定義 §32）。
##
## 状態を持たないので全て static。

## Line Clear の種別。
enum Type { NONE, SINGLE, DOUBLE, TRIPLE, QUAD }

## 1 度に消せる最大行数。Piece が 4 マスなので 4 行を超えることはない。
const MAX_LINES: int = 4

# 行数から種別を引く表。MAX_LINES を超える行数は QUAD として扱う。
const _TYPE_BY_LINE_COUNT: Array[Type] = [
	Type.NONE, Type.SINGLE, Type.DOUBLE, Type.TRIPLE, Type.QUAD
]


## 消えた行数に対応する種別を返す。
static func get_type(line_count: int) -> Type:
	if line_count <= 0:
		return Type.NONE
	if line_count >= MAX_LINES:
		return Type.QUAD
	return _TYPE_BY_LINE_COUNT[line_count]


## 種別の名前を返す。ログとテスト用で、UI の表示名称ではない。
static func get_type_name(type: Type) -> String:
	return Type.keys()[type]


## 埋まっている行を消して上詰めし、結果を返す。
static func execute(board: Board) -> LineClearResult:
	var cleared_rows: Array[int] = board.clear_filled_rows()
	return LineClearResult.create(cleared_rows)


## 消える行を、消さずに調べる。
static func find_filled_rows(board: Board) -> Array[int]:
	return board.get_filled_rows()
