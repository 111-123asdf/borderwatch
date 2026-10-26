class_name ArenaUpgrades
extends RefCounted

const RARITY_NAMES := {
	"common": "普通",
	"rare": "稀有",
	"epic": "史诗",
	"synergy": "协同",
}
const RARITY_COLORS := {
	"common": Color("c8c3b3"),
	"rare": Color("76c9f0"),
	"epic": Color("d6a3ff"),
	"synergy": Color("ffd36e"),
}
const RARITY_WEIGHTS := {
	"common": 60.0,
	"rare": 30.0,
	"epic": 10.0,
	"synergy": 45.0,
}
const STAGE_WEIGHTS := [
	{"common": 82.0, "rare": 16.0, "epic": 2.0, "synergy": 0.0},
	{"common": 48.0, "rare": 38.0, "epic": 10.0, "synergy": 28.0},
	{"common": 18.0, "rare": 38.0, "epic": 30.0, "synergy": 58.0},
]
const ARCHETYPES := {
	"fire": {"name": "火焰", "keys": ["burn", "wildfire", "thermal_shock", "pyroclasm", "inferno"], "branch": ["wildfire", "thermal_shock"], "capstone": "inferno"},
	"frost": {"name": "冰霜", "keys": ["frost", "nova", "permafrost", "deepfreeze", "shatter", "absolute_zero"], "branch": ["permafrost", "deepfreeze"], "capstone": "absolute_zero"},
	"lightning": {"name": "雷电", "keys": ["chain", "storm", "conductive", "stormfire", "thunder_god"], "branch": ["storm", "conductive"], "capstone": "thunder_god"},
}

const DEFS := {
	"power": {"name": "过载", "desc": "武器伤害 +12%", "rarity": "common", "tags": ["弹道"], "max": 5, "pool": "both"},
	"rapid": {"name": "速射", "desc": "攻击速度 +10%", "rarity": "common", "tags": ["弹道"], "max": 5, "pool": "both"},
	"crit": {"name": "致命", "desc": "暴击率 +12%", "rarity": "rare", "tags": ["弹道"], "max": 3, "pool": "both"},
	"berserk": {"name": "狂战", "desc": "伤害 +15%，受到伤害 +8%", "rarity": "rare", "tags": ["弹道", "生存"], "max": 2, "pool": "both"},
	"glass_cannon": {"name": "玻璃大炮", "desc": "伤害 +30%，最大生命 -20", "rarity": "epic", "tags": ["弹道"], "max": 1, "pool": "both"},
	"last_stand": {"name": "背水一战", "desc": "伤害 +5%，生命低于 40% 时再 +30%", "rarity": "rare", "tags": ["生存", "弹道"], "max": 2, "pool": "both"},
	"tower_arsenal": {"name": "塔武合一", "desc": "每种不同塔使英雄伤害 +6%", "rarity": "rare", "tags": ["塔防", "弹道"], "max": 2, "pool": "both"},
	"predator": {"name": "猎杀本能", "desc": "伤害 +5%，对精英和 Boss 再 +25%", "rarity": "rare", "tags": ["弹道"], "max": 2, "pool": "both"},
	"pierce": {"name": "穿透", "desc": "弹道额外穿透 +1", "rarity": "common", "tags": ["弹道"], "max": 4, "pool": "both"},
	"blast": {"name": "爆裂", "desc": "命中附加 25 范围伤害", "rarity": "rare", "tags": ["弹道"], "max": 3, "pool": "both"},
	"multishot": {"name": "分裂", "desc": "额外弹道 +1", "rarity": "rare", "tags": ["弹道"], "max": 3, "pool": "both"},
	"swift": {"name": "疾行", "desc": "移动速度 +8%", "rarity": "common", "tags": ["生存"], "max": 4, "pool": "both"},
	"vitality": {"name": "体魄", "desc": "最大生命 +25 并回复", "rarity": "common", "tags": ["生存"], "max": 5, "pool": "both"},
	"aegis": {"name": "重盾", "desc": "最大护盾 +25 并回满", "rarity": "common", "tags": ["生存"], "max": 4, "pool": "both"},
	"magnet": {"name": "磁力", "desc": "拾取范围 +80", "rarity": "common", "tags": ["经济"], "max": 2, "pool": "both"},
	"greed": {"name": "贪婪", "desc": "金币获取 +25%", "rarity": "rare", "tags": ["经济"], "max": 2, "pool": "both"},
	"scholar": {"name": "博学", "desc": "经验获取 +15%", "rarity": "common", "tags": ["经济"], "max": 3, "pool": "both"},
	"focus": {"name": "专注", "desc": "技能冷却 -10%", "rarity": "rare", "tags": ["生存"], "max": 2, "pool": "both"},
	"frost": {"name": "霜附", "desc": "命中减速 +0.8 秒", "rarity": "rare", "tags": ["元素"], "max": 3, "pool": "both"},
	"burn": {"name": "燃烧", "desc": "命中点燃 3 秒，每秒 6 伤害", "rarity": "rare", "tags": ["元素"], "max": 3, "pool": "both"},
	"chain": {"name": "连锁", "desc": "每第 3 发弹射；叠层缩短间隔并增加跳数", "rarity": "rare", "tags": ["元素"], "max": 3, "pool": "both"},
	"nova": {"name": "霜环", "desc": "每第 5 发冻结周围；叠层缩短间隔并扩大范围", "rarity": "rare", "tags": ["元素"], "max": 2, "pool": "both"},
	"execute": {"name": "处决", "desc": "对 35% 以下敌人伤害 +60%；叠层提高到 +90%", "rarity": "rare", "tags": ["弹道"], "max": 2, "pool": "both"},
	"deathblast": {"name": "尸爆", "desc": "敌人死亡时爆炸；叠层提高伤害和范围", "rarity": "rare", "tags": ["元素"], "max": 2, "pool": "both"},
	"storm": {"name": "雷暴", "desc": "每 6 秒劈向最近敌人；叠层加快并增伤", "rarity": "epic", "tags": ["元素"], "max": 2, "pool": "both"},
	"lifesteal": {"name": "吸血", "desc": "击杀回复 6 生命；叠层每层 +3", "rarity": "rare", "tags": ["生存"], "max": 3, "pool": "both"},
	"dash_reset": {"name": "猎杀", "desc": "击杀减少技能冷却 1 秒；叠层每层 +0.5 秒", "rarity": "rare", "tags": ["生存"], "max": 2, "pool": "both"},
	"overload": {"name": "超载弹", "desc": "每第 8 发双倍伤害；叠层缩短到 6 / 4 发", "rarity": "epic", "tags": ["弹道"], "max": 2, "pool": "both"},
	"tower_link": {"name": "塔链", "desc": "所有塔伤害 +15%", "rarity": "rare", "tags": ["塔防"], "max": 3, "pool": "both"},
	"tower_bolt": {"name": "弩术", "desc": "全塔攻速 +4%，弩塔再 +10%", "rarity": "common", "tags": ["塔防"], "max": 3, "pool": "both"},
	"tower_cannon": {"name": "炮术", "desc": "全塔伤害 +5%，炮塔再 +15% 与溅射", "rarity": "rare", "tags": ["塔防"], "max": 3, "pool": "both"},
	"tower_frost": {"name": "霜核", "desc": "全塔射程 +8，霜塔再 +0.5 秒减速", "rarity": "rare", "tags": ["塔防"], "max": 3, "pool": "both"},
	"tower_network": {"name": "塔网", "desc": "每座 2 格内塔使本塔伤害 +10%", "rarity": "rare", "tags": ["塔防"], "max": 2, "pool": "both"},
	"tower_commander": {"name": "塔防指挥", "desc": "英雄 240 范围内塔伤害 +25%", "rarity": "epic", "tags": ["塔防", "生存"], "max": 1, "pool": "both"},
	"tower_engineer": {"name": "工程学", "desc": "建造与升级费用 -8%", "rarity": "common", "tags": ["塔防", "经济"], "max": 2, "pool": "both"},
	"tower_arc": {"name": "雷术", "desc": "全塔伤害 +4%，电弧塔再 +15% 与跳数", "rarity": "common", "tags": ["塔防", "元素"], "max": 3, "pool": "both"},
	"tower_venom": {"name": "毒术", "desc": "全塔伤害 +5%，毒塔再 +15% 中毒", "rarity": "common", "tags": ["塔防"], "max": 3, "pool": "both"},
	"tower_laser": {"name": "棱镜", "desc": "全塔射程 +8，曜光塔再 +10%", "rarity": "common", "tags": ["塔防"], "max": 3, "pool": "both"},
	"tower_banner": {"name": "号令", "desc": "战旗光环额外 +5% 塔伤害", "rarity": "rare", "tags": ["塔防", "生存"], "max": 2, "pool": "both"},
	"tower_mixed": {"name": "混编", "desc": "每种不同塔使全塔伤害 +4%", "rarity": "rare", "tags": ["塔防"], "max": 2, "pool": "both"},
	"tower_fortress": {"name": "堡垒网络", "desc": "2 格内每座塔使塔伤害 +10%，塔受伤 -25%", "rarity": "synergy", "tags": ["协同", "塔防"], "max": 1, "requires": ["tower_network", "tower_link"], "pool": "both"},
	"tower_overclock": {"name": "超载炮击", "desc": "每座塔每第 5 发造成双倍伤害", "rarity": "synergy", "tags": ["协同", "塔防"], "max": 1, "requires": ["tower_bolt", "tower_cannon"], "pool": "both"},
	"tower_winter": {"name": "永冻核心", "desc": "霜塔减速 +1.5 秒且伤害 +15%", "rarity": "synergy", "tags": ["协同", "塔防"], "max": 1, "requires": ["tower_frost", "tower_network"], "pool": "both"},
	"tower_command": {"name": "指挥协议", "desc": "英雄 240 范围内塔攻速 +20%", "rarity": "synergy", "tags": ["协同", "塔防"], "max": 1, "requires": ["tower_commander", "tower_engineer"], "pool": "both"},
	"pistol_caliber": {"name": "手枪口径", "desc": "手枪伤害 +18%", "rarity": "common", "tags": ["武器", "弹道"], "max": 3, "weapon": "pistol", "pool": "both"},
	"pistol_akimbo": {"name": "双持弹匣", "desc": "手枪额外弹道 +1", "rarity": "rare", "tags": ["武器", "弹道"], "max": 2, "weapon": "pistol", "pool": "both"},
	"pistol_quickdraw": {"name": "快拔", "desc": "手枪攻速 +10%", "rarity": "common", "tags": ["武器", "弹道"], "max": 3, "weapon": "pistol", "pool": "both"},
	"pistol_ricochet": {"name": "跳弹", "desc": "手枪穿透 +1", "rarity": "rare", "tags": ["武器", "弹道"], "max": 2, "weapon": "pistol", "pool": "both"},
	"pistol_storm": {"name": "弹幕风暴", "desc": "每第 6 发追加三发扇形弹", "rarity": "epic", "tags": ["武器", "弹道"], "max": 1, "weapon": "pistol", "pool": "both"},
	"bow_broadhead": {"name": "猎弓", "desc": "弓伤害 +20%，穿透 +1", "rarity": "common", "tags": ["武器", "弹道"], "max": 3, "weapon": "bow", "pool": "both"},
	"bow_hunter": {"name": "猎手印记", "desc": "对减速目标伤害 +30%", "rarity": "rare", "tags": ["武器", "弹道"], "max": 2, "weapon": "bow", "pool": "both"},
	"bow_rapid": {"name": "连珠箭", "desc": "弓攻速 +12%", "rarity": "common", "tags": ["武器", "弹道"], "max": 3, "weapon": "bow", "pool": "both"},
	"bow_pierce": {"name": "破甲箭", "desc": "弓穿透 +1", "rarity": "common", "tags": ["武器", "弹道"], "max": 3, "weapon": "bow", "pool": "both"},
	"bow_marksman": {"name": "神射手", "desc": "暴击率 +10%，暴击伤害 +50%", "rarity": "epic", "tags": ["武器", "弹道"], "max": 1, "weapon": "bow", "pool": "both"},
	"bow_rain": {"name": "箭雨", "desc": "每第 6 箭追加三支散箭", "rarity": "epic", "tags": ["武器", "弹道"], "max": 1, "weapon": "bow", "pool": "both"},
	"scatter_wide": {"name": "散弹加弹", "desc": "散弹弹丸 +1", "rarity": "common", "tags": ["武器", "弹道"], "max": 3, "weapon": "scatter", "pool": "both"},
	"scatter_frost": {"name": "霜弹", "desc": "散弹附带霜冻", "rarity": "rare", "tags": ["武器", "元素"], "max": 2, "weapon": "scatter", "pool": "both"},
	"scatter_close": {"name": "抵近射击", "desc": "近距离伤害 +20%", "rarity": "common", "tags": ["武器", "弹道"], "max": 3, "weapon": "scatter", "pool": "both"},
	"scatter_reload": {"name": "快速装填", "desc": "散弹攻速 +12%", "rarity": "rare", "tags": ["武器", "弹道"], "max": 2, "weapon": "scatter", "pool": "both"},
	"scatter_barrage": {"name": "星弹爆发", "desc": "每第 5 次射击追加一圈弹丸", "rarity": "epic", "tags": ["武器", "弹道"], "max": 1, "weapon": "scatter", "pool": "both"},
	"knight_bulwark": {"name": "壁垒", "desc": "受到的伤害 -6%", "rarity": "common", "tags": ["职业", "生存"], "max": 3, "hero_class": "knight", "pool": "both"},
	"knight_riposte": {"name": "破盾反击", "desc": "护盾破碎时释放冲击波", "rarity": "rare", "tags": ["职业", "生存"], "max": 1, "hero_class": "knight", "pool": "both"},
	"knight_dual": {"name": "双持延续", "desc": "火力双生持续时间 +1.5 秒", "rarity": "rare", "tags": ["职业", "武器"], "max": 2, "hero_class": "knight", "pool": "both"},
	"knight_bastion": {"name": "堡垒", "desc": "护盾存在时伤害 +20%", "rarity": "epic", "tags": ["职业", "生存"], "max": 1, "hero_class": "knight", "pool": "both"},
	"ranger_tempo": {"name": "踏风", "desc": "翻滚后 3 秒攻速 +15%", "rarity": "common", "tags": ["职业", "弹道"], "max": 3, "hero_class": "ranger", "pool": "both"},
	"ranger_trail": {"name": "霜迹", "desc": "翻滚落点触发霜爆", "rarity": "rare", "tags": ["职业", "元素"], "max": 1, "hero_class": "ranger", "pool": "both"},
	"ranger_mark": {"name": "猎印", "desc": "对满血敌人伤害 +20%", "rarity": "rare", "tags": ["职业", "弹道"], "max": 2, "hero_class": "ranger", "pool": "both"},
	"ranger_evasion": {"name": "无影", "desc": "翻滚冷却 -35%，无敌 +0.1 秒", "rarity": "epic", "tags": ["职业", "生存"], "max": 1, "hero_class": "ranger", "pool": "both"},
	"mage_barrier": {"name": "结界延长", "desc": "星纹结界持续 +0.5 秒", "rarity": "common", "tags": ["职业", "生存"], "max": 3, "hero_class": "mage", "pool": "both"},
	"mage_overcharge": {"name": "过载结界", "desc": "结界期间伤害 +25%", "rarity": "rare", "tags": ["职业", "弹道"], "max": 2, "hero_class": "mage", "pool": "both"},
	"mage_reflect": {"name": "星纹反震", "desc": "开结界时冲击周围敌人", "rarity": "rare", "tags": ["职业", "元素"], "max": 1, "hero_class": "mage", "pool": "both"},
	"mage_echo": {"name": "奥术回响", "desc": "每第 4 发追加奥术爆炸", "rarity": "epic", "tags": ["职业", "元素"], "max": 1, "hero_class": "mage", "pool": "both"},
	"stormfire": {"name": "雷火", "desc": "连锁命中引发燃烧爆炸", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["burn", "chain"], "pool": "both"},
	"shatter": {"name": "碎冰", "desc": "暴击冻结目标 1 秒并 +50% 伤害", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["frost", "crit"], "pool": "both"},
	"executioner": {"name": "行刑者", "desc": "处决阈值提高到 50%", "rarity": "synergy", "tags": ["协同", "弹道"], "max": 1, "requires": ["execute", "crit"], "pool": "both"},
	"tempest": {"name": "风暴眼", "desc": "雷暴落点同时触发霜环", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["storm", "nova"], "pool": "both"},
	"reaper": {"name": "收割", "desc": "尸爆会回复生命", "rarity": "synergy", "tags": ["协同", "生存"], "max": 1, "requires": ["lifesteal", "deathblast"], "pool": "both"},
	"tower_doctrine": {"name": "塔防协议", "desc": "塔伤害 +30%，技能冷却 -10%", "rarity": "synergy", "tags": ["协同", "塔防"], "max": 1, "requires": ["tower_link", "focus"], "pool": "both"},
	"pyroclasm": {"name": "燃爆", "desc": "燃烧的敌人死亡时爆炸", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["burn", "blast"], "pool": "both"},
	"chainfrost": {"name": "霜链", "desc": "连锁命中附加霜冻", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["chain", "frost"], "pool": "both"},
	"permafrost": {"name": "永冻", "desc": "霜环范围与减速大幅提高", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["nova", "frost"], "pool": "both"},
	"thermal_shock": {"name": "热震", "desc": "同时燃烧且减速的敌人被命中时爆炸", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["burn", "frost"], "pool": "both"},
	"inferno": {"name": "焚城", "desc": "燃烧敌人死亡时爆炸并把火传给周围", "rarity": "epic", "tags": ["元素", "弹道"], "max": 1, "requires": ["burn", "wildfire"], "pool": "both"},
	"wildfire": {"name": "野火", "desc": "燃烧敌人死亡时把火传给附近敌人", "rarity": "rare", "tags": ["元素"], "max": 1, "requires": ["burn"], "pool": "both"},
	"deepfreeze": {"name": "深寒", "desc": "霜附叠加 2 层即冻结，冻结延长 0.5 秒", "rarity": "rare", "tags": ["元素"], "max": 1, "requires": ["frost"], "pool": "both"},
	"conductive": {"name": "导电", "desc": "连锁/雷暴命中燃烧或减速目标时伤害 +40%", "rarity": "epic", "tags": ["元素"], "max": 1, "requires": ["chain", "storm"], "pool": "both"},
	"absolute_zero": {"name": "绝对零度", "desc": "冻结目标受到的伤害 +30%，冻结延长 0.5 秒", "rarity": "epic", "tags": ["元素"], "max": 1, "requires": ["frost", "deepfreeze"], "pool": "both"},
	"thunder_god": {"name": "雷神", "desc": "雷暴命中时追加一次雷击并短暂眩晕", "rarity": "epic", "tags": ["元素"], "max": 1, "requires": ["storm", "conductive"], "pool": "both"},
	"juggernaut": {"name": "不动如山", "desc": "受到的伤害 -20%", "rarity": "synergy", "tags": ["协同", "生存"], "max": 1, "requires": ["vitality", "aegis"], "pool": "both"},
}

static func info(key: String, stacks := 0) -> Dictionary:
	if not DEFS.has(key):
		return {"name": key, "desc": "", "rarity": "common", "tags": ["被动"], "max": 1, "stacks": stacks}
	var data: Dictionary = DEFS[key].duplicate(true)
	data["stacks"] = stacks
	data["rarity_name"] = String(RARITY_NAMES.get(data.rarity, "普通"))
	data["rarity_color"] = RARITY_COLORS.get(data.rarity, Color.WHITE)
	data["tags_text"] = " · ".join(PackedStringArray(data.tags))
	data["stack_text"] = "%d/%d" % [stacks, int(data.max)]
	var requirements: Array = data.get("requires", [])
	var requirement_names: Array[String] = []
	for req in requirements:
		if DEFS.has(String(req)):
			requirement_names.append(String(DEFS[String(req)].name))
		else:
			requirement_names.append(String(req))
	data["requires_text"] = " + ".join(PackedStringArray(requirement_names))
	return data

static func is_synergy(key: String) -> bool:
	return DEFS.has(key) and String(DEFS[key].rarity) == "synergy"

static func has_towers(hero) -> bool:
	if hero == null: return false
	var game = hero.get("game")
	if game == null: return false
	return game.towers != null and game.towers.size() > 0

static func card_available(key: String, hero) -> bool:
	if not DEFS.has(key): return false
	var data: Dictionary = DEFS[key]
	if "塔防" in data.tags and not has_towers(hero):
		return false
	return true

static func build_pool(hero, source: String, banished: Array[String] = []) -> Array[String]:
	var pool: Array[String] = []
	for key in DEFS:
		if key in banished: continue
		var data: Dictionary = DEFS[key]
		var stacks := int(hero.passives.get(key, 0))
		if stacks >= int(data.max): continue
		if not card_available(String(key), hero): continue
		if data.has("weapon") and not hero.has_weapon_equipped(String(data.weapon)): continue
		if data.has("hero_class") and not hero.has_class_tag(String(data.hero_class)): continue
		if source == "camp" and String(data.rarity) == "common": continue
		var requirements: Array = data.get("requires", [])
		var missing := false
		for req in requirements:
			if not hero.passives.has(String(req)):
				missing = true
				break
		if missing: continue
		pool.append(String(key))
	return pool

static func ready_synergies(hero) -> Array[String]:
	var ready: Array[String] = []
	for key in DEFS:
		var data: Dictionary = DEFS[key]
		if String(data.rarity) != "synergy": continue
		if hero.passives.has(key): continue
		var requirements: Array = data.get("requires", [])
		var met := true
		for req in requirements:
			if not hero.passives.has(String(req)):
				met = false
				break
		if met and requirements.size() > 0:
			ready.append(String(key))
	return ready

static func stage_for_cycle(cycle: int) -> int:
	if cycle <= 2: return 0
	if cycle <= 4: return 1
	return 2

static func weight_for(key: String, hero, cycle := 1) -> float:
	var rarity := String(DEFS[key].rarity)
	var stage := stage_for_cycle(cycle)
	var weight := float(STAGE_WEIGHTS[stage].get(rarity, 0.0))
	if rarity == "synergy":
		if key in ready_synergies(hero):
			weight = maxf(weight, 30.0) * 3.0
		elif stage == 0:
			weight = 0.0
	if DEFS[key].has("hero_class") and hero.has_class_tag(String(DEFS[key].hero_class)):
		weight *= 1.6
	if DEFS[key].has("weapon") and hero.has_weapon_equipped(String(DEFS[key].weapon)):
		weight *= 1.3
	if key in eligible_branches(hero):
		weight *= 3.0
	return weight

static func archetype_stacks(hero, tag: String) -> int:
	if not ARCHETYPES.has(tag): return 0
	var count := 0
	for key in ARCHETYPES[tag].keys:
		count += int(hero.passives.get(String(key), 0))
	return count

static func archetype_tier(hero, tag: String) -> int:
	var count := archetype_stacks(hero, tag)
	if count >= 5: return 3
	if count >= 3: return 2
	if count >= 2: return 1
	return 0

static func eligible_branches(hero, pool: Array[String] = []) -> Array[String]:
	var branches: Array[String] = []
	for tag in ARCHETYPES:
		if archetype_stacks(hero, String(tag)) < 2: continue
		var owned := false
		for branch in ARCHETYPES[tag].branch:
			if hero.passives.has(String(branch)): owned = true
		if owned: continue
		for branch in ARCHETYPES[tag].branch:
			var branch_key := String(branch)
			if pool.size() > 0 and not pool.has(branch_key): continue
			if not DEFS.has(branch_key) or not card_available(branch_key, hero): continue
			var requirements_met := true
			for req in DEFS[branch_key].get("requires", []):
				if not hero.passives.has(String(req)):
					requirements_met = false
					break
			if requirements_met:
				branches.append(branch_key)
	return branches

static func roll(hero, source: String, count: int, rng: RandomNumberGenerator, guarantee_weapon := false, guarantee_element := false, banished: Array[String] = [], cycle := 1) -> Array[String]:
	var pool := build_pool(hero, source, banished)
	var picked: Array[String] = []
	if guarantee_weapon:
		var weapon_candidates: Array[String] = []
		for key in pool:
			if DEFS[key].has("weapon"):
				weapon_candidates.append(key)
		if weapon_candidates.size() > 0 and count > 0:
			var weapon_pick: String = weapon_candidates[rng.randi_range(0, weapon_candidates.size() - 1)]
			picked.append(weapon_pick)
			pool.erase(weapon_pick)
	if guarantee_element and picked.size() < count:
		var element_candidates: Array[String] = []
		for key in pool:
			if "元素" in DEFS[key].tags:
				element_candidates.append(key)
		if element_candidates.size() > 0:
			var element_pick: String = element_candidates[rng.randi_range(0, element_candidates.size() - 1)]
			picked.append(element_pick)
			pool.erase(element_pick)
	if picked.size() < count:
		var branch_candidates := eligible_branches(hero, pool)
		for tag in ARCHETYPES:
			if archetype_stacks(hero, String(tag)) < 2: continue
			var owned := false
			for branch in ARCHETYPES[tag].branch:
				if hero.passives.has(String(branch)): owned = true
			if owned: continue
			if int(hero.branch_pity.get(String(tag), 0)) < 2: continue
			for branch_key in branch_candidates:
				if not pool.has(branch_key): continue
				picked.append(branch_key)
				pool.erase(branch_key)
				hero.branch_pity[String(tag)] = 0
				break
			if picked.size() >= count: break
	while picked.size() < count and pool.size() > 0:
		var total := 0.0
		for key in pool:
			total += weight_for(String(key), hero, cycle)
		var roll_value := rng.randf() * total
		var chosen := ""
		for key in pool:
			roll_value -= weight_for(String(key), hero, cycle)
			if roll_value <= 0.0:
				chosen = key
				break
		if chosen == "": chosen = pool.back()
		picked.append(chosen)
		pool.erase(chosen)
	for tag in ARCHETYPES:
		if archetype_stacks(hero, String(tag)) < 2: continue
		var branch_owned := false
		for branch in ARCHETYPES[tag].branch:
			if hero.passives.has(String(branch)): branch_owned = true
		if branch_owned:
			hero.branch_pity[String(tag)] = 0
			continue
		var offered := false
		for key in picked:
			if key in ARCHETYPES[tag].branch: offered = true
			if offered: break
		hero.branch_pity[String(tag)] = 0 if offered else int(hero.branch_pity.get(String(tag), 0)) + 1
	return picked
