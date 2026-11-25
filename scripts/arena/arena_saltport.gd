class_name ArenaSaltport
extends RefCounted

const ID := "saltport"
const CORE := Vector2(1520, 445)
const EXITS := [CORE]
const ROADS := [
	[
		Vector2(-30, 215), Vector2(235, 215), Vector2(370, 355), Vector2(605, 355),
		Vector2(720, 195), Vector2(990, 195), Vector2(1110, 375), Vector2(1330, 445),
		CORE
	],
	[
		Vector2(430, 930), Vector2(430, 745), Vector2(610, 625), Vector2(895, 625),
		Vector2(1045, 710), Vector2(1235, 565), Vector2(1365, 445),
		CORE
	]
]
const SITES := [
	Vector2(175, 325), Vector2(440, 240), Vector2(585, 480), Vector2(845, 315), Vector2(1165, 250),
	Vector2(298, 700), Vector2(560, 750), Vector2(825, 745), Vector2(1014, 526), Vector2(1250, 705), Vector2(1390, 325)
]
const BLOCKED := [
	Rect2(0, 0, 280, 115), Rect2(450, 0, 175, 110), Rect2(1290, 0, 310, 160),
	Rect2(0, 415, 175, 195), Rect2(0, 790, 310, 110), Rect2(1370, 760, 230, 140)
]

# [enemy, count, elite tail, route, first spawn (s), interval (s)].
# v0.32: 5 long two-stage rounds (~128s): 0..85s skirmish -> 85s Alert -> 95..128s ×2.5 Horde Siege Assault
const GROUPS := [
	[
		["murloc_hunter", 12, 0, 0, 1.0, 2.6], ["murloc_hunter", 10, 0, 1, 7.0, 3.0],
		["water_sprite", 8, 0, 0, 30.0, 3.8], ["murloc_hunter", 10, 0, 1, 44.0, 2.5],
		["tide_warrior", 9, 2, 0, 95.0, 2.4], ["murloc_hunter", 16, 1, 1, 96.5, 1.4], ["water_sprite", 4, 0, 0, 114.0, 3.0]
	],
	[
		["murloc_hunter", 14, 0, 0, 1.0, 2.5], ["tide_rider", 10, 0, 1, 6.0, 3.4],
		["storm_wyrm", 8, 0, 0, 28.0, 4.0], ["water_sprite", 8, 0, 1, 44.0, 3.2],
		["tide_warrior", 11, 2, 0, 95.0, 2.2], ["conch_mage", 9, 1, 1, 97.0, 2.6], ["tide_rider", 14, 1, 1, 102.0, 1.5], ["storm_wyrm", 4, 0, 0, 116.0, 2.6]
	],
	[
		["wind_captain", 8, 0, 1, 1.5, 3.8], ["water_sprite", 10, 0, 0, 5.0, 3.6],
		["storm_wyrm", 8, 0, 1, 28.0, 3.8], ["tide_warrior", 8, 1, 0, 44.0, 3.2],
		["bloodshell_boss", 2, 0, 0, 95.5, 10.5], ["conch_mage", 9, 1, 1, 97.0, 2.6],
		["tide_warrior", 12, 2, 0, 99.0, 1.8], ["water_elder", 7, 1, 1, 106.0, 2.8], ["wind_captain", 6, 1, 1, 114.0, 2.2]
	],
	[
		["tide_rider", 14, 2, 1, 1.0, 2.6], ["conch_mage", 8, 0, 0, 5.0, 4.0],
		["storm_wyrm", 10, 1, 0, 28.0, 3.6], ["wind_captain", 10, 1, 1, 40.0, 3.2],
		["bloodshell_crab", 7, 2, 0, 95.0, 3.4], ["tempest_elemental", 7, 2, 1, 96.5, 3.2],
		["tide_warrior", 14, 3, 0, 100.0, 1.6], ["water_elder", 8, 2, 1, 108.0, 2.4], ["tide_rider", 10, 1, 1, 114.0, 1.8]
	],
	[
		["murloc_hunter", 18, 2, 0, 1.0, 2.2], ["storm_wyrm", 10, 1, 1, 5.0, 3.5],
		["water_sprite", 12, 1, 0, 26.0, 3.2], ["wind_captain", 10, 1, 1, 38.0, 3.0],
		["bloodshell_boss", 2, 0, 0, 95.0, 10.5], ["bloodshell_crab", 9, 2, 1, 96.5, 3.0],
		["tempest_elemental", 9, 2, 0, 98.5, 2.8], ["tide_rider", 18, 3, 1, 102.0, 1.3], ["storm_wyrm", 10, 1, 0, 110.0, 2.0], ["water_elder", 6, 1, 1, 116.0, 2.4]
	]
]

static func definition() -> Dictionary:
	return {
		"id": ID, "name": "白帆盐港", "story": "海族大举登陆！前期建塔进裂隙[T]狂刷发育，警报响起按[R]回防！",
		"tagline": "5轮双域 · 礁湾跃袭 · 狂暴螃蟹统领", "world_region": "salt_coast", "biome": "saltport",
		"map_art": "res://assets/maps_v029/map_saltport.png",
		"preview_art": "res://assets/maps_v029/map_saltport.png",
		"core": CORE, "exits": EXITS.duplicate(), "hero_spawn": Vector2(1385, 455),
		"size": Vector2(1600, 900), "waves": 5,
		"routes": ROADS.duplicate(true), "sites": SITES.duplicate(), "blocked": BLOCKED.duplicate(),
		"site_traits": ["", "", "conduit", "highground", "", "", "", "", "", "", ""],
		"site_roles": [
			"北岸哨口", "北弯高台", "盐湾中央交叉", "北湾内侧", "东北崖壁",
			"南港前沿", "南滩隘口", "东南湾转角", "潮沟脉座", "南段回防", "东侧终防"
		],
		"locked_sites": [10], "locked_site_price": 200,
		"boss": true, "boss_kind": "bloodshell_boss", "boss_in_wave": true,
		"preview_enemies": ["murloc_hunter", "tide_rider", "conch_mage", "bloodshell_boss"],
		"towers": {"storm": 1, "lens": 1, "snare": 1, "archer": 1, "barracks": 1, "mage": 1, "cannon": 1}
	}

static func wave(number: int) -> Dictionary:
	var schedule: Array = GROUPS[clampi(number - 1, 0, GROUPS.size() - 1)]
	var units: Array = []
	var lanes: Array[int] = []
	for group in schedule:
		units.append(group.slice(0, 3))
	var sorted := schedule.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[4] < b[4])
	for group in sorted:
		if int(group[3]) not in lanes:
			lanes.append(int(group[3]))
	return {"units": units, "lead": lanes[0], "lanes": lanes, "schedule": schedule}
