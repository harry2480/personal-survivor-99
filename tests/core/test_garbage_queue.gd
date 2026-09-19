extends GutTest

## Garbage Queue と Cancellation の Unit テスト（要件定義 §41 / §42）。

const DELAY: float = 1.0
const HOLE_SEED: int = 20260920

var board: Board
var queue: GarbageQueue
var holes: GarbageHoleGenerator


func before_each() -> void:
	board = Board.new()
	queue = GarbageQueue.new()
	holes = GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.SAME_COLUMN_PER_EVENT, HOLE_SEED)


func _event(lines: int, created: float = 0.0, attack_id: int = 0) -> GarbageEvent:
	return GarbageEvent.create(1, 2, lines, created, DELAY, LineClear.Type.QUAD, attack_id)


# --- Garbage Event ---------------------------------------------------------


func test_event_holds_the_required_fields() -> void:
	var event: GarbageEvent = GarbageEvent.create(3, 7, 4, 10.0, 1.5, LineClear.Type.QUAD, 42)

	assert_eq(event.source_player_id, 3, "送り主")
	assert_eq(event.target_player_id, 7, "送り先")
	assert_eq(event.line_count, 4, "行数")
	assert_eq(event.created_time, 10.0, "生成時刻")
	assert_eq(event.activation_time, 11.5, "生成時刻 + Delay で有効になる")
	assert_eq(event.attack_type, LineClear.Type.QUAD, "元の Attack 種別")
	assert_eq(event.attack_id, 42, "Attack の識別子")


func test_event_activation() -> void:
	var event: GarbageEvent = _event(2, 5.0)

	assert_false(event.is_active_at(5.9), "Delay 経過前は適用できない")
	assert_true(event.is_active_at(6.0), "Delay 経過で適用できる")


# --- Queue -----------------------------------------------------------------


func test_enqueue_accumulates_lines() -> void:
	queue.enqueue(_event(2))
	queue.enqueue(_event(3))

	assert_eq(queue.get_pending_count(), 2, "2 件溜まる")
	assert_eq(queue.get_pending_lines(), 5, "合計 5 行")


func test_empty_event_is_ignored() -> void:
	queue.enqueue(_event(0))
	queue.enqueue(null)

	assert_eq(queue.get_pending_count(), 0, "0 行と null は無視する")


func test_ready_lines_respect_the_delay() -> void:
	queue.enqueue(_event(2, 0.0))
	queue.enqueue(_event(3, 5.0))

	assert_eq(queue.get_ready_lines(0.5), 0, "まだ 1 件も有効でない")
	assert_eq(queue.get_ready_lines(1.0), 2, "先の 1 件だけ有効")
	assert_eq(queue.get_ready_lines(6.0), 5, "両方有効")


func test_processing_order_is_by_activation_time() -> void:
	queue.enqueue(_event(1, 5.0, 1))
	queue.enqueue(_event(2, 0.0, 2))
	queue.enqueue(_event(3, 2.0, 3))

	var order: Array[GarbageEvent] = queue.peek_all()

	assert_eq(
		[order[0].line_count, order[1].line_count, order[2].line_count], [2, 3, 1], "活性時刻が早い順に並ぶ"
	)


func test_same_time_order_is_decided_by_attack_id() -> void:
	queue.enqueue(_event(1, 0.0, 30))
	queue.enqueue(_event(2, 0.0, 10))
	queue.enqueue(_event(3, 0.0, 20))

	var order: Array[GarbageEvent] = queue.peek_all()

	assert_eq(
		[order[0].attack_id, order[1].attack_id, order[2].attack_id],
		[10, 20, 30],
		"同時刻は attack_id 順で一意に決まる"
	)


func test_same_time_and_id_order_is_decided_by_arrival() -> void:
	var first: GarbageEvent = _event(1, 0.0, 0)
	var second: GarbageEvent = _event(2, 0.0, 0)
	queue.enqueue(first)
	queue.enqueue(second)

	var order: Array[GarbageEvent] = queue.peek_all()

	assert_eq(order[0].line_count, 1, "先に受け取ったものが先")
	assert_eq(order[1].line_count, 2, "後から受け取ったものが後")


# --- Cancellation（要件定義 §42） -------------------------------------------


func test_attack_cancels_incoming_garbage() -> void:
	queue.enqueue(_event(4))

	var surplus: int = queue.cancel_with_attack(3)

	assert_eq(surplus, 0, "相殺しきれなければ送信は 0")
	assert_eq(queue.get_pending_lines(), 1, "Incoming が減る")


func test_surplus_attack_is_returned() -> void:
	queue.enqueue(_event(2))

	var surplus: int = queue.cancel_with_attack(5)

	assert_eq(surplus, 3, "余剰が Target へ送られる")
	assert_eq(queue.get_pending_lines(), 0, "Incoming は消える")


func test_cancelling_exactly_sends_nothing() -> void:
	queue.enqueue(_event(4))

	assert_eq(queue.cancel_with_attack(4), 0, "ちょうど相殺したら送信 0")
	assert_eq(queue.get_pending_count(), 0, "Queue も空になる")


func test_cancellation_consumes_the_oldest_first() -> void:
	queue.enqueue(_event(2, 0.0, 1))
	queue.enqueue(_event(3, 5.0, 2))

	queue.cancel_with_attack(3)

	var remaining: Array[GarbageEvent] = queue.peek_all()
	assert_eq(remaining.size(), 1, "先の 1 件が消える")
	assert_eq(remaining[0].line_count, 2, "後の 1 件から 1 行だけ減る")


func test_attack_without_incoming_is_all_surplus() -> void:
	assert_eq(queue.cancel_with_attack(5), 5, "Incoming がなければ全部送る")


func test_zero_or_negative_attack_cancels_nothing() -> void:
	queue.enqueue(_event(3))

	assert_eq(queue.cancel_with_attack(0), 0, "0 では何も起きない")
	assert_eq(queue.cancel_with_attack(-5), 0, "負の値でも何も起きない")
	assert_eq(queue.get_pending_lines(), 3, "Incoming は変わらない")


# --- 盤面への適用 ----------------------------------------------------------


func test_apply_ready_pushes_lines_into_the_board() -> void:
	queue.enqueue(_event(2, 0.0))

	var applied: int = queue.apply_ready(board, DELAY, holes)

	assert_eq(applied, 2, "2 行適用される")
	assert_eq(queue.get_pending_lines(), 0, "Queue から消える")
	for y in [Board.TOTAL_HEIGHT - 1, Board.TOTAL_HEIGHT - 2]:
		assert_false(board.is_row_empty(y), "下部に Garbage が入る（y=%d）" % y)
		assert_false(board.is_row_filled(y), "穴が空いている（y=%d）" % y)


func test_apply_ready_skips_events_still_in_delay() -> void:
	queue.enqueue(_event(2, 0.0))
	queue.enqueue(_event(3, 10.0))

	var applied: int = queue.apply_ready(board, DELAY, holes)

	assert_eq(applied, 2, "Delay 経過分だけ適用される")
	assert_eq(queue.get_pending_lines(), 3, "残りは Queue に残る")


func test_existing_blocks_are_pushed_up() -> void:
	board.set_cell(0, Board.TOTAL_HEIGHT - 1, Piece.Type.T)
	queue.enqueue(_event(1, 0.0))

	queue.apply_ready(board, DELAY, holes)

	assert_eq(board.get_cell(0, Board.TOTAL_HEIGHT - 2), Piece.Type.T as int, "既存ブロックが 1 行上がる")


func test_garbage_rows_have_exactly_one_hole() -> void:
	queue.enqueue(_event(3, 0.0))

	queue.apply_ready(board, DELAY, holes)

	for offset in range(3):
		var y: int = Board.TOTAL_HEIGHT - 1 - offset
		var empty_cells: int = 0
		for x in range(Board.WIDTH):
			if board.is_cell_empty(x, y):
				empty_cells += 1
		assert_eq(empty_cells, 1, "各行の穴は 1 つ（y=%d）" % y)


func test_clear_empties_the_queue() -> void:
	queue.enqueue(_event(3))

	queue.clear()

	assert_eq(queue.get_pending_count(), 0, "空になる")
