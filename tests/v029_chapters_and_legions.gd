extends SceneTree

var checks := 0
var failures := 0
var game: ArenaGame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V029 FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func frames(count := 2) -> void:
	for _i in range(count):
		await process_frame

func cleanup() -> void:
	if is_instance_valid(game):
		game.running = false
		if is_instance_valid(game.audio):
			game.audio.shutdown()
		await frames(2)
		OS.delay_msec(120)
		game.queue_free()
		await frames(2)
	game = null

func run() -> void:
	create_timer(45.0).timeout.connect(func(): push_error("V029 TIMEOUT"); quit(1))
	# 1. 6-Stage Campaign & World Map Topology
	check(ArenaLevelCatalog.IDS == ["forest", "creek", "saltport", "lighthouse", "ruins", "sanctum"], "campaign exposes 6 ordered stages")
	check(ArenaLevelCatalog.MAP_TRAILS.size() == 5 and ArenaLevelCatalog.FUTURE_LOCKS.size() == 4, "world map connects 6 stages and retains 4 future locks")
	for stage in ArenaLevelCatalog.IDS:
		check(ArenaLevelCatalog.WORLD_NODES.has(stage), "WORLD_NODES has " + stage)

	# 2. All 24 Coast & Ruins pixel monsters + portraits + bosses
	var coast_kinds := ["murloc_hunter", "tide_rider", "water_sprite", "storm_wyrm", "tide_warrior", "wind_captain", "conch_mage", "water_elder", "tempest_elemental", "bluegale", "bloodshell_crab", "leviathan"]
	var ruins_kinds := ["void_eyeling", "void_gazer", "twilight_harasser", "spectral_cutter", "twilight_avenger", "avenger_rider", "venom_spitter", "soul_reaver", "twilight_golem", "vile_eyenest", "bloodsoil_behemoth", "baj_nimen"]
	for kind in coast_kinds + ruins_kinds:
		check(ResourceLoader.exists(ArenaCreature.sheet_path(kind)), "spritesheet exists for " + kind)
		var creature := ArenaCreature.new()
		root.add_child(creature)
		creature.configure(kind)
		check(creature.is_pixel_v023 and creature.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "nearest pixel sheet mounted for " + kind)
		check(creature.sprite_frames.has_animation("walk") and creature.sprite_frames.get_frame_count("walk") == 6, "6 walk frames for " + kind)
		creature.queue_free()
		check(ArenaMenuArt.creature(kind) != null, "portrait loads for " + kind)

	# 3. Stage 4 Lighthouse: 1600x900 pixel map, R2 shoal submersion, Searchlight, Leviathan tentacle seal
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.playtest()
	root.add_child(game)
	current_scene = game
	await frames(2)
	game.start_run("lord", "lighthouse")
	await frames(2)
	check(game.ground.texture != null and game.ground.texture.get_width() == 1600 and game.ground.texture.get_height() == 900, "lighthouse uses 1600x900 map")
	check(game.ground.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and game.ground.material == null, "lighthouse pixel map skips painterly shader")
	check(game.stage_gimmicks != null, "lighthouse mounts ArenaStageGimmicks")

	# R2 shoal submersion & un-blockable check
	var shooter := game.spawn_enemy("tide_rider", 2, 120.0)
	shooter.storm_haste_clock = 3.0
	shooter._physics_process(0.05)
	check(shooter.is_submerged(), "lighthouse R2 enemy starts submerged in shoal water")
	check(shooter.can_chase() == false, "submerged enemy cannot chase")
	game.gold = 3000
	game.build_tower(7, "barracks")
	var bar: ArenaTower = game.site_tower(7)
	bar.finish_project()
	check(not bar.order_preview(game.routes[2].sample_baked(80.0, true)).is_finite(), "barracks order_preview rejects deep shoal point")
	game.blocking.update()
	check(not game.blocking.assignments.has(shooter), "submerged enemy bypasses soldier blocking in shoal")
	shooter.progress = game.routes[2].get_baked_length() * 0.90
	shooter._physics_process(0.05)
	check(not shooter.is_submerged(), "lighthouse R2 enemy surfaces upon reaching eastern dike")

	# Lighthouse Searchlight strips storm haste & exposes for +20% damage
	check(game.stage_gimmicks.trigger_active(), "lighthouse Searchlight [G] triggers cleanly")
	check(not game.stage_gimmicks.trigger_active(), "lighthouse Searchlight respects cooldown")
	check(shooter.lighthouse_exposed > 1.0 and shooter.storm_haste_clock == 0.0, "Searchlight exposes enemies and strips storm_haste")
	var base_probe := game.spawn_enemy("murloc_hunter", 0, 100.0)
	var exp_probe := game.spawn_enemy("murloc_hunter", 0, 100.0)
	exp_probe.lighthouse_exposed = 4.0
	var dmg_norm := base_probe.take_hit(30.0, 0, "tower")
	var dmg_exp := exp_probe.take_hit(30.0, 0, "tower")
	check(is_equal_approx(dmg_exp, dmg_norm * 1.2), "lighthouse_exposed increases damage taken by +20%")

	# Leviathan tentacle seal locks tower upgrade/sell/respawn & HUD context
	game.build_tower(2, "archer")
	var arc: ArenaTower = game.site_tower(2)
	arc.finish_project()
	bar.troops[0].dead = true
	bar.troops[0].respawn_clock = 8.0
	bar.apply_seal(7.5, 0.0)
	arc.apply_seal(7.5, 0.0)
	check(arc.is_sealed() and bar.is_sealed(), "apply_seal locks target towers")
	check(not arc.upgrade() and not arc.sell(), "sealed tower blocks upgrade and sell")
	bar.troops[0]._physics_process(1.0)
	check(is_equal_approx(bar.troops[0].respawn_clock, 8.0), "sealed barracks pauses soldier respawn clock")
	game.selected_site = 2
	game.hud.show_context(2)
	await frames(2)
	var sell_btn := game.hud.context.find_child("SellTower", true, false) as Button
	check(sell_btn != null and sell_btn.disabled, "HUD context disables sell while sealed")
	arc._physics_process(7.6)
	check(not arc.is_sealed(), "tower seal expires cleanly after duration")
	check(arc.sell(), "released tower can sell cleanly")
	await cleanup()

	# 4. Stage 6 Sanctum: dual exits, Starfall Shrine charge & rift suppression, Ruins death skills, Baj'Nimen phases
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.playtest()
	root.add_child(game)
	current_scene = game
	await frames(2)
	game.start_run("lord", "sanctum")
	await frames(2)
	check(ArenaExitGate.pillar_positions(game).size() == 4, "sanctum mounts 2 twin-pillar exit gates (4 pillars)")
	check(game.ground.texture != null and game.ground.texture.get_width() == 1600 and game.ground.texture.get_height() == 900, "sanctum uses 1600x900 pixel map")

	# Rider dismount & Avenger curse blast & Shrine 24-kill beam
	var rider := game.spawn_enemy("avenger_rider", 1, 140.0)
	rider.take_hit(9999.0, 0, "hero")
	var spawned_avenger := game.enemies.any(func(e): return is_instance_valid(e) and e.kind == "twilight_avenger")
	check(spawned_avenger, "avenger_rider dismounts into twilight_avenger upon death")
	var delayed_b := game.delayed.size()
	for e in game.enemies.duplicate():
		if is_instance_valid(e) and e.kind == "twilight_avenger":
			e.take_hit(9999.0, 0, "hero")
	check(game.delayed.size() > delayed_b, "twilight_avenger queues violet curse blast upon death")

	check(not game.stage_gimmicks.trigger_active(), "Starfall Shrine requires full 24-kill charge")
	var swarm := game.spawn_enemy("void_eyeling", 1, 320.0)
	for _k in range(24):
		var fodder := game.spawn_enemy("void_eyeling", 0, 200.0)
		game.stage_gimmicks.on_enemy_killed(fodder)
		game.remove_enemy(fodder)
	check(game.stage_gimmicks.shrine_charge == ArenaStageGimmicks.SHRINE_MAX_CHARGE, "shrine reaches 24/24 charge")
	var hp_before := swarm.health
	check(game.stage_gimmicks.trigger_active(), "charged Starfall Shrine fires [G] beam cleanly")
	check(swarm.health < hp_before and game.stage_gimmicks.is_rift_suppressed(), "Starfall beam damages enemies and suppresses central Void Rift")

	var baj := game.spawn_enemy("baj_nimen", 1, 180.0)
	baj.take_hit(baj.max_health * 0.48, 1, "hero")
	check(baj.boss_phase == 1 and baj.barrier_shield > 100.0, "baj_nimen enters phase 2 with starfall shield")
	baj.barrier_shield = 0.0
	baj.take_hit(baj.max_health * 0.55, 1, "hero")
	check(baj.boss_phase == 2, "baj_nimen enters phase 3 rift overload")

	await cleanup()
	print("V029 CHAPTERS AND LEGIONS CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)
