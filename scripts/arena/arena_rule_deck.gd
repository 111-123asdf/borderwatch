class_name ArenaRuleDeck
extends RefCounted

# Compatible costs are explicit: e.g. a free gate only makes sense with a wall.
const BLESSINGS := {
	"reform": ["塔与驻军", "整备换阵", "整备卖塔，返还 100% 实付金币。", "prep_refund", ["wave_build_lock"]],
	"relay": ["英雄", "两地接应", "整备设两旗，每波可从旗旁转移一次。", "relay", ["handoff","one_way"]],
	"riposte": ["英雄", "回马一击", "把拦住的敌人推回最多 180，撞敌停顿 0.8 秒。", "riposte", ["trade_strike"]],
	"wall": ["核心", "垒墙反推", "升起 300 耐久的墙，手动收墙反推 100。", "wall", ["pledge","open_gate"]],
	"beacon": ["核心", "烽火齐射", "指定路面，四秒内落下三发 70 法伤烽火弹。", "beacon", ["expose_gate"]],
	"bounty": ["军费", "前线悬赏", "在标线前击杀三名前锋，另奖 80 金。", "bounty", ["stake","waive"]],
	"chest": ["军费", "随军钱箱", "存三笔领 1.5 倍，五笔领 2 倍，可提前收箱。", "chest", ["risk_chest"]],
	"lure": ["敌军与波次", "诱敌合流", "整备选南北一路，普通主队沿选中路进军。", "lure", ["flank","vanguard"]],
	"bridge": ["敌军与波次", "定桥迎敌", "整备指定西南桥，整波走长路或短路。", "bridge", ["fixed_bridge"]],
	"battery": ["塔与驻军", "借台齐射", "让一座弓塔或法师塔从另一座的射口开火。", "battery", ["cede_arc","alternate"]],
	"muster": ["塔与驻军", "两营会师", "将一营的整队士兵派往另一营的旗位。", "muster", ["march"]],
	"mark": ["塔与驻军", "亲自点名", "普攻点名精英，自动塔对它增伤 60%。", "mark", ["focus"]],
}
const COSTS := {
	"wave_build_lock":"开波后不能建塔、升级或卖塔。",
	"handoff":"放开拦截目标，原地交接 1.2 秒。",
	"one_way":"须在甲旗开波，只能从甲旗去乙旗。",
	"trade_strike":"换掉这次普攻伤害。每六秒一次，每名敌人一次。",
	"pledge":"押 75 核心耐久，墙破则损失。最多守十秒。",
	"open_gate":"整备指定一路敞开，该路没有墙和反推。",
	"expose_gate":"开炮四秒内首次漏怪，核心额外损失 40。",
	"stake":"签约押 60 金，任一前锋越线即失约。",
	"waive":"签约后让出三名前锋的基础击杀赏金。",
	"risk_chest":"同路有主队触核，未收的钱箱全部丢失。",
	"flank":"所有非首领精英开波时一起从另一路出场。",
	"vanguard":"前三名普通前锋在最早的原定时刻一起出场。",
	"fixed_bridge":"开波后不能临时改桥。",
	"cede_arc":"供火塔放弃原位射界，接收塔照常开火。",
	"alternate":"借射后接收塔让出下一次有效射击，再次借射须等它装填。",
	"march":"整队步行，行军时无法接敌，阵亡从本营补员。",
	"focus":"标记在射程内时，自动塔放过其余目标。",
}

var seen := {}

static func card(id: String, cost: String) -> Dictionary:
	var row: Array = BLESSINGS[id]
	return {"id":id, "name":row[1], "blessing_id":row[3], "curse_id":cost,
		"blessing":row[2], "curse":COSTS[cost], "category":row[0]}

func draw(game: ArenaGame) -> Array[Dictionary]:
	var candidates: Dictionary = {}
	var packets := game.wave_packets(game.wave_pattern())
	for id: String in BLESSINGS:
		var row: Array = BLESSINGS[id]
		if game.has_defense_effect(row[3]): continue
		var costs: Array = []
		for cost: String in row[4]:
			if game.orders.available(id,cost,packets):
				costs.append(cost)
		if not costs.is_empty():
			candidates[id] = costs
	var offers: Array[Dictionary] = []
	while offers.size()<3 and not candidates.is_empty():
		var ids := candidates.keys().filter(func(id): return not seen.has(id))
		if ids.is_empty(): ids = candidates.keys()
		var groups := {}
		for id in ids:
			var category: String = BLESSINGS[id][0]
			if not groups.has(category): groups[category] = []
			groups[category].append(id)
		var group: Array = groups[groups.keys()[game.rng.randi_range(0,groups.size()-1)]]
		var id: String = group[game.rng.randi_range(0,group.size()-1)]
		var costs: Array = candidates[id]
		offers.append(card(id,costs[game.rng.randi_range(0,costs.size()-1)]))
		candidates.erase(id)
		seen[id] = true
	return offers
