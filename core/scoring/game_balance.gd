class_name GameBalance
extends Resource

## Attack に関わるバランスデータ（要件定義 §39 Game Balance Data）。
##
## Combo Table、Back-to-Back の対象 Clear、Attack 値をコードへ固定せず、この
## Resource のデータとして持つ（要件定義 §38）。`config/game_balance.tres` として
## 保存し、調整では値だけを差し替える。
##
## Game Core は FileSystem を知らないため（要件定義 §17）、`.tres` の読み込みは
## 上位層の責務。Game Core へは組み立て済みの [GameBalance] を注入する。

## Back-to-Back の対象となる Clear 種別（[enum LineClear.Type] の値）。
##
## 既定は Quad のみ。T-Spin は [member b2b_includes_t_spin] で扱う。
@export var b2b_clear_types: Array[int] = [LineClear.Type.QUAD]

## T-Spin を Back-to-Back の対象に含めるか（T-Spin 判定は #29）。
@export var b2b_includes_t_spin: bool = true

## Combo 段数ごとの Attack 加算値。
##
## index は「連続 Line Clear 数 - 1」。1 回目の Clear は Combo 0 として index 0 を見る。
## 表の長さを超える Combo は最後の値を使う。
@export
var combo_attack_table: PackedInt32Array = PackedInt32Array([0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 4, 5])


## 既定値の [GameBalance] を作る。
static func create_default() -> GameBalance:
	return GameBalance.new()


## その Clear が Back-to-Back の対象かを返す。
##
## [param is_t_spin] は T-Spin 判定（#29）の結果。Phase 2 の途中までは false で呼ぶ。
func is_b2b_clear(clear_type: LineClear.Type, is_t_spin: bool = false) -> bool:
	if clear_type == LineClear.Type.NONE:
		return false
	if is_t_spin and b2b_includes_t_spin:
		return true
	return clear_type in b2b_clear_types


## Combo 段数に対応する Attack 加算値を返す。
##
## [param combo_count] は連続 Line Clear 数（1 回目の Clear なら 1）。
func get_combo_attack(combo_count: int) -> int:
	if combo_count <= 0 or combo_attack_table.is_empty():
		return 0

	var index: int = mini(combo_count - 1, combo_attack_table.size() - 1)
	return combo_attack_table[index]
