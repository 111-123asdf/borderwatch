class_name ActorVisual
extends Node2D

var sprite: Sprite2D
var family := "warrior"
var factor := 0.85
var walk_phase := 0.0
var idle_phase := 0.0
var action_phase := 0.0
var action_duration := 0.5
var action_direction := Vector2.RIGHT
var direction := Vector2.RIGHT
var moving := false
var hero_cape := false
var cape_velocity := Vector2.ZERO
var hit_flash := 0.0
var death_phase := -1.0
var base_position := Vector2.ZERO
var base_sprite_scale := Vector2.ONE
var animated_frames: Array[int] = []
var weapon_rig: Node2D
var held_weapon := "pistol"
var hero_identity := ""
var dual_active := false
var hero_row := 0
var hero_views: Dictionary = {}
var hero_preview_key := ""
var hero_view := "front"
var enemy_preview_key := ""
var enemy_walk_texture: Texture2D
var enemy_attack_texture: Texture2D
var enemy_walk_frames := 0
var enemy_attack_frames := 0

# Pixel offsets align the generated walk frames to a common foot position.
# They are applied at draw time; the original sheets remain unmodified.
const HERO_FRAME_OFFSETS := {
	"knight_front": [Vector2(-2, 0), Vector2(0, 0), Vector2(0, 16), Vector2(-1, 10), Vector2(0, 10), Vector2(0, 0)],
	"knight_side": [Vector2(-0.7, 4.4), Vector2(-4, 6.5), Vector2(-5.6, 5.5), Vector2(-0.2, 5.4), Vector2(-0.7, 6.5), Vector2(0.4, 5.4)],
	"knight_back": [Vector2(6, 10), Vector2(8.5, 7), Vector2(3, 7), Vector2(12.5, 11), Vector2(3.5, 4), Vector2(-4, 3)],
	"ranger_front": [Vector2(20, 0), Vector2(6.5, 0), Vector2(0, 37), Vector2(-10.5, 0), Vector2(-19, 7), Vector2(-20.5, 7)],
	"ranger_side": [Vector2(0.5, 0), Vector2(1.5, 0), Vector2(-1.5, 0), Vector2(-3.5, 0), Vector2(0.5, 0), Vector2(2, -1)],
	"ranger_back": [Vector2(15.5, 0), Vector2(0, 0), Vector2(2.5, 20), Vector2(0, 0), Vector2(-5, 0), Vector2(-9.5, 0)],
	"mage_front": [Vector2(-9.5, 0), Vector2(4, 0), Vector2(-4, 0), Vector2(-0.5, 0), Vector2(0, 0), Vector2(0.5, 0)],
	"mage_side": [Vector2(-6.5, -2), Vector2(0.5, -2), Vector2(-2, -2), Vector2(0, -2), Vector2(1, -2), Vector2(-2, -2)],
	"mage_back": [Vector2(8.5, 8), Vector2(7.5, 6), Vector2(9.5, 6), Vector2(7, 6), Vector2(8.5, 6), Vector2(9.5, 8)],
}

func setup(kind: String, color := "Blue", size_factor := 0.85, cape := false) -> void:
	family = kind
	hero_preview_key = ""
	hero_views.clear()
	enemy_preview_key = ""
	factor = size_factor
	hero_cape = cape
	if sprite != null:
		sprite.queue_free()
	var path := "Factions/Knights/Troops/Warrior/%s/Warrior_%s.png" % [color, color]
	var dimensions := Vector2i(6, 8)
	if family in ["caster", "crossbow", "modular"]:
		path = "Factions/Knights/Troops/Archer/Archer + Bow/Archer_%s_(NoArms).png" % color
		dimensions = Vector2i(6, 2)
	elif family == "archer":
		# Tiny Swords' original Purple sprite filename contains this spelling.
		var filename_color := "Purlple" if color == "Purple" else color
		path = "Factions/Knights/Troops/Archer/%s/Archer_%s.png" % [color, filename_color]
		dimensions = Vector2i(8, 7)
	elif family == "torch":
		path = "Factions/Goblins/Troops/Torch/%s/Torch_%s.png" % [color, color]
		dimensions = Vector2i(7, 5)
	elif family == "tnt":
		path = "Factions/Goblins/Troops/TNT/%s/TNT_%s.png" % [color, color]
		dimensions = Vector2i(7, 3)
	elif family == "barrel":
		path = "Factions/Goblins/Troops/Barrel/%s/Barrel_%s.png" % [color, color]
		dimensions = Vector2i(6, 6)
	if family == "player":
		sprite = Sprite2D.new()
		sprite.texture = load("res://assets/ui/hero-run-0.3.png")
		sprite.hframes = 6
		sprite.vframes = 3
		hero_row = 1 if color == "Yellow" else (2 if color == "Purple" else 0)
		sprite.scale = Vector2.ONE * factor * 78.0 / (sprite.texture.get_height() / 3.0)
		base_position = Vector2(0, -39 * factor)
	else:
		sprite = Art.sprite(path, dimensions)
		sprite.scale = Vector2.ONE * factor
		base_position = Vector2(0, -32 * factor)
	base_sprite_scale = sprite.scale
	sprite.position = base_position
	add_child(sprite)
	if weapon_rig != null: weapon_rig.queue_free()
	weapon_rig = null
	if family in ["caster", "crossbow", "modular", "player"]:
		weapon_rig = load("res://scripts/weapon_rig.gd").new()
		weapon_rig.visual = self
		add_child(weapon_rig)
	death_phase = -1

func use_hero_preview(key: String) -> void:
	# Some heroes have additional side/back sheets; attack poses remain separate.
	if family != "player" or sprite == null: return
	var paths := {
		"knight": "res://assets/original/knight_walk_preview.png",
		"ranger": "res://assets/original/ranger_walk_preview.png",
		"mage": "res://assets/original/mage_walk_preview.png",
	}
	if not paths.has(key): return
	hero_preview_key = key
	hero_view = "front"
	sprite.texture = load(paths[key])
	hero_views.clear()
	if key == "ranger":
		hero_views = {
			"front": sprite.texture,
			"side": load("res://assets/original/ranger_walk_side.png"),
			"back": load("res://assets/original/ranger_walk_back.png"),
		}
	elif key == "knight":
		hero_views = {
			"front": sprite.texture,
			"side": load("res://assets/original/knight_walk_side.png"),
			"back": load("res://assets/original/knight_walk_back_v2.png"),
		}
	elif key == "mage":
		hero_views = {
			"front": sprite.texture,
			"side": load("res://assets/original/mage_walk_side.png"),
			"back": load("res://assets/original/mage_walk_back_v2.png"),
		}
	sprite.hframes = 6
	sprite.vframes = 1
	hero_row = 0
	sprite.scale = Vector2.ONE * factor * 110.0 / sprite.texture.get_height()
	base_position = Vector2(0, -47 * factor)
	base_sprite_scale = sprite.scale

func use_ranger_preview() -> void:
	use_hero_preview("ranger")

func use_enemy_preview(key: String) -> void:
	if key not in ["brute", "hound", "shaman", "boss"] or sprite == null: return
	enemy_preview_key = key
	if key == "brute":
		enemy_walk_texture = load("res://assets/original/enemy_bark_brute_walk.png")
		enemy_attack_texture = load("res://assets/original/enemy_bark_brute_attack_3.png")
		enemy_walk_frames = 6
		enemy_attack_frames = 3
		sprite.scale = Vector2.ONE * factor * 160.0 / enemy_walk_texture.get_height()
		base_position = Vector2(0, -56 * factor)
	elif key == "hound":
		enemy_walk_texture = load("res://assets/original/enemy_cinder_fox_walk.png")
		enemy_attack_texture = load("res://assets/original/enemy_cinder_fox_attack.png")
		enemy_walk_frames = 4
		enemy_attack_frames = 4
		sprite.scale = Vector2.ONE * factor * 145.0 / enemy_walk_texture.get_height()
		base_position = Vector2(0, -35 * factor)
	elif key == "shaman":
		enemy_walk_texture = load("res://assets/original/enemy_forest_wisp_walk.png")
		enemy_attack_texture = null
		enemy_walk_frames = 4
		enemy_attack_frames = 0
		sprite.scale = Vector2.ONE * factor * 160.0 / enemy_walk_texture.get_height()
		base_position = Vector2(0, -56 * factor)
		sprite.self_modulate = Color(1.3, 1.3, 1.3)
	else:
		enemy_walk_texture = load("res://assets/original/enemy_moth_boss_walk_v2.png")
		enemy_attack_texture = null
		enemy_walk_frames = 4
		enemy_attack_frames = 0
		sprite.scale = Vector2.ONE * factor * 240.0 / enemy_walk_texture.get_height()
		base_position = Vector2(0, -90 * factor)
	sprite.texture = enemy_walk_texture
	sprite.hframes = enemy_walk_frames
	sprite.vframes = 1
	base_sprite_scale = sprite.scale

func advance(delta: float, motion: Vector2, facing: Vector2) -> void:
	if sprite == null:
		return
	var traveled := motion.length() * delta
	moving = traveled > 0.05
	walk_phase += traveled / 16.0
	idle_phase += delta
	cape_velocity = cape_velocity.lerp(-motion * 0.055, 1 - exp(-10 * delta))
	if facing.length() > 0.1:
		direction = facing.normalized()
	hit_flash = maxf(0, hit_flash - delta)
	var frame_index := 0
	var flip := direction.x < -0.15
	if family == "player" and not hero_views.is_empty():
		var body_direction := motion.normalized() if moving else direction
		var view := "side" if absf(body_direction.x) > absf(body_direction.y) else ("back" if body_direction.y < -0.15 else "front")
		hero_view = view
		sprite.texture = hero_views[view]
		flip = view == "side" and body_direction.x < 0
	var bob := 0.0
	var impact := 0.0
	var preview_attacking := false
	if death_phase >= 0:
		death_phase += delta
		sprite.modulate.a = maxf(0, 1 - death_phase / 0.28)
		sprite.rotation = death_phase * 2.5 * (-1 if flip else 1)
		sprite.position.y = base_position.y + death_phase * 18
		queue_redraw()
		return
	if family == "player":
		if action_phase > 0:
			action_phase = maxf(0, action_phase - delta)
			var progress := 1 - action_phase / action_duration
			if hero_views.is_empty(): flip = action_direction.x < 0
			bob = -sin(progress * PI) * 2.5
			impact = sin(progress * PI)
		frame_index = hero_row * 6 + (int(walk_phase) % 6 if moving else 1)
		if moving: bob -= absf(sin(walk_phase * PI / 3)) * 1.5
		else: bob += sin(idle_phase * 3) * 0.6
	elif not enemy_preview_key.is_empty():
		if action_phase > 0 and enemy_attack_texture != null:
			preview_attacking = true
			action_phase = maxf(0, action_phase - delta)
			var progress := 1 - action_phase / action_duration
			if sprite.texture != enemy_attack_texture:
				sprite.frame = 0
				sprite.texture = enemy_attack_texture
				sprite.hframes = enemy_attack_frames
			# The first two fox attack cells overlap; use the two clean poses.
			frame_index = 2 + mini(1, int(progress * 2)) if enemy_preview_key == "hound" else mini(2, int(progress * 3))
			flip = action_direction.x < -0.15
			bob = -sin(progress * PI) * 2.0
		else:
			action_phase = maxf(0, action_phase - delta)
			if sprite.texture != enemy_walk_texture:
				sprite.frame = 0
				sprite.texture = enemy_walk_texture
				sprite.hframes = enemy_walk_frames
			if enemy_preview_key == "boss":
				frame_index = int(idle_phase * 5) % enemy_walk_frames
				bob = sin(idle_phase * 3) * 4.0
			else:
				frame_index = int(walk_phase) % enemy_walk_frames if moving else (int(idle_phase * 5) % enemy_walk_frames if enemy_preview_key == "shaman" else 0)
				if enemy_preview_key == "shaman": bob = sin(idle_phase * 3) * 2.0
	elif action_phase > 0:
		action_phase = maxf(0, action_phase - delta)
		var progress := 1 - action_phase / action_duration
		flip = action_direction.x < 0
		var row := 2
		var frame_count := 6
		if family in ["caster", "crossbow", "modular"]:
			row = 1 if moving else 0
		elif family == "archer":
			frame_count = 8
			var vertical := action_direction.y
			row = 2 if vertical < -0.8 else (3 if vertical < -0.3 else (4 if vertical < 0.3 else (5 if vertical < 0.8 else 6)))
		elif family == "warrior":
			row = 6 if action_direction.y < -0.5 else (4 if action_direction.y > 0.5 else 2)
		elif family == "torch":
			row = 4 if action_direction.y < -0.5 else (3 if action_direction.y > 0.5 else 2)
		elif family == "tnt":
			frame_count = 7
		elif family == "barrel":
			row = 5
			frame_count = 3
		frame_index = row * sprite.hframes + (int(walk_phase) % 6 if moving and family in ["caster", "crossbow", "modular"] else mini(frame_count - 1, int(progress * frame_count)))
		bob = -sin(progress * PI) * 2
	elif moving:
		frame_index = sprite.hframes + int(walk_phase) % 6
		bob = -absf(sin(walk_phase * PI / 3)) * 2.0
	else:
		# Barrel's idle row contains just one pose; the remaining cells are empty.
		var idle_count := 1 if family == "barrel" else (7 if family == "torch" else 6)
		frame_index = int(idle_phase * 8) % idle_count
	sprite.frame = frame_index
	sprite.flip_h = flip
	sprite.position = base_position + Vector2(0, bob)
	if family == "player" and not hero_preview_key.is_empty():
		var key := "%s_%s" % [hero_preview_key, hero_view]
		var offsets: Array = HERO_FRAME_OFFSETS.get(key, [])
		if not offsets.is_empty():
			var offset: Vector2 = offsets[frame_index % 6] * base_sprite_scale
			if flip: offset.x = -offset.x
			sprite.position += offset
	elif not enemy_preview_key.is_empty():
		var offsets: Array
		if enemy_preview_key == "brute":
			offsets = [Vector2(9.4, 0), Vector2(84.7, 4), Vector2(28.2, -1)] if preview_attacking else [Vector2(9, 0), Vector2(-1.5, -1), Vector2(-6.5, -1), Vector2(-4, 0), Vector2(-4.5, 0), Vector2(0.5, 0)]
		elif enemy_preview_key == "hound":
			offsets = [Vector2(0, 2), Vector2(12.6, 0), Vector2(-47.7, 8), Vector2(-1.3, 0)]
			if preview_attacking: offsets = [Vector2.ZERO, Vector2.ZERO, Vector2(60.2, 20), Vector2(-15.9, -7)]
		elif enemy_preview_key == "shaman":
			offsets = [Vector2(0, 0), Vector2(-15, 6), Vector2(-15, 1), Vector2(-26, 2)]
		else:
			# Align the glowing thorax between different wing positions.
			offsets = [Vector2(-4.6, 0), Vector2(10, 0), Vector2(-8.7, -19.4), Vector2(10.7, -3.1)]
		var offset: Vector2 = offsets[frame_index] * base_sprite_scale
		if flip: offset.x = -offset.x
		sprite.position += offset
	# The hero atlas has run poses but no attack poses: use a restrained body
	# reaction while its weapon animates, without changing actor motion.
	if family == "player":
		# The knight's side drawing has extra transparent space above its helmet.
		# Scale that view to match the apparent body height of its front view.
		var view_scale := 1.09 if hero_preview_key == "knight" and hero_view == "side" else 1.0
		sprite.scale = base_sprite_scale * view_scale * Vector2(1.0 + impact * 0.045, 1.0 - impact * 0.045)
	var lean := clampf(motion.x / 230.0, -1, 1) * 0.025 if action_phase <= 0 else 0.0
	sprite.rotation = lerpf(sprite.rotation, lean, minf(1, delta * 14))
	sprite.modulate = Color(2.3, 1.9, 1.5) if hit_flash > 0 else Color.WHITE
	if animated_frames.size() < 120 and (animated_frames.is_empty() or animated_frames.back() != frame_index):
		animated_frames.append(frame_index)
	queue_redraw()
	if weapon_rig != null: weapon_rig.queue_redraw()

func attack(aim: Vector2, duration: float) -> void:
	action_direction = aim.normalized()
	action_duration = duration
	action_phase = duration

func _draw() -> void:
	if not hero_cape or death_phase >= 0 or family == "player":
		return
	var back := Vector2(-12 if direction.x >= 0 else 12, -29)
	var sway := sin(idle_phase * 6) * 3
	var tail := back + Vector2(cape_velocity.x + sway, 24 + absf(cape_velocity.y) * 0.25)
	draw_colored_polygon(PackedVector2Array([back + Vector2(-6, 0), back + Vector2(7, 1), tail + Vector2(7, 0), tail + Vector2(0, 5), tail + Vector2(-8, -1)]), Color("233c4f"))
	draw_colored_polygon(PackedVector2Array([back + Vector2(-3, 1), back + Vector2(5, 1), tail + Vector2(4, -1), tail + Vector2(-4, 1)]), Color("58a2b3"))
