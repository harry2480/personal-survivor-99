extends Node

## Game State と Scene 遷移を一元管理する Autoload。
## 要件定義 §107 Scene構成 / §109 Game State に対応する。
##
## Game Core（core/）はこの Node を参照しない。Scene 遷移は Presentation の責務とする。
##
## 状態の移り方は [constant ALLOWED_TRANSITIONS] で決まっている。通らない遷移は
## 黙って捨てるのではなく、ログへ出して現状を保つ（要件定義 §109 / #51）。
##
## [codeblock]
## BOOT → MAIN_MENU → LOADING → PLAYING ⇄ PAUSED
##                                 ↓         ↓
##                              FINISHED → RESULT → MAIN_MENU
## [/codeblock]

## 状態が変わった直後に発火する。実際の Scene 切り替えはこの後フレーム終端で行われる。
signal state_changed(previous: GameState.State, current: GameState.State)

## 状態に対応する Scene。ここに無い状態（LOADING / PAUSED / FINISHED）は
## Scene を切り替えず、現在の Scene の上で扱う。
const SCENE_PATHS: Dictionary = {
	GameState.State.MAIN_MENU: "res://scenes/main_menu/main_menu.tscn",
	GameState.State.PLAYING: "res://scenes/battle/battle.tscn",
	GameState.State.RESULT: "res://scenes/result/result.tscn",
}

## 許される遷移（要件定義 §109）。
##
## Pause は Scene を切り替えず、PLAYING の上に重ねる。Restart は
## LOADING を挟んで PLAYING へ戻る。
const ALLOWED_TRANSITIONS: Dictionary = {
	GameState.State.BOOT: [GameState.State.MAIN_MENU],
	GameState.State.MAIN_MENU: [GameState.State.LOADING, GameState.State.PLAYING],
	GameState.State.LOADING: [GameState.State.PLAYING, GameState.State.MAIN_MENU],
	GameState.State.PLAYING:
	[GameState.State.PAUSED, GameState.State.FINISHED, GameState.State.MAIN_MENU],
	GameState.State.PAUSED:
	[GameState.State.PLAYING, GameState.State.LOADING, GameState.State.MAIN_MENU],
	GameState.State.FINISHED: [GameState.State.RESULT, GameState.State.MAIN_MENU],
	GameState.State.RESULT: [GameState.State.MAIN_MENU, GameState.State.LOADING],
}

var current_state: GameState.State = GameState.State.BOOT

var _current_scene_path: String = ""
var _battle_setup: BattleSetup = BattleSetup.create_default()
var _user_settings: UserSettings = null
var _last_outcome: BattleOutcome = BattleOutcome.create_empty()


## ユーザー設定を返す（要件定義 §97 / §98）。
##
## まだ読んでいなければ、ここで `user://` から読む。読めなければ既定値。
func get_user_settings() -> UserSettings:
	if _user_settings == null:
		_user_settings = SettingsStore.new().load_settings()
	return _user_settings


## ユーザー設定を差し替える（Settings 画面が保存したあとに呼ぶ）。
func set_user_settings(settings: UserSettings) -> void:
	if settings != null:
		_user_settings = settings


## その遷移が許されているかを返す（要件定義 §109）。
func can_change_state(next_state: GameState.State) -> bool:
	if next_state == current_state:
		return true
	return next_state in ALLOWED_TRANSITIONS.get(current_state, [])


## 次の Battle の設定を返す（要件定義 §95）。
func get_battle_setup() -> BattleSetup:
	return _battle_setup


## 次の Battle の設定を差し替える。
func set_battle_setup(setup: BattleSetup) -> void:
	if setup != null:
		_battle_setup = setup


## Battle を始める（Main Menu からの入口。要件定義 §95）。
##
## LOADING を挟んでから PLAYING へ移る。Seed はここで決まる。
func start_battle(setup: BattleSetup = null) -> void:
	set_battle_setup(setup)
	_battle_setup.resolve_seed()
	change_state(GameState.State.LOADING)
	change_state(GameState.State.PLAYING)


## 同じ設定で Battle をやり直す（要件定義 §96 の Restart）。
##
## Seed を引き直すので、同じ盤面の繰り返しにはならない。
func restart_battle() -> void:
	_battle_setup.clear_seed()
	_battle_setup.resolve_seed()
	change_state(GameState.State.LOADING)
	_current_scene_path = ""
	change_state(GameState.State.PLAYING)


## Battle を中断して Main Menu へ戻る（要件定義 §96 の Quit to Menu）。
func quit_to_menu() -> void:
	_battle_setup.clear_seed()
	change_state(GameState.State.MAIN_MENU)


## Pause / Resume を切り替える（要件定義 §96）。
##
## Scene は切り替えない。Battle 画面がこの状態を見て止める。
func set_battle_paused(paused: bool) -> void:
	if paused and current_state == GameState.State.PLAYING:
		change_state(GameState.State.PAUSED)
	elif not paused and current_state == GameState.State.PAUSED:
		change_state(GameState.State.PLAYING)


## 直前の Battle の結果を返す（Result 画面が読む。要件定義 §99）。
func get_last_outcome() -> BattleOutcome:
	return _last_outcome


## Battle の決着を伝える（要件定義 §109）。
##
## [param outcome] を渡すと Result 画面がそれを表示する。
func finish_battle(outcome: BattleOutcome = null) -> void:
	if outcome != null:
		_last_outcome = outcome
	change_state(GameState.State.FINISHED)
	change_state(GameState.State.RESULT)


## 状態を遷移させ、対応する Scene があれば切り替える。
##
## 許されていない遷移は行わない（要件定義 §109）。
func change_state(next_state: GameState.State) -> void:
	if next_state == current_state:
		return

	if not can_change_state(next_state):
		push_warning(
			(
				"許されていない状態遷移です: %s -> %s"
				% [
					GameState.State.keys()[current_state],
					GameState.State.keys()[next_state],
				]
			)
		)
		return

	var previous: GameState.State = current_state
	current_state = next_state
	state_changed.emit(previous, current_state)

	if not SCENE_PATHS.has(next_state):
		return

	var path: String = SCENE_PATHS[next_state]

	# 同じ Scene への遷移では読み込み直さない。
	# これが無いと PLAYING → PAUSED → PLAYING で Battle が最初からやり直しになる。
	if path == _current_scene_path:
		return

	var previous_scene_path: String = _current_scene_path
	_current_scene_path = path

	# 呼び出し元の _ready() 中に切り替えると SceneTree が子の追加中で落ちるため、
	# 実際の切り替えは常にフレーム終端まで遅延させる。
	_change_scene.call_deferred(path, next_state, previous, previous_scene_path)


## 遅延実行される実際の Scene 切り替え。失敗した場合は状態を呼び出し前へ戻す。
func _change_scene(
	path: String,
	attempted_state: GameState.State,
	previous_state: GameState.State,
	previous_scene_path: String,
) -> void:
	var error: Error = get_tree().change_scene_to_file(path)
	if error == OK:
		return

	# 状態を戻さないと current_state だけが先に進み、同じ状態への再試行が
	# change_state() 冒頭の同値判定で無視されて復帰できなくなる。
	push_error("Scene の切り替えに失敗しました: %s (error=%d)" % [path, error])

	# 遅延中に別の遷移が走っていた場合は、そちらを優先して巻き戻さない。
	if current_state != attempted_state:
		return

	current_state = previous_state
	_current_scene_path = previous_scene_path
	state_changed.emit(attempted_state, previous_state)
