extends GutTest

## KO / Ranking / Attack Multiplier の Unit テスト（要件定義 §54 / §55 / §57）。

const SEED: int = 20260920

var manager: BattleManager
var balance: GameBalance
var attribution: KoAttribution
var ko: KoSystem


func before_each() -> void:
	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	balance = GameBalance.create_default()
	manager = BattleManager.new(rules, balance)
	manager.setup(1, 3, SEED)
	attribution = KoAttribution.new()
	ko = KoSystem.new(manager, attribution, balance)


func _player(player_id: int) -> BattlePlayerState:
	return manager.get_player(player_id)


# --- Ranking（要件定義 §55） ------------------------------------------------


func test_rank_is_the_alive_count_at_elimination() -> void:
	var ranking := RankingSystem.new()

	assert_eq(ranking.get_rank_on_elimination(9), 10, "残り 10 人で脱落したら Rank 10")
	assert_eq(ranking.get_rank_on_elimination(1), 2, "残り 2 人で脱落したら Rank 2")
	assert_eq(ranking.get_rank_on_elimination(0), 1, "1 人しかいなければ Rank 1")


func test_rank_changed_is_emitted_on_elimination() -> void:
	watch_signals(ko)

	manager.eliminate_player(1)

	assert_signal_emitted_with_parameters(ko, "rank_changed", [1, 4])


func test_winner_gets_rank_one() -> void:
	watch_signals(ko)

	manager.eliminate_player(1)
	manager.eliminate_player(2)
	manager.eliminate_player(3)

	assert_eq(_player(0).rank, RankingSystem.WINNER_RANK, "最後の 1 人が Rank 1")
	assert_signal_emitted_with_parameters(ko, "rank_changed", [0, 1])


func test_standings_are_recorded_in_order() -> void:
	manager.eliminate_player(2)
	manager.eliminate_player(1)
	manager.eliminate_player(3)

	assert_eq(ko.get_ranking().get_standings(), [2, 1, 3, 0] as Array[int], "脱落順に並び、最後が勝者")


# --- 脱落後の除外（要件定義 §54） -------------------------------------------


func test_eliminated_player_is_excluded_from_targets() -> void:
	var targets := TargetManager.new(manager, SEED)
	manager.eliminate_player(2)

	for _attempt in range(30):
		assert_ne(targets.select_target(_player(0)), 2, "Target 対象から外れる")


func test_eliminated_player_is_not_simulated() -> void:
	manager.eliminate_player(1)
	var before: Vector2i = _player(1).session.get_active_piece().position

	manager.update(1.0)

	assert_eq(_player(1).session.get_active_piece().position, before, "Simulation が止まる")


func test_eliminated_player_cannot_send_attacks() -> void:
	var router := GarbageRouter.new(manager, balance)
	_player(1).current_target = 0
	manager.eliminate_player(1)

	assert_false(router.route(1, 4, LineClear.Type.QUAD), "Attack が止まる")


# --- KO Attribution（要件定義 §56） -----------------------------------------


func test_ko_is_attributed_to_the_last_effective_attacker() -> void:
	attribution.record_application(1, 2, 0.0, 4)
	watch_signals(ko)

	manager.eliminate_player(1)

	assert_signal_emitted_with_parameters(ko, "player_ko", [1, 2])
	assert_eq(_player(2).ko_count, 1, "攻撃者の KO 数が増える")


func test_self_destruction_is_attributed_to_nobody() -> void:
	watch_signals(ko)

	manager.eliminate_player(1)

	assert_signal_emitted_with_parameters(ko, "player_ko", [1, -1])
	for player in manager.get_players():
		assert_eq(player.ko_count, 0, "誰の KO にもならない")


func test_attribution_expires() -> void:
	attribution.record_application(1, 2, 0.0, 4)
	for _frame in range(60 * 10):
		manager.update(1.0 / 60.0)

	manager.eliminate_player(1)

	assert_eq(_player(2).ko_count, 0, "しきい値を過ぎたら帰属しない")


func test_ko_is_credited_to_an_eliminated_attacker() -> void:
	attribution.record_application(1, 2, 0.0, 4)
	manager.eliminate_player(2)

	manager.eliminate_player(1)

	assert_eq(_player(2).ko_count, 1, "攻撃者が先に脱落していても KO は記録される")


func test_player_ko_is_emitted_after_the_stats_are_updated() -> void:
	attribution.record_application(1, 2, 0.0, 4)
	var seen: Array = []
	ko.player_ko.connect(
		func(_victim: int, attacker: int) -> void: seen.append(_player(attacker).ko_count)
	)

	manager.eliminate_player(1)

	assert_eq(seen, [1], "通知の時点で KO 数が更新済み")


func test_ko_rule_can_be_replaced() -> void:
	attribution.record_application(1, 2, 0.0, 4)
	ko.set_rule(KoRule.new(0.0))

	manager.eliminate_player(1)

	assert_eq(_player(2).ko_count, 1, "しきい値 0 でも同時刻なら帰属する")


# --- Attack Multiplier（要件定義 §57） --------------------------------------


func test_stage_rises_with_attack_points() -> void:
	var expected: Dictionary = {0: 0, 1: 0, 2: 1, 4: 2, 7: 3, 10: 4, 99: 4}
	for points in expected:
		assert_eq(
			balance.get_multiplier_stage(points), expected[points], "%d points の Stage" % points
		)


func test_multiplier_value_per_stage() -> void:
	assert_eq(balance.get_multiplier_value(0), 1.0, "Stage 0 は等倍")
	assert_gt(balance.get_multiplier_value(4), balance.get_multiplier_value(0), "Stage 4 は強い")
	assert_eq(balance.get_max_multiplier_stage(), 4, "Stage は 0〜4")


func test_ko_grants_attack_points() -> void:
	attribution.record_application(1, 2, 0.0, 4)

	manager.eliminate_player(1)

	assert_eq(_player(2).attack_points, balance.ko_attack_points, "KO で Attack Points を得る")


func test_multiplier_changed_is_emitted_on_stage_up() -> void:
	var multiplier: MultiplierSystem = ko.get_multiplier_system()
	watch_signals(multiplier)

	multiplier.add_attack_points(_player(0), balance.multiplier_thresholds[1])

	assert_signal_emitted(multiplier, "multiplier_changed", "Stage が上がると通知される")
	assert_gt(_player(0).attack_multiplier, 1.0, "倍率が上がる")


func test_multiplier_is_not_emitted_without_a_change() -> void:
	var multiplier: MultiplierSystem = ko.get_multiplier_system()
	multiplier.add_attack_points(_player(0), 1)
	watch_signals(multiplier)

	multiplier.refresh(_player(0))

	assert_signal_not_emitted(multiplier, "multiplier_changed", "変わらなければ通知しない")


func test_attack_points_never_go_negative() -> void:
	var multiplier: MultiplierSystem = ko.get_multiplier_system()

	multiplier.add_attack_points(_player(0), -10)

	assert_eq(_player(0).attack_points, 0, "0 未満にはならない")


func test_multiplier_is_applied_to_the_attack() -> void:
	_player(0).attack_multiplier = 2.0

	assert_eq(MultiplierSystem.apply(5, _player(0)), 10, "倍率が乗る")
	assert_eq(MultiplierSystem.apply(5, _player(0), 3), 13, "人数補正も乗る")
	assert_eq(MultiplierSystem.apply(5, null), 5, "Player がいなければ等倍")


func test_multiplier_reaches_the_session() -> void:
	ko.get_multiplier_system().add_attack_points(_player(0), balance.multiplier_thresholds[1])

	assert_eq(_player(0).session.attack_multiplier, _player(0).attack_multiplier, "Session に届く")
	assert_gt(_player(0).session.attack_multiplier, 1.0, "倍率が上がっている")


func test_multiplier_is_applied_before_cancellation() -> void:
	# 5 行の Attack が 2 倍で 10 行になり、Incoming 3 行を相殺して 7 行が残る。
	balance.line_attack_table = PackedInt32Array([0, 5, 5, 5, 5])
	balance.garbage_delay_sec = 100.0
	var session: PuzzleSession = _player(0).session
	session.attack_multiplier = 2.0
	session.receive_garbage_lines(3)
	watch_signals(session)

	_clear_one_line(_player(0))

	assert_eq(session.get_garbage_queue().get_pending_lines(), 0, "Incoming は倍率込みの Attack で消える")
	assert_signal_emitted(session, "attack_generated", "余剰が送られる")
	assert_eq(get_signal_parameters(session, "attack_generated")[0], 7, "余剰は倍率込みで 7 行")


func _clear_one_line(player: BattlePlayerState) -> void:
	# 最下段を左端 1 列だけ空け、縦の I で埋めて 1 行消す。
	var board: Board = player.get_board()
	for x in range(1, Board.WIDTH):
		board.set_cell(x, Board.TOTAL_HEIGHT - 1, Piece.Type.I)
	var piece: ActivePiece = player.session.get_active_piece()
	piece.spawn(Piece.Type.I)
	piece.rotation = Piece.Rotation.RIGHT
	piece.position = Vector2i(-2, 0)
	player.session.hard_drop()


func test_thresholds_are_data_driven() -> void:
	balance.multiplier_thresholds = PackedInt32Array([0, 100])
	balance.multiplier_values = PackedFloat32Array([1.0, 3.0])

	assert_eq(balance.get_multiplier_stage(50), 0, "設定した閾値に従う")
	assert_eq(balance.get_multiplier_stage(100), 1, "閾値に達すると上がる")
	assert_eq(balance.get_multiplier_value(1), 3.0, "倍率も設定から来る")
	assert_eq(balance.get_max_multiplier_stage(), 1, "Stage 数も設定次第")
