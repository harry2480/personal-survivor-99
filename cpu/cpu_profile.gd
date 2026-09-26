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

## Beam Width の上限。Machine（要件定義 §71）はここまで広げる。
const MAX_BEAM_WIDTH: int = 40

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
@export_range(1, MAX_BEAM_WIDTH, 1) var beam_width: int = 8

## NEXT を何手先まで見るか（要件定義 §64）。
##
## 0 で現在 Piece だけ。探索の深さは
## [constant PlacementSearch.MAX_SEARCH_DEPTH] で打ち切られる。
@export_range(0, 5, 1) var lookahead: int = 1

# --- 人間的な制約（§65〜§67） -----------------------------------------------

## この CPU の Strength。変換元の値を残しておく（要件定義 §59）。
@export_range(0.0, 200.0, 1.0, "or_greater") var strength: float = 50.0

## 反応遅延（秒。要件定義 §65）。Garbage 受信や Target 変更への反応が遅れる。
@export_range(0.0, 1.0, 0.005, "or_greater") var reaction_time_sec: float = 0.15

## 1 秒あたりに置く Piece 数（PPS。要件定義 §66）。
@export_range(0.1, 20.0, 0.1, "or_greater") var pieces_per_second: float = 2.5

## 意図しない配置が起きる確率（要件定義 §67）。
@export_range(0.0, 1.0, 0.001) var misdrop_rate: float = 0.05

# --- 技術と判断（§61 / §69） ------------------------------------------------

## 高度テクニックを狙う度合い（要件定義 §69）。
@export_range(0.0, 1.0, 0.01) var technique_usage: float = 0.3

## Garbage のさばき方の上手さ（相殺の狙い方・掘るタイミング）。
@export_range(0.0, 1.0, 0.01) var garbage_skill: float = 0.5

## Target の選び方の上手さ。
@export_range(0.0, 1.0, 0.01) var target_skill: float = 0.5

# --- 評価の軸（§61） --------------------------------------------------------

## 穴を避ける度合い。穴の数と深さに掛かる。
@export_range(0.0, 3.0, 0.05, "or_greater") var hole_avoidance: float = 1.0

## 表面をきれいに保つ度合い。凸凹・溝・切り替わり回数に掛かる。
@export_range(0.0, 3.0, 0.05, "or_greater") var surface_management: float = 1.0

## Garbage をさばく度合い。塞がれた Garbage 行に掛かる。
@export_range(0.0, 3.0, 0.05, "or_greater") var garbage_management: float = 1.0

## 危険な盤面から立て直す度合い。高さと危険度に掛かる。
@export_range(0.0, 3.0, 0.05, "or_greater") var recovery_ability: float = 1.0

# --- Lightweight の見積もり（§82） ------------------------------------------

## 1 秒あたりの Attack 行数の見積もりに掛ける係数（PPS × 腕前 × この値）。
@export_range(0.0, 2.0, 0.01, "or_greater") var attack_rate_factor: float = 0.25

## 1 秒あたりに捌ける Garbage 行数の見積もりに掛ける係数（PPS × Garbage Skill × この値）。
@export_range(0.0, 2.0, 0.01, "or_greater") var defense_rate_factor: float = 0.5

## 1 秒あたりに自分で掘れる行数に掛ける係数（腕前 × この値）。
##
## 平均して受ける Garbage（ほかの CPU の Attack）より遅くしておく。速いと受けた
## Garbage をいくらでも掘り返せてしまい、CPU 同士の Battle で誰も脱落しない（#44）。
@export_range(0.0, 2.0, 0.01, "or_greater") var dig_rate_factor: float = 0.25

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
