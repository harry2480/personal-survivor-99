extends GutTest

## 連続プレイでメモリが増え続けないことの確認
## （要件定義 §105 / MVP 受入条件 30 / #56 の完了条件）。
##
## Battle を作って捨てる、画面を出して閉じる、を繰り返して Object の数が
## 増え続けないことを見る。Godot の RefCounted は参照が切れた時点で解放される
## ので、**増え続けていれば参照が残っている**（購読の切り忘れなど）。

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")
const SEED: int = 20260922
const PLAYER_COUNT: int = 20
const TIME_LIMIT_SEC: float = 20.0
const FRAME_DELTA: float = 1.0 / 60.0
const FRAMES_PER_DROP: int = 10

## 1 回あたりに許す Object の増分。0 にすると Godot 内部の都合で揺れる。
const ALLOWED_GROWTH_PER_ROUND: int = 2


func _object_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))


func _orphan_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))


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
	runner.dispose()


# --- 連続試合（MVP 受入条件 30） --------------------------------------------


func test_repeated_battles_do_not_grow_the_object_count() -> void:
	_run_battle(SEED)  # 1 回目で確保されるぶんを外に出す。
	var before: int = _object_count()

	var rounds: int = 10
	for index in range(rounds):
		_run_battle(SEED + index + 1)

	var growth: int = _object_count() - before
	gut.p("%d 試合ぶんの Object 増分: %d" % [rounds, growth])
	assert_lte(growth, ALLOWED_GROWTH_PER_ROUND * rounds, "試合を重ねても Object が増え続けない")


func test_disposing_a_runner_releases_it() -> void:
	var before: int = _object_count()

	var runner := CpuBattleRunner.new(
		PLAYER_COUNT - 1, CpuDistribution.create_default(), null, SEED, 1
	)
	runner.step(FRAME_DELTA)
	assert_gt(_object_count(), before, "Battle を作れば Object は増える")

	runner.dispose()
	runner = null

	assert_lte(_object_count() - before, ALLOWED_GROWTH_PER_ROUND, "捨てれば元へ戻る")


func test_battle_without_dispose_also_releases() -> void:
	# 購読の持ち方の確認。Runner は method の Callable で購読しており、
	# これは相手を強参照しない（Object ID を持つだけ）ため、循環にならない。
	# lambda で self を捕まえると強参照になり、そこで初めて循環する。
	# dispose はその形の購読（GarbageRouter / KoSystem）のために残してある。
	var before: int = _object_count()

	var runner := CpuBattleRunner.new(9, CpuDistribution.create_default(), null, SEED, 1)
	runner.step(FRAME_DELTA)
	runner = null

	assert_lte(_object_count() - before, ALLOWED_GROWTH_PER_ROUND, "捨て忘れても残らない")


# --- 画面の出し入れ（要件定義 §96 の Restart / Quit to Menu） ---------------


func test_repeated_battle_scenes_do_not_leak_nodes() -> void:
	var setup := BattleSetup.create_default()
	setup.player_count = PLAYER_COUNT
	SceneRouter.set_battle_setup(setup)

	var scene: Node = BATTLE_SCENE.instantiate()
	add_child(scene)
	await wait_frames(2)
	scene.queue_free()
	await wait_frames(2)

	var before: int = _orphan_count()

	for _round in range(3):
		var battle: Node = BATTLE_SCENE.instantiate()
		add_child(battle)
		await wait_frames(2)
		battle.queue_free()
		await wait_frames(2)

	assert_lte(_orphan_count(), before, "画面を出し入れしても孤立した Node が増えない")


func test_restart_and_quit_cycles_stay_stable() -> void:
	SceneRouter.current_state = GameState.State.MAIN_MENU
	var before: int = _object_count()

	for _round in range(10):
		SceneRouter.start_battle()
		SceneRouter.set_battle_paused(true)
		SceneRouter.set_battle_paused(false)
		SceneRouter.quit_to_menu()

	assert_lte(_object_count() - before, ALLOWED_GROWTH_PER_ROUND * 10, "状態遷移でも増えない")
	assert_eq(SceneRouter.current_state, GameState.State.MAIN_MENU, "最後は Main Menu")


# --- 長時間の連続実行 -------------------------------------------------------


func test_long_session_keeps_the_pace() -> void:
	# 長く回しても 1 フレームの時間が悪化しないこと（処理落ちの兆候を見る）。
	var runner := CpuBattleRunner.new(
		PLAYER_COUNT - 1, CpuDistribution.create_default(), null, SEED, 1
	)
	runner.enable_scheduling()

	var first_half: float = _measure_frames(runner, 600)
	var second_half: float = _measure_frames(runner, 600)
	runner.dispose()

	gut.p("前半 %.4f ms/frame → 後半 %.4f ms/frame" % [first_half, second_half])
	assert_lt(second_half, first_half * 3.0 + 0.1, "長く回しても 1 フレームが重くならない")


func _measure_frames(runner: CpuBattleRunner, frames: int) -> float:
	var started: int = Time.get_ticks_usec()
	for _frame in range(frames):
		runner.step(FRAME_DELTA)
	return float(Time.get_ticks_usec() - started) / float(frames) / 1000.0
