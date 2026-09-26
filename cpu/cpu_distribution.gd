class_name CpuDistribution
extends Resource

## 99 人戦での CPU Strength の配り方（要件定義 §73 / §74）。
##
## 全員同じ強さにも、ばらつかせることにもできる。
## [br]・[member fixed_strength_enabled] が [code]true[/code] … 全員同じ Strength（§74）
## [br]・[code]false[/code] … 平均・最小・最大・ばらつきで分布させる（§73）
##
## **Seed を決めれば同じ分布が再現される**（要件定義 §110 / #44 の制約）。
## グローバルな乱数状態は見ない。
##
## 値はコードではなくこの Resource のデータで持つ（要件定義 §38）。
## 既定値は要件定義 §73 の例（Average 75 / Min 45 / Max 110 / Variance 15）。

## 平均 Strength（要件定義 §73）。
@export_range(0.0, 200.0, 1.0, "or_greater") var average_strength: float = 75.0

## 最小 Strength。これより弱い CPU は作らない。
@export_range(0.0, 200.0, 1.0, "or_greater") var minimum_strength: float = 45.0

## 最大 Strength。これより強い CPU は作らない。
@export_range(0.0, 200.0, 1.0, "or_greater") var maximum_strength: float = 110.0

## Strength のばらつき（標準偏差）。0 にすると全員が平均値になる。
@export_range(0.0, 100.0, 0.5, "or_greater") var strength_variance: float = 15.0

## 全 CPU を同じ Strength にするか（Fixed Strength Mode。要件定義 §74）。
@export var fixed_strength_enabled: bool = false

## Fixed Strength Mode で全員に使う Strength。
@export_range(0.0, 200.0, 1.0, "or_greater") var fixed_strength: float = 100.0

## この分布から作る CPU の性格（要件定義 §71 / §72）。
##
## 通常は [constant CpuPreset.Preset.CUSTOM]。Machine / Human-like を選ぶと、
## Strength はそのままに人間の限界の扱いだけが変わる。
@export var preset: CpuPreset.Preset = CpuPreset.Preset.CUSTOM

## 全 CPU の [CpuProfile] に上書きする値（Advanced Settings。要件定義 §77 / §78）。
##
## key は [constant CpuSettings.ADVANCED_KEYS] のいずれか。空なら上書きしない。
@export var profile_overrides: Dictionary = {}


## 既定の分布を作る（要件定義 §73 の例）。
static func create_default() -> CpuDistribution:
	return CpuDistribution.new()


## 全員を同じ Strength にする分布を作る（Fixed Strength Mode。要件定義 §74）。
static func create_fixed(strength: float) -> CpuDistribution:
	var distribution := CpuDistribution.new()
	distribution.fixed_strength_enabled = true
	distribution.fixed_strength = strength
	return distribution


## CPU [param count] 体ぶんの Strength を返す。
##
## 同じ [param distribution_seed] からは同じ並びが返る（#44 の完了条件）。
func generate(count: int, distribution_seed: int = 0) -> PackedFloat32Array:
	var strengths := PackedFloat32Array()
	if count <= 0:
		return strengths

	if fixed_strength_enabled:
		for _index in range(count):
			strengths.append(CpuPreset.clamp_strength(fixed_strength))
		return strengths

	var rng := RandomNumberGenerator.new()
	rng.seed = distribution_seed
	var low: float = minf(minimum_strength, maximum_strength)
	var high: float = maxf(minimum_strength, maximum_strength)

	for _index in range(count):
		# 正規分布で散らし、最小・最大で挟む。ばらつき 0 なら平均そのもの。
		var value: float = rng.randfn(average_strength, maxf(0.0, strength_variance))
		strengths.append(CpuPreset.clamp_strength(clampf(value, low, high)))

	return strengths


## CPU [param count] 体ぶんの [CpuProfile] を作る。
func create_profiles(
	count: int, mapping: CpuStrengthMapping = null, distribution_seed: int = 0
) -> Array[CpuProfile]:
	var table: CpuStrengthMapping = (
		mapping if mapping != null else CpuStrengthMapping.create_default()
	)
	var profiles: Array[CpuProfile] = []
	for strength in generate(count, distribution_seed):
		var profile: CpuProfile = CpuPreset.create_profile_at(preset, strength, table)
		CpuSettings.apply_overrides(profile, profile_overrides)
		profiles.append(profile)
	return profiles


## 設定の形が正しいかを返す。差し替えたときの検証に使う。
func is_valid() -> bool:
	if minimum_strength > maximum_strength:
		return false
	if strength_variance < 0.0:
		return false
	return average_strength >= 0.0 and fixed_strength >= 0.0
