extends SceneTree

## Player 数ごとの Simulation 負荷を測る（要件定義 §102 / §105）。
##
## 2 → 10 → 30 → 50 → 99 の各構成で Battle を回し、1 フレームの処理時間と
## FPS 換算、Detailed CPU の数を出す（#46 の完了条件）。
##
## 描画を含まない Simulation だけの値。実機の FPS は Phase 10（#55）で測る。
## 実行は scripts/benchmark-battle-scaling.sh。

const SEED: int = 20260922
const PLAYER_COUNTS: Array[int] = [2, 10, 30, 50, 99]
const TIME_LIMIT_SEC: float = 300.0
const FRAME_DELTA: float = 1.0 / 60.0
const FRAMES_PER_DROP: int = 10
const FRAME_BUDGET_MS: float = 1000.0 / 60.0


func _init() -> void:
	print("Player 数ごとの Simulation 負荷（Human 1 人 + CPU / Seed %d）" % SEED)
	print("1 フレームの予算: %.2f ms（60fps）" % FRAME_BUDGET_MS)
	print("")
	print("| Player | 平均 (ms) | 最大 (ms) | FPS 換算 | Detailed CPU | Top Out | 決着 |")
	print("|---|---|---|---|---|---|---|")

	for player_count in PLAYER_COUNTS:
		_measure(player_count)

	print("")
	print("Detailed CPU は Hybrid の割り当て結果（要件定義 §80〜§83）。")
	print("時間切れは上限 %.0f 秒で畳んだことを表す。" % TIME_LIMIT_SEC)
	quit()


func _measure(player_count: int) -> void:
	var distribution := CpuDistribution.create_default()
	distribution.average_strength = 70.0
	distribution.minimum_strength = 30.0
	distribution.maximum_strength = 110.0
	distribution.strength_variance = 20.0

	var runner := CpuBattleRunner.new(player_count - 1, distribution, null, SEED, 1)
	var frame: int = 0
	while runner.get_elapsed_sec() < TIME_LIMIT_SEC and not runner.get_manager().is_finished():
		if frame % FRAMES_PER_DROP == 0:
			for human in runner.get_human_players():
				if human.alive and human.session != null and not human.session.is_over():
					human.session.hard_drop()
		runner.step(FRAME_DELTA)
		frame += 1
	runner.run(runner.get_elapsed_sec())

	print(
		(
			"| %d | %.3f | %.3f | %.0f | %d | %d | %s |"
			% [
				player_count,
				runner.get_average_frame_msec(),
				runner.get_max_frame_msec(),
				runner.get_estimated_fps(),
				runner.get_detailed_count(),
				runner.get_combat_elimination_count(),
				"時間切れ" if runner.is_timed_out() else "決着"
			]
		)
	)
	runner.dispose()
