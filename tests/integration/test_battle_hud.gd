extends GutTest

## HUD の確認（要件定義 §90 / §91 / §93 / §108）。
##
## §90 の項目が出ること、Signal で更新されること（毎フレーム全走査しない）、
## 残存人数の閾値で Battle Progression の見た目が変わることを見る。

const HUD := preload("res://ui/hud/battle_hud.tscn")
const SEED: int = 20260922
const PLAYER_COUNT: int = 30
const VIEWER_ID: int = 0

var hud: BattleHud
var manager: BattleManager
var targets: TargetManager
var ko: KoSystem
var router: GarbageRouter


func before_each() -> void:
	hud = HUD.instantiate()
	add_child_autofree(hud)

	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	manager = BattleManager.new(rules)
	manager.setup(1, PLAYER_COUNT - 1, SEED)
	targets = TargetManager.new(manager, SEED)
	router = GarbageRouter.new(manager)
	ko = KoSystem.new(manager, router.get_attribution())

	hud.bind(manager, VIEWER_ID, ko, targets)


func after_each() -> void:
	hud.unbind()
	router.dispose()
	ko.dispose()


func _viewer() -> BattlePlayerState:
	return manager.get_player(VIEWER_ID)


# --- 最低表示（要件定義 §90） -----------------------------------------------


func test_every_required_row_is_shown() -> void:
	# Hold / NEXT は盤面の左右（#48 の PlayerBoardPanel）が持つ。
	for key in BattleHud.ROW_KEYS:
		assert_ne(hud.get_value(key), "", "%s の行がある" % key)


func test_remaining_players_are_shown() -> void:
	assert_eq(hud.get_value("remaining"), str(PLAYER_COUNT), "開始時は全員")


func test_rank_ko_and_multiplier_start_at_the_beginning() -> void:
	assert_eq(hud.get_value("rank"), "#%d" % PLAYER_COUNT, "未確定のうちは最低順位を出す")
	assert_eq(hud.get_value("ko"), "0", "KO は 0 から")
	assert_eq(hud.get_value("multiplier"), "x1.00", "倍率は 1.00 から")


func test_target_and_mode_are_shown() -> void:
	targets.update_all_targets()
	hud.refresh_all()

	assert_ne(hud.get_value("target"), "", "Current Target が出る")
	assert_ne(hud.get_value("target_mode"), "-", "Target Mode が出る")


# --- Signal での更新（要件定義 §108） ---------------------------------------


func test_remaining_updates_on_elimination() -> void:
	manager.eliminate_player(5)

	assert_eq(hud.get_value("remaining"), str(PLAYER_COUNT - 1), "脱落で残存人数が減る")


func test_rank_is_fixed_when_the_viewer_is_eliminated() -> void:
	manager.eliminate_player(VIEWER_ID)

	assert_eq(hud.get_value("rank"), "#%d" % PLAYER_COUNT, "脱落時の生存人数が順位になる")


func test_target_updates_through_the_signal() -> void:
	targets.set_manual_target(VIEWER_ID, 7)
	targets.update_all_targets()

	assert_eq(hud.get_value("target"), "P7", "Target が変わったら表示も変わる")
	assert_eq(
		hud.get_value("target_mode"),
		TargetMode.get_mode_name(TargetMode.Mode.MANUAL),
		"Manual を選んだら Mode も Manual"
	)


func test_multiplier_updates_through_the_signal() -> void:
	ko.get_multiplier_system().add_attack_points(_viewer(), 10)

	assert_ne(hud.get_value("multiplier"), "x1.00", "倍率が上がったら表示も上がる")


func test_ko_count_updates_when_the_viewer_gets_a_ko() -> void:
	# 自分が送った Garbage が原因で相手が落ちた、という形を作る。
	router.get_attribution().record_application(9, VIEWER_ID, 0.0, 4)
	manager.eliminate_player(9)

	assert_eq(hud.get_value("ko"), "1", "KO 数が増える")


func test_incoming_comes_from_the_battle_layer() -> void:
	_viewer().incoming_garbage = 6

	hud.refresh_incoming()

	assert_eq(hud.get_value("incoming"), "6", "Battle Layer の値をそのまま出す")


func test_attackers_are_counted() -> void:
	manager.get_player(2).current_target = VIEWER_ID
	manager.get_player(3).current_target = VIEWER_ID
	manager.get_player(4).current_target = 1

	hud.refresh_attackers()

	assert_eq(hud.get_value("attackers"), "2", "自分を狙っている数を出す")


func test_dead_attackers_are_not_counted() -> void:
	manager.get_player(2).current_target = VIEWER_ID
	manager.eliminate_player(2)

	hud.refresh_attackers()

	assert_eq(hud.get_value("attackers"), "0", "脱落した相手は数えない")


func test_attackers_are_not_counted_every_frame() -> void:
	manager.get_player(2).current_target = VIEWER_ID
	hud.refresh_attackers()
	manager.get_player(3).current_target = VIEWER_ID

	# 周期に満たない間は数え直さない（要件定義 §108）。
	hud._process(0.01)
	assert_eq(hud.get_value("attackers"), "1", "毎フレームは数えない")

	hud._process(BattleHud.ATTACKER_REFRESH_SEC)
	assert_eq(hud.get_value("attackers"), "2", "周期ごとに数え直す")


# --- Battle Progression（要件定義 §93） -------------------------------------


func test_phase_changes_at_the_thresholds() -> void:
	var seen: Array[String] = []
	var alive: int = PLAYER_COUNT

	# 残り 1 人まで落としていき、段階が変わるところを拾う。
	for player_id in range(1, PLAYER_COUNT):
		manager.eliminate_player(player_id)
		alive -= 1
		var name: String = BattlePhase.get_phase_name(hud.get_phase())
		if seen.is_empty() or seen[seen.size() - 1] != name:
			seen.append(name)

	assert_true("MIDDLE" in seen, "20 人以下で MIDDLE へ")
	assert_true("LATE" in seen, "10 人以下で LATE へ")
	assert_true("FINAL" in seen, "5 人以下で FINAL へ")
	assert_true("DUEL" in seen, "2 人で DUEL へ")


func test_phase_changes_the_look() -> void:
	var early_color: Color = hud.get_phase_color()

	for player_id in range(1, PLAYER_COUNT - 4):
		manager.eliminate_player(player_id)

	assert_ne(hud.get_phase_color(), early_color, "段階が変わると見た目も変わる")


func test_phase_comes_from_the_battle_layer() -> void:
	# UI 側で人数から段階を決めない。Battle Layer の phase_changed を映すだけ。
	assert_eq(hud.get_phase(), manager.get_phase(), "Battle Layer の段階と一致する")
