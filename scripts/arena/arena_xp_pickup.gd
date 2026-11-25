class_name ArenaXpPickup
extends Node2D
## Magnetic pixel XP crystal / star-magnet orb / bounty drop in Rift & Defense domains.

var game: Node2D
var domain: String = "rift"
var kind: String = "cyan"
var xp_value: int = 15
var gold_value: int = 0
var magnetized: bool = false
var pop_vel: Vector2 = Vector2.ZERO
var pop_clock: float = 0.22
var life: float = 55.0
var _bob_seed: float = 0.0
var _collected: bool = false

static var _tex_cache: Dictionary = {}


static func _icon_tex(key: String) -> Texture2D:
	if not _tex_cache.has(key):
		var map := {
			"cyan": "res://assets/rift_v030/xp_cyan.png",
			"violet": "res://assets/rift_v030/xp_violet.png",
			"gold_core": "res://assets/rift_v030/xp_magnet.png",
			"bounty_bag": "res://assets/rift_v030/chest_bounty.png",
		}
		var p: String = str(map.get(key, map.cyan))
		_tex_cache[key] = load(p) as Texture2D if ResourceLoader.exists(p) else null
	return _tex_cache.get(key) as Texture2D


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bob_seed = float(get_instance_id() % 97) * 0.13
	queue_redraw()


func _physics_process(delta: float) -> void:
	if _collected or game == null or not game.running or game.game_over:
		return
	if pop_clock > 0.0:
		pop_clock = maxf(0.0, pop_clock - delta)
		position += pop_vel * delta
		pop_vel = pop_vel.move_toward(Vector2.ZERO, 520.0 * delta)
	life -= delta
	if life <= 0.0:
		_dispose()
		return
	var hero: Node2D = game.hero
	if is_instance_valid(hero) and not hero.knocked_out and game.active_domain == domain:
		var mag_scale: float = game.passive_engine.magnet_scale() if game.passive_engine != null else 1.0
		var pull_r: float = 168.0 * mag_scale
		var dist: float = position.distance_to(hero.position)
		if dist <= pull_r:
			magnetized = true
		if magnetized:
			var pull_spd: float = lerpf(540.0, 1180.0, clampf(1.0 - dist / maxf(40.0, pull_r), 0.0, 1.0))
			position = position.move_toward(hero.position + Vector2(0.0, -14.0), pull_spd * delta)
			if position.distance_to(hero.position + Vector2(0.0, -14.0)) <= 24.0:
				_collect()
				return
	if Engine.get_physics_frames() % 2 == 0:
		queue_redraw()


func _collect() -> void:
	if _collected:
		return
	_collected = true
	if kind == "gold_core":
		for item in game.pickups:
			if is_instance_valid(item) and item.domain == domain:
				item.magnetized = true
		game.numbers.append({
			"point": position + Vector2(0.0, -24.0),
			"text": "全屏吸星!",
			"colour": Color("ffe678"),
			"life": 0.75,
			"duration": 0.75,
			"critical": true
		})
	if gold_value > 0:
		game.gold += gold_value
		game.numbers.append({
			"point": position + Vector2(0.0, -18.0),
			"text": "+%d金" % gold_value,
			"colour": Color("f6d468"),
			"life": 0.65,
			"duration": 0.65
		})
	if xp_value > 0 and game.has_method("gain_run_xp"):
		game.gain_run_xp(float(xp_value), position)
	var fx_col := Color("6ef2ff") if kind == "cyan" else (Color("d478ff") if kind == "violet" else Color("ffe474"))
	game.effect(position, 18.0, fx_col, "hit", 0.16)
	game.audio.play("ui_click", -22.0, 1.58 if kind == "cyan" else 1.32)
	_dispose()


func _dispose() -> void:
	if game != null and "pickups" in game:
		game.pickups.erase(self)
	queue_free()


func _draw() -> void:
	var t := float(Time.get_ticks_msec()) * 0.005 + _bob_seed
	var bob_y := sin(t) * 3.0
	draw_set_transform(Vector2(0.0, 4.0), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 9.0 if kind == "cyan" else 13.0, Color(0.05, 0.08, 0.12, 0.42))
	draw_set_transform(Vector2.ZERO)
	var tex := _icon_tex(kind)
	var sz := Vector2(26, 26) if kind == "cyan" else (Vector2(34, 34) if kind == "violet" else Vector2(38, 38))
	if tex != null:
		draw_texture_rect(tex, Rect2(Vector2(-sz.x * 0.5, -sz.y * 0.85 + bob_y), sz), false)
	else:
		var c := Color("6cf0ff") if kind == "cyan" else Color("cf74ff")
		draw_circle(Vector2(0.0, -12.0 + bob_y), 7.0, c)
