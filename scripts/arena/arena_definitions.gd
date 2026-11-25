class_name ArenaDefinitions
extends RefCounted
const HERO_IDS := ["lord","druid","healer","werewolf","gunner"]
const HERO_ALIASES := {"knight":"lord","mage":"healer","longbow":"werewolf","ranger":"gunner"}
const DEFAULT_TOWERS := ["archer","mage","cannon","barracks"]
const TOWER_IDS := ["archer","mage","cannon","barracks","storm","lens","snare"]
const LOADOUT_LIMIT := 4
const HEROES := {
	"lord":{"name":"领主 冥翎","health":420.0,"speed":192.0,"damage":26.0,"interval":0.80,"reach":112.0,"type":0,"block":3,"small_cd":6.5,"ultimate_cd":24.0,"small":"血剑重斩","ultimate":"血棘圣盾","trait":"正面宽弧顺劈，高额霸体减伤，血剑破甲","colour":Color("bd4b4b")},
	"druid":{"name":"德鲁伊","health":200.0,"speed":212.0,"damage":25.0,"interval":0.76,"reach":280.0,"type":1,"block":1,"small_cd":6.5,"ultimate_cd":24.0,"small":"自然号令","ultimate":"野性狂化","trait":"72范围荆棘溅射法球，双狼随行穿越裂隙","colour":Color("78c264")},
	"healer":{"name":"爱神","health":190.0,"speed":215.0,"damage":21.0,"interval":0.72,"reach":295.0,"type":1,"block":1,"small_cd":7.0,"ultimate_cd":22.0,"small":"花灵祝祷","ultimate":"圣泉绽放","trait":"贯穿光弹，每4击迸发150范围炽焰新星并治愈友军","colour":Color("f29db8")},
	"werewolf":{"name":"狼王 凛风","health":270.0,"speed":222.0,"damage":31.0,"interval":0.68,"reach":108.0,"type":0,"block":2,"small_cd":8.0,"ultimate_cd":26.0,"small":"霜爪嗜血","ultimate":"狼王狂化","trait":"常态84范围霜爪顺劈与寒霜减速，狂化极速突袭","colour":Color("7cc8f2")},
	"gunner":{"name":"星衡","health":165.0,"speed":252.0,"damage":29.0,"interval":0.45,"reach":345.0,"type":0,"block":1,"small_cd":4.2,"ultimate_cd":22.0,"small":"战术滑步","ultimate":"超载律动","trait":"射程内流畅游射，普攻自带贯穿，滑步后强穿爆弹","colour":Color("5896e8")}
}
const TOWERS := {
	"archer":{"name":"弓箭塔","cost":70,"damage":16.0,"interval":0.85,"reach":250.0,"type":0,"colour":Color("a7c87b"),"description":"全自动贯穿并挂破绽(+28%英雄易伤)"},
	"mage":{"name":"法师塔","cost":100,"damage":24.0,"interval":1.20,"reach":225.0,"type":1,"colour":Color("c5a4ff"),"description":"全自动寒霜脉冲：范围减速并叠层冻结"},
	"cannon":{"name":"火炮塔","cost":120,"damage":34.0,"interval":2.15,"reach":265.0,"type":0,"colour":Color("e4af73"),"description":"全自动聚怪震荡：大范围击退与眩晕"},
	"barracks":{"name":"兵营","cost":80,"damage":7.0,"interval":1.0,"reach":155.0,"type":0,"colour":Color("d8806c"),"description":"三名高防盾卫拦截，周期升起减速屏障"},
	"storm":{"name":"跃电塔","cost":105,"damage":19.0,"interval":1.30,"reach":215.0,"type":1,"colour":Color("77dddc"),"description":"雷弧连击四敌并附带短暂麻痹打断"},
	"lens":{"name":"聚光塔","cost":125,"damage":14.0,"interval":0.68,"reach":255.0,"type":1,"colour":Color("f4ce72"),"description":"持续照射重甲与首领，大幅削甲减速"},
	"snare":{"name":"绊索工坊","cost":85,"damage":22.0,"interval":2.8,"reach":220.0,"type":0,"colour":Color("bfcd86"),"description":"自动追踪前锋铺设捕网，大范围强减速"}
}
const ENEMIES := {
	"murloc_hunter":{"name":"鱼人猎手","health":74.0,"speed":76.0,"damage":12.0,"type":0,"armour":0.05,"resistance":0.0,"capacity":1,"gold":13,"xp":10,"trait":"成群沿堤推进的深海鱼人，可从礁湾破浪突袭"},
	"tide_rider":{"name":"海潮骑手","health":92.0,"speed":112.0,"damage":14.0,"type":0,"armour":0.08,"resistance":0.10,"capacity":1,"gold":16,"xp":12,"trait":"踏浪高速突袭，浅滩潜泳时不可被士兵拦截"},
	"water_sprite":{"name":"水灵精","health":118.0,"speed":62.0,"damage":13.0,"type":1,"armour":0.0,"resistance":0.52,"capacity":1,"gold":18,"xp":13,"trait":"高法抗水元素，攻击溅水附带减速"},
	"storm_wyrm":{"name":"天雷雏龙","health":98.0,"speed":92.0,"damage":15.0,"type":1,"armour":0.0,"resistance":0.15,"capacity":99,"gold":20,"xp":14,"flying":true,"trait":"飞行单位：无视地面阻挡与火炮，低空电弧游射"},
	"tide_warrior":{"name":"海潮战士","health":185.0,"speed":54.0,"damage":19.0,"type":0,"armour":0.28,"resistance":0.05,"capacity":2,"gold":23,"xp":15,"trait":"中甲海族精锐，中程投掷鱼叉并善近身肉搏"},
	"wind_captain":{"name":"风校尉","health":165.0,"speed":84.0,"damage":21.0,"type":0,"armour":0.22,"resistance":0.12,"capacity":1,"gold":24,"xp":16,"trait":"疾风战将：首次被兵营拦截会疾风穿身一小段并附流血"},
	"conch_mage":{"name":"海螺法师","health":178.0,"speed":46.0,"damage":18.0,"type":1,"armour":0.52,"resistance":0.18,"capacity":2,"gold":26,"xp":17,"trait":"厚螺壳高物甲法系，远程施放古海法球逼出法师塔"},
	"water_elder":{"name":"水长老","health":162.0,"speed":45.0,"damage":14.0,"type":1,"armour":0.10,"resistance":0.54,"capacity":1,"gold":26,"xp":17,"trait":"高法抗水术士：吟唱水幕群体回血并驱散减速（眩晕可断）"},
	"tempest_elemental":{"name":"怒风怪","health":335.0,"speed":48.0,"damage":24.0,"type":1,"armour":0.18,"resistance":0.38,"capacity":3,"gold":36,"xp":23,"trait":"重型风暴元素：蓄力释青蓝旋风震击兵营与英雄并减速"},
	"bluegale":{"name":"蓝色风暴","health":240.0,"speed":52.0,"damage":20.0,"type":1,"armour":0.12,"resistance":0.45,"capacity":2,"gold":34,"xp":22,"trait":"深海指挥官：唤起雷云令周围海族加速+25%并落雷（灯塔强光可破）"},
	"bloodshell_crab":{"name":"狂暴螃蟹","health":480.0,"speed":39.0,"damage":28.0,"type":0,"armour":0.65,"resistance":0.10,"capacity":99,"gold":44,"xp":29,"trait":"超高物甲重蟹：免疫击退，双螯重砸震晕兵营与英雄"},
	"bloodshell_boss":{"name":"狂暴螃蟹统领","health":1550.0,"speed":38.0,"damage":32.0,"type":0,"armour":0.62,"resistance":0.12,"capacity":99,"gold":120,"xp":76,"mini_boss":true,"visual_kind":"bloodshell_crab","trait":"第3关末波小首领：超高物甲重蟹统领，双螯重砸震地"},
	"leviathan":{"name":"利维坦","health":4600.0,"speed":28.0,"damage":36.0,"type":1,"armour":0.24,"resistance":0.22,"capacity":99,"gold":240,"xp":145,"boss":true,"trait":"深渊关底大首领：定期伸出触手封锁2-3座防御塔，三阶段狂暴召潮"},
	"void_eyeling":{"name":"眼精","health":68.0,"speed":88.0,"damage":12.0,"type":1,"armour":0.0,"resistance":0.15,"capacity":1,"gold":11,"xp":9,"trait":"漂浮虚空集群，常由恶毒眼巢与还魂师持续产出"},
	"void_gazer":{"name":"虚空瞥视者","health":112.0,"speed":90.0,"damage":17.0,"type":1,"armour":0.0,"resistance":0.22,"capacity":99,"gold":21,"xp":14,"flying":true,"trait":"飞行单位：无视地面阻挡，高空掠袭发射虚空射线"},
	"twilight_harasser":{"name":"暮光骚扰者","health":132.0,"speed":76.0,"damage":18.0,"type":0,"armour":0.15,"resistance":0.20,"capacity":1,"gold":19,"xp":13,"trait":"暮光游击精锐：远射暗影镖，近身双刃快速连斩"},
	"spectral_cutter":{"name":"回魂割喉者","health":124.0,"speed":98.0,"damage":22.0,"type":0,"armour":0.08,"resistance":0.25,"capacity":1,"gold":21,"xp":14,"trait":"隐影刺客：首次遇兵营拦截会暗影闪步绕过，攻击附流血"},
	"twilight_avenger":{"name":"暮光复仇者","health":245.0,"speed":54.0,"damage":23.0,"type":0,"armour":0.48,"resistance":0.18,"capacity":2,"gold":28,"xp":18,"trait":"重甲暮光战士：阵亡时爆发紫雾诅咒冲击，重创周围小兵"},
	"avenger_rider":{"name":"复仇骑兵","health":260.0,"speed":96.0,"damage":24.0,"type":0,"armour":0.45,"resistance":0.12,"capacity":2,"gold":30,"xp":20,"trait":"高速重甲甲虫骑兵：疾驰冲击防线薄弱缺口"},
	"venom_spitter":{"name":"剧毒喷吐者","health":165.0,"speed":52.0,"damage":18.0,"type":1,"armour":0.12,"resistance":0.28,"capacity":1,"gold":25,"xp":17,"trait":"远程酸液破坏者：形成毒潭令英雄减速，附近防御塔攻速-35%"},
	"soul_reaver":{"name":"还魂师","health":185.0,"speed":48.0,"damage":16.0,"type":1,"armour":0.10,"resistance":0.54,"capacity":1,"gold":29,"xp":19,"trait":"高法抗召唤法师：定期唤出眼精并为周围友军施加虚空护盾"},
	"twilight_golem":{"name":"暮光傀儡","health":460.0,"speed":40.0,"damage":27.0,"type":0,"armour":0.60,"resistance":0.18,"capacity":99,"gold":42,"xp":28,"trait":"超重甲紫能石像：免疫击退，被击毁时爆发紫波眩晕近身士兵"},
	"vile_eyenest":{"name":"恶毒眼巢","health":340.0,"speed":42.0,"damage":20.0,"type":1,"armour":0.18,"resistance":0.38,"capacity":3,"gold":38,"xp":25,"trait":"悬浮产卵母体：持续孵化眼精并发射邪能光束"},
	"bloodsoil_behemoth":{"name":"血壤巨兽","health":560.0,"speed":38.0,"damage":32.0,"type":0,"armour":0.36,"resistance":0.26,"capacity":99,"gold":50,"xp":34,"trait":"巨型血壤重坦：蓄力砸地掀出水晶尖刺穿刺兵营与英雄"},
	"bloodsoil_boss":{"name":"血壤巨兽领主","health":1800.0,"speed":36.0,"damage":34.0,"type":0,"armour":0.34,"resistance":0.26,"capacity":99,"gold":140,"xp":90,"mini_boss":true,"visual_kind":"bloodsoil_behemoth","trait":"第5关末波小首领：血壤巨兽领主，大范围水晶地刺喷发"},
	"baj_nimen":{"name":"憎恶者巴杰尼蒙","health":5200.0,"speed":29.0,"damage":38.0,"type":1,"armour":0.26,"resistance":0.26,"capacity":99,"gold":280,"xp":175,"boss":true,"trait":"终局关底大首领：深渊蜈蚣法王，三阶段星陨紫电轰击、召怪与裂隙换道"},
	"fox":{"name":"炭狐","health":65.0,"speed":73.0,"damage":11.0,"type":0,"armour":0.0,"resistance":0.0,"capacity":1,"gold":13,"xp":9},
	"brute":{"name":"苔甲守卫","health":185.0,"speed":40.0,"damage":19.0,"type":0,"armour":0.55,"resistance":0.0,"capacity":2,"gold":23,"xp":15},
	"wisp":{"name":"林间幽光","health":95.0,"speed":49.0,"damage":10.0,"type":1,"armour":0.0,"resistance":0.5,"capacity":1,"gold":17,"xp":11},
	"spearman":{"name":"棘木投矛手","health":105.0,"speed":52.0,"damage":15.0,"type":0,"armour":0.15,"resistance":0.0,"capacity":1,"gold":17,"xp":12},
	"spore":{"name":"孢囊兽","health":150.0,"speed":45.0,"damage":16.0,"type":1,"armour":0.0,"resistance":0.2,"capacity":1,"gold":20,"xp":14},
	"moth":{"name":"暮林巨蛾","health":3100.0,"speed":26.0,"damage":17.0,"type":1,"armour":0.15,"resistance":0.15,"capacity":99,"gold":150,"xp":100},
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
	return key in ["moth","leviathan","baj_nimen"] or bool(ENEMIES.get(key,{}).get("boss",false))
static func is_mini_boss_kind(key: String) -> bool:
	return bool(ENEMIES.get(key,{}).get("mini_boss",false))
static func leak_damage(kind: String,elite := false) -> int:
	# Core damage is tiered by threat, not by raw spawn index; elites at least 24.
	var base: int=int({
		"fox":14,"wisp":14,"spearman":18,"spore":18,"brute":36,"captain":0,"moth":0,
		"murloc_hunter":14,"tide_rider":16,"water_sprite":18,"storm_wyrm":18,"tide_warrior":22,"wind_captain":20,
		"conch_mage":24,"water_elder":22,"tempest_elemental":32,"bluegale":28,"bloodshell_crab":42,"bloodshell_boss":120,"leviathan":0,
		"void_eyeling":12,"void_gazer":18,"twilight_harasser":18,"spectral_cutter":18,"twilight_avenger":24,"avenger_rider":24,
		"venom_spitter":20,"soul_reaver":22,"twilight_golem":42,"vile_eyenest":32,"bloodsoil_behemoth":48,"bloodsoil_boss":120,"baj_nimen":0,
		"pigsoldier":12,"rottooth_hyena":14,"tusk_fighter":24,"dreadeye_viper":18,"turtle_shaman":20,"bear_vanguard":36,
		"throat_cutter":18,"scout_vulture":18,"skunk_bombardier":20,"bear_woodsman":30,"darksteel_guard":45,"darksteel_boss":120,"two_headed_troll":0
	}.get(kind,14))
	return maxi(base,24) if elite else base
static func skill_text(hero_id: String, slot: int) -> String:
	var id := resolve_hero_id(hero_id)
	if slot==0: return {"lord":"重挥血剑重创并短暂打断前方敌人","druid":"指挥冰火双狼集火目标并为双狼回血","healer":"绽放圣火新星伤敌，并赋予友军与防御塔攻速伤害祝福","werewolf":"5秒内攻速大幅提升且普攻附带吸血与冰溅","gunner":"短CD无敌滑步，下发普攻强穿透并触发电弧爆裂"}[id]
	return {"lord":"展开血棘盾幕获高额护盾、减伤并高频反伤周围敌军","druid":"双狼回满血、体型变大并狂暴强化7秒","healer":"5秒圣泉不断迸发圣火新星烧敌，治疗自身(溢疗转盾)并加速全塔","werewolf":"彻底变身巨狼8秒，高频大范围冰爪横扫并高额吸血","gunner":"超载6秒：刷新并减半滑步冷却，滑步后双发强穿透爆裂弹"}[id]
