class_name ArenaRiftPCG
extends RefCounted
## Deterministic Seeded Multi-Floor Procedural Rift Dungeon Generator (v0.32).
## Generates 9..12 connected rooms on a 5x5 virtual grid with stage-weighted branching,
## quantized 64px variable footprints, strict connectivity doors (zero fake doors),
## room mutators, interior cover obstacles, volatile crystal barrels, and event nodes.

const TILE_SIZE := 64.0
const GRID_COLS := 5
const GRID_ROWS := 5
const CELL_STEP := Vector2(1080.0, 760.0)
const GRID_MARGIN := Vector2(560.0, 440.0)
const CORRIDOR_HALF_W := 74.0
const LAYOUT_ATTEMPTS := 48
const DIRECTIONS := [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]

const SHAPES := {
	"hub": Vector2i(12, 8),
	"standard": Vector2i(12, 8),
	"wide_hall": Vector2i(14, 8),
	"tall_arena": Vector2i(12, 10),
	"vault": Vector2i(10, 7),
	"boss_sanctum": Vector2i(15, 10),
}

const MUTATORS := {
	"none": {"id": "none", "name": "", "color": Color(0, 0, 0, 0), "count_mult": 1.0, "elite_bonus": 0, "gold_mult": 1.0, "extra_barrels": 0, "hazard_bonus": false, "desc": ""},
	"swarm_tide": {"id": "swarm_tide", "name": "狂潮怪海", "color": Color("ff6c62"), "count_mult": 1.45, "elite_bonus": 0, "gold_mult": 1.15, "extra_barrels": 0, "hazard_bonus": false, "desc": "敌潮密度+45%，畅快割草！"},
	"twin_elites": {"id": "twin_elites", "name": "双生精英", "color": Color("d878ff"), "count_mult": 1.05, "elite_bonus": 2, "gold_mult": 1.25, "extra_barrels": 0, "hazard_bonus": false, "desc": "成对重装精英参战，掉落更丰厚"},
	"gold_rush": {"id": "gold_rush", "name": "黄金宝藏潮", "color": Color("ffe678"), "count_mult": 1.15, "elite_bonus": 0, "gold_mult": 1.65, "extra_barrels": 0, "hazard_bonus": false, "desc": "大批黄金赏金怪，金币暴增"},
	"volatile_barrels": {"id": "volatile_barrels", "name": "爆裂晶簇", "color": Color("68f0ff"), "count_mult": 1.20, "elite_bonus": 0, "gold_mult": 1.10, "extra_barrels": 3, "hazard_bonus": false, "desc": "布满爆裂水晶桶，引爆清屏"},
	"elemental_surge": {"id": "elemental_surge", "name": "元素过载", "color": Color("88a4ff"), "count_mult": 1.15, "elite_bonus": 1, "gold_mult": 1.20, "extra_barrels": 1, "hazard_bonus": true, "desc": "周期元素法阵喷发，可诱敌炸伤"},
}

const MUTATOR_POOL := ["swarm_tide", "twin_elites", "gold_rush", "volatile_barrels", "elemental_surge"]
const EVENT_KINDS := ["blood_altar", "forge_anvil", "star_pedestal"]
const TEMPLATES := ["open_arena", "four_pillars", "twin_barricades", "barrel_ring", "hazard_cross", "rune_nexus"]

const BIOME_TITLES := {
	"wilds": ["荒林猎场", "古藤石厅", "兽嗥回廊", "苔石试炼", "荆棘岔路", "苍木祭台", "野性裂窟", "风啸林庭"],
	"abyss": ["暗潮石厅", "珊瑚密室", "龙宫东廊", "深海猎场", "碎礁回廊", "碧渊玄室", "漩涡长殿", "潮汐试炼"],
	"void": ["星纹中庭", "虚空祭廊", "暮光石室", "碎晶长廊", "紫雾试炼", "暗星密殿", "深渊回廊", "蚀影玄厅"],
}


static func _edge_key(a: String, b: String) -> String:
	return (a + ":" + b) if a < b else (b + ":" + a)


static func _new_topology(hub: Vector2i) -> Dictionary:
	return {
		"occupied": {hub: "hub"},
		"cells": [{"rid": "hub", "col": hub.x, "row": hub.y}],
		"edges": {},
		"adjacency": {"hub": []}
	}


static func _connect(topology: Dictionary, a: String, b: String) -> void:
	topology.edges[_edge_key(a,b)] = [a,b]
	topology.adjacency[a].append(b)
	topology.adjacency[b].append(a)


static func _grow_room(topology: Dictionary, point: Vector2i, parent: String) -> Dictionary:
	var id := "r_%d_%d" % [point.x,point.y]
	var cell := {"rid": id, "col": point.x, "row": point.y}
	topology.occupied[point] = id
	topology.cells.append(cell)
	topology.adjacency[id] = []
	_connect(topology,parent,id)
	return cell


static func _random_topology(prng: RandomNumberGenerator, target_count: int, theme_key: String) -> Dictionary:
	var hub := Vector2i(prng.randi_range(1,3),GRID_ROWS-1)
	var topology := _new_topology(hub)
	var occupied: Dictionary = topology.occupied
	var cells: Array = topology.cells
	var frontier: Array = [cells[0]]
	while cells.size() < target_count and not frontier.is_empty():
		var pick_idx := prng.randi_range(0,frontier.size()-1)
		var base: Dictionary = frontier[pick_idx]
		var origin := Vector2i(base.col,base.row)
		var candidates: Array[Vector2i] = []
		for direction: Vector2i in DIRECTIONS:
			var point := origin + direction
			if not Rect2i(0,0,GRID_COLS,GRID_ROWS).has_point(point) or occupied.has(point):
				continue
			candidates.append(point)
			if (theme_key == "wilds" and direction.x != 0) or (theme_key == "void" and direction.y < 0) or (theme_key == "abyss" and direction.y <= 0):
				candidates.append(point)
		if candidates.is_empty():
			frontier.remove_at(pick_idx)
			continue
		frontier.append(_grow_room(topology,candidates[prng.randi_range(0,candidates.size()-1)],str(base.rid)))

	var shortcuts: Array[Array] = []
	for cell: Dictionary in cells:
		for direction: Vector2i in [Vector2i.RIGHT,Vector2i.UP]:
			var neighbor: String = occupied.get(Vector2i(cell.col,cell.row)+direction,"")
			if not neighbor.is_empty() and not topology.edges.has(_edge_key(str(cell.rid),neighbor)):
				shortcuts.append([cell.rid,neighbor])
	for _index in mini(prng.randi_range(1,2),shortcuts.size()):
		var edge: Array = shortcuts.pop_at(prng.randi_range(0,shortcuts.size()-1))
		_connect(topology,edge[0],edge[1])
	return topology


static func _paths_from_hub(adjacency: Dictionary) -> Dictionary:
	var paths := {"hub": ["hub"]}
	var frontier: Array[String] = ["hub"]
	while not frontier.is_empty():
		var room: String = frontier.pop_front()
		for neighbor: String in adjacency[room]:
			if not paths.has(neighbor):
				paths[neighbor] = paths[room] + [neighbor]
				frontier.append(neighbor)
	return paths


static func _place_landmarks(topology: Dictionary, prng: RandomNumberGenerator) -> Dictionary:
	var adjacent: Dictionary = topology.adjacency
	var paths := _paths_from_hub(adjacent)
	if paths.size() < 9 or paths.size() != adjacent.size() or topology.edges.size() < adjacent.size():
		return {}
	var columns := {}
	var rows := {}
	var ends: Array[String] = []
	for cell: Dictionary in topology.cells:
		columns[cell.col] = true
		rows[cell.row] = true
		if cell.rid != "hub" and adjacent[cell.rid].size() == 1:
			ends.append(cell.rid)
	if columns.size() < 3 or rows.size() < 3 or ends.size() < 2 or ends.size() > 4:
		return {}
	if adjacent.hub.size() < 2 and adjacent[adjacent.hub[0]].size() < 3:
		return {}
	var bosses: Array[String] = []
	for id in ends:
		if paths[id].size() in range(5,8):
			bosses.append(id)
	while not bosses.is_empty():
		var boss: String = bosses.pop_at(prng.randi_range(0,bosses.size()-1))
		var main: Array = paths[boss]
		var minibosses: Array[String] = []
		for id in ends:
			if id not in main and paths[id].size() >= 3:
				minibosses.append(id)
		while not minibosses.is_empty():
			var miniboss: String = minibosses.pop_at(prng.randi_range(0,minibosses.size()-1))
			var early: Array[String] = []
			var side: Array[String] = []
			for id: String in paths:
				if id in main or id == miniboss:
					continue
				side.append(id)
				if paths[id].size() <= 4:
					early.append(id)
			if side.size() < 2 or early.is_empty():
				continue
			early.sort_custom(func(a,b): return paths[a].size() < paths[b].size())
			var nearest := early.filter(func(id):return paths[id].size() == paths[early[0]].size())
			var chest: String = nearest[prng.randi_range(0,nearest.size()-1)]
			side.erase(chest)
			return {"boss": boss, "miniboss": miniboss, "chest": chest, "event": side[prng.randi_range(0,side.size()-1)], "main_path": main, "paths": paths}
	return {}


static func _backbone_topology(prng: RandomNumberGenerator, target_count: int) -> Dictionary:
	var hub := Vector2i(prng.randi_range(1,3),GRID_ROWS-1)
	var side := -1 if prng.randi_range(0,1) == 0 else 1
	var topology := _new_topology(hub)
	var offsets := [Vector2i.ZERO, Vector2i(0,-1), Vector2i(0,-2), Vector2i(0,-3), Vector2i(0,-4), Vector2i(side,0), Vector2i(side,-1), Vector2i(-side,-1), Vector2i(-side,-2), Vector2i(side,-2), Vector2i(side,-3), Vector2i(-side,-3)]
	var parents := [0,0,1,2,3,0,5,1,7,6,9,8]
	var ids: Array[String] = ["hub"]
	for index in range(1,target_count):
		ids.append(str(_grow_room(topology,hub+offsets[index],ids[parents[index]]).rid))
	_connect(topology,ids[1],ids[6])
	return topology


static func generate_floor(seed_val: int, stage_id: String, theme_key: String, floor_idx: int, rift_origin: Vector2) -> Dictionary:
	var prng := RandomNumberGenerator.new()
	prng.seed = int(hash(str(seed_val) + "|" + stage_id + "|floor_" + str(floor_idx)))
	var target_count := clampi(9 + (floor_idx - 1) + prng.randi_range(0,2),9,12)
	var topology: Dictionary
	var landmarks := {}
	for _attempt in LAYOUT_ATTEMPTS:
		topology = _random_topology(prng,target_count,theme_key)
		landmarks = _place_landmarks(topology,prng)
		if not landmarks.is_empty():
			break
	if landmarks.is_empty():
		topology = _backbone_topology(prng,target_count)
		landmarks = _place_landmarks(topology,prng)
	var cells: Array = topology.cells
	var edges: Dictionary = topology.edges
	var adjacency: Dictionary = topology.adjacency
	var paths: Dictionary = landmarks.paths
	var hub_id := "hub"
	var boss_rid := str(landmarks.boss)
	var mb_rid := str(landmarks.miniboss)
	var event_rid := str(landmarks.event)
	var chest_rid := str(landmarks.chest)

	# Build full Room Dictionaries
	var rooms: Dictionary = {}
	var room_order: Array[String] = [hub_id]
	for cid: String in paths:
		if cid != hub_id:room_order.append(cid)

	var titles_bank: Array = BIOME_TITLES.get(theme_key, BIOME_TITLES["wilds"])
	var min_col := GRID_COLS
	var max_col := 0
	var min_row := GRID_ROWS
	var max_row := 0
	for c_entry: Dictionary in cells:
		min_col = mini(min_col, int(c_entry.col))
		max_col = maxi(max_col, int(c_entry.col))
		min_row = mini(min_row, int(c_entry.row))
		max_row = maxi(max_row, int(c_entry.row))

	var elite_quota := 2 + (1 if floor_idx >= 2 else 0)
	var elites_assigned := 0
	var tall_rooms := {}
	for cell: Dictionary in cells:
		if cell.rid == boss_rid:tall_rooms[Vector2i(cell.col,cell.row)] = true
	for c_i in range(cells.size()):
		var c_entry: Dictionary = cells[c_i]
		var rid := str(c_entry.rid)
		var col := int(c_entry.col)
		var row := int(c_entry.row)
		var center := rift_origin + GRID_MARGIN + Vector2(float(col) * CELL_STEP.x, float(row) * CELL_STEP.y)

		var kind := "combat"
		var shape_key := "standard"
		var title := str(titles_bank[c_i % titles_bank.size()])
		var waves := 2 + (1 if floor_idx >= 3 else 0)
		var reward := ""
		var event_kind := ""
		var mutator_id := "none"
		var template_id := "open_arena"

		if rid == hub_id:
			kind = "hub"
			shape_key = "hub"
			title = "安全圣殿 · 第%d层" % floor_idx
			waves = 0
		elif rid == boss_rid:
			kind = "boss"
			shape_key = "boss_sanctum"
			title = "首领神殿 · 第%d层" % floor_idx
			waves = 2 if floor_idx >= 2 else 1
			reward = "boss_chest"
			template_id = "four_pillars" if floor_idx >= 2 else "barrel_ring"
		elif rid == mb_rid:
			kind = "miniboss"
			shape_key = "wide_hall" if prng.randf() < 0.55 else "tall_arena"
			title = "统领巢穴"
			waves = 2
			reward = "miniboss_relic"
			template_id = "barrel_ring" if prng.randf() < 0.5 else "twin_barricades"
		elif rid == event_rid:
			kind = "event"
			shape_key = "vault"
			event_kind = str(EVENT_KINDS[prng.randi_range(0, EVENT_KINDS.size() - 1)])
			title = "血契魔坛" if event_kind == "blood_altar" else ("防线铁砧" if event_kind == "forge_anvil" else "星辉秘宝台")
			waves = 0
			template_id = "open_arena"
		elif rid == chest_rid:
			kind = "chest"
			shape_key = "vault"
			title = "秘宝藏库"
			waves = 1
			reward = "chest"
			template_id = "barrel_ring"
		else:
			if elites_assigned < elite_quota and prng.randf() < 0.42:
				kind = "elite"
				elites_assigned += 1
				title = "精锐试炼窟"
			var shape_choices := ["standard", "wide_hall", "tall_arena"]
			if theme_key == "wilds":
				shape_choices = ["wide_hall", "wide_hall", "standard", "tall_arena"]
			elif theme_key == "abyss":
				shape_choices = ["tall_arena", "wide_hall", "standard"]
			shape_key = str(shape_choices[prng.randi_range(0, shape_choices.size() - 1)])
			template_id = str(TEMPLATES[prng.randi_range(0, TEMPLATES.size() - 1)])
			if floor_idx == 1 and paths[rid].size() <= 2:
				template_id = "twin_barricades" if prng.randf() < 0.6 else "open_arena"
			if prng.randf() < (0.58 if floor_idx == 1 else 0.75):
				mutator_id = str(MUTATOR_POOL[prng.randi_range(0, MUTATOR_POOL.size() - 1)])
				if theme_key == "wilds" and prng.randf() < 0.35:
					mutator_id = "swarm_tide" if prng.randf() < 0.5 else "volatile_barrels"
				elif theme_key == "void" and prng.randf() < 0.35:
					mutator_id = "elemental_surge"

		if shape_key == "tall_arena":
			var point := Vector2i(col,row)
			if tall_rooms.has(point+Vector2i.UP) or tall_rooms.has(point+Vector2i.DOWN):
				shape_key = "standard"
			else:
				tall_rooms[point] = true
		var tiles: Vector2i = SHAPES[shape_key]
		var inner_size := Vector2(float(tiles.x) * TILE_SIZE, float(tiles.y) * TILE_SIZE)
		var inner_rect := Rect2(center - inner_size * 0.5, inner_size)
		var vis_rect := inner_rect.grow(TILE_SIZE)
		var trigger_rect := inner_rect.grow(-40.0)
		var nbs: Array = adjacency[rid]
		var init_state := "cleared" if rid == hub_id else ("discovered" if hub_id in nbs else "hidden")

		rooms[rid] = {
			"id": rid,
			"col": col,
			"row": row,
			"kind": kind,
			"shape_key": shape_key,
			"main_route": rid in landmarks.main_path,
			"tile_cols": tiles.x,
			"tile_rows": tiles.y,
			"room_seed": prng.randi(),
			"title": title,
			"center": center,
			"vis_rect": vis_rect,
			"inner_rect": inner_rect,
			"trigger_rect": trigger_rect,
			"neighbors": nbs.duplicate(),
			"doors": [], # populated strictly after all rooms are created
			"state": init_state,
			"wave_idx": 0,
			"total_waves": waves,
			"wave_pause_clock": 0.0,
			"reward_kind": reward,
			"reward_pos": center + Vector2(0.0, 26.0 if kind == "boss" else 0.0),
			"reward_active": false,
			"reward_claimed": false,
			"event_kind": event_kind,
			"event_pos": center,
			"event_used": false,
			"mutator": mutator_id,
			"template": template_id,
			"obstacles": [],
			"barrels": [],
			"speed_pads": [],
			"hazards": [],
			"fog_alpha": 0.0 if rid == hub_id else (0.46 if init_state == "discovered" else 0.96),
		}

	# Populate STRICT doors + corridors from edges ONLY (never fake doors!)
	var corridors: Array[Dictionary] = []
	for ek: String in edges:
		var pair: Array = edges[ek]
		var ra_id := str(pair[0])
		var rb_id := str(pair[1])
		var r_a: Dictionary = rooms[ra_id]
		var r_b: Dictionary = rooms[rb_id]
		var dcol := int(r_b.col) - int(r_a.col)
		var drow := int(r_b.row) - int(r_a.row)
		var horiz: bool = abs(dcol) > abs(drow)
		if horiz:
			if dcol > 0:
				(r_a.doors as Array).append("E")
				(r_b.doors as Array).append("W")
			else:
				(r_a.doors as Array).append("W")
				(r_b.doors as Array).append("E")
		else:
			if drow > 0:
				(r_a.doors as Array).append("S")
				(r_b.doors as Array).append("N")
			else:
				(r_a.doors as Array).append("N")
				(r_b.doors as Array).append("S")

		var ia: Rect2 = r_a.inner_rect
		var ib: Rect2 = r_b.inner_rect
		var ca := Vector2(r_a.center)
		var cb := Vector2(r_b.center)
		var w_rect: Rect2
		var v_rect: Rect2
		if horiz:
			var left_r := ia if ca.x < cb.x else ib
			var right_r := ib if ca.x < cb.x else ia
			var x0 := left_r.end.x - 8.0
			var x1 := right_r.position.x + 8.0
			var ym := (ca.y + cb.y) * 0.5
			w_rect = Rect2(x0, ym - CORRIDOR_HALF_W, maxf(16.0, x1 - x0), CORRIDOR_HALF_W * 2.0)
			v_rect = Rect2(left_r.end.x, ym - 64.0, maxf(16.0, right_r.position.x - left_r.end.x), 128.0)
		else:
			var top_r := ia if ca.y < cb.y else ib
			var bot_r := ib if ca.y < cb.y else ia
			var y0 := top_r.end.y - 8.0
			var y1 := bot_r.position.y + 8.0
			var xm := (ca.x + cb.x) * 0.5
			w_rect = Rect2(xm - CORRIDOR_HALF_W, y0, CORRIDOR_HALF_W * 2.0, maxf(16.0, y1 - y0))
			v_rect = Rect2(xm - 64.0, top_r.end.y, 128.0, maxf(16.0, bot_r.position.y - top_r.end.y))
		corridors.append({"a": ra_id, "b": rb_id, "rect": w_rect, "vis_rect": v_rect, "horizontal": horiz})

	# Generate interior obstacles, explosive crystal barrels, speed pads, and hazards
	for rid in room_order:
		var rm: Dictionary = rooms[rid]
		_populate_room_features(rm, prng)

	# Compute dynamic rift world bounds across all generated rooms
	var min_pt := Vector2(INF, INF)
	var max_pt := Vector2(-INF, -INF)
	for rid in room_order:
		var vr: Rect2 = rooms[rid].vis_rect
		min_pt.x = minf(min_pt.x, vr.position.x)
		min_pt.y = minf(min_pt.y, vr.position.y)
		max_pt.x = maxf(max_pt.x, vr.end.x)
		max_pt.y = maxf(max_pt.y, vr.end.y)
	var world_rect := Rect2(min_pt - Vector2(440.0, 320.0), (max_pt - min_pt) + Vector2(880.0, 640.0))

	return {
		"rooms": rooms,
		"room_order": room_order,
		"corridors": corridors,
		"world_rect": world_rect,
		"boss_room_id": boss_rid,
		"miniboss_room_id": mb_rid,
		"event_room_id": event_rid,
		"grid_bounds": Rect2i(min_col, min_row, maxi(1, max_col - min_col + 1), maxi(1, max_row - min_row + 1)),
	}


static func _populate_room_features(rm: Dictionary, prng: RandomNumberGenerator) -> void:
	var kind := str(rm.kind)
	if kind in ["hub", "event"]:
		return
	var rid := str(rm.id)
	var c := Vector2(rm.center)
	var ir: Rect2 = rm.inner_rect
	var hx := ir.size.x * 0.5 - 92.0
	var hy := ir.size.y * 0.5 - 76.0
	var tmpl := str(rm.template)
	var mut: Dictionary = MUTATORS.get(str(rm.mutator), MUTATORS["none"])

	var obs: Array = rm.obstacles
	var barrels: Array = rm.barrels
	var pads: Array = rm.speed_pads
	var hazards: Array = rm.hazards

	if tmpl == "four_pillars":
		for sx: float in [-0.52, 0.52]:
			for sy: float in [-0.48, 0.48]:
				var p := c + Vector2(sx * hx, sy * hy)
				obs.append(Rect2(p - Vector2(26.0, 22.0), Vector2(52.0, 44.0)))
		barrels.append({"pos": c + Vector2(-hx * 0.72, 0.0), "hp": 32.0, "max_hp": 32.0, "alive": true, "room_id": rid})
		barrels.append({"pos": c + Vector2(hx * 0.72, 0.0), "hp": 32.0, "max_hp": 32.0, "alive": true, "room_id": rid})
	elif tmpl == "twin_barricades":
		for sx: float in [-0.46, 0.46]:
			var p := c + Vector2(sx * hx, 0.0)
			obs.append(Rect2(p - Vector2(26.0, 26.0), Vector2(52.0, 52.0)))
		for sy: float in [-0.54, 0.54]:
			barrels.append({"pos": c + Vector2(0.0, sy * hy), "hp": 32.0, "max_hp": 32.0, "alive": true, "room_id": rid})
	elif tmpl == "barrel_ring":
		for ang_i in range(4):
			var ang := float(ang_i) * (PI * 0.5) + PI * 0.25
			var bp := c + Vector2(cos(ang) * hx * 0.58, sin(ang) * hy * 0.56)
			barrels.append({"pos": bp, "hp": 32.0, "max_hp": 32.0, "alive": true, "room_id": rid})
	elif tmpl == "rune_nexus":
		pads.append(c + Vector2(-hx * 0.45, 0.0))
		pads.append(c + Vector2(hx * 0.45, 0.0))
		barrels.append({"pos": c + Vector2(0.0, -hy * 0.58), "hp": 32.0, "max_hp": 32.0, "alive": true, "room_id": rid})
		barrels.append({"pos": c + Vector2(0.0, hy * 0.58), "hp": 32.0, "max_hp": 32.0, "alive": true, "room_id": rid})
	elif tmpl == "hazard_cross":
		for off: Vector2 in [Vector2(-hx * 0.48, -hy * 0.42), Vector2(hx * 0.48, hy * 0.42)]:
			hazards.append({"pos": c + off, "radius": 62.0, "clock": prng.randf_range(0.0, 2.5), "cycle": 4.2, "armed": false})
		barrels.append({"pos": c + Vector2(hx * 0.48, -hy * 0.42), "hp": 32.0, "max_hp": 32.0, "alive": true, "room_id": rid})
		barrels.append({"pos": c + Vector2(-hx * 0.48, hy * 0.42), "hp": 32.0, "max_hp": 32.0, "alive": true, "room_id": rid})
	else:
		# open_arena still gets 2 corner barrels & 1 speed rune
		pads.append(c + Vector2(0.0, hy * 0.45))
		barrels.append({"pos": c + Vector2(-hx * 0.62, -hy * 0.46), "hp": 32.0, "max_hp": 32.0, "alive": true, "room_id": rid})
		barrels.append({"pos": c + Vector2(hx * 0.62, -hy * 0.46), "hp": 32.0, "max_hp": 32.0, "alive": true, "room_id": rid})

	# Mutator bonus props
	var extra_b := int(mut.get("extra_barrels", 0))
	for bi in range(extra_b):
		var ang := prng.randf_range(0.0, TAU)
		var cand := (c + Vector2(cos(ang) * hx * 0.66, sin(ang) * hy * 0.60)).clamp(ir.position + Vector2(68, 68), ir.end - Vector2(68, 68))
		var blocked := false
		for ob: Rect2 in obs:
			if ob.grow(24.0).has_point(cand):
				blocked = true
				break
		if not blocked and cand.distance_to(c) > 65.0:
			barrels.append({"pos": cand, "hp": 32.0, "max_hp": 32.0, "alive": true, "room_id": rid})

	if bool(mut.get("hazard_bonus", false)) and hazards.is_empty():
		for sx: float in [-0.42, 0.42]:
			hazards.append({"pos": c + Vector2(sx * hx, 0.0), "radius": 66.0, "clock": prng.randf_range(0.0, 2.0), "cycle": 3.6, "armed": false})
