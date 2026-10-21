class_name Tower
extends StaticBody2D

var game: Node2D
const MAX_LEVEL := 4
var kind := "bolt"
var level := 1
var cooldown := 0.3
var invested := 0
var body: Sprite2D
var turret: Node2D
var aim := Vector2.LEFT
var recoil := 0.0
var pulse := 0.0
var boosted := false
var in_aura := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	invested = int(Rules.TOWERS[kind].cost)
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 23
	collision.shape = shape
	add_child(collision)
	var color := "Blue" if kind == "bolt" else ("Purple" if kind == "cannon" else "Yellow")
	body = Art.sprite("Factions/Knights/Buildings/Tower/Tower_%s.png" % color)
	body.scale = Vector2.ONE * 0.5
	body.position.y = -48
	add_child(body)
	turret = load("res://scripts/turret_visual.gd").new()
	turret.kind = kind
	turret.position = Vector2(0, -84)
	add_child(turret)

func center() -> Vector2:
	return position + Vector2(0, -55)

func attack_origin() -> Vector2:
	return position + Vector2(0, -84)

func attack_range() -> float:
	var bonus := 1.10 if in_aura else 1.0
	return (float(Rules.TOWERS[kind].range) + (level - 1) * 30) * bonus

func aura_radius() -> float:
	return 340.0 + 80.0 * game.rank("architect")

func _physics_process(delta: float) -> void:
	if not game.running: return
	in_aura = game.hero.respawn_time <= 0 and game.hero.position.distance_to(position) <= aura_radius()
	boosted = in_aura
	cooldown -= delta * (1.15 if in_aura else 1.0)
	recoil = maxf(0, recoil - delta * (5 if kind == "cannon" else 9))
	pulse += delta
	var target: Enemy = game.leading_enemy(position, attack_range())
	if target != null:
		var speed := 570.0 if kind == "cannon" else 780.0
		var flight := attack_origin().distance_to(target.center()) / speed
		var predicted := target.center() + target.motion * flight
		aim = (predicted - attack_origin()).normalized()
		if cooldown <= 0: shoot(aim)
	turret.rotation = aim.angle() if kind != "frost" else 0.0
	turret.position = Vector2(0, -84) - aim * recoil * 8
	body.scale = Vector2(0.5 + recoil * 0.008, 0.5 - recoil * 0.008)
	queue_redraw()

func shoot(direction: Vector2) -> void:
	var definition: Dictionary = Rules.TOWERS[kind]
	var aura_bonus := 1.0
	if in_aura: aura_bonus = 1.30
	var damage: float = float(definition.damage) * (1 + (level - 1) * 0.55) * aura_bonus * (1.0 + Rules.CAMP_TOWER_BONUS * game.cleared_count()) * game.tower_damage_scale()
	cooldown = float(definition.interval)
	recoil = 1
	var bullet: Projectile = game.fire_projectile(attack_origin() + direction * 20, direction, damage, kind, false)
	if kind == "bolt" and level >= 3: bullet.pierce = 1
	if kind == "cannon":
		bullet.splash += (level - 1) * 15
		game.spark(attack_origin() + direction * 34, direction * 120, Color("ffdc9b"), 0.12, 14)
		game.sound.play("boom", 12)
	else: game.sound.play("shoot", 14)
	game.spark(attack_origin() + direction * 28, direction * 100, definition.color, 0.1, 8)

## 升级按「造价 × 递增比例」计价：升满一座的代价明显高于再建一座，
## 金币因此永远不够把全场拉满，构成「铺开 vs 深挖」的取舍。
func upgrade_price() -> int:
	var price: float = float(Rules.TOWERS[kind].cost) * (0.65 + level * 0.35)
	if game.rank("hold") > 0: price *= 0.7
	return int(price)

func upgrade() -> bool:
	if level >= MAX_LEVEL or game.gold < upgrade_price(): return false
	var price := upgrade_price()
	game.gold -= price
	invested += price
	level += 1
	game.burst(center(), Color("f8d997"), 18)
	game.sound.play("build")
	return true

func _draw() -> void:
	var color: Color = Rules.TOWERS[kind].color
	draw_arc(Vector2(0, 2), 28, 0, TAU, 32, Color(color, 0.6), 2, true)
	for pip in range(level): draw_circle(Vector2((pip - (level - 1) * 0.5) * 8, 10), 2.5, color)
	if boosted:
		draw_arc(Vector2(0, 1), 36 + sin(pulse * 4) * 2, 0, TAU, 40, Color("9ce6dc"), 2, true)
