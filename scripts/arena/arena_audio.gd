class_name ArenaAudio
extends Node

var players: Array[AudioStreamPlayer] = []
var streams := {}
var cursor := 0
var last_play := {}

func _ready() -> void:
	for index in range(8):
		var player := AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		players.append(player)
	_make("shoot", 0.055, 900.0, 0.55, 0.85)
	_make("hit", 0.06, 520.0, 0.65, 0.55)
	_make("crit", 0.11, 1300.0, 0.45, 0.7)
	_make("kill", 0.18, 240.0, 0.5, 0.9)
	_make("hurt", 0.12, 180.0, 0.6, 0.8)
	_make("tower", 0.045, 700.0, 0.6, 0.45)
	_make("explode", 0.32, 110.0, 0.75, 1.0)
	_make("phase", 0.4, 80.0, 0.8, 1.0)

func play(kind: String, volume_db := -8.0, pitch := 1.0) -> void:
	if not streams.has(kind): return
	var now := Time.get_ticks_msec()
	if last_play.has(kind) and now - int(last_play[kind]) < 45: return
	last_play[kind] = now
	var player: AudioStreamPlayer = players[cursor % players.size()]
	cursor += 1
	player.stream = streams[kind]
	player.volume_db = volume_db
	player.pitch_scale = pitch * randf_range(0.94, 1.06)
	player.play()

func _make(kind: String, duration: float, base_hz: float, noise_mix: float, volume: float) -> void:
	var rate := 22050
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var seed_value := int(base_hz) * 17 + count
	for index in range(count):
		var t := float(index) / float(rate)
		var progress := float(index) / float(count)
		var envelope := pow(1.0 - progress, 2.2) * volume
		var tone := sin(TAU * base_hz * t * (1.0 - progress * 0.35))
		var noise := sin(TAU * float((seed_value + index * 7919) % 1000) * t) * 0.5
		var sample := (tone * (1.0 - noise_mix) + noise * noise_mix) * envelope
		var value := int(clampf(sample, -1.0, 1.0) * 32767.0)
		bytes[index * 2] = value & 0xff
		bytes[index * 2 + 1] = (value >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	streams[kind] = stream
