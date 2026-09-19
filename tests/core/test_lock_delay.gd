extends GutTest

## Lock Delay の Unit テスト。実時間は待たず、delta を直接与える。

const GROUND_Y: int = 39

var rules: GameRules
var lock_delay: LockDelay


func before_each() -> void:
	rules = GameRules.create_default()
	rules.lock_delay_sec = 0.5
	rules.lock_delay_reset_limit = 3
	lock_delay = LockDelay.new(rules)
	lock_delay.start_new_piece()


func _grounded(delta_sec: float) -> bool:
	return lock_delay.update(delta_sec, true, GROUND_Y)


# --- 基本 ------------------------------------------------------------------


func test_does_not_lock_while_falling() -> void:
	for step in range(10):
		assert_false(lock_delay.update(0.5, false, 10 + step), "接地していなければ何秒経っても Lock しない")


func test_locks_after_the_delay_on_the_ground() -> void:
	assert_false(_grounded(0.3), "0.3 秒では Lock しない")
	assert_true(_grounded(0.2), "合計 0.5 秒で Lock する")


func test_elapsed_time_accumulates_on_the_ground() -> void:
	_grounded(0.2)

	assert_almost_eq(lock_delay.get_elapsed_sec(), 0.2, 0.0001, "接地中は時間が溜まる")


func test_leaving_the_ground_clears_the_elapsed_time() -> void:
	_grounded(0.4)

	lock_delay.update(0.1, false, GROUND_Y)

	assert_eq(lock_delay.get_elapsed_sec(), 0.0, "浮いたら溜まった時間は消える")


func test_lock_timing_does_not_depend_on_frame_rate() -> void:
	var at_60fps := LockDelay.new(rules)
	at_60fps.start_new_piece()

	var frames_to_lock: int = 0
	for _i in range(120):
		frames_to_lock += 1
		if at_60fps.update(1.0 / 60.0, true, GROUND_Y):
			break

	assert_eq(frames_to_lock, 30, "0.5 秒 = 60fps で 30 フレーム")


# --- Reset -----------------------------------------------------------------


func test_move_resets_the_delay() -> void:
	_grounded(0.4)

	assert_true(lock_delay.notify_action(LockDelay.Action.MOVE), "移動で Reset される")

	assert_eq(lock_delay.get_elapsed_sec(), 0.0, "溜まった時間が戻る")
	assert_false(_grounded(0.4), "Reset 後は再び 0.4 秒では Lock しない")


func test_rotate_resets_the_delay() -> void:
	_grounded(0.4)

	assert_true(lock_delay.notify_action(LockDelay.Action.ROTATE), "回転で Reset される")

	assert_false(_grounded(0.4), "Reset 後は再び 0.4 秒では Lock しない")


func test_reset_can_be_disabled_per_action() -> void:
	rules.lock_delay_reset_on_move = false
	_grounded(0.4)

	assert_false(lock_delay.notify_action(LockDelay.Action.MOVE), "設定で移動 Reset を切れる")
	assert_true(lock_delay.notify_action(LockDelay.Action.ROTATE), "回転 Reset は有効なまま")


func test_reset_count_is_limited() -> void:
	for expected in range(1, rules.lock_delay_reset_limit + 1):
		assert_true(lock_delay.notify_action(LockDelay.Action.MOVE), "%d 回目は Reset できる" % expected)
		assert_eq(lock_delay.get_reset_count(), expected, "Reset 回数が数えられる")

	assert_true(lock_delay.is_reset_exhausted(), "上限に達した")
	assert_false(lock_delay.notify_action(LockDelay.Action.MOVE), "上限を超えた移動では Reset しない")
	assert_false(lock_delay.notify_action(LockDelay.Action.ROTATE), "回転でも Reset しない")


func test_lock_is_not_deferred_after_the_reset_limit() -> void:
	# 先に 1 度 update して最深到達行を確定させる（落下で Reset 回数が戻るため）。
	_grounded(0.0)
	for _i in range(rules.lock_delay_reset_limit):
		lock_delay.notify_action(LockDelay.Action.MOVE)

	_grounded(0.4)
	lock_delay.notify_action(LockDelay.Action.MOVE)

	assert_true(_grounded(0.1), "上限後は移動しても Lock が延期されない")


func test_reset_limit_zero_disables_reset() -> void:
	rules.lock_delay_reset_limit = 0
	lock_delay.start_new_piece()
	_grounded(0.4)

	assert_false(lock_delay.notify_action(LockDelay.Action.MOVE), "上限 0 なら 1 回も Reset できない")
	assert_true(_grounded(0.1), "そのまま Lock する")


func test_negative_reset_limit_means_unlimited() -> void:
	rules.lock_delay_reset_limit = -1
	lock_delay.start_new_piece()

	for _i in range(100):
		assert_true(lock_delay.notify_action(LockDelay.Action.MOVE), "負値なら無制限に Reset できる")

	assert_false(lock_delay.is_reset_exhausted(), "上限なしとして扱う")


# --- 落下による Reset 回数の回復 --------------------------------------------


func test_descending_to_a_new_row_restores_the_reset_count() -> void:
	lock_delay.update(0.0, true, 30)
	for _i in range(rules.lock_delay_reset_limit):
		lock_delay.notify_action(LockDelay.Action.MOVE)
	assert_true(lock_delay.is_reset_exhausted(), "前提: 上限に達している")

	lock_delay.update(0.0, true, 31)

	assert_eq(lock_delay.get_reset_count(), 0, "より深い行へ落ちたら Reset 回数が戻る")
	assert_true(lock_delay.notify_action(LockDelay.Action.MOVE), "また Reset できる")


func test_staying_at_the_same_row_does_not_restore_the_reset_count() -> void:
	lock_delay.update(0.0, true, 30)
	lock_delay.notify_action(LockDelay.Action.MOVE)

	lock_delay.update(0.1, true, 30)

	assert_eq(lock_delay.get_reset_count(), 1, "同じ行に留まる間は戻らない")


func test_moving_back_up_does_not_restore_the_reset_count() -> void:
	# Wall Kick で持ち上がった場合。最深到達行は下がらない。
	lock_delay.update(0.0, true, 30)
	lock_delay.notify_action(LockDelay.Action.MOVE)

	lock_delay.update(0.0, true, 28)

	assert_eq(lock_delay.get_reset_count(), 1, "持ち上がっても Reset 回数は戻らない")


func test_start_new_piece_clears_everything() -> void:
	lock_delay.update(0.0, true, 30)
	lock_delay.notify_action(LockDelay.Action.MOVE)
	_grounded(0.3)

	lock_delay.start_new_piece()

	assert_eq(lock_delay.get_elapsed_sec(), 0.0, "溜まった時間が消える")
	assert_eq(lock_delay.get_reset_count(), 0, "Reset 回数も消える")


# --- 設定の反映 ------------------------------------------------------------


func test_lock_delay_comes_from_the_rules() -> void:
	rules.lock_delay_sec = 1.5
	lock_delay.start_new_piece()

	assert_false(_grounded(1.4), "設定した猶予までは Lock しない")
	assert_true(_grounded(0.1), "設定した猶予で Lock する")
