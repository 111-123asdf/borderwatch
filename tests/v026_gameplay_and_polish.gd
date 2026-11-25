extends SceneTree

var checks := 0
var failures := 0
var game: ArenaGame


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V026 FAIL: " + message)


func frames(count := 2) -> void:
	for _i in range(count):
		await process_frame


func deploy(stage := "forest", hero_id := "lord") -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	current_scene = game
	await frames(2)
	game.rng.seed = 26
	game.start_run(hero_id, stage)
	game.set_physics_process(false)
	game.hero.set_physics_process(false)


func cleanup() -> void:
	paused = false
	if is_instance_valid(game):
		game.running = false
		game.audio.shutdown()
		await frames(2)
		OS.delay_msec(120)
		game.queue_free()
		await frames(2)


func run() -> void:
	await test_v026_assets_and_portraits()
	await test_barracks_blocks_heavy_and_actively_strikes()
	await test_unrestricted_midwave_build_upgrade_sell()
	await test_open_exit_twin_pillars_and_35s_teleport()
	await test_hero_in_place_revive()
	print("V026 GAMEPLAY & POLISH CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func test_v026_assets_and_portraits() -> void:
	for k: String in ["storm", "lens", "snare"]:
		var p_tex := ArenaBattleArt.tower_portrait(k)
		check(p_tex != null and not p_tex.get_image().is_invisible(), "v026 updated portrait exists & non-empty for " + k)
		var p_img := p_tex.get_image()
		check(p_img.get_width() == 128 and p_img.get_height() == 128, "portrait %s is 128x128" % k)
		check(p_img.get_pixel(0, 0).a < 0.1, "portrait %s keeps clean transparent outer corners" % k)
	for f_idx in range(3):
		var pil_tex := ArenaBattleArt.prop_frame_texture("exit_pillar", f_idx, 3)
		check(pil_tex != null and not pil_tex.get_image().is_invisible(), "prop_exit_pillar frame %d non-empty" % f_idx)
	await frames(1)


func test_barracks_blocks_heavy_and_actively_strikes() -> void:
	await deploy("forest", "lord")
	game.gold = 2000
	game.hero.position = Vector2(180.0, 220.0) # Keep hero away from barracks on site 2
	check(game.build_tower(2, "barracks"), "build barracks on site 2")
	var camp := game.site_tower(2)
	camp.finish_project()
	check(camp.troops.size() == 3, "barracks deploys 3 soldiers")
	for s: ArenaSoldier in camp.troops:
		s.deployment_left = 0.0
		s.position = camp.destination_flag() + s._slot_offset()

	# 1. Heavy capacity>=2 enemies (tusk_fighter, bear_vanguard) and elites must be blocked & attacked
	var tusk := game.spawn_enemy("tusk_fighter", 0, 200.0)
	tusk.position = camp.destination_flag() + Vector2(-42.0, 0.0)
	var bear := game.spawn_enemy("bear_vanguard", 0, 210.0)
	bear.position = camp.destination_flag() + Vector2(0.0, 0.0)
	var elite_pig := game.spawn_enemy("pigsoldier", 0, 220.0, true)
	elite_pig.position = camp.destination_flag() + Vector2(36.0, 0.0)
	game.blocking.update()
	check(tusk.blocker is ArenaSoldier, "barracks soldier blocks heavy tusk_fighter (capacity 2)")
	check(bear.blocker is ArenaSoldier, "barracks soldier blocks heavy bear_vanguard (capacity 3)")
	check(elite_pig.blocker is ArenaSoldier, "barracks soldier blocks elite enemy")

	var tusk_hp := tusk.health
	for _i in range(45):
		for s: ArenaSoldier in camp.troops:
			s._physics_process(0.05)
	check(tusk.health < tusk_hp, "soldiers actively approach & deal damage to heavy tusk_fighter (hp %.1f -> %.1f)" % [tusk_hp, tusk.health])

	# 2. Unstoppable enemy (darksteel_guard) is NOT blocked, yet soldiers proactively strike it instead of standing idle
	game.remove_enemy(tusk)
	game.remove_enemy(bear)
	game.remove_enemy(elite_pig)
	game.blocking.update()
	var rhino := game.spawn_enemy("darksteel_guard", 0, 260.0)
	rhino.position = camp.destination_flag() + Vector2(-50.0, 0.0)
	rhino.health = 500.0
	game.blocking.update()
	check(rhino.blocker == null, "darksteel_guard remains unstoppable (cannot be blocked)")
	var rhino_hp := rhino.health
	for _i in range(35):
		for s: ArenaSoldier in camp.troops:
			s._physics_process(0.05)
	check(rhino.health < rhino_hp, "soldiers actively slash passing unstoppable darksteel_guard instead of idling (hp %.1f -> %.1f)" % [rhino_hp, rhino.health])
	await cleanup()


func test_unrestricted_midwave_build_upgrade_sell() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	current_scene = game
	await frames(2)
	game.start_run("lord", "forest")
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	game.gold = 2500
	check(game.build_tower(0, "archer"), "build archer during prep")
	var arch := game.site_tower(0)
	arch.finish_project()
	game.begin_wave()
	check(game.phase == "spawn", "wave started")
	check(game.can_change_towers(), "can_change_towers stays true mid-wave")
	check(game.can_sell_towers(), "can_sell_towers stays enabled mid-wave")
	arch.gain_auto_xp(60.0)
	check(arch.level == 2, "archer auto-evolved to L2 mid-wave")
	check(game.build_tower(1, "mage"), "can build new tower mid-wave")
	check(game.unlock_site(7), "can unlock locked site mid-wave")
	check(arch.sell(), "can sell completed tower mid-wave")
	await cleanup()


func test_open_exit_twin_pillars_and_35s_teleport() -> void:
	# All 6 maps must have unobstructed open exit core & twin pillars installed (dual exits on sanctum)
	for stg: String in ArenaLevelCatalog.IDS:
		await deploy(stg, "lord")
		var c := Vector2(game.level_definition.core)
		check(game.static_walkable(c), "exit core position is completely walkable (open exit) on " + stg)
		var pillars := game.actors.get_children().filter(func(n): return n is ArenaExitGate)
		var expected_pillars := 4 if stg == "sanctum" else 2
		check(pillars.size() == expected_pillars, "expected ArenaExitGate pillars installed on " + stg)
		await cleanup()

	await deploy("forest", "lord")
	var road: Curve2D = game.routes[0]
	var rlen := road.get_baked_length()
	game.begin_wave()
	check(game.exit_ward_ready(), "exit ward starts charged & ready")
	var core_before := game.core_health
	var fox := game.spawn_enemy("fox", 0, rlen - 20.0)
	fox._physics_process(0.10)
	check(is_instance_valid(fox) and not fox.dead, "first leaking non-boss is rescued/teleported instead of despawning")
	check(is_equal_approx(game.core_health, core_before), "teleported enemy deals zero core damage")
	check(fox.progress < rlen * 0.55 and game.exit_ward_cd > 34.0 and game.exit_ward_triggers == 1, "enemy teleported back near midpoint & 35s ward cooldown started (prog=%.1f, cd=%.1f)" % [fox.progress, game.exit_ward_cd])

	# While ward is on cooldown, next enemy leaks normally
	var fox2 := game.spawn_enemy("fox", 0, rlen - 2.0)
	fox2._physics_process(0.10)
	check(game.core_health < core_before, "subsequent leak during 35s cooldown damages core normally")

	# Reset cooldown cleanly and confirm final boss bypasses teleport
	game.exit_ward_cd = 0.0
	var boss := game.spawn_enemy("moth", 0, rlen - 2.0)
	boss._physics_process(0.15)
	check(game.game_over and not game.victory, "boss ignores exit ward teleport and still ends run at core")
	await cleanup()


func test_hero_in_place_revive() -> void:
	await deploy("forest", "lord")
	var h := game.hero
	var spot := Vector2(610.0, 415.0)
	check(spot.distance_to(Vector2(game.level_definition.hero_spawn)) > 500.0, "test spot is far from initial hero_spawn")
	h.position = spot
	h.set_physics_process(true)
	h.knocked_out = true
	h.revive_clock = 0.08
	h.health = 0.0
	for _i in range(10):
		h._physics_process(0.02)
	check(not h.knocked_out and is_equal_approx(h.health, h.max_health), "hero revived at full health")
	check(h.position.distance_to(spot) < 5.0 and h.protection > 1.0, "hero revived in-place at KO location (%.1f px from spot) with i-frames" % h.position.distance_to(spot))
	await cleanup()
