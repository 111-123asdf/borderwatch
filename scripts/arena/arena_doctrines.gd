class_name ArenaDoctrines
extends RefCounted
# L3 tower doctrines. Data only: towers read these keys, no per-kind branches.
# Every doctrine needs a role, a real drawback and at least one numeric effect.
const LIST: Array=[
	{"id":"sentinel","tower":"archer","name":"哨戒塔","role":"标记 · 反重甲",
		"summary":"射程 +50%，攻速 −20%，优先攻击当前血量最高的敌人。箭矢穿透一名敌人并施加持续 3.5 秒的 28% 易伤。",
		"drawback":"攻速 −20%",
		"effects":{"range_mult":1.5,"interval_mult":1.25,"target":"strongest","mark_time":3.5,"mark_bonus":0.28}},
	{"id":"repeater","tower":"archer","name":"连弩阵","role":"反群 · 爆发",
		"summary":"射程 −15%，攻速 +60%；25% 概率一次射出 3 箭。",
		"drawback":"射程 −15%",
		"effects":{"range_mult":0.85,"interval_mult":0.625,"triple_chance":0.25}},
	{"id":"piercer","tower":"archer","name":"穿甲塔","role":"反重甲",
		"summary":"物理穿透 40 个百分点；瞄准重甲目标时箭矢伤害额外 +25%；攻速 −10%。",
		"drawback":"攻速 −10%",
		"effects":{"interval_mult":1.111,"armour_pen":0.4,"bonus_armour":0.25}},
	{"id":"frost","tower":"mage","name":"霜咒塔","role":"控制",
		"summary":"命中减速 38%，叠 3 层冻结 1.8 秒，伤害 −20%。",
		"drawback":"伤害 −20%",
		"effects":{"damage_mult":0.8,"slow_amount":0.38,"slow_time":2.0,"frost_stacks":3,"freeze_time":1.8}},
	{"id":"arcfire","tower":"mage","name":"奥火塔","role":"清群",
		"summary":"伤害 +15%；击杀目标时在 60 半径内爆开，造成 60% 伤害。",
		"drawback":"无控制",
		"effects":{"damage_mult":1.15,"explode_radius":60,"explode_mult":0.6}},
	{"id":"breaker","tower":"mage","name":"破法塔","role":"反法抗",
		"summary":"单体攻击优先选择法抗最高的敌人，法术穿透 40 个百分点，对高法抗目标额外 +25%。",
		"drawback":"单体 · 对低法抗无额外收益",
		"effects":{"resist_pen":0.4,"bonus_resist":0.25}},
	{"id":"siege","tower":"cannon","name":"攻城炮","role":"反首领",
		"summary":"伤害 +50%；瞄准精英或首领时额外 +40%；溅射半径 −40%，攻击间隔 +15%。",
		"drawback":"溅射半径 −40% · 攻击间隔 +15%",
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
		"effects":{"soldier_count":3,"soldier_speed":0.3,"charge_stun":1.0}},
	{"id":"fork","tower":"storm","name":"分叉线圈","role":"密集群体","summary":"多跳两次，首击伤害降低 15%。","drawback":"首击伤害 −15%","effects":{"chain_count":5,"damage_mult":0.85}},
	{"id":"relay","tower":"storm","name":"中继线圈","role":"跨队接力","summary":"跳跃距离增至 165，每次攻击间隔增加 15%。","drawback":"攻击间隔 +15%","effects":{"chain_reach":165,"interval_mult":1.15}},
	{"id":"surge","tower":"storm","name":"蓄雷线圈","role":"双目标","summary":"首击伤害提高 35%，最多击中两敌。","drawback":"少一跳","effects":{"damage_mult":1.35,"chain_count":2}},
	{"id":"focus","tower":"lens","name":"聚日镜","role":"持续照射","summary":"每次聚焦增伤从 35% 提至 55%，射程缩短 12%。","drawback":"射程 −12%","effects":{"focus_step":0.55,"range_mult":0.88}},
	{"id":"sweep","tower":"lens","name":"巡光镜","role":"快速换敌","summary":"基础伤害提高 35%，每层聚焦增伤降至 15%。","drawback":"聚焦收益降低","effects":{"damage_mult":1.35,"focus_step":0.15}},
	{"id":"far_lens","tower":"lens","name":"远望镜","role":"远程压制","summary":"射程提高 30%，攻击间隔增加 12%。","drawback":"攻击间隔 +12%","effects":{"range_mult":1.3,"interval_mult":1.12}},
	{"id":"net","tower":"snare","name":"围网坊","role":"大范围减速","summary":"触发与收网范围扩大 35%，直接伤害降低 20%。","drawback":"伤害 −20%","effects":{"splash_mult":1.35,"damage_mult":0.8}},
	{"id":"barb","tower":"snare","name":"棘刺索","role":"破甲陷阱","summary":"无视 45% 护甲，装填时间增加 20%。","drawback":"装填时间 +20%","effects":{"armour_pen":0.45,"interval_mult":1.2}},
	{"id":"ratchet","tower":"snare","name":"快轮索","role":"反复封路","summary":"装填时间缩短 30%，收网范围缩小 15%。","drawback":"范围 −15%","effects":{"interval_mult":0.7,"splash_mult":0.85}}
]
# Guardrail for data review: these are the only keys tower code understands.
const EFFECT_KEYS: Array[String]=["range_mult","interval_mult","damage_mult","splash_mult","armour_pen","resist_pen",
	"bonus_armour","bonus_resist","bonus_elite","triple_chance","mark_time","mark_bonus",
	"slow_amount","slow_time","frost_stacks","freeze_time","explode_radius","explode_mult",
	"burn_dps","burn_time","burn_radius","knockback","target",
	"soldier_count","soldier_health","soldier_speed","soldier_range","block_capacity","taunt","charge_stun","chain_reach","chain_count","focus_step"]
const HEAVY_ARMOUR:=0.4
const HIGH_RESIST:=0.4
const ENHANCEMENT_PRICES := [55, 85, 115]
const AUTO_DEFAULT := {"archer":"sentinel", "mage":"frost", "cannon":"frag", "barracks":"shield", "storm":"fork", "lens":"focus", "snare":"net"}
const ENHANCEMENTS := {
	"sentinel": [
		{"name":"猎鹰远望","icon":"farsight","summary":"基础射程 +14%，箭矢标记多持续 0.6 秒。","delta":{"range_mult":0.14,"mark_time":0.6}},
		{"name":"裂甲箭簇","icon":"pierce","summary":"物理穿透 +16 个百分点。","delta":{"armour_pen":0.16}},
		{"name":"交叉校射","icon":"focus","summary":"标记易伤从 28% 提高到 36%。","delta":{"mark_bonus":0.08}}
	],
	"repeater": [
		{"name":"并弦齐射","icon":"rapid","summary":"三箭齐射概率从 25% 提高到 43%。","delta":{"triple_chance":0.18}},
		{"name":"贯阵排矢","icon":"piercearrow","summary":"每支箭额外穿透一名敌人。","delta":{"arrow_pierce":1.0}},
		{"name":"回弦棘轮","icon":"warmachine","summary":"射击间隔再缩短约 13%。","delta":{"interval_mult":-0.08}}
	],
	"piercer": [
		{"name":"碎钢弩头","icon":"pierce","summary":"物理穿透再提高 16 个百分点。","delta":{"armour_pen":0.16}},
		{"name":"斩铁追击","icon":"executioner","summary":"瞄准重甲敌人时，额外伤害从 25% 提高到 45%。","delta":{"bonus_armour":0.20}}
	],
	"frost": [
		{"name":"长冬咒文","icon":"frostheart","summary":"减速增强 6 个百分点，冻结延长 0.3 秒。","delta":{"slow_amount":0.06,"freeze_time":0.3}},
		{"name":"裂冰法印","icon":"starcore","summary":"伤害加成 +18 个百分点，法术穿透 +12 个百分点。","delta":{"damage_mult":0.18,"resist_pen":0.12}},
		{"name":"外环刻纹","icon":"enchant","summary":"外圈伤害从内圈的 50% 提高到 65%。","delta":{"outer_power":0.15}}
	],
	"arcfire": [
		{"name":"扩焰刻印","icon":"burn","summary":"击杀殉爆半径从 60 扩大到 84。","delta":{"explode_radius":24.0}},
		{"name":"余烬爆燃","icon":"starcore","summary":"殉爆伤害从基础攻击的 60% 提高到 92%。","delta":{"explode_mult":0.32}}
	],
	"breaker": [
		{"name":"法盾裂隙","icon":"pierce","summary":"法术穿透 +16 个百分点，高法抗目标的额外伤害提高到 45%。","delta":{"resist_pen":0.16,"bonus_resist":0.20}},
		{"name":"追魔法眼","icon":"farsight","summary":"基础射程 +15%，攻击间隔缩短 9%。","delta":{"range_mult":0.15,"interval_mult":-0.09}}
	],
	"frag": [
		{"name":"重装破片","icon":"warmachine","summary":"基础溅射半径 +15%，击退距离 +7。","delta":{"splash_mult":0.15,"knockback":7.0}},
		{"name":"震地引信","icon":"ironwall","summary":"爆炸中心的眩晕延长 0.2 秒。","delta":{"shell_stun":0.2}},
		{"name":"广角破片","icon":"piercearrow","summary":"爆炸边缘的伤害从全额的 50% 提高到 70%。","delta":{"shell_edge_power":0.20}}
	],
	"siege": [
		{"name":"猎首装药","icon":"executioner","summary":"瞄准精英或首领时，额外伤害从 40% 提高到 65%。","delta":{"bonus_elite":0.25}},
		{"name":"钨芯重弹","icon":"pierce","summary":"物理穿透 +18 个百分点。","delta":{"armour_pen":0.18}},
		{"name":"远端测距","icon":"farsight","summary":"基础射程 +14%，攻击间隔再缩短约 9%。","delta":{"range_mult":0.14,"interval_mult":-0.10}}
	],
	"burning": [
		{"name":"蔓焰油囊","icon":"burn","summary":"火区半径从 64 提高到 84，持续时间延长 1.5 秒。","delta":{"burn_radius":20.0,"burn_time":1.5}},
		{"name":"高温炉芯","icon":"starcore","summary":"火区每秒伤害从 30 提高到 42。","delta":{"burn_dps":12.0}}
	],
	"shield": [
		{"name":"加固塔盾","icon":"ironwall","summary":"盾卫的基础生命加成再提高 22 个百分点。","delta":{"soldier_health":0.22}},
		{"name":"拒马加固","icon":"warmachine","summary":"集结点屏障半径 +12，持续时间延长 1 秒。","delta":{"barrier_radius":12.0,"barrier_duration":1.0}},
		{"name":"盾卫预备队","icon":"rapid","summary":"增加一名盾卫，阵亡盾卫的补员速度 +20%。","delta":{"soldier_count":1.0,"respawn_speed":0.2}}
	],
	"hunter": [
		{"name":"钩索猎箭","icon":"piercearrow","summary":"猎箭减速增强 10 个百分点，持续时间延长 0.6 秒。","delta":{"slow_amount":0.10,"slow_time":0.60}},
		{"name":"高射弓架","icon":"farsight","summary":"猎手射程 +44，箭矢伤害 +20%。","delta":{"soldier_range":44.0,"soldier_damage_mult":0.20}},
		{"name":"后备猎手","icon":"rapid","summary":"额外增派一名猎手，维持远程封锁。","delta":{"soldier_count":1.0}}
	],
	"charge": [
		{"name":"雷霆冲锋","icon":"starlight","summary":"冲锋眩晕延长 0.35 秒，士兵移速加成 +15 个百分点。","delta":{"charge_stun":0.35,"soldier_speed":0.15}},
		{"name":"先锋护具","icon":"ironwall","summary":"士兵基础生命 +24%，补员速度 +20%。","delta":{"soldier_health":0.24,"respawn_speed":0.20}}
	],
	"fork": [
		{"name":"接力导线","icon":"starlight","summary":"闪电多跳一名敌人，跳跃距离 +12。","delta":{"chain_count":1.0,"chain_reach":12.0}},
		{"name":"稳压线圈","icon":"starcore","summary":"每次跳跃保留的伤害从 72% 提高到 79%。","delta":{"chain_retention":0.07}}
	],
	"relay": [
		{"name":"高空接线","icon":"farsight","summary":"跳跃距离从 165 提高到 193。","delta":{"chain_reach":28.0}},
		{"name":"中继稳流","icon":"starcore","summary":"每跳伤害保留提高到 83%，攻击间隔缩短约 12%。","delta":{"chain_retention":0.11,"interval_mult":-0.14}}
	],
	"surge": [
		{"name":"蓄压电芯","icon":"starcore","summary":"连锁伤害加成再提高 22 个百分点。","delta":{"damage_mult":0.22}},
		{"name":"滞电极板","icon":"starlight","summary":"每次电击附带的基础硬直从 0.18 秒延长到 0.4 秒。","delta":{"chain_stagger":0.22}}
	],
	"focus": [
		{"name":"灼焦镜面","icon":"starcore","summary":"聚焦上限增加一层，每层额外增伤 7 个百分点。","delta":{"focus_limit":1.0,"focus_step":0.07}},
		{"name":"显影棱镜","icon":"farsight","summary":"光束标记易伤 +5 个百分点，持续时间延长 0.5 秒。","delta":{"lens_mark":0.05,"lens_mark_time":0.5}}
	],
	"sweep": [
		{"name":"首光棱镜","icon":"starlight","summary":"换目标后第一击伤害 +30%。","delta":{"first_light":0.30}},
		{"name":"巡光齿轮","icon":"rapid","summary":"攻击间隔缩短 14%，更快再次出光。","delta":{"interval_mult":-0.14}}
	],
	"far_lens": [
		{"name":"展臂镜筒","icon":"farsight","summary":"基础射程 +18%。","delta":{"range_mult":0.18}},
		{"name":"遥光标定","icon":"frostheart","summary":"照射减速从 25% 提高到 35%，持续时间延长 0.5 秒。","delta":{"lens_slow":0.10,"lens_slow_time":0.5}}
	],
	"net": [
		{"name":"绳网加宽","icon":"warmachine","summary":"基础收网和触发半径再提高 20%。","delta":{"splash_mult":0.20}},
		{"name":"缠足网坠","icon":"frostheart","summary":"减速增强 10 个百分点，并延长 0.65 秒。","delta":{"net_slow":0.10,"net_duration":0.65}}
	],
	"barb": [
		{"name":"刃齿咬合","icon":"pierce","summary":"物理穿透再提高 20 个百分点。","delta":{"armour_pen":0.20}},
		{"name":"密刺绊索","icon":"executioner","summary":"收网直接伤害 +25%。","delta":{"damage_mult":0.25}}
	],
	"ratchet": [
		{"name":"双向快轮","icon":"rapid","summary":"装填间隔再缩短约 21%。","delta":{"interval_mult":-0.15}},
		{"name":"回网导槽","icon":"warmachine","summary":"补回快轮索缩减的 15% 收网半径。","delta":{"splash_mult":0.15}}
	]
}

static func enhancements(doctrine_id: String) -> Array:
	return ENHANCEMENTS.get(doctrine_id, [])

static func is_for_tower(kind: String, doctrine_id: String) -> bool:
	return str(by_id(doctrine_id).get("tower","")) == kind and not kind.is_empty()

static func by_id(id: String) -> Dictionary:
	for entry in LIST:
		if str(entry.id)==id:return entry
	return {}

static func field_summary(id: String) -> String:
	match id:
		"frost": return "范围减速 38%，伤害 −20%。内圈命中叠两层霜冻，外圈叠一层并造成一半伤害，叠满三层冻结 1.8 秒。"
		"fork": return "一道闪电最多击中五名敌人，比基础形态多命中一名，伤害 −15%。"
		_: return str(by_id(id).get("summary",""))

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
