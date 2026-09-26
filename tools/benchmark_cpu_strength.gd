extends SceneTree

## Strength ごとの CPU の強さを測る（要件定義 §86 / §115）。
##
## CPU 同士を戦わせ、Strength ごとの勝率・平均 Rank・平均 Attack を出す。
## Strength Mapping（要件定義 §78）を変えたときに、「上げたら本当に強く
## なったか」を数字で確かめるために使う。
##
## 実行時間が長いので CI の必須 check には入れない（#45 の制約）。
## 実行は scripts/benchmark-cpu-strength.sh。

const SEED: int = 20260922
## 試合数。Strength の数（7）の倍数にして、どの Strength も全部の席を同じ回数だけ回す。
const BATTLES: int = 28
const TIME_LIMIT_SEC: float = 180.0


func _init() -> void:
	var mapping: CpuStrengthMapping = load("res://config/cpu_strength_mapping.tres")
	var benchmark := CpuBenchmark.new(mapping)
	benchmark.set_time_limit_sec(TIME_LIMIT_SEC)

	print("CPU Benchmark（1 試合 = 各 Strength 1 体ずつ / %d 試合）" % BATTLES)
	print("Seed: %d、1 試合の上限: %.0f 秒" % [SEED, TIME_LIMIT_SEC])
	print("")

	var started_msec: int = Time.get_ticks_msec()
	var results: Array[CpuBenchmark.StrengthResult] = benchmark.run_strength_sweep(
		CpuBenchmark.default_strengths(), BATTLES, SEED
	)
	var elapsed_sec: float = float(Time.get_ticks_msec() - started_msec) / 1000.0

	print(CpuBenchmark.format_report(results))
	print("")
	print("計測にかかった時間: %.1f 秒" % elapsed_sec)
	print("")
	print("平均 Rank が Strength の順に並んでいれば、Strength Mapping は素直に効いている。")
	quit()
