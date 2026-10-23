class_name ArenaEnemy
extends Node2D

var game: Node2D
var kind := "torch"
var elite := false
var boss_phase := 0
var health := 60.0
var max_health := 60.0
var speed := 72.0
var radius := 22.0
var dead := false
var slow_time := 0.0
var attack_cooldown := 0.0
var ranged_cooldown := 0.0
var boss_core_cooldown := 0.0
var visual: ActorVisual
var hit_flash := 0.0

func center() -> Vector2:
	return position + Vector2(0, -24 if kind != "boss" else -46)

func _ready() -> void:
	visual = ActorVisual.new()
	add_child(visual)
	var family := "torch"
	var color := "Red"
	var factor := 0.76
	if kind == "shooter":
		family = "archer"
	elif kind == "charger":
		family = "torch"
		factor = 0.82
		speed = 128.0
		radius = 20.0
	elif kind == "bomber":
		family = "barrel"
		color = "Purple"
		factor = 0.92
		speed = 58.0
		radius = 24.0
	elif kind == "brute":
		family = "barrel"
		color = "Blue"
		factor = 1.08
		speed = 46.0
		radius = 32.0
	elif kind == "sapper":
		family = "tnt"
		factor = 0.85
		speed = 96.0
		radius = 20.0
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
	if elite:
		radius *= 1.3
		speed *= 0.90
		visual.scale = Vector2.ONE * 0.96
	else:
		visual.scale = Vector2.ONE * 0.78

func _physics_process(delta: float) -> void:
	if dead or not game.running or game.game_over: return
	slow_time = maxf(0.0, slow_time - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	ranged_cooldown = maxf(0.0, ranged_cooldown - delta)
	boss_core_cooldown = maxf(0.0, boss_core_cooldown - delta)
	if kind == "sapper":
		var tower: ArenaTower = game.nearest_tower(position, 620.0)
		if tower != null:
			var tower_direction := (tower.position - position).normalized()
			position += tower_direction * speed * delta
			visual.advance(delta, tower_direction * speed, tower_direction)
			if position.distance_to(tower.position) < 48.0:
				tower.health -= 32.0 * delta
				if tower.health <= 0.0:
					game.tower_destroyed(tower)
			queue_redraw()
			return
	if kind == "boss":
		if health < max_health * 0.66 and boss_phase == 0:
			boss_phase = 1
			game.boss_summon(position)
		elif health < max_health * 0.33 and boss_phase == 1:
			boss_phase = 2
			game.boss_summon(position)
	var direction: Vector2 = game.flow_at(position)
	if kind == "charger" and game.hero != null and position.distance_to(game.hero.position) < 500.0:
		direction = (game.hero.position - position).normalized()
	if direction == Vector2.ZERO:
		direction = (game.CORE - position).normalized()
	var slow_factor := 0.55 if slow_time > 0.0 else 1.0
	var core_distance := position.distance_to(game.CORE)
	var boss_holding := kind == "boss" and core_distance < 300.0
	if not boss_holding:
		position += direction * speed * slow_factor * delta
	var visual_motion := Vector2.ZERO if boss_holding else direction * speed
	visual.advance(delta, visual_motion, direction)
	if kind in ["shooter", "boss", "bomber"] and game.hero != null:
		var shot_range := 430.0 if kind == "shooter" else (520.0 if kind == "boss" else 480.0)
		if position.distance_to(game.hero.position) < shot_range and ranged_cooldown <= 0.0:
			ranged_cooldown = 1.8 if kind == "shooter" else (1.3 if kind == "boss" else 2.1)
			var shot_damage := 7.0 if kind == "shooter" else (12.0 if kind == "boss" else 10.0)
			game.enemy_shot(position + Vector2(0, -24), game.hero.center(), shot_damage, 190.0 if kind == "shooter" else (230.0 if kind == "boss" else 170.0))
	if kind == "boss":
		if core_distance < 300.0 and boss_core_cooldown <= 0.0:
			boss_core_cooldown = 1.0
			game.core_hit(20.0)
		queue_redraw()
		return
	if core_distance < 58.0:
		var leak := 28.0 if kind == "armored" else (36.0 if kind == "brute" else 14.0)
		game.core_hit(leak)
		game.enemy_escaped(self)
		dead = true
		queue_free()
		return
	if game.hero != null and game.hero.position.distance_to(position) < 34.0 and attack_cooldown <= 0.0:
		attack_cooldown = 1.0
		var contact := 10.0
		if kind == "boss": contact = 22.0
		elif kind == "brute": contact = 18.0
		elif kind == "charger": contact = 12.0
		game.hero.take_damage(contact)
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
	if elite:
		draw_arc(Vector2.ZERO, radius + 8, 0, TAU, 24, Color(1.0, 0.85, 0.4, 0.7), 3, true)
	if kind == "bomber":
		draw_arc(Vector2.ZERO, 28, 0, TAU, 20, Color(0.8, 0.55, 1.0, 0.45), 3, true)
