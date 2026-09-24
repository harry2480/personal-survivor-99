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

## T-Spin と判定された（[enum TSpinDetector.Result]）。
signal t_spin_detected(result: int)

## Perfect Clear が成立した。
signal perfect_clear_achieved

## Attack が発生した。Incoming の相殺後に残った余剰の行数（要件定義 §42）。
## 送り先の決定は Battle Layer の責務（Phase 4）。
signal attack_generated(amount: int, context: AttackContext)

## Incoming Garbage が盤面へ適用された。
signal garbage_applied(line_count: int)

## Incoming Garbage が Event 単位で盤面へ適用された。KO の帰属判定に使う（要件定義 §56）。
## 1 回の Lock で複数の Event が適用されると、Event ごとに 1 回ずつ通知する。
signal garbage_event_applied(source_player_id: int, line_count: int)

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
var _scoring: ScoringState
var _attack_calculator: AttackCalculator
var _garbage_queue: GarbageQueue
var _hole_generator: GarbageHoleGenerator
var _t_spin_detector: TSpinDetector
var _last_action_was_rotation: bool = false
var _last_kick_index: int = -1
var _last_kick_table_size: int = 0
var _is_over: bool = false
var _game_time_sec: float = 0.0
var _next_attack_id: int = 0


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
	_scoring = ScoringState.new(_balance)
	_attack_calculator = AttackCalculator.new(_balance)
	_garbage_queue = GarbageQueue.new()
	_garbage_queue.event_applied.connect(garbage_event_applied.emit)
	_hole_generator = GarbageHoleGenerator.new(_balance.garbage_hole_mode)
	_t_spin_detector = TSpinDetector.new()


## 新しいゲームを始める。Seed を指定すると Piece 列が再現できる。
func start(game_seed: int = 0) -> void:
	_board.clear()
	_next_queue.reset(game_seed)
	_hold.clear()
	_auto_shift.release_all()
	_drop.set_soft_dropping(false)
	_scoring.reset()
	_garbage_queue.clear()
	# Attack ID も初期状態へ戻す。残っていると、同じ操作列でも再開の前後で
	# 同時刻 Event の順序が変わる（要件定義 §110 / §111）。
	_next_attack_id = 0
	_hole_generator.reset(game_seed)
	_game_time_sec = 0.0
	_is_over = false
	_spawn_next()


## 時間を進める。
func update(delta_sec: float) -> void:
	if _is_over or not _piece.is_active():
		return

	_game_time_sec += maxf(0.0, delta_sec)
	_apply_auto_shift(delta_sec)
	# 着地までに使った時間は Lock Delay に含めない。含めると、同じ実時間でも
	# delta の刻み方で Lock のタイミングが変わる（要件定義 §29 / §30）。
	var airborne_sec: float = _apply_gravity(delta_sec)
	_apply_lock_delay(delta_sec - airborne_sec)


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

	var from_rotation: int = _piece.rotation
	var result: RotationResult = _rotation.rotate(
		_board, _piece.type, from_rotation, _piece.position, direction
	)
	if not result.success:
		return false

	_piece.rotation = result.rotation
	_piece.position = result.position
	_lock_delay.notify_action(LockDelay.Action.ROTATE)

	# T-Spin 判定は「直前の操作が回転か」と「どの Kick で収まったか」を根拠にする（§33）。
	_last_action_was_rotation = true
	_last_kick_index = result.kick_index
	_last_kick_table_size = (
		_rotation.get_kick_table(_piece.type).get_offsets(from_rotation, result.rotation).size()
	)
	return true


## Hard Drop する。落ちたマス数を返す。
func hard_drop() -> int:
	if not _can_control():
		return 0

	var distance: int = DropSystem.hard_drop(_board, _piece)
	if distance > 0:
		# 回転してすぐ Hard Drop した場合、1 マスも落ちなければ直前の操作は回転のまま。
		_clear_rotation_flag()
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


## Hold 枠を返す。中身と使用可否はここから見る。
func get_hold_slot() -> HoldSlot:
	return _hold


## Ghost Piece の着地位置を返す。
func get_ghost_position() -> Vector2i:
	if not _piece.is_active():
		return Vector2i.ZERO
	return GhostPiece.get_landing_position(_board, _piece.type, _piece.rotation, _piece.position)


## Top Out してゲームが終わっているかを返す。
func is_over() -> bool:
	return _is_over


## Incoming Garbage を受け取る。送り元の決定は Battle Layer の責務（Phase 4）。
func receive_garbage(event: GarbageEvent) -> void:
	_garbage_queue.enqueue(event)


## Incoming Garbage を行数だけ受け取る簡易版。テストと単体プレイで使う。
func receive_garbage_lines(line_count: int, source_player_id: int = -1) -> void:
	_next_attack_id += 1
	receive_garbage(
		GarbageEvent.create(
			source_player_id,
			-1,
			line_count,
			_game_time_sec,
			_balance.garbage_delay_sec,
			LineClear.Type.NONE,
			_next_attack_id
		)
	)


## Incoming Garbage の Queue を返す。
func get_garbage_queue() -> GarbageQueue:
	return _garbage_queue


## ゲーム内の経過時間（秒）を返す。
func get_game_time_sec() -> float:
	return _game_time_sec


## Combo / Back-to-Back / 直前の T-Spin をまとめた状態を返す。
##
## Attack 計算（#30）はこれをそのまま入力にする。
func get_scoring() -> ScoringState:
	return _scoring


## T-Spin 判定 Module を差し替える。方式を変えたいときに使う。
func set_t_spin_detector(detector: TSpinDetector) -> void:
	if detector != null:
		_t_spin_detector = detector


# --- 内部 ------------------------------------------------------------------


func _clear_rotation_flag() -> void:
	_last_action_was_rotation = false
	_last_kick_index = -1
	_last_kick_table_size = 0


func _detect_t_spin() -> TSpinDetector.Result:
	# Piece を置く前の盤面で判定する。
	var context: TSpinContext = TSpinContext.create(
		_board,
		_piece.type,
		_piece.rotation,
		_piece.position,
		_last_action_was_rotation,
		_last_kick_index,
		_last_kick_table_size
	)
	return _t_spin_detector.detect(context)


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
		_clear_rotation_flag()


## 重力を適用し、この delta のうち「着地するまでに使った時間（秒）」を返す。
##
## 接地したまま始まった場合は 0.0。最後まで空中にいた場合は delta 全部。
func _apply_gravity(delta_sec: float) -> float:
	var distance_to_ground: int = _get_distance_to_ground()
	var speed: float = _drop.get_current_speed()
	var carried_cells: float = _drop.get_accumulated_cells()

	var cells: int = _drop.advance(delta_sec)
	var moved: int = 0
	for _i in range(cells):
		var candidate: Vector2i = _piece.position + Vector2i.DOWN
		if not Collision.can_place(_board, _piece.type, _piece.rotation, candidate):
			break
		_piece.position = candidate
		_clear_rotation_flag()
		moved += 1

	if distance_to_ground <= 0:
		return 0.0
	if moved < distance_to_ground or speed <= 0.0:
		return delta_sec

	# 累積が distance_to_ground に達した時点が着地の瞬間。
	return clampf((float(distance_to_ground) - carried_cells) / speed, 0.0, delta_sec)


func _get_distance_to_ground() -> int:
	var landing: Vector2i = GhostPiece.get_landing_position(
		_board, _piece.type, _piece.rotation, _piece.position
	)
	return landing.y - _piece.position.y


func _apply_lock_delay(delta_sec: float) -> void:
	var on_ground: bool = _piece.is_on_ground(_board)
	if _lock_delay.update(delta_sec, on_ground, _piece.get_lowest_y()):
		_lock_piece()


func _lock_piece() -> void:
	var locked_type: int = _piece.type
	# 「直前の Lock で送信した Attack」なので、Attack が出ない Lock では 0 に戻す。
	_scoring.set_last_attack(0)
	var t_spin: TSpinDetector.Result = _detect_t_spin()
	if t_spin != TSpinDetector.Result.NONE:
		t_spin_detected.emit(t_spin)

	Collision.place(_board, _piece.type, _piece.rotation, _piece.position)
	_piece.clear()
	piece_locked.emit(locked_type)

	var result: LineClearResult = LineClear.execute(_board)

	_scoring.on_piece_locked(result, t_spin)

	if result.has_cleared():
		lines_cleared.emit(result)

		var is_perfect_clear: bool = PerfectClear.is_achieved(_board, result.line_count)
		if is_perfect_clear:
			perfect_clear_achieved.emit()

		var context: AttackContext = AttackContext.create(result, _scoring, is_perfect_clear)
		var attack: int = _attack_calculator.calculate(context)

		# 要件定義 §42 の順序: 生成 Attack → Incoming を相殺 → 余剰を Target へ送信。
		var surplus: int = _garbage_queue.cancel_with_attack(attack)
		_scoring.set_last_attack(surplus)
		if surplus > 0:
			attack_generated.emit(surplus, context)

	# 相殺で残った Incoming のうち、Delay が経過したものを盤面へ入れる。
	var applied: int = _garbage_queue.apply_ready(_board, _game_time_sec, _hole_generator)
	if applied > 0:
		garbage_applied.emit(applied)

	_hold.on_piece_locked()
	_spawn_next()


func _spawn_next() -> void:
	_spawn(_next_queue.pop())


func _spawn(type: int) -> void:
	_piece.spawn(type)
	_clear_rotation_flag()
	_drop.start_new_piece()
	_lock_delay.start_new_piece()

	# Spawn 位置に置けなければ Top Out（要件定義 §32 の完了条件）。
	if not _piece.can_place(_board):
		_piece.clear()
		_is_over = true
		topped_out.emit()
		return

	piece_spawned.emit(type)
