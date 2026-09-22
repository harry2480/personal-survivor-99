class_name DropSystem
extends RefCounted

## 落下の制御（Gravity / Soft Drop / Hard Drop。要件定義 §27 / §28 / §29）。
##
## 通常の Gravity と Soft Drop 中の加速を 1 箇所で扱う。Soft Drop の倍率は
## [member GameRules.soft_drop_multiplier] から来るので、コードに固定しない。
##
## 実時間は見ない。delta は外から与えられる（要件定義 §17）。

var _rules: GameRules
var _gravity: Gravity
var _soft_dropping: bool = false


func _init(rules: GameRules = null) -> void:
	_rules = rules if rules != null else GameRules.create_default()
	_gravity = Gravity.new(_rules.gravity_cells_per_second)


## Soft Drop の入力状態を設定する。
func set_soft_dropping(active: bool) -> void:
	if active == _soft_dropping:
		return

	_soft_dropping = active
	_gravity.set_speed(get_current_speed())


## Soft Drop 中かを返す。
func is_soft_dropping() -> bool:
	return _soft_dropping


## 現在の落下速度（1 秒あたりのマス数）を返す。
func get_current_speed() -> float:
	return _rules.get_soft_drop_speed() if _soft_dropping else _rules.gravity_cells_per_second


## 時間を進め、落とすべきマス数を返す。
func advance(delta_sec: float) -> int:
	return _gravity.advance(delta_sec)


## 新しい Piece の操作を始めるときに呼ぶ。溜まっている端数を捨てる。
func start_new_piece() -> void:
	_gravity.reset()


## ルールが変わったとき（設定変更など）に落下速度を反映する。
func refresh_speed() -> void:
	_gravity.set_speed(get_current_speed())


## Hard Drop 直後に Lock するかを返す（要件定義 §28）。
func locks_after_hard_drop() -> bool:
	return _rules.hard_drop_locks_immediately


## Piece を着地可能位置まで即座に移動させ、落ちたマス数を返す。
##
## Board は変更しない。Lock するかどうかは [method locks_after_hard_drop] を見て
## 呼び出し側が決める。
static func hard_drop(board: Board, piece: ActivePiece) -> int:
	var landing: Vector2i = GhostPiece.get_landing_position(
		board, piece.type, piece.rotation, piece.position
	)
	var distance: int = landing.y - piece.position.y
	piece.position = landing
	return distance
