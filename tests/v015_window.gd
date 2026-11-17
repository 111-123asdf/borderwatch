extends "res://tests/v06_window.gd"
func run() -> void:
	create_timer(90.0).timeout.connect(func():push_error("V015 WINDOW TIMEOUT");quit(1))
	if "--small" in OS.get_cmdline_user_args():suffix="small"
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.playtest()
	root.add_child(game);current_scene=game;await frames()
	await press("StartCampaign");await snapshot("v015-world")
	await press("Level_ruins");await snapshot("v015-stage-ruins")
	await press("Deploy");await frames()
	check(game.started and game.level_id=="ruins","deployed cleanly into stage 3 ruins")
	check(game.routes.size()==4 and game.level_definition.sites.size()==18,"4 routes and 13 trait sites active")
	check(game.tilemap_scene==null and game.ground.visible,"current painted terrain active in window")
	check(game.atmosphere!=null,"ArenaAtmosphere active in window")
	var effects: ArenaEffects=null
	for child in game.get_children():
		if child is ArenaEffects:effects=child;break
	check(effects!=null and effects.has_v016_fx("arcane_blast") and effects.has_v016_fx("fire_brazier"),"pixelfx sheets active in window")

	# Build towers across highground (site 3), choke (site 4), and conduit (site 7)
	await click(game.world_to_hud(game.level_definition.sites[8]));await press("Build_barracks");await click(Vector2(200,200),MOUSE_BUTTON_RIGHT)
	await click(game.world_to_hud(game.level_definition.sites[5]));await press("Build_mage");await click(Vector2(200,200),MOUSE_BUTTON_RIGHT)
	await click(game.world_to_hud(game.level_definition.sites[3]));await press("Build_archer");await click(Vector2(200,200),MOUSE_BUTTON_RIGHT)
	check(game.site_tower(8)!=null and game.site_tower(5)!=null and game.site_tower(3)!=null,"built barracks(choke), mage(conduit), archer(highground)")
	await snapshot("v015-ruins-rest")
	game.hud.show_pause();await frames();await snapshot("v015-ruins-pause");game.hud.resume();await frames()

	# Show Keystone Relic 3-pick Rest modal
	game.cycle=3;game.start_rest(16);await frames()
	check(game.choice_open,"keystone modal opened cleanly")
	await snapshot("v015-ruins-keystone")
	await press("Keystone_"+game.choices[0]);await frames()

	# Showcase Wave 5+ NE rift breach + Bridge Gate detour seal + active Altars + Colossus Boss + pixelfx combat
	if "orbit" not in game.keystones:game.keystones.append("orbit")
	game.cycle=5;game.phase="rest";game.begin_wave();game.spawn_queue.clear()
	await frames()
	game.cycle=8;game.phase="rest";game.begin_wave();game.resonance=100.0
	await press("BridgeGate");await frames()
	check(game.bridge_sealed,"BridgeGate button sealed SW bridge in window")
	game.altars[0].active=10.0;game.siege.open_passage()
	var boss:=game.spawn_enemy("colossus",0,1020.0)
	var harv:=game.spawn_enemy("void_harvester",3,280.0)
	var prism:=game.spawn_enemy("astral_prism",0,840.0)
	var warden:=game.spawn_enemy("rune_warden",2,720.0)
	var hound:=game.spawn_enemy("construct_hound",1,730.0)
	boss.take_hit(boss.max_health*0.50,1,"hero")
	harv.take_hit(harv.max_health*0.35,0,"hero")
	prism.take_hit(prism.max_health*0.40,0,"hero")
	warden.take_hit(warden.max_health*0.35,1,"hero")
	hound.take_hit(hound.max_health*0.40,0,"hero")
	await create_timer(0.45).timeout
	if effects!=null:
		game.effect(boss.center(),95.0,Color("b88cff"),"blast",0.85)
		game.effect(harv.center(),62.0,Color("7fe8ff"),"lightning",0.80,Vector2(1,-0.4))
		game.effect(warden.center(),52.0,Color("f5cd6a"),"slash",0.75,Vector2(-1,0.3))
		game.effect(prism.center(),58.0,Color("7fd8ff"),"shield_break",0.85)
	await snapshot("v015-ruins-boss-combat")
	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(120);game.queue_free();await frames()
	print("V015 WINDOW CHECKS: %d, FAILURES: %d"%[checks,failures])
	quit(0 if failures==0 else 1)
