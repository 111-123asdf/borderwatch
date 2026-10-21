class_name Rules
extends RefCounted

const WORLD_SIZE := Vector2(6400, 3200)
const CORE := Vector2(1472, 832)
const BASE_RADIUS := 660.0
const GRID := 64.0
const TOWER_LIMIT := 12
const WAVES := 6
const PREPARATION := 55.0
const FIRST_WAVE := 90.0
const PATHS := [
	[Vector2(80, 320), Vector2(640, 320), Vector2(896, 576), Vector2(1216, 576), Vector2(1472, 832)],
	[Vector2(80, 1344), Vector2(640, 1344), Vector2(896, 1088), Vector2(1216, 1088), Vector2(1472, 832)],
]
const BUILD_SITES := [Vector2(1184, 736), Vector2(1184, 928), Vector2(1056, 416), Vector2(1184, 416), Vector2(1376, 544), Vector2(1568, 608), Vector2(992, 736), Vector2(1056, 1248), Vector2(1184, 1248), Vector2(1376, 1120), Vector2(1568, 1056), Vector2(992, 928)]
const CAMPS := [Vector2(3072, 832), Vector2(3712, 2368), Vector2(5632, 1600)]
const EXPLORATION_ROUTES := [
	[Vector2(2176, 576), Vector2(2688, 448), Vector2(3072, 832)],
	[Vector2(2304, 1664), Vector2(3008, 2240), Vector2(3712, 2368)],
	[Vector2(4224, 1792), Vector2(4864, 1152), Vector2(5632, 1600)],
]
const COVER_OFFSETS := [Vector2(-140, -100), Vector2(165, 95)]
const CAMP_NAMES := ["苔石林地", "回响石庭", "沉星深殿"]
const CAMP_UNLOCK := [0, 1, 3]
const CAMP_GOLD := [120, 160, 220]
const TOWERS := {
	"bolt": {"name": "巡林弩塔", "cost": 100, "damage": 19.0, "interval": 0.65, "range": 330.0, "color": Color("edc76c"), "description": "快速点杀 · 优先拦截前方敌人"},
	"cannon": {"name": "星火重炮", "cost": 150, "damage": 33.0, "interval": 1.5, "range": 365.0, "color": Color("ff9d65"), "description": "范围轰击 · 克制密集怪群"},
	"frost": {"name": "寒霜哨塔", "cost": 120, "damage": 9.0, "interval": 1.0, "range": 310.0, "color": Color("87dfeb"), "description": "减速拦截 · 延长防线输出时间"},
}
## 伤害结算表：每种敌人对「英雄 / 塔」两个来源的抗性，0 表示拒绝结算。
## 新增塔或敌人只改这张表，不再往 Enemy.take_damage() 里加分支。
const DAMAGE_MULTIPLIERS := {
	"boss": {"hero": 1.0, "tower": 0.45},
	"shielded": {"hero": 1.0, "tower": 0.2},
	"armored": {"hero": 0.0, "tower": 1.0, "refuse": "铁甲 · 用塔打"},
	"barrel": {"hero": 0.7, "tower": 1.35},
}

const LEAK_DAMAGE := {"torch": 16, "tnt": 16, "shooter": 16, "barrel": 32, "shielded": 30, "armored": 44, "warden": 32}

## ── 核心切片 ────────────────────────────────────────────────
## 只有下面这几项真正进入游戏。上面的定义表保持完整，作为素材库：
## 恢复某项内容 = 把它加回这些列表，玩法代码不用改。清单见 docs/CURRENT_SLICE.md。
const ACTIVE_WEAPONS := ["sword", "scatter", "sniper", "boomerang"]
const ACTIVE_RELICS := ["lone", "swarm", "vanguard", "command", "raid", "hold"]
const CAMP_NODES := 1
## 每肃清一个营地，所有塔的伤害加成：夺回的地形变成工事。
const CAMP_TOWER_BONUS := 0.12

const WEAPONS := {
	"sword": {"name": "曙光长剑", "tag": "近战 / 横扫", "damage": 44.0, "interval": 0.43, "color": Color("ffe7ab"), "text": "三式连斩、范围击退；剑刃可以斩掉敌弹。", "evolution": "+3突破：终结斩发出剑气。首关强化上限+3。"},
	"bow": {"name": "疾风连弓", "tag": "远程 / 连射", "damage": 22.0, "interval": 0.22, "color": Color("e8d699"), "text": "快速射箭，适合精准处理投弹手。", "evolution": "+3突破：每第三箭追加连射。首关强化上限+3。"},
	"scatter": {"name": "群星法杖", "tag": "远程 / 散射", "damage": 14.0, "interval": 0.48, "color": Color("a9e8ef"), "text": "同时发射五枚星弹；贴近敌群时火力集中。", "evolution": "+3突破：散射增加至七枚。首关强化上限+3。"},
	"storm": {"name": "雷鸣弩机", "tag": "远程 / 穿透", "damage": 17.0, "interval": 0.16, "color": Color("bbaff3"), "text": "高速穿透弩矢，命中时弹射一名敌人。", "evolution": "+3突破：连锁增加目标。首关强化上限+3。"},
}
const HEROES := {
	"knight": {"name": "曙光骑士", "role": "双持爆发 / 坚实护盾", "health": 120.0, "shield": 70.0, "energy": 100.0, "speed": 265.0, "regen": 3.0, "color": "Blue", "start": "pistol", "skill": "火力双生", "cooldown": 12.0, "duration": 5.0, "text": "5秒内复制当前武器双持，第二把消耗相同能量。没有翻滚；依靠护盾、走位或近战消弹。", "icon": "split"},
	"ranger": {"name": "林影游侠", "role": "高速走位 / 短冷却翻滚", "health": 85.0, "shield": 45.0, "energy": 110.0, "speed": 305.0, "regen": 3.0, "color": "Yellow", "start": "bow", "skill": "掠影翻滚", "cooldown": 1.8, "duration": 0.22, "text": "沿移动方向翻滚，短暂无敌；停步时沿面向翻滚。只有游侠拥有翻滚技能。", "icon": "haste"},
	"mage": {"name": "星纹秘术师", "role": "能量续航 / 防御结界", "health": 75.0, "shield": 65.0, "energy": 180.0, "speed": 280.0, "regen": 5.0, "color": "Purple", "start": "scatter", "skill": "星纹结界", "cooldown": 14.0, "duration": 3.5, "text": "展开结界，拦截近身敌弹并转为能量；红圈与近战仍须走位。没有翻滚。", "icon": "shield"},
}

static func weapon(key: String) -> Dictionary:
	var definition: Dictionary = WEAPONS.get(key, {}).duplicate()
	var extras := {
		"sword": {"energy": 0, "reach": 110.0, "model": "sword"},
		"bow": {"energy": 0, "reach": 650.0, "model": "bow"},
		"scatter": {"energy": 4, "reach": 530.0, "model": "staff"},
		"storm": {"energy": 2, "reach": 650.0, "model": "crossbow"},
		"pistol": {"name": "铜雀手枪", "tag": "手枪 / 零耗能", "damage": 24.0, "interval": 0.32, "energy": 0, "reach": 620.0, "model": "pistol", "color": Color("f6d28b"), "text": "不消耗能量，稳定可靠的备用火力。", "evolution": "+3：每第四发追加一枚弹丸。"},
		"gatling": {"name": "疾雨转管", "tag": "机枪 / 预热扫射", "damage": 8.0, "interval": 0.065, "energy": 1, "reach": 610.0, "model": "gatling", "color": Color("ffd16f"), "text": "连续开火0.7秒完成预热，喷出密集弹雨。", "evolution": "+3：每第六发额外穿透。"},
		"sniper": {"name": "远星狙击", "tag": "狙击 / 直线贯穿", "damage": 105.0, "interval": 1.1, "energy": 6, "reach": 850.0, "model": "sniper", "color": Color("b2e7df"), "text": "高伤重击，长弹道贯穿整列敌人。", "evolution": "+3：贯穿后仍保留伤害，追加一层穿透。"},
		"rocket": {"name": "赤焰火箭", "tag": "炮械 / 大范围爆破", "damage": 76.0, "interval": 1.0, "energy": 7, "reach": 680.0, "model": "rocket", "color": Color("ffad6a"), "text": "慢速火箭落点爆破，适合拥挤怪群。", "evolution": "+3：爆破产生三枚余焰弹。"},
		"laser": {"name": "棱光射线", "tag": "激光 / 持续贯穿", "damage": 12.0, "interval": 0.11, "energy": 2, "reach": 670.0, "model": "laser", "color": Color("8febec"), "text": "持续光束瞬时贯穿敌列，不消除敌弹。", "evolution": "+3：束宽与穿透目标增加。"},
		"boomerang": {"name": "回风月轮", "tag": "投掷 / 返程消弹", "damage": 28.0, "interval": 0.65, "energy": 0, "reach": 410.0, "model": "boomerang", "color": Color("b6e3b4"), "text": "飞出后回到英雄，往返均可伤敌并削去接触的敌弹。", "evolution": "+3：多投出一枚月轮。"},
		"halberd": {"name": "破阵长刃", "tag": "长兵 / 大范围消弹", "damage": 60.0, "interval": 0.7, "energy": 0, "reach": 190.0, "model": "halberd", "color": Color("e7d8ff"), "text": "长距离扇形横扫，击退敌人、切开正面弹幕。", "evolution": "+3：第三击释放穿透刀波。"},
	}
	definition.merge(extras.get(key, {}), true)
	return definition

static func weapon_keys() -> Array:
	return ["sword", "bow", "scatter", "storm", "pistol", "gatling", "sniper", "rocket", "laser", "boomerang", "halberd"]
const RELICS := {
	"lone": {"name": "孤塔", "tag": "防线 · 少而深", "group": "defense", "text": "塔位上限 -2；每座塔伤害 +40%。", "color": Color("e8c37a")},
	"swarm": {"name": "群塔", "tag": "防线 · 多而浅", "group": "defense", "text": "塔位上限 +2；每座塔伤害 -15%。", "color": Color("b9d98a")},
	"vanguard": {"name": "亲征", "tag": "主力 · 英雄", "group": "lead", "text": "英雄伤害 +35%；塔伤害 -10%。", "color": Color("ff9f80")},
	"command": {"name": "指挥", "tag": "主力 · 防线", "group": "lead", "text": "塔伤害 +25%；英雄伤害 -10%。", "color": Color("8fcfe0")},
	"raid": {"name": "急袭", "tag": "节奏 · 快", "group": "tempo", "text": "波间准备 -15 秒；击杀金币 +40%。", "color": Color("f2a65a")},
	"hold": {"name": "深耕", "tag": "节奏 · 稳", "group": "tempo", "text": "波间准备 +20 秒；塔升级费 -30%。", "color": Color("a8c3a0")},
}
## 三组路线：每次营地奖励只给一组里的两个，选一个即锁定该组。
const RELIC_GROUPS := ["defense", "lead", "tempo"]

static func is_tower_source(source: String) -> bool:
	return source == "tower" or TOWERS.has(source)

static func damage_multiplier(kind: String, source: String) -> float:
	var row: Dictionary = DAMAGE_MULTIPLIERS.get(kind, {})
	if row.is_empty(): return 1.0
	return float(row.get("tower" if is_tower_source(source) else "hero", 1.0))

static func refusal_hint(kind: String, source: String) -> String:
	if damage_multiplier(kind, source) > 0.0: return ""
	return String(DAMAGE_MULTIPLIERS.get(kind, {}).get("refuse", ""))

## 漏怪对核心的伤害；Boss 抵达直接清空核心。核心不再自行修复，掉血即记账。
static func leak_damage(kind: String, core: float) -> float:
	if kind == "boss": return core
	return float(LEAK_DAMAGE.get(kind, 16.0))

static func snapped_position(point: Vector2) -> Vector2:
	return (point / GRID).floor() * GRID + Vector2.ONE * GRID * 0.5

static func road_distance(point: Vector2) -> float:
	var distance := INF
	for route in PATHS:
		for segment in range(route.size() - 1):
			distance = minf(distance, point.distance_to(Geometry2D.get_closest_point_to_segment(point, route[segment], route[segment + 1])))
	return distance
