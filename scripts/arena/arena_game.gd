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
const START_GOLD := 180

var running := true
var started := false
var game_over := false
var victory := false
var gold := START_GOLD
var core_health := 240.0
var core_max := 240.0
var cycle := 1
var phase := "rest"
var phase_clock := 5.0
var spawn_budget := 0
var spawn_timer := 0.0
var spawned_this_phase := 0
var hot_region := 0
var boss_spawned := false
var boss_dead := false
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
var build_reason := ""
var focus := 4.0
var focus_max := 4.0
var sim_speed := 1.0
var elapsed := 0.0
var stats := {"kills": 0, "hero_kills": 0, "tower_kills": 0, "built": 0, "cycles": 0}
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
	camera = Camera2D.new()
	camera.position = CORE
	camera.zoom = Vector2(0.58, 0.58)
	add_child(camera)
	camera.make_current()
	hud = ArenaHUD.new()
	hud.game = self
	add_child(hud)
	start_rest(15.0)
	_set_phase_text("第一轮准备：把塔放在核心周围，英雄去林线捡掉落。")

func _configure_input() -> void:
	var actions := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"skill": [KEY_SPACE],
		"build": [KEY_B],
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
	var temp := _compute_reach()
	for cell in spawn_cells:
		if temp[cell_index(cell)] < 0: return false
	return true

# ── build ────────────────────────────────────────────────────
func can_place(cell: Vector2i) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= GRID_W or cell.y >= GRID_H: return "超出地图"
	if not Rules.TOWERS.has(build_kind): return "请选择塔"
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
	if towers.size() >= TOWER_LIMIT: return "塔位已满"
	if gold < int(Rules.TOWERS[build_kind].cost): return "金币不足"
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.position.distance_to(point) < 46: return "敌人太近"
	var index := cell_index(cell)
	blocked[index] = true
	var reachable := _all_spawns_reachable()
	blocked[index] = false
	if not reachable: return "会堵死所有刷怪路线"
	return ""

func _tower_at(cell: Vector2i) -> ArenaTower:
	for tower in towers:
		if is_instance_valid(tower) and tower.cell == cell: return tower
	return null

func place_tower(cell: Vector2i) -> bool:
	var reason := can_place(cell)
	if reason != "":
		debug.build_rejected += 1
		build_reason = reason
		hud.toast(reason, 2)
		return false
	var cost := int(Rules.TOWERS[build_kind].cost)
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
	hud.toast("已建造 %s · 英雄靠近时光环增伤" % Rules.TOWERS[build_kind].name, 2)
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
		if not tower.upgrade():
			hud.toast("金币不足或已满级", 2)
		return
	place_tower(cell)

# ── cycle / spawning ────────────────────────────────────────
func start_rest(seconds: float) -> void:
	phase = "rest"
	phase_clock = seconds
	spawn_timer = 0.0
	spawned_this_phase = 0
	hot_region = rng.randi_range(0, REGION_COUNT - 1)
	var cache_region := (hot_region + 4) % REGION_COUNT
	var cache_point: Vector2 = spawn_points[cache_region] + Vector2(rng.randf_range(-50, 50), rng.randf_range(-50, 50))
	spawn_drop(cache_point, 18, 24, true, true)
	_set_phase_text("休息：下一轮热点 %s；补给箱在 %s；建塔/修塔/捡掉落" % [_region_name(hot_region), _region_name(cache_region)])
	hud.toast("休息段：下一轮热点 %s；补给箱在 %s（休息结束消失）" % [_region_name(hot_region), _region_name(cache_region)], 3)

func start_spawn() -> void:
	expire_normal_drops()
	phase = "spawn"
	phase_clock = 30.0
	spawn_budget = 18 + 8 * cycle
	spawn_timer = 0.0
	if cycle >= 6 and not boss_spawned:
		_spawn_boss()
	_set_phase_text("出怪：林线有动静（热点 %s）" % _region_name(hot_region))
	hud.toast("出怪：林线有动静（热点 %s）" % _region_name(hot_region), 3)

func _region_name(index: int) -> String:
	var names := ["北", "东北", "东", "东南", "南", "西南", "西", "西北"]
	return names[index % names.size()]

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
		if cycle >= 3 and rng.randf() < 0.18: kind = "barrel"
		if cycle >= 4 and rng.randf() < 0.15: kind = "shielded"
		if cycle >= 5 and rng.randf() < 0.15: kind = "armored"
		var health := 42.0 + cycle * 14.0
		if kind == "barrel": health *= 1.6
		if kind == "shielded": health *= 2.2
		if kind == "armored": health *= 2.6
		spawn_enemy(kind, point, health)
		spawn_budget -= 1
	spawn_timer = 0.9
	spawned_this_phase += count
	debug.regions[region] += 1

func _spawn_boss() -> void:
	boss_spawned = true
	var point: Vector2 = spawn_points[hot_region]
	spawn_enemy("boss", point, 2600.0)
	hud.toast("焚林统领从%s林线走来", 4)

func spawn_enemy(kind: String, point: Vector2, health: float) -> ArenaEnemy:
	var enemy := ArenaEnemy.new()
	enemy.game = self
	enemy.kind = kind
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
		spawn_drop(enemy.position, 60, 80, true)
		hud.toast("焚林统领倒下", 3)
	elif enemy.kind in ["shielded", "armored"]:
		spawn_drop(enemy.position, 12, 8, true)
	else:
		spawn_drop(enemy.position, 5, 3, false)
	if boss_dead and cycle >= 6 and enemies.is_empty():
		finish(true)

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
func spawn_drop(point: Vector2, xp: int, gold_value: int, big: bool, cache := false) -> ArenaDrop:
	var drop := ArenaDrop.new()
	drop.game = self
	drop.xp = xp
	drop.gold_value = gold_value
	drop.big = big
	drop.cache = cache
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
		hero.add_xp(drop.xp)
		gold += drop.gold_value
		hero.gold_gained += drop.gold_value
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

func spawn_projectile(origin: Vector2, target: Vector2, damage: float, color: Color, splash := 0.0, slow := 0.0, speed := 760.0) -> ArenaProjectile:
	var projectile := ArenaProjectile.new()
	projectile.game = self
	projectile.position = origin
	projectile.direction = (target - origin).normalized()
	projectile.damage = damage
	projectile.speed = speed
	projectile.color = color
	projectile.splash = splash
	projectile.slow = slow
	add_child(projectile)
	return projectile

func damage_radius(point: Vector2, radius: float, damage: float) -> void:
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(point) < radius:
			enemy.take_damage(damage)

func _set_phase_text(text: String) -> void:
	if hud != null: hud.phase_hint = text

# ── input ──────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if build_mode:
			try_build_at_mouse()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: build_kind = "bolt"
			KEY_2: build_kind = "cannon"
			KEY_3: build_kind = "frost"
			KEY_E: repair_nearest()
			KEY_R: get_tree().reload_current_scene()
			KEY_B:
				pass

# ── process ────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not running: return
	elapsed += delta
	_update_build_mode(delta)
	_update_phase(delta)
	_update_camera(delta)
	if build_mode:
		build_cell = world_to_cell(get_global_mouse_position())
		build_reason = can_place(build_cell)
		build_valid = build_reason == ""
	queue_redraw()

func _update_build_mode(delta: float) -> void:
	var wants := Input.is_action_pressed("build") and not game_over
	var can_slow := phase == "rest" or focus > 0.0
	build_mode = wants and can_slow
	if build_mode and phase != "rest":
		focus = maxf(0.0, focus - delta / 0.35)
		if focus <= 0.0: build_mode = false
	if not build_mode:
		focus = minf(focus_max, focus + delta * 0.9)
	Engine.time_scale = 0.35 if build_mode else sim_speed

func _update_camera(delta: float) -> void:
	var target := CORE
	var zoom := 0.58
	if build_mode:
		target = CORE
		zoom = 0.46
	elif hero != null:
		target = hero.position.clamp(Vector2(500, 500), ARENA_SIZE - Vector2(500, 500))
		zoom = 0.62
	camera.position = camera.position.lerp(target, 1.0 - exp(-4.0 * delta))
	camera.zoom = camera.zoom.lerp(Vector2(zoom, zoom), 1.0 - exp(-5.0 * delta))

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
	start_rest(15.0)

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
			var range_value := float(Rules.TOWERS[build_kind].range)
			draw_arc(cell_center(build_cell), range_value, 0, TAU, 64, Color(0.55, 0.9, 0.75, 0.45), 2, true)
	for rock in obstacles:
		draw_rect(rock, Color("4a4d44"))
		draw_rect(rock, Color("252b25"), false, 3)
	if build_mode:
		for cell in range(GRID_W * GRID_H):
			if reach[cell] == 0: continue
			var direction: Vector2 = flow[cell]
			if direction == Vector2.ZERO: continue
			var start := cell_center(Vector2i(cell % GRID_W, int(cell / GRID_W)))
			draw_line(start, start + direction * 18, Color(0.7, 0.9, 0.85, 0.18), 2)
