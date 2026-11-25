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
		push_error("V025 FAIL: " + message)

func frames(count := 2) -> void:
	for _i in range(count):
		await process_frame

func deploy(stage := "forest", hero_id := "lord") -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	current_scene = game
	await frames(2)
	game.rng.seed = 42
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
	await test_redesigned_towers_assets()
	await test_tower_projectiles_and_vfx()
	await test_melee_duel_and_perfect_dodge()
	print("V025 COMBAT & VFX CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func test_redesigned_towers_assets() -> void:
	var forms: Dictionary = {
		"storm": ["", "", "fork", "relay", "surge"],
		"lens": ["", "", "focus", "sweep", "far_lens"],
		"snare": ["", "", "net", "barb", "ratchet"],
	}
	for kind in forms:
		var list: Array = forms[kind]
		for idx in range(list.size()):
			var lv := 1 if idx == 0 else (2 if idx == 1 else 3)
			var doc := str(list[idx])
			check(ArenaBattleArt.has_v024_tower(kind, lv, doc), "has v024 strip for %s lv%d %s" % [kind, lv, doc])
			var tex := ArenaBattleArt.tower_frame_texture(kind, lv, doc, 0)
			check(tex != null and not tex.get_image().is_invisible(), "nonempty idle frame for %s lv%d %s" % [kind, lv, doc])
			var entry := ArenaBattleArt.v024_entry(kind, lv, doc)
			check(float(entry.get("world_height", 0.0)) >= 70.0, "manifest world_height set for %s %s" % [kind, doc])
	await frames(1)

func test_tower_projectiles_and_vfx() -> void:
	await deploy("forest", "lord")
	game.gold = 4000
	game.cycle = 6
	check(game.build_tower(0, "archer"), "build archer")
	check(game.build_tower(1, "mage"), "build mage")
	var archer: ArenaTower = game.site_tower(0)
	var mage: ArenaTower = game.site_tower(1)
	archer.finish_project()
	mage.finish_project()
	var foe := game.spawn_enemy("brute", 0, 260.0)
	foe.stun = 100.0
	foe.health = 900.0
	foe.position = archer.position + Vector2(180.0, 10.0)

	# Normal defense_rules archer does crisp windup and fires parabolic tracking arrow (not trial line)
	archer.attack_clock = 0.0
	archer._physics_process(0.02)
	check(archer.timing.is_preparing() and archer.timing.prep_duration <= 0.20, "normal archer windup is crisp (<= 0.20s)")
	archer._physics_process(0.30)
	var arrows := game.actors.get_children().filter(func(n): return n is ArenaProjectile and n.feedback_tag == "tower_arrow")
	check(not arrows.is_empty(), "archer fires tower_arrow projectile")
	if not arrows.is_empty():
		var arr := arrows.back() as ArenaProjectile
		check(arr.trial_pierce_scales.is_empty() and arr.arc_height > 15.0, "normal archer uses parabolic tracking arc")
		arr._physics_process(0.10)
		check(arr.visual_offset.y < -2.0, "parabolic arrow lifts mid-flight")
		arr.queue_free()

	# Piercer L3 fires low-arc piercing heavy bolt
	check(archer.upgrade() and archer.project_level == 2, "archer queue L2")
	archer.finish_project()
	check(archer.upgrade("piercer") and archer.project_level == 3, "archer queue L3 piercer")
	archer.finish_project()
	check(archer.doctrine_id == "piercer", "archer doctrine applied")
	archer.fire_shots(foe, 40.0)
	var p_arrows := game.actors.get_children().filter(func(n): return n is ArenaProjectile and n.doctrine_id == "piercer")
	if not p_arrows.is_empty():
		var pb := p_arrows.back() as ArenaProjectile
		check(pb.pierce >= 2 and pb.arc_height > 5.0, "piercer fires low-arc piercing heavy bolt")
	else:
		check(false, "piercer fires low-arc piercing heavy bolt")
	for p in p_arrows: p.queue_free()

	# Normal defense_rules mage (lv1 & frost & arcfire) fires spell orbs instead of trial pulse
	mage.fire_shots(foe, 30.0)
	var spells := game.actors.get_children().filter(func(n): return n is ArenaProjectile and n.feedback_tag == "tower_spell")
	check(not spells.is_empty() and (spells.back() as ArenaProjectile).arc_height > 5.0, "mage fires pixel spell projectile in normal game")
	for s in spells: s.queue_free()
	mage.upgrade(); mage.finish_project()
	mage.upgrade("frost"); mage.finish_project()
	mage.attack_clock = 0.0
	mage.timing.phase = mage.AttackTiming.Phase.IDLE
	mage._fire_at(foe)
	var f_spells := game.actors.get_children().filter(func(n): return n is ArenaProjectile and n.feedback_tag == "tower_spell" and n.doctrine_id == "frost")
	check(not f_spells.is_empty(), "frost mage fires frost bolt instead of giant pulse")
	for s in f_spells: s.queue_free()
	await cleanup()

func test_melee_duel_and_perfect_dodge() -> void:
	await deploy("forest", "lord")
	var h: ArenaHero = game.hero
	h.position = Vector2(540.0, 410.0)
	h.facing = Vector2.RIGHT

	# 1. Light vs Heavy windup grading & soldier fast swing preserved
	var pig := game.spawn_enemy("pigsoldier", 0, 200.0)
	pig.position = h.position + Vector2(36.0, 0.0)
	pig.melee_clock = 0.0
	pig.melee(h)
	check(pig.melee_windup >= 0.50 and pig.melee_windup <= 0.62, "light monster vs hero has readable windup (~0.54s)")
	pig.melee_windup = 0.0; pig.melee_target = null

	var van := game.spawn_enemy("bear_vanguard", 0, 210.0)
	van.position = h.position + Vector2(-42.0, 0.0)
	van.melee_clock = 0.0
	van.melee(h)
	check(van.melee_windup >= 0.70, "heavy monster vs hero has long windup (~0.74s)")

	game.gold = 500
	game.build_tower(2, "barracks")
	var camp: ArenaTower = game.site_tower(2)
	camp.finish_project()
	var sol: ArenaSoldier = camp.troops[0]
	var pig_s := game.spawn_enemy("pigsoldier", 0, 220.0)
	pig_s.position = sol.position + Vector2(20.0, 0.0)
	pig_s.melee_clock = 0.0
	pig_s.melee(sol)
	check(pig_s.melee_windup <= 0.31, "monster vs barracks soldier keeps fast 0.30s swing")

	# 2. Crowd melee stagger cap (max 1 when heavy active; max 2 when only light monsters)
	var extra1 := game.spawn_enemy("pigsoldier", 0, 205.0)
	var extra2 := game.spawn_enemy("pigsoldier", 0, 206.0)
	extra1.position = h.position + Vector2(0.0, 34.0)
	extra2.position = h.position + Vector2(0.0, -34.0)
	extra1.melee_clock = 0.0; extra2.melee_clock = 0.0
	extra1.melee(h)
	var active_with_heavy := game.enemies.filter(func(e): return is_instance_valid(e) and e.melee_target == h and e.melee_windup > 0.0).size()
	check(active_with_heavy == 1 and extra1.melee_windup == 0.0, "crowd melee throttle caps simultaneous hero attackers to 1 when heavy active")
	van.melee_windup = 0.0; van.melee_target = null
	pig.melee_clock = 0.0; extra1.melee_clock = 0.0; extra2.melee_clock = 0.0
	pig.melee(h); extra1.melee(h); extra2.melee(h)
	var active_lights := game.enemies.filter(func(e): return is_instance_valid(e) and e.melee_target == h and e.melee_windup > 0.0).size()
	check(active_lights == 2 and extra2.melee_windup == 0.0, "crowd melee throttle caps simultaneous light attackers to 2")

	# Clear extra enemies for clean 1v1 directional + perfect dodge checks
	for e in game.enemies.duplicate():
		game.remove_enemy(e)
	h.health = h.max_health
	h.protection = 0.0

	# 3. Directional cone miss: walk behind monster during windup -> 0 damage + recovery
	var attacker := game.spawn_enemy("brute", 0, 240.0)
	attacker.position = Vector2(500.0, 410.0)
	h.position = attacker.position + Vector2(40.0, 0.0)
	attacker.melee_clock = 0.0
	attacker.melee(h)
	check(attacker.melee_dir.x > 0.8 and attacker.melee_windup > 0.65, "attacker locks frontal melee direction")
	# Hero dashes/walks around behind the monster before strike resolves
	h.position = attacker.position + Vector2(-34.0, 0.0)
	var hp_before := h.health
	attacker.melee_windup = 0.02
	attacker._physics_process(0.03)
	check(is_equal_approx(h.health, hp_before) and attacker.melee_recovery > 0.20, "moving behind locked melee cone avoids all damage and exposes whiff recovery")

	# Front hit verification
	attacker.melee_recovery = 0.0
	attacker.melee_clock = 0.0
	h.position = attacker.position + Vector2(36.0, 0.0)
	attacker.melee(h)
	attacker.melee_windup = 0.02
	attacker._physics_process(0.03)
	check(h.health < hp_before, "staying inside frontal melee cone deals damage as expected")

	# 4. Whiff Space sets full 4.5s cooldown without counter buff
	h.health = h.max_health
	h.dodge_cooldown = 0.0; h.dodge_left = 0.0; h.protection = 0.0
	h.counter_ready_clock = 0.0
	check(h.try_dodge(Vector2.DOWN), "whiff Space dodge succeeds")
	check(h.dodge_cooldown > 4.0 and h.counter_ready_clock == 0.0, "empty Space dodge keeps long cooldown (>4.0s) and grants no counter")

	# 5. Perfect Dodge vs Melee + 1.6x crit counter stagger interrupt
	h.dodge_cooldown = 0.0; h.dodge_left = 0.0; h.protection = 0.0
	attacker.melee_recovery = 0.0; attacker.melee_clock = 0.0
	h.position = attacker.position + Vector2(38.0, 0.0)
	attacker.melee(h)
	attacker.melee_windup = 0.16 # inside 0.22s~0.26s perfect dodge window
	var hp_pd := h.health
	check(h.try_dodge(Vector2.UP), "timed Space dodge triggers against imminent melee")
	check(h.perfect_dodge_triggered and h.dodge_cooldown <= 1.50 and h.counter_ready_clock > 3.0, "perfect dodge refunds ~70% cooldown and arms counter crit")
	attacker.melee_windup = 0.02
	attacker._physics_process(0.03)
	check(is_equal_approx(h.health, hp_pd), "perfect dodge avoids melee damage cleanly")

	# Next basic attack deals ~1.6x damage and interrupts another enemy's windup
	var shaman := game.spawn_enemy("turtle_shaman", 0, 260.0)
	shaman.position = h.position + Vector2(44.0, 0.0)
	shaman.ability_kind = "heal"; shaman.ability_windup = 0.50
	var s_hp := shaman.health
	h.facing = Vector2.RIGHT
	h.cancel_action(); h.attack_cooldown = 0.0
	h.begin_attack(shaman)
	h.release_action()
	var dealt := s_hp - shaman.health
	var expected_base := ArenaCombat.resolve(h.attack_damage(), 0, float(shaman.data.armour), float(shaman.data.resistance))
	check(dealt > expected_base * 1.45 and shaman.stun >= 0.30 and shaman.ability_windup == 0.0, "counter crit deals ~1.6x damage and staggers/interrupts shaman cast (dealt=%.1f vs base=%.1f)" % [dealt, expected_base])

	# 6. Perfect Dodge vs Enemy Projectile
	h.dodge_cooldown = 0.0; h.dodge_left = 0.0; h.protection = 0.0; h.perfect_dodge_window = 0.0; h.perfect_dodge_triggered = false
	var arrow := game.fire_projectile(h.center() + Vector2(-42.0, 0.0), h.center() + Vector2(60.0, 0.0), 30.0, 0, "enemy", {"speed": 420.0, "appearance": "viper_arrow"})
	var hp_proj := h.health
	h.try_dodge(Vector2.DOWN)
	check(h.perfect_dodge_triggered and h.dodge_cooldown <= 1.50, "perfect dodge triggers against incoming enemy projectile")
	arrow._physics_process(0.05)
	check(is_equal_approx(h.health, hp_proj), "dodged projectile deals zero damage")

	# 7. Perfect Dodge vs Delayed Ground Slam
	h.dodge_cooldown = 0.0; h.dodge_left = 0.0; h.protection = 0.0; h.perfect_dodge_window = 0.0; h.perfect_dodge_triggered = false
	h.position = Vector2(560.0, 410.0)
	game.delayed_attack(h.position, 88.0, 45.0, 0, "enemy", 0.14, {"telegraph": "bear_slam"})
	var hp_slam := h.health
	h.try_dodge(Vector2.RIGHT)
	check(h.perfect_dodge_triggered and h.dodge_cooldown <= 1.50, "perfect dodge triggers against imminent delayed AoE slam")
	game._physics_process(0.16)
	check(is_equal_approx(h.health, hp_slam), "perfect dodge i-frame avoids delayed slam damage cleanly")

	await cleanup()
