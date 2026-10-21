class_name Enemy
extends Node2D

var game: Node2D
var kind := "torch"
var lane := -1
var camp := -1
var health := 50.0
var max_health := 50.0
var speed := 76.0
var radius := 22.0
var waypoint := 1
var home := Vector2.ZERO
var motion := Vector2.ZERO
var knockback := Vector2.ZERO
var visual: ActorVisual
var attack_cooldown := 1.0
var windup := 0.0
var attack_kind := ""
var attack_direction := Vector2.RIGHT
var slow_time := 0.0
var burn_time := 0.0
var burn_tick := 0.0
var burn_source := "hero"
var flash_time := 0.0
var since_hit := 10.0
var dead := false
var death_clock := 0.0
var boss_phase := 0
var armor_hint := 0.0
var emergence := 0.35
var salvo_remaining := 0
var salvo_clock := 0.0
var salvo_direction := Vector2.RIGHT
var navigation := PackedVector2Array()
var navigation_clock := 0.0

func _ready() -> void:
	home = position
	visual = ActorVisual.new()
	add_child(visual)
	var family := kind if kind in ["torch", "tnt", "barrel"] else ("archer" if kind == "shooter" else "warrior")
	visual.setup(family, "Red", 0.76 if kind != "boss" else 1.32)
	if kind == "barrel": visual.setup("barrel", "Red", 0.95)
	if kind == "shielded":
		visual.setup("barrel", "Purple", 1.0)
		radius = 28
	if kind == "armored":
		visual.setup("barrel", "Blue", 0.95)
		radius = 26
	if kind in ["boss", "warden"]:
		radius = 37 if kind == "boss" else 28
		attack_cooldown = 2.0
	visual.scale = Vector2.ONE * 0.6

func center() -> Vector2:
	return position + Vector2(0, -42 if kind == "boss" else (-30 if kind == "shielded" else (-26 if kind == "armored" else -24)))

func remaining_route() -> float:
	if lane < 0: return 100000.0
	var route: Array = Rules.PATHS[lane]
	var remaining: float = position.distance_to(route[waypoint])
	for segment in range(waypoint, route.size() - 1):
		remaining += route[segment].distance_to(route[segment + 1])
	return remaining

func _physics_process(delta: float) -> void:
	if dead:
		death_clock += delta
		visual.advance(delta, Vector2.ZERO, attack_direction)
		if death_clock > 0.29: queue_free()
		return
	if not game.running: return
	emergence = maxf(0, emergence - delta)
	visual.scale = visual.scale.lerp(Vector2.ONE, minf(1, delta * 14))
	attack_cooldown -= delta
	if salvo_remaining > 0:
		salvo_clock -= delta
		if salvo_clock <= 0:
			salvo_remaining -= 1
			salvo_clock = 0.23
			for angle in [-0.36, -0.18, 0.0, 0.18, 0.36]:
				var bullet: Projectile = game.enemy_bullet(center(), salvo_direction.rotated(angle + salvo_remaining * 0.045), 12, 195)
				bullet.pattern = "needle"
	since_hit += delta
	armor_hint = maxf(0, armor_hint - delta)
	slow_time = maxf(0, slow_time - delta)
	flash_time = maxf(0, flash_time - delta)
	if burn_time > 0:
		burn_time -= delta
		burn_tick -= delta
		if burn_tick <= 0:
			burn_tick = 0.5
			take_damage(5 + game.rank("ember") * 3, false, burn_source)
			game.spark(center(), Vector2(0, -45), Color("ffa56c"), 0.35, 4)
		if dead: return
	if emergence > 0:
		visual.advance(delta, Vector2.ZERO, Vector2.LEFT)
		return
	var hero_alive: bool = game.hero.respawn_time <= 0
	var hero_distance: float = position.distance_to(game.hero.position)
	if windup > 0:
		windup -= delta
		motion = Vector2.ZERO
		if windup <= 0: _release_attack()
		visual.advance(delta, Vector2.ZERO, attack_direction)
		queue_redraw()
		return
	var target := home
	if lane >= 0:
		var route: Array = Rules.PATHS[lane]
		target = route[waypoint]
		if position.distance_to(target) < 8:
			waypoint += 1
			if waypoint >= route.size():
				game.damage_core(Rules.leak_damage(kind, game.core_health))
				dead = true
				game.enemy_escaped(self)
				queue_free()
				return
			target = route[waypoint]
	elif hero_alive and game.hero.position.distance_to(home) < 510:
		target = game.hero.position
	var direction := (target - position).normalized()
	var factor := (0.8 if kind == "boss" else 0.45) if slow_time > 0 else 1.0
	var movement := speed * factor
	if lane < 0:
		navigation_clock -= delta
		if navigation_clock <= 0:
			navigation = game.navigation_path(position, target)
			navigation_clock = 0.5
		while not navigation.is_empty() and position.distance_to(navigation[0]) < 12: navigation.remove_at(0)
		if not navigation.is_empty(): direction = (navigation[0] - position).normalized()
		if position.distance_to(target) < (260 if kind in ["tnt", "shooter"] else 48) and game.line_of_sight(center(), game.hero.center()): movement = 0
	if flash_time > 0 and kind not in ["boss", "warden"]: movement *= 0.25
	motion = direction * movement
	position += direction * movement * delta
	position += knockback * delta
	knockback = knockback.move_toward(Vector2.ZERO, delta * 700)
	if hero_alive and attack_cooldown <= 0 and game.line_of_sight(center(), game.hero.center()):
		if kind in ["boss", "warden"] and hero_distance < 790:
			begin_attack("boss", game.hero.position, 0.55)
		elif kind in ["tnt", "shooter"] and hero_distance < 620:
			begin_attack("throw", game.hero.center(), 0.36)
		elif hero_distance < (74 if kind != "barrel" else 95):
			begin_attack("melee" if kind != "barrel" else "burst", game.hero.position, 0.3 if kind != "barrel" else 0.55)
	visual.advance(delta, motion, direction)
	if slow_time > 0 and visual.hit_flash <= 0: visual.sprite.modulate = Color("a5e3ed")
	queue_redraw()

func begin_attack(action: String, target: Vector2, preparation: float) -> void:
	attack_kind = action
	attack_direction = (target - center()).normalized()
	windup = preparation
	attack_cooldown = 1.4 if action == "melee" else (2.2 if action == "throw" else 4.6)
	if kind == "boss" and health < max_health * 0.5: attack_cooldown = 3.6
	visual.attack(attack_direction, preparation + 0.24)

func _release_attack() -> void:
	if game.hero.respawn_time > 0: return
	match attack_kind:
		"melee":
			if position.distance_to(game.hero.position) < 86:
				game.hero.take_damage(13)
		"burst":
			game.add_hazard(position, 88, 0.28, 22)
			attack_cooldown = 2.5
		"throw":
			var direction: Vector2 = (game.hero.center() - center()).normalized()
			for angle in ([-0.25, 0.0, 0.25] if kind == "shooter" or game.wave >= 3 else [0.0]):
				var bullet: Projectile = game.enemy_bullet(center(), direction.rotated(angle), 10 if kind == "shooter" else 12, 185)
				bullet.pattern = "needle" if kind == "shooter" else "orb"
		"boss":
			_boss_attack()

func _boss_attack() -> void:
	boss_phase += 1
	var target: Vector2 = game.hero.position
	var direction: Vector2 = (game.hero.center() - center()).normalized()
	game.add_hazard(target, 98 if kind == "boss" else 75, 1.25, 32 if kind == "boss" else 21)
	if boss_phase % 3 == 2:
		salvo_remaining = 3
		salvo_clock = 0
		salvo_direction = direction
	else:
		var count := 16 if kind == "boss" else 10
		for bullet_index in range(count):
			if bullet_index % 8 == 0: continue
			var angle := TAU * bullet_index / float(count) + boss_phase * 0.22
			var bullet: Projectile = game.enemy_bullet(center(), Vector2.RIGHT.rotated(angle), 14 if kind == "boss" else 10, 135 if boss_phase % 3 == 1 else 165)
			if boss_phase % 3 == 0: bullet.turn_speed = 0.22 if bullet_index % 2 == 0 else -0.22
	if kind == "boss" and boss_phase % 3 == 0:
		for spawn_index in range(3):
			game.spawn_enemy("torch", lane, -1, position + Vector2(randf_range(-35, 35), randf_range(-35, 35)), 80)

func _refuse(text: String, color: Color, offset: float) -> void:
	if armor_hint > 0 or text.is_empty(): return
	armor_hint = 1.2
	game.float_text(center() + Vector2(0, offset), text, color, 15)

func take_damage(amount: float, empowered := false, source := "tower") -> void:
	if dead: return
	var multiplier := Rules.damage_multiplier(kind, source)
	if multiplier <= 0.0:
		_refuse(Rules.refusal_hint(kind, source), Color("c8d4de"), -50)
		return
	amount *= multiplier
	if Rules.is_tower_source(source) and burn_time > 0: amount *= 1.3
	health -= amount
	since_hit = 0
	flash_time = 0.065
	visual.hit_flash = 0.065
	if empowered and game.rank("ember") > 0:
		burn_time = 3
		burn_source = source
	if amount >= 75:
		game.float_text(center() + Vector2(0, -30), str(int(amount)), Color("f5e6bb"), 15)
	if health <= 0:
		dead = true
		visual.death_phase = 0
		game.enemy_defeated(self, source)
		game.burst(center(), Color("e1c18c"), 7)

func _draw() -> void:
	if dead: return
	if windup > 0 and attack_kind in ["melee", "burst"]:
		draw_arc(Vector2.ZERO, 54 if attack_kind == "melee" else 85, 0, TAU, 32, Color(0.95, 0.64, 0.4, 0.6), 2, true)
	if health < max_health and since_hit < 2.5 and kind != "boss":
		draw_rect(Rect2(-20, -68, 40, 4), Color("273a3d"))
		draw_rect(Rect2(-20, -68, 40 * maxf(0, health / max_health), 4), Color("df997b"))
	if kind == "boss":
		draw_arc(Vector2.ZERO, 42, 0, TAU, 36, Color("cc745a"), 2, true)
	if kind == "shielded":
		draw_arc(Vector2.ZERO, 32, 0, TAU, 28, Color(0.55, 0.85, 0.95, 0.75), 3, true)
		draw_arc(Vector2.ZERO, 37, -0.8, 0.8, 12, Color(0.7, 0.95, 1.0, 0.5), 2, true)
	if kind == "armored":
		draw_arc(Vector2.ZERO, 30, 0, TAU, 28, Color(0.78, 0.82, 0.86, 0.8), 4, true)
