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
	check(ArenaPassiveEngine.PASSIVES.size() == 14 and ArenaPassiveEngine.MAX_TOTAL_PICKS == 10 and ArenaPassiveEngine.MAX_RUN_LEVEL == 11, "passive engine exposes 14 passives and 10-pick cap")
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
			check(game.hud.context.find_child("Upgrade", true, false) == null, "formal campaign hides manual Upgrade button")
			var gold_before := game.gold
			bar.gain_auto_xp(250.0)
			check(bar.level >= 2 and game.gold == gold_before, "auto XP levels tower without costing gold")
			bar.gain_auto_xp(500.0)
			check(bar.level == 3, "auto XP caps cleanly at Lv.3")
			check(game.charge_core_aegis() and game.core_shield >= 180.0 and game.core_overdrive_clock > 0.0, "Base Core Aegis shields and overdrives towers")
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
	var r2 := game.request_next_wave_anytime()
	check(bool(r2.ok) and str(r2.mode) == "fast_siege" and game.wave_elapsed >= game.siege_start_at - 1.0, "Anytime Call-Wave fast-forwards skirmish to Siege")
	game.spawn_queue.clear()
	var r3 := game.request_next_wave_anytime()
	check(bool(r3.ok) and str(r3.mode) == "stack_next" and game.cycle == 2 and not game.spawn_queue.is_empty(), "Anytime Call-Wave stacks wave 2 cleanly")

	# Summoned portal warp sequence [T] -> modular PCG dungeon + HUD overlap check!
	check(game.enter_rift() and game.rift_domain.warp_phase == "out", "enter_rift summons animated portal warp")
	for _w in range(10):
		game.rift_domain.tick(0.1)
	await frames(2)
	check(game.active_domain == "rift" and game.hero.domain == "rift", "hero & game transition into rift domain after warp")
	check(game.hero.position.x >= ArenaRiftDomain.RIFT_ORIGIN.x, "hero relocated into PCG Rift dungeon")
	check(game.rift_domain.rooms.size() >= 9 and game.rift_domain._fog_layer != null, "PCG multi-room dungeon & fog of war initialized")
	check(str(game.rift_domain.rooms["hub"].state) == "cleared" and game.rift_domain.rift_explore_haste() >= 0.45, "hub cleared gives >= +45% explore haste")
	check(not game.hud.aegis_button.visible and not game.hud.next_wave_btn.visible and not game.hud.wave_label.visible and game.hud.rift_minimap.visible, "Rift HUD hides defense top-right widgets cleanly with zero minimap overlap")

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
	check(game.rift_domain.descend_next_floor(true) and game.rift_domain.floor_index == 2, "descend_next_floor advances to Floor 2")
	var floor2_keys: Array[String] = game.rift_domain.room_order.duplicate()
	floor2_keys.sort()
	check(floor1_keys != floor2_keys, "Floor 2 generates a brand-new seeded topology")

	# Passive queue + 10-pick cap + overflow
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
	while game.passive_engine.picks_taken < ArenaPassiveEngine.MAX_TOTAL_PICKS:
		game.passive_engine.apply_choice("chain_bolt" if game.passive_engine.rank("chain_bolt") < 3 else ("gravity_well" if game.passive_engine.rank("gravity_well") < 3 else "orbital_laser"))
	check(game.passive_engine.is_maxed_out(), "picks_taken hard caps cleanly at 10")
	var g_pre := game.gold
	var s_pre := game.core_shield
	game.gain_run_xp(150.0)
	check(game.passive_engine.pending_ups == 0 and game.gold >= g_pre + 15 and game.core_shield >= s_pre + 18.0, "overflow XP past 10 picks grants bonus gold and base shield")

	# Instant recall shockwave & cooldown check
	var def_mob := game.spawn_enemy("pigsoldier", 0)
	def_mob.position = game.level_definition.core + Vector2(-45, 0)
	var pre_hp := def_mob.health
	check(game.rift_domain.recall_to_defense(true), "instant recall returns to defense domain")
	check(game.active_domain == "defense" and game.hero.domain == "defense", "hero domain switches back to defense")
	check(game.rift_domain.portal_cooldown > 0.0 and not game.enter_rift(), "recall enforces portal cooldown")
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
