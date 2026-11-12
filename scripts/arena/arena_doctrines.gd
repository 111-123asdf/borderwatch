class_name ArenaDoctrines
extends RefCounted
# L3 tower doctrines. Data only: towers read these keys, no per-kind branches.
# Every doctrine needs a role, a real drawback and at least one numeric effect.
const LIST: Array=[
	{"id":"sentinel","tower":"archer","name":"哨戒塔","role":"标记 · 反重甲",
		"summary":"射程 +50%，攻速 −20%；优先攻击最耐打的敌人；命中标记 2.5 秒，所有来源对其 +15% 伤害。",
		"drawback":"攻速 −20%",
		"effects":{"range_mult":1.5,"interval_mult":1.25,"target":"strongest","mark_time":2.5,"mark_bonus":0.15}},
	{"id":"repeater","tower":"archer","name":"连弩阵","role":"反群 · 爆发",
		"summary":"射程 −15%，攻速 +60%；25% 概率一次射出 3 箭。",
		"drawback":"射程 −15%",
		"effects":{"range_mult":0.85,"interval_mult":0.625,"triple_chance":0.25}},
	{"id":"piercer","tower":"archer","name":"穿甲塔","role":"反重甲",
		"summary":"无视 40% 护甲；对重甲目标额外 +25%；攻速 −10%。",
		"drawback":"攻速 −10%",
		"effects":{"interval_mult":1.111,"armour_pen":0.4,"bonus_armour":0.25}},
	{"id":"frost","tower":"mage","name":"霜咒塔","role":"控制",
		"summary":"命中减速 30%；同一目标叠 5 层冻结 1.5 秒；伤害 −20%。",
		"drawback":"伤害 −20%",
		"effects":{"damage_mult":0.8,"slow_amount":0.3,"slow_time":2.0,"frost_stacks":5,"freeze_time":1.5}},
	{"id":"arcfire","tower":"mage","name":"奥火塔","role":"清群",
		"summary":"伤害 +15%；击杀目标时在 60 半径内爆开，造成 60% 伤害。",
		"drawback":"无控制",
		"effects":{"damage_mult":1.15,"explode_radius":60,"explode_mult":0.6}},
	{"id":"breaker","tower":"mage","name":"破法塔","role":"反法抗",
		"summary":"无视 40% 法抗；对高法抗目标额外 +25%；单体伤害。",
		"drawback":"单体 · 对低法抗无额外收益",
		"effects":{"resist_pen":0.4,"bonus_resist":0.25}},
	{"id":"siege","tower":"cannon","name":"攻城炮","role":"反首领",
		"summary":"伤害 +50%；对精英与首领额外 +40%；溅射 −40%，攻速 −15%。",
		"drawback":"溅射 −40% · 攻速 −15%",
		"effects":{"damage_mult":1.5,"splash_mult":0.6,"bonus_elite":0.4,"interval_mult":1.15}},
	{"id":"burning","tower":"cannon","name":"燃烧炮","role":"区域封锁",
		"summary":"直接伤害 −20%；落点留下 4 秒火焰，每秒 30 伤害。",
		"drawback":"直接伤害 −20%",
		"effects":{"damage_mult":0.8,"burn_dps":30.0,"burn_time":4.0,"burn_radius":64.0}},
	{"id":"frag","tower":"cannon","name":"破片炮","role":"反群",
		"summary":"溅射 +50%，命中后把敌人击退 15。",
		"drawback":"没有单体增伤，靠溅射覆盖",
		"effects":{"splash_mult":1.5,"knockback":15.0}},
	{"id":"shield","tower":"barracks","name":"盾卫营","role":"守线",
		"summary":"士兵生命 +50%，每名可拦 2 人，并优先吸引附近敌人。",
		"drawback":"士兵伤害不变",
		"effects":{"soldier_count":3,"soldier_health":0.5,"block_capacity":2,"taunt":1}},
	{"id":"hunter","tower":"barracks","name":"游猎营","role":"远程",
		"summary":"改为 2 名远程士兵，射程 180，命中减速 25%，生命 −20%。",
		"drawback":"少一名士兵 · 生命 −20%",
		"effects":{"soldier_count":2,"soldier_health":-0.2,"soldier_range":180,"slow_amount":0.25,"slow_time":1.5}},
	{"id":"charge","tower":"barracks","name":"冲锋营","role":"进攻",
		"summary":"士兵移速 +30%，接敌时冲锋眩晕 1 秒。",
		"drawback":"没有防御与射程加成",
		"effects":{"soldier_count":3,"soldier_speed":0.3,"charge_stun":1.0}}
]
# Guardrail for data review: these are the only keys tower code understands.
const EFFECT_KEYS: Array[String]=["range_mult","interval_mult","damage_mult","splash_mult","armour_pen","resist_pen",
	"bonus_armour","bonus_resist","bonus_elite","triple_chance","mark_time","mark_bonus",
	"slow_amount","slow_time","frost_stacks","freeze_time","explode_radius","explode_mult",
	"burn_dps","burn_time","burn_radius","knockback","target",
	"soldier_count","soldier_health","soldier_speed","soldier_range","block_capacity","taunt","charge_stun"]
const HEAVY_ARMOUR:=0.4
const HIGH_RESIST:=0.4
static func by_id(id: String) -> Dictionary:
	for entry in LIST:
		if str(entry.id)==id:return entry
	return {}
static func for_tower(kind: String) -> Array:
	var result: Array=[]
	for entry in LIST:
		if str(entry.tower)==kind:result.append(entry)
	return result
static func ids() -> Array[String]:
	var result: Array[String]=[]
	for entry in LIST:result.append(str(entry.id))
	return result
static func value(id: String,key: String,fallback := 0.0) -> float:
	var entry:=by_id(id)
	if entry.is_empty():return fallback
	var effects: Dictionary=entry.effects
	if not effects.has(key):return fallback
	return float(effects[key])
