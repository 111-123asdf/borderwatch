class_name ArenaRiftDomain
extends Node2D
## Multi-Floor Seeded Procedural Rift Dungeon & Dynamic Portal Coordinator (v0.32).
## Runs simultaneously with Defense Domain (0..1600, 0..900) inside RIFT_ORIGIN..world_rect.end,
## assembling 64x64 modular tiles + GLSL value-noise floor shading, strict connectivity doors,
## cover pillars, chain-exploding crystal barrels, event shrines, mutators, and deep floor descent.

class _RiftFloorCanvas:
	extends Node2D
	var domain_node: Node2D
	func _draw() -> void:
		if domain_node == null:
			return
		domain_node._draw_modular_dungeon(self)

const RIFT_ORIGIN := Vector2(4000.0, 0.0)
const PORTAL_COOLDOWN := 14.0
const FORMATIONS := {
	"wilds": ["tusk_fighter","rottooth_hyena","dreadeye_viper"],
	"abyss": ["tide_warrior","tide_rider","conch_mage"],
	"void": ["twilight_avenger","avenger_rider","venom_spitter"]
}

const BIOME_CONFIGS := {
	"wilds": {
		"title": "荒林秘境",
		"short": "荒林",
		"tint": Color("f6ffec"),
		"bg": Color("0d120e"),
		"mobs": ["pigsoldier", "rottooth_hyena", "throat_cutter", "tusk_fighter", "dreadeye_viper", "bear_woodsman"],
		"elites": ["bear_vanguard", "darksteel_guard"],
		"miniboss": "darksteel_boss",
		"boss": "darksteel_boss",
		"alt_boss": "two_headed_troll",
	},
	"abyss": {
		"title": "沉渊龙宫",
		"short": "沉渊",
		"tint": Color("ecffff"),
		"bg": Color("08141c"),
		"mobs": ["murloc_hunter", "tide_rider", "water_sprite", "tide_warrior", "wind_captain", "conch_mage"],
		"elites": ["tempest_elemental", "bloodshell_crab"],
		"miniboss": "bloodshell_boss",
		"boss": "bloodshell_boss",
		"alt_boss": "leviathan",
	},
	"void": {
		"title": "紫雾星殿",
		"short": "紫雾",
		"tint": Color("f4ebff"),
		"bg": Color("0c0e17"),
		"mobs": ["void_eyeling", "twilight_harasser", "spectral_cutter", "twilight_avenger", "avenger_rider", "venom_spitter"],
		"elites": ["twilight_golem", "bloodsoil_behemoth"],
		"miniboss": "bloodsoil_boss",
		"boss": "bloodsoil_boss",
		"alt_boss": "baj_nimen",
	},
}

var game: Node2D
var stage_id: String = "forest"
var theme_key: String = "wilds"
var layout: Dictionary = {}
var run_seed: int = 1
var floor_index: int = 1
var floors_cleared: int = 0
var floor_rng := RandomNumberGenerator.new()

var rooms: Dictionary = {}
var corridors: Array[Dictionary] = []
var room_order: Array[String] = []
var world_rect: Rect2 = Rect2(RIFT_ORIGIN, Vector2(5600.0, 4200.0))
var grid_bounds: Rect2i = Rect2i(0, 0, 5, 5)
var active_combat_room: String = ""
var _combat_resume_position := Vector2.INF

var defense_portal_pos: Vector2 = Vector2(1320.0, 520.0)
var return_portal_pos: Vector2 = RIFT_ORIGIN + Vector2(2000.0, 2000.0)
var descent_gate_active: bool = false
var descent_gate_pos: Vector2 = Vector2.ZERO
var descent_gate_room: String = ""
var hero_speed_pad_clock: float = 0.0

var portal_cooldown: float = 0.0
var rift_dwell_time: float = 0.0
var total_rift_time: float = 0.0
var _telegraphs: Array[Dictionary] = []
var _reserve_groups: Array[Dictionary] = []
var _reserve_clock := 0.0
var _room_group_idx := 0
var _room_front := Vector2.UP
var _room_flank_sign := 1.0
var _magnet_timers: Array[Dictionary] = []

# Warp animation & iris transition state (zero accidental teleportation)
var warp_phase: String = "" # "", "out", "in"
var warp_target: String = "" # "rift", "defense", "descend"
var warp_clock: float = 0.0
var iris_progress: float = 0.0
var _portal_fx: Array[Dictionary] = []

# Threat & 3-tier alarm state for HUD & audio
var max_road_ratio: float = 0.0
var live_road_enemies: int = 0
var alarm_level: int = 0
var core_hit_alert: float = 0.0
var _beep_clock: float = 0.0
var transition_flash: float = 0.0
var _event_prompt_cd: float = 0.0

var _floor_root: Node2D
var _tile_canvas: _RiftFloorCanvas
var _fog_layer: Node2D
var _fog_rects: Dictionary = {}

# Textures (modular v0.32 + shared v0.31 VFX/props)
var _tex_floor_tiles: Texture2D
var _tex_wall_tiles: Texture2D
var _tex_corridor_biome: Texture2D
var _tex_pillar: Texture2D
var _tex_barrel: Texture2D
var _tex_altar_blood: Texture2D
var _tex_anvil_forge: Texture2D
var _tex_pedestal: Texture2D
var _tex_descent_gate: Texture2D
var _tex_chest_closed: Texture2D
var _tex_chest_open: Texture2D
var _tex_barrier: Texture2D
var _tex_portal_warp: Texture2D


func configure(owner_game: Node2D, p_stage_id: String) -> void:
	game = owner_game
	stage_id = p_stage_id
	z_index = -5
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if stage_id in ["saltport", "lighthouse"]:
		theme_key = "abyss"
	elif stage_id in ["ruins", "sanctum"]:
		theme_key = "void"
	else:
		theme_key = "wilds"
	layout = BIOME_CONFIGS[theme_key].duplicate(true)
	defense_portal_pos = Vector2(game.level_definition.get("hero_spawn", Vector2(1360, 500)))
	run_seed = int(game.rng.randi())
	if run_seed == 0:
		run_seed = 424242
	floor_index = 1
	floors_cleared = 0

	_load_textures()
	_build_topology()
	_rebuild_visual_layers()

	portal_cooldown = 0.0
	rift_dwell_time = 0.0
	total_rift_time = 0.0
	hero_speed_pad_clock = 0.0
	_telegraphs.clear()
	_magnet_timers.clear()
	_portal_fx.clear()
	warp_phase = ""
	warp_target = ""
	warp_clock = 0.0
	iris_progress = 0.0
	alarm_level = 0
	core_hit_alert = 0.0
	transition_flash = 0.0


func _load_tex(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _load_textures() -> void:
	_tex_floor_tiles = _load_tex("res://assets/rift_v032/tiles_%s_floor.png" % theme_key)
	_tex_wall_tiles = _load_tex("res://assets/rift_v032/tiles_%s_wall.png" % theme_key)
	_tex_corridor_biome = _load_tex("res://assets/rift_v032/tiles_%s_corridor.png" % theme_key)
	_tex_pillar = _load_tex("res://assets/rift_v032/prop_pillar_%s.png" % theme_key)
	_tex_barrel = _load_tex("res://assets/rift_v032/prop_barrel_crystal.png")
	_tex_altar_blood = _load_tex("res://assets/rift_v032/prop_altar_blood.png")
	_tex_anvil_forge = _load_tex("res://assets/rift_v032/prop_anvil_forge.png")
	_tex_pedestal = _load_tex("res://assets/rift_v032/prop_pedestal_choice.png")
	_tex_descent_gate = _load_tex("res://assets/rift_v032/prop_descent_gate.png")
	_tex_chest_closed = _load_tex("res://assets/rift_v031/prop_chest_closed.png")
	_tex_chest_open = _load_tex("res://assets/rift_v031/prop_chest_open.png")
	_tex_barrier = _load_tex("res://assets/rift_v031/prop_barrier_pillar.png")
	_tex_portal_warp = _load_tex("res://assets/vfx_v031/vfx_portal_warp.png")


func _build_topology() -> void:
	floor_rng.seed = int(hash(str(run_seed) + "|spawn|" + stage_id + "|" + str(floor_index)))
	var gen := ArenaRiftPCG.generate_floor(run_seed, stage_id, theme_key, floor_index, RIFT_ORIGIN)
	rooms = gen.rooms
	corridors = gen.corridors
	room_order = gen.room_order
	world_rect = gen.world_rect
	grid_bounds = gen.grid_bounds
	active_combat_room = ""
	_combat_resume_position = Vector2.INF
	descent_gate_active = false
	descent_gate_room = str(gen.get("boss_room_id", ""))
	descent_gate_pos = Vector2(rooms[descent_gate_room].center) + Vector2(0.0, -145.0) if rooms.has(descent_gate_room) else Vector2.ZERO
	return_portal_pos = Vector2(rooms["hub"].center)
	_telegraphs.clear()
	_reserve_groups.clear()
	_magnet_timers.clear()


func _rebuild_visual_layers() -> void:
	if is_instance_valid(_floor_root):
		_floor_root.queue_free()
	if is_instance_valid(_fog_layer):
		_fog_layer.queue_free()
	_fog_rects.clear()

	_floor_root = Node2D.new()
	_floor_root.name = "RiftDungeonFloor"
	_floor_root.z_index = -15
	_floor_root.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_floor_root)

	var abyss_bg := ColorRect.new()
	abyss_bg.position = world_rect.position - Vector2(600.0, 600.0)
	abyss_bg.size = world_rect.size + Vector2(1200.0, 1200.0)
	abyss_bg.color = Color(layout.get("bg", Color("0c0e17")))
	abyss_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floor_root.add_child(abyss_bg)

	_tile_canvas = _RiftFloorCanvas.new()
	_tile_canvas.name = "RiftModularTileCanvas"
	_tile_canvas.domain_node = self
	_tile_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://scripts/shaders/rift_tile_floor.gdshader"):
		var sh := load("res://scripts/shaders/rift_tile_floor.gdshader") as Shader
		if sh != null:
			var sm := ShaderMaterial.new()
			sm.shader = sh
			sm.set_shader_parameter("room_seed", float(run_seed % 997) + float(floor_index) * 17.0)
			sm.set_shader_parameter("biome_tint", Color(layout.get("tint", Color.WHITE)))
			sm.set_shader_parameter("mutator_tint", Color(0.0, 0.0, 0.0, 0.0))
			_tile_canvas.material = sm
	_floor_root.add_child(_tile_canvas)
	_tile_canvas.queue_redraw()

	# Fog of war overlay layer rendered above actors
	_fog_layer = Node2D.new()
	_fog_layer.name = "RiftFogLayer"
	_fog_layer.z_index = 25
	add_child(_fog_layer)
	var fog_shader: Shader = _load_tex("res://scripts/shaders/rift_fog.gdshader") if false else (load("res://scripts/shaders/rift_fog.gdshader") as Shader if ResourceLoader.exists("res://scripts/shaders/rift_fog.gdshader") else null)
	for rid: String in room_order:
		var rm: Dictionary = rooms[rid]
		var vr: Rect2 = rm.vis_rect
		var fog_box := ColorRect.new()
		fog_box.position = vr.position - Vector2(16.0, 16.0)
		fog_box.size = vr.size + Vector2(32.0, 32.0)
		fog_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fog_box.color = Color(1.0, 1.0, 1.0, 1.0)
		if fog_shader != null:
			var mat := ShaderMaterial.new()
			mat.shader = fog_shader
			mat.set_shader_parameter("fog_alpha", float(rm.fog_alpha))
			fog_box.material = mat
		else:
			fog_box.color = Color(0.04, 0.05, 0.10, float(rm.fog_alpha))
		fog_box.visible = float(rm.fog_alpha) > 0.01
		_fog_layer.add_child(fog_box)
		_fog_rects[rid] = fog_box


func _draw_modular_dungeon(canvas: Node2D) -> void:
	# 1. Draw modular 128x128 corridors underneath room walls
	if _tex_corridor_biome != null:
		for c: Dictionary in corridors:
			var vr: Rect2 = c.vis_rect
			var horiz := bool(c.horizontal)
			if horiz:
				var segs := maxi(1, int(ceil(vr.size.x / 128.0)))
				var sw := vr.size.x / float(segs)
				for si in range(segs):
					var dst := Rect2(Vector2(vr.position.x + float(si) * sw, vr.position.y), Vector2(sw + 1.0, vr.size.y))
					canvas.draw_texture_rect(_tex_corridor_biome, dst, false)
			else:
				var segs_v := maxi(1, int(ceil(vr.size.y / 128.0)))
				var sh := vr.size.y / float(segs_v)
				for si in range(segs_v):
					var seg_c := Vector2(vr.get_center().x, vr.position.y + (float(si) + 0.5) * sh)
					canvas.draw_set_transform(seg_c, PI * 0.5, Vector2.ONE)
					canvas.draw_texture_rect(_tex_corridor_biome, Rect2(Vector2(-sh * 0.5 - 0.5, -vr.size.x * 0.5), Vector2(sh + 1.0, vr.size.x)), false)
					canvas.draw_set_transform(Vector2.ZERO)

	var ts := ArenaRiftPCG.TILE_SIZE
	for rid: String in room_order:
		var rm: Dictionary = rooms[rid]
		var ir: Rect2 = rm.inner_rect
		var cols := int(rm.tile_cols)
		var rows := int(rm.tile_rows)
		var rseed := int(rm.room_seed)
		var doors: Array = rm.doors

		# 2. Draw floor tiles (64x64) with seeded variation hash
		if _tex_floor_tiles != null:
			var fw := float(_tex_floor_tiles.get_width()) / 4.0
			var fh := float(_tex_floor_tiles.get_height())
			for ty in range(rows):
				for tx in range(cols):
					var hval: int = absi((tx * 73856093) ^ (ty * 19349663) ^ rseed) % 20
					var tid := 0
					if hval >= 11 and hval <= 14:
						tid = 1
					elif hval >= 15 and hval <= 17:
						tid = 2
					elif hval >= 18:
						tid = 3
					var pos := ir.position + Vector2(float(tx) * ts, float(ty) * ts)
					canvas.draw_texture_rect_region(
						_tex_floor_tiles,
						Rect2(pos, Vector2(ts, ts)),
						Rect2(Vector2(float(tid) * fw, 0.0), Vector2(fw, fh))
					)

		# Subtle center emblem or mutator rim inside room
		var rcenter := Vector2(rm.center)
		var rkind := str(rm.kind)
		var mut_cfg: Dictionary = ArenaRiftPCG.MUTATORS.get(str(rm.mutator), ArenaRiftPCG.MUTATORS["none"])
		var mut_col: Color = Color(mut_cfg.get("color", Color(0, 0, 0, 0)))
		if rkind == "hub":
			canvas.draw_arc(rcenter, 96.0, 0.0, TAU, 40, Color("6ceeff", 0.36), 3.0)
			canvas.draw_arc(rcenter, 66.0, 0.0, TAU, 32, Color("ffe678", 0.32), 2.0)
		elif rkind == "boss":
			canvas.draw_arc(rcenter, 132.0, 0.0, TAU, 48, Color("ff5c72", 0.42), 3.5)
			canvas.draw_arc(rcenter, 94.0, 0.0, TAU, 36, Color("ffe678", 0.36), 2.2)
		elif rkind == "miniboss":
			canvas.draw_arc(rcenter, 108.0, 0.0, TAU, 40, Color("ff9e58", 0.36), 3.0)
		elif mut_col.a > 0.05:
			canvas.draw_rect(ir.grow(-6.0), Color(mut_col.r, mut_col.g, mut_col.b, 0.22), false, 3.0)

		# Speed rune pads & hazard bases on floor
		for sp: Vector2 in rm.speed_pads:
			canvas.draw_circle(sp, 28.0, Color(0.20, 0.78, 0.92, 0.26))
			canvas.draw_arc(sp, 28.0, 0.0, TAU, 24, Color("7ef4ff", 0.72), 2.2)
			canvas.draw_polyline(PackedVector2Array([sp + Vector2(-10, 4), sp + Vector2(0, -8), sp + Vector2(10, 4)]), Color("e2ffff", 0.85), 2.6, false)

		for hz: Dictionary in rm.hazards:
			var hp := Vector2(hz.pos)
			var hrad := float(hz.radius)
			canvas.draw_circle(hp, hrad * 0.88, Color(0.32, 0.14, 0.48, 0.22))
			canvas.draw_arc(hp, hrad * 0.88, 0.0, TAU, 24, Color("b474ff", 0.45), 2.0)

		# 3. Auto-tiled perimeter walls: ONLY open a 2-tile doorway on sides listed in rm.doors!
		if _tex_wall_tiles != null:
			var ww := float(_tex_wall_tiles.get_width()) / 4.0
			var wh := float(_tex_wall_tiles.get_height())
			var mid_x0 := cols / 2 - 1
			var mid_x1 := cols / 2
			var mid_y0 := rows / 2 - 1
			var mid_y1 := rows / 2

			# Corners (always sconce tile 3)
			for corner_pos: Vector2 in [
				ir.position + Vector2(-ts, -ts),
				Vector2(ir.end.x, ir.position.y - ts),
				Vector2(ir.position.x - ts, ir.end.y),
				ir.end
			]:
				canvas.draw_texture_rect_region(_tex_wall_tiles, Rect2(corner_pos, Vector2(ts, ts)), Rect2(Vector2(3.0 * ww, 0.0), Vector2(ww, wh)))

			# North & South walls
			for tx in range(cols):
				var is_door_x := tx == mid_x0 or tx == mid_x1
				var n_pos := ir.position + Vector2(float(tx) * ts, -ts)
				if not ("N" in doors and is_door_x):
					var tid_n := 2 if ("N" in doors and (tx == mid_x0 - 1 or tx == mid_x1 + 1)) else 0
					canvas.draw_texture_rect_region(_tex_wall_tiles, Rect2(n_pos, Vector2(ts, ts)), Rect2(Vector2(float(tid_n) * ww, 0.0), Vector2(ww, wh)))

				var s_pos := Vector2(ir.position.x + float(tx) * ts, ir.end.y)
				if not ("S" in doors and is_door_x):
					var tid_s := 2 if ("S" in doors and (tx == mid_x0 - 1 or tx == mid_x1 + 1)) else 1
					canvas.draw_texture_rect_region(_tex_wall_tiles, Rect2(s_pos, Vector2(ts, ts)), Rect2(Vector2(float(tid_s) * ww, 0.0), Vector2(ww, wh)))

			# West & East walls
			for ty in range(rows):
				var is_door_y := ty == mid_y0 or ty == mid_y1
				var w_pos := ir.position + Vector2(-ts, float(ty) * ts)
				if not ("W" in doors and is_door_y):
					var tid_w := 2 if ("W" in doors and (ty == mid_y0 - 1 or ty == mid_y1 + 1)) else 1
					canvas.draw_texture_rect_region(_tex_wall_tiles, Rect2(w_pos, Vector2(ts, ts)), Rect2(Vector2(float(tid_w) * ww, 0.0), Vector2(ww, wh)))

				var e_pos := Vector2(ir.end.x, ir.position.y + float(ty) * ts)
				if not ("E" in doors and is_door_y):
					var tid_e := 2 if ("E" in doors and (ty == mid_y0 - 1 or ty == mid_y1 + 1)) else 1
					canvas.draw_texture_rect_region(_tex_wall_tiles, Rect2(e_pos, Vector2(ts, ts)), Rect2(Vector2(float(tid_e) * ww, 0.0), Vector2(ww, wh)))


func rift_world_rect() -> Rect2:
	return world_rect


func total_explore_rooms() -> int:
	return maxi(1, room_order.size() - 1)


func cleared_count() -> int:
	var n := 0
	for rid: String in room_order:
		if rid != "hub" and str(rooms[rid].state) == "cleared":
			n += 1
	return n


func current_room_id(world_pt: Vector2) -> String:
	for rid: String in room_order:
		if Rect2(rooms[rid].inner_rect).has_point(world_pt):
			return rid
	var best_id := "hub"
	var best_d := INF
	for rid: String in room_order:
		var d := world_pt.distance_squared_to(Vector2(rooms[rid].center))
		if d < best_d:
			best_d = d
			best_id = rid
	return best_id


func current_mutator_label(world_pt: Vector2) -> String:
	var rid := current_room_id(world_pt)
	if not rooms.has(rid):
		return ""
	var m_id := str(rooms[rid].get("mutator", "none"))
	var cfg: Dictionary = ArenaRiftPCG.MUTATORS.get(m_id, {})
	return str(cfg.get("name", ""))


func rift_explore_haste() -> float:
	if game == null or game.active_domain != "rift":
		return 0.0
	var pad_bonus := 0.28 if hero_speed_pad_clock > 0.0 else 0.0
	if not active_combat_room.is_empty():
		return pad_bonus
	if not is_instance_valid(game.hero):
		return pad_bonus
	var rid := current_room_id(game.hero.position)
	var travel: float = game.passive_engine.rift_travel_bonus()
	if rooms.has(rid) and str(rooms[rid].state) == "cleared":
		return 0.45 + pad_bonus + travel
	for corridor: Dictionary in corridors:
		if Rect2(corridor.rect).has_point(game.hero.position) and _is_corridor_passable(corridor):
			return pad_bonus + travel
	return pad_bonus


func _is_corridor_passable(c: Dictionary) -> bool:
	if not active_combat_room.is_empty():
		return false
	var st_a := str(rooms[c.a].state)
	var st_b := str(rooms[c.b].state)
	return st_a != "hidden" and st_b != "hidden" and (st_a == "cleared" or st_b == "cleared")


func is_walkable_in_rift(world_pt: Vector2) -> bool:
	var in_walk := false
	if not active_combat_room.is_empty() and rooms.has(active_combat_room):
		in_walk = Rect2(rooms[active_combat_room].inner_rect).has_point(world_pt)
	else:
		for rid: String in room_order:
			var rm: Dictionary = rooms[rid]
			if str(rm.state) != "hidden" and Rect2(rm.inner_rect).has_point(world_pt):
				in_walk = true
				break
		if not in_walk:
			for c: Dictionary in corridors:
				if _is_corridor_passable(c) and Rect2(c.rect).has_point(world_pt):
					in_walk = true
					break
	if not in_walk:
		return false
	var cur_r := current_room_id(world_pt)
	if rooms.has(cur_r):
		for ob: Rect2 in rooms[cur_r].obstacles:
			if ob.grow(10.0).has_point(world_pt):
				return false
	return true


func _push_out_of_obstacles(world_pt: Vector2, rid: String, pad := 14.0) -> Vector2:
	if not rooms.has(rid):
		return world_pt
	var pt := world_pt
	for ob: Rect2 in rooms[rid].obstacles:
		var box := ob.grow(pad)
		if box.has_point(pt):
			var dx_l := absf(pt.x - box.position.x)
			var dx_r := absf(box.end.x - pt.x)
			var dy_t := absf(pt.y - box.position.y)
			var dy_b := absf(box.end.y - pt.y)
			var m := minf(minf(dx_l, dx_r), minf(dy_t, dy_b))
			if m == dx_l:
				pt.x = box.position.x
			elif m == dx_r:
				pt.x = box.end.x
			elif m == dy_t:
				pt.y = box.position.y
			else:
				pt.y = box.end.y
	return pt


func _cover_contact(from: Vector2, to: Vector2, rect: Rect2) -> Vector2:
	if rect.has_point(from):
		return from
	var nearest := Vector2.INF
	var length := INF
	var corners := [rect.position, Vector2(rect.end.x,rect.position.y), rect.end, Vector2(rect.position.x,rect.end.y)]
	for side in range(4):
		var hit: Variant = Geometry2D.segment_intersects_segment(from,to,corners[side],corners[(side+1)%4])
		if hit is Vector2:
			var distance := from.distance_squared_to(hit)
			if distance < length:
				nearest = hit
				length = distance
	return nearest


func projectile_cover(from: Vector2, to: Vector2) -> Vector2:
	if not rooms.has(active_combat_room):
		return Vector2.INF
	var closest := Vector2.INF
	var distance := INF
	for obstacle: Rect2 in rooms[active_combat_room].obstacles:
		var point := _cover_contact(from,to,obstacle)
		if point.is_finite() and from.distance_squared_to(point) < distance:
			closest = point
			distance = from.distance_squared_to(point)
	return closest


func rift_mob_waypoint(from: Vector2, to: Vector2, rid: String) -> Vector2:
	if not rooms.has(rid):
		return to
	var room: Dictionary = rooms[rid]
	var blocker := Rect2()
	var closest := INF
	for obstacle: Rect2 in room.obstacles:
		var hit := _cover_contact(from,to,obstacle.grow(12.0))
		if hit.is_finite() and from.distance_squared_to(hit) < closest:
			closest = from.distance_squared_to(hit)
			blocker = obstacle
	if not blocker.has_area():
		return to
	var outer := blocker.grow(27.0)
	var best := to
	var cost := INF
	for corner: Vector2 in [outer.position,Vector2(outer.end.x,outer.position.y),outer.end,Vector2(outer.position.x,outer.end.y)]:
		if not Rect2(room.inner_rect).grow(-14.0).has_point(corner) or from.distance_squared_to(corner) < 90.0:
			continue
		var blocked := false
		for obstacle: Rect2 in room.obstacles:
			if _cover_contact(from,corner,obstacle.grow(10.0)).is_finite():
				blocked = true
				break
		if blocked:
			continue
		var length := from.distance_to(corner)+corner.distance_to(to)
		if length < cost:
			cost = length
			best = corner
	return best


func navigation_path(from: Vector2, target: Vector2) -> PackedVector2Array:
	var destination := clamp_rift_position(target)
	var rid := active_combat_room if not active_combat_room.is_empty() else current_room_id(from)
	var route := PackedVector2Array()
	var point := from
	for _turn in 8:
		var next := rift_mob_waypoint(point,destination,rid)
		if next in route or point.distance_squared_to(next) < 1.0:
			break
		route.append(next)
		if next == destination:
			break
		point = next
	return route


func clamp_rift_position(world_pt: Vector2) -> Vector2:
	var best_pt := world_pt
	if not active_combat_room.is_empty() and rooms.has(active_combat_room):
		var ir: Rect2 = rooms[active_combat_room].inner_rect
		best_pt = world_pt.clamp(ir.position + Vector2(12, 12), ir.end - Vector2(12, 12))
		return _push_out_of_obstacles(best_pt, active_combat_room, 12.0)

	if is_walkable_in_rift(world_pt):
		return world_pt

	best_pt = Vector2(rooms["hub"].center)
	var best_d := INF
	for rid: String in room_order:
		var rm: Dictionary = rooms[rid]
		if str(rm.state) == "hidden":
			continue
		var ir: Rect2 = rm.inner_rect
		var cand := world_pt.clamp(ir.position + Vector2(12, 12), ir.end - Vector2(12, 12))
		cand = _push_out_of_obstacles(cand, rid, 12.0)
		var d := world_pt.distance_squared_to(cand)
		if d < best_d:
			best_d = d
			best_pt = cand
	for c: Dictionary in corridors:
		if not _is_corridor_passable(c):
			continue
		var cr: Rect2 = c.rect
		var cand_c := world_pt.clamp(cr.position + Vector2(10, 10), cr.end - Vector2(10, 10))
		var dc := world_pt.distance_squared_to(cand_c)
		if dc < best_d:
			best_d = dc
			best_pt = cand_c
	return best_pt


func clamp_mob_to_room(world_pt: Vector2, room_id: String) -> Vector2:
	if rooms.has(room_id):
		var ir: Rect2 = rooms[room_id].inner_rect
		var pt := world_pt.clamp(ir.position + Vector2(16, 16), ir.end - Vector2(16, 16))
		return _push_out_of_obstacles(pt, room_id, 14.0)
	return clamp_rift_position(world_pt)


func can_enter_rift() -> bool:
	if game == null or not game.running or game.game_over or game.feel_lab or game.tower_lab:
		return false
	if game.active_domain == "rift" or portal_cooldown > 0.0 or warp_phase != "":
		return false
	return not game.get_tree().paused and is_instance_valid(game.hero) and not game.hero.knocked_out


func enter_rift(instant := false) -> bool:
	if not can_enter_rift():
		return false
	if instant or Engine.time_scale > 2.0:
		_relocate_to_rift()
	else:
		_start_warp("rift", game.hero.position, 1.0, 1.18)
	return true

func recall_to_defense(instant := false) -> bool:
	if game == null or not game.running or game.game_over or game.active_domain != "rift" or not warp_phase.is_empty():
		return false
	if not is_instance_valid(game.hero) or game.get_tree().paused:
		return false
	if instant or Engine.time_scale > 2.0:
		_relocate_to_defense()
	else:
		_start_warp("defense", game.hero.position, 1.2, 0.96)
	return true

func can_descend_now() -> bool:
	if not descent_gate_active or game == null or not game.running or game.game_over or game.active_domain != "rift":
		return false
	if not active_combat_room.is_empty() or not warp_phase.is_empty() or game.get_tree().paused:
		return false
	var hero: ArenaHero = game.hero
	return is_instance_valid(hero) and not hero.knocked_out and hero.position.distance_to(descent_gate_pos) <= 78.0

func descend_next_floor(instant := false) -> bool:
	if not can_descend_now():
		return false
	if instant or Engine.time_scale > 2.0:
		_perform_floor_descent()
	else:
		_start_warp("descend", descent_gate_pos, 1.0, 1.32)
	return true

func _clear_portal_orders(hero: ArenaHero) -> void:
	hero.cancel_action()
	hero.path.clear()
	hero.velocity = Vector2.ZERO
	hero.queued_attack_point = Vector2.INF
	game.targeting_slot = -1
	game.rally_site = -1
	game.mouse_shoot_held = false
	game.suppress_primary = Input.is_action_pressed("shoot")
	if is_instance_valid(game.hud):
		game.hud.close_context()

func _start_warp(destination: String, effect_position: Vector2, protection: float, pitch: float) -> void:
	var hero: ArenaHero = game.hero
	_clear_portal_orders(hero)
	hero.protection = maxf(hero.protection, protection)
	warp_phase = "out"
	warp_target = destination
	warp_clock = 0.22
	_spawn_portal_fx(effect_position, true)
	game.audio.play("phase", -7.0 if destination == "descend" else -8.0, pitch)

func _relocate_party(hero: ArenaHero, destination: String, landing: Vector2, protection: float) -> void:
	_clear_portal_orders(hero)
	game.blocking.release(hero)
	hero.domain = destination
	hero.position = landing
	hero.protection = maxf(hero.protection, protection)
	for beast in hero.companions:
		if is_instance_valid(beast):
			game.blocking.release(beast)
			beast.path.clear()
			beast.position = landing + Vector2(-28.0 if beast.slot == 0 else 28.0, 10.0)
	game.active_domain = destination

func _perform_floor_descent() -> void:
	game.clear_rift_attacks()
	# Clean leftover Rift enemies & pickups from current floor
	for e in game.domain_enemies("rift"):
		if is_instance_valid(e):
			game.remove_enemy(e)
	var kept_pickups: Array = []
	for p in game.pickups:
		if is_instance_valid(p) and str(p.domain) == "rift":
			p.queue_free()
		elif is_instance_valid(p):
			kept_pickups.append(p)
	game.pickups = kept_pickups

	floors_cleared += 1
	floor_index += 1
	_build_topology()
	_rebuild_visual_layers()

	var hero: ArenaHero = game.hero
	if is_instance_valid(hero):
		_relocate_party(hero, "rift", Vector2(rooms["hub"].center), 1.0)
		hero._heal_self(hero.max_health * 0.25, true)
	game.camera.sync_domain()
	_spawn_portal_fx(Vector2(rooms["hub"].center), false)
	game.numbers.append({
		"point": hero.center() + Vector2(0.0, -44.0) if is_instance_valid(hero) else Vector2.ZERO,
		"text": "★ 跃迁至第%d层深渊地牢!" % floor_index,
		"colour": Color("ffe678"),
		"life": 1.35,
		"duration": 1.35,
		"critical": true
	})
	game.audio.play("phase", -7.0, 1.35)


func _relocate_to_rift() -> void:
	var hero: ArenaHero = game.hero
	if not is_instance_valid(hero):
		return
	var departure := hero.position
	var landing := Vector2(rooms["hub"].center)
	if rooms.has(active_combat_room) and _combat_resume_position.is_finite():
		landing = _combat_resume_position
	_combat_resume_position = Vector2.INF
	_relocate_party(hero, "rift", landing, 0.85)
	game.event_bus.emit_event("domain_enter", {"departure": departure})
	rift_dwell_time = 0.0
	game.camera.sync_domain()
	_spawn_portal_fx(hero.position, false)
	game.effect(hero.position, 68.0, Color("7ef0ff"), "void_warp", 0.36)
	game.audio.play("phase", -8.0, 1.24)


func _relocate_to_defense() -> void:
	var hero: ArenaHero = game.hero
	if not is_instance_valid(hero):
		return
	if rooms.has(active_combat_room):
		_combat_resume_position = hero.position
	game.clear_rift_attacks()
	var landing := _pick_recall_landing()
	_relocate_party(hero, "defense", landing, 1.50)
	hero.war_cry = maxf(hero.war_cry, 2.5)
	portal_cooldown = PORTAL_COOLDOWN
	core_hit_alert = 0.0
	game.camera.sync_domain()
	_spawn_portal_fx(landing, false)

	# Heroic Recall Landing Shockwave
	var shock_dmg: float = hero.attack_damage() * 2.0
	game.area_damage(landing, 175.0, shock_dmg, 1, "hero", 0.55, 1.6, 0.25, 42.0, "recall_shock", true, {"domain": "defense"})
	game.effect(landing, 150.0, Color("7cf2ff"), "slam", 0.45)
	game.numbers.append({
		"point": hero.center() + Vector2(0, -34),
		"text": "降临救场!",
		"colour": Color("7ef4ff"),
		"life": 0.85,
		"duration": 0.85,
		"critical": true
	})
	game.audio.play("heavy_hit", -7.0, 1.12)
	game.audio.play("phase", -9.0, 0.94)
	if game.event_bus != null:
		game.event_bus.emit_event("domain_recall", {"landing": landing})


func _spawn_portal_fx(world_pt: Vector2, opening: bool) -> void:
	_portal_fx.append({
		"pos": world_pt,
		"life": 0.62,
		"duration": 0.62,
		"opening": opening
	})


func _pick_recall_landing() -> Vector2:
	var spawn := Vector2(game.level_definition.get("hero_spawn", Vector2(1360, 500)))
	var worst_enemy: Node2D = null
	var worst_ratio := 0.62
	for e in game.domain_enemies("defense"):
		if not is_instance_valid(e) or e.dead or e.is_guard:
			continue
		var road: Curve2D = game.enemy_road(e)
		if road == null:
			continue
		var r := float(e.progress) / maxf(1.0, road.get_baked_length())
		if r > worst_ratio:
			worst_ratio = r
			worst_enemy = e
	if is_instance_valid(worst_enemy):
		var cand: Vector2 = worst_enemy.position.lerp(spawn, 0.22)
		if game.walkable(cand):
			return cand
	return spawn


func note_core_hit() -> void:
	core_hit_alert = 3.8


func tick(delta: float) -> void:
	if game == null or not game.running or game.game_over or game.feel_lab or game.tower_lab:
		return
	portal_cooldown = maxf(0.0, portal_cooldown - delta)
	transition_flash = maxf(0.0, transition_flash - delta)
	core_hit_alert = maxf(0.0, core_hit_alert - delta)
	hero_speed_pad_clock = maxf(0.0, hero_speed_pad_clock - delta)
	_event_prompt_cd = maxf(0.0, _event_prompt_cd - delta)

	_tick_portal_warp(delta)
	_tick_portal_fx(delta)
	_update_defense_radar(delta)

	if game.active_domain == "rift":
		rift_dwell_time += delta
		total_rift_time += delta
		_tick_rooms_and_waves(delta)
		_tick_hazards_and_pads(delta)
		_tick_magnet_timers(delta)
		_tick_fog_fade(delta)
	queue_redraw()


func _tick_portal_warp(delta: float) -> void:
	if warp_phase.is_empty():
		iris_progress = move_toward(iris_progress, 0.0, delta * 5.0)
		return
	warp_clock -= delta
	if warp_phase == "out":
		iris_progress = clampf(1.0 - warp_clock / 0.22, 0.0, 1.0)
		if warp_clock <= 0.0:
			iris_progress = 1.0
			if warp_target == "rift":
				_relocate_to_rift()
			elif warp_target == "descend":
				_perform_floor_descent()
			else:
				_relocate_to_defense()
			warp_phase = "in"
			warp_clock = 0.20
	elif warp_phase == "in":
		iris_progress = clampf(warp_clock / 0.20, 0.0, 1.0)
		if warp_clock <= 0.0:
			iris_progress = 0.0
			warp_phase = ""
			warp_target = ""


func _tick_portal_fx(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for fx in _portal_fx:
		fx.life = float(fx.life) - delta
		if float(fx.life) > 0.0:
			kept.append(fx)
	_portal_fx = kept


func _tick_fog_fade(delta: float) -> void:
	for rid: String in room_order:
		var rm: Dictionary = rooms[rid]
		var st := str(rm.state)
		var target_a := 0.96 if st == "hidden" else (0.46 if st == "discovered" else 0.0)
		var cur_a := float(rm.fog_alpha)
		if not is_equal_approx(cur_a, target_a):
			var next_a := move_toward(cur_a, target_a, delta * 2.2)
			rm.fog_alpha = next_a
			var rect: ColorRect = _fog_rects.get(rid)
			if is_instance_valid(rect):
				rect.visible = next_a > 0.01
				if rect.material is ShaderMaterial:
					(rect.material as ShaderMaterial).set_shader_parameter("fog_alpha", next_a)
				else:
					rect.color.a = next_a


func _tick_magnet_timers(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for m in _magnet_timers:
		m.delay = float(m.delay) - delta
		if float(m.delay) <= 0.0:
			var r_rect: Rect2 = m.rect
			for p in game.pickups:
				if is_instance_valid(p) and p.domain == "rift" and r_rect.has_point(p.position):
					p.magnetized = true
		else:
			kept.append(m)
	_magnet_timers = kept


func _tick_hazards_and_pads(delta: float) -> void:
	var hero: ArenaHero = game.hero
	if not is_instance_valid(hero) or hero.knocked_out:
		return
	var cur_rid := current_room_id(hero.position)
	if not rooms.has(cur_rid):
		return
	var rm: Dictionary = rooms[cur_rid]
	for sp: Vector2 in rm.speed_pads:
		if hero.position.distance_to(sp) <= 34.0:
			if hero_speed_pad_clock <= 0.1:
				game.effect(sp, 38.0, Color("7ef4ff"), "upgrade", 0.30)
			hero_speed_pad_clock = 3.0

	if str(rm.state) == "locked_combat":
		for hz: Dictionary in rm.hazards:
			hz.clock = float(hz.clock) + delta
			var cyc := float(hz.cycle)
			var c_val := float(hz.clock)
			if not bool(hz.armed) and c_val >= cyc - 1.15:
				hz.armed = true
			if c_val >= cyc:
				hz.clock = 0.0
				hz.armed = false
				var hpos := Vector2(hz.pos)
				var hrad := float(hz.radius)
				var damage: float = (68.0+float(floor_index-1)*28.0)*game.passive_engine.hazard_damage_multiplier()
				game.area_damage(hpos, hrad, damage, 1, "hero", 0.35, 1.5, 0.2, 0.0, "hazard_blast", true, {"domain": "rift", "passive_proc": true})
				if hero.position.distance_to(hpos) <= hrad and hero.protection <= 0.0:
					var danger := 15.0 if game.passive_engine.is_evo("hazardcraft") else 20.0
					hero.take_hit(danger, 1, false, (hero.position - hpos).normalized(),false)
				game.effect(hpos, hrad, Color("c474ff"), "blast", 0.32)
				game.audio.play("explode", -14.0, 1.18)


func damage_barrels_in_radius(world_pt: Vector2, radius: float, dmg: float, dom: String) -> int:
	if dom != "rift" or dmg <= 0.0:
		return 0
	var check_rid := active_combat_room if not active_combat_room.is_empty() else (current_room_id(game.hero.position) if is_instance_valid(game.hero) else "")
	if check_rid.is_empty() or not rooms.has(check_rid):
		return 0
	var rm: Dictionary = rooms[check_rid]
	var hit_cnt := 0
	var to_detonate: Array[Dictionary] = []
	for br: Dictionary in rm.barrels:
		if not bool(br.alive):
			continue
		if Vector2(br.pos).distance_to(world_pt) <= radius + 24.0:
			br.hp = float(br.hp) - dmg
			hit_cnt += 1
			if float(br.hp) <= 0.0:
				br.alive = false
				to_detonate.append(br)
	for br in to_detonate:
		_detonate_barrel(br, check_rid)
	return hit_cnt


func _detonate_barrel(barrel: Dictionary, rid: String) -> void:
	var pos := Vector2(barrel.pos)
	var r_mult: float = float(game.relic_engine.barrel_damage_mult()) if (game != null and game.relic_engine != null) else 1.0
	var blast_dmg: float = (180.0 + float(floor_index - 1) * 55.0) * r_mult
	var radius: float = 160.0 * game.passive_engine.barrel_range_multiplier()
	game.area_damage(pos, radius, blast_dmg, 1, "hero", 0.60, 0.0, 0.30, 0.0, "crystal_barrel", true, {"domain": "rift", "passive_proc": true})
	game.effect(pos, radius*0.925, Color("6cf4ff"), "blast", 0.42)
	game.effect(pos, 118.0, Color("d474ff"), "void_warp", 0.36)
	game.numbers.append({
		"point": pos + Vector2(0.0, -30.0),
		"text": "★ 晶桶爆裂 %d!" % int(round(blast_dmg)),
		"colour": Color("7ef4ff"),
		"life": 0.95,
		"duration": 0.95,
		"critical": true
	})
	game.audio.play("explode", -8.0, 1.05)
	if game.feel != null and game.feel.enabled and Engine.time_scale <= 2.0:
		game.feel.trauma = minf(1.0, game.feel.trauma + 0.24)
	# Chain-detonate nearby intact crystal barrels in same room
	if rooms.has(rid):
		var rm: Dictionary = rooms[rid]
		var chained: Array[Dictionary] = []
		for other: Dictionary in rm.barrels:
			if bool(other.alive) and Vector2(other.pos).distance_to(pos) <= 165.0:
				other.alive = false
				chained.append(other)
		for ob in chained:
			_detonate_barrel(ob, rid)


func _tick_rooms_and_waves(delta: float) -> void:
	# Resolve spawn telegraphs
	var done: Array[Dictionary] = []
	for tel in _telegraphs:
		tel.life = float(tel.life) - delta
		if float(tel.life) <= 0.0:
			_spawn_room_mob(str(tel.room_id), str(tel.kind), Vector2(tel.pos), bool(tel.bounty), bool(tel.elite))
			done.append(tel)
	for d in done:
		_telegraphs.erase(d)

	var hero: ArenaHero = game.hero
	if not is_instance_valid(hero) or hero.knocked_out:
		return

	# Trigger discovered combat/chest/miniboss/boss room on entry, or instant reveal for peaceful event room
	if active_combat_room.is_empty():
		for rid: String in room_order:
			var rm: Dictionary = rooms[rid]
			if str(rm.state) == "discovered" and Rect2(rm.trigger_rect).has_point(hero.position):
				if str(rm.kind) == "event" and int(rm.total_waves) == 0:
					_clear_room(rid)
				else:
					_start_room_combat(rid)
				break

	# Active combat room wave progression
	if not active_combat_room.is_empty() and rooms.has(active_combat_room):
		var cur: Dictionary = rooms[active_combat_room]
		var alive := _room_alive_count(active_combat_room)
		var pending_tel := _room_telegraph_count(active_combat_room)
		if not _reserve_groups.is_empty():
			_reserve_clock = maxf(0.0,_reserve_clock-delta)
			var group := _reserve_groups[0]
			var limit := 20 if cur.mutator == "swarm_tide" else 14
			if bool(group.after_clear):limit = group.units.size()
			if pending_tel == 0 and alive+group.units.size() <= limit and (_reserve_clock <= 0.0 or alive == 0):
				_send_next_group(active_combat_room)
		elif alive == 0 and pending_tel == 0:
			if int(cur.wave_idx) < int(cur.total_waves):
				if float(cur.wave_pause_clock) <= 0.0:
					cur.wave_pause_clock = 0.65
				else:
					cur.wave_pause_clock = float(cur.wave_pause_clock) - delta
					if float(cur.wave_pause_clock) <= 0.0:
						cur.wave_idx = int(cur.wave_idx) + 1
						_spawn_room_wave(active_combat_room, int(cur.wave_idx))
			else:
				_clear_room(active_combat_room)

	# Reward chests, Event Shrines, and Deep Descent Gate proximity
	for rid: String in room_order:
		var rm: Dictionary = rooms[rid]
		if bool(rm.reward_active) and not bool(rm.reward_claimed):
			if hero.position.distance_to(Vector2(rm.reward_pos)) <= 62.0:
				_claim_room_reward(rid)
		if str(rm.kind) == "event" and str(rm.state) == "cleared" and not bool(rm.event_used) and _event_prompt_cd <= 0.0:
			if hero.position.distance_to(Vector2(rm.event_pos)) <= 64.0 and game.active_event_offer.is_empty() and (not is_instance_valid(game.hud) or not game.hud.has_modal()):
				_event_prompt_cd = 1.6
				game.open_rift_event(rid)



func _room_alive_count(rid: String) -> int:
	var n := 0
	for e in game.domain_enemies("rift"):
		if is_instance_valid(e) and not e.dead and str(e.get("rift_room_id")) == rid:
			n += 1
	return n


func _room_telegraph_count(rid: String) -> int:
	var n := 0
	for t in _telegraphs:
		if str(t.room_id) == rid:
			n += 1
	return n


func _start_room_combat(rid: String) -> void:
	var rm: Dictionary = rooms[rid]
	if int(rm.total_waves) <= 0:
		rm.state = "cleared"
		return
	active_combat_room = rid
	rm.state = "locked_combat"
	rm.wave_idx = 1
	rm.wave_pause_clock = 0.0
	var approach: Vector2 = Vector2(rm.center) - game.hero.position
	_room_front = Vector2(signf(approach.x),0.0) if absf(approach.x) > absf(approach.y) else Vector2(0.0,signf(approach.y))
	if _room_front.is_zero_approx():_room_front = Vector2.UP
	_room_flank_sign = -1.0 if floor_rng.randf() < 0.5 else 1.0
	_spawn_room_wave(rid, 1)
	if is_instance_valid(game.hero):
		var mut_tag := ""
		var m_cfg: Dictionary = ArenaRiftPCG.MUTATORS.get(str(rm.mutator), {})
		if str(m_cfg.get("name", "")) != "":
			mut_tag = " [" + str(m_cfg.name) + "]"
		game.numbers.append({
			"point": Vector2(rm.center) + Vector2(0.0, -148.0),
			"text": "%s%s" % [str(rm.title), mut_tag],
			"colour": Color("ff6c7a") if str(rm.kind) in ["boss", "miniboss"] else Color("ff9e68"),
			"life": 1.25,
			"duration": 1.25,
			"critical": true
		})
	game.audio.play("phase", -9.0, 0.92)


func _spawn_room_wave(rid: String, wave_num: int) -> void:
	var room: Dictionary = rooms[rid]
	var kind: String = room.kind
	var mutator: Dictionary = ArenaRiftPCG.MUTATORS[room.mutator]
	var roster: Array[Dictionary] = []
	var count: int
	var elites: int
	if kind == "boss":
		count = 18 if floor_index == 1 else 22
		elites = 2
	elif kind == "miniboss":
		count = 14 + (floor_index-1)*3
		elites = 1
	else:
		var base := 16 if kind == "chest" else ((15 if wave_num == 1 else 17) if kind == "combat" else (16 if wave_num == 1 else 19))
		base += mini(4,(floor_index-1)*2)
		count = clampi(roundi(base*float(mutator.count_mult)),12,26)
		elites = (1 if kind == "chest" or wave_num >= 2 else 0) + int(mutator.elite_bonus)
		if kind == "elite":
			elites = maxi(2,elites+1)

	var formation: Array = FORMATIONS[theme_key]
	for index in count:
		var elite := index < elites
		var pool: Array = layout.elites if elite and kind in ["combat","elite","chest"] else layout.mobs
		var mob: String = pool[floor_rng.randi_range(0,pool.size()-1)]
		if not elite and (index == elites or index == elites+2):
			mob = formation[0]
		elif not elite and index >= 8 and index % 3 == 1:
			mob = formation[1]
		if not elite and index == maxi(5,elites+1):
			mob = formation[2]
		elif mob == formation[2]:
			mob = formation[1]
		var bounty: bool = (elite and kind in ["chest","elite"]) or (room.mutator == "gold_rush" and index % 4 == 0)
		roster.append({"kind": mob, "bounty": bounty, "elite": elite})

	if kind == "boss":
		var leader: String = layout.boss if wave_num == 1 else layout.alt_boss
		roster.insert(0,{"kind": leader, "bounty": true, "elite": true})
		if wave_num == 2:
			game.numbers.append({
				"point": Vector2(room.center)+Vector2(0,-120), "text": "第二战 · "+str(ArenaDefinitions.enemy(leader).name),
				"colour": Color("ffad88"), "life": 1.2, "duration": 1.2, "critical": true
			})
	elif kind == "miniboss" and wave_num == 2:
		roster.insert(0,{"kind": layout.miniboss, "bounty": true, "elite": true})

	var group_size := 11 if room.mutator == "swarm_tide" else 8
	var bands: Array = []
	for offset in range(0,roster.size(),group_size):
		bands.append({"units": roster.slice(offset,offset+group_size), "after_clear": false})
	# Deeper floors keep the original third leader. Its entrance follows the second boss.
	if kind == "boss" and wave_num == 2:
		bands.append({"units": [{"kind": layout.miniboss, "bounty": true, "elite": true}], "after_clear": true})
	_reserve_groups.assign(bands)
	_room_group_idx = 0
	_send_next_group(rid)


func _send_next_group(rid: String) -> void:
	var room: Dictionary = rooms[rid]
	var group: Dictionary = _reserve_groups.pop_front()
	var units: Array = group.units
	var center: Vector2 = room.center
	var size: Vector2 = Rect2(room.inner_rect).size
	var direction := _room_front
	var flank := _room_front.orthogonal() * _room_flank_sign
	if _room_group_idx % 3 == 1:direction = flank
	elif _room_group_idx % 3 == 2:direction = -flank
	var tangent := direction.orthogonal()
	var base := center + direction * (size*direction.abs()).length()*0.35
	var span := (size*tangent.abs()).length()*0.58
	for index in units.size():
		var unit: Dictionary = units[index]
		var ratio := float(index+1)/float(units.size()+1)-0.5
		var point := base + tangent * (span*ratio)
		var stagger := float(index % 3)*0.09
		_queue_room_telegraph(rid,unit.kind,point,0.70+stagger,unit.bounty,unit.elite)
	_room_group_idx += 1
	_reserve_clock = 1.65


func _queue_room_telegraph(rid: String, mob_kind: String, world_pos: Vector2, delay: float, bounty: bool, is_el: bool) -> void:
	_telegraphs.append({
		"room_id": rid,
		"kind": mob_kind,
		"pos": clamp_mob_to_room(world_pos, rid),
		"life": delay,
		"duration": maxf(0.1, delay),
		"bounty": bounty,
		"elite": is_el
	})


func _spawn_room_mob(rid: String, kind: String, world_pos: Vector2, bounty: bool, is_el: bool) -> Node2D:
	var mob := ArenaEnemy.new()
	mob.game = game
	mob.kind = kind
	mob.domain = "rift"
	mob.is_rift_mob = true
	mob.is_bounty_elite = bounty
	mob.elite = is_el or bounty
	mob.rift_room_id = rid
	mob.position = clamp_mob_to_room(world_pos, rid)
	game.register_enemy(mob)
	var col := Color("ffe478") if bounty else (Color("5ef2e8") if theme_key == "abyss" else (Color("d46eff") if theme_key == "void" else Color("7ef296")))
	game.effect(mob.position, 42.0 if bounty else 26.0, col, "summon", 0.26)
	return mob


func _clear_room(rid: String) -> void:
	var rm: Dictionary = rooms[rid]
	if rm.state == "cleared":return
	rm.state = "cleared"
	if active_combat_room == rid:
		active_combat_room = ""
	for nb: String in rm.neighbors:
		if rooms.has(nb) and str(rooms[nb].state) == "hidden":
			rooms[nb].state = "discovered"

	if str(rm.reward_kind) != "":
		rm.reward_active = true
	if str(rm.kind) == "boss":
		descent_gate_active = true
	if int(rm.total_waves) > 0:
		game.event_bus.emit_event("rift_room_cleared", {"room_id": rid})
	_magnet_timers.append({"rect": Rect2(rm.inner_rect).grow(110.0), "delay": 0.38})

	if is_instance_valid(game.hero):
		var suffix := " · 深层跃迁门已开!" if str(rm.kind) == "boss" else "!"
		game.numbers.append({
			"point": Vector2(rm.center) + Vector2(0.0, -54.0),
			"text": "%s 清剿完成%s" % [str(rm.title), suffix],
			"colour": Color("82ffac"),
			"life": 1.2,
			"duration": 1.2,
			"critical": true
		})
	game.effect(Vector2(rm.center), 92.0, Color("82ffac"), "upgrade", 0.45)
	game.audio.play("phase", -8.0, 1.32)
	if game.passive_engine != null and game.passive_engine.pending_ups > 0 and is_instance_valid(game.hud) and game.hud.has_method("pulse_passive_badge"):
		game.hud.pulse_passive_badge()


func _spawn_xp_fountain(pos: Vector2, violet_cnt: int, gold_cores: int, xp_each: int, gold_each: int) -> void:
	var g_mult: float = float(game.relic_engine.gold_xp_mult()) if (game != null and game.relic_engine != null) else 1.0
	for _i in range(violet_cnt):
		game.spawn_pickup(pos, "rift", "violet", xp_each, int(round(float(gold_each) * g_mult)))
	for _g in range(gold_cores):
		game.spawn_pickup(pos, "rift", "gold_core", 68, int(round(4.0 * g_mult)))


func _claim_room_reward(rid: String) -> void:
	var rm: Dictionary = rooms[rid]
	if bool(rm.reward_claimed):
		return
	rm.reward_claimed = true
	var rkind := str(rm.reward_kind)
	var rpos := Vector2(rm.reward_pos)
	var g_mult: float = float(game.relic_engine.gold_xp_mult()) if (game != null and game.relic_engine != null) else 1.0

	if rkind == "chest":
		var gain_g := int(round(50.0 * g_mult))
		game.gain_gold(gain_g, "rift_room")
		_spawn_xp_fountain(rpos, 6, 2, 34, 1)
		var relic_note := ""
		if game.relic_engine != null and (floor_index >= 2 or floor_rng.randf() < 0.55):
			var rel: Dictionary = game.relic_engine.grant_random_relic(floor_rng)
			if not rel.is_empty():
				relic_note = " · 得遗物[" + str(rel.name) + "]!"
		game.numbers.append({"point": rpos + Vector2(0, -34), "text": "秘宝箱 +%d金 · 晶石喷泉%s" % [gain_g, relic_note], "colour": Color("ffe678"), "life": 1.30, "duration": 1.30, "critical": true})
	elif rkind == "miniboss_relic":
		var gain_mg := int(round(75.0 * g_mult))
		game.gain_gold(gain_mg, "rift_room")
		var shield_m: float = game.add_core_shield(70.0)
		_spawn_xp_fountain(rpos, 8, 2, 38, 2)
		var rel_m: Dictionary = game.relic_engine.grant_random_relic(floor_rng) if game.relic_engine != null else {}
		if rel_m.is_empty():
			game.gain_gold(25, "rift_room")
			gain_mg += 25
			shield_m += game.add_core_shield(60.0)
		var msg_m := "统领秘藏 +%d 金 · +%d 盾" % [gain_mg,roundi(shield_m)]
		msg_m += " · 遗物[%s]" % rel_m.name if not rel_m.is_empty() else " · 遗物已满"
		game.numbers.append({"point": rpos + Vector2(0, -36), "text": msg_m, "colour": Color("ffe678"), "life": 1.35, "duration": 1.35, "critical": true})
	elif rkind == "boss_chest":
		var gain_bg := int(round(110.0 * g_mult))
		game.gain_gold(gain_bg, "rift_room")
		var shield_b: float = game.add_core_shield(120.0)
		_spawn_xp_fountain(rpos, 10, 3, 44, 3)
		var rel_b: Dictionary = game.relic_engine.grant_random_relic(floor_rng) if game.relic_engine != null else {}
		if rel_b.is_empty():
			game.gain_gold(40, "rift_room")
			gain_bg += 40
			shield_b += game.add_core_shield(80.0)
		var msg_b := "神殿传奇箱 +%d 金 · +%d 盾" % [gain_bg,roundi(shield_b)]
		msg_b += " · 遗物[%s]" % rel_b.name if not rel_b.is_empty() else " · 遗物已满"
		game.numbers.append({"point": rpos + Vector2(0, -38), "text": msg_b, "colour": Color("ffe678"), "life": 1.45, "duration": 1.45, "critical": true})

	_magnet_timers.append({"rect": Rect2(rm.inner_rect).grow(120.0), "delay": 0.25})
	game.effect(rpos, 92.0, Color("ffe678"), "upgrade", 0.52)
	game.audio.play("phase", -7.0, 1.38)


func on_rift_mob_killed(enemy: Node2D) -> void:
	if not is_instance_valid(enemy) or not bool(enemy.is_rift_mob):
		return


func _update_defense_radar(delta: float) -> void:
	max_road_ratio = 0.0
	live_road_enemies = 0
	for e in game.domain_enemies("defense"):
		if not is_instance_valid(e) or e.dead or e.is_guard:
			continue
		live_road_enemies += 1
		var road: Curve2D = game.enemy_road(e)
		if road != null:
			var r := clampf(float(e.progress) / maxf(1.0, road.get_baked_length()), 0.0, 1.0)
			if r > max_road_ratio:
				max_road_ratio = r
	var prev_alarm := alarm_level
	if core_hit_alert > 0.0 or max_road_ratio >= 0.86:
		alarm_level = 2
	elif game.siege_alert_active or max_road_ratio >= 0.70:
		alarm_level = 1
	else:
		alarm_level = 0

	if game.active_domain == "rift":
		if alarm_level == 2:
			_beep_clock -= delta
			if _beep_clock <= 0.0:
				_beep_clock = 0.56
				game.audio.play("crit", -9.0, 1.48)
		elif alarm_level == 1 and prev_alarm == 0:
			game.audio.play("phase", -10.0, 0.86)


func _draw() -> void:
	if game == null or not game.started or game.feel_lab or game.tower_lab:
		return
	var t := float(Time.get_ticks_msec()) * 0.004

	# 1. Corridor exploration chevrons
	if game.active_domain == "rift" and active_combat_room.is_empty():
		for c: Dictionary in corridors:
			if not _is_corridor_passable(c):
				continue
			var r_a: Dictionary = rooms[c.a]
			var r_b: Dictionary = rooms[c.b]
			var unexplored_target: Dictionary = {}
			if str(r_a.state) == "cleared" and str(r_b.state) != "cleared":
				unexplored_target = r_b
			elif str(r_b.state) == "cleared" and str(r_a.state) != "cleared":
				unexplored_target = r_a
			if not unexplored_target.is_empty():
				var cr: Rect2 = c.rect
				var mid := cr.get_center()
				var from_c := Vector2(r_a.center) if unexplored_target.id == r_b.id else Vector2(r_b.center)
				var dir := (Vector2(unexplored_target.center) - from_c).normalized()
				var pulse := 0.55 + 0.45 * sin(t * 2.2)
				var p0 := mid + dir * (-6.0 + sin(t * 2.2) * 5.0)
				var perp := dir.orthogonal()
				var tip := p0 + dir * 16.0
				draw_polyline(PackedVector2Array([tip - dir * 14.0 + perp * 11.0, tip, tip - dir * 14.0 - perp * 11.0]), Color(0.45, 0.94, 1.0, 0.88 * pulse), 3.2, false)
				if is_instance_valid(game.hero) and game.hero.position.distance_squared_to(mid) < 370.0*370.0:
					var tag: String = {"boss":"首领","miniboss":"统领","chest":"宝箱","event":"奇遇","elite":"精英"}.get(unexplored_target.kind,"战斗")
					var mutator: Dictionary = ArenaRiftPCG.MUTATORS[unexplored_target.mutator]
					if not str(mutator.name).is_empty():tag += " · "+str(mutator.name)
					var font := ThemeDB.fallback_font
					var offset := Vector2(font.get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x*0.5,21.0)
					draw_string_outline(font,mid-offset,tag,HORIZONTAL_ALIGNMENT_LEFT,-1,17,4,Color("071321"))
					draw_string(font,mid-offset,tag,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("ddf0de"))

	# 2. Room props: Pillars, Explosive Barrels, Hazards, Chests, Event Shrines, Descent Gate, Door Barriers
	for rid: String in room_order:
		var rm: Dictionary = rooms[rid]
		var rst := str(rm.state)
		if rst == "hidden":
			continue

		for ob: Rect2 in rm.obstacles:
			var oc := ob.get_center()
			if _tex_pillar != null:
				draw_texture_rect(_tex_pillar, Rect2(oc - Vector2(30.0, 58.0), Vector2(60.0, 76.0)), false)

		for br: Dictionary in rm.barrels:
			if not bool(br.alive):
				continue
			var bp := Vector2(br.pos)
			draw_set_transform(bp + Vector2(0.0, 6.0), 0.0, Vector2(1.0, 0.48))
			draw_arc(Vector2.ZERO, 24.0 + sin(t * 2.8) * 2.5, 0.0, TAU, 18, Color("6cf4ff", 0.55), 2.0)
			draw_set_transform(Vector2.ZERO)
			if _tex_barrel != null:
				draw_texture_rect(_tex_barrel, Rect2(bp - Vector2(26.0, 42.0), Vector2(52.0, 52.0)), false)
			var br_hp := float(br.hp)
			var br_max := float(br.max_hp)
			if br_hp < br_max:
				draw_rect(Rect2(bp + Vector2(-16.0, -48.0), Vector2(32.0, 4.0)), Color("141822"))
				draw_rect(Rect2(bp + Vector2(-16.0, -48.0), Vector2(32.0 * clampf(br_hp / br_max, 0.0, 1.0), 4.0)), Color("6cf4ff"))

		for hz: Dictionary in rm.hazards:
			if rst == "locked_combat" and bool(hz.armed):
				var hp := Vector2(hz.pos)
				var hrad := float(hz.radius)
				var rem := clampf((float(hz.cycle) - float(hz.clock)) / 1.15, 0.0, 1.0)
				draw_circle(hp, hrad, Color(0.85, 0.28, 1.0, 0.18 + (1.0 - rem) * 0.25))
				draw_arc(hp, hrad, 0.0, TAU, 28, Color("ff78a8", 0.90), 3.0)
				draw_arc(hp, hrad * (1.0 - rem), 0.0, TAU, 24, Color("ffe678", 0.92), 2.4)

		if str(rm.kind) == "event":
			var ep := Vector2(rm.event_pos)
			var ek := str(rm.event_kind)
			var used := bool(rm.event_used)
			var etex := _tex_altar_blood if ek == "blood_altar" else (_tex_anvil_forge if ek == "forge_anvil" else _tex_pedestal)
			draw_set_transform(ep + Vector2(0.0, 6.0), 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, 38.0, Color(0.05, 0.08, 0.14, 0.55))
			if not used:
				draw_arc(Vector2.ZERO, 40.0 + sin(t * 2.4) * 3.0, 0.0, TAU, 24, Color("ffe678", 0.85), 2.8)
			draw_set_transform(Vector2.ZERO)
			if etex != null:
				draw_texture_rect(etex, Rect2(ep - Vector2(46.0, 78.0), Vector2(92.0, 92.0)), false, Color(0.68, 0.72, 0.78, 0.75) if used else Color.WHITE)

		if bool(rm.reward_active):
			var rp := Vector2(rm.reward_pos)
			var claimed := bool(rm.reward_claimed)
			draw_set_transform(rp + Vector2(0.0, 6.0), 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, 34.0, Color(0.05, 0.08, 0.14, 0.55))
			if not claimed:
				draw_arc(Vector2.ZERO, 36.0 + sin(t * 2.4) * 3.0, 0.0, TAU, 24, Color("ffe678", 0.78), 2.5)
			draw_set_transform(Vector2.ZERO)
			var rtex: Texture2D = _tex_chest_open if claimed else _tex_chest_closed
			if rtex != null:
				draw_texture_rect(rtex, Rect2(rp - Vector2(44.0, 74.0), Vector2(88.0, 88.0)), false)

		if rst == "locked_combat":
			var ir: Rect2 = rm.inner_rect
			var c_pt := Vector2(rm.center)
			var doors: Array = rm.doors
			for d_side: String in doors:
				var door_pt: Vector2
				var bar_perp: Vector2
				if d_side == "E":
					door_pt = Vector2(ir.end.x, c_pt.y)
					bar_perp = Vector2(0.0, 62.0)
				elif d_side == "W":
					door_pt = Vector2(ir.position.x, c_pt.y)
					bar_perp = Vector2(0.0, 62.0)
				elif d_side == "S":
					door_pt = Vector2(c_pt.x, ir.end.y)
					bar_perp = Vector2(62.0, 0.0)
				else:
					door_pt = Vector2(c_pt.x, ir.position.y)
					bar_perp = Vector2(62.0, 0.0)
				draw_line(door_pt - bar_perp, door_pt + bar_perp, Color(0.78, 0.36, 1.0, 0.85), 5.0, false)
				draw_line(door_pt - bar_perp, door_pt + bar_perp, Color(0.55, 0.94, 1.0, 0.92), 2.0, false)
				if _tex_barrier != null:
					for side: float in [-1.0, 1.0]:
						var bp_bar := door_pt + bar_perp * side
						draw_texture_rect(_tex_barrier, Rect2(bp_bar - Vector2(22.0, 50.0), Vector2(44.0, 54.0)), false)

	# 2b. Deep Descent Gate (appears in Boss room once Boss is defeated)
	if descent_gate_active and game.active_domain == "rift":
		draw_set_transform(descent_gate_pos + Vector2(0.0, 10.0), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 48.0, Color(0.18, 0.08, 0.36, 0.65))
		draw_arc(Vector2.ZERO, 52.0 + sin(t * 3.0) * 4.0, 0.0, TAU, 30, Color("ffe678", 0.92), 3.0)
		draw_set_transform(Vector2.ZERO)
		if _tex_descent_gate != null:
			draw_texture_rect(_tex_descent_gate, Rect2(descent_gate_pos - Vector2(60.0, 96.0), Vector2(120.0, 120.0)), false)

	# 3. Room spawn telegraphs
	for tel in _telegraphs:
		var u := 1.0 - clampf(float(tel.life) / float(tel.duration), 0.0, 1.0)
		var tp := Vector2(tel.pos)
		var c_tel := Color("ffe46e") if bool(tel.bounty) else Color("d26eff")
		draw_set_transform(tp, 0.0, Vector2(1.0, 0.55))
		draw_arc(Vector2.ZERO, 16.0 + u * 22.0, 0.0, TAU, 20, Color(c_tel.r, c_tel.g, c_tel.b, 0.48 + 0.45 * u), 3.0)
		draw_circle(Vector2.ZERO, 10.0 * u, Color(c_tel.r, c_tel.g, c_tel.b, 0.38))
		draw_set_transform(Vector2.ZERO)

	# 4. Summoned dynamic 8-frame pixel portals
	for fx in _portal_fx:
		var fp := clampf(1.0 - float(fx.life) / float(fx.duration), 0.0, 1.0)
		var pos := Vector2(fx.pos)
		if _tex_portal_warp != null:
			var f_idx := clampi(int(floor(fp * 4.0)) if bool(fx.opening) else (3 + clampi(int(floor(fp * 5.0)), 0, 4)), 0, 7)
			var cell_w := float(_tex_portal_warp.get_width()) / 8.0
			var cell_h := float(_tex_portal_warp.get_height())
			var alpha := clampf(1.0 - maxf(0.0, fp - 0.72) / 0.28, 0.0, 1.0)
			draw_texture_rect_region(
				_tex_portal_warp,
				Rect2(pos - Vector2(58.0, 86.0), Vector2(116.0, 116.0)),
				Rect2(Vector2(float(f_idx) * cell_w, 0.0), Vector2(cell_w, cell_h)),
				Color(1.0, 1.0, 1.0, alpha)
			)
