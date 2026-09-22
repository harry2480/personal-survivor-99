class_name TSpinDetector
extends RefCounted

## T-Spin / T-Spin Mini の判定（要件定義 §33）。
##
## 判定ロジックをここだけに閉じ、Board にも Rotation にも埋め込まない。方式を
## 変えたい場合はこのクラスを継承して [method detect] を差し替える。進行側は
## [TSpinContext] を渡して結果を受け取るだけ。
##
## 採用している方式は **3 コーナー方式**。
## [br]・直前の操作が回転であること
## [br]・T の中心の四隅のうち 3 つ以上が埋まっている（壁と床も埋まり扱い）こと
## [br]・「正面」側の隅が 2 つとも埋まっていれば T-Spin、片方だけなら T-Spin Mini
## [br]・ただし Kick Table の最後のオフセットで収まった回転は Mini にしない
##
## 状態を持たないので、同じ [TSpinContext] からは必ず同じ結果になる。

## 判定結果。
enum Result { NONE, MINI, FULL }

## 3 コーナー方式で必要な、埋まっている隅の数。
const REQUIRED_CORNERS: int = 3

# T の Bounding Box（3×3）における四隅。
const _CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]

# 回転状態ごとの「正面」側の隅（T が向いている方向の 2 つ）。
const _FRONT_CORNERS: Array[Array] = [
	[Vector2i(0, 0), Vector2i(2, 0)],  # SPAWN: 上を向いている
	[Vector2i(2, 0), Vector2i(2, 2)],  # RIGHT: 右を向いている
	[Vector2i(0, 2), Vector2i(2, 2)],  # TWO:   下を向いている
	[Vector2i(0, 0), Vector2i(0, 2)],  # LEFT:  左を向いている
]


## T-Spin かどうかを判定する。
func detect(context: TSpinContext) -> Result:
	if not _is_candidate(context):
		return Result.NONE
	if count_occupied_corners(context) < REQUIRED_CORNERS:
		return Result.NONE

	# 正面の 2 隅が埋まっていれば通常の T-Spin。
	# Kick Table の最後で収まった回転も、正面が開いていても Mini にしない。
	var is_full: bool = count_occupied_front_corners(context) == 2 or context.used_last_kick()
	return Result.FULL if is_full else Result.MINI


# 判定の前提（T であること、直前が回転であること）を満たすかを返す。
func _is_candidate(context: TSpinContext) -> bool:
	if context == null or context.board == null:
		return false
	if context.piece_type != Piece.Type.T:
		return false
	return context.last_action_was_rotation


## 四隅のうち埋まっている数を返す。
func count_occupied_corners(context: TSpinContext) -> int:
	var occupied: int = 0
	for corner in _CORNERS:
		if _is_occupied(context, corner):
			occupied += 1
	return occupied


## 正面側の隅のうち埋まっている数を返す。
func count_occupied_front_corners(context: TSpinContext) -> int:
	var front: Array = _FRONT_CORNERS[context.rotation]
	var occupied: int = 0
	for corner in front:
		if _is_occupied(context, corner):
			occupied += 1
	return occupied


## 結果の名前を返す。ログとテスト用。
static func get_result_name(result: Result) -> String:
	return Result.keys()[result]


# 盤面の外は「埋まっている」として扱う。壁際・床際の T-Spin を成立させるため。
func _is_occupied(context: TSpinContext, corner_offset: Vector2i) -> bool:
	var x: int = context.position.x + corner_offset.x
	var y: int = context.position.y + corner_offset.y

	if not context.board.is_inside(x, y):
		return true
	return not context.board.is_cell_empty(x, y)
