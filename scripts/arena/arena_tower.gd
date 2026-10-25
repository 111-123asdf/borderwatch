class_name ArenaTower
extends Node2D

const STATS := {
	"bolt": {"name": "巡林弩塔", "cost": 70, "damage": 22.0, "interval": 0.55, "range": 340.0, "color": Color("edc76c"), "role": "单体持续", "trait": "高攻速弩箭，升级增加穿透与齐射"},
	"cannon": {"name": "星火重炮", "cost": 110, "damage": 40.0, "interval": 1.25, "range": 380.0, "color": Color("ff9d65"), "role": "群体爆发", "trait": "抛射爆炸，Lv3 附加减速"},
	"frost": {"name": "寒霜哨塔", "cost": 90, "damage": 10.0, "interval": 0.8, "range": 320.0, "color": Color("87dfeb"), "role": "控场", "trait": "范围霜爆，叠冻气冻结"},
	"arc": {"name": "鸣雷弧塔", "cost": 120, "damage": 28.0, "interval": 1.05, "range": 360.0, "color": Color("ffe36e"), "role": "连锁", "trait": "直接弹射多名敌人，升级加跳数"},
	"venom": {"name": "腐毒藤塔", "cost": 100, "damage": 14.0, "interval": 0.9, "range": 330.0, "color": Color("9fe86e"), "role": "持续伤害", "trait": "毒云范围中毒，适合高血精英"},
	"laser": {"name": "曜光棱塔", "cost": 140, "damage": 15.0, "interval": 0.28, "range": 360.0, "color": Color("ffb36e"), "role": "穿透直线", "trait": "瞬时光束贯穿直线上的敌人"},
	"banner": {"name": "战地号令", "cost": 85, "damage": 0.0, "interval": 1.0, "range": 260.0, "color": Color("ff9fb0"), "role": "支援", "trait": "不攻击，光环提高附近塔伤害"},
}
const TOWER_ORDER := ["bolt", "cannon", "frost", "arc", "venom", "laser", "banner"]
const MAX_LEVEL := 3
const TARGET_MODES := ["nearest", "strongest", "first"]
const TARGET_LABELS := {"nearest": "最近", "strongest": "最强", "first": "最前"}
const TARGET_HINTS := {"nearest": "优先打离塔最近的敌人", "strongest": "优先打当前生命最高的敌人", "first": "优先打离核心最近的敌人"}

var game: Node2D
var kind := "bolt"
var cell := Vector2i.ZERO
var level := 1
var health := 320.0
var max_health := 320.0
var active := false
var build_clock := 2.0
var cooldown := 0.0
var aim := Vector2.LEFT
var target_mode := "nearest"
var body: Sprite2D
var shots_fired := 0

func _ready() -> void:
	var color := "Blue"
	match kind:
		"cannon", "venom": color = "Purple"
		"frost", "banner": color = "Yellow"
		"arc", "laser": color = "Red"
	body = Art.sprite("Factions/Knights/Buildings/Tower/Tower_%s.png" % color)
	body.scale = Vector2.ONE * 0.5
	body.position.y = -48
	add_child(body)
	health = max_health
	if kind == "banner":
		active = true
		build_clock = 0.0
	queue_redraw()

func attack_range() -> float:
	var range_bonus := 0.0
	if kind == "frost" and game.hero != null:
		range_bonus = 15.0 * int(game.hero.passives.get("tower_frost", 0))
	return (float(STATS[kind].range) + (level - 1) * 22.0 + range_bonus) * (1.12 if game.hero != null and game.hero.position.distance_to(position) < 340.0 else 1.0) + game.tower_global_range_bonus()

func attack_interval() -> float:
	var level_speed := 1.0 + 0.08 * (level - 1)
	return float(STATS[kind].interval) / (game.tower_attack_speed_scale(kind, position) * level_speed)

func sell_value() -> int:
	return int(float(STATS[kind].cost) * 0.6 * (1.0 + 0.25 * (level - 1)))

func upgrade_price() -> int:
	return int(float(STATS[kind].cost) * (0.55 + level * 0.25) * game.upgrade_scale() * game.tower_cost_scale())

func next_upgrade_text() -> String:
	if level >= MAX_LEVEL: return "已满级"
	match kind:
		"bolt": return "下一级：伤害提高，穿透 +1"
		"cannon": return "下一级：伤害/溅射提高" if level < 2 else "下一级：溅射提高，附加减速"
		"frost": return "下一级：伤害提高，减速 +0.5 秒"
		"arc": return "下一级：伤害提高，弹射 +1"
		"venom": return "下一级：中毒伤害提高"
		"laser": return "下一级：伤害提高，穿透 +1"
		"banner": return "下一级：光环强度提高"
	return "下一级：属性提高"

func upgrade() -> bool:
	if level >= MAX_LEVEL or game.gold < upgrade_price(): return false
	game.gold -= upgrade_price()
	level += 1
	max_health += 50.0
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
	if kind == "banner":
		queue_redraw()
		return
	cooldown = maxf(0.0, cooldown - delta)
	for enemy in game.enemies.duplicate():
		if is_instance_valid(enemy) and enemy.position.distance_to(position) < 72.0:
			var contact_damage := 13.0
			if game.hero.passives.has("tower_fortress"):
				contact_damage *= 0.75
			health -= contact_damage * delta
			if health <= 0.0:
				game.tower_destroyed(self)
				return
	var target: ArenaEnemy = game.tower_target(self)
	if target != null and cooldown <= 0.0:
		fire(target)
	queue_redraw()

func fire(target: ArenaEnemy) -> void:
	var definition: Dictionary = STATS[kind]
	cooldown = attack_interval()
	aim = (target.position - position).normalized()
	if kind == "banner":
		return
	var damage: float = float(definition.damage) * (1.0 + (level - 1) * 0.6) * game.tower_damage_scale() * game.tower_conditional_damage(self)
	var splash := 0.0
	var slow := 0.0
	var poison := 0.0
	var pierce := 0
	var speed := 700.0
	if kind == "bolt":
		pierce = level - 1
		speed = 900.0
	if kind == "cannon":
		damage *= 1.0 + 0.15 * int(game.hero.passives.get("tower_cannon", 0))
		splash = 68.0 + 8.0 * int(game.hero.passives.get("tower_cannon", 0)) + (level - 1) * 18.0
		if level >= 3: slow = 1.2
	if kind == "frost":
		slow = 2.6 + 0.5 * int(game.hero.passives.get("tower_frost", 0)) + (level - 1) * 0.5
		if game.hero.passives.has("tower_winter"):
			slow += 1.5
			damage *= 1.15
		game.frost_nova(target.position, 74.0 + 12.0 * level, damage, slow)
		return
	if kind == "arc":
		var jumps := 2 + level + int(game.hero.passives.get("tower_arc", 0))
		if game.hero.passives.has("tower_arc"):
			damage *= 1.0 + 0.15 * int(game.hero.passives.get("tower_arc", 0))
		game.chain_strike(position, damage, jumps)
		return
	if kind == "venom":
		poison = (6.0 + 4.0 * level) * (1.0 + 0.15 * int(game.hero.passives.get("tower_venom", 0)))
		game.poison_cloud(target.position, 82.0 + 10.0 * level, damage, poison)
		return
	if kind == "laser":
		pierce = 1 + level
		speed = 1200.0
		damage *= 1.0 + 0.10 * int(game.hero.passives.get("tower_laser", 0))
		game.beam_damage(position + Vector2(0, -84), target.position, damage, 18.0 + level * 3.0)
		return
	shots_fired += 1
	if game.hero.passives.has("tower_overclock") and shots_fired % 5 == 0:
		damage *= 2.0
		if kind == "cannon": splash += 20.0
	if kind == "bolt":
		var shots := level
		for index in range(shots):
			var offset := (index - (shots - 1) * 0.5) * 12.0
			game.spawn_projectile(position + Vector2(0, -84) + aim.orthogonal() * offset, target.position + aim.orthogonal() * offset, damage * (0.85 if shots > 1 else 1.0), definition.color, 0.0, 0.0, speed, pierce, 0.0, 0.0, false, 0.35, false, 0.0)
		return
	game.spawn_projectile(position + Vector2(0, -84), target.position, damage, definition.color, splash, slow, speed, pierce, 0.0, 0.0, false, 0.35, false, poison)

func _draw() -> void:
	var color: Color = STATS[kind].color
	if kind == "banner":
		draw_arc(Vector2.ZERO, attack_range(), 0, TAU, 48, Color(color, 0.18), 3, true)
	draw_arc(Vector2(0, 2), 24, 0, TAU, 28, Color(color, 0.55), 2, true)
	draw_line(Vector2(0, -84), Vector2(0, -84) + aim * 20, Color(color, 0.9), 5, true)
	if not active:
		draw_arc(Vector2(0, -20), 24, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - build_clock / 2.0), 24, Color(0.95, 0.85, 0.5, 0.8), 3, true)
	if health < max_health:
		draw_rect(Rect2(-22, -112, 44, 5), Color("2a2324"))
		draw_rect(Rect2(-22, -112, 44 * maxf(0.0, health / max_health), 5), Color("e0937d"))
	if game.build_mode:
		draw_arc(Vector2.ZERO, attack_range(), 0, TAU, 48, Color(0.6, 0.9, 0.8, 0.28), 2, true)
