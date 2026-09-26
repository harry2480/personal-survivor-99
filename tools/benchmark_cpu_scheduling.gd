extends SceneTree

## CPU 更新の分散が 1 フレームのコストに効くかを測る（要件定義 §84 / §104）。
##
## 98 体の CPU を、分散なし（毎フレーム全員）と分散あり（組に分ける）で回し、
## **1 フレームあたりの CPU 更新時間**と、そのフレームで動かした CPU の数を出す。
##
## Human Input は「前のフレームの処理が終わるまで待つ」ため、1 フレームの
## CPU コストが下がるほど Input の待ちも短くなる（MVP 受入条件 29）。
##
## 実行は scripts/benchmark-cpu-scheduling.sh。

const SEED: int = 20260922
const CPU_COUNT: int = 98
const FRAMES: int = 1800
const FRAME_DELTA: float = 1.0 / 60.0
const SLICE_COUNTS: Array[int] = [1, 2, 4, 8]
const FRAME_BUDGET_MS: float = 1000.0 / 60.0

## 計測の回数。回ごとに計測順を逆にし、先に測る側への偏りを打ち消す。
const ROUNDS: int = 4

## 計測を始める前に空回しするフレーム数。
##
## 1 回目の更新には確保や遅延読み込みが混ざるため、そのぶんを外す。
const WARMUP_FRAMES: int = 120


func _init() -> void:
	# 最初の計測だけがプロセス起動の影響を受けるため、捨てる計測を 1 回挟む。
	_warmup()

	print("CPU 更新の分散（CPU %d 体 / %d フレーム / Seed %d）" % [CPU_COUNT, FRAMES, SEED])
	print("1 フレームの予算: %.2f ms（60fps）" % FRAME_BUDGET_MS)
	print("")

	# 分割数ごとのサンプルを、全回ぶん集める。1 は分散なし。
	var samples: Dictionary = {}
	var updated: Dictionary = {}
	for slice_count in SLICE_COUNTS:
		samples[slice_count] = []
		updated[slice_count] = 0

	for round_index in range(ROUNDS):
		# 偶数回は「なし → 8 分割」、奇数回は「8 分割 → なし」の順に測る。
		var order: Array[int] = SLICE_COUNTS.duplicate()
		if round_index % 2 == 1:
			order.reverse()
		var labels: Array[String] = []
		for slice_count in order:
			labels.append(_label(slice_count))
			var result: Array = _measure(slice_count)
			samples[slice_count].append_array(result[0])
			updated[slice_count] = maxi(updated[slice_count], result[1])
		print("計測 %d 回目の順序: %s" % [round_index + 1, " → ".join(labels)])

	print("")
	print("| 分散 | 平均 (ms) | p99 (ms) | 最大 (ms) | 1 フレームで動かす CPU |")
	print("|---|---|---|---|---|")
	for slice_count in SLICE_COUNTS:
		_print_row(_label(slice_count), samples[slice_count], updated[slice_count])

	print("")
	print("%d 回ぶんのサンプルをまとめた値。回ごとに計測順を逆にしている。" % ROUNDS)
	print("分散しても進めるゲーム内時間は変わらない。効くのは「重いフレーム」なので p99 を見る。")
	print("")
	print("負荷が続いた場合は CpuSchedulePolicy に従って Lookahead → Beam Width →")
	print("Detailed CPU 数の順に削る（要件定義 §84 の優先順位）。")
	quit()


func _warmup() -> void:
	var cpus: CpuManager = _new_cpus()
	for _frame in range(FRAMES):
		cpus.update(FRAME_DELTA)


func _new_cpus() -> CpuManager:
	var manager := BattleManager.new()
	manager.setup(1, CPU_COUNT, SEED)
	var cpus := CpuManager.new(manager, SEED, 0)
	cpus.register_all_from_distribution(CpuDistribution.create_default(), null, SEED)
	return cpus


func _label(slice_count: int) -> String:
	return "なし" if slice_count <= 1 else "%d 分割" % slice_count


# 1 回ぶん測り、[サンプル, 1 フレームで動かした CPU の最大数] を返す。
func _measure(slice_count: int) -> Array:
	if slice_count <= 1:
		return _measure_without_scheduling()
	return _measure_with_scheduling(slice_count)


func _measure_without_scheduling() -> Array:
	var cpus: CpuManager = _new_cpus()
	var samples: Array[int] = []

	for _frame in range(WARMUP_FRAMES):
		cpus.update(FRAME_DELTA)

	for _frame in range(FRAMES):
		var started: int = Time.get_ticks_usec()
		cpus.update(FRAME_DELTA)
		samples.append(Time.get_ticks_usec() - started)

	return [samples, CPU_COUNT]


func _measure_with_scheduling(slice_count: int) -> Array:
	var cpus: CpuManager = _new_cpus()
	var policy := CpuSchedulePolicy.create_default()
	policy.slice_count = slice_count
	var scheduler := CpuScheduler.new(cpus, policy)

	var samples: Array[int] = []
	var max_updated: int = 0

	for _frame in range(WARMUP_FRAMES):
		scheduler.update(FRAME_DELTA)

	for _frame in range(FRAMES):
		var started: int = Time.get_ticks_usec()
		scheduler.update(FRAME_DELTA)
		samples.append(Time.get_ticks_usec() - started)
		max_updated = maxi(max_updated, scheduler.get_last_update_count())

	return [samples, max_updated]


# 平均だけでは分散の効果が見えにくい。効くのは「重いフレーム」なので p99 と最大も出す。
func _print_row(label: String, samples: Array, updated: int) -> void:
	var sorted_samples: Array = samples.duplicate()
	sorted_samples.sort()

	var total: int = 0
	for sample in samples:
		total += sample
	var p99: int = sorted_samples[mini(
		sorted_samples.size() - 1, int(sorted_samples.size() * 0.99)
	)]

	print(
		(
			"| %s | %.4f | %.4f | %.4f | %d |"
			% [
				label,
				float(total) / float(samples.size()) / 1000.0,
				float(p99) / 1000.0,
				float(sorted_samples[sorted_samples.size() - 1]) / 1000.0,
				updated
			]
		)
	)
