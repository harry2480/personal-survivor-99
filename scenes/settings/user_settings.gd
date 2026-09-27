class_name UserSettings
extends Resource

## ユーザー設定（要件定義 §97 / §128）。
##
## Gameplay / Audio / Video / Input の 4 つを持つ。保存と読み込みは
## [SettingsStore] が行い、この Resource は値だけを持つ。
##
## Dictionary との相互変換を持たせてあるのは、保存方式を **JSON 1 本に統一する**
## ため（要件定義 §98 / #52 の完了条件）。

## Gameplay の既定値の置き場所（要件定義 §39）。
const DEFAULTS_PATH: String = "res://config/defaults.json"

# --- Gameplay（要件定義 §97） ----------------------------------------------

## DAS（秒）。
@export_range(0.0, 1.0, 0.001, "or_greater") var das_sec: float = 0.167

## ARR（秒）。
@export_range(0.0, 0.5, 0.001, "or_greater") var arr_sec: float = 0.033

## Soft Drop の速さ（Gravity の倍率）。
@export_range(1.0, 100.0, 0.5, "or_greater") var soft_drop_multiplier: float = 20.0

## Ghost Piece を出すか。
@export var ghost_enabled: bool = true

## CPU の難易度（要件定義 §77 / §79）。
@export var cpu_settings: CpuSettings = CpuSettings.create_default()

# --- Audio（要件定義 §97 / §100） ------------------------------------------

## 全体音量（0.0〜1.0）。
@export_range(0.0, 1.0, 0.01) var master_volume: float = 0.8

## BGM の音量（0.0〜1.0）。
@export_range(0.0, 1.0, 0.01) var bgm_volume: float = 0.7

## SE の音量（0.0〜1.0）。
@export_range(0.0, 1.0, 0.01) var se_volume: float = 0.8

# --- Video（要件定義 §97 / §129） ------------------------------------------

## 全画面にするか。
@export var fullscreen: bool = false

## ウィンドウの大きさ（要件定義 §129 の対応解像度）。
@export var window_size: Vector2i = Vector2i(1440, 900)

## 垂直同期を使うか。
@export var vsync_enabled: bool = true

## FPS の上限。0 で無制限（要件定義 §102）。
@export_range(0, 240, 1) var fps_limit: int = 0

# --- Input（要件定義 §97 / §128） ------------------------------------------

## Keyboard の割り当て。key は Action 名、値は Keycode。
@export var keyboard_bindings: Dictionary = {}

## Controller の割り当て。key は Action 名、値は Button Index。
@export var controller_bindings: Dictionary = {}

## Stick の Dead Zone。
@export_range(0.0, 1.0, 0.01) var stick_dead_zone: float = 0.5


## 既定値の設定を作る。
##
## Gameplay の既定値は `config/defaults.json` から読む。読めなければ、この
## Resource の初期値をそのまま使う（起動できなくならないように）。
static func create_default() -> UserSettings:
	var settings := UserSettings.new()
	settings.apply_dictionary(_read_defaults())
	return settings


## Dictionary から値を取り込む。
##
## 知らない key は無視し、型が違う値も無視する。壊れたファイルを読んでも
## 既定値のまま動く（#52 の完了条件）。
func apply_dictionary(data: Dictionary) -> void:
	var gameplay: Dictionary = _section(data, "gameplay")
	das_sec = _read_float(gameplay, "das_sec", das_sec, 0.0, 1.0)
	arr_sec = _read_float(gameplay, "arr_sec", arr_sec, 0.0, 0.5)
	soft_drop_multiplier = _read_float(
		gameplay, "soft_drop_multiplier", soft_drop_multiplier, 1.0, 100.0
	)
	ghost_enabled = _read_bool(gameplay, "ghost_enabled", ghost_enabled)
	_apply_cpu_section(_section(gameplay, "cpu"))

	var audio: Dictionary = _section(data, "audio")
	master_volume = _read_float(audio, "master", master_volume, 0.0, 1.0)
	bgm_volume = _read_float(audio, "bgm", bgm_volume, 0.0, 1.0)
	se_volume = _read_float(audio, "se", se_volume, 0.0, 1.0)

	var video: Dictionary = _section(data, "video")
	fullscreen = _read_bool(video, "fullscreen", fullscreen)
	vsync_enabled = _read_bool(video, "vsync", vsync_enabled)
	fps_limit = int(_read_float(video, "fps_limit", float(fps_limit), 0.0, 240.0))
	window_size = Vector2i(
		int(_read_float(video, "window_width", float(window_size.x), 640.0, 7680.0)),
		int(_read_float(video, "window_height", float(window_size.y), 480.0, 4320.0))
	)

	var input: Dictionary = _section(data, "input")
	stick_dead_zone = _read_float(input, "stick_dead_zone", stick_dead_zone, 0.0, 1.0)
	keyboard_bindings = _read_bindings(input, "keyboard")
	controller_bindings = _read_bindings(input, "controller")


## 保存用の Dictionary へ落とす。
func to_dictionary() -> Dictionary:
	return {
		"gameplay":
		{
			"das_sec": das_sec,
			"arr_sec": arr_sec,
			"soft_drop_multiplier": soft_drop_multiplier,
			"ghost_enabled": ghost_enabled,
			"cpu":
			{
				"preset": int(cpu_settings.preset),
				"strength": cpu_settings.strength,
				"advanced_enabled": cpu_settings.advanced_enabled,
				"advanced_overrides": cpu_settings.advanced_overrides.duplicate(),
			},
		},
		"audio": {"master": master_volume, "bgm": bgm_volume, "se": se_volume},
		"video":
		{
			"fullscreen": fullscreen,
			"vsync": vsync_enabled,
			"fps_limit": fps_limit,
			"window_width": window_size.x,
			"window_height": window_size.y,
		},
		"input":
		{
			"stick_dead_zone": stick_dead_zone,
			"keyboard": keyboard_bindings.duplicate(),
			"controller": controller_bindings.duplicate(),
		},
	}


## Gameplay のうち Game Core へ渡すぶんを返す。
##
## [method GameRules.apply_user_settings] がそのまま受け取れる形。
func to_game_rules_dictionary() -> Dictionary:
	return {
		"das_sec": das_sec,
		"arr_sec": arr_sec,
		"soft_drop_multiplier": soft_drop_multiplier,
	}


static func _read_defaults() -> Dictionary:
	if not FileAccess.file_exists(DEFAULTS_PATH):
		return {}

	var file: FileAccess = FileAccess.open(DEFAULTS_PATH, FileAccess.READ)
	if file == null:
		return {}

	var json := JSON.new()
	var ok: bool = json.parse(file.get_as_text()) == OK
	file.close()
	return json.data if ok and json.data is Dictionary else {}


static func _section(data: Dictionary, key: String) -> Dictionary:
	var value: Variant = data.get(key)
	return value if value is Dictionary else {}


static func _read_float(
	data: Dictionary, key: String, fallback: float, minimum: float, maximum: float
) -> float:
	var value: Variant = data.get(key)
	if not (value is float or value is int):
		return fallback
	return clampf(float(value), minimum, maximum)


static func _read_bool(data: Dictionary, key: String, fallback: bool) -> bool:
	var value: Variant = data.get(key)
	return value if value is bool else fallback


static func _read_bindings(data: Dictionary, key: String) -> Dictionary:
	var bindings: Dictionary = {}
	for action in _section(data, key):
		var value: Variant = _section(data, key)[action]
		if value is float or value is int:
			bindings[str(action)] = int(value)
	return bindings


func _apply_cpu_section(cpu: Dictionary) -> void:
	if cpu.is_empty():
		return
	if cpu_settings == null:
		cpu_settings = CpuSettings.create_default()

	var preset: float = _read_float(cpu, "preset", float(cpu_settings.preset), 0.0, 7.0)
	cpu_settings.preset = int(preset) as CpuPreset.Preset
	cpu_settings.set_strength(
		_read_float(cpu, "strength", cpu_settings.strength, 0.0, CpuPreset.MAX_CUSTOM_STRENGTH)
	)
	cpu_settings.advanced_enabled = _read_bool(
		cpu, "advanced_enabled", cpu_settings.advanced_enabled
	)

	var overrides: Variant = cpu.get("advanced_overrides")
	if overrides is Dictionary:
		cpu_settings.clear_advanced_overrides()
		for key in overrides:
			cpu_settings.set_advanced_override(str(key), overrides[key])
