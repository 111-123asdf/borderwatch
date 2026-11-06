class_name ArenaLevelCatalog
extends RefCounted
const IDS := ["forest","creek"]
const SIZE := Vector2(1600,900)
static func definition(key: String) -> Dictionary:
	if key=="creek":
		return {"id":"creek","name":"溪谷驿站","story":"两座桥，一道防线。","boss":false,"waves":8,"core":Vector2(1510,540),"hero_spawn":Vector2(1390,565),
			"routes":[[Vector2(-30,190),Vector2(230,190),Vector2(350,350),Vector2(590,350),Vector2(640,185),Vector2(990,185),Vector2(1110,390),Vector2(1040,510),Vector2(1240,540),Vector2(1510,540)],
				[Vector2(320,930),Vector2(320,750),Vector2(500,640),Vector2(780,640),Vector2(970,700),Vector2(1130,570),Vector2(1390,540),Vector2(1510,540)]],
			"sites":[Vector2(170,315),Vector2(400,230),Vector2(615,470),Vector2(825,305),Vector2(1210,385),Vector2(195,770),Vector2(475,770),Vector2(945,500),Vector2(1050,775),Vector2(1375,670)],
			"site_roles":["西侧入口","林间回弯","长路拦截","北桥东岸","汇合前沿","南侧入口","南路转弯","溪岸交叉射界","短路后段","终点回防"],
			"camps":[Vector2(100,485),Vector2(1390,180)],
			"blocked":[Rect2(710,0,85,120),Rect2(710,255,85,150),Rect2(755,405,95,125),Rect2(815,530,85,70),Rect2(900,735,95,165),Rect2(1180,35,190,120),Rect2(50,610,105,130)],
			"water_rects":[Rect2(710,0,85,120),Rect2(710,255,85,150),Rect2(755,405,95,125),Rect2(815,530,85,70),Rect2(900,735,95,165)],
			"bridges":[Vector2(750,185),Vector2(875,668)],
			"pool":[["fox","spearman"],["fox","wisp","spearman"],["brute","spearman","spore","wisp"]],
			"towers":{"archer":1,"barracks":1,"mage":1,"cannon":1}}
	return {"id":"forest","name":"边境林地","story":"守住林间最后的微光。","boss":true,"waves":8,"core":Vector2(1510,655),"hero_spawn":Vector2(1375,615),
		"routes":[[Vector2(-30,270),Vector2(220,270),Vector2(355,415),Vector2(580,415),Vector2(700,265),Vector2(940,265),Vector2(1080,490),Vector2(1260,490),Vector2(1375,655),Vector2(1510,655)]],
		"sites":[Vector2(175,385),Vector2(375,290),Vector2(560,530),Vector2(730,385),Vector2(900,405),Vector2(1100,350),Vector2(1250,625),Vector2(1430,485)],
		"site_roles":["入口消耗","首弯交战","前段拦截","中段交叉射界","侧翼集火","转弯控制","末段拦截","终点保险"],
		"camps":[Vector2(255,770),Vector2(1370,205)],
		"blocked":[Rect2(50,490,120,135),Rect2(820,590,170,160),Rect2(1100,40,130,125)],
		"pool":[["fox"],["fox","brute"],["fox","brute","wisp"]],
		"towers":{"archer":1,"barracks":1,"mage":3,"cannon":5}}
static func wave(stage: String,number: int) -> Dictionary:
	# Authored teaching beats and alternating lane pressure, not decorative spawn randomness.
	var forest: Array=[
		{"units":[["fox",8]],"lead":0},
		{"units":[["fox",12]],"lead":0},
		{"units":[["fox",10],["brute",2]],"lead":0},
		{"units":[["fox",12],["brute",4]],"lead":0},
		{"units":[["fox",24]],"lead":0},
		{"units":[["fox",16],["brute",6]],"lead":0},
		{"units":[["fox",12],["wisp",8],["brute",4]],"lead":0},
		{"units":[["fox",16],["wisp",6],["brute",4]],"lead":0}]
	var creek: Array=[
		{"units":[["fox",8],["spearman",4]],"lead":0},
		{"units":[["fox",10],["wisp",6]],"lead":1},
		{"units":[["fox",10],["brute",5]],"lead":0},
		{"units":[["fox",14],["spearman",8]],"lead":1},
		{"units":[["fox",20],["spore",6]],"lead":0},
		{"units":[["brute",8],["wisp",6],["spearman",8]],"lead":1},
		{"units":[["fox",24],["spore",6],["spearman",6]],"lead":-1},
		{"units":[["fox",20],["brute",4],["wisp",4],["spearman",8]],"lead":-1}]
	return (creek if stage=="creek" else forest)[clampi(number-1,0,7)].duplicate(true)
static func curve(points: Array) -> Curve2D:
	var result:=Curve2D.new()
	result.bake_interval=4.0
	for index in range(points.size()):
		var previous: Vector2=points[maxi(0,index-1)]
		var next: Vector2=points[mini(points.size()-1,index+1)]
		var tangent: Vector2=(next-previous).normalized()*minf(previous.distance_to(points[index]),next.distance_to(points[index]))*0.23
		result.add_point(points[index],-tangent,tangent)
	return result
