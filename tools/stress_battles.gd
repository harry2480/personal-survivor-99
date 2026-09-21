extends SceneTree

## 連続試合でメモリが増え続けないかを見る（要件定義 §105 / MVP 受入条件 30）。
##
## Battle を何度も作って捨て、そのたびに使用メモリと Object の数を記録する
## （#56 の完了条件）。増え続けていれば、どこかで参照が残っている。
##
## 実行は scripts/stress-battles.sh。

const SEED: int = 20260922
const BATTLES: int = 50
const PLAYER_COUNT: int = 30
const TIME_LIMIT_SEC: float = 60.0
const FRAME_DELTA: float = 1.0 / 60.0
const FRAMES_PER_DROP: int = 10

## 何試合ごとに記録するか。
const REPORT_INTERVAL: int = 10


func _init() -> void:
	print("連続試合のメモリ（%d 人戦 × %d 試合 / Seed %d）" % [PLAYER_COUNT, BATTLES, SEED])
	print("")
	print("| 試合 | 静的メモリ (MB) | Object 数 | 孤立 Node 数 |")
	print("|---|---|---|---|")

	_report(0)
	for index in range(BATTLES):
		_run_battle(SEED + index)
		if (index + 1) % REPORT_INTERVAL == 0:
			_report(index + 1)

	print("")
	print("試合数が増えてもメモリと Object 数が横ばいなら、リークしていない。")
	quit()


func _run_battle(battle_seed: int) -> void:
	var runner := CpuBattleRunner.new(
		PLAYER_COUNT - 1, CpuDistribution.create_default(), null, battle_seed, 1
	)
	runner.enable_scheduling()

	var frame: int = 0
	while runner.get_elapsed_sec() < TIME_LIMIT_SEC and not runner.get_manager().is_finished():
		if frame % FRAMES_PER_DROP == 0:
			for human in runner.get_human_players():
				if human.alive and human.session != null and not human.session.is_over():
					human.session.hard_drop()
		runner.step(FRAME_DELTA)
		frame += 1

	runner.run(runner.get_elapsed_sec())
	# 捨てる前に購読を切る。切り忘れると RefCounted 同士が参照し合って残る。
	runner.dispose()


func _report(battles: int) -> void:
	print(
		(
			"| %d | %.2f | %d | %d |"
			% [
				battles,
				float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0,
				int(Performance.get_monitor(Performance.OBJECT_COUNT)),
				int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
			]
		)
	)
