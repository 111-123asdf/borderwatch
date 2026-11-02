extends SceneTree

# Standalone native-window fixture: injected gold/enemy, no natural-play claim.
# Reports only this process's state; the external driver targets its PID.
var game
var output := ""
var last_update := 0
var screenshot_saved := false
var tower_screenshot_saved := false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	output = OS.get_environment("BW_PROBE_DIR")
	if output.is_empty():
		push_error("BW_PROBE_DIR is required")
		quit(1)
		return
	DisplayServer.window_set_title("Borderwatch independent build probe")
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	game.gold = 1000
	game.spawn_enemy("torch", game.hero.position + Vector2(110, 0), 10000.0)
	process_frame.connect(_write_state)

func _cell_candidate(edge: bool) -> Dictionary:
	var size := root.get_visible_rect().size
	var best_score := -INF
	var result := {}
	for x in range(game.GRID_W):
		for y in range(game.GRID_H):
			var cell := Vector2i(x, y)
			if not game._build_site_ok(cell): continue
			var p: Vector2 = root.get_canvas_transform() * game.cell_center(cell)
			if p.x < 16 or p.y < 16 or p.x > size.x - 16 or p.y > size.y - 16: continue
			var distance := minf(minf(p.x, size.x - p.x), minf(p.y, size.y - p.y))
			var score := -distance if edge else -p.distance_to(size * 0.5)
			if score > best_score:
				best_score = score
				result = {"cell": [x, y], "point": [p.x, p.y], "edge_distance": distance}
	return result

func _write_state() -> void:
	if not is_instance_valid(game) or Time.get_ticks_msec() - last_update < 120: return
	last_update = Time.get_ticks_msec()
	var buttons := []
	for b in game.hud.build_buttons:
		var p: Vector2 = b.get_global_rect().get_center()
		buttons.append([p.x, p.y])
	var panel: Rect2 = game.hud.build_palette.get_global_rect()
	var size := root.get_visible_rect().size
	var state := {
		"pid": OS.get_process_id(), "build_mode": game.build_mode,
		"selected": game.build_site_selected, "cell": [game.build_cell.x, game.build_cell.y],
		"center": _cell_candidate(false), "edge": _cell_candidate(true),
		"towers": game.towers.size(), "shots": game.hero.shots_fired,
		"kinds": game.towers.map(func(t): return t.kind),
		"guide": is_instance_valid(game.hud.guide_overlay),
		"buttons": buttons, "palette": game.hud.build_palette.visible,
		"panel_rect": [panel.position.x, panel.position.y, panel.size.x, panel.size.y],
		"viewport": [size.x, size.y], "reason": game.build_reason,
	}
	var file := FileAccess.open(output.path_join("state.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(state))
		file.close()
	if game.hud.build_palette.visible and not screenshot_saved:
		screenshot_saved = true
		_save_screenshot.call_deferred("build-menu.png")
	if game.towers.size() >= 4 and not game.build_mode and not tower_screenshot_saved:
		tower_screenshot_saved = true
		_save_screenshot.call_deferred("tower-examples.png")

func _save_screenshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(name))
