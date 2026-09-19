class_name BattlePhase
extends RefCounted

## 残存人数による Battle の段階（要件定義 §93）。
##
## BGM・背景・演出・CPU の Simulation 優先度がこの段階で変わる。判定を Battle
## Layer に閉じ、Presentation は結果を受け取るだけにする。
##
## 状態を持たないので全て static。

## Battle の段階。
enum Phase { OPENING, EARLY, MIDDLE, LATE, FINAL, DUEL, FINISHED }

## 段階が切り替わる残存人数（要件定義 §93 の代表的閾値）。
##
## 「この人数以下になったら次の段階」という下限を、上の段階から順に並べる。
const THRESHOLDS: Array[int] = [50, 20, 10, 5, 2]


## 残存人数から段階を返す。
static func from_alive_count(alive_count: int) -> Phase:
	if alive_count <= 1:
		return Phase.FINISHED

	var phase: int = Phase.OPENING
	for threshold in THRESHOLDS:
		if alive_count <= threshold:
			phase += 1
	return phase as Phase


## 段階の名前を返す。ログとテスト用。
static func get_phase_name(phase: Phase) -> String:
	return Phase.keys()[phase]
