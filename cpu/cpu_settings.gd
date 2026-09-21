class_name CpuSettings
extends Resource

## ユーザーが選んだ CPU 難易度（要件定義 §77 / §79）。
##
## **通常は Strength（または Preset）だけ指定すれば済む**。Advanced を開いた
## ときだけ、§61 の各パラメータを個別に上書きする（要件定義 §78）。
##
## UI（[CpuDifficultyPanel]）はこの Resource を組み立てて渡すだけで、CPU の
## 内部状態には触れない（#45 の制約）。Battle 側はここから [CpuDistribution] と
## [CpuProfile] を作る。

## Advanced で個別に触れるパラメータ（要件定義 §61 / §77）。
##
## [CpuProfile] の property 名と対応させてある。
const ADVANCED_KEYS: Array[String] = [
	"reaction_time_sec",
	"pieces_per_second",
	"misdrop_rate",
	"lookahead",
	"beam_width",
	"placement_quality",
	"technique_usage",
	"garbage_skill",
	"target_skill",
	"hole_avoidance",
	"surface_management",
	"garbage_management",
	"recovery_ability",
]

## 選んだ Preset（要件定義 §60 / §79）。
@export var preset: CpuPreset.Preset = CpuPreset.Preset.NORMAL

## Strength（要件定義 §59）。Custom のときにユーザーが動かす。
@export_range(0.0, 200.0, 1.0, "or_greater") var strength: float = 50.0

## CPU の人数（要件定義 §77）。
@export_range(1, 98, 1) var cpu_count: int = 98

## Strength の配り方（要件定義 §73 / §74）。
@export var distribution: CpuDistribution = CpuDistribution.create_default()

## Advanced Settings を開いているか（要件定義 §78）。
##
## 閉じている間は [member advanced_overrides] を使わない。
@export var advanced_enabled: bool = false

## Advanced で上書きした値。key は [constant ADVANCED_KEYS] のいずれか。
@export var advanced_overrides: Dictionary = {}


## 既定の設定（Normal / 既定の分布）を作る。
static func create_default() -> CpuSettings:
	return CpuSettings.new()


## Preset を選ぶ。Strength も Preset の既定値に合わせる。
func select_preset(new_preset: CpuPreset.Preset) -> void:
	preset = new_preset
	strength = CpuPreset.get_strength(new_preset)


## Strength を設定する（0 〜 [constant CpuPreset.MAX_CUSTOM_STRENGTH]）。
func set_strength(new_strength: float) -> void:
	strength = CpuPreset.clamp_strength(new_strength)


## Advanced の 1 項目を上書きする。知らない key は無視する。
func set_advanced_override(key: String, value: Variant) -> bool:
	if not key in ADVANCED_KEYS:
		return false
	advanced_overrides[key] = value
	return true


## Advanced の上書きをすべて捨てる。
func clear_advanced_overrides() -> void:
	advanced_overrides.clear()


## この設定から CPU 1 体ぶんの [CpuProfile] を作る。
##
## Preset と Strength で作ってから、Advanced の上書きを当てる。
func build_profile(mapping: CpuStrengthMapping = null) -> CpuProfile:
	var profile: CpuProfile = CpuPreset.create_profile_at(preset, strength, mapping)
	if not advanced_enabled:
		return profile

	for key in advanced_overrides:
		if key in ADVANCED_KEYS:
			profile.set(key, advanced_overrides[key])
	return profile


## この設定から CPU 群の [CpuDistribution] を作る。
##
## 元の [member distribution] は書き換えず、Preset と Strength を反映した複製を返す。
func build_distribution() -> CpuDistribution:
	var built: CpuDistribution = distribution.duplicate()
	built.preset = preset
	built.average_strength = strength
	built.minimum_strength = minf(built.minimum_strength, strength)
	built.maximum_strength = maxf(built.maximum_strength, strength)
	if built.fixed_strength_enabled:
		built.fixed_strength = strength
	return built


## 標準最高難易度（Extreme）を超える設定かを返す（MVP 受入条件 24）。
func is_above_standard_maximum() -> bool:
	if strength > CpuPreset.get_strength(CpuPreset.Preset.EXTREME):
		return true
	return CpuPreset.is_developer_preset(preset)
