extends SceneTree

## 99 人戦の内訳を測る（要件定義 §85 / §102 / §105）。
##
## 1 フレームの中で、どこに時間がかかっているかを部位ごとに測る（#55 の完了条件）。
## 当て推量で最適化しないための土台。
##
## 測るのは Simulation だけ（描画は含まない）。描画込みの FPS は実機で測る。
## 実行は scripts/profile-battle.sh。

const SEED: int = 20260922
const PLAYER_COUNT: int = 99
const FRAMES: int = 1800
const FRAME_DELTA: float = 1.0 / 60.0
const FRAMES_PER_DROP: int = 10
const FRAME_BUDGET_MS: float = 1000.0 / 60.0

var _totals: Dictionary = {}
var _counts: Dictionary = {}


func _init() -> void:
	print("99 人戦の内訳（Human 1 人 + CPU 98 / %d フレーム / Seed %d）" % [FRAMES, SEED])
	print("1 フレームの予算: %.2f ms（60fps）" % FRAME_BUDGET_MS)
	print("")

	_measure()

	print("| 部位 | 合計 (ms) | 1 フレーム平均 (ms) | 割合 |")
	print("|---|---|---|---|")
	var grand_total: float = 0.0
	for key in _totals:
		grand_total += _totals[key]
	for key in _totals:
		print(
			(
				"| %s | %.1f | %.4f | %.1f%% |"
				% [
					key,
					_totals[key],
					_totals[key] / float(FRAMES),
					_totals[key] / maxf(grand_total, 0.0001) * 100.0
				]
			)
		)
	print("")
	print("| 合計 | %.1f | %.4f | 100%% |" % [grand_total, grand_total / float(FRAMES)])
	print("")
	print("割合の大きい部位から手を入れる。数字の裏付けのない最適化はしない。")
	quit()


func _measure() -> void:
	var distribution := CpuDistribution.create_default()
	var runner := CpuBattleRunner.new(PLAYER_COUNT - 1, distribution, null, SEED, 1)
	var scheduler: CpuScheduler = runner.enable_scheduling()
	var manager: BattleManager = runner.get_manager()
	var targets: TargetManager = runner.get_target_manager()
	var cpus: CpuManager = runner.get_cpu_manager()

	for frame in range(FRAMES):
		if manager.is_finished():
			break

		if frame % FRAMES_PER_DROP == 0:
			for human in runner.get_human_players():
				if human.alive and human.session != null and not human.session.is_over():
					human.session.hard_drop()

		_time("battle_update", func() -> void: manager.update(FRAME_DELTA))
		_time("target_update", func() -> void: targets.update_all_targets())
		_time("cpu_update", func() -> void: scheduler.update(FRAME_DELTA))
		_time("cpu_indicators", func() -> void: _read_indicators(manager, cpus))

	runner.dispose()


func _read_indicators(manager: BattleManager, cpus: CpuManager) -> void:
	# Opponent Grid（#49）と HUD（#50）が読む値の取り出し。
	for player in manager.get_alive_players():
		if not player.is_human():
			cpus.get_indicators(player.player_id)


func _time(key: String, body: Callable) -> void:
	var started: int = Time.get_ticks_usec()
	body.call()
	var elapsed_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	_totals[key] = _totals.get(key, 0.0) + elapsed_ms
	_counts[key] = _counts.get(key, 0) + 1
