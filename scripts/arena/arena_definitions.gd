class_name ArenaDefinitions
extends RefCounted
const HERO_IDS := ["knight","ranger","mage"]
const TOWER_IDS := ["archer","mage","cannon","barracks"]
const HEROES := {
	"knight":{"name":"重剑骑士","health":320.0,"speed":195.0,"damage":42.0,"interval":0.8,"reach":88.0,"type":0,"block":3,"small_cd":8.0,"ultimate_cd":30.0,"small":"震地斩","ultimate":"守望战吼","trait":"拦截时近战减伤15%","colour":Color("bd5b55")},
	"ranger":{"name":"森林游侠","health":190.0,"speed":230.0,"damage":30.0,"interval":0.65,"reach":310.0,"type":0,"block":1,"small_cd":6.0,"ultimate_cd":28.0,"small":"掠影翻滚","ultimate":"万叶箭雨","trait":"每第三箭额外贯穿一人","colour":Color("9fbe75")},
	"mage":{"name":"星纹法师","health":170.0,"speed":205.0,"damage":33.0,"interval":0.9,"reach":285.0,"type":1,"block":1,"small_cd":9.0,"ultimate_cd":32.0,"small":"寒星霜环","ultimate":"星陨","trait":"普攻附加10%魔法易伤","colour":Color("b29ae1")}
}
const TOWERS := {
	"archer":{"name":"弓箭塔","cost":70,"damage":23.0,"interval":0.8,"reach":240.0,"type":0,"colour":Color("a7c87b"),"description":"快速物理射击"},
	"mage":{"name":"法师塔","cost":100,"damage":40.0,"interval":1.15,"reach":220.0,"type":1,"colour":Color("c5a4ff"),"description":"法术攻击，克制重甲"},
	"cannon":{"name":"火炮塔","cost":120,"damage":57.0,"interval":2.2,"reach":265.0,"type":0,"colour":Color("e4af73"),"description":"范围物理轰击"},
	"barracks":{"name":"兵营","cost":80,"damage":7.0,"interval":1.0,"reach":145.0,"type":0,"colour":Color("d8806c"),"description":"三名士兵拦截道路"}
}
const ENEMIES := {
	"fox":{"name":"炭狐","health":65.0,"speed":73.0,"damage":11.0,"type":0,"armour":0.0,"resistance":0.0,"capacity":1,"gold":13,"xp":9},
	"brute":{"name":"苔甲守卫","health":185.0,"speed":40.0,"damage":19.0,"type":0,"armour":0.55,"resistance":0.0,"capacity":2,"gold":23,"xp":15},
	"wisp":{"name":"林间幽光","health":95.0,"speed":49.0,"damage":10.0,"type":1,"armour":0.0,"resistance":0.5,"capacity":1,"gold":17,"xp":11},
	"spearman":{"name":"棘木投矛手","health":105.0,"speed":52.0,"damage":15.0,"type":0,"armour":0.15,"resistance":0.0,"capacity":1,"gold":17,"xp":12},
	"spore":{"name":"孢囊兽","health":150.0,"speed":45.0,"damage":16.0,"type":1,"armour":0.0,"resistance":0.2,"capacity":1,"gold":20,"xp":14},
	"moth":{"name":"暮林巨蛾","health":3100.0,"speed":26.0,"damage":17.0,"type":1,"armour":0.15,"resistance":0.15,"capacity":99,"gold":150,"xp":100}
}
const PERKS := {
	"power":{"name":"锋芒","text":"伤害 +12%","icon":"physical","max":3},
	"vitality":{"name":"坚韧","text":"生命 +12%","icon":"heart","max":3},
	"rapid":{"name":"疾攻","text":"普攻速度 +10%","icon":"physical","max":3},
	"haste":{"name":"轻步","text":"移动速度 +7%","icon":"move","max":3},
	"focus":{"name":"专注","text":"技能冷却 -8%","icon":"skill","max":3},
	"command":{"name":"共战","text":"附近塔与士兵伤害 +10%","icon":"flag","max":3},
	"small":{"name":"技艺","text":"强化本职小技能","icon":"skill","max":3},
	"ultimate":{"name":"觉醒","text":"强化本职大招","icon":"magic","max":3}
}
static func hero(key: String) -> Dictionary:
	return HEROES.get(key,HEROES.knight).duplicate(true)
static func tower(key: String) -> Dictionary:
	return TOWERS.get(key,TOWERS.archer).duplicate(true)
static func enemy(key: String) -> Dictionary:
	return ENEMIES.get(key,ENEMIES.fox).duplicate(true)
static func skill_text(hero_id: String, slot: int) -> String:
	if slot==0: return {"knight":"扇形重斩，短暂眩晕","ranger":"朝移动方向翻滚，短暂无敌","mage":"霜环造成法术伤害并减速"}[hero_id]
	return {"knight":"战吼强化附近英雄、士兵与塔","ranger":"向指定区域降下物理箭雨","mage":"星陨轰击指定区域，造成法术伤害"}[hero_id]
