class_name SoundBank
extends RefCounted

## SE の音源を用意する（要件定義 §100 / §138）。
##
## **音源はすべてこのコードが生成する**（独自制作）。外部の音源を持ち込まないので、
## 権利の確認が要らない（要件定義 §138 Intellectual Property / #53 の完了条件）。
## 出典とライセンスの記録は `assets/se/README.md`。
##
## 差し替えたくなったら [method load_overrides] で `assets/se/` の音源を使える。
## ファイルがあればそちらを優先し、無ければ生成した音を使う。

## 生成する音の Sampling Rate。
const SAMPLE_RATE: int = 22050

## 音源を差し替えるときの置き場所。
const OVERRIDE_DIR: String = "res://assets/se/"

## Event ごとの音の作り（周波数 Hz / 長さ 秒 / 音量）。
##
## 低め・短めを基本にして、頻度の高い操作音が耳に付かないようにする。
const TONES: Dictionary = {
	AudioManager.Event.MOVE: [440.0, 0.03, 0.25],
	AudioManager.Event.ROTATE: [520.0, 0.04, 0.3],
	AudioManager.Event.HOLD: [360.0, 0.05, 0.3],
	AudioManager.Event.SOFT_DROP: [300.0, 0.03, 0.2],
	AudioManager.Event.HARD_DROP: [180.0, 0.07, 0.45],
	AudioManager.Event.LOCK: [240.0, 0.05, 0.35],
	AudioManager.Event.LINE_CLEAR: [660.0, 0.12, 0.5],
	AudioManager.Event.HIGH_VALUE_CLEAR: [880.0, 0.2, 0.6],
	AudioManager.Event.COMBO: [990.0, 0.08, 0.45],
	AudioManager.Event.GARBAGE_SEND: [520.0, 0.1, 0.45],
	AudioManager.Event.GARBAGE_RECEIVE: [160.0, 0.12, 0.5],
	AudioManager.Event.TARGET_CHANGE: [700.0, 0.05, 0.3],
	AudioManager.Event.DANGER: [140.0, 0.25, 0.55],
	AudioManager.Event.KO: [300.0, 0.25, 0.6],
	AudioManager.Event.VICTORY: [740.0, 0.6, 0.6],
	AudioManager.Event.DEFEAT: [200.0, 0.6, 0.55],
}

var _streams: Dictionary = {}


func _init() -> void:
	for event in TONES:
		_streams[event] = _build_tone(TONES[event][0], TONES[event][1], TONES[event][2])
	load_overrides()


## Event に対応する音源を返す。無ければ [code]null[/code]。
func get_stream(event: AudioManager.Event) -> AudioStream:
	return _streams.get(event, null)


## 用意されている Event の数を返す。
func get_stream_count() -> int:
	return _streams.size()


## `assets/se/` に音源があれば差し替える。
##
## ファイル名は Event の名前（小文字）。例: `hard_drop.wav`。
func load_overrides() -> int:
	var replaced: int = 0
	for event in TONES:
		var name: String = AudioManager.get_event_name(event).to_lower()
		for extension in [".wav", ".ogg", ".mp3"]:
			var path: String = OVERRIDE_DIR + name + extension
			if not ResourceLoader.exists(path):
				continue
			var stream: Resource = load(path)
			if stream is AudioStream:
				_streams[event] = stream
				replaced += 1
			break
	return replaced


# 単純な減衰付きサイン波を作る。生成なので音源の権利が発生しない。
func _build_tone(frequency: float, duration_sec: float, volume: float) -> AudioStreamWAV:
	var frames: int = maxi(1, int(SAMPLE_RATE * duration_sec))
	var data := PackedByteArray()
	data.resize(frames * 2)

	for index in range(frames):
		var time: float = float(index) / float(SAMPLE_RATE)
		# 終わりに向けて減衰させる。ぶつ切りにすると「プチッ」と鳴るため。
		var envelope: float = 1.0 - float(index) / float(frames)
		var sample: float = sin(TAU * frequency * time) * envelope * volume
		var value: int = clampi(int(sample * 32767.0), -32768, 32767)
		data.encode_s16(index * 2, value)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
