class_name SrsKickTables
extends RefCounted

## 標準 SRS の Wall Kick 表（要件定義 §25）。
##
## 公開されている SRS の表をそのまま転記できるよう、以下のリテラルは
## **classic 記法（[code]y[/code] が上が正）** で書いている。[method _kicks] が
## Board の座標系（[code]y[/code] が下が正）へ符号を反転する。
##
## I Piece とその他で表が分かれている（要件定義 §25）。180 度回転は現在の回転操作に
## 存在しないため定義しない。
##
## 回転系を変えたい場合は、ここを書き換えるのではなく [KickTable] を差し替える。

# 回転状態の index。表を読みやすくするための別名。
const _SPAWN: int = Piece.Rotation.SPAWN
const _RIGHT: int = Piece.Rotation.RIGHT
const _TWO: int = Piece.Rotation.TWO
const _LEFT: int = Piece.Rotation.LEFT


## J / L / S / T / Z 用の標準 SRS 表を作る。
static func create_standard() -> KickTable:
	var table := KickTable.new()
	table.table_name = "SRS Standard (JLSTZ)"
	table.offsets_by_transition = _build_transitions(
		{
			[_SPAWN, _RIGHT]: [[0, 0], [-1, 0], [-1, 1], [0, -2], [-1, -2]],
			[_RIGHT, _SPAWN]: [[0, 0], [1, 0], [1, -1], [0, 2], [1, 2]],
			[_RIGHT, _TWO]: [[0, 0], [1, 0], [1, -1], [0, 2], [1, 2]],
			[_TWO, _RIGHT]: [[0, 0], [-1, 0], [-1, 1], [0, -2], [-1, -2]],
			[_TWO, _LEFT]: [[0, 0], [1, 0], [1, 1], [0, -2], [1, -2]],
			[_LEFT, _TWO]: [[0, 0], [-1, 0], [-1, -1], [0, 2], [-1, 2]],
			[_LEFT, _SPAWN]: [[0, 0], [-1, 0], [-1, -1], [0, 2], [-1, 2]],
			[_SPAWN, _LEFT]: [[0, 0], [1, 0], [1, 1], [0, -2], [1, -2]],
		}
	)
	return table


## I 用の標準 SRS 表を作る。
static func create_i() -> KickTable:
	var table := KickTable.new()
	table.table_name = "SRS I"
	table.offsets_by_transition = _build_transitions(
		{
			[_SPAWN, _RIGHT]: [[0, 0], [-2, 0], [1, 0], [-2, -1], [1, 2]],
			[_RIGHT, _SPAWN]: [[0, 0], [2, 0], [-1, 0], [2, 1], [-1, -2]],
			[_RIGHT, _TWO]: [[0, 0], [-1, 0], [2, 0], [-1, 2], [2, -1]],
			[_TWO, _RIGHT]: [[0, 0], [1, 0], [-2, 0], [1, -2], [-2, 1]],
			[_TWO, _LEFT]: [[0, 0], [2, 0], [-1, 0], [2, 1], [-1, -2]],
			[_LEFT, _TWO]: [[0, 0], [-2, 0], [1, 0], [-2, -1], [1, 2]],
			[_LEFT, _SPAWN]: [[0, 0], [1, 0], [-2, 0], [1, -2], [-2, 1]],
			[_SPAWN, _LEFT]: [[0, 0], [-1, 0], [2, 0], [-1, 2], [2, -1]],
		}
	)
	return table


## Piece の種類に応じた標準 SRS 表を返す。
static func create_for(type: Piece.Type) -> KickTable:
	return create_i() if type == Piece.Type.I else create_standard()


static func _build_transitions(by_transition: Dictionary) -> Array[PackedVector2Array]:
	var transitions: Array[PackedVector2Array] = []
	transitions.resize(Piece.ROTATION_COUNT * Piece.ROTATION_COUNT)
	for index in range(transitions.size()):
		transitions[index] = PackedVector2Array()

	for transition in by_transition:
		var index: int = transition[0] * Piece.ROTATION_COUNT + transition[1]
		transitions[index] = _kicks(by_transition[transition])

	return transitions


# classic 記法（y が上が正）で書かれたオフセット列を、Board の座標系へ変換する。
static func _kicks(classic_offsets: Array) -> PackedVector2Array:
	var offsets: PackedVector2Array = PackedVector2Array()
	for offset in classic_offsets:
		offsets.append(Vector2(offset[0], -offset[1]))
	return offsets
