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
				if execute_bonus > 0.0 and enemy.health < enemy.max_health * 0.35:
					applied *= 1.0 + execute_bonus
				enemy.take_damage(applied)
				game.hit_feedback(enemy.center(), applied)
			enemy.slow_time = maxf(enemy.slow_time, slow)
			if pierce > 0:
				pierce -= 1
			else:
				queue_free()
				return
	queue_redraw()

func _draw() -> void:
	draw_line(-direction * 10, direction * 4, Color(color, 0.5), 4, true)
	draw_circle(Vector2.ZERO, 4.0 if splash <= 0.0 else 6.0, color)
	if hostile:
		draw_arc(Vector2.ZERO, 9, 0, TAU, 16, Color(color, 0.35), 2, true)