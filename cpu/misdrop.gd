class_name Misdrop
extends RefCounted

## 意図しない配置（Misdrop。要件定義 §67）。
##
## CPU が選んだ配置を、一定の確率でわざと崩す。**何が起きるか**は 3 種類。
## [br]・[constant Kind.SHIFT]  … 左右に 1 マスずれる
## [br]・[constant Kind.ROTATE] … 回転が 1 つずれる
## [br]・[constant Kind.HOLD]   … Hold の判断を取り違える
##
## Issue #41 の「人間判断が必要になる条件」にあった Misdrop の中身は、この 3 種類
## とした。どれも「操作を 1 つ間違える」形にしてあり、盤面を直接壊さない。
##
## 崩した結果が置けない場合は、元の配置をそのまま返す。ミスで Crash させないため。
##
## 乱数は CPU ごとに独立した [RandomNumberGenerator] を持つ（#41 の制約）。

## Misdrop の種類。
enum Kind { NONE, SHIFT, ROTATE, HOLD }

## 種類ごとの起こりやすさ。合計で割って使う。
const KIND_WEIGHTS: Dictionary = {Kind.SHIFT: 5, Kind.ROTATE: 3, Kind.HOLD: 2}

var _profile: CpuProfile
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _last_kind: Kind = Kind.NONE


func _init(profile: CpuProfile = null, misdrop_seed: int = 0) -> void:
	_profile = profile if profile != null else CpuProfile.create_default()
	_rng.seed = misdrop_seed


## Seed を指定して初期状態へ戻す。
func reset(misdrop_seed: int) -> void:
	_rng.seed = misdrop_seed
	_last_kind = Kind.NONE


## 直前に起きた Misdrop の種類を返す。起きていなければ [constant Kind.NONE]。
func get_last_kind() -> Kind:
	return _last_kind


## 配置を崩すかどうかを決め、必要なら崩した配置を返す。
##
## 崩さない場合は [param placement] をそのまま返す。
func apply(board: Board, placement: Placement) -> Placement:
	_last_kind = Kind.NONE
	if placement == null or _profile.misdrop_rate <= 0.0:
		return placement
	if _rng.randf() >= _profile.misdrop_rate:
		return placement

	var kind: Kind = _pick_kind()
	var broken: Placement = _break(board, placement, kind)
	if broken == null:
		return placement

	_last_kind = kind
	return broken


func _pick_kind() -> Kind:
	var total: int = 0
	for weight in KIND_WEIGHTS.values():
		total += weight

	var roll: int = _rng.randi_range(0, total - 1)
	for kind in KIND_WEIGHTS:
		roll -= KIND_WEIGHTS[kind]
		if roll < 0:
			return kind
	return Kind.SHIFT


func _break(board: Board, placement: Placement, kind: Kind) -> Placement:
	match kind:
		Kind.SHIFT:
			return _shift(board, placement)
		Kind.ROTATE:
			return _rotate(board, placement)
		Kind.HOLD:
			return _flip_hold(placement)
	return null


# 左右に 1 マスずらす。ずらした先に置けなければ諦める。
func _shift(board: Board, placement: Placement) -> Placement:
	var direction: int = 1 if _rng.randf() < 0.5 else -1
	for step in [direction, -direction]:
		var moved := Vector2i(placement.position.x + step, placement.position.y)
		if Collision.can_place(board, placement.piece_type, placement.rotation, moved):
			var broken: Placement = _duplicate(placement)
			broken.position = _settle(board, placement.piece_type, placement.rotation, moved)
			return broken
	return null


# 回転を 1 つずらす。ずらした向きで置けなければ諦める。
func _rotate(board: Board, placement: Placement) -> Placement:
	var step: int = 1 if _rng.randf() < 0.5 else -1
	for direction in [step, -step]:
		var rotation: int = posmod(placement.rotation + direction, Piece.ROTATION_COUNT)
		if Collision.can_place(board, placement.piece_type, rotation, placement.position):
			var broken: Placement = _duplicate(placement)
			broken.rotation = rotation
			broken.position = _settle(board, placement.piece_type, rotation, placement.position)
			return broken
	return null


# Hold を使う／使わないを取り違える。種類が変わるので呼び出し側が置き直す。
func _flip_hold(placement: Placement) -> Placement:
	var broken: Placement = _duplicate(placement)
	broken.uses_hold = not placement.uses_hold
	return broken


# ずらした後も接地させる。宙に浮いた配置を返さないため。
static func _settle(board: Board, piece_type: int, rotation: int, origin: Vector2i) -> Vector2i:
	return GhostPiece.get_landing_position(board, piece_type, rotation, origin)


static func _duplicate(placement: Placement) -> Placement:
	var copy: Placement = Placement.create(
		placement.piece_type, placement.rotation, placement.position, placement.uses_hold
	)
	copy.score = placement.score
	return copy
