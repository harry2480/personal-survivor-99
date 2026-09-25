class_name CpuProfile
extends Resource

## CPU の挙動を決めるパラメータ（要件定義 §61 / §68）。
##
## 評価の重みと CPU の難易度パラメータをコードへ固定せず、この Resource の
## データとして持つ。`config/cpu_profiles.tres` として保存し、Strength からの
## 変換（#40）もこの形へ落とす。
##
## 評価の重みは **4 つの軸へ分離**してある（#38 の完了条件）。軸ごとの倍率を
## 動かせば、個別の重みを触らずに「穴に厳しい CPU」「表面をきれいに保つ CPU」
## といった性格を作れる。

## Profile の名前。
@export var profile_name: String = "Default"

# --- 探索のパラメータ（§62〜§64） -------------------------------------------

## 配置の質（要件定義 §62）。
##
## 1.0 で常に最良の候補、下げるほど上位候補から準ランダムに選ぶ。
@export_range(0.0, 1.0, 0.01) var placement_quality: float = 1.0

## 先読みで深く読む候補の数（Beam Width）。
##
## 到達できる配置は 40 前後あり、全部を深く読むと 1 手に数十 ms かかる
## （scripts/benchmark-cpu.sh の計測）。まず浅く並べ、上位だけを深く読む。
@export_range(1, 40, 1) var beam_width: int = 8

## NEXT を何手先まで見るか（要件定義 §64）。
##
## 0 で現在 Piece だけ。探索の深さは
## [constant PlacementSearch.MAX_SEARCH_DEPTH] で打ち切られる。
@export_range(0, 5, 1) var lookahead: int = 1

# --- 評価の軸（§61） --------------------------------------------------------

## 穴を避ける度合い。穴の数と深さに掛かる。
@export_range(0.0, 3.0, 0.05, "or_greater") var hole_avoidance: float = 1.0

## 表面をきれいに保つ度合い。凸凹・溝・切り替わり回数に掛かる。
@export_range(0.0, 3.0, 0.05, "or_greater") var surface_management: float = 1.0

## Garbage をさばく度合い。塞がれた Garbage 行に掛かる。
@export_range(0.0, 3.0, 0.05, "or_greater") var garbage_management: float = 1.0

## 危険な盤面から立て直す度合い。高さと危険度に掛かる。
@export_range(0.0, 3.0, 0.05, "or_greater") var recovery_ability: float = 1.0

# --- 個別の重み（§68） ------------------------------------------------------
# 符号は「評価値に足す向き」。悪い指標は負の重みにする。

## 各列の高さの合計に掛かる重み。
@export var weight_aggregate_height: float = -0.51

## 一番高い列に掛かる重み。
@export var weight_max_height: float = -0.3

## 穴の数に掛かる重み。
@export var weight_holes: float = -3.6

## 穴の深さに掛かる重み。
@export var weight_hole_depth: float = -0.4

## 表面の凸凹に掛かる重み。
@export var weight_bumpiness: float = -0.18

## 深い溝に掛かる重み。
@export var weight_wells: float = -0.3

## 行方向の切り替わり回数に掛かる重み。
@export var weight_row_transitions: float = -0.2

## 列方向の切り替わり回数に掛かる重み。
@export var weight_column_transitions: float = -0.3

## 揃った行に掛かる重み。唯一の正の重み。
@export var weight_completed_lines: float = 1.6

## 穴が塞がれた Garbage 行に掛かる重み。
@export var weight_blocked_garbage: float = -1.2

## 危険度に掛かる重み。
@export var weight_danger: float = -2.0


## 既定値の [CpuProfile] を作る。
static func create_default() -> CpuProfile:
	return CpuProfile.new()
