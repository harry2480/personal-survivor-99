extends Node2D

## Battle 画面（要件定義 §87 / §107）。
##
## 組み立てだけを行う。ここが Battle Layer と View の橋渡しをする唯一の窓口で、
## 各 View は渡された状態を読んで自分の描画を更新する（フロントエンド
## アーキテクチャの Battle Scene 構成）。
##
## [codeblock]
## Battle
## ├── OpponentGrid       … 対戦相手の一覧（#49）
## ├── PlayerBoardPanel   … 自分の盤面 + Hold / NEXT（#48）
## ├── BattleHud          … 状況表示（#50）
## ├── AudioManager       … SE（#53）
## ├── MusicManager       … BGM（#53）
## ├── DebugOverlay       … 開発時の状態表示（#54。Release では既定 OFF）
## └── InputManager       … Input Action → Game Command（§11）
## [/codeblock]
##
## Battle の進行そのものは [CpuBattleRunner] が持つ。Presentation では
## Game Core の内部状態を直接書き換えない（要件定義 §19）。
##
## 何人で・どの難易度で始めるかは [SceneRouter] が持つ [BattleSetup]（#51）。
## Pause と Restart / Quit to Menu も [SceneRouter] を通す（要件定義 §96 / §109）。

## 自分の Player ID。
const VIEWER_ID: int = 0

## 配色の置き場所。
const PALETTE_PATH: String = "res://assets/themes/board_palette.tres"

## 画面の余白（ピクセル）。
const MARGIN := Vector2(24.0, 24.0)

var _runner: CpuBattleRunner
var _input: InputManager
var _board_panel: PlayerBoardPanel
var _opponent_grid: OpponentGrid
var _hud: BattleHud
var _pause_menu: PauseMenu
var _audio: AudioManager
var _music: MusicManager
var _debug_overlay: DebugOverlay
var _logger := BattleLogger.new()
var _quad_count: int = 0
var _t_spin_count: int = 0
var _perfect_clear_count: int = 0
var _highest_cpu_strength_defeated: float = 0.0
var _setup: BattleSetup
var _paused: bool = false
var _finished: bool = false


func _ready() -> void:
	_setup = SceneRouter.get_battle_setup()
	_runner = _create_runner()
	_build_views()
	_build_audio()
	_build_pause_menu()
	_build_debug_overlay()
	_build_input()
	_watch_progress()


func _process(delta: float) -> void:
	if _paused or _runner == null:
		return

	_runner.step(delta)
	if _runner.get_manager().is_finished():
		_on_battle_finished()


func _exit_tree() -> void:
	_logger.unbind()
	if _runner != null:
		_runner.dispose()
		_runner = null


## Battle の進行を返す（Debug Overlay と Result 画面のため）。
func get_runner() -> CpuBattleRunner:
	return _runner


## 自分の Player を返す。
func get_viewer() -> BattlePlayerState:
	return _runner.get_manager().get_player(VIEWER_ID) if _runner != null else null


## 一時停止を切り替える（要件定義 §96）。
##
## Pause 中は Player / CPU の Simulation と時間が止まる。Audio の扱いは #53。
func set_paused(paused: bool) -> void:
	_paused = paused
	if _input != null:
		_input.release_all()
	if _pause_menu != null:
		_pause_menu.visible = paused
	# Pause 中は SE を止め、BGM は減衰させる（要件定義 §96）。
	if _audio != null:
		_audio.set_enabled(not paused)
	if _music != null:
		_music.set_ducked(paused)
	SceneRouter.set_battle_paused(paused)


## 一時停止中かを返す。
func is_paused() -> bool:
	return _paused


## SE の管理を返す。
func get_audio_manager() -> AudioManager:
	return _audio


## BGM の管理を返す。
func get_music_manager() -> MusicManager:
	return _music


## Debug Overlay を返す（要件定義 §113）。
func get_debug_overlay() -> DebugOverlay:
	return _debug_overlay


## 記録している Battle のログを返す（要件定義 §112）。
func get_logger() -> BattleLogger:
	return _logger


## いまの内容で結果をまとめる（要件定義 §99）。
func build_outcome() -> BattleOutcome:
	var outcome := BattleOutcome.create_empty()
	var viewer: BattlePlayerState = get_viewer()
	var manager: BattleManager = _runner.get_manager()

	outcome.player_count = manager.get_player_count()
	outcome.rank = viewer.rank if viewer != null and viewer.rank > 0 else 1
	outcome.ko_count = viewer.ko_count if viewer != null else 0
	outcome.cleared_lines = (
		viewer.session.get_scoring().get_cleared_lines_total()
		if viewer != null and viewer.session != null
		else 0
	)
	outcome.quad_count = _quad_count
	outcome.t_spin_count = _t_spin_count
	outcome.perfect_clear_count = _perfect_clear_count
	outcome.duration_sec = _runner.get_elapsed_sec()
	outcome.highest_cpu_strength_defeated = _highest_cpu_strength_defeated
	outcome.battle_seed = manager.get_battle_seed()
	return outcome


## Pause メニューを返す。
func get_pause_menu() -> PauseMenu:
	return _pause_menu


## この Battle の設定を返す。
func get_setup() -> BattleSetup:
	return _setup


func _create_runner() -> CpuBattleRunner:
	var mapping: Resource = load("res://config/cpu_strength_mapping.tres")
	var runner := CpuBattleRunner.new(
		_setup.get_cpu_count(),
		_setup.build_distribution(),
		mapping if mapping is CpuStrengthMapping else null,
		_setup.resolve_seed(),
		1,
		_load_human_rules()
	)

	# CPU の更新は分散する（要件定義 §104 / #47）。
	var policy: Resource = load("res://config/cpu_scheduling.tres")
	runner.enable_scheduling(policy if policy is CpuSchedulePolicy else null)
	return runner


# 自分の盤面のルールを作る。config の値に、ユーザー設定（#52）を重ねる。
func _load_human_rules() -> GameRules:
	var loaded: Resource = load("res://config/game_rules.tres")
	var rules: GameRules = loaded if loaded is GameRules else GameRules.create_default()
	var settings: UserSettings = SceneRouter.get_user_settings()
	SettingsApplier.apply_gameplay(settings, rules)
	# Dead Zone は Input の設定（要件定義 §97）。Game Core の GameRules には持たせない。
	InputManager.apply_dead_zone(
		settings.stick_dead_zone if settings != null else InputManager.DEFAULT_DEAD_ZONE
	)
	return rules


func _build_views() -> void:
	var palette: Resource = load(PALETTE_PATH)
	var manager: BattleManager = _runner.get_manager()
	var viewer: BattlePlayerState = manager.get_player(VIEWER_ID)

	_opponent_grid = OpponentGrid.new()
	_opponent_grid.name = "OpponentGrid"
	_opponent_grid.position = MARGIN
	add_child(_opponent_grid)
	_opponent_grid.bind(manager, VIEWER_ID, _runner.get_cpu_manager())
	# 選択は Battle Layer へ渡すだけ（要件定義 §52 / §53）。
	_opponent_grid.opponent_selected.connect(_on_opponent_selected)

	_board_panel = PlayerBoardPanel.new()
	_board_panel.name = "PlayerBoardPanel"
	_board_panel.position = MARGIN + Vector2(0.0, 360.0)
	add_child(_board_panel)
	_board_panel.bind(viewer.session, viewer)

	_hud = BattleHud.new()
	_hud.name = "BattleHud"
	_hud.position = MARGIN + Vector2(560.0, 360.0)
	add_child(_hud)
	_hud.bind(manager, VIEWER_ID, _runner.get_ko_system(), _runner.get_target_manager())

	if palette is BoardPalette:
		_board_panel.set_palette(palette)
		_opponent_grid.set_palette(palette)


func _build_audio() -> void:
	var manager: BattleManager = _runner.get_manager()
	var viewer: BattlePlayerState = manager.get_player(VIEWER_ID)

	_audio = AudioManager.new()
	_audio.name = "AudioManager"
	add_child(_audio)
	_audio.bind_session(viewer.session)
	_audio.bind_battle(_runner.get_ko_system(), _runner.get_target_manager(), VIEWER_ID)

	_music = MusicManager.new()
	_music.name = "MusicManager"
	add_child(_music)
	_music.follow_phase(manager.get_phase())

	# 残存人数の段階が変わったら BGM も変える（要件定義 §93）。
	manager.phase_changed.connect(
		func(_previous: int, current: int) -> void:
			_music.follow_phase(current as BattlePhase.Phase)
	)


func _build_debug_overlay() -> void:
	_debug_overlay = DebugOverlay.new()
	_debug_overlay.name = "DebugOverlay"
	_debug_overlay.position = MARGIN + Vector2(900.0, 360.0)
	add_child(_debug_overlay)
	_debug_overlay.bind(_runner)


# 結果に必要な数（Quad / T-Spin / Perfect Clear / 倒した CPU の強さ）を数える。
func _watch_progress() -> void:
	var manager: BattleManager = _runner.get_manager()
	var viewer: BattlePlayerState = manager.get_player(VIEWER_ID)
	if viewer != null and viewer.session != null:
		viewer.session.lines_cleared.connect(_on_lines_cleared)
		viewer.session.t_spin_detected.connect(func(_result: int) -> void: _t_spin_count += 1)
		viewer.session.perfect_clear_achieved.connect(func() -> void: _perfect_clear_count += 1)

	_runner.get_ko_system().player_ko.connect(_on_player_ko)
	_logger.bind(manager, _runner.get_ko_system(), _runner.get_target_manager(), null)


func _on_lines_cleared(result: LineClearResult) -> void:
	if result.line_count >= 4:
		_quad_count += 1


func _on_player_ko(victim: int, attacker: int) -> void:
	# 自分が倒した相手の Strength を覚えておく（要件定義 §99）。
	if attacker != VIEWER_ID:
		return
	_highest_cpu_strength_defeated = maxf(
		_highest_cpu_strength_defeated, _runner.get_strength(victim)
	)


func _build_pause_menu() -> void:
	_pause_menu = PauseMenu.new()
	_pause_menu.name = "PauseMenu"
	_pause_menu.position = MARGIN + Vector2(240.0, 200.0)
	_pause_menu.visible = false
	add_child(_pause_menu)
	_pause_menu.action_selected.connect(_on_pause_action)


func _on_pause_action(action: PauseMenu.Action) -> void:
	match action:
		PauseMenu.Action.RESUME:
			set_paused(false)
		PauseMenu.Action.RESTART:
			SceneRouter.restart_battle()
		PauseMenu.Action.SETTINGS:
			# Settings の中身は #52。ここでは開く口だけ用意しておく。
			get_tree().change_scene_to_file("res://scenes/settings/settings.tscn")
		PauseMenu.Action.QUIT_TO_MENU:
			SceneRouter.quit_to_menu()


func _on_battle_finished() -> void:
	if _finished:
		return
	_finished = true
	set_process(false)

	var viewer: BattlePlayerState = get_viewer()
	var won: bool = viewer != null and viewer.alive
	if _music != null:
		_music.play_result(won)
	if _audio != null:
		_audio.play(AudioManager.Event.VICTORY if won else AudioManager.Event.DEFEAT)

	SceneRouter.finish_battle(build_outcome())


func _build_input() -> void:
	_input = InputManager.new()
	_input.name = "InputManager"
	add_child(_input)
	_input.command_pressed.connect(_on_command_pressed)
	_input.command_released.connect(_on_command_released)


func _on_opponent_selected(player_id: int) -> void:
	# Target にするかどうかは Battle Layer が決める（要件定義 §53）。
	_runner.get_target_manager().set_manual_target(VIEWER_ID, player_id)


func _on_command_pressed(command: GameCommand.Command) -> void:
	var session: PuzzleSession = _viewer_session()
	if session == null:
		return

	match command:
		GameCommand.Command.MOVE_LEFT:
			session.press_move(AutoShift.Direction.LEFT)
		GameCommand.Command.MOVE_RIGHT:
			session.press_move(AutoShift.Direction.RIGHT)
		GameCommand.Command.SOFT_DROP:
			session.set_soft_dropping(true)
		GameCommand.Command.HARD_DROP:
			session.hard_drop()
		GameCommand.Command.ROTATE_LEFT:
			session.rotate(RotationSystem.Direction.COUNTER_CLOCKWISE)
		GameCommand.Command.ROTATE_RIGHT:
			session.rotate(RotationSystem.Direction.CLOCKWISE)
		GameCommand.Command.HOLD:
			session.hold()
		GameCommand.Command.PAUSE:
			set_paused(not _paused)

	if _audio != null and command != GameCommand.Command.PAUSE:
		_audio.play_for_command(command)


func _on_command_released(command: GameCommand.Command) -> void:
	var session: PuzzleSession = _viewer_session()
	if session == null:
		return

	match command:
		GameCommand.Command.MOVE_LEFT:
			session.release_move(AutoShift.Direction.LEFT)
		GameCommand.Command.MOVE_RIGHT:
			session.release_move(AutoShift.Direction.RIGHT)
		GameCommand.Command.SOFT_DROP:
			session.set_soft_dropping(false)


func _viewer_session() -> PuzzleSession:
	var viewer: BattlePlayerState = get_viewer()
	if viewer == null or not viewer.alive:
		return null
	return viewer.session
