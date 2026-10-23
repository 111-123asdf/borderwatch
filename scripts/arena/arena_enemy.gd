class_name ArenaEnemy
extends Node2D

var game: Node2D
var kind := "torch"
var health := 60.0
var max_health := 60.0
var speed := 72.0
var radius := 22.0
var dead := false
var slow_time := 0.0
var attack_cooldown := 0.0
var visual: ActorVisual
var hit_flash := 0.0

func _ready() -> void:
	visual = ActorVisual.new()
	add_child(visual)
	var family := "torch"
	var color := "Red"
	var factor := 0.76
	if kind == "shooter":
		family = "archer"
	elif kind == "barrel":
		family = "barrel"
		factor = 0.95
	elif kind == "shielded":
		family = "barrel"
		color = "Purple"
		factor = 1.0
		radius = 28.0
	elif kind == "armored":
		family = "barrel"
		color = "Blue"
		factor = 0.95
		radius = 26.0
	elif kind == "boss":
		family = "barrel"
		color = "Red"
		factor = 1.25
		radius = 40.0
		speed = 36.0
	visual.setup(family, color, factor)
	visual.scale = Vector2.ONE * 0.62

func _physics_process(delta: float) -> void:
	if dead or not game.running or game.game_over: return
	slow_time = maxf(0.0, slow_time - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var direction: Vector2 = game.flow_at(position)
	if direction == Vector2.ZERO:
		direction = (game.CORE - position).normalized()
	var slow_factor := 0.55 if slow_time > 0.0 else 1.0
	position += direction * speed * slow_factor * delta
	visual.advance(delta, direction * speed, direction)
	if position.distance_to(game.CORE) < 58.0:
		game.core_hit(9999.0 if kind == "boss" else (34.0 if kind == "armored" else 16.0))
		game.enemy_escaped(self)
		dead = true
		queue_free()
		return
	if game.hero != null and game.hero.position.distance_to(position) < 34.0 and attack_cooldown <= 0.0:
		attack_cooldown = 1.0
		game.hero.take_damage(10.0 if kind != "boss" else 22.0)
	queue_redraw()

func take_damage(amount: float) -> void:
	if dead: return
	health -= amount
	hit_flash = 0.1
	visual.hit_flash = 0.1
	if health <= 0.0:
		dead = true
		game.enemy_died(self)
		queue_free()

func _draw() -> void:
	if dead: return
	var width := 42.0 if kind != "boss" else 76.0
	if health < max_health:
		draw_rect(Rect2(-width * 0.5, -44 if kind != "boss" else -70, width, 5), Color("251f21"))
		draw_rect(Rect2(-width * 0.5, -44 if kind != "boss" else -70, width * health / max_health, 5), Color("df8267"))
	if hit_flash > 0.0:
		draw_circle(Vector2.ZERO, radius + 4, Color(1.0, 0.9, 0.8, 0.3))
	if kind == "shielded":
		draw_arc(Vector2.ZERO, 30, 0, TAU, 24, Color(0.65, 0.9, 1.0, 0.45), 3, true)
	elif kind == "armored":
		draw_arc(Vector2.ZERO, 29, 0, TAU, 24, Color(0.8, 0.85, 0.9, 0.5), 4, true)
	elif kind == "boss":
		draw_arc(Vector2.ZERO, 46, 0, TAU, 32, Color(0.9, 0.45, 0.35, 0.6), 4, true)
