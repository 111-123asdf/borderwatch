class_name ArenaTower
extends Node2D

var game: Node2D
var kind := "bolt"
var cell := Vector2i.ZERO
var level := 1
var health := 300.0
var max_health := 300.0
var active := false
var build_clock := 2.0
var cooldown := 0.0
var aim := Vector2.LEFT
var body: Sprite2D
const MAX_LEVEL := 3

func _ready() -> void:
	var color := "Blue" if kind == "bolt" else ("Purple" if kind == "cannon" else "Yellow")
	body = Art.sprite("Factions/Knights/Buildings/Tower/Tower_%s.png" % color)
	body.scale = Vector2.ONE * 0.5
	body.position.y = -48
	add_child(body)
	health = max_health
	queue_redraw()

func attack_range() -> float:
	return (float(Rules.TOWERS[kind].range) + (level - 1) * 28.0) * (1.12 if game.hero != null and game.hero.position.distance_to(position) < 340.0 else 1.0)

func upgrade_price() -> int:
	return int(float(Rules.TOWERS[kind].cost) * (0.7 + level * 0.35))

func upgrade() -> bool:
	if level >= MAX_LEVEL or game.gold < upgrade_price(): return false
	game.gold -= upgrade_price()
	level += 1
	max_health += 60.0
	health = max_health
	game.hud.toast("塔升级到 Lv.%d" % level, 1)
	return true

func _physics_process(delta: float) -> void:
	if not game.running or game.game_over: return
	if not active:
		build_clock -= delta
		if build_clock <= 0.0:
			active = true
			game.hud.toast("塔已就绪", 1)
		queue_redraw()
		return
	cooldown = maxf(0.0, cooldown - delta)
	for enemy in game.enemies.duplicate():
		if is_instance_valid(enemy) and enemy.position.distance_to(position) < 58.0:
			health -= 16.0 * delta
			if health <= 0.0:
				game.tower_destroyed(self)
				return
	var target: ArenaEnemy = game.nearest_enemy(position, attack_range())
	if target != null and cooldown <= 0.0:
		fire(target)
	queue_redraw()

func fire(target: ArenaEnemy) -> void:
	var definition: Dictionary = Rules.TOWERS[kind]
	cooldown = float(definition.interval)
	aim = (target.position - position).normalized()
	var damage: float = float(definition.damage) * (1.0 + (level - 1) * 0.5)
	var splash := 0.0
	var slow := 0.0
	if kind == "cannon": splash = 64.0
	if kind == "frost": slow = 2.6
	game.spawn_projectile(position + Vector2(0, -84), target.position, damage, definition.color, splash, slow, 700.0)

func _draw() -> void:
	var color: Color = Rules.TOWERS[kind].color
	draw_arc(Vector2(0, 2), 24, 0, TAU, 28, Color(color, 0.55), 2, true)
	draw_line(Vector2(0, -84), Vector2(0, -84) + aim * 20, Color(color, 0.9), 5, true)
	if not active:
		draw_arc(Vector2(0, -20), 24, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - build_clock / 2.0), 24, Color(0.95, 0.85, 0.5, 0.8), 3, true)
	if health < max_health:
		draw_rect(Rect2(-22, -112, 44, 5), Color("2a2324"))
		draw_rect(Rect2(-22, -112, 44 * maxf(0.0, health / max_health), 5), Color("e0937d"))
	if game.build_mode:
		draw_arc(Vector2.ZERO, attack_range(), 0, TAU, 48, Color(0.6, 0.9, 0.8, 0.28), 2, true)
