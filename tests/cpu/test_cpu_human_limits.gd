extends GutTest

## Reaction Time / PPS / Misdrop / Advanced Technique の Unit テスト
## （要件定義 §65 / §66 / §67 / §69）。

const SEED: int = 20260920
const FRAME: float = 1.0 / 60.0

var profile: CpuProfile


func before_each() -> void:
	profile = CpuProfile.create_default()
	profile.reaction_time_sec = 0.2
	profile.pieces_per_second = 2.0
	profile.misdrop_rate = 0.0
	profile.technique_usage = 0.5


func _count_places(timing: CpuTiming, seconds: float, step: float = FRAME) -> int:
	var places: int = 0
	var elapsed: float = 0.0
	while elapsed + step <= seconds + GameRules.ACCUMULATION_EPSILON:
		if timing.update(step):
			places += 1
			timing.notify_placed()
		elapsed += step
	return places


# --- PPS（要件定義 §66） ----------------------------------------------------


func test_place_interval_comes_from_pps() -> void:
	var timing := CpuTiming.new(profile)

	assert_almost_eq(timing.get_place_interval_sec(), 0.5, 0.0001, "2 PPS なら 0.5 秒間隔")


func test_places_at_the_configured_rate() -> void:
	var timing := CpuTiming.new(profile)

	assert_eq(_count_places(timing, 5.0), 10, "2 PPS × 5 秒で 10 回")


func test_higher_pps_places_more() -> void:
	profile.pieces_per_second = 5.0
	var fast := CpuTiming.new(profile)

	assert_eq(_count_places(fast, 4.0), 20, "5 PPS × 4 秒で 20 回")


func test_place_count_does_not_depend_on_frame_rate() -> void:
	var at_60fps := CpuTiming.new(profile)
	var at_30fps := CpuTiming.new(profile)

	assert_eq(
		_count_places(at_60fps, 5.0, 1.0 / 60.0),
		_count_places(at_30fps, 5.0, 1.0 / 30.0),
		"60fps でも 30fps でも回数が一致する"
	)


func test_pps_holds_when_the_interval_is_not_a_multiple_of_the_frame() -> void:
	# 4 PPS（0.25 秒）は 30fps / 45fps のフレーム幅で割り切れない。
	# 配置のたびに端数を捨てると、置く回数がフレームレートで減る。
	profile.pieces_per_second = 4.0

	for fps in [60.0, 45.0, 30.0]:
		var timing := CpuTiming.new(profile)
		assert_eq(_count_places(timing, 5.0, 1.0 / fps), 20, "%.0f fps でも 4 PPS × 5 秒で 20 回" % fps)


func test_a_long_stall_does_not_cause_a_burst() -> void:
	# 処理落ちで 1 秒止まっても、取り戻そうとまとめて置かない。
	var timing := CpuTiming.new(profile)

	assert_true(timing.update(1.0), "止まっていた間に 1 回ぶんは溜まる")
	timing.notify_placed()

	assert_false(timing.update(FRAME), "次のフレームですぐまた置かない")


func test_zero_or_negative_pps_is_handled() -> void:
	profile.pieces_per_second = 0.0
	var timing := CpuTiming.new(profile)

	assert_gt(timing.get_place_interval_sec(), 0.0, "間隔が 0 にならない（無限ループを避ける）")


# --- Reaction Time（要件定義 §65） ------------------------------------------


func test_event_delays_the_next_placement() -> void:
	var timing := CpuTiming.new(profile)

	timing.notify_event()

	assert_true(timing.is_reacting(), "反応待ちになる")
	assert_eq(_count_places(timing, 0.19), 0, "反応し終わるまで置かない")


func test_reaction_finishes_after_the_configured_time() -> void:
	var timing := CpuTiming.new(profile)
	timing.notify_event()

	_count_places(timing, 0.2)

	assert_false(timing.is_reacting(), "設定した時間で反応し終わる")


func test_reaction_time_comes_from_the_profile() -> void:
	profile.reaction_time_sec = 0.6
	var timing := CpuTiming.new(profile)

	timing.notify_event()
	_count_places(timing, 0.5)

	assert_true(timing.is_reacting(), "設定した時間までは反応待ちのまま")


func test_zero_reaction_time_never_waits() -> void:
	profile.reaction_time_sec = 0.0
	var timing := CpuTiming.new(profile)

	timing.notify_event()

	assert_false(timing.is_reacting(), "反応 0 なら待たない")


func test_repeated_events_do_not_stack() -> void:
	var timing := CpuTiming.new(profile)

	timing.notify_event()
	timing.notify_event()
	timing.notify_event()

	assert_almost_eq(timing.get_reaction_remaining_sec(), 0.2, 0.0001, "遅延は積み上がらない")


func test_reaction_reduces_placements_over_time() -> void:
	var calm := CpuTiming.new(profile)
	var startled := CpuTiming.new(profile)
	startled.notify_event()

	assert_lt(_count_places(startled, 2.0), _count_places(calm, 2.0), "反応待ちのぶんだけ置く回数が減る")


# --- Misdrop（要件定義 §67） ------------------------------------------------


func _make_board() -> Board:
	var board := Board.new()
	for x in range(Board.WIDTH):
		board.set_cell(x, Board.TOTAL_HEIGHT - 1, Piece.Type.I)
	board.clear_filled_rows()
	return board


func test_zero_rate_never_misdrops() -> void:
	profile.misdrop_rate = 0.0
	var misdrop := Misdrop.new(profile, SEED)
	var board: Board = _make_board()
	var placement: Placement = Placement.create(Piece.Type.O, Piece.Rotation.SPAWN, Vector2i(4, 38))

	for _attempt in range(50):
		assert_true(misdrop.apply(board, placement).equals(placement), "ミス率 0 なら崩れない")


func test_full_rate_always_misdrops() -> void:
	# 床に接した状態では回転できないため、崩す余地のある位置から始める。
	profile.misdrop_rate = 1.0
	var misdrop := Misdrop.new(profile, SEED)
	var board: Board = _make_board()
	var placement: Placement = Placement.create(Piece.Type.T, Piece.Rotation.SPAWN, Vector2i(4, 30))

	var changed: int = 0
	for _attempt in range(50):
		if not misdrop.apply(board, placement).equals(placement):
			changed += 1

	assert_gt(changed, 40, "ミス率 1.0 ならほぼ毎回崩れる")


func test_misdrop_rate_controls_the_frequency() -> void:
	var board: Board = _make_board()
	var placement: Placement = Placement.create(Piece.Type.T, Piece.Rotation.SPAWN, Vector2i(4, 38))

	var counts: Array[int] = []
	for rate in [0.1, 0.5]:
		profile.misdrop_rate = rate
		var misdrop := Misdrop.new(profile, SEED)
		var changed: int = 0
		for _attempt in range(200):
			if not misdrop.apply(board, placement).equals(placement):
				changed += 1
		counts.append(changed)

	assert_gt(counts[1], counts[0], "ミス率が高いほど多く崩れる（%s）" % str(counts))


func test_misdrop_result_is_always_placeable() -> void:
	profile.misdrop_rate = 1.0
	var misdrop := Misdrop.new(profile, SEED)
	var board: Board = _make_board()

	for type in Piece.get_all_types():
		var landing: Vector2i = GhostPiece.get_landing_position(
			board, type, Piece.SPAWN_ROTATION, Piece.get_spawn_position(type)
		)
		var placement: Placement = Placement.create(type, Piece.SPAWN_ROTATION, landing)

		for _attempt in range(20):
			var result: Placement = misdrop.apply(board, placement)
			if result.uses_hold != placement.uses_hold:
				continue  # Hold の取り違えは種類が変わるので置き直しは呼び出し側
			assert_true(
				Collision.can_place(board, result.piece_type, result.rotation, result.position),
				"%s の Misdrop 後も置ける" % Piece.get_letter(type)
			)


func test_misdrop_kinds_all_occur() -> void:
	profile.misdrop_rate = 1.0
	var misdrop := Misdrop.new(profile, SEED)
	var board: Board = _make_board()
	var placement: Placement = Placement.create(Piece.Type.T, Piece.Rotation.SPAWN, Vector2i(4, 30))

	var kinds: Dictionary = {}
	for _attempt in range(200):
		misdrop.apply(board, placement)
		kinds[misdrop.get_last_kind()] = true

	assert_true(kinds.has(Misdrop.Kind.SHIFT), "1 マスずれが起きる")
	assert_true(kinds.has(Misdrop.Kind.ROTATE), "回転ミスが起きる")
	assert_true(kinds.has(Misdrop.Kind.HOLD), "Hold ミスが起きる")


func test_misdrop_is_reproducible() -> void:
	profile.misdrop_rate = 0.5
	var board: Board = _make_board()
	var placement: Placement = Placement.create(Piece.Type.T, Piece.Rotation.SPAWN, Vector2i(4, 38))

	var first: Array[int] = []
	var misdrop := Misdrop.new(profile, SEED)
	for _attempt in range(30):
		misdrop.apply(board, placement)
		first.append(misdrop.get_last_kind())

	misdrop.reset(SEED)
	for index in range(30):
		misdrop.apply(board, placement)
		assert_eq(misdrop.get_last_kind(), first[index], "同じ Seed からは同じミス列")


func test_misdrop_does_not_depend_on_global_random_state() -> void:
	profile.misdrop_rate = 0.5
	var board: Board = _make_board()
	var placement: Placement = Placement.create(Piece.Type.T, Piece.Rotation.SPAWN, Vector2i(4, 38))

	seed(1)
	randi()
	var first := Misdrop.new(profile, SEED)
	var first_kinds: Array[int] = []
	for _attempt in range(20):
		first.apply(board, placement)
		first_kinds.append(first.get_last_kind())

	seed(999999)
	for _i in range(100):
		randi()
	var second := Misdrop.new(profile, SEED)
	for index in range(20):
		second.apply(board, placement)
		assert_eq(second.get_last_kind(), first_kinds[index], "グローバル乱数に影響されない")


# --- Advanced Technique（要件定義 §69） -------------------------------------


func test_weak_cpu_uses_no_techniques() -> void:
	profile.technique_usage = 0.0
	var usage := TechniqueUsage.new(profile, SEED)

	assert_eq(usage.get_available_techniques().size(), 0, "使用率 0 なら何も狙わない")


func test_strong_cpu_uses_every_technique() -> void:
	profile.technique_usage = 1.0
	var usage := TechniqueUsage.new(profile, SEED)

	assert_eq(
		usage.get_available_techniques().size(),
		TechniqueUsage.REQUIRED_USAGE.size(),
		"使用率 1.0 なら全部狙う"
	)


func test_techniques_unlock_in_order() -> void:
	# Downstack は低い使用率でも出るが、Perfect Clear は高い使用率でしか出ない。
	profile.technique_usage = 0.2
	var weak := TechniqueUsage.new(profile, SEED)

	assert_gt(weak.get_chance(TechniqueUsage.Technique.DOWNSTACK), 0.0, "Downstack は早く使える")
	assert_eq(weak.get_chance(TechniqueUsage.Technique.PERFECT_CLEAR), 0.0, "Perfect Clear はまだ")
	assert_eq(weak.get_chance(TechniqueUsage.Technique.T_SPIN), 0.0, "T-Spin もまだ")


func test_chance_rises_with_usage() -> void:
	var previous: float = -1.0
	for usage_value in [0.6, 0.7, 0.8, 0.9, 1.0]:
		profile.technique_usage = usage_value
		var usage := TechniqueUsage.new(profile, SEED)
		var chance: float = usage.get_chance(TechniqueUsage.Technique.T_SPIN)
		assert_gt(chance, previous, "使用率 %.1f で T-Spin の確率が上がる" % usage_value)
		previous = chance


func test_attempt_frequency_follows_the_chance() -> void:
	var counts: Array[int] = []
	for usage_value in [0.65, 0.95]:
		profile.technique_usage = usage_value
		var usage := TechniqueUsage.new(profile, SEED)
		var attempts: int = 0
		for _attempt in range(200):
			if usage.should_attempt(TechniqueUsage.Technique.T_SPIN):
				attempts += 1
		counts.append(attempts)

	assert_gt(counts[1], counts[0], "使用率が高いほど多く狙う（%s）" % str(counts))


func test_attempts_are_reproducible() -> void:
	profile.technique_usage = 0.8
	var usage := TechniqueUsage.new(profile, SEED)

	var first: Array[bool] = []
	for _attempt in range(30):
		first.append(usage.should_attempt(TechniqueUsage.Technique.COMBO))

	usage.reset(SEED)
	for index in range(30):
		assert_eq(
			usage.should_attempt(TechniqueUsage.Technique.COMBO), first[index], "同じ Seed で同じ判断列"
		)


func test_strength_mapping_drives_technique_usage() -> void:
	var mapping := CpuStrengthMapping.create_default()
	var weak := TechniqueUsage.new(mapping.create_profile(20.0), SEED)
	var strong := TechniqueUsage.new(mapping.create_profile(95.0), SEED)

	assert_lt(
		weak.get_available_techniques().size(),
		strong.get_available_techniques().size(),
		"Strength を上げると使えるテクニックが増える"
	)


func test_misdrop_falls_back_when_it_cannot_break_the_placement() -> void:
	# 床に接した T は回転できない。崩せない場合は元の配置をそのまま返す。
	profile.misdrop_rate = 1.0
	var misdrop := Misdrop.new(profile, SEED)
	var board: Board = _make_board()
	var placement: Placement = Placement.create(Piece.Type.T, Piece.Rotation.SPAWN, Vector2i(4, 38))

	var unchanged: int = 0
	for _attempt in range(100):
		if misdrop.apply(board, placement).equals(placement):
			unchanged += 1
			assert_eq(misdrop.get_last_kind(), Misdrop.Kind.NONE, "崩せなかったことが分かる")

	assert_gt(unchanged, 0, "崩せない場合がある")
