class_name AudioManager
extends Node

## SE の再生（要件定義 §100）。
##
## Game Core / Battle Layer の signal を受けて、対応する SE を鳴らす。
## Audio 側から Game Core を触ることはない（要件定義 §19）。
##
## **99 人戦では SE が大量に発生する**（#53 の完了条件）。そのままでは音が重なって
## 割れるため、2 つの制限を掛ける。
## [br]・同時に鳴らす数の上限（[constant MAX_VOICES]）
## [br]・同じ Event を続けて鳴らさない間隔（[constant THROTTLE_SEC]）

## SE を鳴らした。
signal sound_played(event: Event)

## SE の種類（要件定義 §100）。
enum Event {
	MOVE,
	ROTATE,
	HOLD,
	SOFT_DROP,
	HARD_DROP,
	LOCK,
	LINE_CLEAR,
	HIGH_VALUE_CLEAR,
	COMBO,
	GARBAGE_SEND,
	GARBAGE_RECEIVE,
	TARGET_CHANGE,
	DANGER,
	KO,
	VICTORY,
	DEFEAT,
}

## 同時に鳴らせる数。これを超えたぶんは捨てる。
const MAX_VOICES: int = 16

## 同じ Event を続けて鳴らさない間隔（秒）。
const THROTTLE_SEC: float = 0.03

## SE を流す Bus の名前。
const BUS_NAME: String = "SE"

## 高得点の Clear とみなす行数（要件定義 §100 の High-value Clear）。
const HIGH_VALUE_LINES: int = 4

var _bank := SoundBank.new()
var _players: Array[AudioStreamPlayer] = []
var _last_played_sec: Dictionary = {}
var _played_counts: Dictionary = {}
var _dropped_count: int = 0
var _elapsed_sec: float = 0.0
var _enabled: bool = true
var _connections: Array = []


func _ready() -> void:
	AudioBusSetup.ensure_buses()
	for _index in range(MAX_VOICES):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_NAME
		add_child(player)
		_players.append(player)


func _process(delta: float) -> void:
	_elapsed_sec += delta


func _exit_tree() -> void:
	unbind_all()


## Event の名前を返す。
static func get_event_name(event: Event) -> String:
	return Event.keys()[event]


## SE を鳴らす。鳴らせたら [code]true[/code]。
##
## 間隔が短すぎる場合と、同時数の上限を超えた場合は鳴らさない。
func play(event: Event) -> bool:
	if not _enabled:
		return false

	var last: float = _last_played_sec.get(event, -1000.0)
	if _elapsed_sec - last < THROTTLE_SEC:
		_dropped_count += 1
		return false

	var player: AudioStreamPlayer = _find_free_player()
	if player == null:
		_dropped_count += 1
		return false

	var stream: AudioStream = _bank.get_stream(event)
	if stream == null:
		return false

	player.stream = stream
	player.play()
	_last_played_sec[event] = _elapsed_sec
	_played_counts[event] = _played_counts.get(event, 0) + 1
	sound_played.emit(event)
	return true


## SE を鳴らすかどうかを切り替える（Pause 中に止めるため。要件定義 §96）。
func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if enabled:
		return
	for player in _players:
		player.stop()


## SE を鳴らす状態かを返す。
func is_enabled() -> bool:
	return _enabled


## その Event を鳴らした回数を返す。
func get_played_count(event: Event) -> int:
	return _played_counts.get(event, 0)


## 上限や間隔で捨てた数を返す（負荷の確認に使う）。
func get_dropped_count() -> int:
	return _dropped_count


## いま鳴っている数を返す。
func get_active_count() -> int:
	var count: int = 0
	for player in _players:
		if player.playing:
			count += 1
	return count


## 用意されている音源の数を返す。
func get_stream_count() -> int:
	return _bank.get_stream_count()


## Game Core の出来事を SE へ繋ぐ（要件定義 §100）。
func bind_session(session: PuzzleSession) -> void:
	if session == null:
		return

	var on_locked: Callable = func(_type: int) -> void: play(Event.LOCK)
	var on_held: Callable = func(_type: int) -> void: play(Event.HOLD)
	var on_cleared: Callable = func(result: LineClearResult) -> void: _on_lines_cleared(result)
	var on_garbage: Callable = func(_lines: int) -> void: play(Event.GARBAGE_RECEIVE)
	var on_attack: Callable = func(_amount: int, _context: AttackContext) -> void:
		play(Event.GARBAGE_SEND)

	_connect(session, "piece_locked", on_locked)
	_connect(session, "piece_held", on_held)
	_connect(session, "lines_cleared", on_cleared)
	_connect(session, "garbage_applied", on_garbage)
	_connect(session, "attack_generated", on_attack)


## Battle の出来事を SE へ繋ぐ（要件定義 §100）。
func bind_battle(ko: KoSystem, targets: TargetManager, viewer_id: int) -> void:
	if ko != null:
		var on_ko: Callable = func(victim: int, attacker: int) -> void:
			_on_player_ko(victim, attacker, viewer_id)
		_connect(ko, "player_ko", on_ko)

	if targets != null:
		var on_target: Callable = func(player_id: int, _previous: int, _current: int) -> void:
			if player_id == viewer_id:
				play(Event.TARGET_CHANGE)
		_connect(targets, "target_changed", on_target)


## 操作に対応する SE を鳴らす（Input 側から呼ぶ）。
func play_for_command(command: GameCommand.Command) -> void:
	match command:
		GameCommand.Command.MOVE_LEFT, GameCommand.Command.MOVE_RIGHT:
			play(Event.MOVE)
		GameCommand.Command.ROTATE_LEFT, GameCommand.Command.ROTATE_RIGHT:
			play(Event.ROTATE)
		GameCommand.Command.SOFT_DROP:
			play(Event.SOFT_DROP)
		GameCommand.Command.HARD_DROP:
			play(Event.HARD_DROP)
		_:
			pass


## 盤面の危険度が上がったことを伝える（要件定義 §92 / §100）。
func notify_danger(level: DangerLevel.Level) -> void:
	if level >= DangerLevel.Level.DANGER:
		play(Event.DANGER)


## 購読を解除する。
##
## 相手（[PuzzleSession] など）が先に捨てられていることもあるので、
## 生きているものだけ解除する。
func unbind_all() -> void:
	for entry in _connections:
		var source: Object = entry[0]
		if is_instance_valid(source) and source.is_connected(entry[1], entry[2]):
			source.disconnect(entry[1], entry[2])
	_connections.clear()


# 購読して、解除に必要な情報を残す。
func _connect(source: Object, signal_name: String, handler: Callable) -> void:
	source.connect(signal_name, handler)
	_connections.append([source, signal_name, handler])


func _find_free_player() -> AudioStreamPlayer:
	for player in _players:
		if not player.playing:
			return player
	return null


func _on_lines_cleared(result: LineClearResult) -> void:
	if result.line_count >= HIGH_VALUE_LINES or result.type != LineClear.Type.NONE:
		play(Event.HIGH_VALUE_CLEAR)
	else:
		play(Event.LINE_CLEAR)


func _on_player_ko(victim: int, attacker: int, viewer_id: int) -> void:
	if victim == viewer_id:
		play(Event.DEFEAT)
	elif attacker == viewer_id:
		play(Event.KO)
	else:
		play(Event.KO)
