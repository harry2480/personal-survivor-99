extends GutTest

## Battle Manager の Unit テスト（要件定義 §44 / §54 / §55 / §93）。

const SEED: int = 20260920

var manager: BattleManager


func before_each() -> void:
	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	manager = BattleManager.new(rules)


# --- Player の生成と ID ----------------------------------------------------


func test_setup_creates_the_requested_players() -> void:
	manager.setup(1, 3, SEED)

	assert_eq(manager.get_player_count(), 4, "人数ぶん作られる")
	assert_eq(manager.get_alive_count(), 4, "全員生存している")


func test_player_ids_are_unique() -> void:
	manager.setup(1, 20, SEED)

	var seen: Dictionary = {}
	for player in manager.get_players():
		assert_false(seen.has(player.player_id), "ID が重複しない")
		seen[player.player_id] = true

	assert_eq(seen.size(), manager.get_player_count(), "全員に ID が付く")


func test_player_types_follow_the_setup() -> void:
	manager.setup(1, 2, SEED)

	var players: Array[BattlePlayerState] = manager.get_players()
	assert_eq(players[0].player_type, PlayerType.Type.LOCAL_HUMAN, "最初が Human")
	assert_eq(players[1].player_type, PlayerType.Type.CPU, "残りが CPU")
	assert_eq(players[2].player_type, PlayerType.Type.CPU, "残りが CPU")


func test_invalid_id_returns_null() -> void:
	manager.setup(1, 1, SEED)

	assert_null(manager.get_player(-1), "負の ID は null")
	assert_null(manager.get_player(999), "存在しない ID も null")


func test_each_player_has_a_board_state() -> void:
	manager.setup(1, 2, SEED)

	for player in manager.get_players():
		assert_true(player.has_board_state(), "Detailed Simulation 対象に Board が紐付く")
		assert_not_null(player.get_board(), "盤面が取れる")


func test_players_get_different_piece_orders() -> void:
	manager.setup(2, 0, SEED)

	var players: Array[BattlePlayerState] = manager.get_players()
	assert_ne(
		players[0].session.get_next_types(7),
		players[1].session.get_next_types(7),
		"Player ごとに Seed がずれる"
	)


func test_same_battle_seed_reproduces_the_same_battle() -> void:
	manager.setup(1, 2, SEED)
	var other := BattleManager.new(GameRules.create_default())
	other.setup(1, 2, SEED)

	for index in range(manager.get_player_count()):
		assert_eq(
			manager.get_players()[index].session.get_next_types(7),
			other.get_players()[index].session.get_next_types(7),
			"同じ Battle Seed からは同じ並び"
		)


# --- 生存人数と脱落 --------------------------------------------------------


func test_elimination_reduces_the_alive_count() -> void:
	manager.setup(1, 3, SEED)

	manager.eliminate_player(0)

	assert_eq(manager.get_alive_count(), 3, "生存人数が減る")
	assert_false(manager.get_player(0).alive, "脱落した Player は alive=false")


func test_rank_is_the_alive_count_at_elimination() -> void:
	manager.setup(1, 9, SEED)
	watch_signals(manager)

	manager.eliminate_player(0)

	assert_eq(manager.get_player(0).rank, 10, "残り 10 人で脱落したら Rank 10")
	assert_signal_emitted_with_parameters(manager, "player_eliminated", [0, 10])


func test_eliminating_twice_is_ignored() -> void:
	manager.setup(1, 3, SEED)
	manager.eliminate_player(0)

	manager.eliminate_player(0)

	assert_eq(manager.get_alive_count(), 3, "2 回目は無視する")


func test_eliminating_an_invalid_id_is_safe() -> void:
	manager.setup(1, 3, SEED)

	manager.eliminate_player(999)

	assert_eq(manager.get_alive_count(), 4, "存在しない ID では何も起きない")


func test_alive_players_exclude_the_eliminated() -> void:
	manager.setup(1, 3, SEED)

	manager.eliminate_player(1)

	for player in manager.get_alive_players():
		assert_ne(player.player_id, 1, "脱落者は含まれない")


# --- 決着 ------------------------------------------------------------------


func test_battle_finishes_when_one_player_remains() -> void:
	manager.setup(1, 1, SEED)
	watch_signals(manager)

	manager.eliminate_player(1)

	assert_true(manager.is_finished(), "1 人になったら終了")
	assert_eq(manager.get_player(0).rank, 1, "最後の 1 人が Rank 1")
	assert_signal_emitted_with_parameters(manager, "battle_finished", [0])


func test_no_further_updates_after_finishing() -> void:
	manager.setup(1, 1, SEED)
	manager.eliminate_player(1)

	manager.update(1.0)

	assert_true(manager.is_finished(), "終了状態のまま")


# --- Battle Phase（要件定義 §93） -------------------------------------------


func test_phase_follows_the_alive_count() -> void:
	assert_eq(BattlePhase.from_alive_count(99), BattlePhase.Phase.OPENING, "99 人")
	assert_eq(BattlePhase.from_alive_count(50), BattlePhase.Phase.EARLY, "50 人")
	assert_eq(BattlePhase.from_alive_count(20), BattlePhase.Phase.MIDDLE, "20 人")
	assert_eq(BattlePhase.from_alive_count(10), BattlePhase.Phase.LATE, "10 人")
	assert_eq(BattlePhase.from_alive_count(5), BattlePhase.Phase.FINAL, "5 人")
	assert_eq(BattlePhase.from_alive_count(2), BattlePhase.Phase.DUEL, "2 人")
	assert_eq(BattlePhase.from_alive_count(1), BattlePhase.Phase.FINISHED, "1 人")


func test_phase_change_is_reported() -> void:
	manager.setup(1, 5, SEED)
	assert_eq(manager.get_phase(), BattlePhase.Phase.LATE, "前提: 6 人なので LATE（10 人以下）")
	watch_signals(manager)

	manager.eliminate_player(0)
	manager.eliminate_player(1)
	manager.eliminate_player(2)
	manager.eliminate_player(3)

	assert_eq(manager.get_phase(), BattlePhase.Phase.DUEL, "2 人になると DUEL")
	assert_signal_emitted(manager, "phase_changed", "段階の変化が通知される")
