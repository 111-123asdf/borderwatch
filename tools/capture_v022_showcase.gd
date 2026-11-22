extends SceneTree
var out_dir := ProjectSettings.globalize_path("res://test-results/v022-showcase")
var game: ArenaGame

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):out_dir=arg.trim_prefix("--output=")
	if not out_dir.is_absolute_path() or DirAccess.make_dir_recursive_absolute(out_dir)!=OK:
		push_error("Invalid showcase output directory: "+out_dir)
		quit(1)
		return
	call_deferred("run")

func frames(n := 4) -> void:
	for _i in range(n):
		await process_frame

func snap(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := out_dir.path_join(filename)
	if img.save_png(path)!=OK:
		push_error("Could not save showcase frame: "+path)
		quit(1)
		return
	print("SAVED: ",path)

func cleanup() -> void:
	if is_instance_valid(game):
		game.running = false
		game.audio.shutdown()
		await frames(2)
		OS.delay_msec(120)
		game.queue_free()
		await frames(2)

func setup_battle(hero_id: String, stage := "forest") -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	for id in ArenaDefinitions.HERO_IDS:
		game.campaign.data.levels[id] = 5
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.start_run(hero_id, stage)
	await frames(3)
	game.gold = 900
	game.build_tower(0, "archer")
	game.build_tower(1, "barracks")
	await frames(2)

func run() -> void:
	# 1. Hero Hall with all 5 new pixel heroes
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	for id in ArenaDefinitions.HERO_IDS:
		game.campaign.data.levels[id] = 5
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.hud.frontend.hall()
	game.hud.frontend.select_hall("werewolf")
	await frames(5)
	await snap("v022_live_hall.png")
	await cleanup()

	# 2. Lord Dolorion — E Blood-Thorn Shield + Q Heavy Blood Cleave
	await setup_battle("lord")
	var road := game.routes[0]
	var center_pt := road.sample_baked(680.0, true)
	game.hero.position = center_pt
	for off in [36.0, 62.0, 88.0, 110.0]:
		game.spawn_enemy("brute" if off > 80.0 else "fox", 0, 680.0 - off)
	game.hero.facing = Vector2.LEFT
	game.hero.cast(1, center_pt)
	await create_timer(0.35).timeout
	game.hero.cancel_action()
	game.hero.cast(0, center_pt + Vector2(-90, 0))
	await create_timer(0.32).timeout
	await snap("v022_live_lord.png")
	await cleanup()

	# 3. Druid — Frost Wolf + Ember Wolf enlarged 1.35x Frenzy
	await setup_battle("druid")
	var d_pt := game.routes[0].sample_baked(640.0, true)
	game.hero.position = d_pt + Vector2(60, 48)
	for off in [20.0, 56.0, 96.0]:
		game.spawn_enemy("fox", 0, 640.0 - off)
	game.hero.cast(1, d_pt)
	await create_timer(0.55).timeout
	game.hero.cancel_action()
	game.hero.cast(0, d_pt - Vector2(40, 0))
	await create_timer(0.42).timeout
	await snap("v022_live_druid.png")
	await cleanup()

	# 4. Healer Aphrodite — Blooming Sanctuary + Blessing Ring around Towers/Soldiers
	await setup_battle("healer")
	var h_pt: Vector2 = Vector2(game.level_definition.sites[0]) + Vector2(45, 55)
	game.hero.position = h_pt
	game.hero.health = game.hero.max_health * 0.72
	for off in [10.0, 48.0, 86.0]:
		game.spawn_enemy("brute", 0, 560.0 - off)
	game.hero.cast(0, h_pt)
	await create_timer(0.34).timeout
	game.hero.cancel_action()
	game.hero.cast(1, h_pt)
	await create_timer(0.45).timeout
	await snap("v022_live_healer.png")
	await cleanup()

	# 5. Werewolf Gale — Transformed Giant White Werewolf mid-cleave!
	await setup_battle("werewolf")
	var w_pt := game.routes[0].sample_baked(680.0, true)
	game.hero.position = w_pt
	for off in [34.0, 56.0, 78.0, 102.0]:
		game.spawn_enemy("fox", 0, 680.0 - off)
	game.hero.facing = Vector2.LEFT
	game.hero.cast(1, w_pt)
	await create_timer(0.38).timeout
	game.hero.cancel_action()
	var foe := game.nearest_enemy(w_pt, 140.0)
	if foe != null:
		game.hero.attack_cooldown = 0.0
		game.hero.begin_attack(foe)
	await create_timer(0.28).timeout
	await snap("v022_live_werewolf.png")
	await cleanup()

	# 6. Gunner Syrus — Overdrive + Empowered Twin Piercing Crit Bolts!
	await setup_battle("gunner")
	var g_pt := game.routes[0].sample_baked(760.0, true) + Vector2(0, 28)
	game.hero.position = g_pt
	for off in [110.0, 150.0, 195.0, 240.0]:
		game.spawn_enemy("brute", 0, 760.0 - off)
	game.hero.facing = Vector2.LEFT
	game.hero.cast(1, g_pt)
	await create_timer(0.35).timeout
	game.hero.cancel_action()
	game.hero.cast(0, g_pt + Vector2(40, 20))
	await create_timer(0.24).timeout
	game.hero.cancel_action()
	game.hero.attack_cooldown = 0.0
	var target_e := game.nearest_enemy(g_pt, 420.0)
	if target_e != null:
		game.hero.begin_attack(target_e)
	await create_timer(0.29).timeout
	await snap("v022_live_gunner.png")
	await cleanup()

	quit(0)
