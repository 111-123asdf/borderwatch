class_name ArenaAudio
extends Node

var players: Array[AudioStreamPlayer] = []
var streams := {}
var cursor := 0
var last_play := {}
var sampled:=true
var banks: Dictionary={}
var variants: Dictionary={}
var player_families: Array[String]=["","","","","","","","","","","","","","","",""]
const HERO_CUES:=["ranger_draw","ranger_release","ranger_hit","ranger_roll","ranger_rain","mage_gather","mage_cast","mage_hit","mage_frost","mage_meteor_charge","mage_meteor_hit"]
const FILES:={
	"blade":["knifeSlice","knifeSlice2"],
	"hit":["impactPunch_medium_000","impactPunch_medium_001","impactPunch_medium_002"],
	"heavy_hit":["impactPunch_heavy_000","impactPunch_heavy_001"],
	"kill":["impactSoft_heavy_000","impactSoft_heavy_001"],
	"explode":["impactWood_heavy_000","impactWood_heavy_001"],
	"phase":["impactBell_heavy_000","impactBell_heavy_001"],
	"footstep":["footstep_grass_000","footstep_grass_001","footstep_grass_002"]}

func _ready() -> void:
	for label in ["Combat","Interface"]:
		if AudioServer.get_bus_index(label)<0:
			AudioServer.add_bus();AudioServer.set_bus_name(AudioServer.bus_count-1,label)
			var compressor:=AudioEffectCompressor.new();compressor.threshold=-6.0;compressor.ratio=8.0
			AudioServer.add_bus_effect(AudioServer.get_bus_index(label),compressor)
	for index in range(16):
		var player := AudioStreamPlayer.new()
		player.volume_db = -8.0
		add_child(player)
		players.append(player)
	for kind in FILES:
		var bank: Array=[]
		for file in FILES[kind]:
			var path: String="res://assets/v011/audio/"+str(file)+".ogg"
			if ResourceLoader.exists(path):bank.append(load(path))
		if not bank.is_empty():banks[kind]=bank
	for kind in HERO_CUES:
		var path: String="res://assets/v012/audio/"+kind+".ogg"
		if ResourceLoader.exists(path):banks[kind]=[load(path)]
	banks.ui_click=[load("res://assets/v012/audio/mage_cast.ogg")]
	_make("blade",0.12,340.0,0.88,0.7)
	_make("bow",0.09,760.0,0.15,0.55)
	_make("rocket",0.22,95.0,0.85,0.8)
	_make("throw",0.15,410.0,0.5,0.5)
	_make("shoot", 0.055, 900.0, 0.55, 0.85)
	_make("hit", 0.06, 520.0, 0.65, 0.55)
	_make("crit", 0.11, 1300.0, 0.45, 0.7)
	_make("kill", 0.18, 240.0, 0.5, 0.9)
	_make("hurt", 0.12, 180.0, 0.6, 0.8)
	_make("tower", 0.045, 700.0, 0.6, 0.45)
	_make("explode", 0.32, 110.0, 0.75, 1.0)
	_make("phase", 0.4, 80.0, 0.8, 1.0)

func _family_for(kind: String) -> String:
	if kind in ["hit","heavy_hit","mage_hit","ranger_hit"]:return "impact"
	if kind in ["bow","shoot","ranger_draw","ranger_release","mage_gather","mage_cast","explode","mage_frost","mage_meteor_hit"]:return "release"
	if kind in ["kill"]:return "kill"
	if kind in ["tower","ui_click","phase","hurt"]:return "cue"
	return "other"
func _family_cap(fam: String) -> int:
	match fam:
		"impact":return 3
		"release":return 2
		"kill":return 2
		"cue":return 2
		_:return 3
func play(kind: String, volume_db := -8.0, pitch := 1.0) -> void:
	if not streams.has(kind) and not banks.has(kind): return
	var now := Time.get_ticks_msec()
	if last_play.has(kind) and now - int(last_play[kind]) < 45: return
	var important: bool=kind in ["hurt","phase","heavy_hit","explode","mage_frost","mage_meteor_charge","mage_meteor_hit","ranger_rain"]
	var fam:=_family_for(kind)
	var cap:=_family_cap(fam)
	var active_fam:=0
	for p_idx in range(players.size()):
		if players[p_idx].playing and player_families[p_idx]==fam:
			active_fam+=1
	if active_fam>=cap and not important:return
	last_play[kind] = now
	var index: int=12+cursor%4 if important else cursor%12
	# Ordinary effects use a free voice and cannot cut off a skill or injury cue.
	if not important:
		var found:=false
		for offset in range(12):
			var candidate: int=(cursor+offset)%12
			if not players[candidate].playing:index=candidate;found=true;break
		if not found:return
	var player: AudioStreamPlayer=players[index]
	player_families[index]=fam
	cursor += 1
	if sampled and banks.has(kind):
		var variant: int=(int(variants.get(kind,-1))+1)%banks[kind].size()
		variants[kind]=variant;player.stream=banks[kind][variant]
	else:
		if not streams.has(kind):return
		player.stream=streams[kind]
	player.bus="Interface" if kind in ["tower","ui_click"] else "Combat"
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

func _exit_tree() -> void:
	shutdown()

func shutdown() -> void:
	for player in players:
		if not is_instance_valid(player): continue
		player.stop()
		player.stream = null
	streams.clear()
	banks.clear()
