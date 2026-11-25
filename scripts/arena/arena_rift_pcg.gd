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


static func _cell_key(col: int, row: int) -> String:
	return "%d_%d" % [col, row]


static func _edge_key(a: String, b: String) -> String:
	return (a + ":" + b) if a < b else (b + ":" + a)


static func generate_floor(seed_val: int, stage_id: String, theme_key: String, floor_idx: int, rift_origin: Vector2) -> Dictionary:
	var prng := RandomNumberGenerator.new()
	prng.seed = int(hash(str(seed_val) + "|" + stage_id + "|floor_" + str(floor_idx)))

	var target_count := clampi(9 + (floor_idx - 1) + prng.randi_range(0, 2), 9, 12)
	var hub_col := clampi(1 + prng.randi_range(0, 2), 1, 3)
	var hub_row := GRID_ROWS - 1
	var occupied: Dictionary = {} # cell_key -> {col, row, rid}
	var cells: Array[Dictionary] = []
	var edges: Dictionary = {} # edge_key -> [rid_a, rid_b]
	var adjacency: Dictionary = {} # rid -> Array[String]

	var hub_id := "hub"
	occupied[_cell_key(hub_col, hub_row)] = hub_id
	cells.append({"rid": hub_id, "col": hub_col, "row": hub_row})
	adjacency[hub_id] = []

	var dirs := [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]
	var room_counter := 1
	var frontier: Array[Dictionary] = [{"rid": hub_id, "col": hub_col, "row": hub_row}]
	var safety := 0

	# Stage-biased spanning tree growth on 5x5 grid
	while cells.size() < target_count and safety < 240:
		safety += 1
		if frontier.is_empty():
			frontier = cells.duplicate()
		var pick_idx: int = prng.randi_range(0, frontier.size() - 1)
		if theme_key == "void" and frontier.size() > 1 and prng.randf() < 0.55:
			# Void favors branching from northernmost / newest frontier
			pick_idx = frontier.size() - 1
		var base_node: Dictionary = frontier[pick_idx]
		var b_col := int(base_node.col)
		var b_row := int(base_node.row)

		var candidates: Array[Vector2i] = []
		for d: Vector2i in dirs:
			var nc := b_col + d.x
			var nr := b_row + d.y
			if nc >= 0 and nc < GRID_COLS and nr >= 0 and nr < GRID_ROWS:
				if not occupied.has(_cell_key(nc, nr)):
					candidates.append(d)
					# Stage-specific directional bias via weighted duplicate candidates
					if theme_key == "wilds" and abs(d.x) > 0:
						candidates.append(d)
					elif theme_key == "void" and d.y < 0:
						candidates.append(d)
					elif theme_key == "abyss" and (d.y < 0 or abs(d.x) > 0):
						candidates.append(d)
		if candidates.is_empty():
			frontier.remove_at(pick_idx)
			continue
		var chosen_d: Vector2i = candidates[prng.randi_range(0, candidates.size() - 1)]
		var next_c := b_col + chosen_d.x
		var next_r := b_row + chosen_d.y
		var new_rid := "r_%d_%d" % [next_c, next_r]
		room_counter += 1
		occupied[_cell_key(next_c, next_r)] = new_rid
		var new_entry := {"rid": new_rid, "col": next_c, "row": next_r}
		cells.append(new_entry)
		frontier.append(new_entry)
		adjacency[new_rid] = [str(base_node.rid)]
		(adjacency[str(base_node.rid)] as Array).append(new_rid)
		edges[_edge_key(str(base_node.rid), new_rid)] = [str(base_node.rid), new_rid]

	# Add 1..2 loop shortcut corridors between adjacent cells for tactical variety
	var extra_loops := prng.randi_range(1, 2)
	var loop_cands: Array[Array] = []
	for cell_d: Dictionary in cells:
		var cid := str(cell_d.rid)
		var cc := int(cell_d.col)
		var cr := int(cell_d.row)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, -1)]:
			var nk := _cell_key(cc + d.x, cr + d.y)
			if occupied.has(nk):
				var nid := str(occupied[nk])
				var ek := _edge_key(cid, nid)
				if not edges.has(ek):
					loop_cands.append([cid, nid, ek])
	for _l in range(extra_loops):
		if loop_cands.is_empty():
			break
		var li: int = prng.randi_range(0, loop_cands.size() - 1)
		var pair: Array = loop_cands[li]
		loop_cands.remove_at(li)
		edges[str(pair[2])] = [str(pair[0]), str(pair[1])]
		(adjacency[str(pair[0])] as Array).append(str(pair[1]))
		(adjacency[str(pair[1])] as Array).append(str(pair[0]))

	# BFS distance map from hub
	var dist_map: Dictionary = {hub_id: 0}
	var bfs_q: Array[String] = [hub_id]
	while not bfs_q.is_empty():
		var cur_id: String = bfs_q.pop_front()
		var cur_d: int = int(dist_map[cur_id])
		for nb: String in adjacency[cur_id]:
			if not dist_map.has(nb):
				dist_map[nb] = cur_d + 1
				bfs_q.append(nb)

	# Assign special rooms cleanly by BFS depth
	var sorted_by_dist: Array[String] = []
	for cell_d: Dictionary in cells:
		var cid := str(cell_d.rid)
		if cid != hub_id:
			sorted_by_dist.append(cid)
	sorted_by_dist.sort_custom(func(a: String, b: String) -> bool:
		var da := int(dist_map.get(a, 0))
		var db := int(dist_map.get(b, 0))
		return da > db if da != db else a < b
	)

	var boss_rid := sorted_by_dist[0] if not sorted_by_dist.is_empty() else hub_id
	var used_special := {hub_id: true, boss_rid: true}

	var mb_rid := ""
	for cid in sorted_by_dist:
		if not used_special.has(cid) and int(dist_map.get(cid, 0)) >= 2:
			mb_rid = cid
			used_special[cid] = true
			break
	if mb_rid.is_empty() and sorted_by_dist.size() >= 2:
		mb_rid = sorted_by_dist[1]
		used_special[mb_rid] = true

	var event_rid := ""
	var mid_idx := clampi(sorted_by_dist.size() / 2, 0, maxi(0, sorted_by_dist.size() - 1))
	for offset in range(sorted_by_dist.size()):
		var cid: String = sorted_by_dist[(mid_idx + offset) % sorted_by_dist.size()]
		if not used_special.has(cid):
			event_rid = cid
			used_special[cid] = true
			break

	var chest_rid := ""
	for cid in sorted_by_dist:
		if not used_special.has(cid):
			chest_rid = cid
			used_special[cid] = true
			break

	# Build full Room Dictionaries
	var rooms: Dictionary = {}
	var room_order: Array[String] = [hub_id]
	for cid in sorted_by_dist:
		room_order.append(cid)

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
			if prng.randf() < (0.58 if floor_idx == 1 else 0.75):
				mutator_id = str(MUTATOR_POOL[prng.randi_range(0, MUTATOR_POOL.size() - 1)])
				if theme_key == "wilds" and prng.randf() < 0.35:
					mutator_id = "swarm_tide" if prng.randf() < 0.5 else "volatile_barrels"
				elif theme_key == "void" and prng.randf() < 0.35:
					mutator_id = "elemental_surge"

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
