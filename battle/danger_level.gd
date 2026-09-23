class_name DangerLevel
extends RefCounted

## 盤面の危険度（要件定義 §92）。
##
## 盤面の高さから算出する。**UI 側で独自に判定しない。** 表示（色・点滅・SE）は
## この結果を受け取るだけにして、判定を 1 箇所に閉じる。
##
## 状態を持たないので全て static。

## 危険度の段階。
enum Level { SAFE, WARNING, DANGER, CRITICAL }

## WARNING に入る積み上げ比率。
const WARNING_RATIO: float = 0.5

## DANGER に入る積み上げ比率。
const DANGER_RATIO: float = 0.7

## CRITICAL に入る積み上げ比率。
const CRITICAL_RATIO: float = 0.9


## 積み上がっている高さ（マス数）を返す。
##
## 一番上にあるブロックから床までの距離。表示領域より上に積まれていれば
## 表示領域の高さを超える。
static func get_stack_height(board: Board) -> int:
	for y in range(Board.TOTAL_HEIGHT):
		if not board.is_row_empty(y):
			return Board.TOTAL_HEIGHT - y
	return 0


## 危険度を 0.0〜1.0 の比率で返す。表示領域の高さを 1.0 とする。
static func get_ratio(board: Board) -> float:
	var height: int = get_stack_height(board)
	return clampf(float(height) / float(Board.VISIBLE_HEIGHT), 0.0, 1.0)


## 危険度の段階を返す。
static func get_level(board: Board) -> Level:
	var ratio: float = get_ratio(board)
	if ratio >= CRITICAL_RATIO:
		return Level.CRITICAL
	if ratio >= DANGER_RATIO:
		return Level.DANGER
	if ratio >= WARNING_RATIO:
		return Level.WARNING
	return Level.SAFE


## 段階の名前を返す。ログとテスト用。
static func get_level_name(level: Level) -> String:
	return Level.keys()[level]
