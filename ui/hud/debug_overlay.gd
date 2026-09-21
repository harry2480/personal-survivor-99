class_name DebugOverlay
extends VBoxContainer

## 開発時の状態表示（要件定義 §113）。
##
## 出すのは §113 の項目（FPS / Frame Time / Alive Players / Detailed CPU /
## Lightweight CPU / 平均・最高 CPU Strength / Memory / Active Garbage /
## Seed / Game Time）。
##
## **Release Build では既定 OFF**（#54 の完了条件）。Development Build でだけ
## 既定 ON にし、どちらでもキーで切り替えられる。

## 表示を切り替える Action（Development Build 用）。
const TOGGLE_ACTION: StringName = &"ui_home"

## 読み直す周期（秒）。毎フレーム集計しない。
const REFRESH_INTERVAL_SEC: float = 0.25

## 出す項目（要件定義 §113）。
const ROW_KEYS: Array[String] = [
	"fps",
	"frame_time",
	"alive",
	"detailed_cpu",
	"lightweight_cpu",
	"average_strength",
	"highest_strength",
	"memory",
	"active_garbage",
	"seed",
	"game_time",
]

var _runner: CpuBattleRunner = null
var _labels: Dictionary = {}
var _values: Dictionary = {}
var _elapsed_sec: float = 0.0


func _ready() -> void:
	if _labels.is_empty():
		build()
	# Release では既定 OFF（要件定義 §113 / #54 の完了条件）。
	visible = OS.is_debug_build()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(TOGGLE_ACTION):
		visible = not visible

	if not visible:
		return

	_elapsed_sec += delta
	if _elapsed_sec < REFRESH_INTERVAL_SEC:
		return
	_elapsed_sec = 0.0
	refresh()


## 中身を組み立てる。
func build() -> void:
	for key in ROW_KEYS:
		var label := Label.new()
		label.text = "%s: -" % key
		add_child(label)
		_labels[key] = label
		_values[key] = "-"


## 表示する Battle を結び付ける。
func bind(runner: CpuBattleRunner) -> void:
	_runner = runner
	refresh()


## 結び付けを解く。
func unbind() -> void:
	_runner = null


## 表示している値を返す。
func get_value(key: String) -> String:
	return _values.get(key, "")


## 表示を切り替える。
func set_shown(shown: bool) -> void:
	visible = shown


## 表示しているかを返す。
func is_shown() -> bool:
	return visible


## 値を読み直す。
func refresh() -> void:
	_set_value("fps", str(Engine.get_frames_per_second()))
	_set_value("memory", "%.1f MB" % (float(OS.get_static_memory_usage()) / 1048576.0))

	if _runner == null:
		return

	var stats: CpuBattleRunner.FrameStats = _runner.get_frame_stats()
	var manager: BattleManager = _runner.get_manager()
	var cpus: CpuManager = _runner.get_cpu_manager()
	var ids: Array[int] = cpus.get_registered_ids()

	_set_value("frame_time", "%.3f ms" % stats.average_msec)
	_set_value("alive", "%d / %d" % [manager.get_alive_count(), manager.get_player_count()])
	_set_value("detailed_cpu", str(cpus.get_detailed_count()))
	_set_value("lightweight_cpu", str(ids.size() - cpus.get_detailed_count()))
	_set_value("seed", str(manager.get_battle_seed()))
	_set_value("game_time", "%.1f s" % _runner.get_elapsed_sec())
	_set_strength_values(ids)
	_set_value("active_garbage", str(_count_active_garbage(manager)))


func _set_strength_values(ids: Array[int]) -> void:
	if ids.is_empty():
		return

	var total: float = 0.0
	var highest: float = 0.0
	for player_id in ids:
		var strength: float = _runner.get_strength(player_id)
		total += strength
		highest = maxf(highest, strength)

	_set_value("average_strength", "%.1f" % (total / float(ids.size())))
	_set_value("highest_strength", "%.0f" % highest)


func _count_active_garbage(manager: BattleManager) -> int:
	var total: int = 0
	for player in manager.get_alive_players():
		total += player.incoming_garbage
	return total


func _set_value(key: String, value: String) -> void:
	if not _values.has(key):
		return
	_values[key] = value
	var label: Label = _labels.get(key, null)
	if label != null:
		label.text = "%s: %s" % [key, value]
