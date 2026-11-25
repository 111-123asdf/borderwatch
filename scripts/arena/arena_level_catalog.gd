class_name ArenaLevelCatalog
extends RefCounted
const IDS := ["forest","creek",ArenaSaltport.ID,"lighthouse","ruins","sanctum"]
const SIZE := Vector2(1600,900)
# Campaign geography is independent of battlefield roads and art. Future regions add nodes here.
const WORLD_NODES:={
	"forest":{"region":"forest_frontier","position":Vector2(215,615)},
	"creek":{"region":"forest_frontier","position":Vector2(432,418)},
	"saltport":{"region":"salt_coast","position":Vector2(692,648)},
	"lighthouse":{"region":"salt_coast","position":Vector2(968,668)},
	"ruins":{"region":"arcane_ruins","position":Vector2(1218,456)},
	"sanctum":{"region":"arcane_ruins","position":Vector2(1425,292)}
}
const FUTURE_LOCKS:=[
	{"pos":Vector2(346,172),"tip":"林地北哨 · 敬请期待"},
	{"pos":Vector2(1454,488),"tip":"断柱回廊 · 敬请期待"},
	{"pos":Vector2(994,246),"tip":"黑铁外闸 · 敬请期待"},
	{"pos":Vector2(1196,112),"tip":"焦土黑铁要塞 · 敬请期待"}
]
const MAP_TRAILS:=[
	[Vector2(215,615),Vector2(212,515),Vector2(286,464),Vector2(355,442),Vector2(432,418)],
	[Vector2(432,418),Vector2(506,490),Vector2(598,568),Vector2(654,618),Vector2(692,648)],
	[Vector2(692,648),Vector2(780,664),Vector2(875,672),Vector2(968,668)],
	[Vector2(968,668),Vector2(1045,595),Vector2(1130,520),Vector2(1218,456)],
	[Vector2(1218,456),Vector2(1292,398),Vector2(1360,342),Vector2(1425,292)]
]

static func definition(key: String) -> Dictionary:
	if key==ArenaSaltport.ID:return ArenaSaltport.definition()
	if key=="lighthouse":
		return {
			"id":"lighthouse","name":"汐涌灯塔","story":"南部浅滩潜泳避战，善用灯塔强光[G]，裂隙刷神装及时回防！",
			"tagline":"5轮双域 · 灯塔破雾[G] · 利维坦终战","world_region":"salt_coast","biome":"saltport",
			"map_art":"res://assets/maps_v029/map_lighthouse.png","preview_art":"res://assets/maps_v029/map_lighthouse.png",
			"boss":true,"boss_kind":"leviathan","boss_in_wave":true,"waves":5,"size":Vector2(1600,900),
			"core":Vector2(1520,495),"exits":[Vector2(1520,495)],"hero_spawn":Vector2(1385,495),
			"routes":[
				[Vector2(-30,175),Vector2(280,175),Vector2(455,295),Vector2(765,295),Vector2(925,195),Vector2(1145,290),Vector2(1285,495),Vector2(1520,495)],
				[Vector2(-30,540),Vector2(245,540),Vector2(405,455),Vector2(680,485),Vector2(900,465),Vector2(1120,515),Vector2(1285,495),Vector2(1520,495)],
				[Vector2(575,930),Vector2(575,765),Vector2(755,670),Vector2(990,705),Vector2(1185,600),Vector2(1335,495),Vector2(1520,495)]
			],
			"sites":[
				Vector2(190,290),Vector2(545,185),Vector2(610,385),Vector2(845,380),Vector2(1065,385),Vector2(250,618),
				Vector2(425,598),Vector2(735,575),Vector2(880,780),Vector2(1085,776),Vector2(1295,345),Vector2(1395,610)
			],
			"site_traits":["","highground","","","","","","","","","conduit",""],
			"site_roles":["西北哨口","北崖高台","中北交叉","北堤拐角","东北礁台","中港前沿","西沙坝角","南滩登陆口","潮礁高点","东南重防","灯塔脚下","东岸总汇"],
			"locked_sites":[9,10],"locked_prices":{"9":180,"10":220},"locked_site_price":200,
			"blocked":[Rect2(0,0,420,90),Rect2(1340,0,260,250),Rect2(0,750,450,150),Rect2(1320,765,280,135)],
			"pool":[["murloc_hunter","tide_rider"],["water_sprite","tide_warrior","storm_wyrm"],["tempest_elemental","bluegale","bloodshell_crab"]],
			"preview_enemies":["tide_warrior","tempest_elemental","bluegale","leviathan"],
			"towers":{"storm":1,"lens":1,"snare":1,"archer":1,"barracks":1,"mage":1,"cannon":1}
		}
	if key=="ruins":
		return {
			"id":"ruins","name":"紫雾遗迹 · 断桥古隘","story":"调度西桥 [G] 拖延敌军，进裂隙发育备战血壤破障！",
			"tagline":"5轮双域 · 可控吊桥[G] · 血壤巨兽领主","world_region":"arcane_ruins","biome":"ruins",
			"map_art":"res://assets/maps_v029/map_ruins.png","preview_art":"res://assets/maps_v029/map_ruins.png",
			"boss":true,"boss_kind":"bloodsoil_boss","boss_in_wave":true,"waves":5,"size":Vector2(1600,900),
			"core":Vector2(1520,470),"exits":[Vector2(1520,470)],"hero_spawn":Vector2(1380,470),
			"routes":[
				[Vector2(-30,190),Vector2(240,190),Vector2(395,325),Vector2(675,325),Vector2(805,195),Vector2(1040,240),Vector2(1185,440),Vector2(1355,470),Vector2(1520,470)],
				[Vector2(-30,725),Vector2(260,725),Vector2(385,675),Vector2(495,675),Vector2(655,675),Vector2(855,745),Vector2(1065,630),Vector2(1240,520),Vector2(1355,470),Vector2(1520,470)],
				[Vector2(1210,-30),Vector2(1160,155),Vector2(1185,330),Vector2(1255,445),Vector2(1355,470),Vector2(1520,470)]
			],
			"bridge_gate":{
				"point":Vector2(495,675),"route_id":1,"fork":Vector2(385,675),
				"detour":[Vector2(-30,725),Vector2(260,725),Vector2(385,675),Vector2(345,515),Vector2(545,465),Vector2(760,510),Vector2(790,675),Vector2(855,745),Vector2(1065,630),Vector2(1240,520),Vector2(1355,470),Vector2(1520,470)]
			},
			"sites":[
				Vector2(190,315),Vector2(471,244),Vector2(560,412),Vector2(884,306),Vector2(1035,365),Vector2(215,595),
				Vector2(581,595),Vector2(640,775),Vector2(945,550),Vector2(1095,745),Vector2(1295,255),Vector2(1395,595)
			],
			"site_traits":["highground","","conduit","","","","","","","","",""],
			"site_roles":["西北入弯","北道隘口","中北交叉","北环高台","断柱内弯","西桥前哨","裂谷北岸","吊桥南弯","双线交汇","南段后防","东北破口","东门终防"],
			"braziers":[Vector2(180,20),Vector2(450,875),Vector2(1460,28),Vector2(1480,872)],
			"breach":{"point":Vector2(1160,155),"guard":Vector2(1175,130),"route_id":2,"wave":3},
			"locked_sites":[9,10],"locked_prices":{"9":180,"10":220},"locked_site_price":200,
			"blocked":[
				Rect2(0,0,280,100),Rect2(540,0,180,115),Rect2(1380,0,220,165),
				Rect2(0,805,340,95),Rect2(462,725,68,175),Rect2(1290,775,310,125)
			],
			"pool":[["void_eyeling","twilight_harasser"],["twilight_avenger","venom_spitter","soul_reaver"],["twilight_golem","vile_eyenest","bloodsoil_behemoth"]],
			"preview_enemies":["void_eyeling","twilight_avenger","soul_reaver","bloodsoil_boss"],
			"towers":{"storm":1,"lens":1,"snare":1,"archer":1,"barracks":1,"mage":1,"cannon":1}
		}
	if key=="sanctum":
		return {
			"id":"sanctum","name":"星陨高坛","story":"守住双门，裂隙狂刷超武后回防击败憎恶者巴杰尼蒙！",
			"tagline":"5轮双域 · 星陨神坛[G] · 终局大首领","world_region":"arcane_ruins","biome":"ruins",
			"map_art":"res://assets/maps_v029/map_sanctum.png","preview_art":"res://assets/maps_v029/map_sanctum.png",
			"boss":true,"boss_kind":"baj_nimen","boss_in_wave":true,"waves":5,"size":Vector2(1600,900),
			"core":Vector2(1520,455),"exits":[Vector2(1520,290),Vector2(1520,620)],"hero_spawn":Vector2(1345,455),
			"routes":[
				[Vector2(-30,175),Vector2(265,175),Vector2(425,275),Vector2(720,245),Vector2(965,185),Vector2(1185,290),Vector2(1520,290)],
				[Vector2(-30,455),Vector2(260,455),Vector2(455,455),Vector2(695,455),Vector2(935,455),Vector2(1155,575),Vector2(1355,620),Vector2(1520,620)],
				[Vector2(-30,745),Vector2(295,745),Vector2(505,650),Vector2(795,725),Vector2(1045,695),Vector2(1245,620),Vector2(1520,620)],
				[Vector2(695,455),Vector2(895,365),Vector2(1135,320),Vector2(1335,290),Vector2(1520,290)]
			],
			"sites":[
				Vector2(190,295),Vector2(545,165),Vector2(545,355),Vector2(855,286),Vector2(740,155),Vector2(1404,208),
				Vector2(195,595),Vector2(454,546),Vector2(697,562),Vector2(965,575),Vector2(1075,435),Vector2(1250,740),Vector2(1400,489)
			],
			"site_traits":["","","","conduit","","","","","","highground","","",""],
			"site_roles":["北门高台","北道隘口","星坛北翼","裂隙北侧","北端高位","上出口终防","南门前哨","中南拐角","裂隙南侧","南汇交叉","东中传导","下道后防","下出口终防"],
			"braziers":[Vector2(170,22),Vector2(440,872),Vector2(1470,32),Vector2(1470,868)],
			"locked_sites":[5,11],"locked_prices":{"5":200,"11":220},"locked_site_price":220,
			"blocked":[
				Rect2(0,0,260,95),Rect2(1420,0,180,150),Rect2(0,815,340,85),Rect2(1380,770,220,130)
			],
			"pool":[["void_eyeling","void_gazer","twilight_harasser"],["twilight_avenger","avenger_rider","soul_reaver"],["twilight_golem","vile_eyenest","bloodsoil_behemoth"]],
			"preview_enemies":["void_gazer","avenger_rider","bloodsoil_behemoth","baj_nimen"],
			"towers":{"storm":1,"lens":1,"snare":1,"archer":1,"barracks":1,"mage":1,"cannon":1}
		}
	if key=="creek":
		return {"id":"creek","name":"溪谷驿站","story":"双桥控场拖住兽潮，进裂隙拿满被动回防迎战双头巨魔！",
			"tagline":"5轮双域 · 双路防空 · 双头巨魔","world_region":"forest_frontier","biome":"creek","map_art":"res://assets/v09/map_creek.png","boss":true,"boss_kind":"two_headed_troll","boss_in_wave":true,"waves":5,"core":Vector2(1510,540),"hero_spawn":Vector2(1390,565),
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
	return {"id":"forest","name":"边境林地","story":"建控场塔稳住前线，进裂隙[T]疯狂升级拿超武，红警按[R]回防！",
		"tagline":"5轮双域 · 自动控场塔 · 野兽攻城潮","world_region":"forest_frontier","biome":"woodland","map_art":"res://assets/v09/map_forest.png","boss":false,"waves":5,"core":Vector2(1510,655),"hero_spawn":Vector2(1375,615),
		"routes":[[Vector2(-30,270),Vector2(220,270),Vector2(355,415),Vector2(580,415),Vector2(700,265),Vector2(940,265),Vector2(1080,490),Vector2(1260,490),Vector2(1375,655),Vector2(1510,655)]],
		"sites":[Vector2(175,385),Vector2(375,290),Vector2(560,530),Vector2(730,385),Vector2(900,405),Vector2(1100,350),Vector2(1250,625),Vector2(1430,485)],
		"site_roles":["入口消耗","首弯交战","前段拦截","中段交叉射界","侧翼集火","转弯控制","末段拦截","终点保险"],
		"locked_sites":[7],"locked_site_price":200,
		"blocked":[Rect2(50,490,120,135),Rect2(820,590,170,160),Rect2(1100,40,130,125)],
		"pool":[["pigsoldier","rottooth_hyena"],["pigsoldier","tusk_fighter","dreadeye_viper"],["tusk_fighter","turtle_shaman","bear_vanguard"]],
		"preview_enemies":["pigsoldier","tusk_fighter","dreadeye_viper","bear_vanguard"],
		"towers":{"storm":1,"lens":1,"snare":1,"archer":1,"barracks":1,"mage":1,"cannon":1}}
const HEAVY_ARMOUR:=0.4
const HIGH_RESIST:=0.4
static func total_waves(stage: String) -> int:
	return int(definition(stage).get("waves",5))
static func wave(stage: String,number: int) -> Dictionary:
	if stage==ArenaSaltport.ID:return ArenaSaltport.wave(number)
	# v0.32: 5 long two-stage rounds (~128s): 0..85s skirmish window -> 85s Alert -> 95..128s ×2.5 Horde Siege Assault
	var forest: Array=[
		{"units":[["pigsoldier",32],["rottooth_hyena",16],["tusk_fighter",10,2]],"lead":0,"tag":"第一轮 · 兽潮试探",
			"schedule":[["pigsoldier",12,0,0,1.0,2.8],["rottooth_hyena",8,0,0,26.0,3.2],["pigsoldier",8,0,0,52.0,2.4],["tusk_fighter",8,2,0,95.0,2.6],["pigsoldier",12,0,0,96.5,1.8],["rottooth_hyena",8,0,0,104.0,2.0],["tusk_fighter",2,0,0,118.0,4.0]]},
		{"units":[["pigsoldier",28],["rottooth_hyena",20,1],["tusk_fighter",14,3],["dreadeye_viper",8],["bear_vanguard",8,2]],"lead":0,"tag":"第二轮 · 獠牙狂潮",
			"schedule":[["pigsoldier",14,0,0,1.0,2.6],["dreadeye_viper",6,0,0,26.0,4.2],["rottooth_hyena",8,0,0,50.0,2.8],["bear_vanguard",6,2,0,95.0,3.8],["tusk_fighter",10,2,0,96.0,2.2],["pigsoldier",14,0,0,98.0,1.5],["rottooth_hyena",12,1,0,108.0,1.5],["tusk_fighter",4,1,0,116.0,2.5],["bear_vanguard",2,0,0,120.0,4.0],["dreadeye_viper",2,0,0,122.0,3.0]]},
		{"units":[["pigsoldier",32],["tusk_fighter",18,4],["turtle_shaman",9,2],["bear_vanguard",13,4],["darksteel_guard",8,2],["darksteel_boss",1]],"lead":0,"tag":"第三轮 · 暗钢犀牛阵",
			"schedule":[["pigsoldier",16,0,0,1.0,2.4],["turtle_shaman",4,0,0,28.0,5.2],["tusk_fighter",6,0,0,46.0,3.5],["darksteel_boss",1,0,0,95.5,0.0],["darksteel_guard",6,2,0,96.5,4.2],["bear_vanguard",10,3,0,97.5,2.4],["pigsoldier",16,0,0,98.5,1.3],["tusk_fighter",12,4,0,106.0,1.6],["turtle_shaman",5,2,0,110.0,3.0],["bear_vanguard",3,1,0,118.0,3.2],["darksteel_guard",2,0,0,122.0,3.5]]},
		{"units":[["rottooth_hyena",28,2],["tusk_fighter",22,5],["dreadeye_viper",12],["turtle_shaman",10,3],["bear_vanguard",18,5],["darksteel_guard",14,4],["darksteel_boss",3]],"lead":0,"tag":"第四轮 · 重装三统领",
			"schedule":[["rottooth_hyena",14,0,0,1.0,2.6],["dreadeye_viper",8,0,0,24.0,3.8],["tusk_fighter",6,0,0,44.0,3.8],["darksteel_boss",3,0,0,95.0,8.5],["darksteel_guard",10,3,0,96.0,2.4],["bear_vanguard",14,4,0,97.0,1.8],["tusk_fighter",16,5,0,99.0,1.4],["turtle_shaman",10,3,0,104.0,2.2],["rottooth_hyena",14,2,0,110.0,1.2],["bear_vanguard",4,1,0,118.0,2.4],["darksteel_guard",4,1,0,120.0,2.5],["dreadeye_viper",4,0,0,121.0,2.0]]},
		{"units":[["pigsoldier",36],["rottooth_hyena",20,2],["tusk_fighter",24,6],["turtle_shaman",12,3],["bear_vanguard",20,6],["darksteel_guard",16,5],["darksteel_boss",6]],"lead":0,"tag":"第五轮 · 暗钢总攻狂潮",
			"schedule":[["pigsoldier",18,0,0,1.0,2.2],["turtle_shaman",4,0,0,25.0,5.0],["tusk_fighter",6,0,0,44.0,3.5],["darksteel_boss",6,0,0,95.0,5.0],["darksteel_guard",12,4,0,96.0,2.2],["bear_vanguard",16,5,0,97.0,1.7],["pigsoldier",18,0,0,98.0,1.1],["tusk_fighter",18,6,0,102.0,1.3],["rottooth_hyena",20,2,0,108.0,1.0],["turtle_shaman",8,3,0,112.0,2.0],["darksteel_guard",4,1,0,120.0,2.2],["bear_vanguard",4,1,0,122.0,2.2]]}]
	var creek: Array=[
		{"units":[["pigsoldier",24],["throat_cutter",14],["dreadeye_viper",9],["tusk_fighter",9,2]],"lead":0,"tag":"第一轮 · 双桥潮袭",
			"schedule":[["pigsoldier",12,0,0,1.0,2.8],["throat_cutter",8,0,1,8.0,3.6],["dreadeye_viper",6,0,0,30.0,4.5],["tusk_fighter",7,2,0,95.0,2.8],["pigsoldier",12,0,1,96.5,1.8],["throat_cutter",6,0,1,106.0,2.4],["dreadeye_viper",3,0,0,114.0,3.5],["tusk_fighter",2,0,1,120.0,3.5]]},
		{"units":[["rottooth_hyena",24],["scout_vulture",16],["bear_woodsman",9,2],["tusk_fighter",12,2]],"lead":1,"tag":"第二轮 · 群鸦与狂熊",
			"schedule":[["rottooth_hyena",12,0,0,1.0,2.8],["scout_vulture",8,0,1,8.0,4.0],["bear_woodsman",4,0,0,34.0,5.2],["tusk_fighter",10,2,0,95.0,2.4],["bear_woodsman",5,2,1,97.0,3.8],["rottooth_hyena",12,0,1,100.0,1.8],["scout_vulture",8,0,0,108.0,2.4],["tusk_fighter",2,0,1,120.0,3.0]]},
		{"units":[["darksteel_boss",2],["tusk_fighter",16,3],["skunk_bombardier",10],["turtle_shaman",8],["scout_vulture",14],["pigsoldier",18]],"lead":0,"tag":"第三轮 · 双犀统领",
			"schedule":[["pigsoldier",12,0,0,1.0,2.8],["scout_vulture",8,0,1,6.0,4.2],["skunk_bombardier",5,0,0,30.0,5.0],["darksteel_boss",2,0,0,95.5,10.0],["tusk_fighter",12,3,1,96.5,2.0],["turtle_shaman",8,0,0,100.0,3.0],["pigsoldier",6,0,1,106.0,2.2],["scout_vulture",6,0,0,110.0,2.6],["skunk_bombardier",5,0,1,114.0,2.8],["tusk_fighter",4,0,0,118.0,2.4]]},
		{"units":[["bear_vanguard",12,3],["bear_woodsman",11,3],["darksteel_guard",8,2],["throat_cutter",18,2],["scout_vulture",16,2],["pigsoldier",18]],"lead":-1,"tag":"第四轮 · 双线重甲潮",
			"schedule":[["throat_cutter",10,0,1,1.0,3.0],["scout_vulture",10,0,0,5.0,3.6],["bear_woodsman",5,0,1,32.0,4.8],["darksteel_guard",6,2,0,95.0,3.6],["bear_vanguard",10,3,1,96.5,2.4],["pigsoldier",18,0,0,98.0,1.4],["bear_woodsman",6,3,0,106.0,2.8],["throat_cutter",8,2,1,112.0,2.0],["scout_vulture",6,2,1,116.0,2.4],["darksteel_guard",2,0,1,121.0,3.5],["bear_vanguard",2,0,0,122.0,3.0]]},
		{"units":[["two_headed_troll",1],["darksteel_boss",2],["bear_vanguard",13,3],["darksteel_guard",9,3],["turtle_shaman",10,2],["dreadeye_viper",14],["scout_vulture",18],["pigsoldier",24]],"lead":-1,"tag":"第五轮 · 巨魔灭世潮",
			"schedule":[["pigsoldier",14,0,0,1.0,2.5],["scout_vulture",10,0,1,5.0,3.5],["dreadeye_viper",8,0,0,28.0,4.2],["two_headed_troll",1,0,0,95.5,0.0],["darksteel_boss",2,0,1,97.5,11.0],["darksteel_guard",9,3,1,98.0,3.0],["bear_vanguard",13,3,0,99.0,2.2],["pigsoldier",10,0,1,102.0,1.5],["turtle_shaman",10,2,0,106.0,2.4],["dreadeye_viper",6,0,1,112.0,2.4],["scout_vulture",8,0,1,116.0,2.0]]}]
	var lighthouse: Array=[
		{"units":[["murloc_hunter",28],["water_sprite",14],["tide_rider",14],["tide_warrior",9,2]],"lead":0,"tag":"第一轮 · 潮汐千军",
			"schedule":[["murloc_hunter",14,0,0,1.0,2.6],["tide_rider",8,0,2,8.0,3.8],["water_sprite",8,0,1,28.0,3.8],["tide_warrior",9,2,0,95.0,2.6],["murloc_hunter",14,0,1,96.5,1.6],["tide_rider",6,0,2,106.0,2.4],["water_sprite",6,0,1,114.0,2.4]]},
		{"units":[["tide_warrior",14,2],["conch_mage",11],["storm_wyrm",14],["wind_captain",12,2],["murloc_hunter",18]],"lead":1,"tag":"第二轮 · 雷翼涌岸",
			"schedule":[["murloc_hunter",12,0,0,1.0,2.8],["storm_wyrm",8,0,2,6.0,4.0],["conch_mage",5,0,1,30.0,4.6],["wind_captain",10,2,1,95.0,2.2],["tide_warrior",12,2,0,96.5,2.2],["murloc_hunter",6,0,1,102.0,2.0],["conch_mage",6,0,1,106.0,2.8],["storm_wyrm",6,0,2,112.0,2.5],["tide_warrior",2,0,0,120.0,3.0],["wind_captain",2,0,2,122.0,2.5]]},
		{"units":[["bloodshell_boss",2],["tempest_elemental",8,2],["water_elder",9],["tide_warrior",14],["storm_wyrm",14],["murloc_hunter",18]],"lead":0,"tag":"第三轮 · 双蟹统领登岸",
			"schedule":[["murloc_hunter",12,0,0,1.0,2.8],["storm_wyrm",8,0,2,5.0,4.0],["water_elder",4,0,1,30.0,5.0],["bloodshell_boss",2,0,1,95.5,10.0],["tempest_elemental",6,2,0,96.5,3.6],["tide_warrior",12,0,2,98.0,2.0],["murloc_hunter",6,0,0,104.0,2.0],["water_elder",5,0,1,108.0,2.8],["storm_wyrm",6,0,0,114.0,2.4],["tempest_elemental",2,0,2,120.0,3.5],["tide_warrior",2,0,1,122.0,3.0]]},
		{"units":[["bluegale",9,2],["bloodshell_crab",8,2],["tempest_elemental",9,2],["wind_captain",18,2],["storm_wyrm",16],["tide_rider",16]],"lead":-1,"tag":"第四轮 · 怒涛暴雨阵",
			"schedule":[["wind_captain",10,0,2,1.5,3.0],["storm_wyrm",10,0,0,5.0,3.6],["tempest_elemental",4,0,1,30.0,5.0],["bloodshell_crab",6,2,1,95.0,3.8],["bluegale",7,2,0,96.5,3.0],["tide_rider",16,0,2,98.0,1.6],["wind_captain",8,2,1,106.0,2.2],["tempest_elemental",5,2,2,110.0,3.0],["storm_wyrm",6,0,2,116.0,2.4],["bloodshell_crab",2,0,0,120.0,4.0],["bluegale",2,0,1,122.0,3.5]]},
		{"units":[["leviathan",1],["bloodshell_boss",1],["tempest_elemental",10,3],["bluegale",9,2],["bloodshell_crab",8,2],["conch_mage",12,2],["storm_wyrm",18],["murloc_hunter",24]],"lead":-1,"tag":"第五轮 · 利维坦渊潮",
			"schedule":[["murloc_hunter",14,0,0,1.0,2.5],["storm_wyrm",10,0,2,5.0,3.5],["conch_mage",6,0,1,28.0,4.5],["leviathan",1,0,1,95.5,0.0],["bloodshell_boss",1,0,0,98.5,0.0],["bloodshell_crab",8,2,0,99.0,3.4],["tempest_elemental",10,3,2,100.0,2.8],["murloc_hunter",10,0,1,102.0,1.5],["bluegale",9,2,1,108.0,2.6],["conch_mage",6,2,0,114.0,2.4],["storm_wyrm",8,0,1,118.0,2.2]]}]
	var ruins: Array=[
		{"units":[["void_eyeling",30],["twilight_harasser",14],["twilight_avenger",12,2]],"lead":0,"tag":"第一轮 · 紫雾前哨潮",
			"schedule":[["void_eyeling",16,0,0,1.0,2.4],["twilight_harasser",8,0,1,8.0,3.8],["void_eyeling",6,0,1,32.0,3.6],["twilight_avenger",10,2,0,95.0,2.4],["void_eyeling",8,0,0,97.0,1.8],["twilight_harasser",6,0,1,108.0,2.4],["twilight_avenger",2,0,0,118.0,3.5]]},
		{"units":[["spectral_cutter",14],["twilight_avenger",14,2],["venom_spitter",10],["void_gazer",12],["void_eyeling",18]],"lead":1,"tag":"第二轮 · 蚀影大游击",
			"schedule":[["void_eyeling",12,0,0,1.0,2.6],["void_gazer",8,0,0,6.0,4.0],["venom_spitter",4,0,1,30.0,5.0],["twilight_avenger",12,2,0,95.0,2.2],["spectral_cutter",10,0,1,97.0,2.2],["void_eyeling",6,0,1,102.0,2.0],["venom_spitter",6,0,1,108.0,2.6],["spectral_cutter",4,0,1,114.0,2.4],["void_gazer",4,0,0,118.0,2.6],["twilight_avenger",2,0,0,122.0,3.0]]},
		{"units":[["twilight_golem",9,2],["avenger_rider",15,2],["soul_reaver",10],["vile_eyenest",8],["void_eyeling",22]],"lead":2,"tag":"第三轮 · 魔傀破阵潮",
			"schedule":[["void_eyeling",14,0,0,1.0,2.4],["avenger_rider",7,0,1,8.0,3.8],["soul_reaver",4,0,0,30.0,5.2],["twilight_golem",7,2,2,95.0,3.2],["vile_eyenest",6,0,1,96.5,3.4],["void_eyeling",8,0,0,99.0,1.8],["avenger_rider",8,2,0,106.0,2.2],["soul_reaver",6,0,1,112.0,2.8],["twilight_golem",2,0,2,120.0,3.5],["vile_eyenest",2,0,1,122.0,3.5]]},
		{"units":[["bloodsoil_behemoth",8,2],["twilight_golem",10,2],["avenger_rider",18,3],["venom_spitter",12],["void_gazer",14],["void_eyeling",20]],"lead":-1,"tag":"第四轮 · 血壤压境潮",
			"schedule":[["avenger_rider",9,0,1,1.5,3.2],["void_gazer",8,0,0,5.0,3.8],["venom_spitter",5,0,2,30.0,4.8],["bloodsoil_behemoth",6,2,1,95.0,3.6],["twilight_golem",8,2,2,96.5,3.2],["void_eyeling",20,0,0,98.0,1.3],["avenger_rider",9,3,0,104.0,2.0],["venom_spitter",7,0,1,110.0,2.4],["void_gazer",6,0,2,116.0,2.4],["bloodsoil_behemoth",2,0,1,120.0,4.0],["twilight_golem",2,0,2,122.0,3.5]]},
		{"units":[["bloodsoil_boss",2],["bloodsoil_behemoth",10,3],["twilight_golem",10,2],["vile_eyenest",9,2],["soul_reaver",12,2],["void_gazer",16],["void_eyeling",24]],"lead":-1,"tag":"第五轮 · 双巨兽终临",
			"schedule":[["void_eyeling",16,0,0,1.0,2.2],["void_gazer",10,0,2,5.0,3.6],["soul_reaver",5,0,1,28.0,4.8],["bloodsoil_boss",2,0,1,95.5,11.0],["bloodsoil_behemoth",8,3,0,96.5,3.2],["twilight_golem",8,2,2,98.0,3.0],["void_eyeling",8,0,1,100.0,1.6],["vile_eyenest",9,2,1,106.0,2.6],["soul_reaver",7,2,0,112.0,2.4],["void_gazer",6,0,1,118.0,2.4],["bloodsoil_behemoth",2,0,0,122.0,3.5],["twilight_golem",2,0,2,123.0,3.5]]}]
	var sanctum: Array=[
		{"units":[["void_eyeling",30],["void_gazer",14],["twilight_harasser",14],["twilight_avenger",12,2]],"lead":0,"tag":"第一轮 · 坛前星潮",
			"schedule":[["void_eyeling",16,0,0,1.0,2.5],["void_gazer",8,0,2,6.0,3.8],["twilight_harasser",8,0,1,28.0,3.8],["twilight_avenger",10,2,1,95.0,2.4],["void_eyeling",14,0,0,96.5,1.6],["twilight_harasser",6,0,2,106.0,2.4],["void_gazer",6,0,1,114.0,2.4],["twilight_avenger",2,0,1,120.0,3.5]]},
		{"units":[["avenger_rider",16,2],["spectral_cutter",14],["venom_spitter",12],["soul_reaver",10],["void_eyeling",18]],"lead":1,"tag":"第二轮 · 双翼狂袭",
			"schedule":[["void_eyeling",12,0,0,1.0,2.6],["avenger_rider",8,0,0,6.0,3.8],["venom_spitter",5,0,1,28.0,4.6],["spectral_cutter",10,0,2,95.0,2.2],["avenger_rider",8,2,2,96.5,2.2],["soul_reaver",8,0,1,99.0,2.6],["void_eyeling",6,0,0,104.0,2.0],["venom_spitter",7,0,0,108.0,2.6],["spectral_cutter",4,0,1,116.0,2.4],["soul_reaver",2,0,1,120.0,3.5]]},
		{"units":[["bloodsoil_boss",2],["twilight_golem",10,2],["vile_eyenest",9],["avenger_rider",14,2],["void_gazer",14],["void_eyeling",18]],"lead":1,"tag":"第三轮 · 双巨兽镇坛",
			"schedule":[["void_eyeling",12,0,0,1.0,2.5],["avenger_rider",7,0,2,6.0,3.8],["vile_eyenest",4,0,1,30.0,5.2],["bloodsoil_boss",2,0,1,95.5,10.5],["twilight_golem",8,2,3,96.5,3.2],["void_eyeling",6,0,0,100.0,2.0],["avenger_rider",7,2,0,104.0,2.4],["vile_eyenest",5,0,2,110.0,2.8],["void_gazer",14,0,1,114.0,1.8],["twilight_golem",2,0,3,121.0,3.5]]},
		{"units":[["bloodsoil_behemoth",10,2],["twilight_golem",12,3],["avenger_rider",18,3],["vile_eyenest",10,2],["soul_reaver",12],["void_eyeling",24]],"lead":-1,"tag":"第四轮 · 星裂总攻潮",
			"schedule":[["void_eyeling",16,0,0,1.0,2.2],["avenger_rider",8,0,2,6.0,3.6],["soul_reaver",5,0,1,28.0,4.6],["bloodsoil_behemoth",8,2,1,95.0,3.2],["twilight_golem",9,3,3,96.5,2.8],["void_eyeling",8,0,0,99.0,1.6],["vile_eyenest",8,2,0,104.0,2.6],["avenger_rider",10,3,2,108.0,2.0],["soul_reaver",7,0,1,114.0,2.4],["bloodsoil_behemoth",2,0,1,120.0,3.5],["twilight_golem",3,0,3,121.0,3.0],["vile_eyenest",2,0,0,122.0,3.0]]},
		{"units":[["baj_nimen",1],["bloodsoil_boss",1],["bloodsoil_behemoth",10,3],["twilight_golem",10,2],["vile_eyenest",10,2],["soul_reaver",12,2],["void_gazer",18],["void_eyeling",28]],"lead":-1,"tag":"第五轮 · 憎恶灭世潮",
			"schedule":[["void_eyeling",18,0,0,1.0,2.2],["void_gazer",10,0,2,5.0,3.4],["soul_reaver",5,0,1,26.0,4.5],["baj_nimen",1,0,1,95.5,0.0],["bloodsoil_boss",1,0,2,99.0,0.0],["bloodsoil_behemoth",10,3,2,100.0,2.8],["twilight_golem",10,2,3,101.5,2.8],["void_eyeling",10,0,0,103.0,1.4],["vile_eyenest",10,2,0,108.0,2.4],["soul_reaver",7,2,1,114.0,2.4],["void_gazer",8,0,0,118.0,2.0]]}]
	var bank: Array = sanctum if stage=="sanctum" else (ruins if stage=="ruins" else (lighthouse if stage=="lighthouse" else (creek if stage=="creek" else forest)))
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
