class_name ArenaDefinitions
extends RefCounted
const HERO_IDS := ["lord","druid","healer","werewolf","gunner"]
const HERO_ALIASES := {"knight":"lord","mage":"healer","longbow":"werewolf","ranger":"gunner"}
const DEFAULT_TOWERS := ["archer","mage","cannon","barracks"]
const TOWER_IDS := ["archer","mage","cannon","barracks","storm","lens","snare"]
const LOADOUT_LIMIT := 4
const HEROES := {
	"lord":{"name":"领主 冥翎","health":420.0,"speed":188.0,"damage":18.0,"interval":1.05,"reach":90.0,"type":0,"block":3,"small_cd":7.0,"ultimate_cd":28.0,"small":"血剑重斩","ultimate":"血棘圣盾","trait":"拦截时近战减伤20%","colour":Color("bd4b4b")},
	"druid":{"name":"德鲁伊","health":185.0,"speed":210.0,"damage":20.0,"interval":0.85,"reach":255.0,"type":1,"block":1,"small_cd":7.0,"ultimate_cd":28.0,"small":"自然号令","ultimate":"野性狂化","trait":"常驻冰蓝狼与赤红狼双跟班","colour":Color("78c264")},
	"healer":{"name":"爱神","health":170.0,"speed":212.0,"damage":15.0,"interval":0.80,"reach":275.0,"type":1,"block":1,"small_cd":8.0,"ultimate_cd":26.0,"small":"花灵祝祷","ultimate":"圣泉绽放","trait":"附近友方士兵攻速常驻+10%","colour":Color("f29db8")},
	"werewolf":{"name":"狼王 凛风","health":250.0,"speed":218.0,"damage":28.0,"interval":0.78,"reach":92.0,"type":0,"block":2,"small_cd":9.0,"ultimate_cd":30.0,"small":"霜爪嗜血","ultimate":"狼王狂化","trait":"普攻附带15%短暂寒霜减速","colour":Color("7cc8f2")},
	"gunner":{"name":"星衡","health":145.0,"speed":250.0,"damage":32.0,"interval":0.50,"reach":330.0,"type":0,"block":1,"small_cd":4.5,"ultimate_cd":24.0,"small":"战术滑步","ultimate":"超载律动","trait":"全游最高移速，翻滚后下发普攻2倍必爆贯穿","colour":Color("5896e8")}
}
const TOWERS := {
	"archer":{"name":"弓箭塔","cost":70,"damage":23.0,"interval":0.8,"reach":240.0,"type":0,"colour":Color("a7c87b"),"description":"快速物理射击"},
	"mage":{"name":"法师塔","cost":100,"damage":40.0,"interval":1.15,"reach":220.0,"type":1,"colour":Color("c5a4ff"),"description":"法术攻击，克制重甲"},
	"cannon":{"name":"火炮塔","cost":120,"damage":57.0,"interval":2.2,"reach":265.0,"type":0,"colour":Color("e4af73"),"description":"范围物理轰击"},
	"barracks":{"name":"兵营","cost":80,"damage":7.0,"interval":1.0,"reach":145.0,"type":0,"colour":Color("d8806c"),"description":"三名士兵拦截道路"},
	"storm":{"name":"跃电塔","cost":105,"damage":28.0,"interval":1.35,"reach":205.0,"type":1,"colour":Color("77dddc"),"description":"雷弧连击至多三敌，每跳保留七成伤害"},
	"lens":{"name":"聚光塔","cost":125,"damage":17.0,"interval":0.65,"reach":250.0,"type":1,"colour":Color("f4ce72"),"description":"同敌每击增伤35%，最多四层，换敌清零"},
	"snare":{"name":"绊索工坊","cost":85,"damage":36.0,"interval":3.2,"reach":210.0,"type":0,"colour":Color("bfcd86"),"description":"路面布索，触发后范围减速，移索需1.2秒"}
}
const ENEMIES := {
	"fiddler":{"name":"招潮蟹","health":76.0,"speed":82.0,"damage":11.0,"type":0,"armour":0.08,"resistance":0.08,"capacity":1,"gold":13,"xp":10},
	"mudshrimp":{"name":"跳滩虾","health":122.0,"speed":95.0,"damage":16.0,"type":0,"armour":0.04,"resistance":0.29,"capacity":1,"gold":15,"xp":11},
	"salt_hermit":{"name":"负盐寄居蟹","health":232.0,"speed":56.0,"damage":23.0,"type":0,"armour":0.58,"resistance":0.07,"capacity":2,"gold":25,"xp":16},
	"anchor_crab":{"name":"沉锚巨蟹","health":3300.0,"speed":47.0,"damage":26.0,"type":0,"armour":0.30,"resistance":0.21,"capacity":99,"gold":170,"xp":104,"boss":true},
	"fox":{"name":"炭狐","health":65.0,"speed":73.0,"damage":11.0,"type":0,"armour":0.0,"resistance":0.0,"capacity":1,"gold":13,"xp":9},
	"brute":{"name":"苔甲守卫","health":185.0,"speed":40.0,"damage":19.0,"type":0,"armour":0.55,"resistance":0.0,"capacity":2,"gold":23,"xp":15},
	"wisp":{"name":"林间幽光","health":95.0,"speed":49.0,"damage":10.0,"type":1,"armour":0.0,"resistance":0.5,"capacity":1,"gold":17,"xp":11},
	"spearman":{"name":"棘木投矛手","health":105.0,"speed":52.0,"damage":15.0,"type":0,"armour":0.15,"resistance":0.0,"capacity":1,"gold":17,"xp":12},
	"spore":{"name":"孢囊兽","health":150.0,"speed":45.0,"damage":16.0,"type":1,"armour":0.0,"resistance":0.2,"capacity":1,"gold":20,"xp":14},
	"moth":{"name":"暮林巨蛾","health":3100.0,"speed":26.0,"damage":17.0,"type":1,"armour":0.15,"resistance":0.15,"capacity":99,"gold":150,"xp":100},
	"construct_hound":{"name":"裂隙猎犬","health":72.0,"speed":92.0,"damage":12.0,"type":0,"armour":0.05,"resistance":0.0,"capacity":1,"gold":14,"xp":10},
	"rune_warden":{"name":"符文重盾傀儡","health":245.0,"speed":38.0,"damage":22.0,"type":0,"armour":0.58,"resistance":0.05,"capacity":2,"gold":26,"xp":17},
	"astral_prism":{"name":"星界棱镜","health":125.0,"speed":48.0,"damage":14.0,"type":1,"armour":0.0,"resistance":0.52,"capacity":1,"gold":19,"xp":13},
	"rift_bomber":{"name":"坍缩魔芯","health":135.0,"speed":55.0,"damage":18.0,"type":1,"armour":0.15,"resistance":0.25,"capacity":1,"gold":21,"xp":14},
	"void_harvester":{"name":"虚空收割者","health":460.0,"speed":62.0,"damage":27.0,"type":0,"armour":0.28,"resistance":0.28,"capacity":99,"gold":48,"xp":32},
	"breacher":{"name":"裂隙破障者","health":900.0,"speed":0.0,"damage":22.0,"type":0,"armour":0.35,"resistance":0.05,"capacity":99,"gold":40,"xp":30},
	"colossus":{"name":"星界巨像","health":4200.0,"speed":25.0,"damage":24.0,"type":1,"armour":0.22,"resistance":0.22,"capacity":99,"gold":200,"xp":120},
	"pigsoldier":{"name":"猪头兵","health":62.0,"speed":72.0,"damage":10.0,"type":0,"armour":0.0,"resistance":0.0,"capacity":1,"gold":12,"xp":9,"trait":"野兽主力杂兵，成群沿路推进"},
	"rottooth_hyena":{"name":"腐牙鬣狗","health":54.0,"speed":104.0,"damage":11.0,"type":0,"armour":0.0,"resistance":0.0,"capacity":1,"gold":13,"xp":10,"trait":"高速突袭野兽，撕咬附带流血"},
	"tusk_fighter":{"name":"獠牙斗士","health":175.0,"speed":48.0,"damage":18.0,"type":0,"armour":0.48,"resistance":0.0,"capacity":2,"gold":22,"xp":15,"trait":"重甲步兵，需法师塔或破甲克制"},
	"dreadeye_viper":{"name":"骸眼毒蛇","health":96.0,"speed":54.0,"damage":17.0,"type":0,"armour":0.05,"resistance":0.15,"capacity":1,"gold":19,"xp":13,"trait":"红线锁定高速毒箭（Space闪避），命中中毒减速"},
	"turtle_shaman":{"name":"乌龟萨满","health":135.0,"speed":44.0,"damage":12.0,"type":1,"armour":0.10,"resistance":0.52,"capacity":1,"gold":23,"xp":15,"trait":"高法抗萨满，吟唱群体治疗并驱散减速（眩晕可打断）"},
	"bear_vanguard":{"name":"熊先锋","health":310.0,"speed":40.0,"damage":24.0,"type":0,"armour":0.52,"resistance":0.10,"capacity":3,"gold":34,"xp":22,"trait":"重装推线巨熊，蓄力震地伤士兵与英雄并减速"},
	"throat_cutter":{"name":"割喉鼠","health":88.0,"speed":96.0,"damage":19.0,"type":0,"armour":0.05,"resistance":0.10,"capacity":1,"gold":17,"xp":13,"trait":"首次被士兵拦截会暗影闪身绕过，攻击附流血"},
	"scout_vulture":{"name":"侦察秃鹫","health":86.0,"speed":84.0,"damage":13.0,"type":0,"armour":0.0,"resistance":0.15,"capacity":99,"gold":18,"xp":13,"flying":true,"trait":"飞行单位：无视地面阻挡/火炮/近战普攻，需防空"},
	"skunk_bombardier":{"name":"臭鼬投弹手","health":125.0,"speed":50.0,"damage":15.0,"type":1,"armour":0.10,"resistance":0.20,"capacity":1,"gold":22,"xp":15,"trait":"抛掷毒雾弹：英雄减速中毒，附近塔攻速-35%"},
	"bear_woodsman":{"name":"熊樵夫","health":260.0,"speed":46.0,"damage":23.0,"type":0,"armour":0.30,"resistance":0.15,"capacity":2,"gold":28,"xp":19,"trait":"半血以下狂暴（移速攻速飙升）并扇形顺劈拆兵营"},
	"darksteel_guard":{"name":"暗钢守卫","health":460.0,"speed":38.0,"damage":28.0,"type":0,"armour":0.65,"resistance":0.10,"capacity":99,"gold":42,"xp":28,"trait":"超高物甲推土犀牛，免疫击退，蓄力蛮撞震晕"},
	"darksteel_boss":{"name":"暗钢守卫统领","health":1450.0,"speed":38.0,"damage":30.0,"type":0,"armour":0.65,"resistance":0.10,"capacity":99,"gold":110,"xp":70,"mini_boss":true,"visual_kind":"darksteel_guard","trait":"第6波小首领：超高物甲、免疫击退、红眼冲锋蛮撞"},
	"two_headed_troll":{"name":"双头巨魔","health":4200.0,"speed":30.0,"damage":34.0,"type":0,"armour":0.25,"resistance":0.20,"capacity":99,"gold":220,"xp":130,"boss":true,"trait":"关底大首领：三阶段狂暴、巨木砸地、战吼召怪潮与自愈"}
}
static func is_valid_hero_id(key: String) -> bool:
	return HEROES.has(key) or HERO_ALIASES.has(key)
static func resolve_hero_id(key: String) -> String:
	if HEROES.has(key):return key
	return str(HERO_ALIASES.get(key,"lord"))
static func hero(key: String) -> Dictionary:
	return HEROES.get(resolve_hero_id(key),HEROES.lord).duplicate(true)
static func tower(key: String) -> Dictionary:
	return TOWERS.get(key,TOWERS.archer).duplicate(true)
static func enemy(key: String) -> Dictionary:
	return ENEMIES.get(key,ENEMIES.fox).duplicate(true)
static func is_flying_kind(key: String) -> bool:
	return bool(ENEMIES.get(key,{}).get("flying",false))
static func is_boss_kind(key: String) -> bool:
	return key in ["moth","colossus","anchor_crab","two_headed_troll"] or bool(ENEMIES.get(key,{}).get("boss",false))
static func is_mini_boss_kind(key: String) -> bool:
	return bool(ENEMIES.get(key,{}).get("mini_boss",false))
static func leak_damage(kind: String,elite := false) -> int:
	# Core damage is tiered by threat, not by raw spawn index; elites at least 24.
	var base: int=int({
		"fox":14,"wisp":14,"spearman":18,"spore":18,"brute":36,"captain":0,"moth":0,
		"construct_hound":14,"astral_prism":16,"rift_bomber":22,"rune_warden":36,"void_harvester":0,"colossus":0,
		"mudshrimp":24,"salt_hermit":34,"anchor_crab":0,
		"pigsoldier":12,"rottooth_hyena":14,"tusk_fighter":24,"dreadeye_viper":18,"turtle_shaman":20,"bear_vanguard":36,
		"throat_cutter":18,"scout_vulture":18,"skunk_bombardier":20,"bear_woodsman":30,"darksteel_guard":45,"darksteel_boss":120,"two_headed_troll":0
	}.get(kind,14))
	return maxi(base,24) if elite else base
static func skill_text(hero_id: String, slot: int) -> String:
	var id := resolve_hero_id(hero_id)
	if slot==0: return {"lord":"重挥血剑重创并短暂打断前方敌人","druid":"指挥冰火双狼集火目标并为双狼回血","healer":"轻伤周围敌人并赋予友军与防御塔攻速伤害祝福","werewolf":"5秒内攻速大幅提升且普攻附带吸血与冰溅","gunner":"短CD无敌滑步，下发普攻2倍必爆贯穿"}[id]
	return {"lord":"展开血棘盾幕获高额护盾、减伤并提升阻挡上限","druid":"双狼回满血、体型变大并狂暴强化7秒","healer":"5秒圣光花阵强力治疗自身与士兵（溢出转护盾）并加速防御塔","werewolf":"彻底变身巨狼8秒，高频大范围冰爪横扫并高额吸血","gunner":"超载6秒：刷新并减半滑步冷却，滑步后双发2倍贯穿爆裂弹"}[id]
