class_name KickTable
extends Resource

## Wall Kick のオフセット表（要件定義 §25）。
##
## 回転の「元の状態 → 先の状態」ごとに、試す平行移動のオフセットを順番に持つ。
## 回転系を差し替えられるよう、表の中身はコードではなくこの Resource のデータ。
## I Piece とその他で別々の表を用意できる（要件定義 §25）。
##
## オフセットは Board の座標系（[code]y[/code] は下が正）。公開されている SRS の
## 表は [code]y[/code] が上が正なので、[method SrsKickTables] で符号を反転している。
##
## Resource なので `.tres` として保存・差し替えができる。ただし Game Core は
## FileSystem を知らないため（要件定義 §17）、読み込みは上位層の責務。

## 表の名前。ログとデバッグのため。
@export var table_name: String = ""

## [code]from * Piece.ROTATION_COUNT + to[/code] で引く、オフセットの並び。
##
## 同じ回転状態同士（from == to）は使わないので空でよい。
@export var offsets_by_transition: Array[PackedVector2Array] = []


## 指定した回転遷移で試すオフセットを順に返す。
##
## 定義がない遷移では「移動なし」だけを返し、Kick なしの回転として扱う。
func get_offsets(from_rotation: int, to_rotation: int) -> PackedVector2Array:
	var index: int = from_rotation * Piece.ROTATION_COUNT + to_rotation
	if index < 0 or index >= offsets_by_transition.size():
		return PackedVector2Array([Vector2.ZERO])

	var offsets: PackedVector2Array = offsets_by_transition[index]
	if offsets.is_empty():
		return PackedVector2Array([Vector2.ZERO])
	return offsets


## 90 度回転の 8 遷移がすべて定義されているかを返す。表を差し替えたときの検証に使う。
##
## 180 度回転（0↔2 / R↔L）は現在の回転操作に存在しないため、対象にしない。
func has_all_quarter_turns() -> bool:
	for from_rotation in range(Piece.ROTATION_COUNT):
		for step in [1, -1]:
			var to_rotation: int = posmod(from_rotation + step, Piece.ROTATION_COUNT)
			var index: int = from_rotation * Piece.ROTATION_COUNT + to_rotation
			if index >= offsets_by_transition.size():
				return false
			if offsets_by_transition[index].is_empty():
				return false
	return true
