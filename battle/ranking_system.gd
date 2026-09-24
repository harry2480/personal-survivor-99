class_name RankingSystem
extends RefCounted

## 順位の確定（要件定義 §55）。
##
## 脱落時の生存人数がそのまま順位になる。残り 10 人で脱落したら Rank 10、
## 最後の 1 人は Rank 1。
##
## 判定をここに閉じ、Battle Manager からは呼ぶだけにする。

## 最後の 1 人に与える順位。
const WINNER_RANK: int = 1

var _standings: Array[int] = []


## 脱落した Player の順位を返す。
##
## [param alive_count_after] は、その Player が脱落した**あと**の生存人数。
func get_rank_on_elimination(alive_count_after: int) -> int:
	return maxi(WINNER_RANK, alive_count_after + 1)


## 脱落を記録し、確定した順位を返す。
func record_elimination(player_id: int, alive_count_after: int) -> int:
	_standings.append(player_id)
	return get_rank_on_elimination(alive_count_after)


## 勝者を記録する。
func record_winner(player_id: int) -> int:
	_standings.append(player_id)
	return WINNER_RANK


## 脱落した順（最後が勝者）に Player ID を返す。
func get_standings() -> Array[int]:
	return _standings.duplicate()


## 記録を捨てる。
func reset() -> void:
	_standings.clear()
