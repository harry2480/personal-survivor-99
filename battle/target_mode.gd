class_name TargetMode
extends RefCounted

## 攻撃先の選び方（要件定義 §47〜§52）。

## Target の選び方。
enum Mode {
	## 生存中の他 Player からランダムに選ぶ（§48）。
	RANDOM,
	## 脱落しやすい Player を優先する（§49）。
	KO,
	## Attack Multiplier 用リソースを多く持つ Player を優先する（§50）。
	BADGE,
	## 自分を狙っている Player を優先する（§51）。
	COUNTER,
	## プレイヤーが直接指定する（§52）。Auto より優先される。
	MANUAL,
}

## Counter Target で候補が複数いる場合の選び方（§51）。
enum CounterTieBreak {
	## ランダムに 1 人選ぶ。
	RANDOM,
	## 盤面が危険な Player を優先する。
	MOST_DANGEROUS,
	## Player ID が小さい方を選ぶ（完全に決定論的）。
	LOWEST_ID,
}

## Auto Target の Mode（Manual を除く）。
const AUTO_MODES: Array[int] = [Mode.RANDOM, Mode.KO, Mode.BADGE, Mode.COUNTER]

## Target がいないことを表す値。
const NO_TARGET: int = -1


## Auto Target の Mode かを返す。
static func is_auto(mode: Mode) -> bool:
	return mode in AUTO_MODES


## Mode の名前を返す。ログとテスト用。
static func get_mode_name(mode: Mode) -> String:
	return Mode.keys()[mode]
