extends Control

## Result 画面（要件定義 §99 / MVP 受入条件 21）。
##
## 直前の Battle の結果（[BattleOutcome]）を出し、通算の記録（[Statistics]）へ
## 足し込む。集計は [Statistics] が行い、この画面は並べるだけ。

## 出す項目（MVP 受入条件 21）。
const ROW_KEYS: Array[String] = [
	"rank",
	"ko",
	"lines",
	"quad",
	"t_spin",
	"perfect_clear",
	"duration",
	"highest_cpu",
]

## 項目の見出し。
const ROW_LABELS: Dictionary = {
	"rank": "RANK",
	"ko": "KO",
	"lines": "LINES",
	"quad": "QUAD",
	"t_spin": "T-SPIN",
	"perfect_clear": "PERFECT CLEAR",
	"duration": "TIME",
	"highest_cpu": "STRONGEST CPU BEATEN",
}

## 画面が出てからボタンを押せるようになるまでの時間（秒）。
## 決着の直前に連打していた Hard Drop（Space）や決定ボタンで、結果を読む前に戻らないようにする。
const INPUT_GUARD_SEC: float = 0.5

var _outcome: BattleOutcome
var _statistics: Statistics
var _values: Dictionary = {}
var _back_button: Button


func _ready() -> void:
	_outcome = SceneRouter.get_last_outcome()
	# 保存先は Settings と同じ 1 か所（要件定義 §98）。
	var store: SettingsStore = SceneRouter.settings_store
	_statistics = Statistics.load_from(store)

	# 通算へ足して保存する（要件定義 §98 / §99）。
	_statistics.record_battle(_outcome)
	_statistics.save_to(store)

	_build()


## 表示している結果を返す。
func get_outcome() -> BattleOutcome:
	return _outcome


## 足し込んだあとの通算記録を返す。
func get_statistics() -> Statistics:
	return _statistics


## 表示している値を返す。
func get_value(key: String) -> String:
	return _values.get(key, "")


## 戻るボタンを返す。
func get_back_button() -> Button:
	return _back_button


## Main Menu へ戻る。
func back_to_menu() -> void:
	SceneRouter.quit_to_menu()


func _build() -> void:
	var root := VBoxContainer.new()
	root.name = "Result"
	root.position = Vector2(80.0, 60.0)
	add_child(root)

	var title := Label.new()
	title.text = "VICTORY" if _outcome.is_win() else "RESULT"
	root.add_child(title)

	_values = {
		"rank": "#%d / %d" % [_outcome.rank, _outcome.player_count],
		"ko": str(_outcome.ko_count),
		"lines": str(_outcome.cleared_lines),
		"quad": str(_outcome.quad_count),
		"t_spin": str(_outcome.t_spin_count),
		"perfect_clear": str(_outcome.perfect_clear_count),
		"duration": tr("%.1f s") % _outcome.duration_sec,
		"highest_cpu": "%.0f" % _outcome.highest_cpu_strength_defeated,
	}

	for key in ROW_KEYS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = ROW_LABELS[key]
		var value := Label.new()
		value.text = _values[key]
		row.add_child(label)
		row.add_child(value)
		root.add_child(row)

	root.add_child(_build_statistics_label())

	var back := Button.new()
	back.text = "BACK TO MENU"
	back.pressed.connect(back_to_menu)
	root.add_child(back)
	# フォーカスが無いと Keyboard / Controller で押せない。
	# ただし出た直前の連打を拾わないよう、少し待ってから置く。
	_back_button = back
	get_tree().create_timer(INPUT_GUARD_SEC).timeout.connect(_focus_back_button)


func _build_statistics_label() -> Label:
	var label := Label.new()
	label.text = (
		tr("TOTAL  GAMES %d / WINS %d / TOP10 %d / AVG RANK %.1f / KO %d")
		% [
			_statistics.games_played,
			_statistics.wins,
			_statistics.top_ten_count,
			_statistics.get_average_rank(),
			_statistics.total_ko,
		]
	)
	return label


# 待っている間にほかの操作でフォーカスが置かれていたら、奪わない。
func _focus_back_button() -> void:
	if not is_instance_valid(_back_button) or not _back_button.is_visible_in_tree():
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	_back_button.grab_focus()
