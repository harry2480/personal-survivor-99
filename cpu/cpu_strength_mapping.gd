class_name CpuStrengthMapping
extends Resource

## Strength から各パラメータへの変換表（要件定義 §78）。
##
## 通常ユーザーは Strength を 1 つ指定するだけでよい（§59）。この Resource が
## 折れ線として変換表を持ち、[method create_profile] が [CpuProfile] を組み立てる。
## **カーブはコードではなくデータ**なので、調整は値の差し替えで済む。
##
## [member strength_points] を超える Strength も扱える。100 を絶対上限にしないため
## （§59）、最後の区間の傾きをそのまま延長し、物理的な限界（反応 0 秒・ミス 0%・
## 品質 1.0）で頭打ちにする。

## 折れ線の節点となる Strength。昇順に並べる。
@export
var strength_points: PackedFloat32Array = PackedFloat32Array([0.0, 30.0, 50.0, 70.0, 85.0, 100.0])

## 節点ごとの反応遅延（秒。要件定義 §65）。
@export
var reaction_time_sec: PackedFloat32Array = PackedFloat32Array([0.5, 0.3, 0.15, 0.07, 0.03, 0.02])

## 節点ごとの PPS（要件定義 §66）。
@export
var pieces_per_second: PackedFloat32Array = PackedFloat32Array([0.8, 1.5, 2.5, 3.0, 4.0, 5.0])

## 節点ごとの Misdrop 率（要件定義 §67）。
@export
var misdrop_rate: PackedFloat32Array = PackedFloat32Array([0.3, 0.15, 0.06, 0.02, 0.005, 0.0])

## 節点ごとの Placement Quality（要件定義 §62）。
@export
var placement_quality: PackedFloat32Array = PackedFloat32Array([0.15, 0.4, 0.6, 0.8, 0.93, 1.0])

## 節点ごとの Lookahead（要件定義 §64）。
@export var lookahead: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 1.0, 1.0, 1.0])

## 節点ごとの高度テクニック使用率（要件定義 §69）。
@export var technique_usage: PackedFloat32Array = PackedFloat32Array([0.0, 0.1, 0.3, 0.5, 0.8, 1.0])

## 節点ごとの Garbage のさばき方の上手さ。
@export var garbage_skill: PackedFloat32Array = PackedFloat32Array([0.1, 0.3, 0.5, 0.7, 0.88, 1.0])

## 節点ごとの Target の選び方の上手さ。
@export var target_skill: PackedFloat32Array = PackedFloat32Array([0.1, 0.3, 0.5, 0.7, 0.88, 1.0])

## 節点ごとの穴の避け方の強さ（評価の軸）。
@export var hole_avoidance: PackedFloat32Array = PackedFloat32Array([0.4, 0.7, 1.0, 1.2, 1.4, 1.5])

## 節点ごとの表面の整え方の強さ（評価の軸）。
@export
var surface_management: PackedFloat32Array = PackedFloat32Array([0.3, 0.6, 1.0, 1.2, 1.4, 1.5])


## 既定の変換表を作る。
static func create_default() -> CpuStrengthMapping:
	return CpuStrengthMapping.new()


## Strength から [CpuProfile] を組み立てる（要件定義 §78）。
func create_profile(strength: float) -> CpuProfile:
	var profile := CpuProfile.new()
	profile.profile_name = "Strength %.0f" % strength
	profile.strength = strength

	profile.reaction_time_sec = maxf(0.0, sample(reaction_time_sec, strength))
	profile.pieces_per_second = maxf(0.1, sample(pieces_per_second, strength))
	profile.misdrop_rate = clampf(sample(misdrop_rate, strength), 0.0, 1.0)
	profile.placement_quality = clampf(sample(placement_quality, strength), 0.0, 1.0)
	profile.lookahead = maxi(0, int(round(sample(lookahead, strength))))
	profile.technique_usage = clampf(sample(technique_usage, strength), 0.0, 1.0)
	profile.garbage_skill = clampf(sample(garbage_skill, strength), 0.0, 1.0)
	profile.target_skill = clampf(sample(target_skill, strength), 0.0, 1.0)
	profile.hole_avoidance = maxf(0.0, sample(hole_avoidance, strength))
	profile.surface_management = maxf(0.0, sample(surface_management, strength))

	return profile


## 変換表から 1 つの値を取り出す。
##
## 節点の間は線形補間し、両端の外側は端の区間の傾きをそのまま延長する。
func sample(values: PackedFloat32Array, strength: float) -> float:
	if values.is_empty() or strength_points.is_empty():
		return 0.0
	if values.size() == 1 or strength_points.size() == 1:
		return values[0]

	var count: int = mini(values.size(), strength_points.size())

	# 下端より小さい場合は最初の区間を延長する。
	if strength <= strength_points[0]:
		return _extrapolate(values, 0, 1, strength)

	for index in range(1, count):
		if strength <= strength_points[index]:
			return _extrapolate(values, index - 1, index, strength)

	# 上端より大きい場合は最後の区間を延長する（100 を絶対上限にしない。§59）。
	return _extrapolate(values, count - 2, count - 1, strength)


## 変換表の形が正しいかを返す。差し替えたときの検証に使う。
func is_valid() -> bool:
	if strength_points.size() < 2:
		return false
	for index in range(1, strength_points.size()):
		if strength_points[index] <= strength_points[index - 1]:
			return false
	return true


func _extrapolate(values: PackedFloat32Array, left: int, right: int, strength: float) -> float:
	var x0: float = strength_points[left]
	var x1: float = strength_points[right]
	if is_equal_approx(x0, x1):
		return values[left]

	var ratio: float = (strength - x0) / (x1 - x0)
	return values[left] + (values[right] - values[left]) * ratio
