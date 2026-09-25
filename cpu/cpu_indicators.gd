class_name CpuIndicators
extends RefCounted

## CPU の状態を表す軽量な指標（要件定義 §82）。
##
## Detailed / Lightweight のどちらでもこの形で状態を出せるようにしておく。
## **切り替えの前後でこの指標が連続する**ことが Promotion / Demotion の条件
## （要件定義 §83 / #42 の完了条件）。

## 積み上がっている高さ（マス数）。
var stack_height: int = 0

## 穴の数。
var holes: int = 0

## 表面の凸凹。
var roughness: int = 0

## 1 秒あたりに出す Attack 行数の見込み。
var attack_rate: float = 0.0

## 1 秒あたりに捌ける Garbage 行数の見込み。
var defense_rate: float = 0.0

## 腕前（0.0〜1.0）。Strength から決まる。
var skill: float = 0.0

## 受信待ちの Garbage 行数。
var incoming_garbage: int = 0

## 盤面の危険度。
var danger_level: DangerLevel.Level = DangerLevel.Level.SAFE


## 盤面から指標を組み立てる（Detailed 側の状態を Lightweight の形へ落とす）。
static func from_board(board: Board, metrics: BoardMetrics = null) -> CpuIndicators:
	var indicators := CpuIndicators.new()
	if board == null:
		return indicators

	var measured: BoardMetrics = metrics if metrics != null else BoardMetrics.new()
	measured.measure(board)

	indicators.stack_height = measured.max_height
	indicators.holes = measured.holes
	indicators.roughness = measured.bumpiness
	indicators.danger_level = DangerLevel.get_level(board)
	return indicators


## Profile から腕前（0.0〜2.0）を決める。Strength 100 で 1.0。
static func estimate_skill(profile: CpuProfile) -> float:
	return clampf(profile.strength / 100.0, 0.0, 2.0)


## Profile から、1 秒あたりに出す Attack 行数を見積もる。
##
## Detailed / Lightweight で同じ見積もりを使う。切り替えで値が飛ばないため。
static func estimate_attack_rate(profile: CpuProfile) -> float:
	return profile.pieces_per_second * estimate_skill(profile) * profile.attack_rate_factor


## Profile から、1 秒あたりに捌ける Garbage 行数を見積もる。
static func estimate_defense_rate(profile: CpuProfile) -> float:
	return (
		profile.pieces_per_second
		* clampf(profile.garbage_skill, 0.0, 1.0)
		* profile.defense_rate_factor
	)


## 別の指標の内容を写す。
func copy_from(other: CpuIndicators) -> void:
	if other == null:
		return
	stack_height = other.stack_height
	holes = other.holes
	roughness = other.roughness
	attack_rate = other.attack_rate
	defense_rate = other.defense_rate
	skill = other.skill
	incoming_garbage = other.incoming_garbage
	danger_level = other.danger_level


## 2 つの指標が十分近いかを返す。切り替えの連続性を確かめるために使う。
func is_close_to(other: CpuIndicators, height_tolerance: int = 2, hole_tolerance: int = 2) -> bool:
	if other == null:
		return false
	if absi(stack_height - other.stack_height) > height_tolerance:
		return false
	if absi(holes - other.holes) > hole_tolerance:
		return false
	return danger_level == other.danger_level
