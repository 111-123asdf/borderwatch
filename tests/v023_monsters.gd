extends SceneTree
# Focused suite for v0.23 Beast Legion monsters, universal Space short dodge,
# hero debuffs, strict anti-air, toxic tower jamming, 10-wave creek, and dual bosses.
var checks := 0
var failures := 0
var game: ArenaGame

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V023 FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func frames(count := 2) -> void:
	for _i in range(count):
		await process_frame

func cleanup() -> void:
	paused = false
	if is_instance_valid(game):
		game.choice_queue = 0
		game.choice_open = false
		game.running = false
		game.audio.shutdown()
		await frames(2)
		OS.delay_msec(120)
		game.queue_free()
		await frames(2)

func run() -> void:
	await test_assets()
	await test_dodge_and_debuffs()
	await test_anti_air_and_tower_jam()
	await test_monster_abilities_and_bosses()
	await test_stage_waves_and_settlement()
	print("V023 MONSTER CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func test_assets() -> void:
	var beasts := [
		"pigsoldier", "rottooth_hyena", "tusk_fighter", "dreadeye_viper",
		"turtle_shaman", "bear_vanguard", "throat_cutter", "scout_vulture",
		"skunk_bombardier", "bear_woodsman", "darksteel_guard", "two_headed_troll"
	]
	for k in beasts:
		var c := ArenaCreature.new()
		root.add_child(c)
		c.configure(k, 60.0)
		check(c.is_pixel_v023, "v023 sheet loaded for " + k)
		for anim in ["walk", "attack", "down"]:
			check(c.sprite_frames.has_animation(anim) and c.sprite_frames.get_frame_count(anim) == 6, "6 frames in " + k + " " + anim)
		if k in ["darksteel_guard", "two_headed_troll"]:
			check(c.sprite_frames.has_animation("skill") and c.sprite_frames.get_frame_count("skill") == 6, "4-row skill sheet for " + k)
		var portrait := ArenaMenuArt.creature(k)
		check(portrait != null and not portrait.get_image().is_invisible(), "v023 portrait nonempty for " + k)
		c.queue_free()
	await frames(2)

func test_dodge_and_debuffs() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	await frames(3)
	game.start_run("lord", "forest")
	var h := game.hero
	h.cooldowns = [0.0, 0.0]
	var start_pos := h.position
	check(h.try_dodge(Vector2.RIGHT), "lord can use universal Space dodge")
	check(h.dodge_cooldown > 4.0, "dodge sets independent cooldown")
	check(h.cooldowns[0] == 0.0 and h.cooldowns[1] == 0.0, "dodge never spends Q/E skill cooldowns")
	check(h.protection > 0.15, "dodge grants brief invulnerability frames")
	check(not h.apply_debuff("poison", 3.0, 6.0), "dodge i-frames block incoming debuffs")
	for _i in range(12):
		await physics_frame
	var moved := start_pos.distance_to(h.position)
	check(moved >= 42.0 and moved <= 78.0, "dodge performs a short ~59px sidestep (got %.1f)" % moved)
	check(not h.try_dodge(Vector2.RIGHT), "dodge cannot be spammed during cooldown")
	# Wait out i-frames & test slow, poison, bleed, stun + immunity + clear on KO
	h.protection = 0.0
	var base_hp := h.health
	check(h.apply_debuff("slow", 2.0, 0.40), "slow debuff applies cleanly")
	check(h.apply_debuff("poison", 2.0, 10.0), "poison debuff applies cleanly")
	check(h.apply_debuff("bleed", 2.0, 8.0), "bleed debuff applies cleanly")
	check(h.active_debuffs().size() == 3, "hero reports 3 active debuffs to HUD")
	for _i in range(40):
		h._physics_process(0.016)
	check(h.health < base_hp - 5.0, "poison and bleed deal DoT over time")
	check(h.apply_debuff("stun", 0.6, 0.0), "stun applies cleanly")
	check(not h.apply_debuff("stun", 0.6, 0.0), "stun immunity prevents chain stun")
	h.debuff_stun_clock = 0.0
	h.take_hit(99999.0, 0, true)
	check(h.knocked_out and h.active_debuffs().is_empty(), "KO clears active debuffs")
	# Verify Gunner dodge does not grant Q empower_shot
	h.knocked_out = false
	h.revive_clock = 0.0
	h.configure("gunner")
	h.protection = 0.0
	h.dodge_cooldown = 0.0
	check(h.try_dodge(Vector2.LEFT) and h.empower_shot == 0, "universal Space dodge does not grant gunner Q empower")
	await cleanup()

func test_anti_air_and_tower_jam() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	await frames(3)
	game.start_run("lord", "creek")
	game.gold = 2000
	check(game.build_tower(0, "cannon"), "build cannon on site 0")
	check(game.build_tower(1, "archer"), "build archer on site 1")
	check(game.build_tower(2, "mage"), "build mage on site 2")
	var cannon: ArenaTower = game.site_tower(0)
	var archer: ArenaTower = game.site_tower(1)
	var mage: ArenaTower = game.site_tower(2)
	var vulture := game.spawn_enemy("scout_vulture", 0, 220.0)
	vulture.position = cannon.position + Vector2(30, 0)
	game.hero.position = vulture.position + Vector2(18, 0)
	game.hero.velocity = Vector2.ZERO
	game.blocking.update()
	check(vulture.is_flying() and vulture.blocker == null, "flying vulture ignores ground blocking")
	check(game.tower_target(cannon) == null, "cannon tower ignores flying vulture")
	archer.position = vulture.position + Vector2(40, 0)
	mage.position = vulture.position + Vector2(-40, 0)
	check(game.tower_target(archer) == vulture and game.tower_target(mage) == vulture, "archer and mage target flying vulture")
	check(game.hero.select_attack_target(vulture.center()) == null, "melee hero lord cannot target flying vulture with primary")
	var v_hp := vulture.health
	game.area_damage(vulture.position, 120.0, 50.0, 0, "tower", 0.0, 0.0, 0.0, 0.0, "shell")
	check(is_equal_approx(vulture.health, v_hp), "cannon shell splash misses flying vulture")
	game.hero.configure("gunner")
	game.hero.position = vulture.position + Vector2(80, 0)
	check(game.hero.select_attack_target(vulture.center()) == vulture, "ranged hero gunner targets flying vulture")
	# Toxic zone jams tower without giving tower any HP property
	var base_reload := archer.reload_time()
	game.add_zone(archer.position, 92.0, 7.0, 3.0, 1, "enemy", "toxic_cloud")
	game._physics_process(0.26)
	check(archer.jam_clock > 0.0 and archer.reload_time() > base_reload * 1.35, "toxic cloud jams nearby tower reload speed")
	var has_hp := false
	for p in archer.get_property_list():
		if p.name in ["health", "max_health"]:
			has_hp = true
	check(not has_hp, "jammed tower still has no health property")
	await cleanup()

func test_monster_abilities_and_bosses() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	await frames(3)
	game.start_run("lord", "creek")
	game.gold = 1000
	game.build_tower(0, "barracks")
	var s: ArenaSoldier = game.soldiers[0]
	# 1. Throat Cutter shadow-step bypasses first soldier once
	var rat := game.spawn_enemy("throat_cutter", 0, 120.0)
	rat.position = s.position + Vector2(12, 0)
	var rat_prog_before := rat.progress
	game.blocking.update()
	check(rat.dash_used and rat.progress > rat_prog_before + 40.0 and rat.blocker == null, "throat_cutter shadow-steps past first soldier")
	# 2. Turtle Shaman heals injured ally and clears slow
	var pig := game.spawn_enemy("pigsoldier", 0, 200.0)
	pig.health = pig.max_health * 0.5
	pig.slow = 2.0
	var shaman := game.spawn_enemy("turtle_shaman", 0, 190.0)
	shaman.position = pig.position + Vector2(-20, 0)
	shaman.ability_clock = 0.0
	shaman._physics_process(0.02)
	check(shaman.ability_kind == "heal" and shaman.ability_windup > 0.0, "turtle shaman begins healing chant")
	for _i in range(42):
		shaman._physics_process(0.02)
	check(pig.health > pig.max_health * 0.60 and pig.slow == 0.0, "turtle shaman heals ally and cleanses slow")
	# 3. Bear Woodsman enrages below 65% HP
	var woodsman := game.spawn_enemy("bear_woodsman", 0, 250.0)
	check(not woodsman.enraged, "bear woodsman starts calm")
	woodsman.take_hit(woodsman.max_health * 0.45 / (1.0 - float(woodsman.data.armour)), 0, "hero")
	check(woodsman.enraged and woodsman.speed_scale() >= 1.35, "bear woodsman enrages below 65% HP")
	# 4. Viper sniper lock + poison arrow
	var viper := game.spawn_enemy("dreadeye_viper", 0, 300.0)
	viper.ranged_clock = 0.0
	game.hero.position = viper.position + Vector2(180, 0)
	game.hero.protection = 0.0
	viper._physics_process(0.02)
	check(viper.windup > 0.60 and not viper.aim_locked, "viper begins laser lock tracking")
	for _i in range(32):
		viper._physics_process(0.02)
	check(viper.aim_locked or get_nodes_in_group("hostile_projectile").size() > 0, "viper locks aim before firing")
	# 5. Darksteel Boss & BossBar + Two-Headed Troll multi-phase
	var dboss := game.spawn_enemy("darksteel_boss", 0, 340.0)
	check(dboss.is_mini_boss() and game.active_boss() == dboss, "darksteel_boss registers as active mini-boss")
	game.hud.update_clock = 0.0
	game.hud._process(0.1)
	check(game.hud.boss_bar_panel.visible and game.hud.boss_title.text.contains("暗钢守卫统领"), "HUD shows BossBar for mini-boss")
	var troll := game.spawn_enemy("two_headed_troll", 0, 400.0)
	check(troll.is_boss() and game.active_boss() == troll, "two_headed_troll takes BossBar priority")
	var count_before := game.enemies.size()
	troll.take_hit(troll.max_health * 0.55 / (1.0 - float(troll.data.armour)), 0, "hero")
	check(troll.boss_phase >= 1 and game.enemies.size() > count_before + 4, "two_headed_troll P2 roars and summons beast pack")
	await cleanup()

func test_stage_waves_and_settlement() -> void:
	check(ArenaLevelCatalog.total_waves("forest") == 8, "stage 1 has 8 waves")
	check(ArenaLevelCatalog.total_waves("creek") == 10, "stage 2 has 10 waves")
	check(not bool(ArenaLevelCatalog.definition("forest").boss), "stage 1 has no big boss")
	check(bool(ArenaLevelCatalog.wave_profile("creek", 6).has_mini_boss), "stage 2 wave 6 has darksteel mini-boss")
	check(bool(ArenaLevelCatalog.wave_profile("creek", 10).has_boss), "stage 2 wave 10 has two-headed troll boss")
	check(bool(ArenaLevelCatalog.wave_profile("creek", 2).has_flying), "stage 2 wave 2 warns about flying units")
	var path := "user://v023-settle-" + str(Time.get_ticks_usec()) + ".cfg"
	var camp := ArenaCampaign.new(path, true)
	check(not bool(camp.settle("bad-8", "creek", true, 8).ok), "creek victory rejects 8-wave count")
	var ok10 := camp.settle("ok-10", "creek", true, 10)
	check(bool(ok10.ok) and int(ok10.amount) == 8, "creek victory settles cleanly at 10 waves")
	await frames(1)
