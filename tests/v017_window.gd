extends "v06_window.gd"
# Visual fixture: currency, towers and enemy positions injected for comparison only.
func run() -> void:
	if "--small" in OS.get_cmdline_user_args():suffix="small"
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.playtest();root.add_child(game);current_scene=game;await frames();game.start_run("knight","ruins");await frames()
	game.camera.toggle_overview();game.gold=10000
	check(game.camera.overview,"large map overview active")
	game.camera.focus(game.level_definition.sites[16]);await frames()
	await click(game.world_to_hud(game.level_definition.sites[16]));await press("Build_archer")
	check(game.site_tower(16)!=null,"real pointer builds at panned world coordinate")
	await click(Vector2(700,450),MOUSE_BUTTON_RIGHT);game.camera.toggle_overview();await frames()
	var positions: Array=[3,5,11,8]
	for i in range(4):check(game.build_tower(positions[i],ArenaDefinitions.TOWER_IDS[i]),"four tower silhouettes build")
	game.hud.close_context();await frames();await snapshot("v017-tier1")
	for tier in [2,3]:
		for tower in game.towers:tower.upgrade()
		await create_timer(1.1).timeout;await frames();await snapshot("v017-tier"+str(tier))
	var i:=0
	for kind in ["construct_hound","rune_warden","astral_prism","rift_bomber","void_harvester","colossus"]:
		var enemy:=game.spawn_enemy(kind,0,0);enemy.position=Vector2(650+i*145,550);enemy.stun=20
		check(enemy.visual.construct_rig!=null,"painted rig visible "+kind);i+=1
	game.running=false;await frames();await snapshot("v017-creatures")
	game.audio.shutdown();await frames();game.queue_free();await frames();print("V017 WINDOW CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
