extends Node2D

# Experimental arena survival prototype: ring spawns, free tower placement,
# blocking flow-field pathing, pickups, build mode and one-life death.
# This scene is intentionally separate from scenes/main.tscn.

const ARENA_SIZE := Vector2(2600, 2600)
const CORE := Vector2(1300, 1300)
const CELL := 64.0
const GRID_W := 41
const GRID_H := 41
const BUILD_RADIUS := 900.0
const SPAWN_RADIUS := 1150.0
const CORE_EXCLUSION := 140.0
const TOWER_LIMIT := 10
const REGION_COUNT := 8
const START_GOLD := 260

var running := true
var started := false
var hero_selected := false
var game_over := false
var victory := false
var gold := START_GOLD
var core_health := 400.0
var core_max := 400.0
var cycle := 1
var phase := "rest"
var phase_clock := 5.0
var spawn_budget := 0
var spawn_timer := 0.0
var spawn_interval := 2.0
var spawned_this_phase := 0
var hot_region := 0
var boss_spawned := false
var boss_dead := false
var boss: ArenaEnemy
var rng := RandomNumberGenerator.new()

var blocked: Array[bool] = []
var flow: Array[Vector2] = []
var reach: PackedInt32Array = PackedInt32Array()
var spawn_points: Array[Vector2] = []
var spawn_cells: Array[Vector2i] = []
var obstacles: Array[Rect2] = []
var towers: Array[ArenaTower] = []
var enemies: Array[ArenaEnemy] = []
var drops: Array[ArenaDrop] = []
var hero: ArenaHero
var hud: ArenaHUD
var camera: Camera2D
var build_mode := false
var build_kind := "bolt"
var build_cell := Vector2i(-1, -1)
var build_valid := false
var build_site_ok := false
var build_reason := ""
var selected_tower: ArenaTower
var focus := 4.0
var focus_max := 4.0
var sim_speed := 1.0
var elapsed := 0.0
var shake_amount := 0.0
var bolts: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var floaters: Array[Dictionary] = []
var camps_cleared := 0
var camp_weapons := ["sword", "sniper", "boomerang"]
var relics: Array[String] = []
var relic_choice_pending := false
var pending_relic_group := ""
var passive_selecting := false
var passive_choices: Array[String] = []
var passive_source := ""
var pending_level_choices := 0
var stats := {"kills": 0, "hero_kills": 0, "tower_kills": 0, "built": 0, "cycles": 0}
const PASSIVES := {
	"swift": {"name": "疾行", "desc": "移动速度 +15%"},
	"power": {"name": "过载", "desc": "武器伤害 +25%"},
	"rapid": {"name": "速射", "desc": "攻击速度 +20%"},
	"crit": {"name": "致命", "desc": "25% 概率双倍伤害"},
	"pierce": {"name": "穿透", "desc": "弹道额外穿透 +1"},
	"blast": {"name": "爆裂", "desc": "命中附加 50 范围伤害"},
	"frost": {"name": "霜附", "desc": "命中减速 +1.5 秒"},
	"magnet": {"name": "磁力", "desc": "拾取范围 +90"},
	"aegis": {"name": "重盾", "desc": "最大护盾 +40 并回满"},
	"vitality": {"name": "体魄", "desc": "最大生命 +35 并回复"},
	"focus": {"name": "专注", "desc": "技能冷却 -20%"},
	"greed": {"name": "贪婪", "desc": "金币获取 +25%"},
	"scholar": {"name": "博学", "desc": "经验获取 +25%"},
	"multishot": {"name": "分裂", "desc": "额外弹道 +1"},
	"chain": {"name": "连锁", "desc": "每第 3 发弹射两名敌人"},
	"nova": {"name": "霜环", "desc": "每第 5 发冻结周围敌人"},
	"execute": {"name": "处决", "desc": "对 35% 以下敌人伤害 +60%"},
	"deathblast": {"name": "尸爆", "desc": "敌人死亡时爆炸"},
	"storm": {"name": "雷暴", "desc": "每 6 秒劈向最近敌人"},
	"lifesteal": {"name": "吸血", "desc": "击杀回复 6 生命"},
	"dash_reset": {"name": "猎杀", "desc": "击杀减少技能冷却 1 秒"},
}
const CAMP_PASSIVES := ["power", "rapid", "crit", "multishot", "pierce", "blast", "aegis", "vitality", "focus", "greed", "scholar", "frost", "magnet", "swift", "chain", "nova", "execute", "deathblast", "storm", "lifesteal", "dash_reset"]
var debug := {
	"leaks": 0,
	"leak_damage": 0.0,
	"spawns": 0,
	"drops_spawned": 0,
	"drops_collected": 0,
	"drops_expired": 0,
	"towers_lost": 0,
	"build_rejected": 0,
	"regions": [0, 0, 0, 0, 0, 0, 0, 0],
}

func _ready() -> void:
	rng.randomize()
	_configure_input()
	for index in range(GRID_W * GRID_H):
		blocked.append(false)
	_setup_obstacles()
	_setup_spawn_points()
	_add_castle()
	_rebuild_flow()
	hero = ArenaHero.new()
	hero.game = self
	hero.position = CORE + Vector2(0, 150)
	add_child(hero)
	hero.configure("knight")
	camera = Camera2D.new()
	camera.position = CORE
	camera.zoom = Vector2(0.72, 0.72)
	add_child(camera)
	camera.make_current()
	hud = ArenaHUD.new()
	hud.game = self
	add_child(hud)
	running = false
	hud.show_hero_select()

func start_with_hero(key: String) -> void:
	if hero_selected: return
	hero.configure(key)
	hero_selected = true
	running = true
	started = true
	hud.hide_hero_select()
	start_rest(20.0)
	_set_phase_text("第一轮准备：先建 2 座塔，英雄去林线捡宝匣。")

func _configure_input() -> void:
	var actions := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"skill": [KEY_Q],
		"repair": [KEY_E],
		"restart": [KEY_R],
	}
	for action in actions:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	if not InputMap.has_action("shoot"): InputMap.add_action("shoot")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", mouse)

func _setup_obstacles() -> void:
	var points := [
		Vector2(760, 900), Vector2(1860, 760), Vector2(2110, 1780),
		Vector2(820, 1900), Vector2(1490, 560), Vector2(560, 1300),
		Vector2(2040, 1120), Vector2(1700, 2110), Vector2(1040, 2180),
	]
	for point in points:
		obstacles.append(Rect2(point - Vector2(46, 46), Vector2(92, 92)))
		block_cell_rect(point, 84.0)

func _setup_spawn_points() -> void:
	for index in range(REGION_COUNT):
		var angle := TAU * index / float(REGION_COUNT)
		var point: Vector2 = CORE + Vector2.RIGHT.rotated(angle) * SPAWN_RADIUS
		point = point.clamp(Vector2(80, 80), ARENA_SIZE - Vector2(80, 80))
		spawn_points.append(point)
		spawn_cells.append(world_to_cell(point))

func _add_castle() -> void:
	var castle: Sprite2D = Art.sprite("Factions/Knights/Buildings/Castle/Castle_Blue.png")
	castle.scale = Vector2.ONE * 0.62
	castle.position = CORE + Vector2(0, -70)
	add_child(castle)

# ── grid / flow ──────────────────────────────────────────────
func world_to_cell(point: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor(point.x / CELL)), 0, GRID_W - 1), clampi(int(floor(point.y / CELL)), 0, GRID_H - 1))

func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CELL + CELL * 0.5, cell.y * CELL + CELL * 0.5)

func cell_index(cell: Vector2i) -> int:
	return cell.y * GRID_W + cell.x

func block_cell_rect(point: Vector2, radius: float) -> void:
	var min_cell := world_to_cell(point - Vector2.ONE * radius)
	var max_cell := world_to_cell(point + Vector2.ONE * radius)
	for y in range(min_cell.y, max_cell.y + 1):
		for x in range(min_cell.x, max_cell.x + 1):
			blocked[cell_index(Vector2i(x, y))] = true

func _compute_reach() -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(GRID_W * GRID_H)
	result.fill(-1)
	var core_cell := world_to_cell(CORE)
	var queue: Array[Vector2i] = [core_cell]
	result[cell_index(core_cell)] = 0
	var head := 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		var distance := result[cell_index(cell)]
		for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var next: Vector2i = cell + offset
			if next.x < 0 or next.y < 0 or next.x >= GRID_W or next.y >= GRID_H: continue
			var index := cell_index(next)
			if blocked[index] or result[index] >= 0: continue
			if offset.x != 0 and offset.y != 0:
				if blocked[cell_index(cell + Vector2i(offset.x, 0))] or blocked[cell_index(cell + Vector2i(0, offset.y))]: continue
			result[index] = distance + 1
			queue.append(next)
	return result

func _rebuild_flow() -> void:
	reach = _compute_reach()
	flow.clear()
	flow.resize(GRID_W * GRID_H)
	flow.fill(Vector2.ZERO)
	for y in range(GRID_H):
		for x in range(GRID_W):
			var cell := Vector2i(x, y)
			var index := cell_index(cell)
			if reach[index] < 0 or reach[index] == 0: continue
			var best := Vector2.ZERO
			for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var next: Vector2i = cell + offset
				if next.x < 0 or next.y < 0 or next.x >= GRID_W or next.y >= GRID_H: continue
				if reach[cell_index(next)] != reach[index] - 1: continue
				best = (cell_center(next) - cell_center(cell)).normalized()
				break
			flow[index] = best

func flow_at(point: Vector2) -> Vector2:
	var cell := world_to_cell(point)
	var index := cell_index(cell)
	if index < 0 or reach.size() <= index or reach[index] < 0:
		return (CORE - point).normalized()
	var direction := flow[index]
	if direction == Vector2.ZERO:
		return (CORE - point).normalized()
	return direction

func _all_spawns_reachable() -> bool:
	return _blocked_spawn_names().is_empty()

func _blocked_spawn_names() -> Array[String]:
	var temp := _compute_reach()
	var names: Array[String] = []
	for index in range(REGION_COUNT):
		if temp[cell_index(spawn_cells[index])] < 0:
			names.append(_region_name(index))
	return names

# ── build ────────────────────────────────────────────────────
func can_place(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_W or cell.y >= GRID_H: return "超出地图"
	if not ArenaTower.STATS.has(build_kind): return "请选择塔"
	var point := cell_center(cell)
	if point.distance_to(CORE) < CORE_EXCLUSION: return "离核心太近"
	if point.distance_to(CORE) > BUILD_RADIUS: return "超出建造范围"
	if blocked[cell_index(cell)]: return "这里已被占用"
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0: continue
			var other := cell + Vector2i(ox, oy)
			if other.x < 0 or other.y < 0 or other.x >= GRID_W or other.y >= GRID_H: continue
			if _tower_at(other) != null: return "不能挨着其他塔"
	if towers.size() >= tower_limit(): return "塔位已满"
	if gold < int(ArenaTower.STATS[build_kind].cost): return "金币不足"
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.position.distance_to(point) < 46: return "敌人太近"
	var index := cell_index(cell)
	blocked[index] = true
	var blocked_names := _blocked_spawn_names()
	blocked[index] = false
	if not blocked_names.is_empty():
		return "会堵死%s路线" % "、".join(blocked_names)
	return ""

func _tower_at(cell: Vector2i) -> ArenaTower:
	for tower in towers:
		if is_instance_valid(tower) and tower.cell == cell: return tower
	return null

func _build_site_ok(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_W or cell.y >= GRID_H: return false
	var point := cell_center(cell)
	if point.distance_to(CORE) < CORE_EXCLUSION: return false
	if point.distance_to(CORE) > BUILD_RADIUS: return false
	if blocked[cell_index(cell)]: return false
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0: continue
			if _tower_at(cell + Vector2i(ox, oy)) != null: return false
	return true

func place_tower(cell: Vector2i) -> bool:
	var reason := can_place(cell)
	if reason != "":
		debug.build_rejected += 1
		build_reason = reason
		hud.toast(reason, 2)
		return false
	var cost := int(ArenaTower.STATS[build_kind].cost)
	gold -= cost
	blocked[cell_index(cell)] = true
	var tower := ArenaTower.new()
	tower.game = self
	tower.kind = build_kind
	tower.cell = cell
	tower.position = cell_center(cell)
	add_child(tower)
	towers.append(tower)
	stats.built += 1
	_rebuild_flow()
	hud.toast("已建造 %s（%d 金）" % [ArenaTower.STATS[build_kind].name, cost], 2)
	return true

func tower_destroyed(tower: ArenaTower) -> void:
	if not is_instance_valid(tower): return
	debug.towers_lost += 1
	blocked[cell_index(tower.cell)] = false
	towers.erase(tower)
	tower.queue_free()
	_rebuild_flow()
	hud.toast("一座塔被铁甲撞毁", 2)

func nearest_damaged_tower(point: Vector2, radius: float) -> ArenaTower:
	var result: ArenaTower
	var best := radius
	for tower in towers:
		if not is_instance_valid(tower) or tower.health >= tower.max_health: continue
		var distance := point.distance_to(tower.position)
		if distance < best:
			best = distance
			result = tower
	return result

func nearest_tower(point: Vector2, radius: float) -> ArenaTower:
	var result: ArenaTower
	var best := radius
	for tower in towers:
		if not is_instance_valid(tower) or not tower.active: continue
		var distance := point.distance_to(tower.position)
		if distance < best:
			best = distance
			result = tower
	return result

func repair_nearest() -> void:
	if hero == null or game_over: return
	var tower := nearest_damaged_tower(hero.position, 150.0)
	if tower == null:
		hud.toast("附近没有受损的塔", 2)
		return
	if gold < 30:
		hud.toast("修理需要 30 金", 2)
		return
	gold -= 30
	tower.health = tower.max_health
	hud.toast("塔已修复", 2)

func try_build_at_mouse() -> void:
	if not build_mode: return
	var cell := world_to_cell(get_global_mouse_position())
	var tower := _tower_at(cell)
	if tower != null:
		select_tower(tower)
		return
	place_tower(cell)

func set_build_kind(kind: String) -> void:
	if ArenaTower.STATS.has(kind):
		build_kind = kind
		build_reason = ""

func toggle_build_mode() -> void:
	if game_over or not running: return
	get_viewport().gui_release_focus()
	if build_mode:
		build_mode = false
		selected_tower = null
		hud.show_tower_panel(null)
		Engine.time_scale = sim_speed
		return
	if phase != "rest" and focus <= 0.0:
		hud.toast("专注不足，先等休息段", 2)
		return
	build_mode = true
	selected_tower = null
	hud.show_tower_panel(null)
	build_cell = world_to_cell(get_global_mouse_position())
	build_reason = can_place(build_cell)
	build_valid = build_reason == ""

func build_from_menu(kind: String) -> void:
	if not build_mode: return
	set_build_kind(kind)
	if build_cell.x < 0:
		hud.toast("先选一个建造位置", 2)
		return
	if place_tower(build_cell):
		build_mode = false
		Engine.time_scale = sim_speed
		get_viewport().gui_release_focus()

func select_tower_at_mouse() -> void:
	if not running: return
	var tower := nearest_tower(get_global_mouse_position(), 58.0)
	if tower != null:
		select_tower(tower)

func select_tower(tower: ArenaTower) -> void:
	selected_tower = tower
	hud.show_tower_panel(tower)

func upgrade_selected() -> void:
	if selected_tower == null or not is_instance_valid(selected_tower): return
	if not selected_tower.upgrade():
		hud.toast("金币不足或已满级", 2)
	hud.show_tower_panel(selected_tower)

func repair_selected() -> void:
	if selected_tower == null or not is_instance_valid(selected_tower): return
	if gold < 30:
		hud.toast("修理需要 30 金", 2)
		return
	selected_tower.health = selected_tower.max_health
	gold -= 30
	hud.toast("塔已修复", 1)
	hud.show_tower_panel(selected_tower)

func close_tower_panel() -> void:
	selected_tower = null
	hud.show_tower_panel(null)

# ── cycle / spawning ────────────────────────────────────────
func start_rest(seconds: float) -> void:
	seconds = rest_seconds(seconds)
	phase = "rest"
	phase_clock = seconds
	spawn_timer = 0.0
	spawned_this_phase = 0
	hot_region = rng.randi_range(0, REGION_COUNT - 1)
	var cache_region := (hot_region + 4) % REGION_COUNT
	var cache_point: Vector2 = spawn_points[cache_region] + Vector2(rng.randf_range(-50, 50), rng.randf_range(-50, 50))
	var camp_name: String = Rules.CAMP_NAMES[mini(camps_cleared, Rules.CAMP_NAMES.size() - 1)]
	spawn_drop(cache_point, 20, 30, true, true, "", camp_name)
	_set_phase_text("休息：下一轮热点 %s；%s宝匣在 %s；建塔/修塔/捡宝匣" % [_region_name(hot_region), camp_name, _region_name(cache_region)])
	hud.toast("休息段：热点 %s；%s宝匣在 %s（休息结束消失）" % [_region_name(hot_region), camp_name, _region_name(cache_region)], 3)
func start_spawn() -> void:
	expire_normal_drops()
	phase = "spawn"
	phase_clock = 30.0
	spawn_budget = 30 + 9 * (cycle - 1)
	spawn_interval = 30.0 / maxf(1.0, ceilf(float(spawn_budget) / 4.0))
	spawn_timer = 0.0
	if cycle >= 6 and not boss_spawned:
		_spawn_boss()
	_set_phase_text("出怪：林线有动静（热点 %s，预算 %d）" % [_region_name(hot_region), spawn_budget])
	hud.toast("出怪：热点 %s；本轮预算 %d" % [_region_name(hot_region), spawn_budget], 3)

func _region_name(index: int) -> String:
	var names := ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
	return names[index % names.size()]

func hero_damage_scale() -> float:
	var scale := 1.0
	if "vanguard" in relics: scale += 0.35
	if "command" in relics: scale -= 0.10
	return scale

func tower_damage_scale() -> float:
	var scale := 1.0
	if "lone" in relics: scale += 0.40
	if "swarm" in relics: scale -= 0.15
	if "command" in relics: scale += 0.25
	if "vanguard" in relics: scale -= 0.10
	return scale

func tower_limit() -> int:
	var limit := TOWER_LIMIT
	if "lone" in relics: limit -= 2
	if "swarm" in relics: limit += 2
	return limit

func kill_gold_scale() -> float:
	return 1.40 if "raid" in relics else 1.0

func upgrade_scale() -> float:
	return 0.70 if "hold" in relics else 1.0

func rest_seconds(base: float) -> float:
	var seconds := base
	if "raid" in relics: seconds -= 5.0
	if "hold" in relics: seconds += 5.0
	return maxf(8.0, seconds)

func open_relic_choice(group: String) -> void:
	if group == "" or relic_choice_pending: return
	pending_relic_group = group
	relic_choice_pending = true
	running = false
	hud.show_relic_choice(group)

func passive_info(key: String) -> Dictionary:
	if Rules.RELICS.has(key):
		var relic: Dictionary = Rules.RELICS[key]
		return {"name": relic.name, "desc": relic.text, "tag": relic.tag}
	if PASSIVES.has(key):
		return PASSIVES[key]
	return {"name": key, "desc": "", "tag": "被动"}

func queue_level_choice() -> void:
	pending_level_choices += 1
	if not passive_selecting:
		open_passive_choice("level")

func _relic_available(key: String) -> bool:
	if not Rules.RELICS.has(key): return true
	var group: String = String(Rules.RELICS[key].group)
	for owned in relics:
		if Rules.RELICS.has(owned) and String(Rules.RELICS[owned].group) == group:
			return false
	return true

func open_passive_choice(source: String) -> void:
	if passive_selecting: return
	passive_source = source
	var source_pool: Array = CAMP_PASSIVES.duplicate() if source == "camp" else PASSIVES.keys()
	var pool: Array[String] = []
	for entry in source_pool:
		var key := String(entry)
		if _relic_available(key):
			pool.append(key)
	pool.shuffle()
	passive_choices.clear()
	for index in range(mini(3, pool.size())):
		passive_choices.append(String(pool[index]))
	passive_selecting = true
	running = false
	hud.show_passive_choice(passive_choices, source)

func choose_passive(key: String) -> void:
	if not passive_selecting or not passive_choices.has(key): return
	if Rules.RELICS.has(key):
		relics.append(key)
	else:
		hero.apply_passive(key)
	var was_level := passive_source == "level"
	passive_selecting = false
	if was_level and pending_level_choices > 0:
		pending_level_choices -= 1
	if pending_level_choices > 0:
		open_passive_choice("level")
	else:
		running = true
		hud.hide_passive_choice()
		hud.toast("获得：%s" % passive_info(key).name, 2)

func choose_relic(key: String) -> void:
	if not relic_choice_pending or not Rules.RELICS.has(key): return
	var data: Dictionary = Rules.RELICS[key]
	if String(data.group) != pending_relic_group: return
	relics.append(key)
	relic_choice_pending = false
	pending_relic_group = ""
	running = true
	hud.hide_relic_choice()
	hud.toast("路线：%s" % data.name, 3)

func _weighted_region() -> int:
	var weights: Array[float] = []
	var total := 0.0
	for index in range(REGION_COUNT):
		var weight := 1.0
		if index == hot_region: weight = 2.5
		weights.append(weight)
		total += weight
	var roll := rng.randf_range(0.0, total)
	for index in range(REGION_COUNT):
		roll -= weights[index]
		if roll <= 0.0: return index
	return REGION_COUNT - 1

func spawn_cluster() -> void:
	var region := _weighted_region()
	var base: Vector2 = spawn_points[region]
	var count := mini(4, spawn_budget)
	for index in range(count):
		var point := base + Vector2(rng.randf_range(-70, 70), rng.randf_range(-70, 70))
		var kind := "torch"
		if cycle >= 2 and rng.randf() < 0.25: kind = "shooter"
		if cycle >= 3 and rng.randf() < 0.16: kind = "charger"
		if cycle >= 3 and rng.randf() < 0.10: kind = "bomber"
		if cycle >= 3 and rng.randf() < 0.18: kind = "barrel"
		if cycle >= 4 and rng.randf() < 0.08: kind = "sapper"
		if cycle >= 4 and rng.randf() < 0.12: kind = "brute"
		if cycle >= 4 and rng.randf() < 0.15: kind = "shielded"
		if cycle >= 5 and rng.randf() < 0.15: kind = "armored"
		var health := 38.0 + cycle * 10.0
		if kind == "barrel": health *= 1.6
		if kind == "sapper": health *= 2.2
		if kind == "charger": health *= 0.75
		if kind == "bomber": health *= 1.5
		if kind == "brute": health *= 3.0
		if kind == "shielded": health *= 2.2
		if kind == "armored": health *= 2.6
		var elite := cycle >= 2 and rng.randf() < 0.10
		if elite: health *= 2.5
		spawn_enemy(kind, point, health, elite)
		spawn_budget -= 1
	spawn_timer = spawn_interval
	spawned_this_phase += count
	debug.regions[region] += 1

func _spawn_boss() -> void:
	boss_spawned = true
	var point: Vector2 = spawn_points[hot_region]
	boss = spawn_enemy("boss", point, 4500.0)
	hud.toast("焚林统领从%s林线走来" % _region_name(hot_region), 4)

func boss_summon(point: Vector2) -> void:
	hud.toast("焚林统领召来援军", 2)
	for index in range(3):
		var angle := TAU * index / 3.0
		var spawn_point := point + Vector2.RIGHT.rotated(angle) * 90.0
		var kind := "charger" if index % 2 == 0 else "shooter"
		var health := 70.0 + cycle * 12.0
		spawn_enemy(kind, spawn_point, health, index == 0)

func spawn_enemy(kind: String, point: Vector2, health: float, elite := false) -> ArenaEnemy:
	var enemy := ArenaEnemy.new()
	enemy.game = self
	enemy.kind = kind
	enemy.elite = elite
	enemy.max_health = health
	enemy.health = health
	enemy.position = point
	add_child(enemy)
	enemies.append(enemy)
	debug.spawns += 1
	return enemy

func enemy_died(enemy: ArenaEnemy) -> void:
	if not is_instance_valid(enemy): return
	enemies.erase(enemy)
	stats.kills += 1
	if enemy.kind == "boss":
		boss_dead = true
		boss = null
		spawn_drop(enemy.position, 80, 120, true)
		hud.toast("焚林统领倒下", 3)
	elif enemy.kind in ["shielded", "armored"] or enemy.elite:
		spawn_drop(enemy.position, 20, 15, true)
	else:
		spawn_drop(enemy.position, 6, 5, false)
	if boss_dead and cycle >= 6 and enemies.is_empty():
		finish(true)
	if hero != null:
		if hero.passives.has("lifesteal"):
			hero.health = minf(hero.max_health, hero.health + 6.0)
		if hero.passives.has("dash_reset"):
			hero.skill_cooldown = maxf(0.0, hero.skill_cooldown - 1.0)
		if hero.passives.has("deathblast"):
			damage_radius(enemy.position, 80.0, 38.0)

func enemy_escaped(enemy: ArenaEnemy) -> void:
	enemies.erase(enemy)

func core_hit(amount: float) -> void:
	if game_over: return
	debug.leaks += 1
	debug.leak_damage += amount
	core_health = maxf(0.0, core_health - amount)
	if core_health <= 0: finish(false)

func hero_died() -> void:
	if game_over: return
	finish(false)

func finish(win: bool) -> void:
	if game_over: return
	game_over = true
	victory = win
	running = false
	Engine.time_scale = 1.0
	hud.show_result(win)
	_set_phase_text("")

# ── drops / projectiles ────────────────────────────────────
func spawn_drop(point: Vector2, xp: int, gold_value: int, big: bool, cache := false, weapon_key := "", camp_name := "") -> ArenaDrop:
	var drop := ArenaDrop.new()
	drop.game = self
	drop.xp = xp
	drop.gold_value = gold_value
	drop.big = big
	drop.cache = cache
	drop.weapon_key = weapon_key
	drop.camp_name = camp_name
	drop.position = point
	add_child(drop)
	drops.append(drop)
	debug.drops_spawned += 1
	if drops.size() > 150:
		for index in range(drops.size()):
			if not drops[index].big:
				var oldest: ArenaDrop = drops[index]
				drops.remove_at(index)
				oldest.queue_free()
				break
	return drop

func collect_drop(drop: ArenaDrop) -> void:
	if not is_instance_valid(drop): return
	drops.erase(drop)
	debug.drops_collected += 1
	if hero != null:
		var gold_value := int(drop.gold_value * kill_gold_scale() * hero.gold_mult)
		gold += gold_value
		hero.gold_gained += gold_value
		if drop.cache:
			if camps_cleared < Rules.CAMP_NAMES.size():
				camps_cleared += 1
				open_passive_choice("camp")
			else:
				hud.toast("营地已全部肃清，宝匣只留下金币", 2)
		hero.add_xp(drop.xp)
	drop.queue_free()

func expire_normal_drops() -> void:
	for drop in drops.duplicate():
		if is_instance_valid(drop) and (not drop.big or drop.cache):
			drops.erase(drop)
			debug.drops_expired += 1
			drop.queue_free()

func nearest_enemy(point: Vector2, radius: float) -> ArenaEnemy:
	var result: ArenaEnemy
	var best := radius
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var distance := point.distance_to(enemy.position)
		if distance < best:
			best = distance
			result = enemy
	return result

func spawn_projectile(origin: Vector2, target: Vector2, damage: float, color: Color, splash := 0.0, slow := 0.0, speed := 760.0, pierce := 0, execute_bonus := 0.0) -> ArenaProjectile:
	var projectile := ArenaProjectile.new()
	projectile.game = self
	projectile.position = origin
	projectile.direction = (target - origin).normalized()
	projectile.damage = damage
	projectile.speed = speed
	projectile.color = color
	projectile.splash = splash
	projectile.slow = slow
	projectile.pierce = pierce
	projectile.execute_bonus = execute_bonus
	add_child(projectile)
	return projectile

func enemy_shot(origin: Vector2, target: Vector2, damage: float, speed := 190.0) -> ArenaProjectile:
	var projectile := ArenaProjectile.new()
	projectile.game = self
	projectile.hostile = true
	projectile.position = origin
	projectile.direction = (target - origin).normalized()
	projectile.damage = damage
	projectile.speed = speed
	projectile.color = Color("ff6b5e")
	add_child(projectile)
	projectile.add_to_group("hostile_projectile")
	return projectile

func chain_strike(origin: Vector2, damage: float, jumps: int) -> void:
	var from := origin
	var hit: Array[int] = []
	for index in range(jumps):
		var target: ArenaEnemy
		var best := 360.0
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.dead: continue
			if enemy.get_instance_id() in hit: continue
			var distance := from.distance_to(enemy.position)
			if distance < best:
				best = distance
				target = enemy
		if target == null: break
		hit.append(target.get_instance_id())
		bolts.append({"start": from, "end": target.center(), "life": 0.14})
		target.take_damage(damage)
		from = target.center()
	shake(2.0)

func frost_nova(point: Vector2, radius: float, damage: float, slow: float) -> void:
	rings.append({"point": point, "radius": radius, "life": 0.35})
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(point) < radius:
			enemy.take_damage(damage)
			enemy.slow_time = maxf(enemy.slow_time, slow)
	shake(3.0)

func storm_strike(target: ArenaEnemy, damage: float) -> void:
	if not is_instance_valid(target): return
	bolts.append({"start": target.center() + Vector2(0, -320), "end": target.center(), "life": 0.18})
	target.take_damage(damage)
	shake(4.0)

func hit_feedback(point: Vector2, amount: float) -> void:
	if amount <= 0.0: return
	floaters.append({
		"point": point + Vector2(randf_range(-12, 12), randf_range(-8, 8)),
		"text": str(int(round(amount))),
		"life": 0.5,
		"max_life": 0.5,
	})
	shake(minf(3.0, amount * 0.03))

func clear_hostile_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("hostile_projectile"):
		if is_instance_valid(projectile):
			projectile.queue_free()

func damage_radius(point: Vector2, radius: float, damage: float) -> void:
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(point) < radius:
			enemy.take_damage(damage)

func _set_phase_text(text: String) -> void:
	if hud != null: hud.phase_hint = text

# ── input ──────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if build_mode:
				toggle_build_mode()
				get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if build_mode:
				select_tower_at_mouse()
				get_viewport().set_input_as_handled()
				return
			select_tower_at_mouse()
			if selected_tower != null:
				get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				toggle_build_mode()
				get_viewport().set_input_as_handled()
			KEY_1: set_build_kind("bolt")
			KEY_2: set_build_kind("cannon")
			KEY_3: set_build_kind("frost")
			KEY_E: repair_nearest()
			KEY_R: get_tree().reload_current_scene()

# ── process ────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not running: return
	elapsed += delta
	_update_build_mode(delta)
	_update_phase(delta)
	_update_camera(delta)
	for bolt in bolts: bolt.life -= delta
	bolts = bolts.filter(func(item): return item.life > 0.0)
	for ring in rings: ring.life -= delta
	rings = rings.filter(func(item): return item.life > 0.0)
	for floater in floaters: floater.life -= delta
	floaters = floaters.filter(func(item): return item.life > 0.0)
	if build_mode:
		var mouse_screen := get_viewport().get_mouse_position()
		if hud.build_palette.visible and hud.build_palette.get_global_rect().has_point(mouse_screen):
			pass
		else:
			build_cell = world_to_cell(get_global_mouse_position())
			build_site_ok = _build_site_ok(build_cell)
			build_reason = can_place(build_cell)
			build_valid = build_reason == ""
	queue_redraw()

func _update_build_mode(delta: float) -> void:
	if build_mode and phase != "rest":
		focus = maxf(0.0, focus - delta / 0.45)
		if focus <= 0.0:
			build_mode = false
	if not build_mode:
		focus = minf(focus_max, focus + delta * 0.9)
	Engine.time_scale = 0.45 if build_mode else sim_speed

func _update_camera(delta: float) -> void:
	var target := CORE
	var zoom := 0.72
	if build_mode:
		target = CORE
		zoom = 0.60
	elif hero != null:
		var framing := hero.position * 0.72 + CORE * 0.28 + hero.velocity * 0.12
		target = framing.clamp(Vector2(420, 420), ARENA_SIZE - Vector2(420, 420))
		zoom = 0.78
	camera.position = camera.position.lerp(target, 1.0 - exp(-6.0 * delta))
	camera.zoom = camera.zoom.lerp(Vector2(zoom, zoom), 1.0 - exp(-7.0 * delta))
	shake_amount = maxf(0.0, shake_amount - delta * 28.0)
	camera.offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))

func shake(amount: float) -> void:
	shake_amount = maxf(shake_amount, amount)

func _update_phase(delta: float) -> void:
	match phase:
		"rest":
			var rest_delta := delta / maxf(0.01, Engine.time_scale)
			phase_clock -= rest_delta
			if phase_clock <= 0.0: start_spawn()
		"spawn":
			phase_clock -= delta
			spawn_timer -= delta
			if spawn_budget > 0 and spawn_timer <= 0.0:
				spawn_cluster()
			if spawn_budget <= 0 and enemies.is_empty():
				if cycle >= 6 and boss_dead:
					finish(true)
				else:
					_advance_cycle()
			elif phase_clock <= 0.0:
				phase = "clear"
		"clear":
			if enemies.is_empty():
				if cycle >= 6 and boss_dead: finish(true)
				else: _advance_cycle()

func _advance_cycle() -> void:
	if cycle >= 6: return
	cycle += 1
	start_rest(16.0)

# ── draw ───────────────────────────────────────────────────
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color("2d4a38"))
	draw_rect(Rect2(Vector2.ZERO, ARENA_SIZE), Color("17251e"), false, 10)
	draw_arc(CORE, BUILD_RADIUS, 0, TAU, 96, Color(0.55, 0.85, 0.7, 0.18), 3, true)
	draw_arc(CORE, SPAWN_RADIUS, 0, TAU, 96, Color(0.9, 0.65, 0.4, 0.22), 3, true)
	for index in range(REGION_COUNT):
		var angle := TAU * index / float(REGION_COUNT)
		var color := Color(0.95, 0.4, 0.25, 0.35 if index == hot_region else 0.12)
		draw_arc(CORE, SPAWN_RADIUS, angle - 0.32, angle + 0.32, 24, color, 8, true)
		draw_circle(spawn_points[index], 10 if index != hot_region else 18, color)
	if build_mode:
		for x in range(0, GRID_W + 1):
			draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, ARENA_SIZE.y), Color(0.7, 0.85, 0.8, 0.06), 1)
		for y in range(0, GRID_H + 1):
			draw_line(Vector2(0, y * CELL), Vector2(ARENA_SIZE.x, y * CELL), Color(0.7, 0.85, 0.8, 0.06), 1)
		if build_cell.x >= 0:
			var rect := Rect2(cell_center(build_cell) - Vector2.ONE * CELL * 0.5, Vector2.ONE * CELL)
			draw_rect(rect, Color(0.4, 0.95, 0.65, 0.28) if build_valid else Color(0.95, 0.35, 0.3, 0.28))
			draw_rect(rect, Color(0.4, 0.95, 0.65, 0.8) if build_valid else Color(0.95, 0.35, 0.3, 0.8), false, 2)
			var range_value := float(ArenaTower.STATS[build_kind].range)
			draw_arc(cell_center(build_cell), range_value, 0, TAU, 64, Color(0.55, 0.9, 0.75, 0.45), 2, true)
		var route_point: Vector2 = spawn_points[hot_region]
		for step in range(60):
			var direction: Vector2 = flow_at(route_point)
			if direction == Vector2.ZERO: break
			draw_line(route_point, route_point + direction * 18.0, Color(0.95, 0.55, 0.35, 0.55), 4, true)
			route_point += direction * 18.0
			if route_point.distance_to(CORE) < 50.0: break
	for rock in obstacles:
		draw_rect(rock, Color("4a4d44"))
		draw_rect(rock, Color("252b25"), false, 3)
	for bolt in bolts:
		draw_line(bolt.start, bolt.end, Color(0.7, 0.95, 1.0, bolt.life / 0.18), 4, true)
		draw_line(bolt.start, bolt.end, Color.WHITE, 1.5, true)
	for ring in rings:
		var progress: float = 1.0 - ring.life / 0.35
		draw_arc(ring.point, ring.radius * (0.4 + progress * 0.6), 0, TAU, 40, Color(0.65, 0.95, 1.0, ring.life / 0.35), 4, true)
	for floater in floaters:
		draw_string(ThemeDB.fallback_font, floater.point, floater.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(1.0, 0.9, 0.55, floater.life / floater.max_life))
	if build_mode:
		for cell in range(GRID_W * GRID_H):
			if reach[cell] == 0: continue
			var direction: Vector2 = flow[cell]
			if direction == Vector2.ZERO: continue
			var start := cell_center(Vector2i(cell % GRID_W, int(cell / GRID_W)))
			draw_line(start, start + direction * 18, Color(0.7, 0.9, 0.85, 0.18), 2)
