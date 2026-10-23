class_name ArenaProjectile
extends Node2D

var game: Node2D
var direction := Vector2.RIGHT
var damage := 10.0
var speed := 700.0
var color := Color("ffe3a1")
var splash := 0.0
var slow := 0.0
var life := 1.6

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	position += direction * speed * delta
	for enemy in game.enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead: continue
		if enemy.position.distance_to(position) < enemy.radius + 10.0:
			if splash > 0.0:
				game.damage_radius(position, splash, damage)
			else:
				enemy.take_damage(damage)
			enemy.slow_time = maxf(enemy.slow_time, slow)
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	draw_line(-direction * 10, direction * 4, Color(color, 0.5), 4, true)
	draw_circle(Vector2.ZERO, 4.0 if splash <= 0.0 else 6.0, color)
