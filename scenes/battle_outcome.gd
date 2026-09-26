class_name BattleOutcome
extends Resource

## Battle 1 回ぶんの結果（要件定義 §99 / MVP 受入条件 21）。
##
## Result 画面（#54）が表示し、[Statistics] が集計に使う。Battle が終わった
## 時点の値をそのまま持つだけで、判定や集計は行わない。

## 確定した順位（1 が優勝）。
@export var rank: int = 0

## 参加人数。
@export var player_count: int = 0

## 奪った KO の数。
@export var ko_count: int = 0

## 消した行数の合計。
@export var cleared_lines: int = 0

## 4 行消し（Quad）の回数。
@export var quad_count: int = 0

## T-Spin の回数。
@export var t_spin_count: int = 0

## Perfect Clear の回数。
@export var perfect_clear_count: int = 0

## Battle の長さ（秒）。
@export var duration_sec: float = 0.0

## 倒した CPU のうち、いちばん強かった Strength。
@export var highest_cpu_strength_defeated: float = 0.0

## この Battle の Seed（要件定義 §110）。
@export var battle_seed: int = 0


## 空の結果を作る。
static func create_empty() -> BattleOutcome:
	return BattleOutcome.new()


## 優勝したかを返す。
func is_win() -> bool:
	return rank == 1


## 上位 10 位以内かを返す（要件定義 §99 の Top 10 Count）。
func is_top_ten() -> bool:
	return rank >= 1 and rank <= 10
