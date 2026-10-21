class_name Projectile
extends Node2D

var game: Node2D
var direction := Vector2.RIGHT
var damage := 15.0
var kind := "bow"
var empowered := false
var hostile := false
var speed := 780.0
var lifetime := 1.5
var splash := 0.0
var color := Color("ffe3a1")
var traveled := 0.0
var max_distance := 740.0
var pierce := 0
var chain_count := 0
var struck: Array[int] = []
var clock := 0.0
var pattern := "orb"
var turn_speed := 0.0
var returning := false
var upgrade_level := 1

func _physics_process(delta: float) -> void:
	if not game.running: return
	lifetime -= delta
	clock += delta
	var previous := position
	if hostile and turn_speed != 0: direction = direction.rotated(turn_speed * delta)
	if kind == "boomerang":
		if clock > 0.58 and not returning:
			returning = true
			struck.clear()
		if returning:
			direction = (game.hero.center() - position).normalized()
			if position.distance_to(game.hero.center()) < 20:
				queue_free()
				return
		game.sweep_bullets(position, 18)
	position += direction * speed * delta
	traveled += speed * delta
	if lifetime <= 0 or (traveled >= max_distance and kind != "boomerang"):
		queue_free()
		return
	if kind != "boomerang" and not game.line_of_sight(previous, position):
		game.burst(position, Color("d0c9a8"), 3)
		queue_free()
		return
	if hostile:
		if game.hero.class_id == "mage" and game.hero.skill_time > 0 and position.distance_to(game.hero.center()) < 58:
			game.hero.energy = minf(game.hero.max_energy, game.hero.energy + 3 + game.hero.skill_level)
			game.burst(position, Color("b3dced"), 3)
			queue_free()
			return
		if game.hero.respawn_time <= 0 and _hits(previous, position, game.hero.center(), 16):
			game.hero.take_damage(damage)
			queue_free()
		queue_redraw()
		return
	for enemy in game.enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead or enemy.get_instance_id() in struck: continue
		if _hits(previous, position, enemy.center(), enemy.radius + (6 if kind == "cannon" else 0)):
			struck.append(enemy.get_instance_id())
			_impact(enemy)
			if pierce <= 0:
				queue_free()
				return
			pierce -= 1
	if kind == "cannon" and int(clock * 35) % 3 == 0:
		game.spark(position, -direction * 25, Color(0.8, 0.77, 0.61, 0.45), 0.22, 3)
	queue_redraw()

func _hits(start: Vector2, end: Vector2, target: Vector2, radius: float) -> bool:
	return target.distance_to(Geometry2D.get_closest_point_to_segment(target, start, end)) < radius

func _impact(target: Enemy) -> void:
	var source := "hero" if kind in Rules.weapon_keys() or kind == "crescent" else kind
	if splash > 0:
		game.radial_damage(position, splash, damage, source, empowered)
		game.explosion(position, splash, color, kind == "cannon")
		if kind == "rocket" and upgrade_level >= 3:
			for angle in [-0.5, 0.0, 0.5]: game.fire_projectile(position, direction.rotated(angle), damage * 0.2, "crescent", true)
	else:
		target.take_damage(damage, empowered, source)
		game.burst(position, color, 4)
	if kind == "frost" and not target.dead: target.slow_time = 2.6
	if empowered and game.rank("storm") > 0: chain_count = maxi(chain_count, 1)
	var excluded: Array[Enemy] = [target]
	var origin := target.center()
	for chain_index in range(chain_count):
		var chained: Enemy = game.nearest_enemy(origin, 185, null, excluded)
		if chained == null: break
		excluded.append(chained)
		game.lightning(origin, chained.center())
		chained.take_damage(damage * (0.4 + game.rank("storm") * 0.12), empowered, source)
		origin = chained.center()
	game.sound.play("hit", 16)

func _draw() -> void:
	if hostile:
		draw_circle(Vector2.ZERO, 10, Color(0.9, 0.05, 0.14, 0.1))
		draw_circle(Vector2.ZERO, 8, Color("591a32"))
		draw_circle(Vector2.ZERO, 6.5, Color("fb4258"))
		draw_circle(Vector2.ZERO, 4, Color("fff0d1"))
		draw_circle(Vector2.ZERO, 2, Color("ff8586"))
		if pattern == "needle":
			draw_line(-direction * 17, -direction * 8, Color("ff6d77"), 3, true)
		return
	draw_set_transform(Vector2.ZERO, direction.angle())
	if kind == "boomerang":
		draw_set_transform(Vector2.ZERO, clock * 18)
		draw_arc(Vector2.ZERO, 14, 0.1, PI * 1.65, 20, Color("304f4a"), 8, false)
		draw_arc(Vector2.ZERO, 14, 0.1, PI * 1.65, 20, color, 4, false)
	elif kind in ["pistol", "gatling", "sniper"]:
		draw_line(Vector2(-22 if kind == "sniper" else -12, 0), Vector2(6, 0), Color(color, 0.35), 5, true)
		draw_line(Vector2(-7, 0), Vector2(6, 0), color, 3, false)
		draw_circle(Vector2(5, 0), 2, Color("fff5c7"))
	elif kind == "rocket":
		draw_rect(Rect2(-9, -4, 14, 8), Color("aab6bb"))
		draw_colored_polygon(PackedVector2Array([Vector2(13, 0), Vector2(3, -6), Vector2(3, 6)]), Color("f5795e"))
		draw_line(Vector2(-9, 0), Vector2(-20 - sin(clock * 70) * 5, 0), Color("ffd58b"), 5, true)
	elif kind in ["bow", "bolt", "storm"]:
		draw_line(Vector2(-27, 0), Vector2(-5, 0), Color(color, 0.28), 3, true)
		draw_line(Vector2(-13, 0), Vector2(10, 0), Color("3c4b4c"), 5, false)
		draw_line(Vector2(-13, 0), Vector2(9, 0), color, 2, false)
		draw_colored_polygon(PackedVector2Array([Vector2(13, 0), Vector2(5, -4), Vector2(5, 4)]), Color("f1eed2"))
		draw_line(Vector2(-9, 0), Vector2(-14, -4), color, 2, false)
		draw_line(Vector2(-9, 0), Vector2(-14, 4), color, 2, false)
	elif kind == "crescent":
		draw_arc(Vector2.ZERO, 14, -1.3, 1.3, 12, Color(color, 0.45), 8, true)
		draw_arc(Vector2.ZERO, 13, -1.2, 1.2, 12, color, 3, true)
	else:
		var radius := 8.0 if kind == "cannon" else 4.5
		draw_line(Vector2(-22, 0), Vector2.ZERO, Color(color, 0.35), radius, true)
		draw_circle(Vector2.ZERO, radius + 2, Color("3b4450"))
		draw_circle(Vector2.ZERO, radius, color)
		draw_circle(Vector2(-2, -2), radius * 0.35, Color("fff2cf"))
