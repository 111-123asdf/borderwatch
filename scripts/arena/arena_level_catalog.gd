class_name ArenaLevelCatalog
extends RefCounted
const IDS := ["forest","creek","ruins",ArenaSaltport.ID]
const SIZE := Vector2(1600,900)
# Campaign geography is independent of battlefield roads and art. Future regions add nodes here.
const WORLD_NODES:={
	"forest":{"region":"forest_frontier","position":Vector2(400,558)},
	"creek":{"region":"forest_frontier","position":Vector2(688,432)},
	"ruins":{"region":"arcane_ruins","position":Vector2(1240,620)},
	"saltport":{"region":"salt_coast","position":Vector2(951,680)}
}
static func definition(key: String) -> Dictionary:
	if key==ArenaSaltport.ID:return ArenaSaltport.definition()
	if key=="ruins":
		var ruins: Dictionary={"id":"ruins","name":"紫雾遗迹 · 星陨古殿","story":"调度吊桥，借交叉火力守住星陨殿。","world_region":"arcane_ruins","biome":"ruins",
			"map_art":"res://assets/v017/map_ruins.png","preview_art":"res://assets/v017/map_ruins.png",
			"perk_mode":"keystone","boss":true,"boss_kind":"colossus","waves":8,"size":Vector2(2000,1125),"core":Vector2(1120,560),"hero_spawn":Vector2(1030,600),
			"routes":[
				[Vector2(-30,180),Vector2(220,180),Vector2(360,320),Vector2(600,320),Vector2(680,160),Vector2(840,160),Vector2(900,350),Vector2(760,440),Vector2(860,560),Vector2(1120,560)],
				[Vector2(-30,950),Vector2(240,950),Vector2(360,800),Vector2(620,800),Vector2(700,960),Vector2(950,960),Vector2(1040,790),Vector2(920,700),Vector2(860,560),Vector2(1120,560)],
				[Vector2(2030,920),Vector2(1770,920),Vector2(1650,750),Vector2(1460,750),Vector2(1370,940),Vector2(1240,940),Vector2(1230,770),Vector2(1380,700),Vector2(1380,560),Vector2(1120,560)],
				[Vector2(2030,170),Vector2(1800,170),Vector2(1680,330),Vector2(1450,330),Vector2(1380,440),Vector2(1380,560),Vector2(1120,560)]],
			"bridge_gate":{"point":Vector2(480,800),"route_id":1,"fork":Vector2(360,800),
				"detour":[Vector2(-30,950),Vector2(240,950),Vector2(360,800),Vector2(220,660),Vector2(350,530),Vector2(640,530),Vector2(700,700),Vector2(620,800),Vector2(700,960),Vector2(950,960),Vector2(1040,790),Vector2(920,700),Vector2(860,560),Vector2(1120,560)]},
			"sites":[Vector2(180,300),Vector2(400,210),Vector2(580,455),Vector2(750,280),Vector2(990,275),Vector2(1000,450),Vector2(180,815),Vector2(405,940),Vector2(575,665),Vector2(800,835),Vector2(1250,640),Vector2(1500,590),Vector2(1560,430),Vector2(1600,870),Vector2(1360,1030),Vector2(1490,210),Vector2(1870,310),Vector2(1870,810)],
			"site_traits":["highground","choke","choke","highground","highground","conduit","highground","choke","choke","highground","conduit","conduit","choke","highground","choke","conduit","highground","choke"],
			"site_roles":["西北入弯","北侧回弯","绕行交叉射界","北环内侧","北环折返","核心西侧","西南前哨","吊桥分流","绕行内湾","南环内侧","南环汇防","核心东侧","破障前沿","东南回弯","南环长线","裂隙前哨","东北入口","东南入口"],
			"altars":[Vector2(1120,670)],
			"braziers":[Vector2(540,20),Vector2(373,1002),Vector2(1688,36),Vector2(1634,932)],
			"breach":{"point":Vector2(1550,330),"guard":Vector2(1570,285),"route_id":3,"wave":4},
			"locked_sites":[10,15],"locked_prices":{"10":180,"15":220},"locked_site_price":200,
			"blocked":[Rect2(430,50,120,80),Rect2(960,80,70,75)],
			"pool":[["construct_hound","astral_prism"],["rune_warden","astral_prism","rift_bomber"],["construct_hound","rune_warden","void_harvester"]],
			"preview_enemies":["construct_hound","rune_warden","astral_prism","colossus"],
			"towers":{"storm":1,"lens":1,"snare":1,"archer":1,"barracks":1,"mage":1,"cannon":1}}
		var terrain_file:=FileAccess.open("res://assets/v017/terrain_blocks.json",FileAccess.READ)
		if terrain_file!=null:
			var rectangles: Array=JSON.parse_string(terrain_file.get_as_text())
			for rect in rectangles:ruins.blocked.append(Rect2(float(rect[0]),float(rect[1]),float(rect[2]),float(rect[3])))
		return ruins
	if key=="creek":
		return {"id":"creek","name":"溪谷驿站","story":"两座桥，一道防线。","tagline":"双路防空 · 暗钢犀牛 · 双头巨魔","world_region":"forest_frontier","biome":"creek","map_art":"res://assets/v09/map_creek.png","boss":true,"boss_kind":"two_headed_troll","boss_in_wave":true,"waves":10,"core":Vector2(1510,540),"hero_spawn":Vector2(1390,565),
			"routes":[[Vector2(-30,190),Vector2(230,190),Vector2(350,350),Vector2(590,350),Vector2(640,185),Vector2(990,185),Vector2(1110,390),Vector2(1040,510),Vector2(1240,540),Vector2(1510,540)],
				[Vector2(320,930),Vector2(320,750),Vector2(500,640),Vector2(780,640),Vector2(970,700),Vector2(1130,570),Vector2(1390,540),Vector2(1510,540)]],
			"sites":[Vector2(170,315),Vector2(400,230),Vector2(615,470),Vector2(825,305),Vector2(1210,385),Vector2(195,770),Vector2(475,770),Vector2(945,500),Vector2(1050,775),Vector2(1375,670)],
			"site_roles":["西侧入口","林间回弯","长路拦截","北桥东岸","汇合前沿","南侧入口","南路转弯","溪岸交叉射界","短路后段","终点回防"],
			"locked_sites":[9],"locked_site_price":200,
			"blocked":[Rect2(710,0,85,120),Rect2(710,255,85,150),Rect2(755,405,95,125),Rect2(815,530,85,70),Rect2(900,735,95,165),Rect2(1180,35,190,120),Rect2(50,610,105,130)],
			"water_rects":[Rect2(710,0,85,120),Rect2(710,255,85,150),Rect2(755,405,95,125),Rect2(815,530,85,70),Rect2(900,735,95,165)],
			"bridges":[Vector2(750,185),Vector2(875,668)],
			"pool":[["pigsoldier","throat_cutter","scout_vulture"],["tusk_fighter","skunk_bombardier","bear_woodsman"],["bear_vanguard","darksteel_guard","two_headed_troll"]],
			"preview_enemies":["throat_cutter","scout_vulture","darksteel_guard","two_headed_troll"],
			"towers":{"storm":1,"lens":1,"snare":1,"archer":1,"barracks":1,"mage":1,"cannon":1}}
	return {"id":"forest","name":"边境林地","story":"守住林间最后的微光。","tagline":"单路教学 · 野兽军团先锋","world_region":"forest_frontier","biome":"woodland","map_art":"res://assets/v09/map_forest.png","boss":false,"waves":8,"core":Vector2(1510,655),"hero_spawn":Vector2(1375,615),
		"routes":[[Vector2(-30,270),Vector2(220,270),Vector2(355,415),Vector2(580,415),Vector2(700,265),Vector2(940,265),Vector2(1080,490),Vector2(1260,490),Vector2(1375,655),Vector2(1510,655)]],
		"sites":[Vector2(175,385),Vector2(375,290),Vector2(560,530),Vector2(730,385),Vector2(900,405),Vector2(1100,350),Vector2(1250,625),Vector2(1430,485)],
		"site_roles":["入口消耗","首弯交战","前段拦截","中段交叉射界","侧翼集火","转弯控制","末段拦截","终点保险"],
		"locked_sites":[7],"locked_site_price":200,
		"blocked":[Rect2(50,490,120,135),Rect2(820,590,170,160),Rect2(1100,40,130,125)],
		"pool":[["pigsoldier","rottooth_hyena"],["pigsoldier","tusk_fighter","dreadeye_viper"],["tusk_fighter","turtle_shaman","bear_vanguard"]],
		"preview_enemies":["pigsoldier","tusk_fighter","dreadeye_viper","bear_vanguard"],
		"towers":{"storm":1,"lens":1,"snare":1,"archer":1,"barracks":1,"mage":3,"cannon":5}}
const HEAVY_ARMOUR:=0.4
const HIGH_RESIST:=0.4
static func total_waves(stage: String) -> int:
	return int(definition(stage).get("waves",8))
static func wave(stage: String,number: int) -> Dictionary:
	if stage==ArenaSaltport.ID:return ArenaSaltport.wave(number)
	# Authored teaching beats and alternating lane pressure, not decorative spawn randomness.
	# Group: [kind, count, elite_count] — the last elite_count units of the group are elites.
	var forest: Array=[
		{"units":[["pigsoldier",9]],"lead":0},
		{"units":[["pigsoldier",8],["rottooth_hyena",6]],"lead":0},
		{"units":[["pigsoldier",8],["tusk_fighter",4]],"lead":0},
		{"units":[["rottooth_hyena",8],["dreadeye_viper",4],["tusk_fighter",3,1]],"lead":0},
		{"units":[["pigsoldier",18,1],["rottooth_hyena",10]],"lead":0,"tag":"小怪潮"},
		{"units":[["tusk_fighter",6,1],["turtle_shaman",3],["dreadeye_viper",4]],"lead":0},
		{"units":[["pigsoldier",12],["bear_vanguard",3,1],["turtle_shaman",3]],"lead":0},
		{"units":[["rottooth_hyena",12],["tusk_fighter",6,1],["dreadeye_viper",5,1],["turtle_shaman",3],["bear_vanguard",3,2]],"lead":0,"tag":"精英压轴"}]
	var creek: Array=[
		{"units":[["pigsoldier",10],["throat_cutter",5],["dreadeye_viper",3]],"lead":0},
		{"units":[["rottooth_hyena",10],["scout_vulture",6]],"lead":1},
		{"units":[["tusk_fighter",6],["skunk_bombardier",4],["dreadeye_viper",4]],"lead":0},
		{"units":[["pigsoldier",18],["rottooth_hyena",14,1],["throat_cutter",6,1]],"lead":-1,"tag":"小怪潮"},
		{"units":[["bear_woodsman",5,1],["turtle_shaman",4],["scout_vulture",6]],"lead":1},
		{"units":[["darksteel_boss",1],["tusk_fighter",6],["skunk_bombardier",4,1],["dreadeye_viper",4]],"lead":0,"tag":"小首领来袭",
			"schedule":[["tusk_fighter",6,0,0,0.4,1.3],["dreadeye_viper",4,0,1,1.2,1.6],["darksteel_boss",1,0,0,3.2,0.0],["skunk_bombardier",2,0,0,5.2,2.2],["skunk_bombardier",2,1,1,6.0,2.2]]},
		{"units":[["scout_vulture",12,1],["skunk_bombardier",6,1],["throat_cutter",8],["turtle_shaman",3]],"lead":-1},
		{"units":[["bear_vanguard",5,1],["bear_woodsman",5,1],["darksteel_guard",2],["turtle_shaman",4]],"lead":0},
		{"units":[["pigsoldier",20],["rottooth_hyena",16,1],["throat_cutter",8,1],["scout_vulture",10,1],["dreadeye_viper",6],["skunk_bombardier",5,1]],"lead":-1,"tag":"大怪潮"},
		{"units":[["two_headed_troll",1],["bear_vanguard",4,1],["turtle_shaman",4,1],["dreadeye_viper",6],["scout_vulture",8],["skunk_bombardier",4]],"lead":-1,"tag":"关底首领决战",
			"schedule":[["bear_vanguard",4,1,0,0.4,2.1],["scout_vulture",4,0,0,1.0,1.6],["scout_vulture",4,0,1,2.2,1.6],["two_headed_troll",1,0,0,3.2,0.0],["turtle_shaman",4,1,0,4.8,2.2],["dreadeye_viper",6,0,1,4.0,1.7],["skunk_bombardier",2,0,0,7.5,2.4],["skunk_bombardier",2,0,1,8.5,2.4]]}]
	var ruins: Array=[
		{"units":[["construct_hound",9],["astral_prism",3]],"lead":0,"route_pool":[0,0,0,1]},
		{"units":[["construct_hound",10],["rune_warden",4]],"lead":1,"route_pool":[1,1,0,1]},
		{"units":[["construct_hound",8],["astral_prism",7],["rift_bomber",3]],"lead":2,"route_pool":[2,2,1,0]},
		{"units":[["rune_warden",6,1],["construct_hound",12,1],["astral_prism",6]],"lead":-1,"route_pool":[0,2,1]},
		{"units":[["construct_hound",16,1],["rift_bomber",6,1],["rune_warden",4],["astral_prism",5]],"lead":3,"route_pool":[3,0,1,2,3]},
		{"units":[["rune_warden",8,1],["void_harvester",3,1],["astral_prism",8,1]],"lead":-1,"route_pool":[0,1,2,3]},
		{"units":[["construct_hound",18,1],["rift_bomber",8,1],["rune_warden",8,1],["void_harvester",2,1]],"lead":-1,"route_pool":[0,1,2,3]},
		{"units":[["construct_hound",20,1],["rune_warden",10,1],["astral_prism",8,1],["rift_bomber",10,1]],"lead":-1,"route_pool":[0,1,2,3]}]
	var bank: Array = ruins if stage=="ruins" else (creek if stage=="creek" else forest)
	return bank[clampi(number-1,0,bank.size()-1)].duplicate(true)
static func wave_profile(stage: String,number: int,pattern: Dictionary={}) -> Dictionary:
	if pattern.is_empty(): pattern=wave(stage,number)
	var scale:=1.0+0.11*maxi(0,number-1)
	var total:=0.0
	var non_boss:=0.0
	var heavy:=0.0
	var high_res:=0.0
	var elites:=0
	var count:=0
	var has_flying:=false
	var has_boss:=false
	var has_mini_boss:=false
	for group in pattern.units:
		var kind:=str(group[0]);var amount:=int(group[1]);var elite_count:=int(group[2]) if group.size()>2 else 0
		var data:=ArenaDefinitions.enemy(kind)
		if ArenaDefinitions.is_flying_kind(kind):has_flying=true
		if ArenaDefinitions.is_boss_kind(kind):has_boss=true
		if ArenaDefinitions.is_mini_boss_kind(kind):has_mini_boss=true
		for unit in range(amount):
			var elite:=unit>=amount-elite_count
			var health:=float(data.health)*scale*(1.65 if elite else 1.0)
			total+=health;count+=1
			if not ArenaDefinitions.is_boss_kind(kind):non_boss+=health
			if float(data.armour)>=HEAVY_ARMOUR:heavy+=health
			if float(data.resistance)>=HIGH_RESIST:high_res+=health
			if elite:elites+=1
	var def:=definition(stage)
	if bool(def.get("boss",false)) and not def.get("boss_in_wave",false) and number==total_waves(stage):
		var boss_kind: String=str(def.get("boss_kind","moth"))
		var boss:=ArenaDefinitions.enemy(boss_kind);var health:=float(boss.health)*scale
		total+=health;count+=1;has_boss=true
		if float(boss.armour)>=HEAVY_ARMOUR:heavy+=health
		if float(boss.resistance)>=HIGH_RESIST:high_res+=health
	return {"count":count,"hp":total,"non_boss":non_boss,"heavy":heavy/maxf(total,1.0),"high_res":high_res/maxf(total,1.0),"elites":elites,"has_flying":has_flying,"has_boss":has_boss,"has_mini_boss":has_mini_boss,"tag":str(pattern.get("tag",""))}
static func elite_kinds(stage: String,number: int) -> Array[String]:
	var result: Array[String]=[]
	for group in wave(stage,number).units:
		var elite_count:=int(group[2]) if group.size()>2 else 0
		for index in range(elite_count):result.append(str(group[0]))
	return result
static func curve(points: Array) -> Curve2D:
	var result:=Curve2D.new()
	result.bake_interval=4.0
	for index in range(points.size()):
		var previous: Vector2=points[maxi(0,index-1)]
		var next: Vector2=points[mini(points.size()-1,index+1)]
		var tangent: Vector2=(next-previous).normalized()*minf(previous.distance_to(points[index]),next.distance_to(points[index]))*0.23
		result.add_point(points[index],-tangent,tangent)
	return result
