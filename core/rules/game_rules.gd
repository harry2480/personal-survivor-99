class_name GameRules
extends Resource

## 操作感を決めるルール値（要件定義 §39 Game Balance Data）。
##
## Gravity / Lock Delay / DAS / ARR / Soft Drop Speed をコードへ固定せず、この
## Resource のデータとして持つ（要件定義 §38）。`config/game_rules.tres` として
## 保存し、Phase 10 の調整で値だけを差し替えられるようにする。
##
## Game Core は FileSystem を知らないため（要件定義 §17）、`.tres` の読み込みは
## 上位層の責務。Game Core へは組み立て済みの [GameRules] を注入する。
##
## 時間はすべて秒で持つ。フレーム数で持つと FPS 依存になるため（要件定義 §29）。

## 累積値を比較するときの許容差。
##
## delta を何度も足すと浮動小数の誤差が溜まり、ちょうど境界で 1 回ぶんずれる。
## 60fps の delta を 30 回足すと 0.5 秒にわずかに届かない、といった形で現れる。
## FPS が変わっても同じタイミングで揃うよう、比較時にこの幅を足す。
## 秒にもマス数にも使う（どちらも 1 に対して十分小さい）。
const ACCUMULATION_EPSILON: float = 0.000001

## 1 秒あたりに落下するマス数。
@export_range(0.0, 60.0, 0.01, "or_greater") var gravity_cells_per_second: float = 1.0

## 接地してから Lock するまでの時間（秒）。
@export_range(0.0, 5.0, 0.01, "or_greater") var lock_delay_sec: float = 0.5

## 左右移動で Lock Delay を Reset するか。
@export var lock_delay_reset_on_move: bool = true

## 回転で Lock Delay を Reset するか。
@export var lock_delay_reset_on_rotate: bool = true

## 1 つの Piece で Lock Delay を Reset できる回数の上限。
##
## 上限に達した後は、移動しても回転しても Lock が延期されない。
## 0 にすると Reset なし、負値にすると無制限。
@export_range(-1, 60, 1, "or_greater") var lock_delay_reset_limit: int = 15


## 既定値の [GameRules] を作る。
##
## Phase 1 時点の暫定値。実際の調整は Phase 10 で行う（[member gravity_cells_per_second]
## などの値そのものは `config/game_rules.tres` で上書きする）。
static func create_default() -> GameRules:
	return GameRules.new()


## Reset 回数に上限があるかを返す。
func has_reset_limit() -> bool:
	return lock_delay_reset_limit >= 0
