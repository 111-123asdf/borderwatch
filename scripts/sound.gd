class_name GameSound
extends Node

var enabled := true
var voices: Array[AudioStreamPlayer] = []
var samples: Dictionary = {}
var cursor := 0

func _ready() -> void:
	for voice_index in range(12):
		var voice := AudioStreamPlayer.new()
		voice.volume_db = -16
		add_child(voice)
		voices.append(voice)
	for kind in ["shoot", "hit", "boom", "build", "reward", "dash", "hurt", "wave"]:
		samples[kind] = _make_sample(kind)

func play(kind: String, quiet := 0.0) -> void:
	if not enabled or not samples.has(kind):
		return
	var voice := voices[cursor % voices.size()]
	cursor += 1
	voice.stream = samples[kind]
	voice.volume_db = -17.0 - quiet
	voice.pitch_scale = randf_range(0.95, 1.05)
	voice.play()

func _make_sample(kind: String) -> AudioStreamWAV:
	var frequency := 430.0
	var duration := 0.09
	match kind:
		"hit": frequency = 170.0
		"boom": frequency = 65.0; duration = 0.25
		"build": frequency = 590.0; duration = 0.18
		"reward": frequency = 780.0; duration = 0.3
		"dash": frequency = 240.0; duration = 0.15
		"hurt": frequency = 95.0; duration = 0.2
		"wave": frequency = 210.0; duration = 0.45
	var bytes := PackedByteArray()
	var sample_count := int(22050 * duration)
	bytes.resize(sample_count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 321
	for sample_index in range(sample_count):
		var time := float(sample_index) / 22050.0
		var progress := time / duration
		var tone := sin(TAU * frequency * (time - time * progress * 0.2))
		if kind == "reward" or kind == "build":
			tone += sin(TAU * frequency * 1.5 * time) * 0.4
		if kind in ["boom", "dash", "hit"]:
			tone = tone * 0.3 + random.randf_range(-1, 1) * 0.65
		var amplitude := tone * pow(1.0 - progress, 2) * minf(time * 100, 1) * 0.5
		bytes.encode_s16(sample_index * 2, int(clampf(amplitude, -1, 1) * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = bytes
	return stream
