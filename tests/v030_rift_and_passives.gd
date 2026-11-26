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
		push_error("V030 FAIL: " + message)


func frames(count := 2) -> void:
	for _i in range(count):
		await process_frame


func cleanup() -> void:
	paused = false
	if is_instance_valid(game):
		game.running = false
		game.audio.shutdown()
		await frames(2)
		OS.delay_msec(100)
		game.queue_free()
		await frames(2)
	game = null


func run() -> void:
	test_purges_and_v032_assets()
	test_pcg_topology_and_strict_doors()
	test_event_bus_and_keybinds()
	await test_unified_6_stages_and_auto_towers()
	await test_dual_domain_pcg_barrels_events_relics_and_callwave()
	await test_recall_resume_and_compass()
	await test_deeper_room_phases_and_cover()
	await test_new_passive_damage_paths()
	await test_hud_matches_runtime()
	await test_five_heroes_swarm_adaptation()
	print("V030 RIFT & PASSIVES CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func test_purges_and_v032_assets() -> void:
	for fname in ["arena_rule_deck.gd", "arena_defense_orders.gd"]:
		check(not FileAccess.file_exists("res://scripts/arena/" + fname), "obsolete v028 file removed: " + fname)
	for art: String in ["rift_wilds", "rift_abyss", "rift_void", "portal_rift", "portal_return", "chest_bounty", "xp_cyan", "xp_violet", "xp_magnet"]:
		var path := "res://assets/rift_v030/" + art + ".png"
		var tex := load(path) as Texture2D
		check(tex != null and not tex.get_image().is_invisible(), "v030 rift asset loads: " + art)
	check(ArenaMenuArt.v030("card_evo_gold") != null, "golden evo frame loads")
	check(ArenaPassiveEngine.PASSIVES.size() == 29 and ArenaPassiveEngine.MAX_TOTAL_PICKS == 16 and ArenaPassiveEngine.MAX_RUN_LEVEL == 17, "29 passives and one choice per level up to 16 choices")
	for pid in ArenaPassiveEngine.ORDER:
		var medal := ArenaMenuArt.passive_medal(pid)
		check(medal != null and not medal.get_image().is_invisible(), "passive medal valid: " + pid)
	for rid in ArenaRelicEngine.ORDER:
		var rmedal := ArenaMenuArt.relic_medal(rid)
		check(rmedal != null and not rmedal.get_image().is_invisible(), "v032 relic medal valid: " + rid)
	for bkey in ["wilds", "abyss", "void"]:
		for tname in ["tiles_%s_floor" % bkey, "tiles_%s_wall" % bkey, "tiles_%s_corridor" % bkey, "prop_pillar_%s" % bkey]:
			var mtex := load("res://assets/rift_v032/" + tname + ".png") as Texture2D
			check(mtex != null and not mtex.get_image().is_invisible(), "v032 modular asset loads: " + tname)
	for pname in ["prop_barrel_crystal", "prop_altar_blood", "prop_anvil_forge", "prop_pedestal_choice", "prop_descent_gate"]:
		var ptex := load("res://assets/rift_v032/" + pname + ".png") as Texture2D
		check(ptex != null and not ptex.get_image().is_invisible(), "v032 prop loads: " + pname)
	for vfx31: String in ["vfx_portal_warp", "vfx_blade_cyan", "vfx_blade_gold", "vfx_meteor_comet", "vfx_frost_spikes", "vfx_blackhole_void", "vfx_orbital_beam"]:
		var vtex := load("res://assets/vfx_v031/" + vfx31 + ".png") as Texture2D
		check(vtex != null and not vtex.get_image().is_invisible(), "v031 VFX sheet loads: " + vfx31)
	for sid in ["saltport", "lighthouse", "ruins", "sanctum"]:
		var sdef := ArenaLevelCatalog.definition(sid)
		var traits: Array = sdef.get("site_traits", [])
		var non_empty := 0
		for t in traits:
			if str(t) != "":
				non_empty += 1
		check(non_empty <= 2, "%s site_traits simplified to <= 2 landmarks (got %d)" % [sid, non_empty])


func test_pcg_topology_and_strict_doors() -> void:
	var g1 := ArenaRiftPCG.generate_floor(101, "forest", "wilds", 1, ArenaRiftDomain.RIFT_ORIGIN)
	var g2 := ArenaRiftPCG.generate_floor(909, "saltport", "abyss", 1, ArenaRiftDomain.RIFT_ORIGIN)
	var keys1: Array[String] = g1.room_order.duplicate()
	var keys2: Array[String] = g2.room_order.duplicate()
	keys1.sort()
	keys2.sort()
	check(g1.rooms.size() >= 9 and g1.rooms.size() <= 12, "PCG floor generates 9..12 rooms")
	check(keys1 != keys2, "different seeds generate distinct irregular Rift topologies")
	check(str(g1.boss_room_id) != "" and str(g1.miniboss_room_id) != "" and str(g1.event_room_id) != "", "PCG floor places Boss, MiniBoss, and Event rooms")

	# Verify BFS connectivity & strict doors == neighbor directions (zero fake doors!)
	var visited := {"hub": true}
	var q: Array[String] = ["hub"]
	while not q.is_empty():
		var cid: String = q.pop_front()
		var rm: Dictionary = g1.rooms[cid]
		var nbs: Array = rm.neighbors
		var doors: Array = rm.doors
		check(nbs.size() == doors.size(), "room %s doors match exact neighbor count (%d == %d)" % [cid, doors.size(), nbs.size()])
		for nb: String in nbs:
			if not visited.has(nb):
				visited[nb] = true
				q.append(nb)
	check(visited.size() == g1.rooms.size(), "all generated PCG rooms are reachable from hub")
	for stage: String in ["forest","saltport","ruins"]:
		var theme: String = {"forest":"wilds","saltport":"abyss","ruins":"void"}[stage]
		var versions := {}
		for seed in range(1,49):
			for layer in [1,3]:
				var floor_data := ArenaRiftPCG.generate_floor(seed,stage,theme,layer,ArenaRiftDomain.RIFT_ORIGIN)
				var rooms: Dictionary = floor_data.rooms
				var boss: Dictionary = rooms[floor_data.boss_room_id]
				var main := rooms.values().filter(func(room): return room.main_route)
				var branch: Array = rooms.hub.neighbors
				var early_fork: bool = branch.size() >= 2 or rooms[branch[0]].neighbors.size() >= 3
				var optional_off_route := main.all(func(room): return room.kind not in ["miniboss","chest","event"])
				var depth := main.size()-1
				check(early_fork and floor_data.corridors.size() >= rooms.size() and boss.neighbors.size() == 1 and depth >= 4 and depth <= 6 and optional_off_route,"%s seed %d layer %d has a main route, early branch and optional rewards" % [stage,seed,layer])
				check(floor_data.corridors.all(func(link): return Rect2(link.vis_rect).size.x >= 128.0 and Rect2(link.vis_rect).size.y >= 128.0),"corridors have clear space between adjacent room walls")
				var ids: Array = rooms.keys()
				ids.sort()
				versions[str(ids)] = true
		check(versions.size() >= 35,"%s generator keeps a variety of whole-floor footprints" % stage)


func test_event_bus_and_keybinds() -> void:
	var bus := ArenaEventBus.new()
	var seen := []
	bus.subscribe("test_evt", func(p): seen.append(int(p.get("val", 0))))
	bus.emit_event("test_evt", {"val": 42})
	check(seen.size() == 1 and seen[0] == 42, "EventBus Observer dispatches typed payloads")
	bus.clear()
	bus.emit_event("test_evt", {"val": 99})
	check(seen.size() == 1, "EventBus clear detaches subscribers")

	var camp := ArenaCampaign.new("", false)
	check(camp.keybind("dodge") == KEY_V and camp.keybind("recall") == KEY_R and camp.keybind("portal") == KEY_T, "default keybinds use V / R / T")
	check(camp.set_keybind("dodge", KEY_F) and camp.keybind("dodge") == KEY_F, "set_keybind updates custom dodge key")


func test_unified_6_stages_and_auto_towers() -> void:
	var expected_biomes := {
		"forest": "wilds", "creek": "wilds",
		"saltport": "abyss", "lighthouse": "abyss",
		"ruins": "void", "sanctum": "void"
	}
	for sid in ArenaLevelCatalog.IDS:
		game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
		game.campaign = ArenaCampaign.new("", false)
		root.add_child(game)
		current_scene = game
		await frames(2)
		game.start_run("lord", sid)
		await frames(2)
		check(game.total_waves() == 5, "%s unified to 5 rounds (got %d)" % [sid, game.total_waves()])
		check(game.rift_domain != null and game.rift_domain.theme_key == expected_biomes[sid], "%s uses %s rift biome" % [sid, expected_biomes[sid]])
		if sid == "forest":
			check(game.passive_offers.size() == 0, "forest starts seamlessly without forced opening rule modal")
			check(game.build_tower(0, "barracks"), "build automated barracks")
			var bar := game.site_tower(0)
			bar._physics_process(ArenaTowerTrial.BUILD_TIME + 0.05)
			game.hud.show_context(0)
			check(game.hud.context.find_child("Upgrade", true, false) == null, "formal upgrades do not require a click")
			var gold_before := game.gold
			var price := bar.upgrade_price()
			check(bar.upgrade(), "start the tier two project")
			bar.finish_project()
			check(bar.level == 2 and game.gold == gold_before - price, "upgrading to tier two charges the listed price")
			game.gold = bar.upgrade_price()
			check(bar.upgrade(), "start the tier three project")
			bar.finish_project()
			check(bar.level == 3 and game.gold == 0, "upgrading to tier three charges the listed price")
			check(bar.doctrine_id == "shield" and bar.enhancements().size() == 3, "barracks gains its automatic doctrine and three enhancements")
		await cleanup()


func test_dual_domain_pcg_barrels_events_relics_and_callwave() -> void:
	game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	game.next_run_seed = 777
	root.add_child(game)
	current_scene = game
	await frames(2)
	game.start_run("gunner", "forest")
	await frames(2)
	check(game.active_domain == "defense", "starts in defense domain")

	# Anytime Call-Wave: rest -> wave 1 -> fast_siege -> stack wave 2!
	var r1 := game.request_next_wave_anytime()
	check(bool(r1.ok) and str(r1.mode) == "rest" and game.phase == "spawn" and game.cycle == 1, "Anytime Call-Wave starts round 1 from rest")
	var previous_queue := game.spawn_queue.duplicate(true)
	var price_before := game.gold
	var r2 := game.request_next_wave_anytime()
	var migrated: Array[float] = []
	var scheduled_matches := true
	for old in previous_queue:
		var current: Dictionary = game.spawn_queue.filter(func(packet): return packet.serial == old.serial)[0]
		if float(old.at) < game.siege_start_at:
			migrated.append(float(current.at))
		else:
			scheduled_matches = scheduled_matches and current.at == old.at
	var sorted := migrated.duplicate()
	sorted.sort()
	check(migrated == sorted and is_equal_approx(migrated.back() - migrated.front(), 10.0) and scheduled_matches, "fast siege spreads old skirmish in order without altering the siege schedule")
	check(r1.bonus == 24 and r2.bonus == 50 and game.gold == price_before + 50, "early wave and fast siege rewards use the new caps")
	check(bool(r2.ok) and str(r2.mode) == "fast_siege" and game.wave_elapsed >= game.siege_start_at - 1.0, "Anytime Call-Wave fast-forwards skirmish to Siege")
	game.spawn_queue.clear()
	var r3 := game.request_next_wave_anytime()
	check(bool(r3.ok) and str(r3.mode) == "stack_next" and r3.bonus == 40 and game.cycle == 2 and not game.spawn_queue.is_empty(), "Anytime Call-Wave stacks wave 2 cleanly")

	# Summoned portal warp sequence [T] -> modular PCG dungeon + HUD overlap check!
	game.targeting_slot = 0
	game.rally_site = 1
	game.hero.queued_attack_point = game.hero.position + Vector2(60.0, 0.0)
	check(game.enter_rift() and game.rift_domain.warp_phase == "out", "enter_rift summons animated portal warp")
	for _w in range(10):
		game.rift_domain.tick(0.1)
	await frames(2)
	check(game.active_domain == "rift" and game.hero.domain == "rift", "hero & game transition into rift domain after warp")
	var gold_before_rift_call := game.gold
	check(not game.next_wave_button_state().enabled and not game.request_next_wave_anytime().ok and game.gold == gold_before_rift_call, "the HUD and call-wave action agree that the hero must be in defense")
	check(game.targeting_slot == -1 and game.rally_site == -1 and game.hero.queued_attack_point == Vector2.INF, "portal clears skill, rally, and attack orders from the previous domain")
	check(game.hero.position.x >= ArenaRiftDomain.RIFT_ORIGIN.x, "hero relocated into PCG Rift dungeon")
	check(game.rift_domain.rooms.size() >= 9 and game.rift_domain._fog_layer != null, "PCG multi-room dungeon & fog of war initialized")
	check(str(game.rift_domain.rooms["hub"].state) == "cleared" and game.rift_domain.rift_explore_haste() >= 0.45, "hub cleared gives >= +45% explore haste")
	check(not game.hud.next_wave_btn.visible and not game.hud.wave_label.visible and game.hud.rift_minimap.visible, "Rift HUD hides defense top-right widgets cleanly with zero minimap overlap")

	# Crystal Barrel explosion damages Rift enemies
	var combat_rid := ""
	for rid in game.rift_domain.room_order:
		var rm: Dictionary = game.rift_domain.rooms[rid]
		if str(rm.kind) == "combat" and not (rm.barrels as Array).is_empty():
			combat_rid = rid
			break
	check(combat_rid != "", "PCG dungeon includes combat room with volatile crystal barrels")
	if combat_rid != "":
		var crm: Dictionary = game.rift_domain.rooms[combat_rid]
		var br: Dictionary = crm.barrels[0]
		var b_foe := game.spawn_enemy("pigsoldier", 0, 0.0)
		b_foe.domain = "rift"
		b_foe.is_rift_mob = true
		b_foe.rift_room_id = combat_rid
		b_foe.position = Vector2(br.pos) + Vector2(30.0, 0.0)
		var bhp_pre := b_foe.health
		game.rift_domain.active_combat_room = combat_rid
		var hits := game.rift_domain.damage_barrels_in_radius(Vector2(br.pos), 30.0, 99.0, "rift")
		game.rift_domain.active_combat_room = ""
		check(hits >= 1 and not bool(br.alive) and (b_foe.dead or b_foe.health < bhp_pre), "crystal barrel detonates and damages nearby Rift mob")
		if is_instance_valid(b_foe):
			game.remove_enemy(b_foe)

	# Event Room 3-choice & Relic Engine (6-relic cap + Orbital Beacon on recall)
	var ev_rid := ""
	for rid in game.rift_domain.room_order:
		if str(game.rift_domain.rooms[rid].kind) == "event":
			ev_rid = rid
			break
	check(ev_rid != "" and game.open_rift_event(ev_rid) and not game.active_event_offer.is_empty(), "event room modal opens cleanly")
	check(game.choose_rift_event(0), "choosing event option resolves & closes modal")
	for rel_id in ArenaRelicEngine.ORDER:
		game.relic_engine.grant_relic(rel_id)
	check(game.relic_engine.owned.size() == ArenaRelicEngine.MAX_RELICS, "Relic engine caps cleanly at 6 relics")
	game.relic_engine.grant_relic("orbital_beacon")

	# Multi-floor descent (Floor 1 Boss cleared -> Floor 2)
	var boss_rid := game.rift_domain.descent_gate_room
	check(boss_rid != "", "boss room tracked for floor descent")
	game.rift_domain._clear_room(boss_rid)
	check(game.rift_domain.descent_gate_active, "clearing Boss unlocks Deep Descent Gate")
	var floor1_keys: Array[String] = game.rift_domain.room_order.duplicate()
	floor1_keys.sort()
	game.hero.position = game.rift_domain.descent_gate_pos + Vector2(150.0, 0.0)
	check(not game.rift_domain.descend_next_floor(true), "speeding up the warp does not bypass the descent gate distance")
	game.hero.position = game.rift_domain.descent_gate_pos
	check(game.rift_domain.descend_next_floor(true) and game.rift_domain.floor_index == 2, "descend_next_floor advances to Floor 2 at the gate")
	var floor2_keys: Array[String] = game.rift_domain.room_order.duplicate()
	floor2_keys.sort()
	check(floor1_keys != floor2_keys, "Floor 2 generates a brand-new seeded topology")

	# Passive queue, one choice per upgrade, cap and overflow.
	for _i in range(4):
		game.gain_run_xp(180.0)
	check(not paused and game.passive_offers.is_empty() and game.passive_engine.pending_ups >= 1, "level ups queue without interrupting combat")
	check(game.open_pending_passive_choice() and game.hud.has_modal(), "[Tab] open_pending_passive_choice opens 3-choice passive modal")
	var chosen := str(game.passive_offers[0].id)
	check(game.choose_passive(chosen) and game.passive_engine.rank(chosen) == 1, "choosing passive increases rank")
	while game.passive_engine.pending_ups > 0 or not game.passive_offers.is_empty():
		if game.passive_offers.is_empty():
			game.open_pending_passive_choice()
		if not game.passive_offers.is_empty():
			game.choose_passive(str(game.passive_offers[0].id))
	var engine := game.passive_engine
	var remaining_xp := -engine.run_xp+0.001
	var levels_left := ArenaPassiveEngine.MAX_RUN_LEVEL-engine.run_level
	for level in range(engine.run_level,ArenaPassiveEngine.MAX_RUN_LEVEL):
		var original := 60.0+58.0*float(level-1)+18.0*pow(float(level-1),1.45)
		check(engine.xp_needed(level) == original,"original XP threshold holds at level %d" % level)
		remaining_xp += original
	game.gain_run_xp(remaining_xp/engine.xp_gain_mult())
	check(engine.pending_ups == levels_left and engine.run_level == 17,"one pending choice per level from the original XP curve")
	for id: String in ArenaPassiveEngine.ORDER:
		if engine.pending_ups <= 0:break
		engine.apply_choice(id)
	check(engine.is_maxed_out() and engine.picks_taken == 16 and not engine.apply_choice("last_stand"),"16 selections settle exactly once at the cap")
	var g_pre := game.gold
	var s_pre := game.core_shield
	game.gain_run_xp(150.0/engine.xp_gain_mult())
	check(game.passive_engine.pending_ups == 0 and game.gold == g_pre + ArenaPassiveEngine.OVERFLOW_GOLD and game.core_shield >= s_pre + 18.0, "overflow uses the existing gold and base shield values")

	# Instant recall shockwave & cooldown check
	var def_mob := game.spawn_enemy("pigsoldier", 0)
	def_mob.position = game.level_definition.core + Vector2(-45, 0)
	var pre_hp := def_mob.health
	check(game.rift_domain.recall_to_defense(true), "instant recall returns to defense domain")
	check(game.active_domain == "defense" and game.hero.domain == "defense", "hero domain switches back to defense")
	check(game.rift_domain.portal_cooldown == 14.0 and not game.enter_rift(), "recall enforces portal cooldown")
	check(def_mob.health < pre_hp, "recall shockwave damages nearby defense enemies")
	await cleanup()


func test_five_heroes_swarm_adaptation() -> void:
	for hid in ["gunner", "healer", "druid"]:
		game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
		game.campaign = ArenaCampaign.new("", false)
		root.add_child(game)
		current_scene = game
		await frames(2)
		game.start_run(hid, "forest")
		await frames(2)
		game.rift_domain.enter_rift(true)
		var foe := game.spawn_enemy("pigsoldier", 0, 0.0)
		foe.domain = "rift"
		foe.is_rift_mob = true
		foe.position = game.hero.position + Vector2(85, 0)
		if hid == "gunner":
			var foe2 := game.spawn_enemy("pigsoldier", 0, 0.0)
			foe2.domain = "rift"
			foe2.is_rift_mob = true
			foe2.position = game.hero.position + Vector2(125, 0)
			var shot := game.fire_projectile(game.hero.center(), foe2.center(), 45.0, 0, "hero", {"pierce": 1 + game.passive_engine.extra_pierce(), "domain": "rift"})
			check(shot.pierce >= 1, "gunner baseline shots pierce at least 1 enemy")
		elif hid == "healer":
			var hp_pre := foe.health
			game.hero._emit_healer_radiant_nova(180.0, 1.2)
			check(foe.health < hp_pre, "healer radiant overheal nova damages surrounding enemies")
		elif hid == "druid":
			check(game.hero.companions.size() == 2, "druid brings 2 companions")
			check(game.hero.companions.all(func(w): return w.position.x >= ArenaRiftDomain.RIFT_ORIGIN.x), "druid companions follow hero into Rift")
		await cleanup()


func test_recall_resume_and_compass() -> void:
	game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	game.next_run_seed = 42
	root.add_child(game)
	current_scene = game
	game.start_run("lord", "forest")
	game.set_physics_process(false)
	var rd := game.rift_domain
	check(rd.enter_rift(true), "start a normal Rift encounter")
	var rid: String = rd.room_order.filter(func(id): return rd.rooms[id].kind == "combat")[0]
	var position := Vector2(rd.rooms[rid].center)
	game.hero.position = position
	rd._start_room_combat(rid)
	var pending := rd._room_telegraph_count(rid)
	var reserves := rd._reserve_groups.duplicate(true)
	check(pending > 0 and not reserves.is_empty(),"room divides its initial wave into telegraphs and reserve groups")
	var foe := rd._spawn_room_mob(rid, "pigsoldier", position + Vector2(60.0, 0.0), false, false) as ArenaEnemy
	foe.health *= 0.5
	foe.ignite(50.0, 3.0)
	var health := foe.health
	var old_drop := game.spawn_pickup(position, "rift", "cyan", 4)
	var shot := game.fire_projectile(position, foe.position, 200.0, ArenaCombat.Type.PHYSICAL, "hero", {"domain": "rift"})
	game.add_zone(position, 150.0, 200.0, 5.0, ArenaCombat.Type.MAGIC, "hero", "burn", "rift")
	game.delayed_attack(position, 150.0, 200.0, ArenaCombat.Type.MAGIC, "hero", 1.0, {"domain": "rift"})
	game.delayed_attack(Vector2.ZERO, 40.0, 0.0, ArenaCombat.Type.MAGIC, "neutral", 1.0, {"domain": "defense"})
	game.passive_engine.active_wells.append({"domain": "rift"})
	var gold := game.gold
	check(rd.recall_to_defense(true), "recall suspends the active room")
	old_drop._physics_process(120.0)
	rd.tick(14.0)
	check(shot.is_queued_for_deletion() and game.zones.is_empty() and game.delayed.size() == 1 and game.passive_engine.active_wells.is_empty() and foe.burn_clock == 0.0, "Rift attacks stop and the defense schedule remains")
	check(foe.health == health and rd._room_telegraph_count(rid) == pending and not old_drop.is_queued_for_deletion(), "Rift foes, pending spawns and drops survive the time spent away")
	check(rd._reserve_groups == reserves,"reserve batches do not advance while the hero is away")
	check(rd.enter_rift(true) and game.hero.position == position and rd.active_combat_room == rid and int(rd.rooms[rid].wave_idx) == 1, "reentry resumes the same room at the saved position")
	check(game.gold == gold and game.kills == 0, "domain transitions grant no repeat rewards")

	game.relic_engine.grant_relic("gilded_compass")
	foe.take_hit(1000.0, ArenaCombat.Type.PHYSICAL, "hero")
	var drop := game.pickups.back() as ArenaXpPickup
	check(drop.gold_value == 0, "regular Rift enemies grant XP without passive coin income")
	drop._collect()
	check(is_equal_approx(game.passive_engine.run_xp, 15.6), "raw mob XP is multiplied by the compass once")
	var gold_after := game.gold
	drop._collect()
	check(game.gold == gold_after and is_equal_approx(game.passive_engine.run_xp, 15.6), "a collected Rift pickup cannot pay again")
	rd._spawn_xp_fountain(position, 1, 0, 34, 4)
	var fountain_drop := game.pickups.back() as ArenaXpPickup
	fountain_drop._collect()
	check(is_equal_approx(game.passive_engine.run_xp, 59.8), "room chest XP gets the same single compass multiplier")
	await cleanup()


func test_deeper_room_phases_and_cover() -> void:
	game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	game.next_run_seed = 137
	root.add_child(game)
	current_scene = game
	game.start_run("lord", "forest")
	game.set_physics_process(false)
	var rd := game.rift_domain
	rd.enter_rift(true)
	rd.descent_gate_active = true
	game.hero.position = rd.descent_gate_pos
	check(rd.descend_next_floor(true), "start a deep encounter through the descent gate")
	var room: Dictionary = rd.rooms.values().filter(func(candidate): return candidate.kind == "boss")[0]
	var rid: String = room.id
	var center := Vector2(room.center)
	game.hero.position = center
	rd._start_room_combat(rid)
	var first: String = rd.layout.boss
	var second: String = rd.layout.alt_boss
	check(rd._telegraphs.any(func(spawn): return spawn.kind == first) and not rd._telegraphs.any(func(spawn): return spawn.kind == second), "the first boss telegraph contains one leader")
	var pillar: Rect2 = room.obstacles[0]
	var left := Vector2(pillar.position.x-52.0,pillar.get_center().y)
	var right := Vector2(pillar.end.x+52.0,pillar.get_center().y)
	var shot := game.fire_projectile(left, right, 80.0, ArenaCombat.Type.PHYSICAL, "hero", {"domain": "rift", "speed": 1000.0})
	shot._physics_process(0.25)
	check(shot.is_queued_for_deletion() and is_equal_approx(shot.position.x,pillar.position.x), "a direct Rift shot is stopped at the first pillar face")
	var route := rd.navigation_path(left,right)
	check(route.size() > 1 and route[-1].is_equal_approx(right), "a movement order can reach the far side by going around a pillar")
	var phases := []
	var deepest_group := 0
	for _i in range(24):
		rd._tick_rooms_and_waves(1.0)
		var enemies := game.domain_enemies("rift")
		deepest_group = maxi(deepest_group,enemies.size())
		for enemy: ArenaEnemy in enemies:
			if enemy.kind in [first,second,rd.layout.miniboss]:
				phases.append(enemy.kind)
				enemy.health = enemy.max_health*0.45
				enemy.take_hit(1.0,ArenaCombat.Type.PHYSICAL,"hero")
			game.remove_enemy(enemy)
		if room.state == "cleared":
			break
	check(phases == [first,second,rd.layout.miniboss] and deepest_group <= 8, "deep bosses and final escort appear in order within the group limit")
	check(game.domain_enemies("defense").is_empty(), "Rift boss phase thresholds do not summon enemies on defense roads")
	check(room.state == "cleared" and room.reward_active and rd.descent_gate_active, "the room reward and descent unlock after the final group")
	await cleanup()


func test_new_passive_damage_paths() -> void:
	game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	game.campaign.data.levels.lord = 2
	root.add_child(game)
	current_scene = game
	game.start_run("lord", "forest")
	game.set_physics_process(false)
	var passive := game.passive_engine
	passive.stacks = {"spellbreak": 1, "shieldbreak": 3, "riposte": 1, "focus_energy": 3, "iron_guard": 1, "handover": 2}
	var foe := game.spawn_enemy("pigsoldier", 0)
	foe.health = 500.0
	foe.max_health = 500.0
	foe.ability_kind = "heal"
	foe.ability_windup = 1.0
	foe.barrier_shield = 30.0
	foe.take_hit(5.0, ArenaCombat.Type.PHYSICAL, "hero", 0.0, 0.0, 0.0, "chain_bolt", Vector2.ZERO, Vector2.INF, {"passive_proc": true})
	check(foe.ability_windup == 1.0 and passive._energy_hits == 0, "indirect hits do not interrupt support or charge energy")
	var strike := {"rule_basic": true, "per_attack": {}, "counter": true}
	var first := foe.take_hit(34.0, ArenaCombat.Type.PHYSICAL, "hero", 0.0, 0.0, 0.0, "attack", Vector2.ZERO, Vector2.INF, strike)
	check(foe.ability_windup == 0.0 and foe.barrier_shield == 0.0 and foe.marked > 0.0, "direct hit interrupts support, breaks the shield and marks the target")
	var second := foe.take_hit(34.0, ArenaCombat.Type.PHYSICAL, "hero", 0.0, 0.0, 0.0, "attack", Vector2.ZERO, Vector2.INF, strike.duplicate())
	check(first > second and passive._energy_hits == 1 and strike.per_attack.has("riposte"), "shared attack data counts a counter and energy once across hits")
	game.hero.cooldowns[0] = 5.0
	for _i in range(2):
		foe.take_hit(10.0, ArenaCombat.Type.PHYSICAL, "hero", 0.0, 0.0, 0.0, "attack", Vector2.ZERO, Vector2.INF, {"rule_basic": true, "per_attack": {}})
	check(is_equal_approx(game.hero.cooldowns[0], 4.2) and passive._energy_hits == 0, "three separate attacks with max-rank energy shorten an unlocked cooldown")
	check(is_equal_approx(passive.guard_damage(50.0), 41.0) and passive.guard_damage(50.0) == 50.0, "iron guard reduces only the first hit during its cooldown")
	var departure := game.hero.position
	check(game.rift_domain.enter_rift(true), "handover begins with a real departure")
	check(is_equal_approx(passive.tower_power_mult(departure), 1.18) and passive.tower_power_mult(departure+Vector2(500.0,0.0)) == 1.0, "handover empowers nearby towers at the departure site")
	check(game.rift_domain.recall_to_defense(true) and passive.tower_power_mult(departure) == 1.0, "the handover bonus clears on recall")
	await cleanup()


func test_hud_matches_runtime() -> void:
	game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	game.campaign.data.levels.gunner = 5
	game.next_run_seed = 137
	root.add_child(game)
	current_scene = game
	game.start_run("gunner", "forest")
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	game.hero.gunner_overdrive_clock = 6.0
	check(game.hero.cast(0,game.hero.position+Vector2(50.0,0.0)), "cast an overdrive slide through the regular hero entry point")
	game.hud._process(0.1)
	check(game.hud.skills[0].text == str(ceili(game.hero.cooldowns[0])) and is_zero_approx(game.hud.skill_glyphs[0].progress), "the overdrive cooling gauge uses the actual two-second cycle")
	check("2.3 倍" in game.hud.skills[0].tooltip_text and "额外穿透 4" in game.hud.skills[0].tooltip_text, "battle tooltip describes the current rank and actual piercing shot")
	game.hero.cooldowns[0] *= 0.5
	game.hud._process(0.1)
	check(is_equal_approx(game.hud.skill_glyphs[0].progress,0.5), "the skill ring shows half of the applied cooldown")
	game.hero.rolling = 0.0
	game.hero.cancel_action()
	game.passive_engine.stacks["phantom_slash"] = 3
	game.relic_engine.grant_relic("chrono_prism")
	check(game.hero.try_dodge(), "start a reduced-cooldown dodge")
	game.hud._process(0.1)
	check(is_zero_approx(game.hud.dodge_glyph.progress), "the dodge ring starts at zero even with two cooldown modifiers")

	var packets := game.wave_packets(game.wave_pattern())
	var profile := ArenaLevelCatalog.preview_profile(packets,game.cycle)
	game.request_wave()
	game.hud._process(0.1)
	var wave_labels := game.hud.preview.find_children("*","Label",true,false)
	check(wave_labels.any(func(node): return "计划 %d 敌" % profile.count in node.text), "wave panel displays the planned spawn count")
	var gold := game.gold
	var bonus := game.preview_wave_bonus()
	game.request_wave()
	check(game.gold == gold+bonus and game.spawn_queue == packets, "preview bounty and roster match the committed wave")
	check(game.rift_domain.enter_rift(true), "enter Rift through the normal domain transition")
	game.hud._process(0.1)
	check(not game.hud.wave_button.visible and game.hud.wave_button.disabled, "defense wave control is absent when it cannot be used")

	for relic: String in ArenaRelicEngine.ORDER:
		game.relic_engine.grant_relic(relic)
	var rid: String = game.rift_domain.rooms.values().filter(func(room): return room.kind == "miniboss")[0].id
	game.core_shield = ArenaGame.CORE_SHIELD_MAX-3.0
	gold = game.gold
	game.rift_domain._claim_room_reward(rid)
	check(game.gold-gold == 100 and game.core_shield == ArenaGame.CORE_SHIELD_MAX and "+100 金 · +3 盾" in str(game.numbers.back().text), "Rift chest popup reports capped shield and the full relic overflow")
	await cleanup()
