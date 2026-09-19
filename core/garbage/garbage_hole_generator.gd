class_name GarbageHoleGenerator
extends RefCounted

## Garbage Line の Hole（穴）の位置を決める（要件定義 §43）。
##
## 生成方式は設定で選べる。Seed 付きの [RandomNumberGenerator] を持つので、同じ
## Seed からは必ず同じ穴の並びになる（要件定義 §110）。
##
## グローバル乱数は使わない。他所の乱数消費で盤面が変わってしまうため。

## 穴の開け方。
enum Mode {
	## 1 行ごとに穴の位置を選び直す。
	PER_LINE,
	## 1 回の Garbage の中では同じ列に穴を開ける。
	SAME_COLUMN_PER_EVENT,
	## 前回と同じ列は選ばない（PER_LINE の変種）。
	PER_LINE_NO_REPEAT,
}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mode: Mode = Mode.SAME_COLUMN_PER_EVENT
var _seed: int = 0
var _last_hole_x: int = -1


func _init(mode: Mode = Mode.SAME_COLUMN_PER_EVENT, generator_seed: int = 0) -> void:
	_mode = mode
	reset(generator_seed)


## Seed を指定して初期状態へ戻す。
func reset(new_seed: int) -> void:
	_seed = new_seed
	_rng.seed = new_seed
	_last_hole_x = -1


## 現在の Seed を返す。
func get_seed() -> int:
	return _seed


## 生成方式を返す。
func get_mode() -> Mode:
	return _mode


## 生成方式を設定する。
func set_mode(mode: Mode) -> void:
	_mode = mode


## [param line_count] 行ぶんの穴の列を、上の行から順に返す。
func generate(line_count: int) -> PackedInt32Array:
	var holes: PackedInt32Array = PackedInt32Array()
	if line_count <= 0:
		return holes

	var shared_x: int = _pick_column()
	for index in range(line_count):
		match _mode:
			Mode.SAME_COLUMN_PER_EVENT:
				holes.append(shared_x)
			Mode.PER_LINE_NO_REPEAT:
				holes.append(_pick_column_avoiding_last() if index > 0 else shared_x)
			_:
				holes.append(shared_x if index == 0 else _pick_column())

	_last_hole_x = holes[holes.size() - 1]
	return holes


func _pick_column() -> int:
	var column: int = _rng.randi_range(0, Board.WIDTH - 1)
	_last_hole_x = column
	return column


func _pick_column_avoiding_last() -> int:
	if Board.WIDTH <= 1:
		return 0

	# 直前の列を除いた範囲から選び、境界で読み替える。乱数を 1 回しか消費しないので
	# 再現性を保ちやすい。
	var previous: int = _last_hole_x
	var column: int = _rng.randi_range(0, Board.WIDTH - 2)
	if previous >= 0 and column >= previous:
		column += 1
	_last_hole_x = column
	return column
