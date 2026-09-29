class_name ControlsGuide
extends GridContainer

## 操作方法の一覧（要件定義 §14 / §15）。
##
## Keyboard と Pro コントローラーの割り当てを並べて出す。表示する文字は
## InputMap から作るので、割り当てを変えても表示と食い違わない。
##
## Pro コントローラーのボタン名は、Godot の番号（位置で決まる）を Switch の
## 刻印へ読み替えて出す。下のボタン（番号 0）が Switch の B になる。
## 見出しにはブランド名を出さない（スタイルガイド §7）。
##
## キーとボタンの名前は locale/ja.po の文脈 "key" で訳す。

## 1 行に並べる操作。複数の Command をまとめた行は、それぞれの先頭の割り当てを並べる。
const ROWS: Array[Dictionary] = [
	{"label": "MOVE", "commands": [GameCommand.Command.MOVE_LEFT, GameCommand.Command.MOVE_RIGHT]},
	{"label": "SOFT DROP", "commands": [GameCommand.Command.SOFT_DROP]},
	{"label": "HARD DROP", "commands": [GameCommand.Command.HARD_DROP]},
	{
		"label": "ROTATE L / R",
		"commands": [GameCommand.Command.ROTATE_LEFT, GameCommand.Command.ROTATE_RIGHT]
	},
	{"label": "HOLD", "commands": [GameCommand.Command.HOLD]},
	{"label": "TARGET RANDOM", "commands": [GameCommand.Command.TARGET_RANDOM]},
	{"label": "TARGET KO", "commands": [GameCommand.Command.TARGET_KO]},
	{"label": "TARGET BADGE", "commands": [GameCommand.Command.TARGET_BADGE]},
	{"label": "TARGET COUNTER", "commands": [GameCommand.Command.TARGET_COUNTER]},
	{"label": "PAUSE", "commands": [GameCommand.Command.PAUSE]},
]

## 列の見出し。
const HEADERS: Array[String] = ["", "KEYBOARD", "CONTROLLER"]

## キーとボタンの名前を訳すときの文脈。
const NAME_CONTEXT: StringName = &"key"

## 割り当てが無いときの表示。
const UNBOUND_TEXT: String = "-"

## 複数の割り当てをつなぐ文字。
const SEPARATOR: String = " / "

## Godot のボタン番号 → Pro コントローラーの刻印。
const JOY_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "B",
	JOY_BUTTON_B: "A",
	JOY_BUTTON_X: "Y",
	JOY_BUTTON_Y: "X",
	JOY_BUTTON_BACK: "-",
	JOY_BUTTON_GUIDE: "HOME",
	JOY_BUTTON_START: "+",
	JOY_BUTTON_LEFT_STICK: "L Stick Press",
	JOY_BUTTON_RIGHT_STICK: "R Stick Press",
	JOY_BUTTON_LEFT_SHOULDER: "L",
	JOY_BUTTON_RIGHT_SHOULDER: "R",
	JOY_BUTTON_DPAD_UP: "D-Pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
	JOY_BUTTON_MISC1: "Capture",
}

## Godot の軸番号 → Pro コントローラーの名前。
const JOY_AXIS_NAMES: Dictionary = {
	JOY_AXIS_LEFT_X: "L Stick",
	JOY_AXIS_LEFT_Y: "L Stick",
	JOY_AXIS_RIGHT_X: "R Stick",
	JOY_AXIS_RIGHT_Y: "R Stick",
	JOY_AXIS_TRIGGER_LEFT: "ZL",
	JOY_AXIS_TRIGGER_RIGHT: "ZR",
}


func _ready() -> void:
	columns = HEADERS.size()
	theme_type_variation = &"GuideGrid"
	refresh()


## InputMap を読み直して表示を作り直す（Settings で割り当てが変わったとき用）。
func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	for header in HEADERS:
		_add_cell(header)
	for row in ROWS:
		_add_cell(row["label"])
		_add_cell(describe(row["commands"], false))
		_add_cell(describe(row["commands"], true))


## 操作の割り当てを文字で返す。[param joypad] が真なら Pro コントローラー側。
static func describe(commands: Array, joypad: bool) -> String:
	var names: PackedStringArray = PackedStringArray()
	for command in commands:
		var bound: PackedStringArray = _names_for(GameCommand.get_action_name(command), joypad)
		if bound.is_empty():
			continue
		# まとめた行は先頭だけ、1 つの操作の行はすべて並べる（HOLD の L / R など）。
		if commands.size() > 1:
			names.append(bound[0])
		else:
			names.append_array(bound)
	return SEPARATOR.join(names) if not names.is_empty() else UNBOUND_TEXT


## 1 つの入力イベントを文字にする。表示できないものは空文字。
static func describe_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var keycode: Key = (
			event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
		)
		return OS.get_keycode_string(keycode)
	if event is InputEventJoypadButton:
		return JOY_BUTTON_NAMES.get(event.button_index, "Button %d" % event.button_index)
	if event is InputEventJoypadMotion:
		var stick: String = JOY_AXIS_NAMES.get(event.axis, "Axis %d" % event.axis)
		if event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT:
			return stick
		return "%s %s" % [stick, _direction(event.axis, event.axis_value)]
	return ""


static func _names_for(action_name: String, joypad: bool) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	if not InputMap.has_action(action_name):
		return names
	for event in InputMap.action_get_events(action_name):
		var is_joypad: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
		if is_joypad != joypad:
			continue
		var text: String = describe_event(event)
		if text.is_empty():
			continue
		# 空文字を訳すと .po のヘッダーが返るので、空でないものだけ訳す。
		text = TranslationServer.translate(text, NAME_CONTEXT)
		if not names.has(text):
			names.append(text)
	return names


static func _direction(axis: int, value: float) -> String:
	var horizontal: bool = axis == JOY_AXIS_LEFT_X or axis == JOY_AXIS_RIGHT_X
	if horizontal:
		return "Right" if value > 0.0 else "Left"
	return "Down" if value > 0.0 else "Up"


func _add_cell(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = &"GuideLabel"
	add_child(label)
