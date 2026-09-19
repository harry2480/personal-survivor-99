class_name PuzzleSession
extends RefCounted

## 1 人ぶんのパズル進行（Phase 1 の Game Core 全体をまとめる層）。
##
## Board / Piece / Rotation / Gravity / Lock Delay / Hold / NEXT / Line Clear を
## 1 つの状態遷移として扱う。Battle Layer（Phase 4）はこの上に載る。
##
## Game Core Layer に属するため、UI / Audio / Input / Scene / FileSystem に依存しない
## （要件定義 §17）。実時間も乱数のグローバル状態も持たないので、同じ Seed と同じ
## コマンド列からは必ず同じ結果になる（要件定義 §111）。

## Piece が出現した。
signal piece_spawned(type: int)

## Piece が Lock された。
signal piece_locked(type: int)

## 行が消えた。
signal lines_cleared(result: LineClearResult)

## Hold を使った。
signal piece_held(held_type: int)

## Top Out した（Spawn できなかった）。
signal topped_out

var _rules: GameRules
var _balance: GameBalance
var _board: Board
var _piece: ActivePiece
var _next_queue: NextQueue
var _hold: HoldSlot
var _rotation: RotationSystem
var _drop: DropSystem
var _auto_shift: AutoShift
var _lock_delay: LockDelay
var _combo: ComboState
var _b2b: BackToBackState
var _is_over: bool = false
var _cleared_lines_total: int = 0


func _init(
	rules: GameRules = null, randomizer: PieceRandomizer = null, balance: GameBalance = null
) -> void:
	_rules = rules if rules != null else GameRules.create_default()
	_balance = balance if balance != null else GameBalance.create_default()
	_board = Board.new()
	_piece = ActivePiece.new()
	_next_queue = NextQueue.new(randomizer)
	_hold = HoldSlot.new()
	_rotation = RotationSystem.new()
	_drop = DropSystem.new(_rules)
	_auto_shift = AutoShift.new(_rules)
	_lock_delay = LockDelay.new(_rules)
	_combo = ComboState.new()
	_b2b = BackToBackState.new(_balance)


## 新しいゲームを始める。Seed を指定すると Piece 列が再現できる。
func start(game_seed: int = 0) -> void:
	_board.clear()
	_next_queue.reset(game_seed)
	_hold.clear()
	_auto_shift.release_all()
	_drop.set_soft_dropping(false)
	_combo.reset()
	_b2b.reset()
	_is_over = false
	_cleared_lines_total = 0
	_spawn_next()


## 時間を進める。
func update(delta_sec: float) -> void:
	if _is_over or not _piece.is_active():
		return

	_apply_auto_shift(delta_sec)
	_apply_gravity(delta_sec)
	_apply_lock_delay(delta_sec)


# --- 操作 ------------------------------------------------------------------


## 横移動を押す。
func press_move(direction: AutoShift.Direction) -> void:
	if not _can_control():
		return
	var steps: int = _auto_shift.press(direction)
	_move_horizontally(_auto_shift.get_step_x(), steps)


## 横移動を離す。
func release_move(direction: AutoShift.Direction) -> void:
	_auto_shift.release(direction)


## Soft Drop の入力状態を設定する。
func set_soft_dropping(active: bool) -> void:
	_drop.set_soft_dropping(active)


## 回転する。成功したら true。
func rotate(direction: RotationSystem.Direction) -> bool:
	if not _can_control():
		return false

	var result: RotationResult = _rotation.rotate(
		_board, _piece.type, _piece.rotation, _piece.position, direction
	)
	if not result.success:
		return false

	_piece.rotation = result.rotation
	_piece.position = result.position
	_lock_delay.notify_action(LockDelay.Action.ROTATE)
	return true


## Hard Drop する。落ちたマス数を返す。
func hard_drop() -> int:
	if not _can_control():
		return 0

	var distance: int = DropSystem.hard_drop(_board, _piece)
	if _drop.locks_after_hard_drop():
		_lock_piece()
	return distance


## Hold を使う。使えたら true。
func hold() -> bool:
	if not _can_control() or not _hold.can_hold():
		return false

	var current_type: int = _piece.type
	var released: int = _hold.swap(current_type)
	piece_held.emit(current_type)

	if released == HoldSlot.EMPTY:
		_spawn_next()
	else:
		_spawn(released)
	return true


# --- 参照 ------------------------------------------------------------------


func get_board() -> Board:
	return _board


func get_active_piece() -> ActivePiece:
	return _piece


func get_next_types(count: int = NextQueue.MINIMUM_VISIBLE) -> Array[int]:
	return _next_queue.peek(count)


func get_held_type() -> int:
	return _hold.get_held_type()


func can_hold() -> bool:
	return _hold.can_hold()


## Ghost Piece の着地位置を返す。
func get_ghost_position() -> Vector2i:
	if not _piece.is_active():
		return Vector2i.ZERO
	return GhostPiece.get_landing_position(_board, _piece.type, _piece.rotation, _piece.position)


## Top Out してゲームが終わっているかを返す。
func is_over() -> bool:
	return _is_over


## これまでに消した行数の合計を返す。
func get_cleared_lines_total() -> int:
	return _cleared_lines_total


## 現在の連続 Line Clear 数を返す（要件定義 §34）。
func get_combo_count() -> int:
	return _combo.get_count()


## 現在の Back-to-Back の鎖の長さを返す（要件定義 §35）。
func get_b2b_chain() -> int:
	return _b2b.get_chain()


## Back-to-Back の効果が乗る状態かを返す。
func is_b2b_active() -> bool:
	return _b2b.is_active()


# --- 内部 ------------------------------------------------------------------


func _can_control() -> bool:
	return not _is_over and _piece.is_active()


func _apply_auto_shift(delta_sec: float) -> void:
	var steps: int = _auto_shift.update(delta_sec)
	if steps > 0:
		_move_horizontally(_auto_shift.get_step_x(), steps)


func _move_horizontally(step_x: int, steps: int) -> void:
	if step_x == 0 or steps <= 0:
		return

	var moved: bool = false
	for _i in range(steps):
		var candidate: Vector2i = _piece.position + Vector2i(step_x, 0)
		if not Collision.can_place(_board, _piece.type, _piece.rotation, candidate):
			break
		_piece.position = candidate
		moved = true

	if moved:
		_lock_delay.notify_action(LockDelay.Action.MOVE)


func _apply_gravity(delta_sec: float) -> void:
	var cells: int = _drop.advance(delta_sec)
	for _i in range(cells):
		var candidate: Vector2i = _piece.position + Vector2i.DOWN
		if not Collision.can_place(_board, _piece.type, _piece.rotation, candidate):
			break
		_piece.position = candidate


func _apply_lock_delay(delta_sec: float) -> void:
	var on_ground: bool = _piece.is_on_ground(_board)
	if _lock_delay.update(delta_sec, on_ground, _piece.get_lowest_y()):
		_lock_piece()


func _lock_piece() -> void:
	var locked_type: int = _piece.type
	Collision.place(_board, _piece.type, _piece.rotation, _piece.position)
	_piece.clear()
	piece_locked.emit(locked_type)

	var result: LineClearResult = LineClear.execute(_board)

	# Combo は Line Clear なしの Lock で終了するが、B2B は維持される（§34 / §35）。
	_combo.on_piece_locked(result.line_count)
	_b2b.on_piece_locked(result.type, result.line_count)

	if result.has_cleared():
		_cleared_lines_total += result.line_count
		lines_cleared.emit(result)

	_hold.on_piece_locked()
	_spawn_next()


func _spawn_next() -> void:
	_spawn(_next_queue.pop())


func _spawn(type: int) -> void:
	_piece.spawn(type)
	_drop.start_new_piece()
	_lock_delay.start_new_piece()

	# Spawn 位置に置けなければ Top Out（要件定義 §32 の完了条件）。
	if not _piece.can_place(_board):
		_piece.clear()
		_is_over = true
		topped_out.emit()
		return

	piece_spawned.emit(type)
