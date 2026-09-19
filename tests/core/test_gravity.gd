extends GutTest

## 時間ベース Gravity の Unit テスト。実時間は待たず、delta を直接与える。


func test_no_fall_before_one_cell_is_accumulated() -> void:
	var gravity := Gravity.new(1.0)

	assert_eq(gravity.advance(0.5), 0, "0.5 秒では 1 マスに届かない")
	assert_almost_eq(gravity.get_accumulated_cells(), 0.5, 0.0001, "端数は溜まっている")


func test_falls_one_cell_per_second_at_speed_one() -> void:
	var gravity := Gravity.new(1.0)

	assert_eq(gravity.advance(1.0), 1, "1 秒で 1 マス")


func test_speed_scales_the_fall() -> void:
	var gravity := Gravity.new(20.0)

	assert_eq(gravity.advance(1.0), 20, "20 マス/秒なら 1 秒で 20 マス")


func test_fall_amount_does_not_depend_on_frame_rate() -> void:
	# 同じ 1 秒を、60fps 相当と 30fps 相当と 1 回で与えて比べる（要件定義 §29）。
	var at_60fps := Gravity.new(5.0)
	var at_30fps := Gravity.new(5.0)
	var at_once := Gravity.new(5.0)

	var cells_60: int = 0
	for _i in range(60):
		cells_60 += at_60fps.advance(1.0 / 60.0)

	var cells_30: int = 0
	for _i in range(30):
		cells_30 += at_30fps.advance(1.0 / 30.0)

	var cells_once: int = at_once.advance(1.0)

	assert_eq(cells_60, cells_once, "60fps でも 1 回でも同じマス数")
	assert_eq(cells_30, cells_once, "30fps でも同じマス数")


func test_remainder_carries_over() -> void:
	var gravity := Gravity.new(1.0)

	var total: int = 0
	for _i in range(4):
		total += gravity.advance(0.3)

	assert_eq(total, 1, "0.3 秒 × 4 = 1.2 秒で 1 マス")
	assert_almost_eq(gravity.get_accumulated_cells(), 0.2, 0.0001, "残りは持ち越す")


func test_multiple_cells_in_one_step() -> void:
	var gravity := Gravity.new(10.0)

	assert_eq(gravity.advance(0.35), 3, "大きな delta では複数マス落ちる")


func test_zero_or_negative_delta_does_nothing() -> void:
	var gravity := Gravity.new(10.0)

	assert_eq(gravity.advance(0.0), 0, "0 秒では落ちない")
	assert_eq(gravity.advance(-1.0), 0, "負の delta でも落ちない")
	assert_eq(gravity.get_accumulated_cells(), 0.0, "端数も動かない")


func test_zero_speed_never_falls() -> void:
	var gravity := Gravity.new(0.0)

	assert_eq(gravity.advance(10.0), 0, "速度 0 なら落ちない")


func test_negative_speed_is_clamped_to_zero() -> void:
	var gravity := Gravity.new(-5.0)

	assert_eq(gravity.get_speed(), 0.0, "負の速度は 0 に丸める")
	assert_eq(gravity.advance(1.0), 0, "落ちない")


func test_set_speed_keeps_the_remainder() -> void:
	var gravity := Gravity.new(1.0)
	gravity.advance(0.5)

	gravity.set_speed(2.0)

	assert_almost_eq(gravity.get_accumulated_cells(), 0.5, 0.0001, "速度を変えても端数は残る")
	assert_eq(gravity.advance(0.25), 1, "0.5 + 2.0 × 0.25 = 1.0 マス")


func test_reset_discards_the_remainder() -> void:
	var gravity := Gravity.new(1.0)
	gravity.advance(0.9)

	gravity.reset()

	assert_eq(gravity.get_accumulated_cells(), 0.0, "端数を捨てる")
	assert_eq(gravity.advance(0.5), 0, "溜め直しになる")


func test_same_delta_sequence_produces_the_same_result() -> void:
	var first := Gravity.new(3.7)
	var second := Gravity.new(3.7)
	var deltas: Array[float] = [0.016, 0.033, 0.008, 0.25, 0.1]

	for delta in deltas:
		assert_eq(first.advance(delta), second.advance(delta), "同じ delta 列からは同じ落下量")
