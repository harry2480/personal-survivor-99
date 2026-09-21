extends GutTest

## CPU 更新の分散と負荷時の削減の確認（要件定義 §84 / §102〜§104）。
##
## 見るのは 3 つ。
## [br]・1 フレームで動かす CPU の数が分散で減ること
## [br]・分散しても **CPU に渡した時間の合計が変わらない**こと（時間整合性）
## [br]・負荷が続いたら §84 の順に削り、収まったら戻ること

const SEED: int = 20260922
const PLAYER_COUNT: int = 99
const TIME_LIMIT_SEC: float = 120.0
const FRAME_DELTA: float = 1.0 / 60.0
const FRAMES_PER_DROP: int = 10

var runners: Array = []


func after_each() -> void:
	for runner in runners:
		runner.dispose()
	runners.clear()


func _distribution() -> CpuDistribution:
	var distribution := CpuDistribution.create_default()
	distribution.average_strength = 70.0
	distribution.minimum_strength = 30.0
	distribution.maximum_strength = 110.0
	distribution.strength_variance = 20.0
	return distribution


func _new_battle(player_count: int = PLAYER_COUNT) -> CpuBattleRunner:
	var runner := CpuBattleRunner.new(player_count - 1, _distribution(), null, SEED, 1)
	runners.append(runner)
	return runner


func _run(runner: CpuBattleRunner) -> void:
	var frame: int = 0
	while runner.get_elapsed_sec() < TIME_LIMIT_SEC and not runner.get_manager().is_finished():
		if frame % FRAMES_PER_DROP == 0:
			for human in runner.get_human_players():
				if human.alive and human.session != null and not human.session.is_over():
					human.session.hard_drop()
		runner.step(FRAME_DELTA)
		frame += 1
	runner.run(runner.get_elapsed_sec())


func _standings(runner: CpuBattleRunner) -> Array:
	var standings: Array = []
	for result in runner.get_results():
		standings.append([result.player_id, result.rank])
	return standings


# --- 更新の分散（要件定義 §104） --------------------------------------------


func test_only_a_slice_of_cpus_updates_each_frame() -> void:
	var runner: CpuBattleRunner = _new_battle()
	var scheduler: CpuScheduler = runner.enable_scheduling()
	var slices: int = scheduler.get_policy().slice_count

	var counts: Array[int] = []
	for _frame in range(slices * 2):
		runner.step(FRAME_DELTA)
		counts.append(scheduler.get_last_update_count())

	var cpu_count: int = PLAYER_COUNT - 1
	for count in counts:
		assert_lte(count, cpu_count / slices + 1, "1 フレームで動かすのは全体の 1/%d だけ" % slices)
	assert_eq(_sum(counts), cpu_count * 2, "%d フレームで全員が 2 巡する" % (slices * 2))


func test_every_cpu_gets_the_same_simulated_time() -> void:
	# 分散しても 1 体に渡す時間の合計は変わらない（#47 の制約）。
	var runner: CpuBattleRunner = _new_battle(30)
	var scheduler: CpuScheduler = runner.enable_scheduling()
	var slices: int = scheduler.get_policy().slice_count

	for _frame in range(slices * 10):
		runner.step(FRAME_DELTA)

	# 分散の途中では「渡した時間 + 渡していない時間」が経過時間と一致する。
	var expected: float = FRAME_DELTA * float(slices * 10)
	for player_id in runner.get_cpu_manager().get_registered_ids():
		assert_almost_eq(
			scheduler.get_simulated_sec(player_id) + scheduler.get_pending_sec(player_id),
			expected,
			0.0001,
			"Player %d の時間が経過時間と一致する" % player_id
		)
		assert_lte(
			scheduler.get_pending_sec(player_id), FRAME_DELTA * float(slices), "渡し残しは 1 巡ぶんまで"
		)

	# 渡しきれば、渡した時間そのものが経過時間と一致する。
	scheduler.flush()
	for player_id in runner.get_cpu_manager().get_registered_ids():
		assert_almost_eq(
			scheduler.get_simulated_sec(player_id),
			expected,
			0.0001,
			"渡しきると Player %d の時間が揃う" % player_id
		)


func test_pending_time_is_flushed_when_the_battle_ends() -> void:
	var runner: CpuBattleRunner = _new_battle(30)
	var scheduler: CpuScheduler = runner.enable_scheduling()

	# 分散の途中（全員が 1 巡しない長さ）で終わらせる。
	runner.step(FRAME_DELTA)
	runner.run(runner.get_elapsed_sec())

	for player_id in runner.get_cpu_manager().get_registered_ids():
		assert_almost_eq(scheduler.get_simulated_sec(player_id), FRAME_DELTA, 0.0001, "渡し残しがない")


func test_scheduling_keeps_the_battle_consistent() -> void:
	var scheduled: CpuBattleRunner = _new_battle(30)
	scheduled.enable_scheduling()
	_run(scheduled)

	var plain: CpuBattleRunner = _new_battle(30)
	_run(plain)

	# 分散すると Attack を出すフレームが最大 3 フレーム（50 ms）ずれる。
	# 決着そのものが壊れていないことを見る。
	assert_eq(scheduled.get_manager().get_alive_count(), 1, "分散しても決着する")
	assert_eq(_standings(scheduled).size(), _standings(plain).size(), "順位は全員ぶん確定する")


func test_scheduling_spreads_the_cpu_cost_over_frames() -> void:
	# MVP 受入条件 29: CPU 負荷で Human Input が遅れないこと。1 フレームで動かす
	# CPU を減らせば、その分だけ Input の処理が待たされにくくなる。
	#
	# Battle 全体の時間には盤面更新や Target 更新も混ざるため、ここでは
	# **CPU の更新にかかる時間だけ**を測って比べる。
	var manager := BattleManager.new()
	manager.setup(1, PLAYER_COUNT - 1, SEED)
	var plain_cpus := CpuManager.new(manager, SEED, 0)
	plain_cpus.register_all_from_distribution(_distribution(), null, SEED)
	var sliced_cpus := CpuManager.new(manager, SEED, 0)
	sliced_cpus.register_all_from_distribution(_distribution(), null, SEED)
	var scheduler := CpuScheduler.new(sliced_cpus)

	var plain_usec: int = 0
	var sliced_usec: int = 0
	var frames: int = scheduler.get_policy().slice_count * 10
	for _frame in range(frames):
		var started: int = Time.get_ticks_usec()
		plain_cpus.update(FRAME_DELTA)
		plain_usec += Time.get_ticks_usec() - started

		started = Time.get_ticks_usec()
		scheduler.update(FRAME_DELTA)
		sliced_usec += Time.get_ticks_usec() - started

	var plain_msec: float = float(plain_usec) / float(frames) / 1000.0
	var sliced_msec: float = float(sliced_usec) / float(frames) / 1000.0
	gut.p("CPU 更新の 1 フレーム平均: 分散なし %.4f ms / 分散あり %.4f ms" % [plain_msec, sliced_msec])

	assert_lt(sliced_msec, plain_msec, "1 フレームあたりの CPU 更新コストが下がる")


# --- 負荷時の削減（要件定義 §84） -------------------------------------------


func test_degradation_follows_the_priority_order() -> void:
	var runner: CpuBattleRunner = _new_battle(30)
	var scheduler: CpuScheduler = runner.enable_scheduling()
	var policy: CpuSchedulePolicy = scheduler.get_policy()
	var player_id: int = runner.get_cpu_manager().get_registered_ids()[0]
	var profile: CpuProfile = runner.get_cpu_manager().get_profile(player_id)
	var original_beam: int = profile.beam_width

	assert_eq(scheduler.get_level(), CpuSchedulePolicy.Level.NONE, "はじめは削らない")

	# 1 段目: Lookahead（Search Depth）を落とす。
	_observe_slow_frames(scheduler, policy)
	assert_eq(scheduler.get_level(), CpuSchedulePolicy.Level.LOOKAHEAD, "まず Lookahead を削る")
	assert_eq(profile.lookahead, 0, "先読みをやめる")
	assert_eq(profile.beam_width, original_beam, "Beam はまだ触らない")

	# 2 段目: Beam Width を絞る。
	_observe_slow_frames(scheduler, policy)
	assert_eq(scheduler.get_level(), CpuSchedulePolicy.Level.BEAM, "次に Beam Width を絞る")
	assert_lt(profile.beam_width, original_beam, "読む候補を減らす")

	# 3 段目: Detailed CPU の数を減らす。
	_observe_slow_frames(scheduler, policy)
	assert_eq(scheduler.get_level(), CpuSchedulePolicy.Level.DETAILED, "最後に Detailed を減らす")
	assert_eq(
		runner.get_cpu_manager().get_detailed_limit(),
		policy.degraded_detailed_limit,
		"Detailed の上限が下がる"
	)


func test_degradation_recovers_when_the_load_drops() -> void:
	var runner: CpuBattleRunner = _new_battle(30)
	var scheduler: CpuScheduler = runner.enable_scheduling()
	var policy: CpuSchedulePolicy = scheduler.get_policy()
	var profile: CpuProfile = runner.get_cpu_manager().get_profile(
		runner.get_cpu_manager().get_registered_ids()[0]
	)
	var original_lookahead: int = profile.lookahead

	_observe_slow_frames(scheduler, policy)
	assert_eq(scheduler.get_level(), CpuSchedulePolicy.Level.LOOKAHEAD, "一度削る")

	_observe_fast_frames(scheduler, policy)

	assert_eq(scheduler.get_level(), CpuSchedulePolicy.Level.NONE, "余裕が戻れば元へ戻す")
	assert_eq(profile.lookahead, original_lookahead, "Lookahead が戻る")


func test_a_single_slow_frame_does_not_degrade() -> void:
	var runner: CpuBattleRunner = _new_battle(30)
	var scheduler: CpuScheduler = runner.enable_scheduling()

	scheduler.observe_frame_time(100.0)

	assert_eq(scheduler.get_level(), CpuSchedulePolicy.Level.NONE, "瞬間的な跳ねでは削らない")


func test_degradation_emits_a_signal() -> void:
	var runner: CpuBattleRunner = _new_battle(30)
	var scheduler: CpuScheduler = runner.enable_scheduling()
	var events: Array = []
	scheduler.degradation_changed.connect(
		func(previous: int, current: int) -> void: events.append([previous, current])
	)

	_observe_slow_frames(scheduler, scheduler.get_policy())

	assert_eq(events.size(), 1, "段階が変わったら 1 回だけ出る")
	assert_eq(
		events[0],
		[CpuSchedulePolicy.Level.NONE, CpuSchedulePolicy.Level.LOOKAHEAD],
		"どこからどこへ動いたかが分かる"
	)


## 1 段ぶんだけ重いフレームを流す（続いた状態がちょうど閾値に届く数）。
func _observe_slow_frames(scheduler: CpuScheduler, policy: CpuSchedulePolicy) -> void:
	var slow_msec: float = 1000.0 / policy.degrade_fps * 2.0
	for _frame in range(policy.sustained_frames):
		scheduler.observe_frame_time(slow_msec)


## 1 段ぶんだけ軽いフレームを流す。
##
## 平均は窓（[member CpuSchedulePolicy.sample_frames]）で取るため、重いフレームが
## 窓から抜けるまでのぶんを足して流す。
func _observe_fast_frames(scheduler: CpuScheduler, policy: CpuSchedulePolicy) -> void:
	var fast_msec: float = 1000.0 / (policy.restore_fps * 2.0)
	for _frame in range(policy.sample_frames + policy.sustained_frames):
		scheduler.observe_frame_time(fast_msec)


func _sum(values: Array[int]) -> int:
	var total: int = 0
	for value in values:
		total += value
	return total
