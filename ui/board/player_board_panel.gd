class_name PlayerBoardPanel
extends HBoxContainer

## 自分の盤面まわりのまとまり（要件定義 §87 / §88）。
##
## [codeblock]
## HOLD    PLAYER BOARD    NEXT
## [/codeblock]
##
## [PlayerBoardView] と Hold / NEXT の [PiecePreview] を並べ、更新をまとめて
## 面倒を見る。Game Core の状態は読むだけ（要件定義 §19）。

## NEXT に出す数（要件定義 §88 / #48 の完了条件は最低 5 個）。
const NEXT_COUNT: int = 5

var _board_view: PlayerBoardView
var _hold_view: PiecePreview
var _next_view: PiecePreview
var _session: PuzzleSession = null


func _ready() -> void:
	if _board_view == null:
		build()


func _process(_delta: float) -> void:
	refresh()


## 中身を組み立てる。
func build() -> void:
	_hold_view = PiecePreview.new()
	_board_view = PlayerBoardView.new()
	_next_view = PiecePreview.new()

	# 並びは要件定義 §87 のとおり（HOLD / BOARD / NEXT）。
	add_child(_wrap("HOLD", _hold_view))
	add_child(_board_view)
	add_child(_wrap("NEXT", _next_view))


## 表示する Game Core と Battle の状態を結び付ける。
func bind(session: PuzzleSession, player: BattlePlayerState = null) -> void:
	_session = session
	_board_view.bind(session, player)
	refresh()


## 結び付けを解く。
func unbind() -> void:
	_session = null
	_board_view.unbind()


## 配色を差し替える。
func set_palette(palette: BoardPalette) -> void:
	_board_view.set_palette(palette)
	_hold_view.set_palette(palette)
	_next_view.set_palette(palette)


## 盤面の表示を返す。
func get_board_view() -> PlayerBoardView:
	return _board_view


## Hold の表示を返す。
func get_hold_view() -> PiecePreview:
	return _hold_view


## NEXT の表示を返す。
func get_next_view() -> PiecePreview:
	return _next_view


## Hold と NEXT を読み直す。
func refresh() -> void:
	if _session == null:
		return

	var hold: HoldSlot = _session.get_hold_slot()
	var held: Array[int] = []
	if not hold.is_empty():
		held.append(hold.get_held_type())
	_hold_view.set_types(held, not hold.can_hold())
	_next_view.set_types(_session.get_next_types(NEXT_COUNT))


func _wrap(title: String, view: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = title
	box.add_child(label)
	box.add_child(view)
	return box
