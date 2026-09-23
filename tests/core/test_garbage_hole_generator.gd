extends GutTest

## Garbage Hole 生成の Unit テスト（要件定義 §43）。

const SEED_A: int = 20260920
const SEED_B: int = 777


func test_generates_one_hole_per_line() -> void:
	var generator := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE, SEED_A)

	var holes: PackedInt32Array = generator.generate(5)

	assert_eq(holes.size(), 5, "行数ぶん返る")
	for hole in holes:
		assert_true(hole >= 0 and hole < Board.WIDTH, "穴は盤面の中")


func test_zero_lines_generates_nothing() -> void:
	var generator := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE, SEED_A)

	assert_eq(generator.generate(0).size(), 0, "0 行なら空")
	assert_eq(generator.generate(-1).size(), 0, "負の値でも空")


func test_same_column_mode_keeps_one_column() -> void:
	var generator := GarbageHoleGenerator.new(
		GarbageHoleGenerator.Mode.SAME_COLUMN_PER_EVENT, SEED_A
	)

	var holes: PackedInt32Array = generator.generate(6)

	for hole in holes:
		assert_eq(hole, holes[0], "1 回の Garbage では同じ列に開く")


func test_per_line_mode_can_vary() -> void:
	var generator := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE, SEED_A)
	var varied: bool = false

	for _attempt in range(20):
		var holes: PackedInt32Array = generator.generate(6)
		for hole in holes:
			if hole != holes[0]:
				varied = true

	assert_true(varied, "行ごとに位置が変わりうる")


func test_no_repeat_mode_never_repeats_consecutively() -> void:
	var generator := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE_NO_REPEAT, SEED_A)

	for _attempt in range(30):
		var holes: PackedInt32Array = generator.generate(8)
		for index in range(1, holes.size()):
			assert_ne(holes[index], holes[index - 1], "連続して同じ列にはしない")


func test_no_repeat_mode_never_repeats_across_events() -> void:
	# 1 行ずつ別の Garbage が来ると、行は別の Event にまたがる。前の Event の最後の
	# 穴と同じ列が続けて開くと「前回と同じ列は選ばない」方式として成立しない。
	var generator := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE_NO_REPEAT, SEED_A)
	var previous: int = generator.generate(1)[0]

	for _attempt in range(40):
		var hole: int = generator.generate(1)[0]
		assert_ne(hole, previous, "Event をまたいでも続けて同じ列にはしない")
		previous = hole


func test_same_seed_produces_the_same_holes() -> void:
	var first := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE, SEED_A)
	var second := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE, SEED_A)

	assert_eq(first.generate(20), second.generate(20), "同じ Seed からは同じ並び")


func test_different_seed_produces_different_holes() -> void:
	var first := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE, SEED_A)
	var second := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE, SEED_B)

	assert_ne(first.generate(20), second.generate(20), "Seed が違えば並びも変わる")


func test_reset_restarts_the_sequence() -> void:
	var generator := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE, SEED_A)
	var expected: PackedInt32Array = generator.generate(10)

	generator.reset(SEED_A)

	assert_eq(generator.generate(10), expected, "同じ Seed で作り直すと同じ並び")
	assert_eq(generator.get_seed(), SEED_A, "Seed を取得できる")


func test_does_not_depend_on_global_random_state() -> void:
	seed(1)
	randi()
	var first := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE, SEED_A)
	var first_holes: PackedInt32Array = first.generate(15)

	seed(999999)
	for _i in range(50):
		randi()
	var second := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE, SEED_A)

	assert_eq(second.generate(15), first_holes, "グローバル乱数の状態に影響されない")


func test_mode_can_be_changed() -> void:
	var generator := GarbageHoleGenerator.new(GarbageHoleGenerator.Mode.PER_LINE, SEED_A)

	generator.set_mode(GarbageHoleGenerator.Mode.SAME_COLUMN_PER_EVENT)

	assert_eq(generator.get_mode(), GarbageHoleGenerator.Mode.SAME_COLUMN_PER_EVENT, "方式を差し替えられる")
