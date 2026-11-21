class_name ArenaPassives
extends RefCounted
# v0.20 passive prototype: event + action cards, shared across heroes.
# Data only; effects are read at runtime by ArenaGame/ArenaHero.

const MAX_RANK:=2

const CARDS: Array = [
	{"id":"chain","name":"连锁","type":"event","rarity":"common","desc":["击杀时对 60 范围造成 30 伤害","击杀时对 80 范围造成 45 伤害"],"color":Color("e8a45c")},
	{"id":"echo","name":"回响","type":"event","rarity":"common","desc":["击杀使 Q 冷却 −1s","击杀使 Q 冷却 −1.5s"],"color":Color("7fc8e8")},
	{"id":"combo","name":"连击","type":"event","rarity":"common","desc":["连续命中同一目标，每层 +6% 伤害，最多 5 层","每层 +8% 伤害"],"color":Color("d8b46a")},
	{"id":"break","name":"破势","type":"event","rarity":"rare","desc":["命中被减速目标时 +20% 伤害","+30% 伤害"],"color":Color("9fd8f0")},
	{"id":"charge","name":"充能","type":"event","rarity":"rare","desc":["击杀使 E 冷却 −2s","击杀使 E 冷却 −3s"],"color":Color("c5a4ff")},
	{"id":"rebuke","name":"反震","type":"event","rarity":"rare","desc":["受击时对周围 80 造成 20 伤害（1s 一次）","造成 30 伤害"],"color":Color("e07a6a")},
	{"id":"desperate","name":"背水","type":"event","rarity":"rare","desc":["生命 <40% 时伤害 +30%","生命 <50% 时伤害 +40%"],"color":Color("d05a5a")},
	{"id":"sweep","name":"三段斩","type":"action","rarity":"rare","desc":["每第 3 次普攻对目标 90 范围造成 80% 伤害","范围 120、100% 伤害"],"color":Color("e2a34f")},
	{"id":"icetrace","name":"冰痕","type":"action","rarity":"rare","desc":["Q 命中后留下 2s 霜区，每秒 10 伤害","每秒 15 伤害"],"color":Color("8fd0e8")},
	{"id":"doublecast","name":"双发","type":"action","rarity":"epic","desc":["E 后 1.5s 内 Q 伤害 +40%","+60%"],"color":Color("caa4ff")},
	{"id":"windup","name":"蓄力","type":"action","rarity":"epic","desc":["按住普攻 0.8s 后下一击 220% 并击退","280%"],"color":Color("f0c26a")},
	{"id":"afterimage","name":"残影","type":"action","rarity":"epic","desc":["翻滚后留下 1.5s 减速区（半径 80）","半径 110"],"color":Color("9ce7be")},
]
const RARITY_WEIGHT := {"common":6.0,"rare":3.0,"epic":1.0}

static func card(id: String) -> Dictionary:
	for entry in CARDS:
		if str(entry.id)==id:return entry
	return {}

static func max_rank(id: String) -> int:
	return MAX_RANK

static func weight(id: String) -> float:
	return float(RARITY_WEIGHT.get(str(card(id).get("rarity","common")),1.0))

static func draw(rng: RandomNumberGenerator,ranks: Dictionary,count: int) -> Array[String]:
	var pool: Array[String]=[]
	for entry in CARDS:
		var id: String=str(entry.id)
		if int(ranks.get(id,0))<MAX_RANK:pool.append(id)
	var result: Array[String]=[]
	while not pool.is_empty() and result.size()<count:
		var total:=0.0
		for id in pool: total+=weight(id)
		var roll:=rng.randf()*total
		var picked: String=pool[0]
		for id in pool:
			roll-=weight(id)
			if roll<=0.0:picked=id;break
		result.append(picked);pool.erase(picked)
	return result
