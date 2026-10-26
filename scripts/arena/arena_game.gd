extends Node2D

# Experimental arena survival prototype: ring spawns, free tower placement,
# blocking flow-field pathing, pickups, build mode and one-life death.
# This scene is intentionally separate from scenes/main.tscn.

const ARENA_SIZE := Vector2(2600, 2600)
const CORE := Vector2(1300, 1300)
const CELL := 64.0
const GRID_W := 41
const GRID_H := 41
const BUILD_RADIUS := 1050.0
const SPAWN_RADIUS := 1150.0
const CORE_EXCLUSION := 140.0
const REGION_COUNT := 8
const START_GOLD := 260

var running := true
var started := false
var hero_selected := false
var game_over := false
var victory := false
var gold := START_GOLD
var core_health := 750.0
var core_max := 750.0
var cycle := 1
var level_cycles := 8
var level_name := "林线"
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
var spawn_warnings: Array[Dictionary] = []
var pending_spawns: Array[Dictionary] = []
var obstacles: Array[Rect2] = []
var towers: Array[ArenaTower] = []
var enemies: Array[ArenaEnemy] = []
var drops: Array[ArenaDrop] = []
var hero: ArenaHero
var hud: ArenaHUD
var audio: ArenaAudio
var camera: Camera2D
var build_mode := false
var build_kind := "bolt"
var default_target_mode := "nearest"
var build_cell := Vector2i(-1, -1)
var build_valid := false
var build_site_ok := false
var build_reason := ""
var selected_tower: ArenaTower
var focus := 10.0
var focus_max := 10.0
var sim_speed := 1.0
var elapsed := 0.0
var shake_amount := 0.0
var shake_direction := Vector2.ZERO
var hitstop := 0.0
var hitstop_lock := 0.0
var sparks: Array[Dictionary] = []
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
var passive_rerolls := 3
var passive_banishes := 1
var banished_passives: Array[String] = []
var dry_weapon_choices := 0
var dry_element_choices := 0
var passive_guarantee_weapon := false
var passive_guarantee_element := false
var stats := {"kills": 0, "hero_kills": 0, "tower_kills": 0, "built": 0, "cycles": 0}
var damage_stats := {"hero": 0.0, "tower": 0.0, "other": 0.0}
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
	"spawn_patterns": {},
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
	audio = ArenaAudio.new()
	add_child(audio)
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
		"skill": [KEY_SPACE],
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
	if gold < tower_cost(build_kind): return "金币不足"
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

func _nearest_build_cell(origin: Vector2i) -> Vector2i:
	if _build_site_ok(origin): return origin
	for radius in range(1, 8):
		for x in range(origin.x - radius, origin.x + radius + 1):
			for y in [origin.y - radius, origin.y + radius]:
				var candidate := Vector2i(x, y)
				if _build_site_ok(candidate): return candidate
		for y in range(origin.y - radius + 1, origin.y + radius):
			for x in [origin.x - radius, origin.x + radius]:
				var candidate := Vector2i(x, y)
				if _build_site_ok(candidate): return candidate
	return world_to_cell(CORE + Vector2(CELL * 3.0, 0))

func place_tower(cell: Vector2i) -> bool:
	var reason := can_place(cell)
	if reason != "":
		debug.build_rejected += 1
		build_reason = reason
		hud.toast(reason, 2)
		return false
	var cost := tower_cost(build_kind)
	gold -= cost
	blocked[cell_index(cell)] = true
	var tower := ArenaTower.new()
	tower.game = self
	tower.kind = build_kind
	tower.cell = cell
	tower.position = cell_center(cell)
	tower.target_mode = default_target_mode
	add_child(tower)
	towers.append(tower)
	stats.built += 1
	_rebuild_flow()
	hud.toast("已建造 %s（%d 金）" % [ArenaTower.STATS[build_kind].name, cost], 2)
	return true

func tower_destroyed(tower: ArenaTower) -> void:
	if not is_instance_valid(tower) or tower.destroyed: return
	tower.destroyed = true
	debug.towers_lost += 1
	blocked[cell_index(tower.cell)] = false
	towers.erase(tower)
	rings.append({"point": tower.position, "radius": 66.0, "life": 0.32, "max_life": 0.32, "color": Color("ff8b6a")})
	for index in range(8):
		var angle := randf() * TAU
		sparks.append({
			"point": tower.position,
			"velocity": Vector2.RIGHT.rotated(angle) * randf_range(100.0, 280.0),
			"life": randf_range(0.16, 0.32),
			"max_life": 0.32,
			"color": Color("ff9d65"),
		})
	hitstop = maxf(hitstop, 0.05)
	shake(5.0, (tower.position - CORE).normalized())
	if audio != null:
		audio.play("explode", -9.0)
	tower.queue_free()
	_rebuild_flow()
	hud.toast("一座塔被摧毁", 2)

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
	confirm_build()

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
	build_cell = _nearest_build_cell(world_to_cell(get_global_mouse_position()))
	build_site_ok = true
	build_reason = can_place(build_cell)
	build_valid = build_reason == ""

func build_from_menu(kind: String) -> void:
	number_build(kind)

func number_build(kind: String) -> void:
	if not ArenaTower.STATS.has(kind): return
	if not build_mode:
		toggle_build_mode()
		if not build_mode: return
	set_build_kind(kind)

func cycle_build_kind(step: int) -> void:
	if not build_mode: return
	var index := ArenaTower.TOWER_ORDER.find(build_kind)
	if index < 0: index = 0
	var next := (index + step + ArenaTower.TOWER_ORDER.size()) % ArenaTower.TOWER_ORDER.size()
	set_build_kind(ArenaTower.TOWER_ORDER[next])

func confirm_build() -> bool:
	if not build_mode: return false
	if build_cell.x < 0:
		hud.toast("先选一个建造位置", 2)
		return false
	var target := build_cell
	var built := place_tower(target)
	if not built:
		var fallback := _nearest_build_cell(target)
		if fallback != target:
			built = place_tower(fallback)
	if built:
		build_mode = false
		Engine.time_scale = sim_speed
		get_viewport().gui_release_focus()
	return built

func select_tower_at_mouse() -> void:
	if not running: return
	var tower := nearest_tower(get_global_mouse_position(), 46.0)
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
	spawn_budget = 32 + 9 * (cycle - 1)
	spawn_interval = 30.0 / maxf(1.0, ceilf(float(spawn_budget) / 4.0))
	spawn_timer = 0.0
	if cycle >= level_cycles and not boss_spawned:
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
	if hero != null:
		scale += 0.15 * int(hero.passives.get("tower_link", 0))
		if hero.passives.has("tower_doctrine"):
			scale += 0.30
	return scale

func tower_attack_speed_scale(kind := "", tower_position := Vector2.ZERO) -> float:
	if hero == null: return 1.0
	var scale := 1.0 + tower_global_speed_bonus()
	if hero.passives.has("tower_legion"):
		scale += 0.10
	if kind == "bolt":
		scale += 0.10 * int(hero.passives.get("tower_bolt", 0))
	if hero.passives.has("tower_command") and tower_position.distance_to(hero.position) <= 240.0:
		scale += 0.20
	return scale

func tower_cost_scale() -> float:
	if hero == null: return 1.0
	return maxf(0.84, 1.0 - 0.08 * int(hero.passives.get("tower_engineer", 0)))

func tower_cost(kind: String) -> int:
	if not ArenaTower.STATS.has(kind): return 0
	return int(round(float(ArenaTower.STATS[kind].cost) * tower_cost_scale()))

func distinct_tower_kinds() -> int:
	var kinds := {}
	for tower in towers:
		if is_instance_valid(tower): kinds[tower.kind] = true
	return kinds.size()

func tower_global_damage_bonus() -> float:
	if hero == null: return 0.0
	var bonus := 0.0
	bonus += 0.05 * int(hero.passives.get("tower_cannon", 0))
	bonus += 0.04 * int(hero.passives.get("tower_arc", 0))
	bonus += 0.05 * int(hero.passives.get("tower_venom", 0))
	bonus += 0.04 * int(hero.passives.get("tower_laser", 0))
	bonus += 0.04 * int(hero.passives.get("tower_mixed", 0)) * distinct_tower_kinds()
	return bonus

func tower_global_speed_bonus() -> float:
	if hero == null: return 0.0
	return 0.04 * int(hero.passives.get("tower_bolt", 0))

func tower_global_range_bonus() -> float:
	if hero == null: return 0.0
	return 8.0 * (int(hero.passives.get("tower_frost", 0)) + int(hero.passives.get("tower_laser", 0)))

func tower_support_bonus(tower: ArenaTower) -> float:
	if hero == null or tower == null: return 0.0
	var bonus := 0.0
	for other in towers:
		if other == tower or not is_instance_valid(other) or not other.active: continue
		if other.kind != "banner": continue
		if other.position.distance_to(tower.position) <= other.attack_range():
			bonus += 0.10 * other.level
	if hero.passives.has("tower_banner"):
		bonus += 0.05 * int(hero.passives.get("tower_banner", 0))
	return bonus

func tower_conditional_damage(tower: ArenaTower) -> float:
	if hero == null or tower == null: return 1.0
	var scale := 1.0 + tower_support_bonus(tower) + tower_global_damage_bonus()
	if hero.passives.has("tower_legion"):
		scale += 0.15
	var adjacent := 0
	for other in towers:
		if other == tower or not is_instance_valid(other): continue
		if absi(other.cell.x - tower.cell.x) <= 2 and absi(other.cell.y - tower.cell.y) <= 2:
			adjacent += 1
	var network := int(hero.passives.get("tower_network", 0))
	if network > 0:
		scale += 0.10 * network * adjacent
	if hero.passives.has("tower_fortress"):
		scale += 0.10 * adjacent
	if hero.passives.has("tower_commander") and tower.position.distance_to(hero.position) <= 240.0:
		scale += 0.25
	return scale

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
		return {"name": relic.name, "desc": relic.text, "tag": relic.tag, "tags_text": relic.tag, "rarity_name": "路线", "stack_text": ""}
	var info: Dictionary
	if hero != null:
		info = ArenaUpgrades.info(key, int(hero.passives.get(key, 0)))
	else:
		info = ArenaUpgrades.info(key, 0)
	var preview := tower_card_preview(key)
	if preview != "":
		info = info.duplicate()
		info["preview"] = preview
	for tag in ArenaUpgrades.ARCHETYPES:
		if key in ArenaUpgrades.ARCHETYPES[tag].keys:
			info = info.duplicate()
			info["archetype_name"] = ArenaUpgrades.ARCHETYPES[tag].name
			info["archetype_tier"] = ArenaUpgrades.archetype_tier(hero, String(tag))
			break
	var active_text := card_active_text(key)
	if active_text != "":
		info = info.duplicate()
		info["active_text"] = active_text
	return info

func card_active_text(key: String) -> String:
	if hero == null: return ""
	match key:
		"last_stand":
			return "当前已触发" if hero.health < hero.max_health * 0.4 else "当前未触发"
		"tower_arsenal":
			return "当前 %d 种塔" % distinct_tower_kinds()
		"predator":
			for enemy in enemies:
				if is_instance_valid(enemy) and (enemy.elite or enemy.kind == "boss"): return "当前有精英/Boss"
			return "当前无精英/Boss"
		"knight_champion":
			return "当前护盾 %d" % int(hero.shield)
		"mage_archon":
			return "当前结界 %.1fs" % hero.barrier_time
	return ""

func tower_card_preview(key: String) -> String:
	if hero == null or not key.begins_with("tower_"): return ""
	var stacks := int(hero.passives.get(key, 0))
	var distinct := distinct_tower_kinds()
	var speed_before := int(round(tower_global_speed_bonus() * 100.0))
	var damage_before := int(round(tower_global_damage_bonus() * 100.0))
	var range_before := int(round(tower_global_range_bonus()))
	var speed_after := speed_before
	var damage_after := damage_before
	var range_after := range_before
	match key:
		"tower_bolt":
			speed_after += 4
			return "全塔攻速 +%d%% → +%d%%；弩塔再 +%d%% → +%d%%" % [speed_before, speed_after, 10 * stacks, 10 * (stacks + 1)]
		"tower_cannon":
			damage_after += 5
			return "全塔伤害 +%d%% → +%d%%；炮塔再 +15%%" % [damage_before, damage_after]
		"tower_frost":
			range_after += 8
			return "全塔射程 +%d → +%d；霜塔减速再 +0.5 秒" % [range_before, range_after]
		"tower_arc":
			damage_after += 4
			return "全塔伤害 +%d%% → +%d%%；电弧塔再 +15%%/跳数" % [damage_before, damage_after]
		"tower_venom":
			damage_after += 5
			return "全塔伤害 +%d%% → +%d%%；毒塔再 +15%% 中毒" % [damage_before, damage_after]
		"tower_laser":
			range_after += 8
			return "全塔射程 +%d → +%d；曜光塔再 +10%%" % [range_before, range_after]
		"tower_banner":
			return "战旗光环额外 +5% → +%d%% 塔伤害" % (5 * (stacks + 1))
		"tower_mixed":
			return "当前 %d 种塔：全塔伤害 +%d%% → +%d%%" % [distinct, damage_before, damage_after + 4 * distinct]
		"tower_network":
			return "2 格内每座塔伤害 +10%"
		"tower_commander":
			return "英雄 240 范围内塔伤害 +25%"
		"tower_engineer":
			return "建造/升级费用再 -8%"
		"tower_fortress":
			return "塔网伤害再 +10%/邻塔，塔受伤 -25%"
		"tower_overclock":
			return "每座塔第 5 发双倍伤害"
		"tower_winter":
			return "霜塔减速 +1.5 秒，伤害 +15%"
		"tower_command":
			return "英雄附近塔攻速 +20%"
	return ""

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
	passive_guarantee_weapon = dry_weapon_choices >= 2
	passive_guarantee_element = dry_element_choices >= 2
	passive_choices = ArenaUpgrades.roll(hero, source, 3, rng, passive_guarantee_weapon, passive_guarantee_element, banished_passives, cycle)
	if passive_choices.is_empty():
		passive_selecting = false
		var rewards := maxi(1, pending_level_choices)
		pending_level_choices = 0
		gold += 50 * rewards
		if hero != null:
			hero.health = minf(hero.max_health, hero.health + 20.0 * rewards)
		running = true
		hud.toast("被动已全满：转化为 %d 金与生命" % (50 * rewards), 3)
		return
	_update_dry_choices(passive_choices)
	passive_selecting = true
	running = false
	hud.show_passive_choice(passive_choices, source, passive_rerolls, passive_banishes)

func _update_dry_choices(choices: Array) -> void:
	var has_weapon := false
	var has_element := false
	for key in choices:
		if not ArenaUpgrades.DEFS.has(key): continue
		if ArenaUpgrades.DEFS[key].has("weapon"): has_weapon = true
		if "元素" in ArenaUpgrades.DEFS[key].tags: has_element = true
	dry_weapon_choices = 0 if has_weapon else dry_weapon_choices + 1
	dry_element_choices = 0 if has_element else dry_element_choices + 1

func reroll_passive_choice() -> void:
	if not passive_selecting or passive_rerolls <= 0: return
	passive_rerolls -= 1
	var next: Array[String] = []
	for attempt in range(3):
		next = ArenaUpgrades.roll(hero, passive_source, 3, rng, passive_guarantee_weapon, passive_guarantee_element, banished_passives, cycle)
		if next != passive_choices:
			break
	if next.is_empty():
		passive_rerolls += 1
		hud.toast("没有可刷新的卡了", 2)
		return
	passive_choices = next
	_update_dry_choices(passive_choices)
	hud.show_passive_choice(passive_choices, passive_source, passive_rerolls, passive_banishes)

func banish_passive_choice(key: String) -> void:
	if not passive_selecting or passive_banishes <= 0 or not passive_choices.has(key): return
	passive_banishes -= 1
	banished_passives.append(key)
	passive_choices.erase(key)
	for attempt in range(3):
		var replacement := ArenaUpgrades.roll(hero, passive_source, 1, rng, false, false, banished_passives, cycle)
		if not replacement.is_empty() and not passive_choices.has(replacement[0]):
			passive_choices.append(replacement[0])
			break
	_update_dry_choices(passive_choices)
	hud.show_passive_choice(passive_choices, passive_source, passive_rerolls, passive_banishes)

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
	var count := mini(4, spawn_budget)
	var pattern := "swarm"
	var angle_sigma := 0.30
	var radius_sigma := 90.0
	var roll := rng.randf()
	if roll < 0.24:
		pattern = "column"
		count = mini(4, spawn_budget)
		angle_sigma = 0.10
		radius_sigma = 45.0
	elif roll < 0.52:
		pattern = "swarm"
		angle_sigma = 0.48
		radius_sigma = 120.0
	elif roll < 0.76:
		pattern = "pincer"
		angle_sigma = 0.20
	count = mini(count, spawn_budget)
	if count <= 0: return
	var anchors: Array[Vector2] = []
	if pattern == "pincer":
		anchors.append(_spawn_point(region, angle_sigma, radius_sigma))
		var other := (region + 4) % REGION_COUNT
		anchors.append(_spawn_point(other, angle_sigma, radius_sigma))
	else:
		anchors.append(_spawn_point(region, angle_sigma, radius_sigma))
	spawn_warnings.append({"point": anchors[0], "life": 1.2, "radius": 74.0})
	if anchors.size() > 1:
		spawn_warnings.append({"point": anchors[1], "life": 1.2, "radius": 74.0})
	var delay := 0.62 if pattern == "column" else (1.0 if pattern == "pincer" else 0.82)
	for index in range(count):
		var base: Vector2 = anchors[index % anchors.size()]
		var jitter := Vector2(rng.randfn(0.0, 42.0), rng.randfn(0.0, 42.0))
		var point := _nearest_spawn_point(base + jitter)
		var kind := _roll_enemy_kind()
		var health := 44.0 + cycle * 13.0
		if kind == "barrel": health *= 1.6
		if kind == "sapper": health *= 2.2
		if kind == "charger": health *= 0.75
		if kind == "hound": health *= 0.65
		if kind == "bomber": health *= 1.5
		if kind == "brute": health *= 3.0
		if kind == "shielded": health *= 2.2
		if kind == "armored": health *= 2.6
		if kind == "shaman": health *= 1.8
		if kind == "mortar": health *= 2.0
		if kind == "splitter": health *= 1.8
		if kind != "boss": health *= 1.08
		var elite := cycle >= 2 and rng.randf() < 0.20
		if elite: health *= 3.0
		pending_spawns.append({
			"point": point,
			"kind": kind,
			"health": health,
			"elite": elite,
			"delay": delay + rng.randf_range(-0.12, 0.18),
		})
		spawn_budget -= 1
	spawn_timer = spawn_interval
	spawned_this_phase += count
	debug.regions[region] += 1
	debug.spawn_patterns[pattern] = int(debug.spawn_patterns.get(pattern, 0)) + 1

func _spawn_point(region: int, angle_sigma: float, radius_sigma: float) -> Vector2:
	var base_angle := TAU * float(region) / float(REGION_COUNT)
	var angle := base_angle + rng.randfn(0.0, angle_sigma)
	var radius := SPAWN_RADIUS + rng.randfn(0.0, radius_sigma)
	radius = clampf(radius, SPAWN_RADIUS - 180.0, SPAWN_RADIUS + 180.0)
	var point: Vector2 = CORE + Vector2.RIGHT.rotated(angle) * radius
	point = point.clamp(Vector2(80, 80), ARENA_SIZE - Vector2(80, 80))
	return _nearest_spawn_point(point)

func _nearest_spawn_point(point: Vector2) -> Vector2:
	var cell := world_to_cell(point)
	for radius in range(0, 12):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius: continue
				var candidate := cell + Vector2i(dx, dy)
				if candidate.x < 0 or candidate.y < 0 or candidate.x >= GRID_W or candidate.y >= GRID_H: continue
				var index := cell_index(candidate)
				if blocked[index] or reach[index] < 0: continue
				return cell_center(candidate)
	return cell_center(cell)

func _roll_enemy_kind() -> String:
	var kind := "torch"
	if cycle >= 2 and rng.randf() < 0.24: kind = "shooter"
	if cycle >= 2 and rng.randf() < 0.10: kind = "hound"
	if cycle >= 3 and rng.randf() < 0.15: kind = "charger"
	if cycle >= 3 and rng.randf() < 0.10: kind = "bomber"
	if cycle >= 3 and rng.randf() < 0.16: kind = "barrel"
	if cycle >= 3 and rng.randf() < 0.07: kind = "shaman"
	if cycle >= 4 and rng.randf() < 0.08: kind = "sapper"
	if cycle >= 4 and rng.randf() < 0.12: kind = "brute"
	if cycle >= 4 and rng.randf() < 0.15: kind = "shielded"
	if cycle >= 4 and rng.randf() < 0.07: kind = "mortar"
	if cycle >= 4 and rng.randf() < 0.08: kind = "splitter"
	if cycle >= 5 and rng.randf() < 0.15: kind = "armored"
	return kind

func build_report() -> Dictionary:
	var fire := 0
	var frost := 0
	var lightning := 0
	var towers := 0
	var survival := 0
	var class_cards := 0
	var synergies := 0
	for key in hero.passives:
		var stacks := int(hero.passives[key])
		if key in ["burn", "pyroclasm", "thermal_shock"]:
			fire += stacks
		if key in ["frost", "nova", "permafrost", "scatter_frost", "chainfrost"]:
			frost += stacks
		if key in ["chain", "storm", "tempest", "stormfire"]:
			lightning += stacks
		if ArenaUpgrades.DEFS.has(key):
			var data: Dictionary = ArenaUpgrades.DEFS[key]
			if "塔防" in data.tags: towers += stacks
			if "生存" in data.tags: survival += stacks
			if "职业" in data.tags: class_cards += stacks
			if String(data.rarity) == "synergy": synergies += 1
	var element_total := fire + frost + lightning
	var dominant := ""
	var best := 0
	for pair in [["fire", fire], ["frost", frost], ["lightning", lightning]]:
		if int(pair[1]) > best:
			best = int(pair[1])
			dominant = String(pair[0])
	var counter := {"fire": "frost", "frost": "lightning", "lightning": "fire"}
	var boss_affinity := String(dominant) if dominant != "" else "fire"
	var boss_weakness := String(counter.get(dominant, "frost"))
	var warnings: Array[String] = []
	if hero.weapon_level < 2: warnings.append("武器未进化")
	if element_total < 2: warnings.append("元素覆盖不足")
	if synergies == 0: warnings.append("没有协同")
	if towers == 0: warnings.append("没有塔防投入")
	if survival == 0: warnings.append("没有生存卡")
	var score := hero.weapon_level * 2 + element_total + synergies * 3 + towers * 2 + survival + class_cards
	var grade := "C"
	if score >= 20: grade = "S"
	elif score >= 14: grade = "A"
	elif score >= 9: grade = "B"
	return {
		"score": score,
		"grade": grade,
		"weapon_level": hero.weapon_level,
		"elements": element_total,
		"dominant": dominant,
		"synergies": synergies,
		"towers": towers,
		"survival": survival,
		"class_cards": class_cards,
		"boss_affinity": boss_affinity,
		"boss_weakness": boss_weakness,
		"warnings": warnings,
	}

func _spawn_boss() -> void:
	boss_spawned = true
	var report := build_report()
	var point: Vector2 = _spawn_point(hot_region, 0.22, 60.0)
	boss = spawn_enemy("boss", point, 5000.0)
	boss.affinity = String(report.boss_affinity)
	boss.weakness = String(report.boss_weakness)
	hud.show_boss_check(report)
	hud.toast("焚林统领从%s林线走来" % _region_name(hot_region), 4)

func boss_phase_shift(point: Vector2, phase: int) -> void:
	rings.append({"point": point, "radius": 320.0, "life": 0.55})
	shake(8.0 + phase * 2.0)
	if audio != null:
		audio.play("phase", -4.0, 0.9 + phase * 0.05)
	for tower in towers.duplicate():
		if is_instance_valid(tower) and tower.position.distance_to(point) <= 360.0:
			tower.disabled_time = maxf(tower.disabled_time, 1.2 + phase * 0.4)
			tower.health -= 8.0 * phase
			if tower.health <= 0.0: tower_destroyed(tower)
	hud.toast("Boss 阶段 %d：冲击波静默附近塔" % (phase + 1), 3)

func boss_summon(point: Vector2) -> void:
	hud.toast("焚林统领召来援军", 2)
	for index in range(3):
		var angle := TAU * index / 3.0
		var spawn_point := point + Vector2.RIGHT.rotated(angle) * 90.0
		var kind := "charger" if index % 2 == 0 else "shooter"
		var health := 70.0 + cycle * 12.0
		spawn_enemy(kind, spawn_point, health, index == 0)

func _weakness_for(kind: String) -> String:
	match kind:
		"armored", "shielded", "mortar": return "lightning"
		"brute", "shaman", "splitter": return "fire"
		"bomber", "sapper", "charger", "hound": return "frost"
		"shooter": return "lightning"
		"boss": return "frost"
	return ""

func _affinity_for(kind: String, elite: bool, weakness: String) -> String:
	if not elite and kind != "boss":
		return ""
	var elements := ["fire", "frost", "lightning"]
	if kind == "boss":
		return "fire"
	for _attempt in range(4):
		var pick: String = elements[rng.randi_range(0, elements.size() - 1)]
		if pick != weakness:
			return pick
	return ""

func spawn_enemy(kind: String, point: Vector2, health: float, elite := false) -> ArenaEnemy:
	var enemy := ArenaEnemy.new()
	enemy.game = self
	enemy.kind = kind
	enemy.elite = elite
	if elite:
		enemy.elite_mod = ["swift", "tough", "volatile", "warding"][rng.randi_range(0, 3)]
	enemy.weakness = _weakness_for(kind)
	enemy.affinity = _affinity_for(kind, elite, enemy.weakness)
	enemy.max_health = health
	enemy.health = health
	enemy.position = point
	add_child(enemy)
	enemies.append(enemy)
	debug.spawns += 1
	return enemy

func record_damage(amount: float, source: String) -> void:
	var key := source if source in ["hero", "tower"] else "other"
	damage_stats[key] = float(damage_stats[key]) + maxf(0.0, amount)

func enemy_died(enemy: ArenaEnemy) -> void:
	if not is_instance_valid(enemy): return
	enemies.erase(enemy)
	stats.kills += 1
	if enemy.last_source == "hero":
		stats.hero_kills += 1
	elif enemy.last_source == "tower":
		stats.tower_kills += 1
	death_feedback(enemy)
	if enemy.kind == "boss":
		boss_dead = true
		boss = null
		spawn_drop(enemy.position, 80, 120, true)
		hud.toast("焚林统领倒下", 3)
	elif enemy.kind in ["shielded", "armored"] or enemy.elite:
		spawn_drop(enemy.position, 20, 15, true)
	else:
		spawn_drop(enemy.position, 6, 5, false)
	if boss_dead and cycle >= level_cycles and enemies.is_empty() and pending_spawns.is_empty():
		finish(true)
	if hero != null:
		if hero.passives.has("lifesteal"):
			var lifesteal_stacks := int(hero.passives.get("lifesteal", 1))
			hero.health = minf(hero.max_health, hero.health + 6.0 + 3.0 * (lifesteal_stacks - 1))
		if hero.passives.has("dash_reset"):
			var reset_stacks := int(hero.passives.get("dash_reset", 1))
			hero.skill_cooldown = maxf(0.0, hero.skill_cooldown - (1.0 + 0.5 * (reset_stacks - 1)))
		if hero.passives.has("deathblast"):
			var blast_stacks := int(hero.passives.get("deathblast", 1))
			damage_radius(enemy.position, 80.0 + 10.0 * (blast_stacks - 1), 38.0 + 20.0 * (blast_stacks - 1), "hero")
			if hero.passives.has("reaper"):
				hero.health = minf(hero.max_health, hero.health + 5.0)
		if hero.passives.has("pyroclasm") and enemy.burn_time > 0.0:
			damage_radius(enemy.position, 90.0, 32.0, "hero")
		if hero.passives.has("inferno") and enemy.burn_time > 0.0:
			damage_radius(enemy.position, 120.0, 54.0, "hero")
			for other in enemies.duplicate():
				if is_instance_valid(other) and not other.dead and other != enemy and other.position.distance_to(enemy.position) < 150.0:
					other.apply_burn(hero.burn_dps * 0.8, 3.0, "hero")
		if hero.passives.has("firestorm") and enemy.burn_time > 0.0:
			damage_radius(enemy.position, 155.0, 70.0, "hero")
		if hero.passives.has("wildfire") and enemy.burn_time > 0.0:
			for other in enemies.duplicate():
				if is_instance_valid(other) and not other.dead and other != enemy and other.position.distance_to(enemy.position) < 120.0:
					other.apply_burn(hero.burn_dps * 0.6, 3.0, "hero")
		if enemy.elite and enemy.elite_mod == "volatile":
			enemy_explosion(enemy.position, 110.0, 12.0, 18.0)
		if enemy.kind == "splitter":
			for index in range(2):
				var angle := TAU * index / 2.0
				var child := spawn_enemy("hound", enemy.position + Vector2.RIGHT.rotated(angle) * 34.0, maxf(20.0, enemy.max_health * 0.22))
				child.elite = false

func enemy_escaped(enemy: ArenaEnemy) -> void:
	enemies.erase(enemy)

func death_feedback(enemy: ArenaEnemy) -> void:
	var point := enemy.center()
	var color := Color("ffb36e") if enemy.elite else Color("ff8b6a")
	rings.append({"point": point, "radius": 40.0 if enemy.elite else 26.0, "life": 0.3, "max_life": 0.3, "color": color})
	for index in range(10 if enemy.elite else 5):
		var angle := randf() * TAU
		sparks.append({
			"point": point,
			"velocity": Vector2.RIGHT.rotated(angle) * randf_range(120.0, 320.0),
			"life": randf_range(0.18, 0.38),
			"max_life": 0.38,
			"color": color,
		})
	hitstop = maxf(hitstop, 0.06 if enemy.elite else 0.04)
	shake(4.0 if enemy.elite else 2.2, (point - CORE).normalized())
	if audio != null:
		audio.play("kill", -8.0 if enemy.elite else -12.0)

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
	if hero != null:
		gold_value = int(round(gold_value * hero.gold_mult))
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

func tower_target(tower: ArenaTower) -> ArenaEnemy:
	if tower == null or not is_instance_valid(tower): return null
	var reach := tower.attack_range()
	var best: ArenaEnemy
	var best_score := -INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var distance := tower.position.distance_to(enemy.position)
		if distance > reach: continue
		var score := -distance
		match tower.target_mode:
			"strongest": score = enemy.health
			"first": score = -enemy.position.distance_to(CORE)
		if score > best_score:
			best_score = score
			best = enemy
	return best

func cycle_tower_target() -> void:
	if selected_tower == null or not is_instance_valid(selected_tower): return
	var index := ArenaTower.TARGET_MODES.find(selected_tower.target_mode)
	selected_tower.target_mode = ArenaTower.TARGET_MODES[(index + 1) % ArenaTower.TARGET_MODES.size()]
	hud.toast("目标：%s" % ArenaTower.TARGET_LABELS[selected_tower.target_mode], 1)
	hud.show_tower_panel(selected_tower)

func cycle_all_targets() -> void:
	var index := ArenaTower.TARGET_MODES.find(default_target_mode)
	default_target_mode = ArenaTower.TARGET_MODES[(index + 1) % ArenaTower.TARGET_MODES.size()]
	for tower in towers:
		if is_instance_valid(tower):
			tower.target_mode = default_target_mode
	hud.toast("全塔目标：%s" % ArenaTower.TARGET_LABELS[default_target_mode], 2)
	if selected_tower != null:
		hud.show_tower_panel(selected_tower)

func sell_selected() -> void:
	if selected_tower == null or not is_instance_valid(selected_tower): return
	var tower := selected_tower
	var refund := tower.sell_value()
	gold += refund
	tower.destroyed = true
	blocked[cell_index(tower.cell)] = false
	towers.erase(tower)
	tower.queue_free()
	selected_tower = null
	hud.show_tower_panel(null)
	_rebuild_flow()
	hud.toast("已拆除塔，返还 %d 金" % refund, 2)

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

func spawn_projectile(origin: Vector2, target: Vector2, damage: float, color: Color, splash := 0.0, slow := 0.0, speed := 760.0, pierce := 0, execute_bonus := 0.0, burn_dps := 0.0, critical := false, execute_threshold := 0.35, shatter := false, poison_dps := 0.0, source := "other") -> ArenaProjectile:
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
	projectile.burn_dps = burn_dps
	projectile.poison_dps = poison_dps
	projectile.source = source
	projectile.critical = critical
	projectile.execute_threshold = execute_threshold
	projectile.shatter = shatter
	add_child(projectile)
	return projectile

func enemy_shot_arc(origin: Vector2, target: Vector2, damage: float, speed: float, count: int, spread: float) -> void:
	var direction := (target - origin).normalized()
	for index in range(count):
		var t := 0.0 if count <= 1 else float(index) / float(count - 1)
		var angle := lerpf(-spread, spread, t)
		enemy_shot(origin, origin + direction.rotated(angle) * 800.0, damage, speed)

func enemy_shot_radial(origin: Vector2, damage: float, speed: float, count: int) -> void:
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		enemy_shot(origin, origin + Vector2.RIGHT.rotated(angle) * 800.0, damage, speed)

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

func chain_strike(origin: Vector2, damage: float, jumps: int, source := "hero") -> void:
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
		var lightning_damage := damage
		if hero != null and hero.passives.has("conductive") and (target.burn_time > 0.0 or target.slow_time > 0.0 or target.freeze_time > 0.0):
			lightning_damage *= 1.4
		target.take_damage(lightning_damage * target.element_multiplier("lightning"), source)
		if hero != null and hero.passives.has("burn"):
			target.apply_burn(hero.burn_dps, 3.0, source)
		if hero != null and hero.passives.has("stormfire"):
			damage_radius(target.position, 72.0, damage * 0.55, source)
		if hero != null and hero.passives.has("chainfrost"):
			target.apply_frost(1.5)
		from = target.center()
	shake(2.0)

func poison_cloud(point: Vector2, radius: float, damage: float, poison: float, source := "tower") -> void:
	rings.append({"point": point, "radius": radius, "life": 0.35})
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(point) <= radius:
			enemy.take_damage(damage, source)
			enemy.apply_poison(poison, 3.0, source)
	shake(2.0)

func beam_damage(origin: Vector2, endpoint: Vector2, damage: float, width: float, source := "tower") -> void:
	bolts.append({"start": origin, "end": endpoint, "life": 0.12})
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead: continue
		var closest := Geometry2D.get_closest_point_to_segment(enemy.position, origin, endpoint)
		if closest.distance_to(enemy.position) <= width + enemy.radius:
			enemy.take_damage(damage, source)
	shake(1.5)

func frost_nova(point: Vector2, radius: float, damage: float, slow: float, source := "hero") -> void:
	if hero != null and hero.passives.has("permafrost"):
		radius += 30.0
		slow += 1.0
		damage *= 1.20
	rings.append({"point": point, "radius": radius, "life": 0.35})
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(point) < radius:
			enemy.take_damage(damage * enemy.element_multiplier("frost"), source)
			enemy.apply_frost(slow)
	shake(3.0)

func storm_strike(target: ArenaEnemy, damage: float, source := "hero") -> void:
	if not is_instance_valid(target): return
	bolts.append({"start": target.center() + Vector2(0, -320), "end": target.center(), "life": 0.18})
	var lightning_damage := damage
	if hero != null and hero.passives.has("conductive") and (target.burn_time > 0.0 or target.slow_time > 0.0 or target.freeze_time > 0.0):
		lightning_damage *= 1.4
	target.take_damage(lightning_damage * target.element_multiplier("lightning"), source)
	if hero != null and hero.passives.has("thunder_god"):
		target.take_damage(lightning_damage * 0.55 * target.element_multiplier("lightning"), source)
		target.freeze_time = maxf(target.freeze_time, 0.55)
	shake(4.0)

func hit_feedback(point: Vector2, amount: float, critical := false, direction := Vector2.ZERO, enemy: ArenaEnemy = null, kill := false) -> void:
	if amount <= 0.0: return
	var color := Color("ffd36e") if critical else Color(1.0, 0.9, 0.55)
	floaters.append({
		"point": point + Vector2(randf_range(-12, 12), randf_range(-8, 8)),
		"text": ("✦" if critical else "") + str(int(round(amount))),
		"life": 0.55 if critical else 0.45,
		"max_life": 0.55 if critical else 0.45,
		"color": color,
		"size": 19 if critical else 14,
	})
	rings.append({"point": point, "radius": 20.0 if critical else 13.0, "life": 0.22, "max_life": 0.22, "color": color})
	for index in range(7 if critical else 4):
		var angle := randf() * TAU
		var speed := randf_range(90.0, 260.0) * (1.3 if critical else 1.0)
		sparks.append({
			"point": point,
			"velocity": Vector2.RIGHT.rotated(angle) * speed + direction * 80.0,
			"life": randf_range(0.12, 0.24),
			"max_life": 0.24,
			"color": color,
		})
	if hitstop_lock <= 0.0:
		hitstop_lock = 0.07
		hitstop = maxf(hitstop, 0.055 if kill else (0.038 if critical else 0.018))
	shake(minf(6.0, amount * 0.035) * (1.8 if critical else 1.0), direction)
	if audio != null:
		audio.play("crit" if critical else "hit", -7.0 if critical else -11.0)
	if enemy != null and is_instance_valid(enemy) and direction != Vector2.ZERO:
		enemy.apply_knockback(direction, 46.0 if critical else 28.0)

func ambient_hit(point: Vector2, amount: float) -> void:
	hit_feedback(point, amount)

func clear_hostile_projectiles() -> void:
	for projectile in get_tree().get_nodes_in_group("hostile_projectile"):
		if is_instance_valid(projectile):
			projectile.queue_free()

func enemy_explosion(point: Vector2, radius: float, hero_damage: float, tower_damage: float) -> void:
	rings.append({"point": point, "radius": radius, "life": 0.35})
	if audio != null:
		audio.play("explode", -8.0)
	if hero != null and hero.position.distance_to(point) < radius:
		hero.take_damage(hero_damage)
	for tower in towers.duplicate():
		if is_instance_valid(tower) and tower.position.distance_to(point) < radius:
			tower.health -= tower_damage
			if tower.health <= 0.0: tower_destroyed(tower)

func shaman_support(point: Vector2) -> void:
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(point) < 200.0:
			enemy.health = minf(enemy.max_health, enemy.health + enemy.max_health * 0.05)
			rings.append({"point": enemy.position, "radius": 26.0, "life": 0.25})

func damage_radius(point: Vector2, radius: float, damage: float, source := "other") -> void:
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(point) < radius:
			enemy.take_damage(damage, source)

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
			var tower := nearest_tower(get_global_mouse_position(), 46.0)
			if tower != null:
				select_tower(tower)
			else:
				close_tower_panel()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if build_mode:
				cycle_build_kind(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
				get_viewport().set_input_as_handled()
				return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if build_mode:
				var mouse: Vector2 = event.position
				if hud.build_palette.visible and hud.build_palette.get_global_rect().has_point(mouse):
					get_viewport().set_input_as_handled()
					return
				confirm_build()
				get_viewport().set_input_as_handled()
				return
			if selected_tower != null:
				close_tower_panel()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				toggle_build_mode()
			KEY_1:
				number_build("bolt")
			KEY_2:
				number_build("cannon")
			KEY_3:
				number_build("frost")
			KEY_4:
				number_build("arc")
			KEY_5:
				number_build("venom")
			KEY_6:
				number_build("laser")
			KEY_7:
				number_build("banner")
			KEY_T:
				cycle_all_targets()
			KEY_ESCAPE:
				if build_mode:
					toggle_build_mode()
				elif selected_tower != null:
					close_tower_panel()
			KEY_E: repair_nearest()
			KEY_R: get_tree().reload_current_scene()

# ── process ────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not running: return
	elapsed += delta
	hitstop = maxf(0.0, hitstop - delta)
	hitstop_lock = maxf(0.0, hitstop_lock - delta)
	_update_build_mode(delta)
	_update_phase(delta)
	_update_camera(delta)
	for spark in sparks:
		spark.life -= delta
		spark.point += spark.velocity * delta
		spark.velocity *= 0.92
	sparks = sparks.filter(func(item): return item.life > 0.0)
	for bolt in bolts: bolt.life -= delta
	bolts = bolts.filter(func(item): return item.life > 0.0)
	for ring in rings: ring.life -= delta
	rings = rings.filter(func(item): return item.life > 0.0)
	for warning in spawn_warnings: warning.life -= delta
	spawn_warnings = spawn_warnings.filter(func(item): return item.life > 0.0)
	var ready_spawns: Array[Dictionary] = []
	for pending in pending_spawns:
		pending["delay"] = float(pending.delay) - delta
		if float(pending.delay) <= 0.0:
			ready_spawns.append(pending)
	pending_spawns = pending_spawns.filter(func(item): return float(item.delay) > 0.0)
	for pending in ready_spawns:
		spawn_enemy(String(pending.kind), pending.point, float(pending.health), bool(pending.elite))
	for floater in floaters: floater.life -= delta
	floaters = floaters.filter(func(item): return item.life > 0.0)
	if build_mode:
		var mouse_screen := get_viewport().get_mouse_position()
		if hud.build_palette.visible and hud.build_palette.get_global_rect().has_point(mouse_screen):
			pass
		else:
			var raw_cell := world_to_cell(get_global_mouse_position())
			if _build_site_ok(raw_cell):
				build_cell = raw_cell
			elif not _build_site_ok(build_cell):
				build_cell = _nearest_build_cell(raw_cell)
			build_site_ok = true
			build_reason = can_place(build_cell)
			build_valid = build_reason == ""
	queue_redraw()

func _update_build_mode(delta: float) -> void:
	if build_mode and phase != "rest":
		focus = maxf(0.0, focus - delta / 1.0)
		if focus <= 0.0:
			build_mode = false
	if not build_mode:
		focus = minf(focus_max, focus + delta * 1.5)
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
	if shake_direction != Vector2.ZERO:
		camera.offset = shake_direction * randf_range(-shake_amount, shake_amount) + shake_direction.orthogonal() * randf_range(-shake_amount * 0.35, shake_amount * 0.35)
	else:
		camera.offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))

func shake(amount: float, direction := Vector2.ZERO) -> void:
	if amount > shake_amount:
		shake_amount = amount
		shake_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.ZERO

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
			if spawn_budget <= 0 and enemies.is_empty() and pending_spawns.is_empty():
				if cycle >= level_cycles and boss_dead:
					finish(true)
				else:
					_advance_cycle()
			elif phase_clock <= 0.0:
				phase = "clear"
		"clear":
			if enemies.is_empty() and pending_spawns.is_empty():
				if cycle >= level_cycles and boss_dead: finish(true)
				else: _advance_cycle()

func _advance_cycle() -> void:
	if cycle >= level_cycles: return
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
	for warning in spawn_warnings:
		var alpha: float = clampf(warning.life / 1.2, 0.0, 1.0)
		draw_arc(warning.point, warning.radius * (1.25 - alpha * 0.25), 0, TAU, 40, Color(1.0, 0.55, 0.32, alpha * 0.8), 3, true)
		draw_circle(warning.point, 8, Color(1.0, 0.62, 0.35, alpha * 0.7))
	if build_mode:
		for x in range(0, GRID_W + 1):
			draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, ARENA_SIZE.y), Color(0.7, 0.85, 0.8, 0.06), 1)
		for y in range(0, GRID_H + 1):
			draw_line(Vector2(0, y * CELL), Vector2(ARENA_SIZE.x, y * CELL), Color(0.7, 0.85, 0.8, 0.06), 1)
		if build_cell.x >= 0:
			var rect := Rect2(cell_center(build_cell) - Vector2.ONE * CELL * 0.5, Vector2.ONE * CELL)
			draw_rect(rect, Color(0.4, 0.95, 0.65, 0.28) if build_valid else Color(0.95, 0.35, 0.3, 0.28))
			draw_rect(rect, Color(0.4, 0.95, 0.65, 0.8) if build_valid else Color(0.95, 0.35, 0.3, 0.8), false, 2)
			var tower_color: Color = ArenaTower.STATS[build_kind].color
			var ghost_center := cell_center(build_cell)
			var alpha := 0.32 if build_valid else 0.14
			draw_circle(ghost_center + Vector2(0, 2), 27, Color(tower_color, alpha * 0.55))
			draw_arc(ghost_center + Vector2(0, 2), 27, 0, TAU, 32, Color(tower_color, alpha * 1.6), 2, true)
			draw_circle(ghost_center + Vector2(0, -18), 17, Color(tower_color, alpha * 1.2))
			draw_arc(ghost_center + Vector2(0, -18), 17, 0, TAU, 24, Color(tower_color, alpha * 2.0), 2, true)
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
		var ring_life: float = float(ring.get("max_life", 0.35))
		var progress: float = 1.0 - ring.life / ring_life
		var ring_color: Color = ring.get("color", Color(0.65, 0.95, 1.0))
		draw_arc(ring.point, ring.radius * (0.4 + progress * 0.6), 0, TAU, 40, Color(ring_color, ring.life / ring_life), 4, true)
	for spark in sparks:
		var spark_alpha: float = clampf(spark.life / spark.max_life, 0.0, 1.0)
		draw_line(spark.point - spark.velocity * 0.012, spark.point, Color(spark.color, spark_alpha), 2.5, true)
	for floater in floaters:
		draw_string(ThemeDB.fallback_font, floater.point, floater.text, HORIZONTAL_ALIGNMENT_CENTER, -1, int(floater.get("size", 14)), Color(floater.get("color", Color(1.0, 0.9, 0.55)), floater.life / floater.max_life))
	if build_mode:
		for cell in range(GRID_W * GRID_H):
			if reach[cell] == 0: continue
			var direction: Vector2 = flow[cell]
			if direction == Vector2.ZERO: continue
			var start := cell_center(Vector2i(cell % GRID_W, int(cell / GRID_W)))
			draw_line(start, start + direction * 18, Color(0.7, 0.9, 0.85, 0.18), 2)
