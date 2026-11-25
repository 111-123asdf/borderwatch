class_name ArenaStageGimmicks
extends Node2D

const LIGHTHOUSE_POS := Vector2(1470.0, 125.0)
const LIGHTHOUSE_COOLDOWN := 24.0
const LIGHTHOUSE_DURATION := 6.0

const RIFT_POS := Vector2(695.0, 455.0)
const SHRINE_POS := Vector2(120.0, 455.0)
const SHRINE_MAX_CHARGE := 24
const RIFT_SUPPRESS_TIME := 10.0

var game: Node2D
var clock := 0.0

var searchlight_cd := 0.0
var searchlight_active := 0.0
var searchlight_sweep_dir := 0.0

var shrine_charge := 0
var shrine_beam_clock := 0.0
var shrine_beam_target := Vector2(695.0, 455.0)
var rift_suppressed := 0.0

var _ambushes: Array[Dictionary] = []
var _triggered_waves: Dictionary = {}

func _ready() -> void:
	z_index = 18
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func has_active_beacon() -> bool:
	return game != null and game.level_id in ["lighthouse", "sanctum"]

func active_beacon_point() -> Vector2:
	if game == null:
		return Vector2.INF
	if game.level_id == "lighthouse":
		return LIGHTHOUSE_POS
	if game.level_id == "sanctum":
		return SHRINE_POS
	return Vector2.INF

func is_shoal_point(pt: Vector2) -> bool:
	if game == null or game.level_id != "lighthouse" or game.routes.size() <= 2:
		return false
	var road: Curve2D = game.routes[2]
	if road == null:
		return false
	var off: float = road.get_closest_offset(pt)
	var surf: Vector2 = road.sample_baked(off, true)
	return surf.distance_to(pt) <= 58.0 and off < road.get_baked_length() * 0.48

func nearest_dry_road(pt: Vector2) -> Dictionary:
	var best_dist := INF
	var best := {}
	if game == null:
		return best
	for r_i in range(game.routes.size()):
		var road: Curve2D = game.routes[r_i]
		if road == null:
			continue
		var total_len := road.get_baked_length()
		var steps := 28
		for s_i in range(steps + 1):
			var p_off := total_len * (float(s_i) / float(steps))
			if game.level_id == "lighthouse" and r_i == 2 and p_off < total_len * 0.48:
				continue
			var sample_pt: Vector2 = road.sample_baked(p_off, true)
			var d := pt.distance_squared_to(sample_pt)
			if d < best_dist:
				best_dist = d
				best = {"route": r_i, "progress": p_off, "point": sample_pt}
	return best

func is_enemy_submerged(enemy: Node2D) -> bool:
	if game == null or not is_instance_valid(enemy) or game.level_id != "lighthouse":
		return false
	if int(enemy.get("route_id")) != 2 or game.routes.size() <= 2:
		return false
	var road: Curve2D = game.routes[2]
	if road == null:
		return false
	return float(enemy.get("progress")) < road.get_baked_length() * 0.48

func is_rift_suppressed() -> bool:
	return rift_suppressed > 0.0

func on_enemy_killed(enemy: Node2D) -> void:
	if game == null or game.level_id != "sanctum" or not is_instance_valid(enemy):
		return
	if bool(enemy.get("is_rift_mob")):
		return
	var gain := 2 if bool(enemy.get("elite")) or (enemy.has_method("is_mini_boss") and enemy.is_mini_boss()) else 1
	shrine_charge = mini(SHRINE_MAX_CHARGE, shrine_charge + gain)
	queue_redraw()

func on_wave_started(wave_num: int) -> void:
	if game == null or _triggered_waves.has(wave_num):
		return
	_triggered_waves[wave_num] = true
	if game.level_id == "saltport":
		if wave_num == 2:
			_queue_ambush(Vector2(220.0, 445.0), 0, 265.0, ["murloc_hunter", "murloc_hunter"], "water_ambush")
		elif wave_num == 3:
			_queue_ambush(Vector2(950.0, 775.0), 1, 670.0, ["tide_rider", "murloc_hunter"], "water_ambush")
		elif wave_num == 4:
			_queue_ambush(Vector2(220.0, 445.0), 0, 265.0, ["tide_rider", "tide_warrior"], "water_ambush")
			_queue_ambush(Vector2(950.0, 775.0), 1, 670.0, ["murloc_hunter", "water_sprite"], "water_ambush")
	elif game.level_id == "lighthouse":
		if wave_num == 2:
			_queue_ambush(Vector2(310.0, 770.0), 2, 235.0, ["murloc_hunter", "water_sprite"], "water_ambush")
		elif wave_num == 4:
			_queue_ambush(Vector2(920.0, 125.0), 0, 620.0, ["tide_warrior", "tide_rider"], "water_ambush")
		elif wave_num == 5:
			_queue_ambush(Vector2(310.0, 770.0), 2, 540.0, ["tide_warrior", "water_sprite"], "water_ambush")
	elif game.level_id == "ruins":
		if wave_num == 2:
			_queue_ambush(Vector2(495.0, 795.0), 1, 595.0, ["void_eyeling", "spectral_cutter"], "chasm_ambush")
		elif wave_num == 3:
			_queue_ambush(Vector2(495.0, 795.0), 1, 560.0, ["spectral_cutter", "twilight_avenger"], "chasm_ambush")
		elif wave_num == 5:
			_queue_ambush(Vector2(495.0, 795.0), 1, 620.0, ["spectral_cutter", "twilight_harasser"], "chasm_ambush")

func _queue_ambush(from_pt: Vector2, route_idx: int, prog: float, kinds: Array, tag: String) -> void:
	if game == null or route_idx >= game.routes.size():
		return
	var road: Curve2D = game.routes[route_idx]
	if road == null:
		return
	var clamped_p := clampf(prog, 40.0, maxf(60.0, road.get_baked_length() - 60.0))
	var land_pt := road.sample_baked(clamped_p, true)
	game.delayed_attack(from_pt, 54.0, 0.0, 1, "neutral", 1.8, {"telegraph": tag})
	game.delayed_attack(land_pt, 46.0, 0.0, 1, "neutral", 1.8, {"telegraph": tag})
	_ambushes.append({
		"from": from_pt,
		"route": route_idx,
		"progress": clamped_p,
		"kinds": kinds,
		"delay": 1.8,
		"duration": 1.8,
		"tag": tag,
	})
	queue_redraw()

func trigger_active() -> bool:
	if game == null or game.game_over or not game.running:
		return false
	if game.level_id == "lighthouse":
		return _trigger_searchlight()
	if game.level_id == "sanctum":
		return _trigger_shrine()
	return false

func try_click(point: Vector2) -> bool:
	if not has_active_beacon():
		return false
	var target := active_beacon_point()
	if point.distance_to(target) <= 68.0:
		return trigger_active()
	return false

func _trigger_searchlight() -> bool:
	if searchlight_cd > 0.0 or searchlight_active > 0.0:
		return false
	searchlight_active = LIGHTHOUSE_DURATION
	searchlight_cd = LIGHTHOUSE_COOLDOWN
	for enemy in game.domain_enemies("defense"):
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_guard:
			continue
		enemy.lighthouse_exposed = maxf(enemy.lighthouse_exposed, LIGHTHOUSE_DURATION)
		enemy.storm_haste_clock = 0.0
	game.effect(LIGHTHOUSE_POS, 120.0, Color("ffe882"), "upgrade", 0.65)
	game.numbers.append({"point": LIGHTHOUSE_POS + Vector2(-40.0, 32.0), "text": "灯塔破雾!", "colour": Color("fff0a8"), "life": 1.2, "duration": 1.2})
	if is_instance_valid(game.audio):
		game.audio.play("mage_cast", -8)
	queue_redraw()
	return true

func _trigger_shrine() -> bool:
	if shrine_charge < SHRINE_MAX_CHARGE:
		return false
	shrine_charge = 0
	shrine_beam_clock = 1.05
	rift_suppressed = RIFT_SUPPRESS_TIME
	var blast_pt := _pick_shrine_target()
	shrine_beam_target = blast_pt
	for enemy in game.domain_enemies("defense"):
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_guard:
			continue
		if enemy.position.distance_to(blast_pt) <= 195.0 or enemy.position.distance_to(RIFT_POS) <= 135.0:
			var is_b: bool = enemy.is_boss()
			var stun_t := 1.0 if is_b else 2.0
			enemy.take_hit(260.0, ArenaCombat.Type.MAGIC, "hero", stun_t, 0.0, 0.30, "starfall", SHRINE_POS.direction_to(enemy.position))
	game.effect(blast_pt, 165.0, Color("7eeeff"), "starfall", 0.75)
	game.effect(RIFT_POS, 92.0, Color("ffd87a"), "shield_break", 0.65)
	game.numbers.append({"point": blast_pt + Vector2(0, -34), "text": "星陨制裁!", "colour": Color("fff4a6"), "life": 1.3, "duration": 1.3})
	if is_instance_valid(game.feel) and game.feel.enabled:
		game.feel.trauma = minf(1.0, game.feel.trauma + 0.35)
	if is_instance_valid(game.audio):
		game.audio.play("explode", -6)
	queue_redraw()
	return true

func _pick_shrine_target() -> Vector2:
	var best_pt := RIFT_POS
	var best_score := -1
	for enemy in game.domain_enemies("defense"):
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_guard:
			continue
		var score := 0
		for other in game.domain_enemies("defense"):
			if is_instance_valid(other) and not other.dead and other.position.distance_to(enemy.position) <= 195.0:
				score += 4 if other.is_boss() else 1
		if score > best_score:
			best_score = score
			best_pt = enemy.position
	return best_pt

func trigger_boss_rift_warp(boss: Node2D) -> void:
	if game == null or game.level_id != "sanctum" or not is_instance_valid(boss):
		return
	if rift_suppressed > 0.0:
		game.effect(RIFT_POS, 96.0, Color("ffd878"), "shield_break", 0.6)
		game.numbers.append({"point": RIFT_POS + Vector2(0, -32), "text": "星陨镇压裂隙!", "colour": Color("ffe994"), "life": 1.1, "duration": 1.1})
		return
	var target_route := 3 if game.routes.size() > 3 else 0
	var road: Curve2D = game.routes[target_route]
	game.effect(boss.position, 88.0, Color("cb76ff"), "void_warp", 0.65)
	if road != null and target_route == 3:
		boss.route_id = 3
		boss.progress = 20.0
		boss.position = RIFT_POS
		game.effect(RIFT_POS, 118.0, Color("ff78f4"), "void_warp", 0.75)
		for i in range(2):
			game.spawn_enemy("spectral_cutter", 3, 28.0 + float(i) * 26.0)
			game.spawn_enemy("void_eyeling", 3, 10.0 + float(i) * 22.0)
	else:
		for i in range(2):
			game.spawn_enemy("spectral_cutter", boss.route_id, maxf(0.0, boss.progress - 30.0 - float(i) * 24.0))

func _physics_process(delta: float) -> void:
	if game == null or not game.running or game.game_over:
		return
	clock += delta
	if searchlight_active > 0.0:
		searchlight_active = maxf(0.0, searchlight_active - delta)
		searchlight_sweep_dir += delta * 2.2
		for enemy in game.domain_enemies("defense"):
			if is_instance_valid(enemy) and not enemy.dead and not enemy.is_guard:
				enemy.lighthouse_exposed = maxf(enemy.lighthouse_exposed, 0.45)
				enemy.storm_haste_clock = 0.0
	if searchlight_cd > 0.0:
		searchlight_cd = maxf(0.0, searchlight_cd - delta)
	if rift_suppressed > 0.0:
		rift_suppressed = maxf(0.0, rift_suppressed - delta)
	if shrine_beam_clock > 0.0:
		shrine_beam_clock = maxf(0.0, shrine_beam_clock - delta)
	if not _ambushes.is_empty():
		var remaining: Array[Dictionary] = []
		for amb in _ambushes:
			amb.delay = float(amb.delay) - delta
			if float(amb.delay) <= 0.0:
				_spawn_ambush_pack(amb)
			else:
				remaining.append(amb)
		_ambushes = remaining
	if has_active_beacon() or not _ambushes.is_empty() or game.level_id == "sanctum":
		queue_redraw()

func _spawn_ambush_pack(amb: Dictionary) -> void:
	var r_idx := int(amb.route)
	var base_prog := float(amb.progress)
	var from_pt := Vector2(amb.from)
	var kinds: Array = amb.kinds
	var road: Curve2D = game.routes[r_idx] if r_idx < game.routes.size() else null
	if road == null:
		return
	for i in range(kinds.size()):
		var p_i := clampf(base_prog + float(i - 1) * 32.0, 35.0, maxf(50.0, road.get_baked_length() - 50.0))
		var enemy: Node2D = game.spawn_enemy(str(kinds[i]), r_idx, p_i)
		if is_instance_valid(enemy) and enemy.has_method("start_ambush_leap"):
			var dest_pt := road.sample_baked(p_i, true)
			enemy.start_ambush_leap(from_pt + Vector2(float(i) * 14.0 - 7.0, 0.0), dest_pt, 0.48)

func _draw() -> void:
	if game == null or not game.started:
		return
	if game.level_id == "lighthouse":
		_draw_lighthouse()
	elif game.level_id == "sanctum":
		_draw_void_rift()
		_draw_shrine()

func _draw_lighthouse() -> void:
	var ready := searchlight_cd <= 0.0 and searchlight_active <= 0.0
	if searchlight_active > 0.0:
		var ang := 2.4 + sin(searchlight_sweep_dir) * 0.62
		var dir_v := Vector2.RIGHT.rotated(ang)
		var perp := Vector2(-dir_v.y, dir_v.x)
		var b_len := 1050.0
		var cone := PackedVector2Array([
			LIGHTHOUSE_POS + Vector2(-8, -16),
			LIGHTHOUSE_POS + dir_v * b_len + perp * 165.0,
			LIGHTHOUSE_POS + dir_v * b_len - perp * 165.0
		])
		draw_colored_polygon(cone, Color(1.0, 0.92, 0.56, 0.18))
		var inner_cone := PackedVector2Array([
			LIGHTHOUSE_POS + Vector2(-8, -16),
			LIGHTHOUSE_POS + dir_v * (b_len * 0.85) + perp * 75.0,
			LIGHTHOUSE_POS + dir_v * (b_len * 0.85) - perp * 75.0
		])
		draw_colored_polygon(inner_cone, Color(1.0, 0.96, 0.78, 0.22))
	var box_pos := LIGHTHOUSE_POS + Vector2(-58.0, 34.0)
	_draw_pixel_widget(box_pos, "灯塔 [G]" if ready else ("照耀 %ds" % int(ceil(searchlight_active)) if searchlight_active > 0.0 else "CD %ds" % int(ceil(searchlight_cd))), 1.0 if ready else (1.0 - searchlight_cd / LIGHTHOUSE_COOLDOWN), ready, Color("ffe882"))

func _draw_void_rift() -> void:
	var sup := rift_suppressed > 0.0
	var active_rift: bool = int(game.get("cycle")) >= 5 and not sup
	for k in range(6):
		var a := clock * (2.6 if active_rift else 1.2) + float(k) * (TAU / 6.0)
		var rx := cos(a) * (34.0 if active_rift else 24.0)
		var ry := sin(a) * (18.0 if active_rift else 13.0)
		var p := (RIFT_POS + Vector2(rx, ry)).snapped(Vector2(2, 2))
		var col := Color("ffcf74", 0.85) if sup else (Color("e076ff", 0.92) if active_rift else Color("8b5cc4", 0.65))
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color("1b0e28", 0.82))
		draw_rect(Rect2(p - Vector2(2, 2), Vector2(4, 4)), col)
	if active_rift and int(clock * 3.0) % 2 == 0:
		var core_p := RIFT_POS.snapped(Vector2(2, 2))
		draw_rect(Rect2(core_p - Vector2(4, 4), Vector2(8, 8)), Color("ff9cff", 0.75))

func _draw_shrine() -> void:
	var ready := shrine_charge >= SHRINE_MAX_CHARGE
	var ratio := float(shrine_charge) / float(SHRINE_MAX_CHARGE)
	if shrine_beam_clock > 0.0:
		var bp := clampf(shrine_beam_clock / 1.05, 0.0, 1.0)
		draw_line(SHRINE_POS + Vector2(0, -18), shrine_beam_target, Color("18384e", 0.78 * bp), 14.0 * bp)
		draw_line(SHRINE_POS + Vector2(0, -18), shrine_beam_target, Color("6eeeff", 0.92 * bp), 8.0 * bp)
		draw_line(SHRINE_POS + Vector2(0, -18), shrine_beam_target, Color("fffbe0", 0.98 * bp), 3.0 * bp)
	for s_i in range(4):
		var sa := clock * 1.8 + float(s_i) * (TAU / 4.0)
		var sr := 22.0 + sin(clock * 3.0 + float(s_i)) * 3.0
		var sp := (SHRINE_POS + Vector2(cos(sa) * sr, sin(sa) * sr * 0.55 - 12.0)).snapped(Vector2(2, 2))
		draw_rect(Rect2(sp - Vector2(2, 2), Vector2(4, 4)), Color("ffe875" if ready else "7edcff", 0.88 if ready else 0.45 + 0.4 * ratio))
	var box_pos := SHRINE_POS + Vector2(-46.0, 28.0)
	_draw_pixel_widget(box_pos, "星陨 [G]" if ready else "充能 %d/%d" % [shrine_charge, SHRINE_MAX_CHARGE], ratio, ready, Color("86efff"))

func _draw_pixel_widget(origin: Vector2, text_str: String, fill_ratio: float, ready: bool, accent: Color) -> void:
	var w := 96.0
	var h := 24.0
	draw_rect(Rect2(origin - Vector2(2, 2), Vector2(w + 4.0, h + 4.0)), Color("090f17", 0.92))
	draw_rect(Rect2(origin, Vector2(w, h)), Color("182638", 0.94))
	draw_rect(Rect2(origin + Vector2(2, h - 5.0), Vector2((w - 4.0) * clampf(fill_ratio, 0.0, 1.0), 3.0)), accent if ready else Color("4d7c98"))
	draw_string_outline(ThemeDB.fallback_font, origin + Vector2(6, 15), text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 2, Color("070c12"))
	draw_string(ThemeDB.fallback_font, origin + Vector2(6, 15), text_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, accent if ready else Color("cfe0ed"))
