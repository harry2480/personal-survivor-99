extends GutTest

## Extreme / Machine / Human-like Preset と Strength > 100 の Unit テスト
## （要件定義 §59 / §60 / §70〜§72）。
##
## Preset の定義が要件どおりかを見たうえで、**Extreme が通常 CPU より明確に
## 高性能である**ことを実際に動かして確かめる（MVP 受入条件 25 / #43 の完了条件）。

const SEED: int = 20260920
const FRAME_DELTA: float = 1.0 / 60.0

## 標準難易度との比較に使う時間（秒）。
##
## 走行は 1 手ごとに配置探索を回すので重い（Extreme で 1 手 約 80 ms）。
## 同じ Seed で Attack の差が出るのは 10 秒から。これより縮めると Attack が 0 同士になる。
const RUN_SEC: float = 10.0

## Machine の比較に使う時間（秒）。
##
## Machine は 1 手 約 200 ms かかり、PPS が 4 倍あるぶん走行がさらに重い。
## 2 秒でも手数・消した行数は 4 倍ほど開くので、この比較だけ短くする。
const MACHINE_RUN_SEC: float = 2.0

## 再現性の確認に使う時間（秒）。同じ結果になるかを見るだけなので短くてよい。
const REPRODUCIBILITY_RUN_SEC: float = 3.0
const QUALITY_PIECES: int = 40

## scripts/coverage.sh が立てる環境変数。立っていれば CPU を走らせる比較を飛ばす。
const COVERAGE_ENV: String = "PROJECT99_COVERAGE"

var mapping: CpuStrengthMapping

# Preset ごとの走行結果。同じ Seed なら結果は同じなので、走らせ直さない。
var _runs: Dictionary = {}


func before_each() -> void:
	mapping = CpuStrengthMapping.create_default()


# --- Preset の定義（要件定義 §60 / §70〜§72） -------------------------------


func test_user_presets_follow_the_requirement() -> void:
	var names: Array = []
	for preset in CpuPreset.USER_PRESETS:
		names.append(CpuPreset.get_preset_name(preset))

	assert_eq(
		names, ["EASY", "NORMAL", "HARD", "VERY_HARD", "EXTREME", "CUSTOM"], "通常 UI の並びは §60 のとおり"
	)


func test_machine_and_human_like_are_separated_from_normal_difficulty() -> void:
	for preset in [CpuPreset.Preset.MACHINE, CpuPreset.Preset.HUMAN_LIKE]:
		assert_false(CpuPreset.is_user_preset(preset), "通常 Difficulty に混ぜない（§71）")
		assert_true(CpuPreset.is_developer_preset(preset), "Custom / Developer Mode に出す")

	assert_false(CpuPreset.is_developer_preset(CpuPreset.Preset.EXTREME), "Extreme は通常難易度")


func test_extreme_is_defined_as_the_requirement_says() -> void:
	var profile: CpuProfile = CpuPreset.create_profile(CpuPreset.Preset.EXTREME, mapping)

	# 要件定義 §70: 反応ほぼ 0 / Misdrop 0% / 高精度 Evaluation / 高い Lookahead /
	# 高速 Placement / Technique 積極利用。
	assert_eq(profile.strength, 100.0, "Extreme は標準最高難易度（Strength 100）")
	assert_lt(profile.reaction_time_sec, 0.05, "反応遅延はほぼ 0")
	assert_eq(profile.misdrop_rate, 0.0, "Misdrop 0%")
	assert_eq(profile.placement_quality, 1.0, "常に最良の候補を選ぶ")
	assert_gte(profile.lookahead, 1, "Lookahead を使う")
	assert_gte(profile.pieces_per_second, 5.0, "高速 Placement")
	assert_eq(profile.technique_usage, 1.0, "Technique を積極利用")


func test_machine_removes_every_human_limit() -> void:
	var profile: CpuProfile = CpuPreset.create_profile(CpuPreset.Preset.MACHINE, mapping)

	# 要件定義 §71: Reaction 0 / Misdrop 0 / Search Quality 最大 / Lookahead 最大 /
	# Placement Speed 最大 / Targeting 最大。
	assert_eq(profile.reaction_time_sec, 0.0, "Reaction 0")
	assert_eq(profile.misdrop_rate, 0.0, "Misdrop 0")
	assert_eq(profile.placement_quality, 1.0, "Search Quality 最大")
	assert_eq(profile.beam_width, CpuProfile.MAX_BEAM_WIDTH, "Beam Width 最大")
	assert_eq(profile.lookahead, PlacementSearch.MAX_SEARCH_DEPTH - 1, "Lookahead は探索の上限いっぱい")
	assert_gte(profile.pieces_per_second, 20.0, "Placement Speed は人間の限界を超える")
	assert_eq(profile.target_skill, 1.0, "Targeting 最大")
	assert_eq(profile.garbage_skill, 1.0, "Garbage 処理も最大")


func test_human_like_keeps_human_limits() -> void:
	var profile: CpuProfile = CpuPreset.create_profile(CpuPreset.Preset.HUMAN_LIKE, mapping)

	# 要件定義 §72: PPS 上限あり / Reaction あり / Misdrop 極小。
	assert_gt(profile.strength, 100.0, "Strength は標準最高難易度より上")
	assert_lte(profile.pieces_per_second, mapping.human_max_pieces_per_second, "PPS に上限がある")
	assert_gte(profile.reaction_time_sec, mapping.human_min_reaction_time_sec, "反応遅延が残る")
	assert_gt(profile.misdrop_rate, 0.0, "Misdrop は 0 にしない")
	assert_lt(profile.misdrop_rate, 0.01, "ただし極小")


func test_human_like_thinks_as_well_as_machine() -> void:
	var human: CpuProfile = CpuPreset.create_profile(CpuPreset.Preset.HUMAN_LIKE, mapping)
	var machine: CpuProfile = CpuPreset.create_profile(CpuPreset.Preset.MACHINE, mapping)

	assert_eq(human.placement_quality, machine.placement_quality, "思考の精度は落とさない")
	assert_lt(human.pieces_per_second, machine.pieces_per_second, "操作速度で Machine と分かれる")
	assert_gt(human.reaction_time_sec, machine.reaction_time_sec, "反応遅延で Machine と分かれる")


# --- Strength > 100（要件定義 §59） ------------------------------------------


func test_strength_over_100_is_allowed() -> void:
	for strength in [120.0, 150.0, 200.0]:
		var profile: CpuProfile = CpuPreset.create_profile_at(
			CpuPreset.Preset.CUSTOM, strength, mapping
		)
		assert_eq(profile.strength, strength, "Strength %.0f を設定できる" % strength)


func test_strength_over_100_keeps_getting_stronger() -> void:
	var extreme: CpuProfile = mapping.create_profile(100.0)
	var over: CpuProfile = mapping.create_profile(150.0)

	assert_gt(over.pieces_per_second, extreme.pieces_per_second, "PPS は上がり続ける")
	assert_lte(over.reaction_time_sec, extreme.reaction_time_sec, "反応遅延は下がり続ける")
	assert_gte(over.hole_avoidance, extreme.hole_avoidance, "評価の厳しさも上がる")


func test_strength_is_clamped_to_the_custom_maximum() -> void:
	var profile: CpuProfile = CpuPreset.create_profile_at(CpuPreset.Preset.CUSTOM, 9999.0, mapping)

	assert_eq(profile.strength, CpuPreset.MAX_CUSTOM_STRENGTH, "上限で頭打ちにする")
	assert_gte(profile.reaction_time_sec, 0.0, "反応遅延が負にならない")
	assert_gte(profile.misdrop_rate, 0.0, "Misdrop 率が負にならない")


func test_physical_limits_are_respected_at_any_strength() -> void:
	var profile: CpuProfile = mapping.create_profile(CpuPreset.MAX_CUSTOM_STRENGTH)

	assert_lte(profile.placement_quality, 1.0, "Placement Quality は 1.0 が上限")
	assert_gte(profile.reaction_time_sec, 0.0, "反応遅延は 0 秒が下限")
	assert_gte(profile.misdrop_rate, 0.0, "Misdrop は 0% が下限")
	assert_lte(profile.beam_width, CpuProfile.MAX_BEAM_WIDTH, "Beam Width は上限で止まる")


# --- Extreme が通常 CPU より強い（MVP 受入条件 25） --------------------------


class SoloRun:
	extends RefCounted

	## 実際に置いた Piece 数。
	var pieces: int = 0

	## 消した行数の合計。
	var lines: int = 0

	## 生成した Attack 行数の合計。
	var attack: int = 0

	## 終了時点の穴の数。
	var holes: int = 0

	## Top Out したか。
	var topped_out: bool = false


func _new_session() -> PuzzleSession:
	var rules := GameRules.create_default()
	# Gravity を止めて、CPU が置いた結果だけを見る。
	rules.gravity_cells_per_second = 0.0
	var session := PuzzleSession.new(rules, PieceRandomizer.new(SEED))
	session.start(SEED)
	return session


## Preset を [constant RUN_SEC] 秒ぶん動かした結果を返す。
##
## 同じ Seed からは同じ結果になるので、一度走らせたら使い回す（走行 1 回が重い）。
func _preset_run(preset: CpuPreset.Preset) -> SoloRun:
	if not _runs.has(preset):
		_runs[preset] = _run_solo(CpuPreset.create_profile(preset, mapping), RUN_SEC)
	return _runs[preset]


## Profile を 1 人で [param duration_sec] 秒ぶん動かし、結果を返す。
func _run_solo(profile: CpuProfile, duration_sec: float) -> SoloRun:
	var run := SoloRun.new()
	var session: PuzzleSession = _new_session()
	var cpu := DetailedCpu.new(profile, session, SEED)

	var on_lines: Callable = func(result: LineClearResult) -> void: run.lines += result.line_count
	var on_attack: Callable = func(amount: int, _context: AttackContext) -> void:
		run.attack += amount
	var on_locked: Callable = func(_type: int) -> void: run.pieces += 1
	session.lines_cleared.connect(on_lines)
	session.attack_generated.connect(on_attack)
	session.piece_locked.connect(on_locked)

	var frames: int = int(duration_sec / FRAME_DELTA)
	for _frame in range(frames):
		if session.is_over():
			break
		cpu.update(FRAME_DELTA)

	session.lines_cleared.disconnect(on_lines)
	session.attack_generated.disconnect(on_attack)
	session.piece_locked.disconnect(on_locked)

	run.topped_out = session.is_over()
	run.holes = _count_holes(session.get_board())
	return run


## Profile に [param piece_count] 手だけ置かせ、終わった盤面の穴の数を返す。
##
## PPS の差を外して「置き方の質」だけを見るための測り方。
func _place_and_count_holes(profile: CpuProfile, piece_count: int) -> int:
	var session: PuzzleSession = _new_session()
	var cpu := DetailedCpu.new(profile, session, SEED)

	for _index in range(piece_count):
		if session.is_over():
			break
		cpu.place_once()

	return _count_holes(session.get_board())


## カバレッジ計測中なら保留にして [code]true[/code] を返す。
##
## CPU を実際に走らせる比較は 1 手ごとに配置探索を回すので、行ごとに記録する
## カバレッジ計測では 7 倍ほど遅くなり、計測全体の半分を占める。確かめたいのは
## 「強さの差が出るか」で、どの行を通るかは他のテストで足りている。
## 合否ゲートの scripts/run-tests.sh では環境変数が立たないので、毎回走る。
func _skip_during_coverage() -> bool:
	if OS.get_environment(COVERAGE_ENV) != "1":
		return false
	pending("カバレッジ計測中は CPU を走らせる比較を飛ばす（scripts/run-tests.sh では走る）")
	return true


func _count_holes(board: Board) -> int:
	var metrics := BoardMetrics.new()
	metrics.measure(board)
	return metrics.holes


func test_extreme_places_more_pieces_than_a_normal_cpu() -> void:
	if _skip_during_coverage():
		return
	var extreme: SoloRun = _preset_run(CpuPreset.Preset.EXTREME)
	var normal: SoloRun = _preset_run(CpuPreset.Preset.NORMAL)

	assert_gt(extreme.pieces, normal.pieces, "同じ時間で置く手数が多い")
	assert_gt(extreme.lines, normal.lines, "同じ時間で消す行数が多い")
	assert_gt(extreme.attack, normal.attack, "同じ時間で出す Attack が多い")


func test_extreme_stacks_more_cleanly_than_a_normal_cpu() -> void:
	if _skip_during_coverage():
		return
	# PPS を外し、同じ手数で比べる。置き方の質そのものの比較。
	var extreme_holes: int = _place_and_count_holes(
		CpuPreset.create_profile(CpuPreset.Preset.EXTREME, mapping), QUALITY_PIECES
	)
	var normal_holes: int = _place_and_count_holes(
		CpuPreset.create_profile(CpuPreset.Preset.NORMAL, mapping), QUALITY_PIECES
	)

	assert_lt(extreme_holes, normal_holes, "同じ手数なら Extreme のほうが穴が少ない")


func test_extreme_beats_every_standard_difficulty() -> void:
	if _skip_during_coverage():
		return
	# 標準難易度（Strength 100 未満）のすべてに対して、同じ時間・同じ Seed で
	# 「多く置き・多く消し・盤面が荒れない」ことを見る（MVP 受入条件 25）。
	var extreme: SoloRun = _preset_run(CpuPreset.Preset.EXTREME)

	for preset in [
		CpuPreset.Preset.EASY,
		CpuPreset.Preset.NORMAL,
		CpuPreset.Preset.HARD,
		CpuPreset.Preset.VERY_HARD
	]:
		var name: String = CpuPreset.get_preset_name(preset)
		var run: SoloRun = _preset_run(preset)

		assert_gt(extreme.pieces, run.pieces, "Extreme は %s より多く置く" % name)
		assert_gte(extreme.lines, run.lines, "Extreme は %s より消す行数が少なくない" % name)
		assert_lte(extreme.holes, run.holes, "Extreme は %s より盤面が荒れない" % name)
		assert_false(extreme.topped_out, "Extreme は %s との比較中に Top Out しない" % name)


func test_machine_outperforms_extreme() -> void:
	if _skip_during_coverage():
		return
	var machine: SoloRun = _run_solo(
		CpuPreset.create_profile(CpuPreset.Preset.MACHINE, mapping), MACHINE_RUN_SEC
	)
	var extreme: SoloRun = _run_solo(
		CpuPreset.create_profile(CpuPreset.Preset.EXTREME, mapping), MACHINE_RUN_SEC
	)

	assert_gt(machine.pieces, extreme.pieces, "同じ時間で置く手数が多い")
	# 短い走行では Attack がまだ出ないので、消した行数で比べる。
	assert_gt(machine.lines, extreme.lines, "Machine は Extreme より多く消す")


func test_runs_are_reproducible() -> void:
	if _skip_during_coverage():
		return
	var profile: CpuProfile = CpuPreset.create_profile(CpuPreset.Preset.EXTREME, mapping)

	var first: SoloRun = _run_solo(profile, REPRODUCIBILITY_RUN_SEC)
	var second: SoloRun = _run_solo(profile, REPRODUCIBILITY_RUN_SEC)

	assert_gt(first.lines, 0, "比べる意味があるだけ動いている")
	assert_eq(first.pieces, second.pieces, "置いた手数も同じ")

	assert_eq(first.lines, second.lines, "同じ Seed からは同じ結果になる")
	assert_eq(first.attack, second.attack, "Attack も同じ")
	assert_eq(first.holes, second.holes, "盤面も同じ")


func test_machine_speed_follows_the_last_node_of_the_table() -> void:
	# Machine の速さは表の最後の節点から取る。節点を差し替えてもコードを直さずに済む。
	mapping.strength_points = PackedFloat32Array([0.0, 100.0, 300.0])
	mapping.pieces_per_second = PackedFloat32Array([1.0, 5.0, 40.0])

	var profile: CpuProfile = mapping.create_machine_profile(100.0)

	assert_eq(profile.pieces_per_second, 40.0, "最後の節点（300）の PPS まで上げる")
