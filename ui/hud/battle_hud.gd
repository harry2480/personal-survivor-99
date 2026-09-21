class_name BattleHud
extends VBoxContainer

## Battle の状況表示（要件定義 §90 / §91 / §93 / §108）。
##
## 出すのは §90 の最低表示のうち、盤面の左右に出す Hold / NEXT を除いた 8 つ。
##
## [codeblock]
## Remaining Players / Rank / KO Count / Attack Multiplier
## Target Mode / Current Target / Incoming Garbage / Attackers Count
## [/codeblock]
##
## **更新は Signal 経由**（要件定義 §108）。毎フレーム全 Player を走査しない。
## 残存人数は脱落の Signal で減らし、Attacker の数だけは周期を決めて数える
## （誰が誰を狙っているかは Signal で追い切れないため）。
##
## Battle Progression（要件定義 §93）は [BattlePhase] の段階が変わったときに
## 見た目を切り替える。判定は Battle Layer が持っているので、UI では行わない。

## 表示の並び（要件定義 §91 の優先順位に沿う）。
const ROW_KEYS: Array[String] = [
	"incoming",
	"target",
	"target_mode",
	"attackers",
	"remaining",
	"rank",
	"ko",
	"multiplier",
]

## 行の見出し。
const ROW_LABELS: Dictionary = {
	"incoming": "INCOMING",
	"target": "TARGET",
	"target_mode": "TARGET MODE",
	"attackers": "ATTACKERS",
	"remaining": "REMAINING",
	"rank": "RANK",
	"ko": "KO",
	"multiplier": "POWER",
}

## Attacker の数を数え直す周期（秒）。
const ATTACKER_REFRESH_SEC: float = 0.25

var _manager: BattleManager = null
var _ko: KoSystem = null
var _targets: TargetManager = null
var _viewer_id: int = -1
var _values: Dictionary = {}
var _value_labels: Dictionary = {}
var _phase_label: Label
var _phase: BattlePhase.Phase = BattlePhase.Phase.OPENING
var _attacker_timer_sec: float = 0.0
var _connections: Array = []


func _ready() -> void:
	if _phase_label == null:
		build()


func _process(delta: float) -> void:
	_attacker_timer_sec += delta
	if _attacker_timer_sec < ATTACKER_REFRESH_SEC:
		return
	_attacker_timer_sec = 0.0
	refresh_attackers()
	refresh_incoming()


func _exit_tree() -> void:
	unbind()


## 中身を組み立てる。
func build() -> void:
	_phase_label = Label.new()
	_phase_label.text = BattlePhase.get_phase_name(_phase)
	add_child(_phase_label)

	for key in ROW_KEYS:
		var row := HBoxContainer.new()
		var title := Label.new()
		title.text = ROW_LABELS[key]
		var value := Label.new()
		value.text = "-"
		row.add_child(title)
		row.add_child(value)
		add_child(row)
		_value_labels[key] = value
		_values[key] = "-"


## 表示する Battle を結び付ける（要件定義 §108 の Signal 経由）。
func bind(
	manager: BattleManager, viewer_id: int, ko: KoSystem = null, targets: TargetManager = null
) -> void:
	unbind()
	_manager = manager
	_viewer_id = viewer_id
	_ko = ko
	_targets = targets

	var on_eliminated: Callable = func(player_id: int, rank: int) -> void:
		_on_player_eliminated(player_id, rank)
	var on_phase: Callable = func(_previous: int, current: int) -> void:
		_on_phase_changed(current as BattlePhase.Phase)
	_manager.player_eliminated.connect(on_eliminated)
	_manager.phase_changed.connect(on_phase)
	_connections = [[_manager.player_eliminated, on_eliminated], [_manager.phase_changed, on_phase]]

	if _targets != null:
		var on_target: Callable = func(player_id: int, _previous: int, current: int) -> void:
			if player_id != _viewer_id:
				return
			_set_value("target", _format_player(current))
			_set_value("target_mode", _format_target_mode(_viewer()))
		_targets.target_changed.connect(on_target)
		_connections.append([_targets.target_changed, on_target])

	if _ko != null:
		var multiplier: MultiplierSystem = _ko.get_multiplier_system()
		var on_multiplier: Callable = func(player_id: int, _stage: int, value: float) -> void:
			if player_id == _viewer_id:
				_set_value("multiplier", "x%.2f" % value)
		multiplier.multiplier_changed.connect(on_multiplier)
		_connections.append([multiplier.multiplier_changed, on_multiplier])

		var on_ko: Callable = func(_victim: int, attacker: int) -> void:
			if attacker == _viewer_id:
				_set_value("ko", str(_viewer().ko_count))
		_ko.player_ko.connect(on_ko)
		_connections.append([_ko.player_ko, on_ko])

	refresh_all()


## 結び付けを解く。参照の循環を残さない。
func unbind() -> void:
	for entry in _connections:
		var source: Signal = entry[0]
		if source.is_connected(entry[1]):
			source.disconnect(entry[1])
	_connections.clear()
	_manager = null
	_ko = null
	_targets = null


## 表示している値を返す（テストと Debug Overlay 用）。
func get_value(key: String) -> String:
	return _values.get(key, "")


## 現在の段階を返す（要件定義 §93）。
func get_phase() -> BattlePhase.Phase:
	return _phase


## 段階に応じた色を返す（要件定義 §93 の UI 変化）。
##
## 残りが少ないほど強い色にする。判定そのものは Battle Layer が持つ。
static func get_color_for_phase(phase: BattlePhase.Phase) -> Color:
	match phase:
		BattlePhase.Phase.MIDDLE:
			return Color("#f5e03d")
		BattlePhase.Phase.LATE:
			return Color("#f59f3d")
		BattlePhase.Phase.FINAL:
			return Color("#f0724f")
		BattlePhase.Phase.DUEL:
			return Color("#f04f5c")
		BattlePhase.Phase.FINISHED:
			return Color("#ffffff")
		_:
			return Color("#d6dae3")


## 今の段階に応じた色を返す。
func get_phase_color() -> Color:
	return get_color_for_phase(_phase)


## すべて読み直す（開始時と Restart 時に使う）。
func refresh_all() -> void:
	if _manager == null:
		return

	var viewer: BattlePlayerState = _viewer()
	_set_value("remaining", str(_manager.get_alive_count()))
	_set_value("rank", _format_rank(viewer))
	_set_value("ko", str(viewer.ko_count) if viewer != null else "0")
	_set_value("multiplier", "x%.2f" % (viewer.attack_multiplier if viewer != null else 1.0))
	_set_value("target_mode", _format_target_mode(viewer))
	_set_value("target", _format_player(viewer.current_target if viewer != null else -1))
	refresh_incoming()
	refresh_attackers()
	_on_phase_changed(_manager.get_phase())


## Incoming Garbage を読み直す。
func refresh_incoming() -> void:
	var viewer: BattlePlayerState = _viewer()
	if viewer == null:
		return
	_set_value("incoming", str(viewer.incoming_garbage))


## 自分を狙っている Player の数を数え直す。
##
## 誰が誰を狙っているかは Signal では追い切れないため、ここだけ周期で数える。
func refresh_attackers() -> void:
	if _manager == null:
		return

	var count: int = 0
	for player in _manager.get_alive_players():
		if player.player_id != _viewer_id and player.current_target == _viewer_id:
			count += 1
	_set_value("attackers", str(count))


func _viewer() -> BattlePlayerState:
	return _manager.get_player(_viewer_id) if _manager != null else null


func _on_player_eliminated(player_id: int, rank: int) -> void:
	_set_value("remaining", str(_manager.get_alive_count()))
	if player_id == _viewer_id:
		_set_value("rank", "#%d" % rank)
	else:
		_set_value("rank", _format_rank(_viewer()))


func _on_phase_changed(phase: BattlePhase.Phase) -> void:
	_phase = phase
	if _phase_label == null:
		return
	_phase_label.text = BattlePhase.get_phase_name(phase)
	_phase_label.add_theme_color_override("font_color", get_phase_color())


func _set_value(key: String, value: String) -> void:
	if not _values.has(key):
		return
	_values[key] = value
	var label: Label = _value_labels.get(key, null)
	if label != null:
		label.text = value


func _format_rank(viewer: BattlePlayerState) -> String:
	if viewer == null:
		return "-"
	if viewer.rank > 0:
		return "#%d" % viewer.rank
	# 未確定のうちは「今の生存人数 = 最低でもこの順位」を出す。
	return "#%d" % _manager.get_alive_count()


func _format_player(player_id: int) -> String:
	return "-" if player_id < 0 else "P%d" % player_id


func _format_target_mode(viewer: BattlePlayerState) -> String:
	if viewer == null:
		return "-"
	if _targets != null and _targets.get_manual_target(viewer.player_id) >= 0:
		return TargetMode.get_mode_name(TargetMode.Mode.MANUAL)
	return TargetMode.get_mode_name(viewer.target_mode as TargetMode.Mode)
