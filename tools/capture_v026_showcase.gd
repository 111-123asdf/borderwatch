extends SceneTree

var out_dir := ""


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	if out_dir.is_empty():
		out_dir = ProjectSettings.globalize_path("res://test-results/v026_media")
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("run")


func _pump(frames: int, dt: float = 1.0 / 60.0) -> void:
	for _i in range(frames):
		await process_frame
		if dt > 0.0 and root != null:
			var sc := current_scene as ArenaGame
			if is_instance_valid(sc):
				sc._physics_process(dt)
				sc._process(dt)


func _save_shot(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(filename))
	print("SAVED ", filename)


func _spawn_game(stage: String, hero_id: String, towers_list: Array[String]) -> ArenaGame:
	var game := load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	current_scene = game
	await process_frame
	game.run_towers.assign(towers_list)
	game.start_run(hero_id, stage, true)
	game.gold = 3500
	await process_frame
	return game


func _cleanup(game: ArenaGame) -> void:
	if is_instance_valid(game):
		game.running = false
		game.audio.shutdown()
		await process_frame
		OS.delay_msec(120)
		game.queue_free()
		await process_frame
		await process_frame


func run() -> void:
	await _shot_01_portraits_and_wave_upgrade()
	await _shot_02_barracks_blocking_heavy()
	await _shot_03_organic_vfx_zero_circles()
	await _shot_04_open_exit_twin_pillars()
	await _shot_05_creek_exit_and_revive()
	print("ALL V026 SHOWCASE SHOTS COMPLETE")
	quit(0)


func _shot_01_portraits_and_wave_upgrade() -> void:
	var list: Array[String] = ["storm", "lens", "snare", "barracks"]
	var game := await _spawn_game("forest", "lord", list)
	game.build_tower(0, "storm")
	var st := game.site_tower(0)
	st.finish_project()
	st.upgrade()
	st.finish_project()
	game.build_tower(1, "lens")
	var ln := game.site_tower(1)
	ln.finish_project()
	game.build_tower(2, "snare")
	var sn := game.site_tower(2)
	sn.finish_project()
	game.begin_wave()
	# Spawn a few enemies mid-road so live mid-wave action + build menu with 3 updated portraits + unlocked upgrade work cleanly
	game.spawn_enemy("pigsoldier", 0, 180.0)
	game.spawn_enemy("tusk_fighter", 0, 240.0)
	await _pump(25, 0.02)
	game.selected_site = 3
	game.hud.show_context(3)
	await _pump(4, 0.0)
	await _save_shot("01_portraits_and_wave_upgrade.png")
	await _cleanup(game)


func _shot_02_barracks_blocking_heavy() -> void:
	var list: Array[String] = ["archer", "barracks", "mage", "cannon"]
	var game := await _spawn_game("forest", "lord", list)
	game.hero.position = Vector2(180.0, 220.0)
	game.build_tower(2, "barracks")
	var camp := game.site_tower(2)
	camp.finish_project()
	camp.upgrade()
	camp.finish_project()
	game.build_tower(1, "archer")
	var arch := game.site_tower(1)
	arch.finish_project()
	for s: ArenaSoldier in camp.troops:
		s.deployment_left = 0.0
		s.position = camp.destination_flag() + s._slot_offset()
	game.begin_wave()
	var tusk := game.spawn_enemy("tusk_fighter", 0, 390.0)
	tusk.position = camp.destination_flag() + Vector2(-46.0, -4.0)
	var bear := game.spawn_enemy("bear_vanguard", 0, 415.0)
	bear.position = camp.destination_flag() + Vector2(8.0, 6.0)
	var ep := game.spawn_enemy("pigsoldier", 0, 430.0, true)
	ep.position = camp.destination_flag() + Vector2(-18.0, -16.0)
	var rhino := game.spawn_enemy("darksteel_guard", 0, 360.0)
	rhino.position = camp.destination_flag() + Vector2(-78.0, 8.0)
	await _pump(35, 0.02)
	await _save_shot("02_barracks_blocking_heavy.png")
	await _cleanup(game)


func _shot_03_organic_vfx_zero_circles() -> void:
	var list: Array[String] = ["cannon", "mage", "storm", "barracks"]
	var game := await _spawn_game("forest", "werewolf", list)
	game.feel.enabled = true
	game.hero.position = Vector2(540.0, 415.0)
	game.hero.facing = Vector2.RIGHT
	game.hero.cast(1, game.hero.position + Vector2.RIGHT * 40.0)
	game.build_tower(0, "cannon")
	var can := game.site_tower(0)
	can.finish_project()
	can.upgrade(); can.finish_project()
	can.upgrade("burning"); can.finish_project()

	# 1. Monster mid-melee urgent glint + pullback (zero red wedge)
	var bear := game.spawn_enemy("bear_vanguard", 0, 460.0)
	bear.position = Vector2(582.0, 415.0)
	bear.melee_clock = 0.0
	bear.melee(game.hero)
	bear.melee_windup = 0.14
	bear.visual.frame = 2

	# 2. Earth crack slam telegraph on clean open road (zero dashed circle)
	game.delayed_attack(Vector2(685.0, 290.0), 92.0, 40.0, 0, "enemy", 0.34, {"telegraph": "bear_slam"})
	# 3. Skunk toxic cloud with organic billowing puffs & bubbles (zero green ring)
	game.add_zone(Vector2(390.0, 395.0), 92.0, 7.0, 4.8, 1, "enemy", "toxic_cloud")
	# 4. Burning cannon fire zone with irregular embers & pixel flames (zero orange circle)
	game.add_zone(Vector2(820.0, 275.0), 74.0, 18.0, 4.0, 0, "tower", "burn")
	await _pump(4, 0.016)
	# 5. Active cannon blast explosion (spawned post-warmup so fireball peak is captured)
	game.effect(Vector2(760.0, 295.0), 82.0, Color("ff7832"), "cannon_blast", 0.60, Vector2.RIGHT, {"doctrine": "burning", "tier": 3})
	bear.melee_windup = 0.16
	bear.melee_target = game.hero
	bear.melee_dir = Vector2.LEFT
	bear._physics_process(0.001)
	await _pump(2, 0.0)
	await _save_shot("03_organic_vfx_zero_circles.png")
	await _cleanup(game)


func _shot_04_open_exit_twin_pillars() -> void:
	var list: Array[String] = ["archer", "storm", "lens", "barracks"]
	var game := await _spawn_game("forest", "lord", list)
	game.hero.position = Vector2(1320.0, 565.0)
	game.build_tower(6, "storm")
	var st := game.site_tower(6)
	if st != null: st.finish_project()
	game.unlock_site(7)
	game.build_tower(7, "archer")
	var ar := game.site_tower(7)
	if ar != null: ar.finish_project()
	game.begin_wave()
	var road: Curve2D = game.routes[0]
	var rlen := road.get_baked_length()
	var tusk := game.spawn_enemy("tusk_fighter", 0, rlen - 23.0)
	tusk.stun = 0.0
	var pig := game.spawn_enemy("pigsoldier", 0, rlen - 80.0)
	pig.stun = 0.0
	tusk._physics_process(0.08)
	await _pump(2, 0.016)
	await _save_shot("04_open_exit_twin_pillars.png")
	await _cleanup(game)


func _shot_05_creek_exit_and_revive() -> void:
	var list: Array[String] = ["archer", "mage", "lens", "barracks"]
	var game := await _spawn_game("creek", "healer", list)
	game.hero.position = Vector2(1260.0, 540.0)
	game.hero.knocked_out = true
	game.hero.revive_clock = 0.04
	game.build_tower(7, "lens")
	var ln := game.site_tower(7)
	if ln != null: ln.finish_project()
	await _pump(6, 0.016)
	await _save_shot("05_creek_exit_and_revive.png")
	await _cleanup(game)
