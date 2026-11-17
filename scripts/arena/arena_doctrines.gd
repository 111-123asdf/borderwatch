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
const BRANCH_PRICES: Array[int]=[45,60,75]
const BRANCHES: Dictionary={
	"sentinel":[
		{"id":"a","name":"猎鹰视界","summary":"射程+12% · 攻速+9%","delta":{"range_mult":0.12,"interval_mult":-0.09}},
		{"id":"b","name":"弱点印记","summary":"易伤+10% · 破甲+15% · 精英伤+10%","delta":{"mark_bonus":0.10,"armour_pen":0.15,"bonus_elite":0.10}},
	],
	"repeater":[
		{"id":"a","name":"疾风连矢","summary":"连射+12% · 攻速+6%(满级4箭)","delta":{"triple_chance":0.12,"interval_mult":-0.06}},
		{"id":"b","name":"致命箭簇","summary":"伤害+16% · 破甲+10%","delta":{"damage_mult":0.16,"armour_pen":0.10}},
	],
	"piercer":[
		{"id":"a","name":"重弩破钢","summary":"破甲+18% · 重甲伤+18%","delta":{"armour_pen":0.18,"bonus_armour":0.18}},
		{"id":"b","name":"精准狙杀","summary":"伤害+18% · 攻速+9%","delta":{"damage_mult":0.18,"interval_mult":-0.09}},
	],
	"frost":[
		{"id":"a","name":"极寒蔓延","summary":"减速+7% · 冻结+0.35s · 叠层-1","delta":{"slow_amount":0.07,"freeze_time":0.35,"frost_stacks":-1.0}},
		{"id":"b","name":"冰晶碎裂","summary":"法伤+18% · 法穿+12%","delta":{"damage_mult":0.18,"resist_pen":0.12}},
	],
	"arcfire":[
		{"id":"a","name":"连环爆焰","summary":"殉爆范围+16 · 爆伤+22%","delta":{"explode_radius":16.0,"explode_mult":0.22}},
		{"id":"b","name":"奥能过载","summary":"法伤+16% · 攻速+8%","delta":{"damage_mult":0.16,"interval_mult":-0.08}},
	],
	"breaker":[
		{"id":"a","name":"法盾崩解","summary":"法穿+18% · 高抗伤+20%","delta":{"resist_pen":0.18,"bonus_resist":0.20}},
		{"id":"b","name":"秘法洪流","summary":"射程+10% · 攻速+9% · 法伤+10%","delta":{"range_mult":0.10,"interval_mult":-0.09,"damage_mult":0.10}},
	],
	"siege":[
		{"id":"a","name":"震天巨炮","summary":"精英首领伤+22% · 炮伤+18%","delta":{"bonus_elite":0.22,"damage_mult":0.18}},
		{"id":"b","name":"迅捷装填","summary":"射程+10% · 攻速+10% · 破甲+10%","delta":{"range_mult":0.10,"interval_mult":-0.10,"armour_pen":0.10}},
	],
	"burning":[
		{"id":"a","name":"焦土火海","summary":"火域半径+12 · 持续+1.0s","delta":{"burn_radius":12.0,"burn_time":1.0}},
		{"id":"b","name":"烈焰高爆","summary":"灼伤+14/s · 炮伤+14%","delta":{"burn_dps":14.0,"damage_mult":0.14}},
	],
	"frag":[
		{"id":"a","name":"广域震荡","summary":"溅射+18% · 击退+6","delta":{"splash_mult":0.18,"knockback":6.0}},
		{"id":"b","name":"暴雨弹幕","summary":"攻速+9% · 炮伤+15%","delta":{"interval_mult":-0.09,"damage_mult":0.15}},
	],
	"shield":[
		{"id":"a","name":"铁壁增援","summary":"士兵生命+25% · 3级增兵+1","delta":{"soldier_health":0.25,"soldier_count":0.34}},
		{"id":"b","name":"磐石防线","summary":"阻挡数+1 · 移速+10%","delta":{"block_capacity":1.0,"soldier_speed":0.10}},
	],
	"hunter":[
		{"id":"a","name":"群猎伏击","summary":"射程+25 · 2级+1猎手","delta":{"soldier_range":25.0,"soldier_count":0.50}},
		{"id":"b","name":"荆棘毒箭","summary":"减速+8% · 持续+0.4s · 生命+20%","delta":{"slow_amount":0.08,"slow_time":0.40,"soldier_health":0.20}},
	],
	"charge":[
		{"id":"a","name":"雷霆冲锋","summary":"冲锋眩晕+0.4s · 移速+15%","delta":{"charge_stun":0.40,"soldier_speed":0.15}},
		{"id":"b","name":"先锋战甲","summary":"士兵生命+28% · 3级增兵+1","delta":{"soldier_health":0.28,"soldier_count":0.34}},
	],
}
static func branches(id: String) -> Array:
	return BRANCHES.get(id,[])
static func branch_price(rank: int) -> int:
	return BRANCH_PRICES[clampi(rank,0,BRANCH_PRICES.size()-1)]
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
