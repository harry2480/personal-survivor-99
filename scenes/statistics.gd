class_name Statistics
extends Resource

## 通算の記録（要件定義 §99）。
##
## 保存は [SettingsStore] を通す。Settings と同じ JSON 1 本の方式にそろえる
## （要件定義 §98 / #54 の完了条件）。
##
## 集計はここだけで行う。Battle 側は [BattleOutcome] を渡すだけ。

## 遊んだ回数。
@export var games_played: int = 0

## 優勝した回数。
@export var wins: int = 0

## 10 位以内に入った回数。
@export var top_ten_count: int = 0

## 順位の合計。平均順位を出すのに使う。
@export var rank_total: int = 0

## 奪った KO の合計。
@export var total_ko: int = 0

## 1 試合での最高 KO 数。
@export var best_ko: int = 0

## 消した行数の合計。
@export var total_lines: int = 0

## 4 行消しの回数。
@export var quad_count: int = 0

## T-Spin の回数。
@export var t_spin_count: int = 0

## Perfect Clear の回数。
@export var perfect_clear_count: int = 0

## 遊んだ時間の合計（秒）。
@export var play_time_sec: float = 0.0

## 倒した CPU のうち、いちばん強かった Strength。
@export var highest_cpu_strength_defeated: float = 0.0


## 空の記録を作る。
static func create_empty() -> Statistics:
	return Statistics.new()


## 保存されている記録を読む。無ければ空の記録を返す。
static func load_from(store: SettingsStore) -> Statistics:
	var stats := Statistics.create_empty()
	stats.apply_dictionary(store.load_document(SettingsStore.STATISTICS_DOCUMENT))
	return stats


## Battle 1 回ぶんを足し込む（要件定義 §99）。
func record_battle(outcome: BattleOutcome) -> void:
	if outcome == null or outcome.rank <= 0:
		return

	games_played += 1
	rank_total += outcome.rank
	if outcome.is_win():
		wins += 1
	if outcome.is_top_ten():
		top_ten_count += 1

	total_ko += outcome.ko_count
	best_ko = maxi(best_ko, outcome.ko_count)
	total_lines += outcome.cleared_lines
	quad_count += outcome.quad_count
	t_spin_count += outcome.t_spin_count
	perfect_clear_count += outcome.perfect_clear_count
	play_time_sec += maxf(0.0, outcome.duration_sec)
	highest_cpu_strength_defeated = maxf(
		highest_cpu_strength_defeated, outcome.highest_cpu_strength_defeated
	)


## 平均順位を返す。1 試合もしていなければ 0。
func get_average_rank() -> float:
	return float(rank_total) / float(games_played) if games_played > 0 else 0.0


## 勝率を返す。
func get_win_rate() -> float:
	return float(wins) / float(games_played) if games_played > 0 else 0.0


## 保存する。
func save_to(store: SettingsStore) -> bool:
	return store.save_document(SettingsStore.STATISTICS_DOCUMENT, to_dictionary())


## 保存用の Dictionary へ落とす。
func to_dictionary() -> Dictionary:
	return {
		"games_played": games_played,
		"wins": wins,
		"top_ten_count": top_ten_count,
		"rank_total": rank_total,
		"total_ko": total_ko,
		"best_ko": best_ko,
		"total_lines": total_lines,
		"quad_count": quad_count,
		"t_spin_count": t_spin_count,
		"perfect_clear_count": perfect_clear_count,
		"play_time_sec": play_time_sec,
		"highest_cpu_strength_defeated": highest_cpu_strength_defeated,
	}


## Dictionary から取り込む。型が違う値と知らない key は無視する。
func apply_dictionary(data: Dictionary) -> void:
	games_played = _read_int(data, "games_played", games_played)
	wins = _read_int(data, "wins", wins)
	top_ten_count = _read_int(data, "top_ten_count", top_ten_count)
	rank_total = _read_int(data, "rank_total", rank_total)
	total_ko = _read_int(data, "total_ko", total_ko)
	best_ko = _read_int(data, "best_ko", best_ko)
	total_lines = _read_int(data, "total_lines", total_lines)
	quad_count = _read_int(data, "quad_count", quad_count)
	t_spin_count = _read_int(data, "t_spin_count", t_spin_count)
	perfect_clear_count = _read_int(data, "perfect_clear_count", perfect_clear_count)
	play_time_sec = _read_float(data, "play_time_sec", play_time_sec)
	highest_cpu_strength_defeated = _read_float(
		data, "highest_cpu_strength_defeated", highest_cpu_strength_defeated
	)


static func _read_int(data: Dictionary, key: String, fallback: int) -> int:
	var value: Variant = data.get(key)
	return maxi(0, int(value)) if (value is int or value is float) else fallback


static func _read_float(data: Dictionary, key: String, fallback: float) -> float:
	var value: Variant = data.get(key)
	return maxf(0.0, float(value)) if (value is int or value is float) else fallback
