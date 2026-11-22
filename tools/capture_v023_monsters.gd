extends SceneTree
var out_dir := ProjectSettings.globalize_path("res://test-results/v023-showcase")
var game: ArenaGame

func _initialize() -> void:
	if DirAccess.make_dir_recursive_absolute(out_dir) != OK:
		push_error("Invalid showcase output directory: " + out_dir)
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
	if img.save_png(path) != OK:
		push_error("Could not save showcase frame: " + path)
		quit(1)
		return
	print("SAVED: ", path)

func cleanup() -> void:
	if is_instance_valid(game):
		game.running = false
		game.audio.shutdown()
		await frames(2)
		OS.delay_msec(120)
		game.queue_free()
		await frames(2)

func setup_battle(hero_id: String, stage: String) -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	for id in ArenaDefinitions.HERO_IDS:
		game.campaign.data.levels[id] = 5
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.start_run(hero_id, stage)
	await frames(3)

func run() -> void:
	# 1. Stage 2 Select Panel (10 Waves + crisp Beast portraits)
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.hud.frontend.levels()
	await frames(2)
	game.hud.frontend.prepare("creek")
	await frames(4)
	await snap("stage2_select.png")
	await cleanup()

	# 2. Stage 1 Combat: Viper sniper laser, Turtle Shaman healing, Bear Vanguard slam, Hero debuffs & Space slot
	await setup_battle("lord", "forest")
	game.cycle = 6
	game.phase = "spawn"
	game.gold = 950
	game.build_tower(0, "archer")
	game.build_tower(1, "barracks")
	game.build_tower(3, "mage")
	var road := game.routes[0]
	game.hero.position = road.sample_baked(560.0, true) + Vector2(36, 44)
	game.hero.apply_debuff("poison", 4.0, 6.0)
	game.hero.apply_debuff("slow", 3.0, 0.28)
	var bear := game.spawn_enemy("bear_vanguard", 0, 560.0, true)
	var tusk := game.spawn_enemy("tusk_fighter", 0, 510.0)
	tusk.health = tusk.max_health * 0.55
	var pig := game.spawn_enemy("pigsoldier", 0, 480.0)
	pig.health = pig.max_health * 0.5
	var shaman := game.spawn_enemy("turtle_shaman", 0, 440.0)
	shaman.ability_clock = 0.0
	var viper := game.spawn_enemy("dreadeye_viper", 0, 390.0)
	viper.ranged_clock = 0.0
	var hyena := game.spawn_enemy("rottooth_hyena", 0, 460.0)
	hyena.health = hyena.max_health * 0.6
	await create_timer(0.32).timeout
	bear.ability_clock = 0.0
	await create_timer(0.18).timeout
	await snap("stage1_combat.png")
	await cleanup()

	# 3. Stage 2 Combat: Flying Scout Vulture, Skunk Toxic Cloud jamming tower, Throat Cutter, Enraged Bear Woodsman
	await setup_battle("gunner", "creek")
	game.cycle = 5
	game.phase = "spawn"
	game.gold = 1200
	game.build_tower(1, "archer")
	game.build_tower(2, "mage")
	game.build_tower(3, "cannon")
	var creek_r := game.routes[0]
	game.hero.position = creek_r.sample_baked(680.0, true) + Vector2(20, 62)
	game.spawn_enemy("scout_vulture", 0, 560.0)
	game.spawn_enemy("scout_vulture", 0, 620.0)
	game.spawn_enemy("throat_cutter", 0, 650.0)
	var woodsman := game.spawn_enemy("bear_woodsman", 0, 520.0)
	woodsman.health = woodsman.max_health * 0.45
	woodsman.enraged = true
	var skunk := game.spawn_enemy("skunk_bombardier", 0, 460.0)
	skunk.ranged_clock = 0.0
	# Place a live toxic cloud over site 1 archer tower to show jamming FX
	var archer_t := game.site_tower(1)
	game.add_zone(archer_t.position, 92.0, 7.0, 4.8, 1, "enemy", "toxic_cloud")
	archer_t.apply_jam(2.5, 0.35)
	await create_timer(0.35).timeout
	await snap("stage2_air_and_smog.png")
	await cleanup()

	# 4. Stage 2 Wave 6 Mini-Boss: Darksteel Boss Charge Telegraph + Top BossBar
	await setup_battle("druid", "creek")
	game.cycle = 6
	game.phase = "spawn"
	game.gold = 1500
	game.build_tower(0, "archer")
	game.build_tower(2, "cannon")
	var boss_r := game.routes[0]
	game.hero.position = boss_r.sample_baked(680.0, true) + Vector2(0, 65)
	var dboss := game.spawn_enemy("darksteel_boss", 0, 520.0)
	dboss.health = dboss.max_health * 0.72
	dboss.ability_clock = 0.0
	game.spawn_enemy("tusk_fighter", 0, 450.0)
	game.spawn_enemy("skunk_bombardier", 0, 410.0)
	await create_timer(0.55).timeout
	dboss.hurt_time = 0.0
	await snap("stage2_miniboss.png")
	await cleanup()

	# 5. Stage 2 Wave 10 Final Boss: Two-Headed Troll Phase 2/3 Roar + Triple Slam + BossBar
	await setup_battle("werewolf", "creek")
	game.cycle = 10
	game.phase = "spawn"
	game.gold = 2200
	game.build_tower(1, "archer")
	game.build_tower(2, "mage")
	game.build_tower(3, "cannon")
	game.build_tower(4, "barracks")
	var troll_r := game.routes[0]
	game.hero.position = troll_r.sample_baked(760.0, true) + Vector2(-45, 55)
	var troll := game.spawn_enemy("two_headed_troll", 0, 610.0)
	troll.health = troll.max_health * 0.30
	troll.slam_clock = 0.0
	troll.take_hit(10.0, 1, "hero")
	await create_timer(0.95).timeout
	troll.hurt_time = 0.0
	await snap("stage2_boss_troll.png")
	await cleanup()

	quit(0)
