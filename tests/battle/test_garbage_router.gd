extends GutTest

## Garbage Routing と KO Attribution の Unit テスト（要件定義 §40〜§42 / §56）。

const SEED: int = 20260920

var manager: BattleManager
var balance: GameBalance
var router: GarbageRouter


func before_each() -> void:
	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	balance = GameBalance.create_default()
	balance.garbage_delay_sec = 1.0
	manager = BattleManager.new(rules, balance)
	manager.setup(1, 2, SEED)
	router = GarbageRouter.new(manager, balance)


func _player(player_id: int) -> BattlePlayerState:
	return manager.get_player(player_id)


func _incoming(player_id: int) -> int:
	return _player(player_id).session.get_garbage_queue().get_pending_lines()


# --- 送信 ------------------------------------------------------------------


func test_attack_is_sent_to_the_current_target() -> void:
	_player(0).current_target = 2
	watch_signals(router)

	assert_true(router.route(0, 4, LineClear.Type.QUAD), "送信できる")

	assert_eq(_incoming(2), 4, "Target の Queue に積まれる")
	assert_eq(_incoming(1), 0, "他の Player には届かない")
	assert_signal_emitted_with_parameters(router, "garbage_routed", [0, 2, 4])


func test_event_records_source_and_target() -> void:
	_player(0).current_target = 1

	router.route(0, 3, LineClear.Type.TRIPLE)

	var events: Array[GarbageEvent] = _player(1).session.get_garbage_queue().peek_all()
	assert_eq(events.size(), 1, "1 件届く")
	assert_eq(events[0].source_player_id, 0, "送り主が記録される")
	assert_eq(events[0].target_player_id, 1, "送り先も記録される")
	assert_eq(events[0].attack_type, LineClear.Type.TRIPLE, "元の Attack 種別も残る")


func test_delay_comes_from_the_balance_data() -> void:
	balance.garbage_delay_sec = 2.5
	_player(0).current_target = 1

	router.route(0, 1, LineClear.Type.SINGLE)

	var event: GarbageEvent = _player(1).session.get_garbage_queue().peek_all()[0]
	assert_eq(event.activation_time - event.created_time, 2.5, "設定した Delay が使われる")


func test_zero_lines_are_not_sent() -> void:
	_player(0).current_target = 1

	assert_false(router.route(0, 0, LineClear.Type.NONE), "0 行は送らない")
	assert_eq(_incoming(1), 0, "Queue にも積まれない")


func test_no_target_means_no_send() -> void:
	_player(0).current_target = TargetMode.NO_TARGET

	assert_false(router.route(0, 4, LineClear.Type.QUAD), "Target がいなければ送らない")


func test_dead_target_is_not_sent_to() -> void:
	_player(0).current_target = 1
	manager.eliminate_player(1)

	assert_false(router.route(0, 4, LineClear.Type.QUAD), "脱落者には送らない")
	assert_eq(_incoming(1), 0, "Queue にも積まれない")


func test_self_target_is_rejected() -> void:
	_player(0).current_target = 0

	assert_false(router.route(0, 4, LineClear.Type.QUAD), "自分には送らない")


func test_dead_source_cannot_send() -> void:
	_player(0).current_target = 1
	manager.eliminate_player(0)

	assert_false(router.route(0, 4, LineClear.Type.QUAD), "脱落者は送れない")


func test_invalid_source_is_safe() -> void:
	assert_false(router.route(999, 4, LineClear.Type.QUAD), "存在しない ID でも落ちない")


# --- 相殺を経由すること（要件定義 §42） -------------------------------------


func test_attack_is_cancelled_before_being_sent() -> void:
	# Game Core が自分の Incoming と相殺し、余剰だけが attack_generated で出る。
	balance.line_attack_table = PackedInt32Array([0, 5, 5, 5, 5])
	balance.garbage_delay_sec = 100.0
	_player(0).current_target = 1
	_player(0).session.receive_garbage_lines(3)

	# 最下段を左端 1 列だけ空け、そこを埋めて 1 行消す。
	var board: Board = _player(0).get_board()
	for x in range(1, Board.WIDTH):
		board.set_cell(x, Board.TOTAL_HEIGHT - 1, Piece.Type.I)
	var piece: ActivePiece = _player(0).session.get_active_piece()
	piece.spawn(Piece.Type.I)
	piece.rotation = Piece.Rotation.RIGHT
	piece.position = Vector2i(-2, 0)

	_player(0).session.hard_drop()

	assert_eq(_player(0).session.get_garbage_queue().get_pending_lines(), 0, "自分の Incoming が消える")
	assert_eq(_incoming(1), 2, "余剰の 2 行だけが Target へ届く")


# --- 受信と適用 ------------------------------------------------------------


func test_garbage_is_applied_after_the_delay() -> void:
	_player(0).current_target = 1
	router.route(0, 2, LineClear.Type.DOUBLE)

	# Delay 経過前に Lock しても入らない。
	_player(1).session.hard_drop()
	assert_eq(_incoming(1), 2, "Delay 前は Queue に残る")

	for _frame in range(90):
		manager.update(1.0 / 60.0)
	_player(1).session.hard_drop()

	assert_eq(_incoming(1), 0, "Delay 経過で適用される")


# --- KO Attribution（要件定義 §56） -----------------------------------------


func test_application_is_recorded_with_its_source() -> void:
	_player(0).current_target = 1
	router.route(0, 2, LineClear.Type.DOUBLE)
	watch_signals(router)

	for _frame in range(90):
		manager.update(1.0 / 60.0)
	_player(1).session.hard_drop()

	var history: Array = router.get_attribution().get_history(1)
	assert_eq(history.size(), 1, "適用が記録される")
	assert_eq(history[0].source_player_id, 0, "Source Player が残る")
	assert_gt(history[0].applied_time, 0.0, "Garbage Application Time が残る")
	assert_signal_emitted(router, "garbage_received", "受信が通知される")


func test_last_effective_attacker_within_the_window() -> void:
	var attribution := KoAttribution.new()
	attribution.record_application(1, 0, 10.0, 2)

	assert_eq(attribution.get_last_effective_attacker(1, 12.0, 5.0), 0, "しきい値以内なら帰属する")
	assert_eq(attribution.get_last_effective_attacker(1, 20.0, 5.0), -1, "古すぎれば帰属しない")


func test_last_effective_attacker_picks_the_most_recent() -> void:
	var attribution := KoAttribution.new()
	attribution.record_application(1, 0, 10.0, 2)
	attribution.record_application(1, 2, 12.0, 1)

	assert_eq(attribution.get_last_effective_attacker(1, 13.0, 5.0), 2, "直近の攻撃者が選ばれる")


func test_all_attackers_are_listed_without_duplicates() -> void:
	var attribution := KoAttribution.new()
	attribution.record_application(1, 0, 1.0, 1)
	attribution.record_application(1, 2, 2.0, 1)
	attribution.record_application(1, 0, 3.0, 1)

	assert_eq(attribution.get_all_attackers(1), [0, 2] as Array[int], "重複なしで並ぶ")


func test_zero_lines_are_not_recorded() -> void:
	var attribution := KoAttribution.new()

	attribution.record_application(1, 0, 1.0, 0)

	assert_eq(attribution.get_history(1).size(), 0, "0 行は記録しない")


# --- KO Rule が交換可能であること（要件定義 §56） ---------------------------


class NoAttributionRule:
	extends KoRule

	func determine_attacker(_attribution: KoAttribution, _victim: int, _time: float) -> int:
		return -1


func test_default_rule_uses_the_last_effective_attacker() -> void:
	var attribution := KoAttribution.new()
	attribution.record_application(1, 0, 10.0, 2)
	var rule := KoRule.new(5.0)

	assert_eq(rule.determine_attacker(attribution, 1, 12.0), 0, "既定は直近の有効な攻撃者")
	assert_eq(rule.determine_attacker(attribution, 1, 100.0), -1, "時間切れなら誰にも帰属しない")


func test_rule_can_be_replaced() -> void:
	var attribution := KoAttribution.new()
	attribution.record_application(1, 0, 10.0, 2)

	var rule: KoRule = NoAttributionRule.new()

	assert_eq(rule.determine_attacker(attribution, 1, 12.0), -1, "差し替えた判定が使われる")


func test_rule_handles_null_attribution() -> void:
	assert_eq(KoRule.new().determine_attacker(null, 1, 0.0), -1, "記録がなくても落ちない")
