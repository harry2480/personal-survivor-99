class_name KoAttribution
extends RefCounted

## Garbage の出所を追跡する（要件定義 §56）。
##
## 最低限、Source Player / Garbage Application Time / Last Effective Attacker を
## 保持する。KO の原因になった攻撃者を後から特定するために使う。
##
## 「直近の有効な攻撃者」は、適用からの経過時間で判定する。しきい値は
## [GameBalance] のデータで変えられる。


## 適用の記録 1 件。
class Application:
	extends RefCounted

	## Garbage を送った Player ID。
	var source_player_id: int = -1

	## 盤面へ適用されたゲーム内時刻（秒）。
	var applied_time: float = 0.0

	## 適用された行数。
	var line_count: int = 0

	func _init(source_id: int, time: float, lines: int) -> void:
		source_player_id = source_id
		applied_time = time
		line_count = lines


var _history_by_victim: Dictionary = {}


## Garbage が盤面へ適用されたことを記録する。
func record_application(victim_id: int, source_id: int, applied_time: float, lines: int) -> void:
	if lines <= 0:
		return

	var history: Array = _history_by_victim.get(victim_id, [])
	history.append(Application.new(source_id, applied_time, lines))
	_history_by_victim[victim_id] = history


## Player に適用された記録を、古い順に返す。
func get_history(victim_id: int) -> Array:
	return _history_by_victim.get(victim_id, [])


## 直近に適用された記録を返す。無ければ null。
func get_last_application(victim_id: int) -> Application:
	var history: Array = get_history(victim_id)
	return history[history.size() - 1] if not history.is_empty() else null


## 直近の有効な攻撃者を返す（要件定義 §56）。
##
## [param window_sec] 以内に Garbage を適用した攻撃者だけを対象にする。
## 該当がなければ -1。
func get_last_effective_attacker(victim_id: int, current_time: float, window_sec: float) -> int:
	var history: Array = get_history(victim_id)
	for index in range(history.size() - 1, -1, -1):
		var application: Application = history[index]
		if current_time - application.applied_time <= window_sec:
			return application.source_player_id
	return -1


## その Player へ Garbage を送った全員を返す（重複なし）。
func get_all_attackers(victim_id: int) -> Array[int]:
	var attackers: Array[int] = []
	var seen: Dictionary = {}
	for application in get_history(victim_id):
		if not seen.has(application.source_player_id):
			seen[application.source_player_id] = true
			attackers.append(application.source_player_id)
	return attackers


## 記録をすべて捨てる。
func clear() -> void:
	_history_by_victim.clear()
