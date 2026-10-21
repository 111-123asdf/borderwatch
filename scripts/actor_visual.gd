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
var animated_frames: Array[int] = []
var weapon_rig: Node2D
var held_weapon := "pistol"
var hero_identity := ""
var dual_active := false
var hero_row := 0

func setup(kind: String, color := "Blue", size_factor := 0.85, cape := false) -> void:
	family = kind
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
		path = "Factions/Knights/Troops/Archer/%s/Archer_%s.png" % [color, color]
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
	sprite.position = base_position
	add_child(sprite)
	if weapon_rig != null: weapon_rig.queue_free()
	weapon_rig = null
	if family in ["caster", "crossbow", "modular", "player"]:
		weapon_rig = load("res://scripts/weapon_rig.gd").new()
		weapon_rig.visual = self
		add_child(weapon_rig)
	death_phase = -1

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
	var bob := 0.0
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
			flip = action_direction.x < 0
			bob = -sin(progress * PI) * 2.5
		frame_index = hero_row * 6 + (int(walk_phase) % 6 if moving else 1)
		if moving: bob -= absf(sin(walk_phase * PI / 3)) * 1.5
		else: bob += sin(idle_phase * 3) * 0.6
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
		var idle_count := 7 if family == "torch" else 6
		frame_index = int(idle_phase * 8) % idle_count
	sprite.frame = frame_index
	sprite.flip_h = flip
	sprite.position = base_position + Vector2(0, bob)
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
