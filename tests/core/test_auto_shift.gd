extends GutTest

## DAS / ARR の Unit テスト（要件定義 §31）。実時間は待たず、delta を直接与える。

var rules: GameRules
var auto_shift: AutoShift


func before_each() -> void:
	rules = GameRules.create_default()
	rules.das_sec = 0.2
	rules.arr_sec = 0.05
	auto_shift = AutoShift.new(rules)


func _hold(seconds: float, step_sec: float = 1.0 / 60.0) -> int:
	var steps: int = 0
	var elapsed: float = 0.0
	while elapsed + step_sec <= seconds + GameRules.ACCUMULATION_EPSILON:
		steps += auto_shift.update(step_sec)
		elapsed += step_sec
	return steps


# --- 押した瞬間 ------------------------------------------------------------


func test_press_moves_once_immediately() -> void:
	assert_eq(auto_shift.press(AutoShift.Direction.LEFT), 1, "押した瞬間に 1 マス動く")
	assert_eq(auto_shift.get_direction(), AutoShift.Direction.LEFT, "方向が記録される")
	assert_eq(auto_shift.get_step_x(), -1, "左は -1")


func test_pressing_the_same_direction_again_does_nothing() -> void:
	auto_shift.press(AutoShift.Direction.RIGHT)

	assert_eq(auto_shift.press(AutoShift.Direction.RIGHT), 0, "押しっぱなしは押し直しにしない")


func test_pressing_the_opposite_direction_switches_and_recharges() -> void:
	auto_shift.press(AutoShift.Direction.LEFT)
	_hold(0.3)
	assert_true(auto_shift.is_repeating(), "前提: 反復に入っている")

	assert_eq(auto_shift.press(AutoShift.Direction.RIGHT), 1, "逆方向は即座に 1 マス")

	assert_eq(auto_shift.get_step_x(), 1, "方向が切り替わる")
	assert_false(auto_shift.is_repeating(), "DAS を溜め直す")


# --- DAS -------------------------------------------------------------------


func test_no_repeat_before_das_elapses() -> void:
	auto_shift.press(AutoShift.Direction.LEFT)

	assert_eq(_hold(0.19), 0, "DAS 経過前は反復しない")
	assert_false(auto_shift.is_repeating(), "まだ反復に入っていない")


func test_repeat_starts_after_das() -> void:
	auto_shift.press(AutoShift.Direction.LEFT)

	var steps: int = _hold(0.2)

	assert_true(auto_shift.is_repeating(), "DAS 経過で反復に入る")
	assert_eq(steps, 1, "DAS 到達と同時に 1 マス目")


func test_das_value_comes_from_the_rules() -> void:
	rules.das_sec = 0.5
	auto_shift.press(AutoShift.Direction.LEFT)

	assert_eq(_hold(0.45), 0, "設定した DAS までは反復しない")
	assert_gt(_hold(0.1), 0, "設定した DAS を超えると反復する")


# --- ARR -------------------------------------------------------------------


func test_arr_controls_the_repeat_interval() -> void:
	auto_shift.press(AutoShift.Direction.LEFT)
	_hold(0.2)

	# ARR 0.05 秒で 0.25 秒ぶん押し続ける → 5 回
	assert_eq(_hold(0.25), 5, "ARR ごとに 1 マスずつ")


func test_repeat_count_does_not_depend_on_frame_rate() -> void:
	# 同じ実時間を 60fps と 30fps で与えて比べる。
	var at_60fps := AutoShift.new(rules)
	var at_30fps := AutoShift.new(rules)
	at_60fps.press(AutoShift.Direction.LEFT)
	at_30fps.press(AutoShift.Direction.LEFT)

	var steps_60: int = 0
	for _i in range(60):
		steps_60 += at_60fps.update(1.0 / 60.0)
	var steps_30: int = 0
	for _i in range(30):
		steps_30 += at_30fps.update(1.0 / 30.0)

	assert_eq(steps_60, steps_30, "1 秒間の反復回数が一致する")


func test_zero_arr_moves_across_the_board_without_looping_forever() -> void:
	rules.arr_sec = 0.0
	auto_shift.press(AutoShift.Direction.RIGHT)

	var steps: int = auto_shift.update(rules.das_sec)

	assert_eq(steps, AutoShift.INSTANT_STEPS, "壁まで届く歩数を 1 回で返す")
	assert_eq(steps, Board.WIDTH, "盤面の幅を超えない（無限にはならない）")


func test_zero_arr_keeps_returning_a_bounded_number_of_steps() -> void:
	rules.arr_sec = 0.0
	auto_shift.press(AutoShift.Direction.RIGHT)
	auto_shift.update(rules.das_sec)

	for _i in range(10):
		assert_eq(auto_shift.update(1.0), AutoShift.INSTANT_STEPS, "毎回上限つきの歩数で返る")


# --- 離す ------------------------------------------------------------------


func test_release_stops_the_repeat() -> void:
	auto_shift.press(AutoShift.Direction.LEFT)
	_hold(0.3)

	auto_shift.release(AutoShift.Direction.LEFT)

	assert_eq(auto_shift.get_direction(), AutoShift.Direction.NONE, "押されていない状態になる")
	assert_eq(_hold(1.0), 0, "離した後は動かない")


func test_releasing_the_other_direction_is_ignored() -> void:
	auto_shift.press(AutoShift.Direction.LEFT)

	auto_shift.release(AutoShift.Direction.RIGHT)

	assert_eq(auto_shift.get_direction(), AutoShift.Direction.LEFT, "押している方向は変わらない")


func test_update_without_input_does_nothing() -> void:
	assert_eq(auto_shift.update(10.0), 0, "何も押していなければ動かない")
