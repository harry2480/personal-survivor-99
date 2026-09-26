extends GutTest

## Player 数を段階的に引き上げた完走テスト（要件定義 §44 / §116）。
##
## 2 → 10 → 30 → 50 → 99 の各構成で、Battle が最後の 1 人まで完走し、
## Rank と Target が壊れないことを見る（#46 の完了条件）。
##
## Human 1 人 + CPU 残りの構成。Human は「一定間隔で Hard Drop を打つだけ」の
## 最小の操作で進める。狙いは強さではなく、**開始から終了まで Crash せず
## 決着する**ことの確認。

## カバレッジ計測で、人数の多い Battle を飛ばすための判定。
const CoverageGuard = preload("res://tests/coverage_guard.gd")

const SEED: int = 20260922
const TIME_LIMIT_SEC: float = 300.0
const FRAME_DELTA: float = 1.0 / 60.0
const FRAMES_PER_DROP: int = 10

var runners: Array = []

# 人数ごとに一度だけ走らせた Battle。完走・Frame Time・再現性の確認で使い回す。
# 99 人戦は 1 回 40 秒近くかかるので、テストごとに走らせ直さない。
var _finished_battles: Dictionary = {}


func after_each() -> void:
	for runner in runners:
		runner.dispose()
	runners.clear()


func after_all() -> void:
	for runner in _finished_battles.values():
		runner.dispose()
	_finished_battles.clear()


func _distribution() -> CpuDistribution:
	var distribution := CpuDistribution.create_default()
	distribution.average_strength = 70.0
	distribution.minimum_strength = 30.0
	distribution.maximum_strength = 110.0
	distribution.strength_variance = 20.0
	return distribution


## Human 1 人 + CPU で Battle を作る。
func _new_battle(player_count: int) -> CpuBattleRunner:
	var runner := CpuBattleRunner.new(player_count - 1, _distribution(), null, SEED, 1)
	runners.append(runner)
	return runner


## 決着するまで進める。Human は一定間隔で Hard Drop を打つ。
func _run(runner: CpuBattleRunner) -> bool:
	var frame: int = 0
	while runner.get_elapsed_sec() < TIME_LIMIT_SEC and not runner.get_manager().is_finished():
		# Human の操作も同じフレームの負荷として測る（フレーム予算の確認に効く）。
		var drops: bool = frame % FRAMES_PER_DROP == 0
		runner.step(FRAME_DELTA, _hard_drop_humans.bind(runner) if drops else Callable())
		frame += 1

	if not runner.get_manager().is_finished():
		# 時間切れは Runner 側の畳み込みに任せる（同じ経路を通す）。
		runner.run(runner.get_elapsed_sec())
	return runner.get_manager().is_finished()


func _hard_drop_humans(runner: CpuBattleRunner) -> void:
	for human in runner.get_human_players():
		if human.alive and human.session != null and not human.session.is_over():
			human.session.hard_drop()


func _assert_ranks_are_consistent(runner: CpuBattleRunner, player_count: int) -> void:
	var ranks: Array[int] = []
	for result in runner.get_results():
		assert_gt(result.rank, 0, "Player %d の Rank が確定する" % result.player_id)
		ranks.append(result.rank)

	ranks.sort()
	var expected: Array[int] = []
	for rank in range(1, player_count + 1):
		expected.append(rank)
	assert_eq(ranks, expected, "%d 人ぶんの Rank が 1 から重複なく並ぶ" % player_count)


func _assert_targets_are_safe(runner: CpuBattleRunner) -> void:
	# 要件定義 §53: 自分を狙わない / Dead Player を狙わない / Invalid ID を出さない。
	var manager: BattleManager = runner.get_manager()
	for player in manager.get_players():
		if player.current_target == TargetMode.NO_TARGET:
			continue
		assert_ne(player.current_target, player.player_id, "自分を狙わない")
		var target: BattlePlayerState = manager.get_player(player.current_target)
		assert_not_null(target, "存在しない ID を狙わない")


func _run_scaling_case(player_count: int) -> CpuBattleRunner:
	if not _finished_battles.has(player_count):
		var battle := CpuBattleRunner.new(player_count - 1, _distribution(), null, SEED, 1)
		_run(battle)
		_finished_battles[player_count] = battle
	var runner: CpuBattleRunner = _finished_battles[player_count]

	assert_true(runner.get_manager().is_finished(), "%d 人戦が完走する" % player_count)
	assert_eq(runner.get_manager().get_alive_count(), 1, "生き残りは 1 人")
	assert_eq(runner.get_manager().get_player_count(), player_count, "人数の構成どおり")
	_assert_ranks_are_consistent(runner, player_count)
	_assert_targets_are_safe(runner)
	return runner


# --- 段階的なスケーリング（要件定義 §116） ---------------------------------


func test_two_player_battle_finishes() -> void:
	_run_scaling_case(2)


func test_ten_player_battle_finishes() -> void:
	_run_scaling_case(10)


func test_thirty_player_battle_finishes() -> void:
	if CoverageGuard.skip_heavy_test(self):
		return
	_run_scaling_case(30)


func test_fifty_player_battle_finishes() -> void:
	if CoverageGuard.skip_heavy_test(self):
		return
	_run_scaling_case(50)


func test_ninety_nine_player_battle_finishes() -> void:
	if CoverageGuard.skip_heavy_test(self):
		return
	# 要件定義 §44 の標準構成（Human × 1 + CPU × 98）。
	var runner: CpuBattleRunner = _run_scaling_case(99)

	assert_gt(runner.get_combat_elimination_count(), 0, "Garbage を受けた Player が実際に脱落する")
	gut.p(
		(
			"99 人戦: 平均 %.3f ms/frame（%.0f FPS 相当）/ 最大 %.3f ms / %d frames / Top Out %d 人 / 時間切れ %s"
			% [
				runner.get_average_frame_msec(),
				runner.get_estimated_fps(),
				runner.get_max_frame_msec(),
				runner.get_frame_count(),
				runner.get_combat_elimination_count(),
				runner.is_timed_out()
			]
		)
	)


# --- 計測（#46 の完了条件） -------------------------------------------------


func test_frame_time_is_measured() -> void:
	# 記録されることを見るだけなので、軽い 10 人戦で見る（カバレッジ計測でも走る）。
	var runner: CpuBattleRunner = _run_scaling_case(10)

	assert_gt(runner.get_frame_count(), 0, "フレーム数が記録される")
	assert_gt(runner.get_average_frame_msec(), 0.0, "平均 Frame Time が記録される")
	assert_gte(runner.get_max_frame_msec(), runner.get_average_frame_msec(), "最大は平均以上")
	assert_gt(runner.get_estimated_fps(), 0.0, "FPS 換算が出る")
	assert_eq(runner.get_detailed_count(), 0, "Lightweight だけで回している（#42）")


func test_simulation_keeps_the_frame_budget() -> void:
	if CoverageGuard.skip_heavy_test(self):
		return
	# 要件定義 §105: 99 人戦で平均 60 FPS 以上。描画を含まない Simulation の
	# 時間がここで予算（16.6 ms）を食い潰していないことを見る。
	# 実時間を測るので、処理が数倍遅くなるカバレッジ計測では意味がなく、飛ばす。
	var runner: CpuBattleRunner = _run_scaling_case(99)

	assert_lt(runner.get_average_frame_msec(), 16.6, "99 人でも 1 フレームの予算に収まる")


# --- Human を混ぜた Runner --------------------------------------------------


func _small_battle() -> CpuBattleRunner:
	var runner := CpuBattleRunner.new(2, _distribution(), null, SEED, 1)
	runners.append(runner)
	return runner


func test_human_pieces_fall_with_normal_gravity() -> void:
	# Lightweight の CPU のために Runner のルールは Gravity 0 だが、Human は通常どおり落ちる。
	var runner: CpuBattleRunner = _small_battle()
	var human: BattlePlayerState = runner.get_human_players()[0]
	var start_y: int = human.session.get_active_piece().position.y

	for _frame in range(120):
		runner.step(FRAME_DELTA)

	assert_gt(human.session.get_active_piece().position.y, start_y, "操作しなくてもピースが落ちる")


func test_human_garbage_is_attributed_when_it_lands() -> void:
	# 送った時点ではなく、Human の盤面へ実際に積まれた時点で KO 帰属を記録する。
	var runner: CpuBattleRunner = _small_battle()
	var human: BattlePlayerState = runner.get_human_players()[0]
	var source: BattlePlayerState = runner.get_manager().get_player(human.player_id + 1)
	source.current_target = human.player_id

	runner._send_attack(source.player_id, 2)
	assert_eq(runner._attribution.get_history(human.player_id).size(), 0, "送っただけでは記録しない")

	var drops: Callable = _hard_drop_humans.bind(runner)
	for frame in range(int(3.0 / FRAME_DELTA)):
		runner.step(FRAME_DELTA, drops if frame % FRAMES_PER_DROP == 0 else Callable())

	var from_source: int = 0
	for application in runner._attribution.get_history(human.player_id):
		if application.source_player_id == source.player_id:
			from_source += application.line_count
	assert_gt(from_source, 0, "積まれた行が送り手に帰属する")


func test_human_elimination_is_not_reported_as_a_cpu() -> void:
	var runner: CpuBattleRunner = _small_battle()
	var human: BattlePlayerState = runner.get_human_players()[0]
	var reported: Array = []
	runner.cpu_eliminated.connect(
		func(player_id: int, _rank: int) -> void: reported.append(player_id)
	)

	runner.get_manager().eliminate_player(human.player_id)

	assert_false(human.player_id in reported, "Human の脱落を CPU の脱落として知らせない")


func test_frame_time_includes_the_human_input() -> void:
	# Human の操作も同じフレームの負荷として測る。重い操作を渡すと Frame Time に出る。
	var runner: CpuBattleRunner = _small_battle()
	var heavy_input: Callable = func() -> void:
		var until: int = Time.get_ticks_usec() + 3000
		while Time.get_ticks_usec() < until:
			pass

	runner.step(FRAME_DELTA, heavy_input)

	assert_gte(runner.get_max_frame_msec(), 3.0, "操作にかかった時間もフレームに入る")


# --- 再現性（要件定義 §110） -------------------------------------------------


func test_scaling_battles_are_reproducible() -> void:
	if CoverageGuard.skip_heavy_test(self):
		return
	# 完走の確認で走らせた 30 人戦と、同じ Seed で走らせ直した 30 人戦を比べる。
	var first: CpuBattleRunner = _run_scaling_case(30)
	var second: CpuBattleRunner = _new_battle(30)
	_run(second)

	var first_ranks: Array = []
	var second_ranks: Array = []
	for result in first.get_results():
		first_ranks.append([result.player_id, result.rank])
	for result in second.get_results():
		second_ranks.append([result.player_id, result.rank])

	assert_eq(first_ranks, second_ranks, "同じ Seed からは同じ決着になる")
