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
## 品質 1.0）で頭打ちにする。節点は Machine 相当の 150 まで持たせてあるので、
## 100〜150 は延長ではなく表の値で決まる。
##
## 同じ Strength でも [method create_machine_profile] は人間の限界を外し、
## [method create_human_like_profile] は人間の限界を掛ける（要件定義 §71 / §72）。

## 折れ線の節点となる Strength。昇順に並べる。
@export var strength_points: PackedFloat32Array = PackedFloat32Array(
	[0.0, 30.0, 50.0, 70.0, 85.0, 100.0, 150.0]
)

## 節点ごとの反応遅延（秒。要件定義 §65）。
@export var reaction_time_sec: PackedFloat32Array = PackedFloat32Array(
	[0.5, 0.3, 0.15, 0.07, 0.03, 0.01, 0.0]
)

## 節点ごとの PPS（要件定義 §66）。
@export
var pieces_per_second: PackedFloat32Array = PackedFloat32Array([0.8, 1.5, 2.5, 3.0, 4.0, 5.0, 20.0])

## 節点ごとの Misdrop 率（要件定義 §67）。
@export
var misdrop_rate: PackedFloat32Array = PackedFloat32Array([0.3, 0.15, 0.06, 0.02, 0.005, 0.0, 0.0])

## 節点ごとの Placement Quality（要件定義 §62）。
@export var placement_quality: PackedFloat32Array = PackedFloat32Array(
	[0.15, 0.4, 0.6, 0.8, 0.93, 1.0, 1.0]
)

## 節点ごとの Lookahead（要件定義 §64）。
@export var lookahead: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 1.0])

## 節点ごとの高度テクニック使用率（要件定義 §69）。
@export
var technique_usage: PackedFloat32Array = PackedFloat32Array([0.0, 0.1, 0.3, 0.5, 0.8, 1.0, 1.0])

## 節点ごとの Garbage のさばき方の上手さ。
@export
var garbage_skill: PackedFloat32Array = PackedFloat32Array([0.1, 0.3, 0.5, 0.7, 0.88, 1.0, 1.0])

## 節点ごとの Target の選び方の上手さ。
@export
var target_skill: PackedFloat32Array = PackedFloat32Array([0.1, 0.3, 0.5, 0.7, 0.88, 1.0, 1.0])

## 節点ごとの穴の避け方の強さ（評価の軸）。
@export
var hole_avoidance: PackedFloat32Array = PackedFloat32Array([0.4, 0.7, 1.0, 1.2, 1.4, 1.5, 1.8])

## 節点ごとの表面の整え方の強さ（評価の軸）。
@export
var surface_management: PackedFloat32Array = PackedFloat32Array([0.3, 0.6, 1.0, 1.2, 1.4, 1.5, 1.8])

## 節点ごとの Garbage のさばき方の強さ（評価の軸。要件定義 §61）。
@export
var garbage_management: PackedFloat32Array = PackedFloat32Array([0.4, 0.7, 1.0, 1.2, 1.4, 1.5, 1.8])

## 節点ごとの立て直しの強さ（評価の軸。要件定義 §61）。
@export
var recovery_ability: PackedFloat32Array = PackedFloat32Array([0.4, 0.7, 1.0, 1.2, 1.4, 1.5, 1.8])

## 節点ごとの Beam Width（深く読む候補の数）。
##
## 強いほど広く深く読む。Machine（150）は [member CpuProfile.beam_width] の
## 上限まで使う。
@export
var beam_width: PackedFloat32Array = PackedFloat32Array([2.0, 3.0, 4.0, 8.0, 12.0, 16.0, 40.0])

# --- Human-like 高難易度の限界（要件定義 §72） ------------------------------
# Machine と違い「人間の操作限界」を残した高難易度のための上限・下限。
# Strength をいくら上げても、この線を越えないところで頭打ちにする。

## Human-like で許す PPS の上限（要件定義 §72 の「最大 3 PPS」）。
@export_range(0.5, 20.0, 0.1, "or_greater") var human_max_pieces_per_second: float = 3.0

## Human-like で残す反応遅延の下限（秒）。人間の反応の下限に相当する。
@export_range(0.0, 1.0, 0.005, "or_greater") var human_min_reaction_time_sec: float = 0.05

## Human-like で残す Misdrop 率の下限。「極小だが 0 ではない」（要件定義 §72）。
@export_range(0.0, 1.0, 0.0005) var human_min_misdrop_rate: float = 0.002


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
	profile.beam_width = clampi(
		int(round(sample(beam_width, strength))), 1, CpuProfile.MAX_BEAM_WIDTH
	)
	profile.technique_usage = clampf(sample(technique_usage, strength), 0.0, 1.0)
	profile.garbage_skill = clampf(sample(garbage_skill, strength), 0.0, 1.0)
	profile.target_skill = clampf(sample(target_skill, strength), 0.0, 1.0)
	profile.hole_avoidance = maxf(0.0, sample(hole_avoidance, strength))
	profile.surface_management = maxf(0.0, sample(surface_management, strength))
	profile.garbage_management = maxf(0.0, sample(garbage_management, strength))
	profile.recovery_ability = maxf(0.0, sample(recovery_ability, strength))

	return profile


## 人間の限界を外した [CpuProfile] を作る（Machine。要件定義 §71）。
##
## 反応 0 / Misdrop 0 / Search Quality 最大 / Lookahead 最大 / Placement Speed 最大 /
## Targeting 最大。通常の Difficulty とは分離して使う（§71 / #43 の制約）。
func create_machine_profile(strength: float) -> CpuProfile:
	var profile: CpuProfile = create_profile(strength)
	profile.profile_name = "Machine %.0f" % strength

	profile.reaction_time_sec = 0.0
	profile.misdrop_rate = 0.0
	profile.placement_quality = 1.0
	profile.lookahead = PlacementSearch.MAX_SEARCH_DEPTH - 1
	profile.beam_width = CpuProfile.MAX_BEAM_WIDTH
	profile.pieces_per_second = maxf(profile.pieces_per_second, sample(pieces_per_second, 150.0))
	profile.technique_usage = 1.0
	profile.garbage_skill = 1.0
	profile.target_skill = 1.0

	return profile


## 人間の限界を残した [CpuProfile] を作る（Human-like。要件定義 §72）。
##
## 思考は Strength なりに強いまま、PPS の上限・反応遅延・極小の Misdrop を残す。
## 「強いが人間的」な CPU を Machine と区別するための口（#43 の完了条件）。
func create_human_like_profile(strength: float) -> CpuProfile:
	var profile: CpuProfile = create_profile(strength)
	profile.profile_name = "Human-like %.0f" % strength

	profile.pieces_per_second = minf(profile.pieces_per_second, human_max_pieces_per_second)
	profile.reaction_time_sec = maxf(profile.reaction_time_sec, human_min_reaction_time_sec)
	profile.misdrop_rate = maxf(profile.misdrop_rate, human_min_misdrop_rate)

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
##
## 節点が昇順であることに加え、どの列も節点と同じ数の値を持つこと。
## 数が違うと [method sample] は短い方に合わせてしまい、端の延長がずれる。
func is_valid() -> bool:
	if strength_points.size() < 2:
		return false
	for index in range(1, strength_points.size()):
		if strength_points[index] <= strength_points[index - 1]:
			return false
	for values in _get_tables():
		if values.size() != strength_points.size():
			return false
	return true


func _get_tables() -> Array[PackedFloat32Array]:
	return [
		reaction_time_sec,
		pieces_per_second,
		misdrop_rate,
		placement_quality,
		lookahead,
		technique_usage,
		garbage_skill,
		target_skill,
		hole_avoidance,
		surface_management,
		garbage_management,
		recovery_ability,
		beam_width,
	]


func _extrapolate(values: PackedFloat32Array, left: int, right: int, strength: float) -> float:
	var x0: float = strength_points[left]
	var x1: float = strength_points[right]
	if is_equal_approx(x0, x1):
		return values[left]

	var ratio: float = (strength - x0) / (x1 - x0)
	return values[left] + (values[right] - values[left]) * ratio
