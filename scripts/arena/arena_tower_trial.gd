class_name ArenaTowerTrial
extends RefCounted

const BUILD_TIME := 1.0
const ARCHER_FLIGHT := 340.0
const WEAKNESS_TIME := 3.0
const WEAKNESS_BONUS := 0.30
const FROST_TTL := 4.0
const FROST_STEP := 0.08
const FROST_LIMIT := 3
const FROST_LOCK := 3.0
const FROST_INNER_RATIO := 0.62
const FROST_OUTER_POWER := 0.5
const SHELL_CORE_RATIO := 0.55
const RALLY_CLICK_DISTANCE := 76.0
const BOSS_CONTROL := 0.4
const BOSS_CONTROL_LOCK := 4.0

const PROFILES := {
	"archer": {
		"name":"穿云弓", "description":"沿敌列贯穿，英雄下次命中可利用破绽",
		"power":[23.0,32.0,44.0], "reach":[300.0,320.0,340.0], "cycle":[2.2,2.15,2.05],
		"prep":[0.90,0.85,0.80], "recovery":[0.4,0.4,0.35], "speed":[900.0,950.0,1000.0]},
	"mage": {
		"name":"霜环塔", "description":"外圈减速，内圈叠寒霜更快",
		"power":[13.0,18.0,24.0], "reach":[250.0,265.0,280.0], "cycle":[2.5,2.5,2.4],
		"freeze":[1.2,1.2,1.5]},
	"cannon": {
		"name":"震地炮", "description":"可预设炮击点，爆炸内圈击退并眩晕",
		"power":[30.0,40.0,52.0], "reach":[265.0,281.0,297.0], "cycle":[3.0,3.0,2.9],
		"prep":[0.8,0.8,0.75], "flight":[0.7,0.7,0.65], "splash":[85.0,95.0,105.0],
		"push":[12.0,14.0,16.0], "stun":[0.35,0.40,0.50]},
	"barracks": {
		"name":"哨卫营", "description":"三名哨卫到旗后拦截，重型敌人可越线",
		"power":[4.5,6.0,7.5], "reach":[200.0,200.0,200.0], "cycle":[1.0,1.0,1.0],
		"health":[160.0,220.0,280.0], "respawn":[8.0,7.0,6.0]}}

static func stat(kind: String, key: String, level: int) -> float:
	return float(PROFILES[kind][key][level-1])

static func offer(kind: String) -> Dictionary:
	var data:=ArenaDefinitions.tower(kind)
	data.name=PROFILES[kind].name
	data.description=PROFILES[kind].description
	return data

static func defense_offer(kind: String) -> Dictionary:
	var data:=offer(kind)
	var stats: Array={
		"archer":[26.0,1.35,285.0], "mage":[22.0,1.85,220.0],
		"cannon":[62.0,2.35,265.0], "barracks":[7.0,1.0,200.0]}[kind]
	data.damage=stats[0]
	data.interval=stats[1]
	data.reach=stats[2]
	return data

static func arrow_scales(level: int) -> Array[float]:
	return [1.0,0.85,0.72,0.60,0.50] if level==3 else [1.0,0.85,0.70,0.55]

static func arrow_contact(origin: Vector2,direction: Vector2,length: float,center: Vector2,radius: float) -> float:
	var offset:=center-origin
	var along:=offset.dot(direction)
	var remaining:=radius*radius-maxf(0.0,offset.length_squared()-along*along)
	if remaining<0.0: return INF
	var half_chord:=sqrt(remaining)
	if along+half_chord<0.0 or along-half_chord>length: return INF
	return maxf(0.0,along-half_chord)
