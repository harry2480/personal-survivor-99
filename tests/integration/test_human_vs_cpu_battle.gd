extends GutTest

## Human 1 人 + CPU 1 人の対戦が最後まで成立することの確認。
##
## Phase 4 の完了条件「Human vs CPU 1 対 1 が終了まで成立する」に対応する。
## CPU の思考は Phase 5（#38〜#42）なので、ここでは「Hard Drop を打ち続けるだけ」の
## 最小の操作で進める。狙いは強さではなく、**開始から終了まで Crash せず決着する**
## ことの確認。

const SEED: int = 20260920
const MAX_FRAMES: int = 60 * 120  # 2 分ぶん。これで決着しなければ異常とみなす。
const FRAME_DELTA: float = 1.0 / 60.0
const FRAMES_PER_DROP: int = 10

var _battles: Array = []


func after_each() -> void:
	for battle in _battles:
		battle.dispose()
	_battles.clear()


func _new_battle(battle_seed: int = SEED) -> Battle:
	var battle := Battle.new(battle_seed)
	_battles.append(battle)
	return battle


class Battle:
	extends RefCounted

	var manager: BattleManager
	var targets: TargetManager
	var router: GarbageRouter
	var ko: KoSystem
	var ko_events: Array = []
	var rank_events: Array = []
	var _listeners: Array = []

	func _init(battle_seed: int) -> void:
		var rules := GameRules.create_default()
		rules.gravity_cells_per_second = 20.0
		rules.lock_delay_sec = 0.05

		var balance := GameBalance.create_default()
		balance.garbage_delay_sec = 0.5
		# 1 対 1 で決着が付くよう、Single でも Garbage が飛ぶようにする。
		balance.line_attack_table = PackedInt32Array([0, 1, 2, 3, 4])

		manager = BattleManager.new(rules, balance)
		manager.setup(1, 1, battle_seed)
		targets = TargetManager.new(manager, battle_seed)
		router = GarbageRouter.new(manager, balance)
		ko = KoSystem.new(manager, router.get_attribution(), balance)

		var on_ko: Callable = func(victim: int, attacker: int): ko_events.append([victim, attacker])
		var on_rank: Callable = func(player: int, rank: int): rank_events.append([player, rank])
		ko.player_ko.connect(on_ko)
		ko.rank_changed.connect(on_rank)
		_listeners = [on_ko, on_rank]

		targets.update_all_targets()

	## 購読を解除して参照の循環を切る。Battle を捨てる前に必ず呼ぶ。
	func dispose() -> void:
		if not _listeners.is_empty():
			ko.player_ko.disconnect(_listeners[0])
			ko.rank_changed.disconnect(_listeners[1])
			_listeners.clear()
		router.dispose()
		ko.dispose()

	## 各 Player の盤面を「あと 1 マスで 1 行揃う」状態にし、縦 I を左端へ用意する。
	##
	## 適当に積むだけでは行がなかなか揃わず、Garbage が行き来しない。実際の経路
	## （Attack 生成 → Router → 相手の Queue → 盤面へ適用）を通すための仕込み。
	func prepare_line_clear_for_all() -> void:
		for player in manager.get_players():
			var board: Board = player.get_board()
			for offset in range(4):
				for x in range(1, Board.WIDTH):
					board.set_cell(x, Board.TOTAL_HEIGHT - 1 - offset, Piece.Type.I)

			var piece: ActivePiece = player.session.get_active_piece()
			piece.spawn(Piece.Type.I)
			piece.rotation = Piece.Rotation.RIGHT
			piece.position = Vector2i(-2, 0)

	## 決着するまで進める。決着したら true。
	func run(max_frames: int, frame_delta: float) -> bool:
		for _frame in range(max_frames):
			if manager.is_finished():
				return true

			# 最小の操作: 一定間隔で Hard Drop を打つ。毎フレーム打つと数秒で
			# 積み上がって決着してしまい、Garbage の往復が観測できない。
			if _frame % FRAMES_PER_DROP == 0:
				for player in manager.get_alive_players():
					if player.session != null and not player.session.is_over():
						player.session.hard_drop()

			manager.update(frame_delta)
			targets.update_all_targets()
		return manager.is_finished()


func test_one_on_one_battle_finishes() -> void:
	var battle: Battle = _new_battle()

	var finished: bool = battle.run(MAX_FRAMES, FRAME_DELTA)

	assert_true(finished, "開始から終了まで Crash せず決着する")
	assert_eq(battle.manager.get_alive_count(), 1, "生き残りは 1 人")


func test_ranks_are_decided() -> void:
	var battle: Battle = _new_battle()
	battle.run(MAX_FRAMES, FRAME_DELTA)

	var ranks: Array[int] = []
	for player in battle.manager.get_players():
		assert_gt(player.rank, 0, "全員の Rank が確定する")
		ranks.append(player.rank)

	ranks.sort()
	assert_eq(ranks, [1, 2] as Array[int], "Rank 1 と Rank 2 が 1 人ずつ")


func test_winner_is_the_survivor() -> void:
	var battle: Battle = _new_battle()
	battle.run(MAX_FRAMES, FRAME_DELTA)

	var survivors: Array[BattlePlayerState] = battle.manager.get_alive_players()
	assert_eq(survivors.size(), 1, "生存者は 1 人")
	assert_eq(survivors[0].rank, 1, "生存者が Rank 1")
	assert_false(battle.manager.get_player(1 - survivors[0].player_id).alive, "もう 1 人は脱落")


func test_events_are_emitted() -> void:
	var battle: Battle = _new_battle()
	battle.run(MAX_FRAMES, FRAME_DELTA)

	assert_eq(battle.ko_events.size(), 1, "player_ko が 1 回出る")
	assert_eq(battle.rank_events.size(), 2, "rank_changed が 2 回出る（脱落者と勝者）")


func test_phase_reaches_duel_and_finished() -> void:
	var battle: Battle = _new_battle()
	assert_eq(battle.manager.get_phase(), BattlePhase.Phase.DUEL, "2 人なので DUEL から始まる")

	battle.run(MAX_FRAMES, FRAME_DELTA)

	assert_eq(battle.manager.get_phase(), BattlePhase.Phase.FINISHED, "決着すると FINISHED")


func test_battle_is_reproducible() -> void:
	var first: Battle = _new_battle()
	first.run(MAX_FRAMES, FRAME_DELTA)

	var second: Battle = _new_battle()
	second.run(MAX_FRAMES, FRAME_DELTA)

	assert_eq(
		first.ko.get_ranking().get_standings(),
		second.ko.get_ranking().get_standings(),
		"同じ Seed からは同じ決着になる"
	)


func test_garbage_actually_travels_between_players() -> void:
	# 盤面を仕込んで Line Clear を起こし、Attack → Router → 相手の Queue を通す。
	# 適用まで見るのは Unit テスト（test_garbage_router.gd）の担当。
	var battle: Battle = _new_battle()
	var routed: Array = []
	battle.router.garbage_routed.connect(
		func(source: int, target: int, lines: int): routed.append([source, target, lines])
	)
	battle.prepare_line_clear_for_all()

	battle.run(MAX_FRAMES, FRAME_DELTA)

	assert_gt(routed.size(), 0, "対戦中に Garbage が相手へ送られる")
	for entry in routed:
		assert_ne(entry[0], entry[1], "自分から自分へは送らない")
		assert_gt(entry[2], 0, "0 行は送られない")
