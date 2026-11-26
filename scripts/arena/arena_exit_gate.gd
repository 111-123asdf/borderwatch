class_name ArenaExitGate
extends Node2D
## Dual pixel Watch Rune Pillars guarding the open frontier exit.

const PILLAR_COLS := 3
const PILLAR_WORLD_HEIGHT := 78.0

var game: Node2D
var pillar_index := 0
var pair_positions: Array[Vector2] = []
var ground_center := Vector2.ZERO
var road_tangent := Vector2.RIGHT
var _clock := 0.0


static func all_gate_groups(arena: Node2D) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	if arena == null or arena.level_definition.is_empty():
		return groups
	var exits_raw: Array = arena.level_definition.get("exits", [arena.level_definition.get("core", Vector2(1510, 655))])
	for exit_item in exits_raw:
		var exit_pt := Vector2(exit_item)
		var tang := Vector2.RIGHT
		var best_dist := INF
		for road_var in arena.routes:
			var road: Curve2D = road_var
			if road == null:
				continue
			var rlen := road.get_baked_length()
			var tail_b := road.sample_baked(rlen, true)
			var d := tail_b.distance_squared_to(exit_pt)
			if d < best_dist:
				best_dist = d
				var tail_a := road.sample_baked(maxf(0.0, rlen - 36.0), true)
				if tail_b.distance_squared_to(tail_a) > 1.0:
					tang = (tail_b - tail_a).normalized()
		var perp := Vector2(-tang.y, tang.x)
		var gate_c := exit_pt - tang * 26.0
		var pair: Array[Vector2] = [gate_c - perp * 42.0, gate_c + perp * 42.0]
		groups.append({"center": gate_c, "tang": tang, "perp": perp, "pillars": pair})
	return groups


static func pillar_positions(arena: Node2D) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for g in all_gate_groups(arena):
		var pair: Array = g.pillars
		for pt in pair:
			positions.append(Vector2(pt))
	return positions


class _ExitThresholdSill extends Node2D:
	var perp := Vector2.DOWN
	var tang := Vector2.RIGHT
	func _draw() -> void:
		for i in range(-3, 4):
			var sp := (perp * (float(i) * 10.0) - tang * float((i % 2) * 2)).snapped(Vector2(2, 2))
			draw_rect(Rect2(sp - Vector2(3.0, 4.0), Vector2(6.0, 8.0)), Color(0.10, 0.09, 0.12, 0.42))
			draw_rect(Rect2(sp - Vector2(2.0, 3.0), Vector2(4.0, 6.0)), Color(0.56, 0.58, 0.64, 0.58))

static func install(arena: Node2D) -> void:
	if arena == null or not is_instance_valid(arena.actors):
		return
	var groups := all_gate_groups(arena)
	var all_positions := pillar_positions(arena)
	var p_counter := 0
	for g_idx in range(groups.size()):
		var g: Dictionary = groups[g_idx]
		var pair: Array = g.pillars
		var center_pt := Vector2(g.center)
		var tang := Vector2(g.tang)
		var perp := Vector2(g.perp)

		var sill := _ExitThresholdSill.new()
		sill.name = "ExitThresholdSill" if g_idx == 0 else "ExitThresholdSill_%d" % g_idx
		sill.z_index = -12
		sill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sill.position = center_pt
		sill.perp = perp
		sill.tang = tang
		arena.terrain.add_child(sill)

		for pt in pair:
			var node := ArenaExitGate.new()
			node.name = "ExitPillar_%d" % p_counter
			node.game = arena
			node.pillar_index = p_counter
			node.pair_positions = all_positions.duplicate()
			node.ground_center = center_pt
			node.road_tangent = tang
			node.position = Vector2(pt)
			arena.actors.add_child(node)
			p_counter += 1


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _process(delta: float) -> void:
	if game == null or not game.started:
		return
	_clock += delta
	if game.exit_ward_flash > 0.0 or game.exit_ward_cd > 0.0 or Engine.get_process_frames() % 3 == 0:
		queue_redraw()


func _draw() -> void:
	if game == null or not game.started:
		return
	var cd: float = game.exit_ward_cd
	var flash: float = game.exit_ward_flash
	var ready_now: bool = cd <= 0.0
	var frame_idx := 1 if flash > 0.0 else (0 if ready_now else 2)
	var tex := ArenaBattleArt.prop_frame_texture("exit_pillar", frame_idx, PILLAR_COLS)

	# Ground drop shadow anchored tightly under plinth
	draw_set_transform(Vector2(0.0, 2.0), 0.0, Vector2(1.0, 0.46))
	draw_circle(Vector2.ZERO, 17.0, Color(0.07, 0.09, 0.10, 0.45))
	draw_set_transform(Vector2.ZERO)

	var gem_local := Vector2(0.0, -PILLAR_WORLD_HEIGHT * 0.80)
	if tex != null:
		var tsize := tex.get_size()
		var draw_h := PILLAR_WORLD_HEIGHT
		var draw_w := draw_h * (tsize.x / maxf(1.0, tsize.y))
		# Foot pixel baseline inside prop_exit_pillar sits at ~69/72 from top.
		var foot_ratio := 69.0 / 72.0
		var top_left := Vector2(-draw_w * 0.5, -draw_h * foot_ratio).snapped(Vector2(1, 1))
		draw_texture_rect(tex, Rect2(top_left, Vector2(draw_w, draw_h)), false)
	else:
		draw_rect(Rect2(-12.0, -64.0, 24.0, 64.0), Color("586074"))

	var reduced := false
	if game.campaign != null and game.campaign.data != null:
		reduced = bool(game.campaign.data.reduced_motion)

	if flash > 0.0:
		var fp := clampf(flash / 0.55, 0.0, 1.0)
		var target_local := Vector2(game.exit_ward_last_target) - position
		var steps := 5
		var pts := PackedVector2Array([gem_local])
		var dir := (target_local - gem_local).normalized()
		var perp := Vector2(-dir.y, dir.x)
		for s_i in range(1, steps):
			var u := float(s_i) / float(steps)
			var jit := sin(u * 14.0 + _clock * 28.0 + float(pillar_index)) * 9.0 * sin(u * PI)
			pts.append((gem_local.lerp(target_local, u) + perp * jit).snapped(Vector2(2, 2)))
		pts.append(target_local)
		draw_polyline(pts, Color(0.08, 0.22, 0.34, 0.85 * fp), 4.8, false)
		draw_polyline(pts, Color(0.46, 0.92, 1.0, fp), 2.4, false)
		draw_polyline(pts, Color(1.0, 0.98, 0.86, fp), 1.0, false)
	elif ready_now:
		# Subtle floating cyan-gold rune sparks around the crystal
		var count := 2 if reduced else 3
		for k in range(count):
			var age := fmod(_clock * 0.65 + float(k) * 0.33 + float(pillar_index) * 0.21, 1.0)
			var drift_x := sin(_clock * 2.2 + float(k) * 2.4 + float(pillar_index)) * 7.0
			var sp := (gem_local + Vector2(drift_x, -age * 16.0)).snapped(Vector2(2, 2))
			var sa := sin(age * PI) * 0.82
			var sc := Color(0.56, 0.96, 1.0, sa) if k % 2 == 0 else Color(1.0, 0.92, 0.56, sa)
			draw_rect(Rect2(sp - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), Color(0.08, 0.12, 0.18, sa * 0.7))
			draw_rect(Rect2(sp - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), sc)
	else:
		# Subtle vertical pixel charge filament inside the recessed shaft groove showing cooldown recovery
		var frac := clampf(1.0 - cd / maxf(1.0, game.EXIT_WARD_COOLDOWN), 0.0, 1.0)
		var groove_bot := -PILLAR_WORLD_HEIGHT * 0.26
		var groove_top := -PILLAR_WORLD_HEIGHT * 0.62
		var fill_top := lerpf(groove_bot, groove_top, frac)
		draw_line(Vector2(0.0, groove_bot), Vector2(0.0, fill_top), Color(0.32, 0.82, 0.94, 0.68), 2.0, false)
