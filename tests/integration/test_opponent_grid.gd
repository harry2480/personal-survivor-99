extends GutTest

## Opponent Grid の確認（要件定義 §52 / §89 / §91）。
##
## 98 面を並べたときに、Alive / Dead・Target・Danger・Attacker・Attack Power が
## 出ること、Manual Target 用に選べることを見る（#49 の完了条件）。

const GRID := preload("res://ui/opponent/opponent_grid.tscn")
const SEED: int = 20260922
const PLAYER_COUNT: int = 99
const VIEWER_ID: int = 0

var grid: OpponentGrid
var manager: BattleManager
var cpus: CpuManager


func before_each() -> void:
	grid = GRID.instantiate()
	add_child_autofree(grid)

	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	manager = BattleManager.new(rules)
	manager.setup(1, PLAYER_COUNT - 1, SEED)
	cpus = CpuManager.new(manager, SEED, 0)
	cpus.register_all_from_distribution(CpuDistribution.create_default(), null, SEED)

	grid.bind(manager, VIEWER_ID, cpus)


func after_each() -> void:
	grid.unbind()


func _tile_position(index: int) -> Vector2:
	var column: int = index % OpponentGrid.COLUMNS
	var row: int = index / OpponentGrid.COLUMNS
	return Vector2(
		float(column) * (OpponentGrid.TILE_SIZE.x + OpponentGrid.TILE_MARGIN) + 1.0,
		float(row) * (OpponentGrid.TILE_SIZE.y + OpponentGrid.TILE_MARGIN) + 1.0
	)


# --- 98 面の表示（要件定義 §89） --------------------------------------------


func test_all_opponents_are_shown() -> void:
	assert_eq(grid.get_tiles().size(), PLAYER_COUNT - 1, "自分を除く 98 面が並ぶ")


func test_the_viewer_is_not_in_the_grid() -> void:
	assert_null(grid.get_tile(VIEWER_ID), "自分は一覧に出さない")


func test_alive_and_dead_are_shown() -> void:
	manager.eliminate_player(5)

	grid.refresh()

	assert_false(grid.get_tile(5).alive, "脱落した相手は Dead になる")
	assert_true(grid.get_tile(6).alive, "生きている相手は Alive のまま")


func test_danger_comes_from_the_battle_layer() -> void:
	manager.get_player(7).danger_level = DangerLevel.Level.DANGER

	grid.refresh()

	assert_eq(grid.get_tile(7).danger_level, DangerLevel.Level.DANGER, "Battle Layer の値を映す")


func test_attack_power_is_shown() -> void:
	manager.get_player(8).attack_multiplier = 1.75

	grid.refresh()

	assert_eq(grid.get_tile(8).attack_multiplier, 1.75, "Attack 倍率が出る")


func test_stack_height_comes_from_the_cpu_indicators() -> void:
	# Lightweight の CPU は盤面を持たないため、指標から積み上がりを出す（§82）。
	cpus.receive_garbage(9, 10)
	for _step in range(4):
		cpus.update(0.5)

	grid.refresh()

	assert_gt(grid.get_tile(9).fill_ratio, 0.0, "Garbage を受けた相手は積み上がって見える")
	assert_lte(grid.get_tile(9).fill_ratio, 1.0, "割合は 1.0 を超えない")


# --- Target と Attacker（要件定義 §89） -------------------------------------


func test_current_target_is_marked() -> void:
	manager.get_player(VIEWER_ID).current_target = 12

	grid.refresh()

	assert_true(grid.get_tile(12).is_target, "自分が狙っている相手が分かる")
	assert_false(grid.get_tile(13).is_target, "他の相手には付かない")


func test_attackers_are_marked() -> void:
	manager.get_player(14).current_target = VIEWER_ID

	grid.refresh()

	assert_true(grid.get_tile(14).is_attacker, "自分を狙っている相手が分かる")
	assert_false(grid.get_tile(15).is_attacker, "狙っていない相手には付かない")


func test_target_and_attacker_are_independent() -> void:
	manager.get_player(VIEWER_ID).current_target = 16
	manager.get_player(16).current_target = VIEWER_ID

	grid.refresh()

	assert_true(grid.get_tile(16).is_target, "狙っている")
	assert_true(grid.get_tile(16).is_attacker, "同時に狙われてもいる")


# --- Manual Target の選択（要件定義 §52） -----------------------------------


func test_clicking_a_tile_reports_the_player_id() -> void:
	var selected: Array[int] = []
	grid.opponent_selected.connect(func(player_id: int) -> void: selected.append(player_id))

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = _tile_position(3)
	grid._gui_input(event)

	assert_eq(selected, [grid.get_tiles()[3].player_id] as Array[int], "押した面の相手を伝える")


func test_only_the_left_button_selects() -> void:
	# 右・中クリックやホイールも pressed で届く。選ぶのは左クリックだけ。
	var selected: Array[int] = []
	grid.opponent_selected.connect(func(player_id: int) -> void: selected.append(player_id))

	for button in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_WHEEL_UP]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = true
		event.position = _tile_position(3)
		grid._gui_input(event)

	assert_eq(selected.size(), 0, "左クリック以外では選ばない")


func test_the_margin_between_tiles_selects_nobody() -> void:
	# 1 枚目のタイルの右の余白と下の余白は、隣のタイルとして扱わない。
	var right_margin := Vector2(OpponentGrid.TILE_SIZE.x + OpponentGrid.TILE_MARGIN / 2.0, 1.0)
	var bottom_margin := Vector2(1.0, OpponentGrid.TILE_SIZE.y + OpponentGrid.TILE_MARGIN / 2.0)

	assert_eq(grid.get_player_id_at(right_margin), -1, "右の余白は選ばない")
	assert_eq(grid.get_player_id_at(bottom_margin), -1, "下の余白は選ばない")
	assert_ne(grid.get_player_id_at(_tile_position(1)), -1, "隣のタイルそのものは選べる")


func test_position_outside_the_grid_selects_nobody() -> void:
	assert_eq(grid.get_player_id_at(Vector2(-10.0, -10.0)), -1, "枠の外は選ばない")
	assert_eq(grid.get_player_id_at(Vector2(0.0, 10000.0)), -1, "面が無いところは選ばない")


func test_the_grid_only_reports_the_selection() -> void:
	# Target にするかどうかは Battle Layer が決める（要件定義 §53）。
	# Grid は「押された」ことを伝えるだけで、Target を書き換えない。
	var before: int = manager.get_player(VIEWER_ID).current_target

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = _tile_position(1)
	grid._gui_input(event)

	assert_eq(manager.get_player(VIEWER_ID).current_target, before, "UI が Target を書き換えない")


func test_manual_target_goes_through_the_battle_layer() -> void:
	var targets := TargetManager.new(manager, SEED)
	grid.opponent_selected.connect(
		func(player_id: int) -> void: targets.set_manual_target(VIEWER_ID, player_id)
	)

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = _tile_position(2)
	grid._gui_input(event)

	assert_eq(
		targets.get_manual_target(VIEWER_ID),
		grid.get_tiles()[2].player_id,
		"選んだ相手が Manual Target になる"
	)


# --- 更新の仕方（要件定義 §108 / §91） --------------------------------------


func test_state_is_not_scanned_every_frame() -> void:
	var before: int = grid.get_refresh_count()

	# 周期に満たない間は読み直さない。
	for _frame in range(3):
		grid._process(0.001)

	assert_eq(grid.get_refresh_count(), before, "毎フレームは走査しない")

	grid._process(OpponentGrid.REFRESH_INTERVAL_SEC)

	assert_eq(grid.get_refresh_count(), before + 1, "周期ごとに 1 回だけ読み直す")


func test_refreshing_98_opponents_is_cheap() -> void:
	# 98 面ぶんの読み直しが 1 フレームの予算（16.6 ms）を食わないこと。
	var started: int = Time.get_ticks_usec()
	for _count in range(10):
		grid.refresh()
	var average_msec: float = float(Time.get_ticks_usec() - started) / 10.0 / 1000.0

	gut.p("Opponent Grid の読み直し: %.4f ms / 回（98 面）" % average_msec)
	assert_lt(average_msec, 1.0, "98 面の読み直しは 1 ms 未満")
