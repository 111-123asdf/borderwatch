class_name ArenaSaltport
extends RefCounted

const ID := "saltport"
const CORE := Vector2(1445,460)
const ROADS := [
	[Vector2(-25,239), Vector2(280,239), Vector2(470,137), Vector2(730,137), Vector2(850,235),
		Vector2(740,330), Vector2(490,330), Vector2(430,435), Vector2(680,510), Vector2(950,445),
		Vector2(1170,355), Vector2(1370,355), CORE],
	[Vector2(1060,925), Vector2(1070,760), Vector2(875,725), Vector2(715,650), Vector2(665,594),
		Vector2(790,576), Vector2(980,588), Vector2(1150,665), Vector2(1335,641), Vector2(1445,540), CORE]
]
const SITES := [
	Vector2(210,330), Vector2(450,240), Vector2(660,240), Vector2(930,220),
	Vector2(340,440), Vector2(590,410), Vector2(931,831), Vector2(1030,500),
	Vector2(1180,440), Vector2(1290,560), Vector2(1390,740), Vector2(1153,837)
]
# The flooded parts of the salt pans are solid for heroes. Their raised rims and
# the gaps between ponds are walkable, including the shortcut through (956,510).
const PONDS := [
	Rect2(54,393,200,167), Rect2(57,583,227,203), Rect2(382,579,194,207),
	Rect2(996,126,192,125), Rect2(1216,103,266,147),
	Rect2(1179,723,102,110), Rect2(1459,565,125,324)
]

const DEEP_WATER := [Rect2(0,876,999,24),Rect2(1152,881,448,19),Rect2(1557,476,43,110)]

# [enemy, count, elite tail, route, first spawn (s), interval (s)].
# Delays account for when each group arrives at the defence, not just when it leaves.
const GROUPS := [
	[["fiddler",4,0,0,1.2,0.75],["fiddler",6,0,0,7.2,0.67]],
	[["fiddler",9,0,0,1.0,0.68],["mudshrimp",6,0,1,13.0,1.10]],
	[["fiddler",10,0,0,0.6,0.56],["mudshrimp",8,0,1,13.0,0.64],["fiddler",4,0,1,23.5,0.6]],
	[["salt_hermit",5,0,0,1.0,1.0],["fiddler",12,0,0,6.7,0.44],["mudshrimp",8,1,1,22.0,0.61]],
	[["salt_hermit",4,1,1,1.0,1.7],["fiddler",12,0,0,3.5,0.8],["mudshrimp",5,0,1,12.0,0.9]],
	[["salt_hermit",8,1,0,0.6,0.8],["mudshrimp",12,0,1,13.5,0.42],["fiddler",12,1,0,9.3,0.46]],
	[["salt_hermit",8,2,1,0.9,0.95],["fiddler",16,1,1,8.2,0.45],["mudshrimp",13,1,0,1.3,0.48]],
	[["anchor_crab",1,0,0,1.4,0.0],["salt_hermit",7,1,0,2.9,0.74],
		["fiddler",16,1,0,10.0,0.5],["mudshrimp",15,1,1,30.0,0.54],["salt_hermit",5,1,1,43.0,1.1]]
]

static func definition() -> Dictionary:
	return {
		"id":ID, "name":"白帆盐港", "story":"长堤截住蟹群，短岸为快敌留一座塔。",
		"tagline":"长堤折返 · 短岸换防", "world_region":"salt_coast", "biome":ID,
		"map_art":"", "preview_art":"res://assets/saltport/preview.png",
		"core":CORE, "hero_spawn":Vector2(1330,474), "size":Vector2(1600,900), "waves":8,
		"routes":ROADS.duplicate(true), "sites":SITES.duplicate(), "blocked":PONDS+DEEP_WATER+[Rect2(533,222,38,39)],
		"site_roles":["入堤哨口","长堤转角","晒盐场内弯","北堤尽头","西堤回转","回头湾",
			"短岸前线","潮沟转角","泵房北侧","双口回防","南堤末端","滩口前哨"],
		"boss":true, "boss_kind":"anchor_crab", "boss_in_wave":true,
		"preview_enemies":["fiddler","mudshrimp","salt_hermit","anchor_crab"],
		"towers":{"storm":1,"lens":1,"snare":1,"archer":1,"barracks":1,"mage":1,"cannon":1}
	}

static func wave(number: int) -> Dictionary:
	var schedule: Array = GROUPS[clampi(number-1,0,7)]
	var units: Array = []
	var lanes: Array[int] = []
	for group in schedule:
		units.append(group.slice(0,3))
	var sorted := schedule.duplicate()
	sorted.sort_custom(func(a: Array,b: Array) -> bool: return a[4]<b[4])
	for group in sorted:
		if int(group[3]) not in lanes:
			lanes.append(int(group[3]))
	return {"units":units, "lead":lanes[0], "lanes":lanes, "schedule":schedule}
