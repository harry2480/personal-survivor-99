extends SceneTree

## 同じ Seed から同じ決着になることを確かめる（要件定義 §110 / §111）。
##
## 最適化の前後で結果が変わっていないかを見るための道具（#55 の完了条件）。
## 順位の並びをそのまま出すので、変更前後の出力を diff すれば分かる。
##
## 実行は scripts/verify-determinism.sh。

const SEEDS: Array[int] = [20260922, 1, 999]
const PLAYER_COUNT: int = 99
const TIME_LIMIT_SEC: float = 120.0
const FRAME_DELTA: float = 1.0 / 60.0
const FRAMES_PER_DROP: int = 10
const SHOWN_RANKS: int = 10


func _init() -> void:
	print("決着の再現性（Human 1 人 + CPU 98 / 上限 %.0f 秒）" % TIME_LIMIT_SEC)
	print("")

	for battle_seed in SEEDS:
		var first: String = _run(battle_seed)
		var second: String = _run(battle_seed)
		print("seed=%d" % battle_seed)
		print("  上位 %d: %s" % [SHOWN_RANKS, first])
		print("  再実行一致: %s" % ("はい" if first == second else "いいえ"))

	print("")
	print("最適化の前後でこの出力が変わらなければ、結果は同じ。")
	quit()


func _run(battle_seed: int) -> String:
	var distribution := CpuDistribution.create_default()
	var runner := CpuBattleRunner.new(PLAYER_COUNT - 1, distribution, null, battle_seed, 1)
	var frame: int = 0

	while runner.get_elapsed_sec() < TIME_LIMIT_SEC and not runner.get_manager().is_finished():
		if frame % FRAMES_PER_DROP == 0:
			for human in runner.get_human_players():
				if human.alive and human.session != null and not human.session.is_over():
					human.session.hard_drop()
		runner.step(FRAME_DELTA)
		frame += 1
	runner.run(runner.get_elapsed_sec())

	var ranks: Array[String] = []
	for result in runner.get_results():
		if result.rank <= SHOWN_RANKS:
			ranks.append("%d:P%d" % [result.rank, result.player_id])
	runner.dispose()
	return " ".join(ranks)
