class_name BattleLogger
extends RefCounted

## Development Build のログ（要件定義 §112）。
##
## 出すのは §112 の出来事（Battle Start / End / KO / Target Change /
## Garbage Send / Apply / Multiplier Change / Fatal Error）。
## CPU Mode Change は [CpuManager] が自分で出す。
##
## **Release Build では出さない**（#54 の完了条件）。`OS.is_debug_build()` を
## 見て、既定では Development Build のときだけ記録する。

## 記録した行の上限。古い行から捨てる（長い試合でも増え続けないように）。
const MAX_LINES: int = 500

var _enabled: bool = OS.is_debug_build()
var _lines: PackedStringArray = PackedStringArray()
var _connections: Array = []


## 記録するかどうかを切り替える（テストと Debug 用）。
func set_enabled(enabled: bool) -> void:
	_enabled = enabled


## 記録する状態かを返す。
func is_enabled() -> bool:
	return _enabled


## 記録した行を返す。
func get_lines() -> PackedStringArray:
	return _lines


## 記録を捨てる。
func clear() -> void:
	_lines.clear()


## 1 行記録する。Development Build では標準出力にも出す。
func log_event(event: String, detail: String = "") -> void:
	if not _enabled:
		return

	var line: String = event if detail.is_empty() else "%s %s" % [event, detail]
	_lines.append(line)
	while _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	print(line)


## Battle の出来事を購読する（要件定義 §112）。
func bind(
	manager: BattleManager, ko: KoSystem, targets: TargetManager, router: GarbageRouter
) -> void:
	unbind()

	if manager != null:
		log_event(
			"battle_start",
			"players=%d seed=%d" % [manager.get_player_count(), manager.get_battle_seed()]
		)
		var on_finished: Callable = func(winner: int) -> void:
			log_event("battle_end", "winner=%d" % winner)
		_connect(manager, "battle_finished", on_finished)

	if ko != null:
		var on_ko: Callable = func(victim: int, attacker: int) -> void:
			log_event("ko", "victim=%d attacker=%d" % [victim, attacker])
		_connect(ko, "player_ko", on_ko)

		var on_multiplier: Callable = func(player_id: int, stage: int, value: float) -> void:
			log_event(
				"multiplier_change", "player=%d stage=%d value=%.2f" % [player_id, stage, value]
			)
		_connect(ko.get_multiplier_system(), "multiplier_changed", on_multiplier)

	if targets != null:
		var on_target: Callable = func(player_id: int, previous: int, current: int) -> void:
			log_event("target_change", "player=%d %d -> %d" % [player_id, previous, current])
		_connect(targets, "target_changed", on_target)

	if router != null:
		var on_send: Callable = func(source: int, target: int, lines: int) -> void:
			log_event("garbage_send", "%d -> %d lines=%d" % [source, target, lines])
		_connect(router, "garbage_routed", on_send)

		var on_apply: Callable = func(victim: int, source: int, lines: int) -> void:
			log_event("garbage_apply", "victim=%d source=%d lines=%d" % [victim, source, lines])
		_connect(router, "garbage_received", on_apply)


## 購読を解除する。
func unbind() -> void:
	for entry in _connections:
		var source: Object = entry[0]
		if is_instance_valid(source) and source.is_connected(entry[1], entry[2]):
			source.disconnect(entry[1], entry[2])
	_connections.clear()


## 復帰できない不具合を記録する（要件定義 §112 の Fatal Error）。
##
## これは Release でも出す。落ちた理由が分からないほうが困るため。
func log_fatal(message: String) -> void:
	push_error("fatal %s" % message)
	_lines.append("fatal %s" % message)


func _connect(source: Object, signal_name: String, handler: Callable) -> void:
	source.connect(signal_name, handler)
	_connections.append([source, signal_name, handler])
