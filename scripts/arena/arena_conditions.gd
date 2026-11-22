class_name ArenaConditions
extends RefCounted

const MAX_RANK := 2
const SOLDIER_RADIUS := 120.0
const RARITIES := {"common": 60.0, "rare": 30.0, "epic": 10.0}
const ICONS := {
	"hunter":"farsight", "opener":"focus", "execute":"execute", "slayer":"executioner", "breaker":"pierce", "pursuit":"shadowstep",
	"desperate":"bloodrage", "bloodprice":"lifesteal", "composure":"tough", "fresh":"revive", "lonewolf":"unyield", "phalanx":"command",
	"stillwater":"frostheart", "rapids":"rapid", "snapstop":"reflect", "glass":"starcore", "heavyhand":"power", "gamble":"overload", "berserk":"combo", "turtle":"ironwall",
}
const CARDS := {
	"hunter": {"name":"猎手", "type":"敌人状态", "rarity":"common", "desc":["对生命 ≥99% 的敌人伤害 +20%", "对生命 ≥99% 的敌人伤害 +30%"]},
	"opener": {"name":"先手", "type":"敌人状态", "rarity":"common", "desc":["对生命 ≥99% 的敌人暴击率 +20%", "对生命 ≥99% 的敌人暴击率 +30%"]},
	"execute": {"name":"处决", "type":"敌人状态", "rarity":"rare", "desc":["对生命 ≤30% 的敌人伤害 +35%", "对生命 ≤40% 的敌人伤害 +40%"]},
	"slayer": {"name":"猎首", "type":"敌人状态", "rarity":"rare", "desc":["对精英和首领伤害 +20%，对普通敌人 −8%", "对精英和首领伤害 +30%，对普通敌人 −8%"]},
	"breaker": {"name":"破防", "type":"敌人状态", "rarity":"common", "desc":["对高防敌人伤害 +20%", "对高防敌人伤害 +30%"]},
	"pursuit": {"name":"追猎", "type":"敌人状态", "rarity":"common", "desc":["对移动中的敌人伤害 +10%", "对移动中的敌人伤害 +15%"]},
	"desperate": {"name":"背水", "type":"自身状态", "rarity":"rare", "desc":["自身生命 <40% 时伤害 +30%", "自身生命 <50% 时伤害 +40%"]},
	"bloodprice": {"name":"血偿", "type":"自身状态", "rarity":"common", "desc":["每损失 10% 生命，伤害 +3%", "每损失 10% 生命，伤害 +4%"]},
	"composure": {"name":"从容", "type":"自身状态", "rarity":"common", "desc":["自身生命 ≥99% 时伤害 +12%", "自身生命 ≥99% 时伤害 +15%"]},
	"fresh": {"name":"意气", "type":"自身状态", "rarity":"common", "desc":["自身生命 ≥99% 时移速 +12%", "自身生命 ≥99% 时移速 +18%"]},
	"lonewolf": {"name":"孤狼", "type":"自身状态", "rarity":"common", "desc":["120 范围内无士兵时伤害 +15%", "120 范围内无士兵时伤害 +22%"]},
	"phalanx": {"name":"并肩", "type":"自身状态", "rarity":"rare", "desc":["减伤 5%，120 范围内有至少 2 名士兵时升至 12%", "减伤 8%，120 范围内有至少 2 名士兵时升至 18%"]},
	"stillwater": {"name":"静水", "type":"姿态", "rarity":"common", "desc":["站定 1.5 秒后暴击率 +20%", "站定 1.5 秒后暴击率 +30%"]},
	"rapids": {"name":"急流", "type":"姿态", "rarity":"rare", "desc":["连续移动 2 秒后蓄势，下一击伤害 +30%", "连续移动 2 秒后蓄势，下一击伤害 +40%"]},
	"snapstop": {"name":"急停", "type":"姿态", "rarity":"rare", "desc":["停下后 0.2 秒内出手，下一击伤害 +35%", "停下后 0.3 秒内出手，下一击伤害 +40%"]},
	"glass": {"name":"玻璃", "type":"交换", "rarity":"epic", "desc":["伤害 +30%，最大生命 −25%", "伤害 +40%，最大生命 −30%"]},
	"heavyhand": {"name":"重手", "type":"交换", "rarity":"common", "desc":["伤害 +25%，攻速 −15%", "伤害 +35%，攻速 −15%"]},
	"gamble": {"name":"孤注", "type":"交换", "rarity":"rare", "desc":["暴击率 +20%，暴击伤害 +50%，非暴击伤害 −20%", "暴击率 +25%，暴击伤害 +50%，非暴击伤害 −20%"]},
	"berserk": {"name":"狂战", "type":"交换", "rarity":"common", "desc":["攻速 +30%，伤害 −20%", "攻速 +40%，伤害 −25%"]},
	"turtle": {"name":"死守", "type":"姿态", "rarity":"rare", "desc":["站定 3 秒后伤害 +50%", "站定 3 秒后伤害 +65%"]},
}

var ranks: Dictionary
var still_time := 0.0
var move_time := 0.0
var stop_age := INF
var nearby_soldiers := 0
var soldier_scan := 0.0
var was_moving := false
var rapids_token := 0
var rapids_used := 0
var stop_token := 0
var stop_used := 0

func _init(selected_ranks: Dictionary) -> void:
	ranks = selected_ranks

static func icon(id: String) -> Texture2D:
	return ArenaMenuArt.perk(str(ICONS.get(id,"")))

static func draw(rng: RandomNumberGenerator, selected_ranks: Dictionary, count: int, exclude: Array[String] = []) -> Array[String]:
	var pools := {"common": [], "rare": [], "epic": []}
	for id in CARDS:
		if int(selected_ranks.get(id, 0)) < MAX_RANK and id not in exclude:
			pools[CARDS[id].rarity].append(id)
	var result: Array[String] = []
	while result.size() < count:
		var total := 0.0
		for rarity in RARITIES:
			if not pools[rarity].is_empty(): total += float(RARITIES[rarity])
		if total <= 0.0: break
		var roll := rng.randf() * total
		for rarity in RARITIES:
			var pool: Array = pools[rarity]
			if pool.is_empty(): continue
			roll -= float(RARITIES[rarity])
			if roll <= 0.0:
				result.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
				break
	return result

func rank(id: String) -> int:
	return int(ranks.get(id, 0))

func value(id: String, first: float, second: float) -> float:
	var tier := rank(id)
	if tier == 0: return 0.0
	return first if tier == 1 else second

static func high_defence(enemy: Node2D, damage_type: int) -> bool:
	var defence: float = enemy.data.armour if damage_type == ArenaCombat.Type.PHYSICAL else enemy.data.resistance
	return defence >= 0.4

func update_movement(delta: float, input_speed: float, rolling: bool, wants_move := false, action_displaces := false) -> void:
	stop_age += delta
	if rolling:
		still_time = 0.0
		return
	if wants_move and action_displaces:
		return
	if input_speed > 10.0:
		still_time = 0.0
		stop_age = INF
		was_moving = true
		var previous := move_time
		move_time += delta
		if rank("rapids") > 0 and previous < 2.0 and move_time >= 2.0 and rapids_token == rapids_used:
			rapids_token += 1
	else:
		move_time = 0.0
		if input_speed < 5.0:
			still_time += delta
			if was_moving:
				was_moving = false
				if not wants_move:
					stop_token += 1
					stop_age = 0.0
		else:
			still_time = 0.0

func reset_stance() -> void:
	still_time=0.0
	move_time=0.0
	was_moving=false
	stop_age=INF

func scan_soldiers(origin: Vector2, soldiers: Array, delta: float) -> void:
	if rank("lonewolf") == 0 and rank("phalanx") == 0: return
	soldier_scan -= delta
	if soldier_scan > 0.0: return
	soldier_scan = 0.1
	nearby_soldiers = 0
	for soldier in soldiers:
		if is_instance_valid(soldier) and not soldier.dead and origin.distance_squared_to(soldier.position) <= SOLDIER_RADIUS * SOLDIER_RADIUS:
			nearby_soldiers += 1

func rapids_ready() -> bool:
	return rapids_token > rapids_used

func snapstop_ready() -> bool:
	return rank("snapstop") > 0 and stop_token > stop_used and stop_age <= value("snapstop", 0.2, 0.3)

func attack_context() -> Dictionary:
	# Pin the input window at the start of the action. Consume it only on a hit.
	return {"rapids": rapids_token if rapids_ready() else 0, "snapstop": stop_token if snapstop_ready() else 0, "priming_checked": false}

func move_bonus(health_ratio: float) -> float:
	return value("fresh", 0.12, 0.18) if health_ratio >= 0.99 else 0.0

func attack_speed_bonus() -> float:
	return clampf(value("berserk", 0.30, 0.40) + value("heavyhand", -0.15, -0.15), -0.40, 0.40)

func max_health_bonus() -> float:
	return value("glass", -0.25, -0.30)

func reduction() -> float:
	return value("phalanx", 0.12, 0.18) if nearby_soldiers >= 2 else value("phalanx", 0.05, 0.08)

func enemy_hp_threshold() -> float:
	return value("execute", 0.30, 0.40)

func hero_hp_threshold() -> float:
	return value("desperate", 0.40, 0.50)

func resolve_hit(enemy: Node2D, defence_type: int, hp: float, max_hp: float, context: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var damage := 0.0
	var chance := value("gamble", 0.20, 0.25)
	var icons: Array[String] = []
	if enemy.health >= enemy.max_health * 0.99:
		damage += value("hunter", 0.20, 0.30)
		chance += value("opener", 0.20, 0.30)
		if rank("hunter") > 0: icons.append("hunter")
		if rank("opener") > 0: icons.append("opener")
	if rank("execute") > 0 and enemy.health <= enemy.max_health * enemy_hp_threshold():
		damage += value("execute", 0.35, 0.40)
		icons.append("execute")
	if rank("slayer") > 0:
		damage += value("slayer", 0.20, 0.30) if enemy.elite or enemy.is_boss() else -0.08
		icons.append("slayer")
	if rank("breaker") > 0 and high_defence(enemy, defence_type):
		damage += value("breaker", 0.20, 0.30)
		icons.append("breaker")
	if rank("pursuit") > 0 and enemy.movement_speed > 10.0:
		damage += value("pursuit", 0.10, 0.15)
		icons.append("pursuit")
	if rank("desperate") > 0 and hp < max_hp * hero_hp_threshold():
		damage += value("desperate", 0.30, 0.40)
		icons.append("desperate")
	var missing_steps := clampi(floori((max_hp - hp) * 10.0 / max_hp), 0, 10)
	if rank("bloodprice") > 0 and missing_steps > 0:
		damage += float(missing_steps) * value("bloodprice", 0.03, 0.04)
		icons.append("bloodprice")
	if rank("composure") > 0 and hp >= max_hp * 0.99:
		damage += value("composure", 0.12, 0.15)
		icons.append("composure")
	if rank("lonewolf") > 0 and nearby_soldiers == 0:
		damage += value("lonewolf", 0.15, 0.22)
		icons.append("lonewolf")
	if still_time >= 1.5 and rank("stillwater") > 0:
		chance += value("stillwater", 0.20, 0.30)
		icons.append("stillwater")
	if still_time >= 3.0 and rank("turtle") > 0:
		damage += value("turtle", 0.50, 0.65)
		icons.append("turtle")
	damage += value("glass", 0.30, 0.40) + value("heavyhand", 0.25, 0.35) + value("berserk", -0.20, -0.25)
	for id in ["glass", "heavyhand", "berserk", "gamble"]:
		if rank(id) > 0: icons.append(id)
	if not bool(context.priming_checked):
		context.priming_checked = true
		if int(context.rapids) > rapids_used:
			rapids_used = int(context.rapids)
			damage += value("rapids", 0.30, 0.40)
			icons.append("rapids")
		if int(context.snapstop) > stop_used:
			stop_used = int(context.snapstop)
			damage += value("snapstop", 0.35, 0.40)
			icons.append("snapstop")
	var critical := chance > 0.0 and rng.randf() < minf(0.40, chance)
	if not critical: damage += value("gamble", -0.20, -0.20)
	var multiplier := 1.0 + minf(0.80, damage)
	if critical: multiplier *= 1.50 + value("gamble", 0.50, 0.50)
	return {"multiplier": multiplier, "bonus": minf(0.80, damage), "crit": critical, "capped": damage > 0.80, "icons": icons}
