class_name ArenaHero
extends CharacterBody2D

var game: Node2D
var visual: ActorVisual
var health := 120.0
var max_health := 120.0
var shield := 60.0
var max_shield := 60.0
var speed := 270.0
var damage := 18.0
var aim := Vector2.RIGHT
var facing := Vector2.RIGHT
var fire_cooldown := 0.0
var skill_cooldown := 0.0
var dash_time := 0.0
var dash_direction := Vector2.RIGHT
var invulnerability := 0.0
var xp := 0
var level := 1
var xp_target := 25
var gold_gained := 0
var hurt_flash := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 13.0
	collision.shape = shape
	add_child(collision)
	visual = ActorVisual.new()
	add_child(visual)
	visual.setup("player", "Blue", 0.9, true)
	visual.held_weapon = "pistol"
	visual.hero_identity = "knight"

func center() -> Vector2:
	return position + Vector2(0, -28)

func _physics_process(delta: float) -> void:
	if not game.running or game.game_over: return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("skill") and skill_cooldown <= 0.0:
		use_skill(movement)
	if dash_time > 0.0:
		dash_time -= delta
		velocity = dash_direction * 620.0
	else:
		velocity = movement * speed
	move_and_slide()
	position = position.clamp(Vector2(50, 50), game.ARENA_SIZE - Vector2(50, 50))
	if movement.length() > 0.1:
		facing = movement.normalized()
	var target: ArenaEnemy = game.nearest_enemy(center(), 650.0)
	if target != null:
		aim = (target.position - center()).normalized()
		facing = aim
		if Input.is_action_pressed("shoot") and not game.build_mode and fire_cooldown <= 0.0:
			fire(target)
	visual.advance(delta, velocity, facing)
	queue_redraw()

func fire(target: ArenaEnemy) -> void:
	fire_cooldown = 0.28
	var direction := aim
	if is_instance_valid(target):
		direction = (target.position - center()).normalized()
		aim = direction
	game.spawn_projectile(center(), center() + direction * 800.0, damage * (1.0 + (level - 1) * 0.05), Color("9fe8e0"), 0.0, 0.0, 900.0)
	visual.attack(direction, 0.18)

func use_skill(movement: Vector2) -> void:
	skill_cooldown = 2.5
	dash_time = 0.18
	invulnerability = maxf(invulnerability, 0.24)
	dash_direction = movement.normalized() if movement.length() > 0.1 else facing
	game.hud.toast("冲刺：短暂无敌", 1)

func take_damage(amount: float) -> void:
	if invulnerability > 0.0 or game.game_over: return
	var shield_loss := minf(shield, amount)
	shield -= shield_loss
	health -= amount - shield_loss
	invulnerability = 0.35
	hurt_flash = 0.12
	game.hud.toast("受伤", 0.8)
	if health <= 0.0:
		health = 0.0
		game.hero_died()

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_target:
		xp -= xp_target
		level += 1
		xp_target += 12
		max_health += 8.0
		health = minf(max_health, health + 10.0)
		damage += 1.5
		game.hud.toast("升级 Lv.%d · 生命/伤害提升" % level, 2)

func _draw() -> void:
	draw_arc(Vector2(0, 2), 21, 0, TAU, 32, Color(0.65, 0.92, 0.82, 0.65), 1.5, true)
	if shield > 0.0:
		draw_arc(Vector2(0, -24), 31, -PI * 0.8, PI * 0.8, 28, Color(0.55, 0.85, 1.0, 0.35), 2, true)
	if hurt_flash > 0.0:
		draw_circle(Vector2(0, -28), 28, Color(1.0, 0.35, 0.3, 0.25))
