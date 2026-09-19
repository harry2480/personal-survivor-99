class_name HoldSlot
extends RefCounted

## Hold 枠（要件定義 §24）。
##
## 枠は 1 つで、1 Piece の操作中に 1 回だけ使える。Lock 後に再び使えるようになる。
## Hold から戻ってきた Piece を初期 Rotation / Spawn Position に戻すのは呼び出し側
## だが、[method swap] が「次に出すべき Piece」を返すので判断は要らない。

## 空であることを表す値。[enum Piece.Type] は 0 以上なので負値を使う。
const EMPTY: int = -1

var _held_type: int = EMPTY
var _used_for_current_piece: bool = false


## Hold 枠が空かを返す。
func is_empty() -> bool:
	return _held_type == EMPTY


## Hold している Piece を返す。空なら [constant EMPTY]。
func get_held_type() -> int:
	return _held_type


## いま Hold を使えるかを返す。
func can_hold() -> bool:
	return not _used_for_current_piece


## Hold を使う。
##
## 空だった場合は [param current_type] を預かり、[constant EMPTY] を返す。
## 呼び出し側は NEXT から次の Piece を出す。
## [br]
## 既に預かっていた場合は入れ替え、出すべき Piece の種類を返す。
## [br]
## この Piece で既に使っていた場合は何もせず [constant EMPTY] を返す。
## 使えるかどうかは [method can_hold] で先に確かめる。
func swap(current_type: int) -> int:
	if not can_hold():
		return EMPTY

	_used_for_current_piece = true

	var released: int = _held_type
	_held_type = current_type
	return released


## Piece が Lock されたときに呼ぶ。次の Piece で Hold が再び使えるようになる。
func on_piece_locked() -> void:
	_used_for_current_piece = false


## Hold 枠と使用状態を初期化する。
func clear() -> void:
	_held_type = EMPTY
	_used_for_current_piece = false
