class_name CpuPreset
extends RefCounted

## CPU の難易度 Preset（要件定義 §60）。
##
## **Preset は内部 Parameter Set への Alias**。実体は Strength の値で、
## [CpuStrengthMapping] を通して [CpuProfile] になる。通常ユーザーは Preset か
## Strength のどちらかを選べばよく、個別調整は Advanced Settings（Phase 9）。

## 選べる Preset。
enum Preset { EASY, NORMAL, HARD, VERY_HARD, EXTREME, CUSTOM, MACHINE }

## Preset に対応する Strength（要件定義 §59 の目安）。
##
## [constant Preset.CUSTOM] はユーザーが指定するため、ここでは中央値を持つ。
## [constant Preset.MACHINE] は 100 を超える。100 を絶対上限にしないため（§59）。
const STRENGTH_BY_PRESET: Dictionary = {
	Preset.EASY: 30.0,
	Preset.NORMAL: 50.0,
	Preset.HARD: 70.0,
	Preset.VERY_HARD: 85.0,
	Preset.EXTREME: 100.0,
	Preset.CUSTOM: 50.0,
	Preset.MACHINE: 150.0,
}

## 通常ユーザー向けに並べる Preset（要件定義 §60）。
const USER_PRESETS: Array[int] = [
	Preset.EASY, Preset.NORMAL, Preset.HARD, Preset.VERY_HARD, Preset.EXTREME, Preset.CUSTOM
]


## Preset に対応する Strength を返す。
static func get_strength(preset: Preset) -> float:
	return STRENGTH_BY_PRESET.get(preset, STRENGTH_BY_PRESET[Preset.NORMAL])


## Preset から [CpuProfile] を作る。
static func create_profile(preset: Preset, mapping: CpuStrengthMapping = null) -> CpuProfile:
	var table: CpuStrengthMapping = (
		mapping if mapping != null else CpuStrengthMapping.create_default()
	)
	return table.create_profile(get_strength(preset))


## 通常の難易度 UI に並べる Preset かを返す（Machine は分離する。§71）。
static func is_user_preset(preset: Preset) -> bool:
	return preset in USER_PRESETS


## Preset の名前を返す。
static func get_preset_name(preset: Preset) -> String:
	return Preset.keys()[preset]
