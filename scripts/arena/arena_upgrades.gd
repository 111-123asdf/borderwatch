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

const DEFS := {
	"power": {"name": "过载", "desc": "武器伤害 +12%", "rarity": "common", "tags": ["弹道"], "max": 5, "pool": "both"},
	"rapid": {"name": "速射", "desc": "攻击速度 +10%", "rarity": "common", "tags": ["弹道"], "max": 5, "pool": "both"},
	"crit": {"name": "致命", "desc": "暴击率 +12%", "rarity": "rare", "tags": ["弹道"], "max": 3, "pool": "both"},
	"pierce": {"name": "穿透", "desc": "弹道额外穿透 +1", "rarity": "common", "tags": ["弹道"], "max": 4, "pool": "both"},
	"blast": {"name": "爆裂", "desc": "命中附加 25 范围伤害", "rarity": "rare", "tags": ["弹道"], "max": 3, "pool": "both"},
	"multishot": {"name": "分裂", "desc": "额外弹道 +1", "rarity": "rare", "tags": ["弹道"], "max": 3, "pool": "both"},
	"swift": {"name": "疾行", "desc": "移动速度 +8%", "rarity": "common", "tags": ["生存"], "max": 4, "pool": "both"},
	"vitality": {"name": "体魄", "desc": "最大生命 +25 并回复", "rarity": "common", "tags": ["生存"], "max": 5, "pool": "both"},
	"aegis": {"name": "重盾", "desc": "最大护盾 +25 并回满", "rarity": "common", "tags": ["生存"], "max": 4, "pool": "both"},
	"magnet": {"name": "磁力", "desc": "拾取范围 +80", "rarity": "common", "tags": ["经济"], "max": 2, "pool": "both"},
	"greed": {"name": "贪婪", "desc": "金币获取 +15%", "rarity": "common", "tags": ["经济"], "max": 3, "pool": "both"},
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
	"stormfire": {"name": "雷火", "desc": "连锁命中引发燃烧爆炸", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["burn", "chain"], "pool": "both"},
	"shatter": {"name": "碎冰", "desc": "暴击冻结目标 1 秒并 +50% 伤害", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["frost", "crit"], "pool": "both"},
	"executioner": {"name": "行刑者", "desc": "处决阈值提高到 50%", "rarity": "synergy", "tags": ["协同", "弹道"], "max": 1, "requires": ["execute", "crit"], "pool": "both"},
	"tempest": {"name": "风暴眼", "desc": "雷暴落点同时触发霜环", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["storm", "nova"], "pool": "both"},
	"reaper": {"name": "收割", "desc": "尸爆会回复生命", "rarity": "synergy", "tags": ["协同", "生存"], "max": 1, "requires": ["lifesteal", "deathblast"], "pool": "both"},
	"tower_doctrine": {"name": "塔防协议", "desc": "塔伤害 +30%，技能冷却 -10%", "rarity": "synergy", "tags": ["协同", "塔防"], "max": 1, "requires": ["tower_link", "focus"], "pool": "both"},
	"pyroclasm": {"name": "燃爆", "desc": "燃烧的敌人死亡时爆炸", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["burn", "blast"], "pool": "both"},
	"chainfrost": {"name": "霜链", "desc": "连锁命中附加霜冻", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["chain", "frost"], "pool": "both"},
	"permafrost": {"name": "永冻", "desc": "霜环范围与减速大幅提高", "rarity": "synergy", "tags": ["协同", "元素"], "max": 1, "requires": ["nova", "frost"], "pool": "both"},
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

static func build_pool(hero, source: String) -> Array[String]:
	var pool: Array[String] = []
	for key in DEFS:
		var data: Dictionary = DEFS[key]
		var stacks := int(hero.passives.get(key, 0))
		if stacks >= int(data.max): continue
		if data.has("weapon") and String(data.weapon) != hero.weapon_key: continue
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

static func roll(hero, source: String, count: int, rng: RandomNumberGenerator, guarantee_weapon := false, guarantee_element := false) -> Array[String]:
	var pool := build_pool(hero, source)
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
	while picked.size() < count and pool.size() > 0:
		var total := 0.0
		for key in pool:
			total += float(RARITY_WEIGHTS.get(String(DEFS[key].rarity), 1.0))
		var roll_value := rng.randf() * total
		var chosen := ""
		for key in pool:
			roll_value -= float(RARITY_WEIGHTS.get(String(DEFS[key].rarity), 1.0))
			if roll_value <= 0.0:
				chosen = key
				break
		if chosen == "": chosen = pool.back()
		picked.append(chosen)
		pool.erase(chosen)
	return picked
