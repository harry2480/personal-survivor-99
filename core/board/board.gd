class_name Board
extends RefCounted

## 落ちものパズルの盤面。
##
## 表示領域と、Spawn Buffer を含む内部領域を分けて持つ（要件定義 §20）。
## Piece は内部領域の上部に出現し、そこから表示領域へ落ちてくる。
##
## 座標系は左上原点。[code]x[/code] は 0 が左端、[code]y[/code] は 0 が内部領域の
## 最上段で、下へ進むほど増える。表示領域は内部領域の下 [constant VISIBLE_HEIGHT] 行。
##
## Game Core Layer に属するため、UI / Audio / Input / Scene / FileSystem に依存しない
## （要件定義 §17）。乱数も時刻も持たず、同じ操作列からは必ず同じ状態になる。

## 盤面の幅（列数）。
const WIDTH: int = 10

## 表示領域の高さ。
const VISIBLE_HEIGHT: int = 20

## Spawn Buffer を含む内部領域の高さ。
const TOTAL_HEIGHT: int = 40

## Spawn Buffer の高さ。表示領域より上にある行数。
const BUFFER_HEIGHT: int = TOTAL_HEIGHT - VISIBLE_HEIGHT

## 表示領域の先頭行（この行から下が表示される）。
const VISIBLE_TOP_Y: int = BUFFER_HEIGHT

## 空セルを表す値。Piece の種類 ID（0 以上）と区別するため負値にする。
const EMPTY: int = -1

## 文字列表現で空セルを表す文字。
const EMPTY_CHAR: String = "."

## 文字列表現で埋まったセルを表す既定の文字。
const FILLED_CHAR: String = "#"

var _cells: PackedInt32Array = PackedInt32Array()


func _init() -> void:
	_cells.resize(WIDTH * TOTAL_HEIGHT)
	clear()


## 盤面全体を空にする。
func clear() -> void:
	_cells.fill(EMPTY)


## 座標が内部領域の中にあるかを返す。
func is_inside(x: int, y: int) -> bool:
	return x >= 0 and x < WIDTH and y >= 0 and y < TOTAL_HEIGHT


## 行が表示領域に含まれるかを返す。
func is_visible_row(y: int) -> bool:
	return y >= VISIBLE_TOP_Y and y < TOTAL_HEIGHT


## セルの値を返す。範囲外は [constant EMPTY] を返し、失敗させない。
##
## 範囲外を「空」として扱うと、上端より上から落ちてくる Piece の判定が単純になる。
## 壁と床の判定は [method is_inside] で行う。
func get_cell(x: int, y: int) -> int:
	if not is_inside(x, y):
		return EMPTY
	return _cells[y * WIDTH + x]


## セルへ値を書き込む。範囲外なら何もせず false を返す。
func set_cell(x: int, y: int, value: int) -> bool:
	if not is_inside(x, y):
		return false
	_cells[y * WIDTH + x] = value
	return true


## セルが空かを返す。範囲外は空として扱う（[method get_cell] と同じ方針）。
func is_cell_empty(x: int, y: int) -> bool:
	return get_cell(x, y) == EMPTY


## 行がすべて埋まっているかを返す。範囲外の行は false。
func is_row_filled(y: int) -> bool:
	if y < 0 or y >= TOTAL_HEIGHT:
		return false
	var row_start: int = y * WIDTH
	for x in range(WIDTH):
		if _cells[row_start + x] == EMPTY:
			return false
	return true


## 行がすべて空かを返す。範囲外の行は true（何も置かれていないため）。
func is_row_empty(y: int) -> bool:
	if y < 0 or y >= TOTAL_HEIGHT:
		return true
	var row_start: int = y * WIDTH
	for x in range(WIDTH):
		if _cells[row_start + x] != EMPTY:
			return false
	return true


## 埋まっている行の y を、上から順（昇順）に返す。
func get_filled_rows() -> Array[int]:
	var rows: Array[int] = []
	for y in range(TOTAL_HEIGHT):
		if is_row_filled(y):
			rows.append(y)
	return rows


## 指定した行を削除し、上の行を下へ詰める。削除した行数を返す。
##
## 引数の順序は問わない。範囲外の y と重複した y は無視する。
func clear_rows(rows: Array[int]) -> int:
	var removed: Dictionary = {}
	for y in rows:
		if y >= 0 and y < TOTAL_HEIGHT:
			removed[y] = true
	if removed.is_empty():
		return 0

	# 下から順に、削除対象でない行だけを詰め直す。
	var next: PackedInt32Array = PackedInt32Array()
	next.resize(WIDTH * TOTAL_HEIGHT)
	next.fill(EMPTY)

	var write_y: int = TOTAL_HEIGHT - 1
	for read_y in range(TOTAL_HEIGHT - 1, -1, -1):
		if removed.has(read_y):
			continue
		for x in range(WIDTH):
			next[write_y * WIDTH + x] = _cells[read_y * WIDTH + x]
		write_y -= 1

	_cells = next
	return removed.size()


## 埋まっている行をすべて削除して上詰めし、削除した行の y を昇順で返す。
func clear_filled_rows() -> Array[int]:
	var rows: Array[int] = get_filled_rows()
	if not rows.is_empty():
		clear_rows(rows)
	return rows


## 文字列で盤面を組み立てる。テストで期待する形を読みやすく書くための入口。
##
## [param rows] の先頭要素が [param top_y] の行になる。[constant EMPTY_CHAR] は空セル、
## それ以外の文字は [param value] を書き込む。範囲外にはみ出した分は無視する。
func fill_from_strings(rows: PackedStringArray, top_y: int, value: int = 0) -> void:
	for row_index in range(rows.size()):
		var y: int = top_y + row_index
		var row: String = rows[row_index]
		for x in range(mini(row.length(), WIDTH)):
			var is_empty: bool = row[x] == EMPTY_CHAR
			set_cell(x, y, EMPTY if is_empty else value)


## 盤面を文字列として取り出す。[method fill_from_strings] と対になる。
func to_strings(top_y: int, row_count: int) -> PackedStringArray:
	var rows: PackedStringArray = PackedStringArray()
	for row_index in range(row_count):
		var y: int = top_y + row_index
		var row: String = ""
		for x in range(WIDTH):
			row += EMPTY_CHAR if is_cell_empty(x, y) else FILLED_CHAR
		rows.append(row)
	return rows


## 表示領域だけを文字列として取り出す。
func visible_to_strings() -> PackedStringArray:
	return to_strings(VISIBLE_TOP_Y, VISIBLE_HEIGHT)
