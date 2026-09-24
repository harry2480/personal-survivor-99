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

## Clear 種別ごとの Base Attack（index は [enum LineClear.Type]）。
@export var line_attack_table: PackedInt32Array = PackedInt32Array([0, 0, 1, 2, 4])

## T-Spin の Clear 種別ごとの Attack（index は [enum LineClear.Type]）。
##
## T-Spin が成立したときは [member line_attack_table] の代わりにこちらを使う。
@export var t_spin_attack_table: PackedInt32Array = PackedInt32Array([0, 2, 4, 6, 6])

## T-Spin Mini の Clear 種別ごとの Attack（index は [enum LineClear.Type]）。
@export var t_spin_mini_attack_table: PackedInt32Array = PackedInt32Array([0, 0, 1, 2, 4])

## Back-to-Back が成立しているときの加算値。
@export_range(0, 10, 1, "or_greater") var b2b_bonus: int = 1

## Perfect Clear の Clear 種別ごとの Attack（index は [enum LineClear.Type]）。
@export var perfect_clear_attack_table: PackedInt32Array = PackedInt32Array([0, 10, 10, 10, 10])

## Perfect Clear の Attack を、通常の Attack に加算するか置き換えるか。
##
## true なら置き換える（Perfect Clear の値だけを使う）。
@export var perfect_clear_replaces_attack: bool = true

## Attack が Garbage として相手の盤面へ届くまでの遅延（秒。要件定義 §41）。
@export_range(0.0, 10.0, 0.05, "or_greater") var garbage_delay_sec: float = 1.0

## Garbage Line の Hole の開け方（[enum GarbageHoleGenerator.Mode]）。
@export var garbage_hole_mode: int = GarbageHoleGenerator.Mode.SAME_COLUMN_PER_EVENT

## KO を攻撃者の手柄とみなす時間（秒。要件定義 §56）。
##
## Garbage が適用されてからこの時間以内に Top Out したら、その攻撃者の KO とする。
@export_range(0.0, 30.0, 0.5, "or_greater") var ko_attribution_window_sec: float = 5.0

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


## Clear 種別に対応する Base Attack を返す。
##
## [param t_spin] に応じて参照する表を切り替える。
func get_base_attack(clear_type: LineClear.Type, t_spin: TSpinDetector.Result) -> int:
	match t_spin:
		TSpinDetector.Result.FULL:
			return _lookup(t_spin_attack_table, clear_type)
		TSpinDetector.Result.MINI:
			return _lookup(t_spin_mini_attack_table, clear_type)
	return _lookup(line_attack_table, clear_type)


## Perfect Clear の Attack を返す。
func get_perfect_clear_attack(clear_type: LineClear.Type) -> int:
	return _lookup(perfect_clear_attack_table, clear_type)


## Combo 段数に対応する Attack 加算値を返す。
##
## [param combo_count] は連続 Line Clear 数（1 回目の Clear なら 1）。
func get_combo_attack(combo_count: int) -> int:
	if combo_count <= 0 or combo_attack_table.is_empty():
		return 0

	var index: int = mini(combo_count - 1, combo_attack_table.size() - 1)
	return combo_attack_table[index]


# 表から Clear 種別の値を引く。表が短い場合は 0 を返す。
static func _lookup(table: PackedInt32Array, clear_type: LineClear.Type) -> int:
	if clear_type < 0 or clear_type >= table.size():
		return 0
	return table[clear_type]
