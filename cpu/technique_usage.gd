class_name TechniqueUsage
extends RefCounted

## 高度テクニックの使用率（要件定義 §69）。
##
## Strength が上がるほど、T-Spin や Combo を狙う頻度が上がる。狙うかどうかだけを
## 決め、実際の積み方は [PlacementSearch] の評価に任せる。
##
## テクニックごとに**必要な強さ**が違う。Downstack は低い Strength でも使うが、
## Perfect Clear は高い Strength でしか狙わない。
##
## 乱数は CPU ごとに独立した [RandomNumberGenerator] を持つ（#41 の制約）。

## 対象のテクニック（要件定義 §69）。
enum Technique {
	T_SPIN,
	COMBO,
	BACK_TO_BACK,
	PERFECT_CLEAR,
	DOWNSTACK,
	GARBAGE_CANCEL,
	GARBAGE_TIMING,
	DEFENSIVE_STACKING,
}

## テクニックごとの「狙い始める」目安（0.0〜1.0）。
##
## [member CpuProfile.technique_usage] がこの値を超えたぶんだけ、実際に狙う確率が
## 上がる。数値が大きいテクニックほど、強い CPU でしか出てこない。
const REQUIRED_USAGE: Dictionary = {
	Technique.DOWNSTACK: 0.0,
	Technique.DEFENSIVE_STACKING: 0.1,
	Technique.GARBAGE_CANCEL: 0.2,
	Technique.COMBO: 0.3,
	Technique.GARBAGE_TIMING: 0.4,
	Technique.BACK_TO_BACK: 0.5,
	Technique.T_SPIN: 0.6,
	Technique.PERFECT_CLEAR: 0.85,
}

var _profile: CpuProfile
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(profile: CpuProfile = null, usage_seed: int = 0) -> void:
	_profile = profile if profile != null else CpuProfile.create_default()
	_rng.seed = usage_seed


## Seed を指定して初期状態へ戻す。
func reset(usage_seed: int) -> void:
	_rng.seed = usage_seed


## そのテクニックを狙う確率（0.0〜1.0）を返す。
func get_chance(technique: Technique) -> float:
	var required: float = REQUIRED_USAGE.get(technique, 0.5)
	var usage: float = clampf(_profile.technique_usage, 0.0, 1.0)
	if usage <= required:
		return 0.0
	if is_equal_approx(required, 1.0):
		return 0.0

	# 目安を超えたぶんを、残りの幅で正規化する。
	return clampf((usage - required) / (1.0 - required), 0.0, 1.0)


## そのテクニックを狙うかを決める。
func should_attempt(technique: Technique) -> bool:
	var chance: float = get_chance(technique)
	if chance <= 0.0:
		return false
	if chance >= 1.0:
		return true
	return _rng.randf() < chance


## 使う可能性があるテクニックを返す（確率が 0 より大きいもの）。
func get_available_techniques() -> Array[int]:
	var available: Array[int] = []
	for technique in REQUIRED_USAGE:
		if get_chance(technique) > 0.0:
			available.append(technique)
	return available


## テクニックの名前を返す。ログとテスト用。
static func get_technique_name(technique: Technique) -> String:
	return Technique.keys()[technique]
