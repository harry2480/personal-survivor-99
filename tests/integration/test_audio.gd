extends GutTest

## SE と BGM の確認（要件定義 §93 / §96 / §100 / §101 / §138）。
##
## §100 の 16 種類が鳴ること、BGM が §101 の状態で切り替わること、
## 99 人戦で SE が溢れても音が重ならないことを見る（#53 の完了条件）。

const SEED: int = 20260922

var audio: AudioManager
var music: MusicManager


func before_each() -> void:
	audio = AudioManager.new()
	add_child_autofree(audio)
	music = MusicManager.new()
	add_child_autofree(music)


func _new_session() -> PuzzleSession:
	var rules := GameRules.create_default()
	rules.gravity_cells_per_second = 0.0
	var session := PuzzleSession.new(rules, PieceRandomizer.new(SEED))
	session.start(SEED)
	return session


## Throttle に掛からないよう、時間を進めてから鳴らす。
func _play_after_interval(event: AudioManager.Event) -> bool:
	audio._process(AudioManager.THROTTLE_SEC * 2.0)
	return audio.play(event)


# --- SE Event（要件定義 §100） ----------------------------------------------


func test_every_required_sound_exists() -> void:
	# 要件定義 §100 の 16 種類。
	assert_eq(AudioManager.Event.size(), 16, "SE Event が 16 種類ある")
	assert_eq(audio.get_stream_count(), 16, "すべてに音源がある")


func test_every_sound_can_be_played() -> void:
	for event in AudioManager.Event.values():
		assert_true(_play_after_interval(event), "%s が鳴る" % AudioManager.get_event_name(event))


func test_sounds_are_generated_not_bundled() -> void:
	# 要件定義 §138: 外部音源を持ち込まない。出典は assets/se/README.md。
	var bank := SoundBank.new()

	for event in AudioManager.Event.values():
		assert_true(bank.get_stream(event) is AudioStreamWAV, "コードで作った音源を使う")


func test_bus_is_separated_for_volume_control() -> void:
	# 音量設定（#52）が効くように、SE と BGM は Bus を分ける。
	assert_true(AudioBusSetup.has_bus(AudioBusSetup.SE_BUS), "SE の Bus がある")
	assert_true(AudioBusSetup.has_bus(AudioBusSetup.BGM_BUS), "BGM の Bus がある")


# --- Game Core / Battle との接続（要件定義 §100） ---------------------------


func test_locking_a_piece_plays_a_sound() -> void:
	var session: PuzzleSession = _new_session()
	audio.bind_session(session)

	session.hard_drop()

	assert_gt(audio.get_played_count(AudioManager.Event.LOCK), 0, "Lock で鳴る")


func test_clearing_lines_plays_a_sound() -> void:
	var session: PuzzleSession = _new_session()
	audio.bind_session(session)
	# 底の行を埋めておく。次の Lock で Line Clear が起きる。
	for x in range(Board.WIDTH):
		session.get_board().set_cell(x, Board.TOTAL_HEIGHT - 1, Piece.Type.I)

	session.hard_drop()

	var cleared: int = (
		audio.get_played_count(AudioManager.Event.LINE_CLEAR)
		+ audio.get_played_count(AudioManager.Event.HIGH_VALUE_CLEAR)
	)
	assert_gt(cleared, 0, "Line Clear で鳴る")


func test_receiving_garbage_plays_a_sound() -> void:
	var session: PuzzleSession = _new_session()
	audio.bind_session(session)

	session.receive_garbage_lines(2)
	session.update(2.0)
	session.hard_drop()

	assert_gt(audio.get_played_count(AudioManager.Event.GARBAGE_RECEIVE), 0, "受けたら鳴る")


func test_commands_play_their_sounds() -> void:
	audio.play_for_command(GameCommand.Command.MOVE_LEFT)
	audio._process(AudioManager.THROTTLE_SEC * 2.0)
	audio.play_for_command(GameCommand.Command.HARD_DROP)

	assert_gt(audio.get_played_count(AudioManager.Event.MOVE), 0, "移動で鳴る")
	assert_gt(audio.get_played_count(AudioManager.Event.HARD_DROP), 0, "Hard Drop で鳴る")


func test_danger_only_sounds_when_it_matters() -> void:
	audio.notify_danger(DangerLevel.Level.SAFE)
	assert_eq(audio.get_played_count(AudioManager.Event.DANGER), 0, "安全なら鳴らさない")

	audio.notify_danger(DangerLevel.Level.CRITICAL)
	assert_gt(audio.get_played_count(AudioManager.Event.DANGER), 0, "危なくなったら鳴る")


# --- 大量発生への備え（#53 の完了条件） -------------------------------------


func test_repeated_events_are_throttled() -> void:
	# 同じ SE を続けて鳴らさない。99 人戦では同じ音が一斉に来るため。
	for _count in range(50):
		audio.play(AudioManager.Event.GARBAGE_SEND)

	assert_eq(audio.get_played_count(AudioManager.Event.GARBAGE_SEND), 1, "間隔を空けて 1 回だけ")
	assert_gt(audio.get_dropped_count(), 0, "捨てた数が分かる")


func test_simultaneous_sounds_are_capped() -> void:
	# 種類を変えて一気に鳴らしても、同時数は上限で止まる。
	for event in AudioManager.Event.values():
		audio.play(event)

	assert_lte(audio.get_active_count(), AudioManager.MAX_VOICES, "同時数が上限を超えない")


func test_disabling_stops_every_sound() -> void:
	_play_after_interval(AudioManager.Event.LINE_CLEAR)

	audio.set_enabled(false)

	assert_eq(audio.get_active_count(), 0, "止めたら鳴っていない")
	assert_false(_play_after_interval(AudioManager.Event.MOVE), "止めている間は鳴らさない")


# --- BGM（要件定義 §101） ---------------------------------------------------


func test_every_required_track_exists() -> void:
	# 要件定義 §101: Menu / Battle Normal / Battle Mid / Battle Late / Final /
	# Victory / Defeat の 7 つ（NONE を除く）。
	assert_eq(MusicManager.Track.size(), 8, "7 状態 + 未設定")

	for track in MusicManager.Track.values():
		if track == MusicManager.Track.NONE:
			continue
		music.play_track(track)
		assert_eq(music.get_track(), track, "%s に切り替わる" % MusicManager.get_track_name(track))


func test_track_follows_the_battle_phase() -> void:
	# 要件定義 §93: 残存人数の段階で切り替わる。
	var expected: Dictionary = {
		BattlePhase.Phase.OPENING: MusicManager.Track.BATTLE_NORMAL,
		BattlePhase.Phase.MIDDLE: MusicManager.Track.BATTLE_MID,
		BattlePhase.Phase.LATE: MusicManager.Track.BATTLE_LATE,
		BattlePhase.Phase.FINAL: MusicManager.Track.FINAL,
		BattlePhase.Phase.DUEL: MusicManager.Track.FINAL,
	}

	for phase in expected:
		music.follow_phase(phase)
		assert_eq(
			music.get_track(), expected[phase], "%s の BGM" % BattlePhase.get_phase_name(phase)
		)


func test_phase_decision_stays_in_the_battle_layer() -> void:
	# UI / Audio 側で人数から段階を決めない（要件定義 §93）。
	var manager := BattleManager.new()
	manager.setup(1, 29, SEED)

	music.follow_phase(manager.get_phase())

	assert_eq(
		music.get_track(),
		MusicManager.track_for_phase(manager.get_phase()),
		"Battle Layer の段階をそのまま使う"
	)


func test_result_tracks() -> void:
	music.play_result(true)
	assert_eq(music.get_track(), MusicManager.Track.VICTORY, "勝ったら Victory")

	music.play_result(false)
	assert_eq(music.get_track(), MusicManager.Track.DEFEAT, "負けたら Defeat")


func test_track_change_is_reported() -> void:
	var changes: Array = []
	music.track_changed.connect(
		func(previous: int, current: int) -> void: changes.append([previous, current])
	)

	music.play_track(MusicManager.Track.MENU)
	music.play_track(MusicManager.Track.MENU)

	assert_eq(changes.size(), 1, "同じ BGM への切り替えでは鳴らし直さない")


# --- Pause（要件定義 §96） --------------------------------------------------


func test_pause_ducks_the_music() -> void:
	music.play_track(MusicManager.Track.BATTLE_NORMAL)

	music.set_ducked(true)
	assert_true(music.is_ducked(), "Pause 中は減衰する")

	music.set_ducked(false)
	assert_false(music.is_ducked(), "戻すと元に戻る")
