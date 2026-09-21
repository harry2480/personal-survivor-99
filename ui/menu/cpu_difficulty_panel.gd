class_name CpuDifficultyPanel
extends VBoxContainer

## CPU 難易度の選択 UI（要件定義 §77 / §79）。
##
## **通常は Strength だけ指定すれば済む**。Advanced を開いたときだけ §61 の各
## パラメータが出る（要件定義 §78 / #45 の完了条件）。
##
## Presentation Layer なので、CPU の内部状態は触らない。ユーザーの選択を
## [CpuSettings] へ書き、[signal settings_changed] で渡すだけ（#45 の制約）。
##
## [br]・Preset  … Easy / Normal / Hard / Very Hard / Extreme / Custom（§79）
## [br]・Custom  … Strength / Min Strength / Max Strength / Variation
## [br]・Advanced … §61 の各パラメータ（既定では隠す）
##
## Developer Mode を有効にすると Machine / Human-like も選べる（要件定義 §71 / §72）。

## 設定が変わった。
signal settings_changed(settings: CpuSettings)

## Strength スライダーの刻み。
const STRENGTH_STEP: float = 1.0

## Custom で指定できる Variation の上限。
const MAX_VARIATION: float = 50.0

var _settings: CpuSettings = CpuSettings.create_default()
var _developer_mode: bool = false
var _updating: bool = false

var _preset_button: OptionButton
var _preset_ids: Array[int] = []
var _custom_box: VBoxContainer
var _strength_slider: HSlider
var _strength_label: Label
var _minimum_spin: SpinBox
var _maximum_spin: SpinBox
var _variation_spin: SpinBox
var _advanced_toggle: CheckButton
var _advanced_box: VBoxContainer
var _advanced_spins: Dictionary = {}


func _ready() -> void:
	if _preset_button == null:
		build()


## UI を組み立てる（Scene から使うときは [method Node._ready] が呼ぶ）。
func build() -> void:
	_preset_button = OptionButton.new()
	_preset_button.item_selected.connect(_on_preset_selected)
	add_child(_labeled("CPU Difficulty", _preset_button))

	_custom_box = VBoxContainer.new()
	add_child(_custom_box)
	_build_custom_controls()

	_advanced_toggle = CheckButton.new()
	_advanced_toggle.text = "Advanced"
	_advanced_toggle.toggled.connect(_on_advanced_toggled)
	add_child(_advanced_toggle)

	_advanced_box = VBoxContainer.new()
	# 通常時は隠しておく。Strength だけ指定すれば済むようにするため（§78）。
	_advanced_box.visible = false
	add_child(_advanced_box)
	_build_advanced_controls()

	_rebuild_preset_items()
	_apply_settings_to_controls()


## 表示している設定を返す。
func get_settings() -> CpuSettings:
	return _settings


## 設定を差し替えて表示へ反映する。
func set_settings(settings: CpuSettings) -> void:
	if settings == null:
		return
	_settings = settings
	_apply_settings_to_controls()


## Machine / Human-like を選べるようにするか（要件定義 §71 / §72）。
##
## 通常の難易度 UI には出さない。Custom / Developer Mode 用。
func set_developer_mode(enabled: bool) -> void:
	if _developer_mode == enabled:
		return
	_developer_mode = enabled
	_rebuild_preset_items()
	_apply_settings_to_controls()


## Developer Mode かを返す。
func is_developer_mode() -> bool:
	return _developer_mode


## Advanced Settings を開いているかを返す。
func is_advanced_open() -> bool:
	return _advanced_box != null and _advanced_box.visible


## 選べる Preset を返す（並びは UI と同じ）。
func get_preset_items() -> Array[int]:
	return _preset_ids


## Preset を選ぶ。UI の操作と同じ経路を通る（設定の復元にも使う）。
func choose_preset(preset: CpuPreset.Preset) -> bool:
	var index: int = _preset_ids.find(preset)
	if index < 0:
		return false
	_preset_button.select(index)
	_on_preset_selected(index)
	return true


## Strength を設定する（Custom のスライダーと同じ経路）。
func set_strength_value(value: float) -> void:
	_strength_slider.value = value


## Min Strength / Max Strength / Variation をまとめて設定する（要件定義 §79）。
func set_distribution_values(minimum: float, maximum: float, variation: float) -> void:
	_minimum_spin.value = minimum
	_maximum_spin.value = maximum
	_variation_spin.value = variation


## Advanced Settings を開く / 閉じる（要件定義 §78）。
func set_advanced_open(open: bool) -> void:
	_advanced_toggle.button_pressed = open


## Advanced の 1 項目を設定する。知らない key は無視する。
##
## 入力欄の上下限で丸められた場合も、丸めた後の値を選んだ値として記録する。
func set_advanced_value(key: String, value: float) -> bool:
	if not _advanced_spins.has(key):
		return false
	var spin: SpinBox = _advanced_spins[key]
	spin.value = value
	_on_advanced_changed(spin.value, key)
	return true


## Custom の入力欄（Strength / Min / Max / Variation）が出ているかを返す。
func is_custom_section_visible() -> bool:
	return _custom_box != null and _custom_box.visible


## Advanced にその項目の入力欄があるかを返す。
func has_advanced_control(key: String) -> bool:
	return _advanced_spins.has(key)


## Strength に指定できる上限を返す。
func get_strength_maximum() -> float:
	return _strength_slider.max_value if _strength_slider != null else 0.0


func _build_custom_controls() -> void:
	_strength_slider = HSlider.new()
	_strength_slider.min_value = 0.0
	_strength_slider.max_value = CpuPreset.MAX_CUSTOM_STRENGTH
	_strength_slider.step = STRENGTH_STEP
	_strength_slider.value_changed.connect(_on_strength_changed)

	_strength_label = Label.new()
	var strength_row := HBoxContainer.new()
	strength_row.add_child(_strength_slider)
	strength_row.add_child(_strength_label)
	_custom_box.add_child(_labeled("Strength", strength_row))

	_minimum_spin = _new_spin(0.0, CpuPreset.MAX_CUSTOM_STRENGTH, STRENGTH_STEP)
	_minimum_spin.value_changed.connect(_on_minimum_changed)
	_custom_box.add_child(_labeled("Min Strength", _minimum_spin))

	_maximum_spin = _new_spin(0.0, CpuPreset.MAX_CUSTOM_STRENGTH, STRENGTH_STEP)
	_maximum_spin.value_changed.connect(_on_maximum_changed)
	_custom_box.add_child(_labeled("Max Strength", _maximum_spin))

	_variation_spin = _new_spin(0.0, MAX_VARIATION, 1.0)
	_variation_spin.value_changed.connect(_on_variation_changed)
	_custom_box.add_child(_labeled("Variation", _variation_spin))


func _build_advanced_controls() -> void:
	var reference := CpuProfile.create_default()
	for key in CpuSettings.ADVANCED_KEYS:
		var spin: SpinBox = _new_spin(0.0, _advanced_maximum(key), _advanced_step(key))
		spin.value = float(reference.get(key))
		spin.value_changed.connect(_on_advanced_changed.bind(key))
		_advanced_spins[key] = spin
		_advanced_box.add_child(_labeled(key, spin))


func _rebuild_preset_items() -> void:
	_preset_ids.clear()
	_preset_button.clear()

	for preset in CpuPreset.USER_PRESETS:
		_preset_ids.append(preset)
	if _developer_mode:
		for preset in CpuPreset.DEVELOPER_PRESETS:
			_preset_ids.append(preset)

	for index in range(_preset_ids.size()):
		_preset_button.add_item(CpuPreset.get_preset_name(_preset_ids[index]), index)


func _apply_settings_to_controls() -> void:
	if _preset_button == null:
		return

	_updating = true

	var selected: int = _preset_ids.find(_settings.preset)
	if selected < 0:
		selected = _preset_ids.find(CpuPreset.Preset.CUSTOM)
	_preset_button.select(maxi(0, selected))

	_strength_slider.value = _settings.strength
	_strength_label.text = "%.0f" % _settings.strength
	_minimum_spin.value = _settings.distribution.minimum_strength
	_maximum_spin.value = _settings.distribution.maximum_strength
	_variation_spin.value = _settings.distribution.strength_variance
	_custom_box.visible = _is_custom_selected()

	_advanced_toggle.button_pressed = _settings.advanced_enabled
	_advanced_box.visible = _settings.advanced_enabled
	for key in _advanced_spins:
		if _settings.advanced_overrides.has(key):
			_advanced_spins[key].value = float(_settings.advanced_overrides[key])

	_updating = false


func _is_custom_selected() -> bool:
	# Custom と Developer Preset は値を触れるようにする。
	return (
		_settings.preset == CpuPreset.Preset.CUSTOM
		or CpuPreset.is_developer_preset(_settings.preset)
	)


func _on_preset_selected(index: int) -> void:
	if _updating or index < 0 or index >= _preset_ids.size():
		return
	_settings.select_preset(_preset_ids[index])
	_apply_settings_to_controls()
	_notify_changed()


func _on_strength_changed(value: float) -> void:
	if _updating:
		return
	_settings.set_strength(value)
	_strength_label.text = "%.0f" % _settings.strength
	_notify_changed()


func _on_minimum_changed(value: float) -> void:
	if _updating:
		return
	_settings.distribution.minimum_strength = value
	_notify_changed()


func _on_maximum_changed(value: float) -> void:
	if _updating:
		return
	_settings.distribution.maximum_strength = value
	_notify_changed()


func _on_variation_changed(value: float) -> void:
	if _updating:
		return
	_settings.distribution.strength_variance = value
	_notify_changed()


func _on_advanced_toggled(pressed: bool) -> void:
	if _updating:
		return
	_settings.advanced_enabled = pressed
	_advanced_box.visible = pressed
	_notify_changed()


func _on_advanced_changed(value: float, key: String) -> void:
	if _updating:
		return
	_settings.set_advanced_override(key, _advanced_value(key, value))
	_notify_changed()


func _notify_changed() -> void:
	settings_changed.emit(_settings)


func _labeled(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	row.add_child(label)
	row.add_child(control)
	return row


func _new_spin(minimum: float, maximum: float, step: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	return spin


# 整数で持つパラメータは整数へ丸めてから渡す。
static func _advanced_value(key: String, value: float) -> Variant:
	if key == "lookahead" or key == "beam_width":
		return int(round(value))
	return value


static func _advanced_maximum(key: String) -> float:
	match key:
		"pieces_per_second":
			return 20.0
		"beam_width":
			return float(CpuProfile.MAX_BEAM_WIDTH)
		"lookahead":
			return float(PlacementSearch.MAX_SEARCH_DEPTH - 1)
		"hole_avoidance", "surface_management", "garbage_management", "recovery_ability":
			return 3.0
		_:
			return 1.0


static func _advanced_step(key: String) -> float:
	match key:
		"lookahead", "beam_width":
			return 1.0
		"pieces_per_second":
			return 0.1
		_:
			return 0.005
