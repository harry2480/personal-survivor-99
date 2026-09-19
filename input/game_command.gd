class_name GameCommand
extends RefCounted

## ゲーム内の操作を表す抽象コマンド（要件定義 §11）。
##
## ゲームロジックは物理ボタンやキーコードを扱わない。Input Action を経由して
## このコマンドへ変換し、以降はコマンドだけで話を進める。Keyboard と Controller
## （Phase 3）で同じコマンドが使える。
##
## Input Action 名の既定キー割り当ては要件定義 §15。Remapping は Phase 9。

## 操作の種類。
enum Command {
	MOVE_LEFT,
	MOVE_RIGHT,
	SOFT_DROP,
	HARD_DROP,
	ROTATE_LEFT,
	ROTATE_RIGHT,
	HOLD,
	TARGET_RANDOM,
	TARGET_KO,
	TARGET_BADGE,
	TARGET_COUNTER,
	PAUSE,
}

## コマンドと Input Action 名の対応。
const ACTION_NAMES: Dictionary = {
	Command.MOVE_LEFT: "move_left",
	Command.MOVE_RIGHT: "move_right",
	Command.SOFT_DROP: "soft_drop",
	Command.HARD_DROP: "hard_drop",
	Command.ROTATE_LEFT: "rotate_left",
	Command.ROTATE_RIGHT: "rotate_right",
	Command.HOLD: "hold",
	Command.TARGET_RANDOM: "target_random",
	Command.TARGET_KO: "target_ko",
	Command.TARGET_BADGE: "target_badge",
	Command.TARGET_COUNTER: "target_counter",
	Command.PAUSE: "pause",
}


## コマンドに対応する Input Action 名を返す。
static func get_action_name(command: Command) -> String:
	return ACTION_NAMES.get(command, "")


## Input Action 名に対応するコマンドを返す。見つからなければ -1。
static func from_action_name(action_name: String) -> int:
	for command in ACTION_NAMES:
		if ACTION_NAMES[command] == action_name:
			return command
	return -1


## 全てのコマンドを返す。
static func get_all_commands() -> Array[int]:
	var commands: Array[int] = []
	for command in ACTION_NAMES:
		commands.append(command)
	return commands


## Battle で Target を切り替えるコマンドかを返す（Phase 4 で使う）。
static func is_target_command(command: Command) -> bool:
	return (
		command
		in [
			Command.TARGET_RANDOM,
			Command.TARGET_KO,
			Command.TARGET_BADGE,
			Command.TARGET_COUNTER,
		]
	)
