class_name ArenaProjectile
extends Node2D

var game: Node2D
var direction := Vector2.RIGHT
var damage := 10.0
var speed := 700.0
var color := Color("ffe3a1")
var splash := 0.0
var slow := 0.0
var hostile := false
var pierce := 0
var execute_bonus := 0.0
var burn_dps := 0.0
var poison_dps := 0.0
var critical := false
var execute_threshold := 0.35
var shatter := false
var hit_ids := {}
var life := 1.6

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	position += direction * speed * delta
	if hostile:
		if game.hero != null and game.hero.position.distance_to(position) < 20.0:
			game.hero.take_damage(damage)
			queue_free()
			return
		queue_redraw()
		return
	for enemy in game.enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead: continue
		if enemy.position.distance_to(position) < enemy.radius + 10.0:
			var enemy_id: int = enemy.get_instance_id()
			if hit_ids.has(enemy_id): continue
			hit_ids[enemy_id] = true
			if splash > 0.0:
				game.damage_radius(position, splash, damage)
				game.hit_feedback(position, damage)
			else:
				var applied := damage
				var element := ""
				if burn_dps > 0.0: element = "fire"
				elif slow > 0.0: element = "frost"
				if element != "":
					applied *= enemy.element_multiplier(element)
				if execute_bonus > 0.0 and enemy.health < enemy.max_health * execute_threshold:
					applied *= 1.0 + execute_bonus
				if shatter and critical:
					applied *= 1.5
					enemy.apply_frost(1.0)
				enemy.take_damage(applied)
				if burn_dps > 0.0:
					enemy.apply_burn(burn_dps, 3.0)
				if poison_dps > 0.0:
					enemy.apply_poison(poison_dps, 3.0)
				if game.hero != null and game.hero.passives.has("thermal_shock") and enemy.burn_time > 0.0 and enemy.slow_time > 0.0:
					game.damage_radius(enemy.position, 90.0, damage * 0.55)
				game.hit_feedback(enemy.center(), applied)
			if slow > 0.0:
				enemy.apply_frost(slow)
			if pierce > 0:
				pierce -= 1
			else:
				queue_free()
				return
	queue_redraw()

func _draw() -> void:
	draw_line(-direction * 10, direction * 4, Color(color, 0.5), 4, true)
	draw_circle(Vector2.ZERO, 4.0 if splash <= 0.0 else 6.0, color)
	if critical and not hostile:
		draw_arc(Vector2.ZERO, 9, 0, TAU, 16, Color(1.0, 0.9, 0.45, 0.8), 2, true)
	if hostile:
		draw_arc(Vector2.ZERO, 9, 0, TAU, 16, Color(color, 0.35), 2, true)