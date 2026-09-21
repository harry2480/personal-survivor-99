class_name PiecePreview
extends Control

## Hold と NEXT の表示（要件定義 §88 / §90）。
##
## Piece を並べて描くだけの部品。Hold は 1 個、NEXT は
## [constant NextQueue.MINIMUM_VISIBLE] 個以上を並べる（#48 の完了条件）。
##
## Game Core の状態は読むだけで、書き換えない（要件定義 §19）。

## 1 マスの大きさ（ピクセル）。
const CELL_SIZE: int = 14

## 1 個ぶんの高さ（ピクセル）。
const SLOT_HEIGHT: int = CELL_SIZE * 3

## Piece を収める枠の幅（マス数）。
const SLOT_WIDTH_CELLS: int = 4

var _palette: BoardPalette = BoardPalette.create_default()
var _types: Array[int] = []
var _dimmed: bool = false


func _ready() -> void:
	_update_minimum_size()


## 配色を差し替える。
func set_palette(palette: BoardPalette) -> void:
	if palette == null:
		return
	_palette = palette
	queue_redraw()


## 並べる Piece を差し替える。
##
## [param dimmed] は「今は使えない」状態（Hold 済みなど）を薄く出すため。
func set_types(types: Array[int], dimmed: bool = false) -> void:
	_types.assign(types)
	_dimmed = dimmed
	_update_minimum_size()
	queue_redraw()


## 並べている Piece を返す。
func get_types() -> Array[int]:
	return _types


## 薄く出しているかを返す。
func is_dimmed() -> bool:
	return _dimmed


func _draw() -> void:
	for index in range(_types.size()):
		_draw_slot(index, _types[index])


func _draw_slot(index: int, type: int) -> void:
	var origin := Vector2(0.0, float(index * SLOT_HEIGHT))
	draw_rect(
		Rect2(origin, Vector2(float(SLOT_WIDTH_CELLS * CELL_SIZE), float(SLOT_HEIGHT))),
		_palette.empty_color
	)
	if type < 0:
		return

	var color: Color = _palette.get_cell_color(type)
	if _dimmed:
		color.a = _palette.ghost_alpha

	# Spawn 時の形をそのまま出す。中央に寄せるため、最小の座標を引く。
	var cells: Array[Vector2i] = Piece.get_cells(type, Piece.Rotation.SPAWN)
	var min_x: int = 9999
	var min_y: int = 9999
	for cell in cells:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)

	for cell in cells:
		draw_rect(
			Rect2(
				(
					origin
					+ Vector2(
						float((cell.x - min_x) * CELL_SIZE), float((cell.y - min_y) * CELL_SIZE)
					)
				),
				Vector2(float(CELL_SIZE), float(CELL_SIZE))
			),
			color
		)


func _update_minimum_size() -> void:
	custom_minimum_size = Vector2(
		float(SLOT_WIDTH_CELLS * CELL_SIZE), float(maxi(1, _types.size()) * SLOT_HEIGHT)
	)
