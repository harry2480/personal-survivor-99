class_name GarbageQueue
extends RefCounted

## Incoming Garbage の Queue（要件定義 §41 / §42）。
##
## 受け取った [GarbageEvent] を Delay 経過まで溜め、時刻が来たものから盤面へ適用する。
##
## **処理順序を明示的に保証する。** 並べ替えの鍵は
## [code](activation_time, attack_id, 受け取った順)[/code] で、同時刻でも順序が一意に決まる。
## 順序が揺れると相殺の結果が変わり、対戦のバランスが壊れるため。
##
## 相殺は要件定義 §42 の順序を守る。
## [codeblock]
## 生成 Attack → Incoming を相殺 → 余剰を Target へ送信
## [/codeblock]

## Event が盤面へ適用された。相殺で消えた分は含まない。
signal event_applied(source_player_id: int, line_count: int)

## Garbage Line を表す Board のセル値。Piece の種類（0 以上）と区別する。
const GARBAGE_CELL: int = 7

var _events: Array[GarbageEvent] = []
var _received_count: int = 0


## Queue へ追加する。受け取り順も記録し、同時刻の順序を一意にする。
func enqueue(event: GarbageEvent) -> void:
	if event == null or not event.has_lines():
		return

	_received_count += 1
	event.set_meta("receive_order", _received_count)
	_events.append(event)
	_sort_events()


## Queue に溜まっている合計行数を返す。
func get_pending_lines() -> int:
	var total: int = 0
	for event in _events:
		total += event.line_count
	return total


## Queue に溜まっている件数を返す。
func get_pending_count() -> int:
	return _events.size()


## 指定時刻で適用できる合計行数を返す。
func get_ready_lines(current_time: float) -> int:
	var total: int = 0
	for event in _events:
		if event.is_active_at(current_time):
			total += event.line_count
	return total


## 処理順に並んだ Queue の内容を返す（確認用のコピー）。
func peek_all() -> Array[GarbageEvent]:
	return _events.duplicate()


## 生成した Attack で Incoming を相殺し、余剰を返す（要件定義 §42）。
##
## 古い（先に適用される）Event から順に打ち消す。相殺しきれば 0 を返す。
func cancel_with_attack(attack_lines: int) -> int:
	var remaining: int = maxi(0, attack_lines)

	for event in _events:
		if remaining <= 0:
			break
		remaining -= event.absorb(remaining)

	_remove_empty_events()
	return remaining


## Delay が経過した Garbage を盤面へ適用し、適用した行数を返す。
##
## 適用は処理順に行う。盤面の下部へ押し込み、はみ出した行は捨てる。
func apply_ready(board: Board, current_time: float, holes: GarbageHoleGenerator) -> int:
	var applied: int = 0

	# 途中で Queue を変更するため、対象を先に決める。
	var ready: Array[GarbageEvent] = []
	for event in _events:
		if event.is_active_at(current_time):
			ready.append(event)

	for event in ready:
		applied += _apply_event(board, event, holes)

	_remove_empty_events()
	return applied


## Queue を空にする。
func clear() -> void:
	_events.clear()
	_received_count = 0


## Garbage 行を盤面の下部へ押し込む。
##
## [param hole_columns] は上の行から順の穴の列。
static func push_lines(board: Board, hole_columns: PackedInt32Array) -> int:
	var line_count: int = hole_columns.size()
	if line_count <= 0:
		return 0

	# 既存の盤面を上へずらす。上端からはみ出した行は捨てる。
	for y in range(Board.TOTAL_HEIGHT - line_count):
		for x in range(Board.WIDTH):
			board.set_cell(x, y, board.get_cell(x, y + line_count))

	# 空いた下部へ Garbage 行を書く。
	for index in range(line_count):
		var y: int = Board.TOTAL_HEIGHT - line_count + index
		var hole_x: int = hole_columns[index]
		for x in range(Board.WIDTH):
			board.set_cell(x, y, Board.EMPTY if x == hole_x else GARBAGE_CELL)

	return line_count


func _apply_event(board: Board, event: GarbageEvent, holes: GarbageHoleGenerator) -> int:
	var hole_columns: PackedInt32Array = holes.generate(event.line_count)
	var applied: int = push_lines(board, hole_columns)
	event.line_count = 0
	if applied > 0:
		event_applied.emit(event.source_player_id, applied)
	return applied


func _remove_empty_events() -> void:
	var remaining: Array[GarbageEvent] = []
	for event in _events:
		if event.has_lines():
			remaining.append(event)
	_events = remaining


func _sort_events() -> void:
	_events.sort_custom(_compare_events)


# 同時刻でも順序が一意に決まるよう、活性時刻 → attack_id → 受け取り順で比較する。
#
# 活性時刻は厳密に比べる。is_equal_approx() は推移律を満たさないため、
# 近い時刻が混ざると比較の結果が並べ替えの順番に依存し、決定論が崩れる（§110 / §111）。
static func _compare_events(left: GarbageEvent, right: GarbageEvent) -> bool:
	if left.activation_time != right.activation_time:
		return left.activation_time < right.activation_time
	if left.attack_id != right.attack_id:
		return left.attack_id < right.attack_id
	return int(left.get_meta("receive_order", 0)) < int(right.get_meta("receive_order", 0))
