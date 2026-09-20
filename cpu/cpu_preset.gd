class_name CpuPreset
extends RefCounted

## CPU の難易度 Preset（要件定義 §60 / §70〜§72）。
##
## **Preset は内部 Parameter Set への Alias**。実体は Strength の値で、
## [CpuStrengthMapping] を通して [CpuProfile] になる。通常ユーザーは Preset か
## Strength のどちらかを選べばよく、個別調整は Advanced Settings（#45）。
##
## Preset は 3 種類に分かれる。
## [br]・通常難易度 … Easy 〜 Extreme と Custom（[constant USER_PRESETS]）
## [br]・Machine    … 人間の限界を外した CPU（要件定義 §71）
## [br]・Human-like … 人間の限界を残したまま強い CPU（要件定義 §72）
##
## Machine と Human-like は通常の難易度 UI に混ぜない（[constant DEVELOPER_PRESETS]）。

## 選べる Preset。
enum Preset { EASY, NORMAL, HARD, VERY_HARD, EXTREME, CUSTOM, MACHINE, HUMAN_LIKE }

## Custom / Developer Mode で指定できる Strength の上限（要件定義 §59）。
##
## 標準 UI は 0〜100 だが、100 を絶対上限にしない。120 / 150 / 200 を許す。
const MAX_CUSTOM_STRENGTH: float = 200.0

## Preset に対応する Strength（要件定義 §59 の目安）。
##
## [constant Preset.CUSTOM] はユーザーが指定するため、ここでは中央値を持つ。
## [constant Preset.MACHINE] と [constant Preset.HUMAN_LIKE] は 100 を超える。
## 100 を絶対上限にしないため（§59）。
const STRENGTH_BY_PRESET: Dictionary = {
	Preset.EASY: 30.0,
	Preset.NORMAL: 50.0,
	Preset.HARD: 70.0,
	Preset.VERY_HARD: 85.0,
	Preset.EXTREME: 100.0,
	Preset.CUSTOM: 50.0,
	Preset.MACHINE: 150.0,
	Preset.HUMAN_LIKE: 120.0,
}

## 通常ユーザー向けに並べる Preset（要件定義 §60 / §79）。
const USER_PRESETS: Array[int] = [
	Preset.EASY, Preset.NORMAL, Preset.HARD, Preset.VERY_HARD, Preset.EXTREME, Preset.CUSTOM
]

## Custom / Developer Mode でのみ出す Preset（要件定義 §71 / §72）。
const DEVELOPER_PRESETS: Array[int] = [Preset.MACHINE, Preset.HUMAN_LIKE]


## Preset に対応する Strength を返す。
static func get_strength(preset: Preset) -> float:
	return STRENGTH_BY_PRESET.get(preset, STRENGTH_BY_PRESET[Preset.NORMAL])


## Preset から [CpuProfile] を作る。
##
## Machine は人間の限界を外し、Human-like は人間の限界を掛ける。通常難易度は
## 変換表（要件定義 §78）のとおりに作る。
static func create_profile(preset: Preset, mapping: CpuStrengthMapping = null) -> CpuProfile:
	return create_profile_at(preset, get_strength(preset), mapping)


## Strength を指定して Preset の性格のまま [CpuProfile] を作る。
##
## Custom で Strength だけ動かしたいとき（要件定義 §77 / §79）に使う。
## Strength は 0 〜 [constant MAX_CUSTOM_STRENGTH] に収める。
static func create_profile_at(
	preset: Preset, strength: float, mapping: CpuStrengthMapping = null
) -> CpuProfile:
	var table: CpuStrengthMapping = (
		mapping if mapping != null else CpuStrengthMapping.create_default()
	)
	var value: float = clamp_strength(strength)

	if preset == Preset.MACHINE:
		return table.create_machine_profile(value)
	if preset == Preset.HUMAN_LIKE:
		return table.create_human_like_profile(value)

	var profile: CpuProfile = table.create_profile(value)
	profile.profile_name = "%s %.0f" % [get_preset_name(preset), value]
	return profile


## Strength を扱える範囲へ収める（要件定義 §59）。
static func clamp_strength(strength: float) -> float:
	return clampf(strength, 0.0, MAX_CUSTOM_STRENGTH)


## 通常の難易度 UI に並べる Preset かを返す（Machine は分離する。§71）。
static func is_user_preset(preset: Preset) -> bool:
	return preset in USER_PRESETS


## Custom / Developer Mode でのみ出す Preset かを返す（要件定義 §71 / §72）。
static func is_developer_preset(preset: Preset) -> bool:
	return preset in DEVELOPER_PRESETS


## Preset の名前を返す。
static func get_preset_name(preset: Preset) -> String:
	return Preset.keys()[preset]
