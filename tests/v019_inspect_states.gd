extends SceneTree

var game: ArenaGame
var out_dir: String = "user://v019-inspect"

func _initialize() -> void:
	call_deferred("_run")

func _wait_frames(n: int = 3) -> void:
	for _i in range(n):
		await process_frame

func _save_shot(filename: String) -> void:
	await _wait_frames(4)
	var img := root.get_texture().get_image()
	img.save_png(out_dir + "/" + filename)
	print("SAVED ", out_dir + "/" + filename)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)

	# 1. Stage 3 5-state plinth & compact HUD badge check (1600x900)
	game = load("res://scenes/arena.tscn").instantiate()
	var camp := ArenaCampaign.new("", false)
	camp.data.levels["knight"] = 5
	game.campaign = camp
	root.add_child(game)
	current_scene = game
	await _wait_frames(3)
	game.start_run("knight", "ruins")
	await _wait_frames(3)
	game.gold = 2000
	game.phase = "wave"

	# Build one Archer & one Cannon (built state), keep other sites open/locked
	var unlocked: Array[int] = []
	var locked_idx: int = -1
	for i in range(game.level_definition.sites.size()):
		if game.site_locked(i):
			if locked_idx < 0:
				locked_idx = i
		else:
			unlocked.append(i)
	if unlocked.size() >= 3:
		game.build_tower(unlocked[0], "archer")
		game.build_tower(unlocked[1], "mage")
		for t in game.towers:
			if t.site_id == unlocked[1]:
				t.upgrade()
				t.upgrade()
		# Select unlocked[2] to show selected plinth + compact icon+numeric build menu
		game.hud.show_context(unlocked[2])
	if game.camera != null:
		if not game.camera.overview:
			game.camera.toggle_overview()
	# Hover over unlocked[3] if available via synthetic mouse motion
	if unlocked.size() >= 4:
		var hover_pt: Vector2 = game.world_to_hud(game.level_definition.sites[unlocked[3]])
		var ev := InputEventMouseMotion.new()
		ev.position = hover_pt
		ev.global_position = hover_pt
		Input.parse_input_event(ev)
	await _save_shot("plinths_states.png")

	# 2. Stage 3 1280x720 zoomed battle check
	root.get_window().size = Vector2i(1280, 720)
	game.hud.close_context()
	if game.camera != null and game.camera.overview:
		game.camera.toggle_overview()
	if game.camera != null:
		game.camera.focus(Vector2(740, 540))
	game.spawn_enemy("construct_hound", 0, 480.0, false)
	game.spawn_enemy("rune_warden", 0, 420.0, false)
	game.spawn_enemy("astral_prism", 0, 360.0, false)
	await _wait_frames(20)
	await _save_shot("ruins_1280x720.png")

	# 3. Stage 1 Forest + Ranger + L3 Barracks/Mage
	game.running = false
	if game.audio != null:
		game.audio.shutdown()
	game.queue_free()
	await _wait_frames(3)
	root.get_window().size = Vector2i(1600, 900)
	game = load("res://scenes/arena.tscn").instantiate()
	var camp2 := ArenaCampaign.new("", false)
	camp2.data.levels["ranger"] = 5
	game.campaign = camp2
	root.add_child(game)
	current_scene = game
	await _wait_frames(3)
	game.start_run("ranger", "forest")
	await _wait_frames(3)
	game.gold = 2500
	game.phase = "wave"
	game.build_tower(0, "barracks")
	game.build_tower(1, "mage")
	for t in game.towers:
		t.upgrade()
		t.upgrade()
	game.spawn_enemy("fox", 0, 460.0, false)
	game.spawn_enemy("brute", 0, 380.0, false)
	await _wait_frames(38)
	await _save_shot("stage1_ranger_forest.png")

	# 4. Stage 2 Creek + Mage Hero + L3 Cannon/Archer
	game.running = false
	if game.audio != null:
		game.audio.shutdown()
	game.queue_free()
	await _wait_frames(3)
	game = load("res://scenes/arena.tscn").instantiate()
	var camp3 := ArenaCampaign.new("", false)
	camp3.data.levels["mage"] = 5
	game.campaign = camp3
	root.add_child(game)
	current_scene = game
	await _wait_frames(3)
	game.start_run("mage", "creek")
	await _wait_frames(3)
	game.gold = 2500
	game.phase = "wave"
	game.build_tower(0, "cannon")
	game.build_tower(1, "archer")
	for t in game.towers:
		t.upgrade()
		t.upgrade()
	game.spawn_enemy("spearman", 0, 460.0, false)
	game.spawn_enemy("wisp", 0, 380.0, false)
	await _wait_frames(38)
	await _save_shot("stage2_mage_creek.png")

	game.running = false
	if game.audio != null:
		game.audio.shutdown()
	await process_frame
	game.queue_free()
	await process_frame
	OS.delay_msec(200)
	print("V019 INSPECT: three stages, site states and compact menus captured; visual fixture")
	quit(0)
