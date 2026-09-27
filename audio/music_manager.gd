class_name MusicManager
extends Node

## BGM の切り替え（要件定義 §101 / §93）。
##
## 状態は Menu / Battle Normal / Battle Mid / Battle Late / Final / Victory /
## Defeat の 7 つ（要件定義 §101）。**残存人数の閾値**で切り替わる部分は
## [BattlePhase] の段階から決める。人数から段階を決める判定は Battle Layer が
## 持っているので、ここでは行わない（要件定義 §93）。
##
## 音源はコードで生成する（要件定義 §138）。出典は `assets/music/README.md`。

## BGM が切り替わった。
signal track_changed(previous: Track, current: Track)

## BGM の状態（要件定義 §101）。
enum Track { NONE, MENU, BATTLE_NORMAL, BATTLE_MID, BATTLE_LATE, FINAL, VICTORY, DEFEAT }

## BGM を流す Bus の名前。
const BUS_NAME: String = "BGM"

## 状態ごとの基準の高さ（Hz）。生成した音の違いを分かるようにする。
const TRACK_TONES: Dictionary = {
	Track.MENU: 220.0,
	Track.BATTLE_NORMAL: 262.0,
	Track.BATTLE_MID: 294.0,
	Track.BATTLE_LATE: 330.0,
	Track.FINAL: 392.0,
	Track.VICTORY: 440.0,
	Track.DEFEAT: 175.0,
}

## Pause 中に音量を下げる量（デシベル。要件定義 §96 の「Pause または減衰」）。
const DUCK_DB: float = -12.0

var _player: AudioStreamPlayer
var _track: Track = Track.NONE
var _ducked: bool = false
var _streams: Dictionary = {}


func _ready() -> void:
	AudioBusSetup.ensure_buses()
	_player = AudioStreamPlayer.new()
	_player.bus = BUS_NAME
	add_child(_player)

	for track in TRACK_TONES:
		_streams[track] = _build_loop(TRACK_TONES[track])


## 状態の名前を返す。
static func get_track_name(track: Track) -> String:
	return Track.keys()[track]


## 残存人数の段階から BGM を決める（要件定義 §93 / §101）。
static func track_for_phase(phase: BattlePhase.Phase) -> Track:
	match phase:
		BattlePhase.Phase.OPENING, BattlePhase.Phase.EARLY:
			return Track.BATTLE_NORMAL
		BattlePhase.Phase.MIDDLE:
			return Track.BATTLE_MID
		BattlePhase.Phase.LATE:
			return Track.BATTLE_LATE
		BattlePhase.Phase.FINAL, BattlePhase.Phase.DUEL:
			return Track.FINAL
		_:
			return Track.BATTLE_NORMAL


## BGM を切り替える。
func play_track(track: Track) -> void:
	if track == _track:
		return

	var previous: Track = _track
	_track = track

	if _player != null:
		_player.stop()
		var stream: AudioStream = _streams.get(track, null)
		if stream != null:
			_player.stream = stream
			_player.play()

	track_changed.emit(previous, _track)


## Battle の段階に合わせて BGM を切り替える（要件定義 §93）。
func follow_phase(phase: BattlePhase.Phase) -> void:
	play_track(track_for_phase(phase))


## 決着の BGM に切り替える。
func play_result(won: bool) -> void:
	play_track(Track.VICTORY if won else Track.DEFEAT)


## 流している BGM を返す。
func get_track() -> Track:
	return _track


## Pause 中の減衰を切り替える（要件定義 §96）。
func set_ducked(ducked: bool) -> void:
	_ducked = ducked
	if _player != null:
		_player.volume_db = DUCK_DB if ducked else 0.0


## 減衰しているかを返す。
func is_ducked() -> bool:
	return _ducked


## 流しているかを返す。
func is_playing() -> bool:
	return _player != null and _player.playing


# 一定の高さの音を繰り返すだけの BGM を作る（差し替え前の仮の音）。
func _build_loop(frequency: float) -> AudioStreamWAV:
	var sample_rate: int = SoundBank.SAMPLE_RATE
	var frames: int = sample_rate  # 1 秒ぶん
	var data := PackedByteArray()
	data.resize(frames * 2)

	for index in range(frames):
		var time: float = float(index) / float(sample_rate)
		# 2 つの高さを重ねて、単音より耳あたりを良くする。
		var sample: float = (
			sin(TAU * frequency * time) * 0.18 + sin(TAU * frequency * 1.5 * time) * 0.08
		)
		data.encode_s16(index * 2, clampi(int(sample * 32767.0), -32768, 32767))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = frames
	stream.data = data
	return stream
