class_name LockDelay
extends RefCounted

## 接地してから Lock するまでの猶予（要件定義 §30）。
##
## 接地中に時間を溜め、[member GameRules.lock_delay_sec] を超えたら Lock する。
## 左右移動と回転で猶予を Reset できるが、Reset 回数には上限がある。上限に達した
## 後は、動かしても回しても Lock は延期されない。
##
## Piece がそれまでより深い行へ落ちたときは、Reset 回数を戻す。落下が進んでいる
## 限りは無制限に操作できるようにするため。
##
## 実時間は見ない。delta は外から与えられる（要件定義 §17）。

## Lock Delay を Reset しうる操作。
enum Action { MOVE, ROTATE }

var _rules: GameRules
var _elapsed_sec: float = 0.0
var _reset_count: int = 0
var _deepest_y: int = -1


func _init(rules: GameRules = null) -> void:
	_rules = rules if rules != null else GameRules.create_default()


## 新しい Piece の操作を始めるときに呼ぶ。猶予も Reset 回数も初期化する。
func start_new_piece() -> void:
	_elapsed_sec = 0.0
	_reset_count = 0
	_deepest_y = -1


## 時間を進め、Lock すべきかを返す。
##
## [param lowest_y] は Piece が占める一番下のマスの y。これが更新されるたびに
## Reset 回数を戻す。
func update(delta_sec: float, is_on_ground: bool, lowest_y: int) -> bool:
	if lowest_y > _deepest_y:
		_deepest_y = lowest_y
		_elapsed_sec = 0.0
		_reset_count = 0

	if not is_on_ground:
		_elapsed_sec = 0.0
		return false

	_elapsed_sec += maxf(0.0, delta_sec)
	return _elapsed_sec + GameRules.ACCUMULATION_EPSILON >= _rules.lock_delay_sec


## 操作による Reset を試みる。Reset できたら true。
##
## 対象外の操作、または Reset 上限に達している場合は false を返し、猶予は動かさない。
func notify_action(action: Action) -> bool:
	if not _is_reset_action(action):
		return false
	if _rules.has_reset_limit() and _reset_count >= _rules.lock_delay_reset_limit:
		return false

	_reset_count += 1
	_elapsed_sec = 0.0
	return true


## 接地してから溜まった時間（秒）を返す。
func get_elapsed_sec() -> float:
	return _elapsed_sec


## この Piece で Reset した回数を返す。
func get_reset_count() -> int:
	return _reset_count


## これ以上 Reset できないかを返す。
func is_reset_exhausted() -> bool:
	return _rules.has_reset_limit() and _reset_count >= _rules.lock_delay_reset_limit


func _is_reset_action(action: Action) -> bool:
	match action:
		Action.MOVE:
			return _rules.lock_delay_reset_on_move
		Action.ROTATE:
			return _rules.lock_delay_reset_on_rotate
	return false
