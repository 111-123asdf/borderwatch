class_name ArenaPassiveEngine
extends RefCounted
## Decorator & Event-Pipeline Auto-Trigger Passive Engine (v0.31).
## 14 distinct high-character passives, strict 10-pick run cap (max Lv.11),
## and automatic overflow XP -> Gold + Base Core Shield conversion.

const MAX_RANK := 3
const MAX_TOTAL_PICKS := 10
const MAX_RUN_LEVEL := 11

const PASSIVES := {
	"chain_bolt": {
		"id": "chain_bolt", "name": "奔雷", "category": "元素",
		"tagline": "普攻跃出[color=#7ef0ff]高能闪电链[/color]连击群敌",
		"evo_name": "九天雷狱", "evo_tagline": "雷链连跳6敌并[color=#ffe878]天降麻痹落雷[/color]",
		"details": ["普攻触发闪电链弹跳 2 名敌人（48% 法伤）", "弹跳 4 名敌人（66% 法伤）", "【超武·九天雷狱】弹跳 6 敌（88% 法伤）并在末目标降下麻痹雷暴"]
	},
	"frost_nova": {
		"id": "frost_nova", "name": "霜爆", "category": "元素",
		"tagline": "命中附寒霜，杀敌[color=#8ce8ff]炸裂破土冰刺[/color]",
		"evo_name": "极寒冰狱", "evo_tagline": "巨型冰刺喷涌并[color=#8ce8ff]直接冰封敌群[/color]",
		"details": ["攻击减速 26%，击杀炸开 88 范围寒冰刺簇", "攻击减速 36%，冰爆扩至 114 且伤害提升", "【超武·极寒冰狱】156 巨型破土冰刺阵并冻结敌群 1.25 秒"]
	},
	"blazing_wake": {
		"id": "blazing_wake", "name": "炽焰", "category": "元素",
		"tagline": "攻击引燃敌军，阵亡[color=#ff9848]熔岩裂焰火海[/color]",
		"evo_name": "业火燎原", "evo_tagline": "亡语爆燃[color=#ff9848]巨型滚烫熔岩火海[/color]",
		"details": ["命中灼烧每秒 18 伤，击杀留下 3 秒熔岩火区", "灼烧每秒 28 伤，熔岩半径与伤害提高", "【超武·业火燎原】灼烧每秒 44 伤，大范围 4.5 秒滚烫熔岩裂海"]
	},
	"star_meteor": {
		"id": "star_meteor", "name": "星陨", "category": "元素",
		"tagline": "暴击与连击召唤[color=#d884ff]紫金彗星轰炸[/color]",
		"evo_name": "群星坠落", "evo_tagline": "每4击必降[color=#ffe878]双倍重型陨星[/color]",
		"details": ["每 6 次命中或暴击召唤紫电彗星砸地（96 范围）", "每 5 次命中触发，陨星伤害与范围提升", "【超武·群星坠落】每 4 次命中连降双发重型紫金彗星轰炸"]
	},
	"void_bloom": {
		"id": "void_bloom", "name": "暗蚀", "category": "元素",
		"tagline": "攻击叠蚀毒，死亡[color=#c878ff]紫雾殉爆传染[/color]",
		"evo_name": "虚空连爆", "evo_tagline": "紫雾殉爆可[color=#ff88f4]连锁引爆整群怪[/color]",
		"details": ["命中附加虚空侵蚀，阵亡产生 90 范围紫雾爆破", "侵蚀增强，紫雾爆破扩至 114 范围", "【超武·虚空连爆】150 范围高伤紫雾爆破，可连续传染引爆残血敌群"]
	},
	"orbit_blades": {
		"id": "orbit_blades", "name": "旋刃", "category": "元素",
		"tagline": "周身环绕[color=#7ef0ff]符文飞刃[/color]贴身绞杀",
		"evo_name": "万刃圣轮", "evo_tagline": "4枚圣金双月圣轮[color=#ffe878]高速护体绞杀[/color]",
		"details": ["召唤 2 枚环绕青蓝符文飞刃自动切割近敌", "增至 3 枚飞刃，转速与伤害提升 35%", "【超武·万刃圣轮】4 枚圣金双月圣轮常驻绞杀并附带击退微顿"]
	},
	"gravity_well": {
		"id": "gravity_well", "name": "奇点", "category": "奇点",
		"tagline": "生成[color=#d478ff]引力黑洞漩涡[/color]聚怪后坍缩内爆",
		"evo_name": "黑洞坍缩", "evo_tagline": "巨型深渊奇点[color=#ffe878]强吸全群并二连内爆[/color]",
		"details": ["每 6 击或暴击生成 1.6s 引力黑洞吸聚 175 范围敌军", "黑洞吸聚 205 范围且结束坍缩高伤内爆", "【超武·黑洞坍缩】每 4 击生成 245 范围巨型黑洞，终结二连紫爆并眩晕敌群"]
	},
	"orbital_laser": {
		"id": "orbital_laser", "name": "星穹", "category": "星穹",
		"tagline": "周期降下追踪[color=#7ef4ff]天基圣光激光柱[/color]",
		"evo_name": "天基审判", "evo_tagline": "双道炽金天基光柱[color=#ffe878]交叉扫荡敌潮[/color]",
		"details": ["每 5.2 秒锁定密集怪群降下 1.4s 追踪星穹光柱", "冷却缩至 4.0 秒，光柱宽幅伤害与灼烧飙升", "【超武·天基审判】每 2.8 秒同降双道金青天基光柱贯穿天地扫荡"]
	},
	"phantom_slash": {
		"id": "phantom_slash", "name": "幻影", "category": "幻影",
		"tagline": "攻闪留下[color=#9cf0ff]发光残影[/color]补发穿透剑潮",
		"evo_name": "万影绝斩", "evo_tagline": "双残影高频斩波并[color=#ffe878]大幅提升暴击与移速[/color]",
		"details": ["每 3 击或闪避唤出残影补发月牙剑波，移速+8%暴击+10%", "闪避冷却-28%，残影伤害飙升，移速+14%暴击+18%", "【超武·万影绝斩】连唤双残影绝斩，暴击+28%、移速+22%、闪避冷却-42%"]
	},
	"multishot": {
		"id": "multishot", "name": "多重", "category": "裂变",
		"tagline": "普攻分裂[color=#ffe478]齐射弹幕与宽幅剑气[/color]",
		"evo_name": "万箭剑潮", "evo_tagline": "扇形多重弹幕，近战[color=#ffe478]挥出三道巨型剑波[/color]",
		"details": ["远程额外 +1 发分裂弹，近战挥出 1 道穿透剑气", "远程 +2 发分裂弹，近战双道剑气波", "【超武·万箭剑潮】远程扇形 +3 发齐射，近战挥出三道宽幅穿透剑潮"]
	},
	"ricochet": {
		"id": "ricochet", "name": "贯弹", "category": "裂变",
		"tagline": "弹道[color=#7ef0ff]穿透弹射[/color]，近战刀光扩幅",
		"evo_name": "无限折射", "evo_tagline": "弹幕连弹3次，近战[color=#ffe478]横扫范围暴涨[/color]",
		"details": ["投射物穿透 +1、弹射 +1；近战攻击范围 +16%", "穿透 +2、弹射 +2；近战范围 +30%", "【超武·无限折射】穿透 +3、弹射 +3；近战横扫范围 +48%"]
	},
	"blood_aegis": {
		"id": "blood_aegis", "name": "血铠", "category": "生息",
		"tagline": "吸血溢血化盾并[color=#7ef0ff]大幅扩大吸晶范围[/color]",
		"evo_name": "不灭血域", "evo_tagline": "近全屏磁吸晶石并[color=#ff7888]周期炸出鲜血新星[/color]",
		"details": ["杀敌回血 3% 溢出化盾，吸晶范围 +65% 经验 +10%", "杀敌回血 4.5% 盾上限 50%，吸晶 +140% 经验 +20%", "【超武·不灭血域】杀敌回血 6.5%，吸晶 +260%，每 3 秒炸出鲜血新星"]
	},
	"tower_storm": {
		"id": "tower_storm", "name": "雷塔共鸣", "category": "共鸣",
		"tagline": "回防时附近防御塔[color=#7ef0ff]共享连锁奔雷[/color]",
		"evo_name": "防线雷网", "evo_tagline": "英雄镇守防线全塔[color=#ffe878]高频劈出连锁雷网[/color]",
		"details": ["英雄在主防线时，周围防御塔 35% 概率触发闪电链", "触发概率升至 55%，雷链跳数 +1", "【超武·防线雷网】英雄在防线时全图防御塔 75% 概率劈出高伤连锁雷网"]
	},
	"tower_aegis": {
		"id": "tower_aegis", "name": "圣障共鸣", "category": "共鸣",
		"tagline": "回防震退全路并[color=#ffe478]厚补基地圣盾[/color]",
		"evo_name": "神殿金钟", "evo_tagline": "回防赋厚盾并令[color=#ffe878]全塔攻速与威力暴涨[/color]",
		"details": ["每次回防震退各路前锋并补 55 基地圣盾，全塔攻速 +8%", "回防补 95 基地圣盾，震退加强，全塔攻速 +16%", "【超武·神殿金钟】回防立补 145 圣盾，7 秒内全塔攻速 +55% 且威力 +20%"]
	}
}

const ORDER := [
	"chain_bolt", "frost_nova", "blazing_wake", "star_meteor", "void_bloom", "orbit_blades",
	"gravity_well", "orbital_laser", "phantom_slash", "multishot", "ricochet",
	"blood_aegis", "tower_storm", "tower_aegis"
]

var game: Node2D
var stacks: Dictionary = {}
var run_level: int = 1
var run_xp: float = 0.0
var pending_ups: int = 0
var picks_taken: int = 0
var overflow_xp: float = 0.0
var overflow_conversions: int = 0
var current_offers: Array[Dictionary] = []

var orbit_angle: float = 0.0
var _orbit_hit_cd: Dictionary = {}
var _blood_nova_clock: float = 3.0
var _meteor_hits: int = 0
var _gravity_hits: int = 0
var _phantom_attacks: int = 0
var _laser_clock: float = 2.6
var aegis_haste_clock: float = 0.0
var _proc_guard: int = 0

var active_wells: Array[Dictionary] = []
var active_beams: Array[Dictionary] = []
var active_phantoms: Array[Dictionary] = []


func bind(owner_game: Node2D, bus: ArenaEventBus) -> void:
	game = owner_game
	if bus == null:
		return
	bus.subscribe("hero_attack", _on_hero_attack)
	bus.subscribe("hero_hit", _on_hero_hit)
	bus.subscribe("enemy_killed", _on_enemy_killed)
	bus.subscribe("hero_dodge", _on_hero_dodge)
	bus.subscribe("tower_fire", _on_tower_fire)
	bus.subscribe("domain_recall", _on_domain_recall)


func reset() -> void:
	stacks.clear()
	run_level = 1
	run_xp = 0.0
	pending_ups = 0
	picks_taken = 0
	overflow_xp = 0.0
	overflow_conversions = 0
	current_offers.clear()
	orbit_angle = 0.0
	_orbit_hit_cd.clear()
	_blood_nova_clock = 3.0
	_meteor_hits = 0
	_gravity_hits = 0
	_phantom_attacks = 0
	_laser_clock = 2.6
	aegis_haste_clock = 0.0
	_proc_guard = 0
	active_wells.clear()
	active_beams.clear()
	active_phantoms.clear()


func can_gain_pick() -> bool:
	return (picks_taken + pending_ups) < MAX_TOTAL_PICKS and run_level < MAX_RUN_LEVEL


func is_maxed_out() -> bool:
	return picks_taken >= MAX_TOTAL_PICKS or run_level >= MAX_RUN_LEVEL


func xp_needed(lvl: int = -1) -> float:
	var lv := run_level if lvl < 1 else lvl
	return 72.0 + float(lv - 1) * 52.0 + pow(float(maxi(0, lv - 1)), 1.45) * 18.0


func rank(id: String) -> int:
	return int(stacks.get(id, 0))


func is_evo(id: String) -> bool:
	return rank(id) >= MAX_RANK


func owned_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in ORDER:
		var r := rank(id)
		if r > 0:
			var spec: Dictionary = PASSIVES[id]
			out.append({
				"id": id,
				"rank": r,
				"evo": r >= MAX_RANK,
				"name": str(spec.evo_name if r >= MAX_RANK else spec.name),
				"base_name": str(spec.name),
				"category": str(spec.category),
				"summary": str(spec.details[clampi(r - 1, 0, 2)])
			})
	return out


func add_xp(raw_amount: float) -> int:
	if raw_amount <= 0.0 or game == null or game.game_over:
		return 0
	var scaled := raw_amount * xp_gain_mult()
	if not can_gain_pick():
		_consume_overflow_xp(scaled)
		return 0
	run_xp += scaled
	var gained := 0
	while can_gain_pick() and run_xp >= xp_needed():
		run_xp -= xp_needed()
		run_level += 1
		pending_ups += 1
		gained += 1
		if is_instance_valid(game.hero) and not game.hero.knocked_out:
			game.hero._heal_self(game.hero.max_health * 0.16, true)
			game.effect(game.hero.position, 58.0, Color("ffe478"), "upgrade", 0.48)
		if game.event_bus != null:
			game.event_bus.emit_event("run_level_up", {"level": run_level, "pending": pending_ups})
	if not can_gain_pick() and run_xp > 0.0:
		_consume_overflow_xp(run_xp)
		run_xp = 0.0
	return gained


func _consume_overflow_xp(amount: float) -> void:
	overflow_xp += amount
	var converted := 0
	while overflow_xp >= 90.0:
		overflow_xp -= 90.0
		converted += 1
		overflow_conversions += 1
		game.gold += 15
		game.add_core_shield(18.0)
	if converted > 0 and is_instance_valid(game.hero):
		game.numbers.append({
			"point": game.hero.center() + Vector2(0.0, -34.0),
			"text": "满级溢出 +%d金/+%d盾!" % [converted * 15, converted * 18],
			"colour": Color("ffe678"),
			"life": 0.95,
			"duration": 0.95
		})


func grant_bonus_pick(_source_label := "秘宝") -> bool:
	if game == null or game.game_over:
		return false
	if (picks_taken + pending_ups) < MAX_TOTAL_PICKS:
		pending_ups += 1
		run_level = mini(MAX_RUN_LEVEL, run_level + 1)
		if game.event_bus != null:
			game.event_bus.emit_event("passive_ready", {"pending": pending_ups})
		return true
	game.gold += 55
	game.add_core_shield(45.0)
	overflow_conversions += 1
	return false


func draw_offers(rng: RandomNumberGenerator, count := 3) -> Array[Dictionary]:
	var pool: Array[String] = []
	for id: String in ORDER:
		if rank(id) < MAX_RANK:
			pool.append(id)
	if pool.is_empty():
		return []

	var distinct_owned := 0
	for id: String in ORDER:
		if rank(id) > 0:
			distinct_owned += 1

	var weighted: Array[String] = []
	for id: String in pool:
		var r := rank(id)
		var w := 1
		if r == 2:
			w = 4 if distinct_owned >= 3 else 3
		elif r == 1:
			w = 3 if distinct_owned >= 3 else 2
		for _k in range(w):
			weighted.append(id)

	var picked: Array[String] = []
	var safety := 0
	while picked.size() < mini(count, pool.size()) and safety < 80:
		safety += 1
		var cand: String = weighted[rng.randi_range(0, weighted.size() - 1)]
		if cand not in picked:
			picked.append(cand)
	for id: String in pool:
		if picked.size() >= mini(count, pool.size()):
			break
		if id not in picked:
			picked.append(id)

	var cards: Array[Dictionary] = []
	for id: String in picked:
		var spec: Dictionary = PASSIVES[id]
		var next_r := rank(id) + 1
		var will_evo := next_r >= MAX_RANK
		cards.append({
			"id": id,
			"name": str(spec.evo_name if will_evo else spec.name),
			"short_name": str(spec.evo_name if will_evo else spec.name),
			"base_name": str(spec.name),
			"category": str(spec.category),
			"category_tag": "★超武觉醒" if will_evo else str(spec.category),
			"next_rank": next_r,
			"will_evo": will_evo,
			"tagline": str(spec.evo_tagline if will_evo else spec.tagline),
			"detail": str(spec.details[clampi(next_r - 1, 0, 2)]),
			"all_details": (spec.details as Array).duplicate()
		})
	current_offers = cards
	return cards


func apply_choice(id: String) -> bool:
	if not PASSIVES.has(id) or rank(id) >= MAX_RANK or picks_taken >= MAX_TOTAL_PICKS:
		return false
	var nr := clampi(rank(id) + 1, 1, MAX_RANK)
	stacks[id] = nr
	picks_taken += 1
	if pending_ups > 0:
		pending_ups -= 1
	current_offers.clear()
	if is_instance_valid(game) and is_instance_valid(game.hero):
		var col := Color("ffe270") if nr >= MAX_RANK else Color("7ef0ff")
		game.effect(game.hero.position, 68.0 if nr >= MAX_RANK else 48.0, col, "upgrade", 0.52)
		if nr >= MAX_RANK:
			var evo_title := str(PASSIVES[id].evo_name)
			game.numbers.append({
				"point": game.hero.center() + Vector2(0, -40),
				"text": "★超武·" + evo_title + "!",
				"colour": Color("ffe97a"),
				"life": 1.15,
				"duration": 1.15,
				"critical": true
			})
			game.audio.play("phase", -6.0, 1.18)
	return true


# --- Stat Modifiers (Decorator Queries) ---

func hero_attack_speed_bonus() -> float:
	var r_ph := rank("phantom_slash")
	return [0.0, 0.06, 0.12, 0.22][r_ph]


func hero_move_speed_bonus() -> float:
	var r_ph := rank("phantom_slash")
	return [0.0, 0.08, 0.14, 0.22][r_ph]


func hero_crit_chance() -> float:
	var r_ph := rank("phantom_slash")
	return [0.06, 0.16, 0.24, 0.34][r_ph]


func hero_crit_mult() -> float:
	var r_ph := rank("phantom_slash")
	return [1.55, 1.70, 1.90, 2.15][r_ph]


func extra_projectiles() -> int:
	return rank("multishot")


func extra_pierce() -> int:
	return rank("ricochet")


func extra_bounce() -> int:
	return rank("ricochet")


func melee_range_scale() -> float:
	var r := rank("ricochet")
	return [1.0, 1.16, 1.30, 1.48][r]


func dodge_cd_scale() -> float:
	var r := rank("phantom_slash")
	return [1.0, 0.85, 0.72, 0.58][r]


func skill_cd_scale() -> float:
	return 1.0


func magnet_scale() -> float:
	var r := rank("blood_aegis")
	return [1.0, 1.65, 2.40, 3.60][r]


func xp_gain_mult() -> float:
	var r := rank("blood_aegis")
	var rel_mult: float = game.relic_engine.gold_xp_mult() if (game != null and game.relic_engine != null) else 1.0
	return [1.0, 1.10, 1.20, 1.32][r] * rel_mult


func max_shield_bonus_ratio() -> float:
	var r := rank("blood_aegis")
	return [0.0, 0.35, 0.50, 0.65][r]


func tower_speed_bonus() -> float:
	if game != null and game.active_domain != "defense":
		return 0.0
	var r_ta := rank("tower_aegis")
	var bonus: float = [0.0, 0.08, 0.16, 0.24][r_ta]
	if aegis_haste_clock > 0.0:
		bonus += 0.55
	return bonus


func tower_power_mult() -> float:
	if game != null and game.active_domain != "defense":
		return 1.0
	return 1.20 if (aegis_haste_clock > 0.0 and is_evo("tower_aegis")) else 1.0


func controlled_enemy_damage_mult(_enemy: Node2D) -> float:
	return 1.0


# --- Frame Tick (Orbit Blades, Gravity Wells, Orbital Lasers, Phantom Slashes, Blood Nova) ---

func tick(delta: float) -> void:
	if game == null or not game.running or game.game_over:
		return
	if aegis_haste_clock > 0.0:
		aegis_haste_clock = maxf(0.0, aegis_haste_clock - delta)
	var hero: Node2D = game.hero
	if not is_instance_valid(hero) or hero.knocked_out:
		return

	_tick_orbit_blades(delta, hero)
	_tick_gravity_wells(delta)
	_tick_orbital_lasers(delta, hero)
	_tick_phantoms(delta, hero)

	if is_evo("blood_aegis"):
		_blood_nova_clock -= delta
		if _blood_nova_clock <= 0.0:
			_blood_nova_clock = 3.0
			var nova_dmg: float = hero.attack_damage() * 1.18
			_proc_guard += 1
			game.area_damage(hero.position, 150.0, nova_dmg, 1, "hero", 0.15, 0.0, 0.2, 14.0, "blood_nova", true, {"domain": hero.domain})
			_proc_guard -= 1
			game.effect(hero.position, 142.0, Color("ff5872"), "blast", 0.30)


func _tick_orbit_blades(delta: float, hero: Node2D) -> void:
	var r_orb := rank("orbit_blades")
	if r_orb <= 0:
		return
	var spd := 3.8 if r_orb == 1 else (4.8 if r_orb == 2 else 6.4)
	orbit_angle = fmod(orbit_angle + delta * spd, TAU)
	for k in _orbit_hit_cd.keys():
		var left := float(_orbit_hit_cd[k]) - delta
		if left <= 0.0:
			_orbit_hit_cd.erase(k)
		else:
			_orbit_hit_cd[k] = left
	var blade_cnt := 2 if r_orb == 1 else (3 if r_orb == 2 else 4)
	var ring_r := 82.0 if r_orb < 3 else 102.0
	var b_dmg: float = hero.attack_damage() * [0.0, 0.56, 0.74, 0.98][r_orb]
	for b_i in range(blade_cnt):
		var ang := orbit_angle + float(b_i) * (TAU / float(blade_cnt))
		var bp: Vector2 = hero.position + Vector2(cos(ang) * ring_r, -18.0 + sin(ang) * ring_r * 0.68)
		for enemy in game.domain_enemies(hero.domain):
			if not is_instance_valid(enemy) or enemy.dead:
				continue
			var eid: int = enemy.get_instance_id()
			if _orbit_hit_cd.has(eid):
				continue
			if bp.distance_to(enemy.center()) <= enemy.radius + (26.0 if r_orb >= 3 else 20.0):
				_orbit_hit_cd[eid] = 0.26 if r_orb >= 3 else 0.36
				_proc_guard += 1
				enemy.take_hit(b_dmg, 0, "hero", 0.08 if r_orb >= 3 else 0.0, 0.0, 0.15, "orbit_blade", hero.position.direction_to(enemy.position))
				_proc_guard -= 1
				game.effect(enemy.center(), 22.0, Color("ffe678") if r_orb >= 3 else Color("7ef0ff"), "hit", 0.14)


func _tick_gravity_wells(delta: float) -> void:
	if active_wells.is_empty():
		return
	var kept: Array[Dictionary] = []
	for w in active_wells:
		w.life = float(w.life) - delta
		w.tick = float(w.tick) + delta
		var wpos := Vector2(w.pos)
		var wrad := float(w.radius)
		var wdom := str(w.domain)
		var is_evo_w := bool(w.evo)

		# Continuous gentle physical pull toward singularity center
		for enemy in game.domain_enemies(wdom):
			if not is_instance_valid(enemy) or enemy.dead:
				continue
			if enemy.is_unstoppable():
				continue
			var dist: float = enemy.position.distance_to(wpos)
			if dist <= wrad and dist > 14.0:
				var pull_spd := (210.0 if is_evo_w else 155.0) * clampf(1.0 - dist / (wrad * 1.15), 0.25, 1.0)
				var pulled: Vector2 = enemy.position.move_toward(wpos, pull_spd * delta)
				if wdom == "rift" and game.rift_domain != null:
					pulled = game.rift_domain.clamp_mob_to_room(pulled, str(enemy.get("rift_room_id")))
				elif wdom == "defense" and not game.walkable(pulled):
					continue
				enemy.position = pulled
				enemy.chill(0.28, 0.35)

		if float(w.tick) >= 0.32:
			w.tick = 0.0
			_proc_guard += 1
			game.area_damage(wpos, wrad * 0.72, float(w.damage) * 0.26, 1, "hero", 0.0, 0.0, 0.18, 0.0, "gravity_tick", true, {"domain": wdom, "passive_proc": true})
			_proc_guard -= 1

		if float(w.life) <= 0.0:
			# Collapse Implosion!
			_proc_guard += 1
			game.area_damage(wpos, wrad * 0.88, float(w.damage) * (1.55 if is_evo_w else 1.10), 1, "hero", 0.45 if is_evo_w else 0.20, 0.0, 0.25, 0.0, "gravity_burst", true, {"domain": wdom, "passive_proc": true})
			if is_evo_w:
				game.delayed_attack(wpos, wrad * 0.96, float(w.damage) * 1.15, 1, "hero", 0.24, {"fx_kind": "void_warp", "fx_color": Color("d878ff"), "stun": 0.40, "domain": wdom})
			_proc_guard -= 1
			game.effect(wpos, wrad * 0.85, Color("d878ff"), "blackhole_burst", 0.34)
			game.audio.play("heavy_hit", -11.0, 0.88)
		else:
			kept.append(w)
	active_wells = kept


func _tick_orbital_lasers(delta: float, hero: Node2D) -> void:
	var r_ol := rank("orbital_laser")
	if r_ol > 0:
		_laser_clock -= delta
		if _laser_clock <= 0.0:
			var cd := float([99.0, 5.2, 4.0, 2.8][r_ol])
			_laser_clock = cd
			var dom: String = hero.domain
			var enemies: Array = game.domain_enemies(dom)
			if not enemies.is_empty():
				var cnt := 2 if r_ol >= 3 else 1
				var used_pos: Array[Vector2] = []
				for b_i in range(cnt):
					var best_e := _pick_cluster_target(enemies, hero.position, used_pos)
					if best_e != null:
						used_pos.append(best_e.position)
						active_beams.append({
							"pos": best_e.position,
							"target": best_e,
							"life": 1.45,
							"duration": 1.45,
							"tick": 0.0,
							"radius": 62.0 if r_ol < 3 else 78.0,
							"damage": hero.attack_damage() * [0.0, 0.48, 0.66, 0.88][r_ol],
							"domain": dom,
							"evo": r_ol >= 3
						})
						game.audio.play("phase", -11.0, 1.38)

	if active_beams.is_empty():
		return
	var kept_b: Array[Dictionary] = []
	for bm in active_beams:
		bm.life = float(bm.life) - delta
		bm.tick = float(bm.tick) + delta
		var tgt_raw: Variant = bm.get("target")
		if is_instance_valid(tgt_raw) and tgt_raw is Node2D:
			var tgt := tgt_raw as Node2D
			if not tgt.dead and str(tgt.domain) == str(bm.domain):
				bm.pos = Vector2(bm.pos).move_toward(tgt.position, 145.0 * delta)
		else:
			bm["target"] = null
		if float(bm.tick) >= 0.22:
			bm.tick = 0.0
			_proc_guard += 1
			game.area_damage(Vector2(bm.pos), float(bm.radius), float(bm.damage), 1, "hero", 0.05, 0.0, 0.25, 0.0, "orbital_beam", true, {"domain": str(bm.domain), "passive_proc": true})
			_proc_guard -= 1
		if float(bm.life) > 0.0:
			kept_b.append(bm)
	active_beams = kept_b


func _pick_cluster_target(enemies: Array, fallback_center: Vector2, avoid: Array[Vector2]) -> Node2D:
	var best: Node2D = null
	var best_score := -1.0
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var too_close := false
		for av in avoid:
			if e.position.distance_to(av) < 95.0:
				too_close = true
				break
		if too_close and avoid.size() < enemies.size():
			continue
		var score := 1.0
		for other in enemies:
			if is_instance_valid(other) and not other.dead and other.position.distance_to(e.position) <= 130.0:
				score += 1.0
		if e.position.distance_to(fallback_center) <= 440.0:
			score += 1.5
		if score > best_score:
			best_score = score
			best = e
	return best


func _tick_phantoms(delta: float, _hero: Node2D) -> void:
	if active_phantoms.is_empty():
		return
	var kept_p: Array[Dictionary] = []
	for ph in active_phantoms:
		ph.life = float(ph.life) - delta
		if not bool(ph.fired) and float(ph.life) <= float(ph.duration) - 0.16:
			ph.fired = true
			var origin := Vector2(ph.pos) + Vector2(0.0, -24.0)
			var dir := Vector2(ph.dir)
			var dom := str(ph.domain)
			var dmg := float(ph.damage)
			_proc_guard += 1
			game.fire_projectile(origin, origin + dir * 380.0, dmg, 1, "hero", {
				"speed": 780.0,
				"pierce": 4,
				"bounce": 0,
				"appearance": "sword_wave",
				"feedback": "slash",
				"domain": dom,
				"condition_hit": {"passive_proc": true}
			})
			_proc_guard -= 1
			game.effect(origin + dir * 32.0, 48.0, Color("9ef4ff"), "slash", 0.18, dir)
		if float(ph.life) > 0.0:
			kept_p.append(ph)
	active_phantoms = kept_p


func _spawn_phantom(origin_pos: Vector2, dir: Vector2, dom: String, hero: ArenaHero) -> void:
	var r_ph := rank("phantom_slash")
	if r_ph <= 0 or active_phantoms.size() >= 6:
		return
	var mult: float = [0.0, 0.72, 0.95, 1.25][r_ph]
	var cnt := 2 if r_ph >= 3 else 1
	for i in range(cnt):
		var spread := 0.0 if cnt == 1 else (0.24 if i == 0 else -0.24)
		var off := dir.orthogonal() * (float(i) * 26.0 - 13.0) if cnt == 2 else Vector2.ZERO
		active_phantoms.append({
			"pos": origin_pos + off,
			"dir": dir.rotated(spread).normalized(),
			"life": 0.42,
			"duration": 0.42,
			"damage": hero.attack_damage() * mult,
			"domain": dom,
			"fired": false,
			"class_id": hero.class_id
		})


func blade_positions(hero_pos: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var r_orb := rank("orbit_blades")
	if r_orb <= 0:
		return out
	var blade_cnt := 2 if r_orb == 1 else (3 if r_orb == 2 else 4)
	var ring_r := 82.0 if r_orb < 3 else 102.0
	for b_i in range(blade_cnt):
		var ang := orbit_angle + float(b_i) * (TAU / float(blade_cnt))
		out.append(hero_pos + Vector2(cos(ang) * ring_r, -18.0 + sin(ang) * ring_r * 0.68))
	return out


# --- Event Hooks ---

func _on_hero_attack(payload: Dictionary) -> void:
	if game == null or not is_instance_valid(game.hero):
		return
	var hero: ArenaHero = game.hero
	var origin: Vector2 = payload.get("origin", hero.center())
	var dir: Vector2 = payload.get("direction", hero.facing)
	if dir.is_zero_approx():
		dir = Vector2.RIGHT
	var base_dmg: float = float(payload.get("damage", hero.attack_damage()))
	var is_melee: bool = bool(payload.get("melee", false))
	var dom: String = str(payload.get("domain", hero.domain))

	var r_ph := rank("phantom_slash")
	if r_ph > 0:
		_phantom_attacks += 1
		if _phantom_attacks >= 3:
			_phantom_attacks = 0
			_spawn_phantom(hero.position, dir, dom, hero)

	var r_m := rank("multishot")
	if r_m <= 0:
		return
	if is_melee:
		var waves := 1 if r_m == 1 else (2 if r_m == 2 else 3)
		for i in range(waves):
			var spread := (float(i) - float(waves - 1) * 0.5) * 0.22
			var w_dir := dir.rotated(spread)
			game.fire_projectile(origin, origin + w_dir * 350.0, base_dmg * (0.74 if r_m >= 3 else 0.58), 0, "hero", {
				"speed": 740.0,
				"pierce": 3 + extra_pierce(),
				"bounce": 0,
				"appearance": "sword_wave",
				"feedback": "slash",
				"domain": dom,
				"condition_hit": {"passive_proc": true}
			})
	else:
		var count := r_m
		for i in range(count):
			var side := -1.0 if i % 2 == 0 else 1.0
			var tier := float(int(i / 2) + 1)
			var w_dir := dir.rotated(side * 0.14 * tier)
			game.fire_projectile(origin, origin + w_dir * hero.attack_reach(), base_dmg * (0.70 if r_m >= 3 else 0.55), int(hero.data.type), "hero", {
				"speed": 840.0,
				"pierce": extra_pierce() + (1 if hero.class_id in ["gunner", "healer"] else 0),
				"bounce": extra_bounce(),
				"appearance": "arrow" if int(hero.data.type) == 0 else "magic",
				"presentation": hero.class_id,
				"feedback": "quick_arrow" if int(hero.data.type) == 0 else "druid_orb",
				"domain": dom,
				"condition_hit": {"passive_proc": true}
			})


func _on_hero_hit(payload: Dictionary) -> void:
	if _proc_guard > 0 or game == null or not is_instance_valid(game.hero):
		return
	var enemy: Node2D = payload.get("enemy")
	if not is_instance_valid(enemy) or enemy.dead:
		return
	var hero: ArenaHero = game.hero
	var dom: String = str(enemy.domain)
	var base_dmg: float = hero.attack_damage()
	var is_crit: bool = bool(payload.get("crit", false))

	_proc_guard += 1
	var r_bolt := rank("chain_bolt")
	if r_bolt > 0:
		_fire_lightning_chain(enemy, [0, 2, 4, 6][r_bolt], base_dmg * [0.0, 0.48, 0.66, 0.88][r_bolt], dom, r_bolt >= 3)

	var r_frost := rank("frost_nova")
	if r_frost > 0 and not enemy.dead:
		if r_frost >= 3:
			enemy.frost_hit(0.44, 2.2, 3, 1.25)
		else:
			enemy.chill(0.26 if r_frost == 1 else 0.36, 1.8)

	var r_fire := rank("blazing_wake")
	if r_fire > 0 and not enemy.dead:
		enemy.ignite([0.0, 18.0, 28.0, 44.0][r_fire], 3.2)

	var r_void := rank("void_bloom")
	if r_void > 0 and not enemy.dead:
		enemy.set_meta("void_cursed", r_void)

	var r_met := rank("star_meteor")
	if r_met > 0:
		_meteor_hits += 1
		var need: int = [99, 6, 5, 4][r_met]
		if is_crit or _meteor_hits >= need:
			_meteor_hits = 0
			var m_cnt := 2 if r_met >= 3 else 1
			for m_i in range(m_cnt):
				var off := Vector2.ZERO if m_i == 0 else Vector2(game.rng.randf_range(-56, 56), game.rng.randf_range(-42, 42))
				var pt := enemy.position + off
				game.delayed_attack(pt, 98.0 if r_met < 3 else 132.0, base_dmg * (1.60 if r_met >= 3 else 1.20), 1, "hero", 0.24 + float(m_i) * 0.14, {
					"fx_kind": "starfall", "fx_color": Color("d878ff"), "stun": 0.28, "domain": dom
				})
				game.effect(pt, 88.0, Color("d878ff"), "starfall", 0.38)

	var r_gw := rank("gravity_well")
	if r_gw > 0 and active_wells.size() < 4:
		_gravity_hits += 1
		var gw_need: int = [99, 6, 5, 4][r_gw]
		if is_crit or _gravity_hits >= gw_need:
			_gravity_hits = 0
			active_wells.append({
				"pos": enemy.position,
				"radius": [0.0, 175.0, 205.0, 245.0][r_gw],
				"life": 1.60,
				"duration": 1.60,
				"tick": 0.0,
				"damage": base_dmg * [0.0, 0.90, 1.22, 1.55][r_gw],
				"domain": dom,
				"evo": r_gw >= 3
			})
			game.audio.play("phase", -12.0, 0.78)
	_proc_guard -= 1


func _fire_lightning_chain(first: Node2D, hops: int, dmg: float, dom: String, thunder_cap := false) -> void:
	var curr := first
	var origin: Vector2 = curr.center()
	var visited: Dictionary = {curr.get_instance_id(): true}
	var cur_dmg := dmg
	for h_i in range(hops):
		var best: Node2D = null
		var best_d2 := 220.0 * 220.0
		for cand in game.domain_enemies(dom):
			if not is_instance_valid(cand) or cand.dead or visited.has(cand.get_instance_id()):
				continue
			var d2 := origin.distance_squared_to(cand.center())
			if d2 < best_d2:
				best_d2 = d2
				best = cand
		if best == null:
			break
		visited[best.get_instance_id()] = true
		var dest: Vector2 = best.center()
		game.effect(origin, origin.distance_to(dest), Color("72f2ff"), "tower_arc", 0.24, origin.direction_to(dest))
		game.effect(dest, 24.0, Color("9ef8ff"), "lightning", 0.22)
		best.take_hit(cur_dmg, 1, "hero", 0.14 if thunder_cap else 0.0, 0.0, 0.20, "chain_bolt")
		origin = dest
		cur_dmg *= 0.88
		if thunder_cap and h_i == hops - 1 and is_instance_valid(best):
			game.area_damage(best.position, 94.0, dmg * 0.98, 1, "hero", 0.40, 0.0, 0.25, 0.0, "thunder_cap", true, {"domain": dom})
			game.effect(best.position, 90.0, Color("ffe978"), "lightning", 0.34)


func _on_enemy_killed(payload: Dictionary) -> void:
	if game == null:
		return
	var pos: Vector2 = payload.get("position", Vector2.ZERO)
	var dom: String = str(payload.get("domain", "defense"))
	var void_tier: int = int(payload.get("void_cursed", 0))
	var hero: ArenaHero = game.hero
	var base_dmg: float = hero.attack_damage() if is_instance_valid(hero) else 28.0

	var r_b := rank("blood_aegis")
	if r_b > 0 and is_instance_valid(hero) and not hero.knocked_out:
		var pct: float = [0.0, 0.03, 0.045, 0.065][r_b]
		hero._heal_self(hero.max_health * pct, true)

	if _proc_guard > 1:
		return
	_proc_guard += 1

	var r_fn := rank("frost_nova")
	if r_fn > 0:
		var rad := 156.0 if r_fn >= 3 else (114.0 if r_fn == 2 else 88.0)
		var stg := 1.25 if r_fn >= 3 else 0.0
		game.area_damage(pos, rad, base_dmg * (1.20 if r_fn >= 3 else 0.82), 1, "hero", stg, 1.8, 0.15, 0.0, "frost_nova", true, {"domain": dom})
		game.effect(pos, rad * 0.90, Color("84eeff"), "frost_spikes", 0.38)

	var r_fire := rank("blazing_wake")
	if r_fire > 0:
		var z_rad: float = [0.0, 68.0, 84.0, 114.0][r_fire]
		var z_dps: float = [0.0, 24.0, 36.0, 56.0][r_fire]
		var z_dur := 4.5 if r_fire >= 3 else 3.0
		game.add_zone(pos, z_rad, z_dps, z_dur, 1, "hero", "burn", dom)

	var r_vb := maxi(rank("void_bloom"), void_tier)
	if r_vb > 0:
		var v_rad: float = [0.0, 90.0, 114.0, 150.0][r_vb]
		var v_dmg: float = base_dmg * [0.0, 0.90, 1.20, 1.60][r_vb]
		if r_vb >= 3:
			for other in game.domain_enemies(dom):
				if is_instance_valid(other) and not other.dead and other.position.distance_to(pos) <= v_rad:
					other.set_meta("void_cursed", 3)
		game.area_damage(pos, v_rad, v_dmg, 1, "hero", 0.12, 0.0, 0.25, 0.0, "void_bloom", true, {"domain": dom})
		game.effect(pos, v_rad * 0.86, Color("c868ff"), "blast", 0.34)

	_proc_guard -= 1


func _on_hero_dodge(payload: Dictionary) -> void:
	if game == null or not is_instance_valid(game.hero):
		return
	var origin: Vector2 = payload.get("origin", game.hero.position)
	var dir: Vector2 = payload.get("direction", game.hero.facing)
	var dom: String = game.hero.domain
	_spawn_phantom(origin, dir, dom, game.hero)


func _on_tower_fire(payload: Dictionary) -> void:
	var r_ts := rank("tower_storm")
	if r_ts <= 0 or game == null or game.active_domain != "defense":
		return
	var target: Node2D = payload.get("target")
	var tower: Node2D = payload.get("tower")
	if not is_instance_valid(target) or target.dead or not is_instance_valid(tower):
		return
	if r_ts < 3 and is_instance_valid(game.hero) and tower.position.distance_to(game.hero.position) > 420.0:
		return
	var chance: float = [0.0, 0.35, 0.55, 0.75][r_ts]
	if game.rng.randf() <= chance:
		_proc_guard += 1
		var hops := 2 if r_ts == 1 else (3 if r_ts == 2 else 4)
		_fire_lightning_chain(target, hops, 26.0 + float(r_ts) * 10.0, "defense", false)
		_proc_guard -= 1


func _on_domain_recall(_payload: Dictionary) -> void:
	var r_a := rank("tower_aegis")
	if r_a <= 0 or game == null:
		return
	var shield_add: float = [0.0, 55.0, 95.0, 145.0][r_a]
	game.add_core_shield(shield_add)
	for enemy in game.domain_enemies("defense"):
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.push_back(58.0 + float(r_a) * 18.0)
			enemy.chill(0.40, 2.0)
	if r_a >= 3:
		aegis_haste_clock = 7.0
		game.numbers.append({
			"point": game.hero.center() + Vector2(0, -36),
			"text": "神殿金钟·全塔狂飙!",
			"colour": Color("ffe878"),
			"life": 1.0,
			"duration": 1.0,
			"critical": true
		})
