class_name BoardPalette
extends Resource

## 盤面の配色（要件定義 §88 / §92）。
##
## 色をコードへ固定せず、この Resource のデータで持つ。差し替えれば見た目だけ
## 変えられる（`assets/themes/board_palette.tres`）。
##
## Piece の色は [enum Piece.Type] の並び（I / J / L / O / S / T / Z）。
## Garbage は [constant GarbageQueue.GARBAGE_CELL] に対応する。

## Piece の種類ごとの色。
@export var piece_colors: PackedColorArray = PackedColorArray(
	[
		Color("#3dd6f5"),  # I
		Color("#3f6fd8"),  # J
		Color("#f59f3d"),  # L
		Color("#f5e03d"),  # O
		Color("#4fd865"),  # S
		Color("#b45cf0"),  # T
		Color("#f04f5c"),  # Z
	]
)

## Garbage の色。
@export var garbage_color: Color = Color("#7a7f8c")

## 空きマスの色。
@export var empty_color: Color = Color("#161a22")

## 盤面の枠線の色。
@export var grid_color: Color = Color("#232936")

## Ghost の不透明度（要件定義 §88）。
@export_range(0.0, 1.0, 0.05) var ghost_alpha: float = 0.35

## Danger State ごとの縁の色（要件定義 §92）。
##
## 並びは [enum DangerLevel.Level]（SAFE / WARNING / DANGER / CRITICAL）。
@export var danger_colors: PackedColorArray = PackedColorArray(
	[
		Color("#00000000"),  # SAFE: 出さない
		Color("#f5e03d80"),  # WARNING
		Color("#f59f3dc0"),  # DANGER
		Color("#f04f5cff"),  # CRITICAL
	]
)

## Incoming Garbage の目盛りの色。
@export var incoming_color: Color = Color("#f04f5c")

## Incoming Garbage の目盛りの下地の色。
@export var incoming_background_color: Color = Color("#2a2f3a")


## 既定の配色を作る。
static func create_default() -> BoardPalette:
	return BoardPalette.new()


## セルの値に対応する色を返す。
##
## [param value] は [constant Board.EMPTY] か [enum Piece.Type] か
## [constant GarbageQueue.GARBAGE_CELL]。
func get_cell_color(value: int) -> Color:
	if value == Board.EMPTY:
		return empty_color
	if value == GarbageQueue.GARBAGE_CELL:
		return garbage_color
	if value < 0 or value >= piece_colors.size():
		return garbage_color
	return piece_colors[value]


## Ghost の色を返す（その Piece の色を薄くしたもの）。
func get_ghost_color(piece_type: int) -> Color:
	var color: Color = get_cell_color(piece_type)
	color.a = ghost_alpha
	return color


## Danger State の縁の色を返す（要件定義 §92）。
func get_danger_color(level: DangerLevel.Level) -> Color:
	var index: int = clampi(int(level), 0, danger_colors.size() - 1)
	return danger_colors[index]
