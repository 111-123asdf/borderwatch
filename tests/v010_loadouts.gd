extends SceneTree
# Explicit isolated profiles and runtime fixtures, not a natural playthrough.
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("LOADOUT FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func frames() -> void:await process_frame;await process_frame;await process_frame
func run() -> void:
	var state:=ArenaCampaign.new("",false)
	check(state.selected_hero()=="knight" and state.tower_loadout()==["archer","mage","cannon","barracks"],"new profile defaults to knight and four towers")
	check(state.select_hero("ranger") and state.selected_hero()=="ranger","one selected hero replaces the old selection")
	check(not state.select_hero("missing") and state.selected_hero()=="ranger","invalid hero preserves selection")
	check(state.equip_towers(["mage","archer"]),"valid ordered tower loadout saves")
	for keys in [[],["missing"],["archer","archer"],["archer",1],["archer","mage","cannon","barracks","fox"]]:
		check(not state.equip_towers(keys) and state.tower_loadout()==["mage","archer"],"invalid loadout cannot replace current towers "+str(keys))
	var copy:=state.tower_loadout();copy.clear();check(state.tower_loadout().size()==2,"callers cannot mutate the saved loadout through an alias")
	state.equip_towers(["mage"])
	check(not state.can_deploy("forest") and state.can_deploy("creek"),"stage gate checks the actual first-wave tower pool")
	check(not state.can_deploy("missing"),"unknown stage cannot deploy")
	var path:="user://loadout-fixture-"+str(Time.get_ticks_usec())+".cfg"
	var legacy:=ArenaCampaign.new("",false);legacy.data.gems=17;legacy.data.levels.mage=4
	legacy.data.erase("selected_hero");legacy.data.erase("equipped_towers")
	var cfg:=ConfigFile.new();cfg.set_value("campaign","version",3);cfg.set_value("campaign","data",legacy.data);cfg.save(path)
	var bytes:=FileAccess.get_file_as_bytes(path);var loaded:=ArenaCampaign.new(path,true)
	check(not loaded.locked and loaded.gems()==17 and loaded.level("mage")==4,"old v3 progression is retained")
	check(loaded.selected_hero()=="knight" and loaded.tower_loadout().size()==4,"missing new fields receive compatible defaults")
	check(bytes==FileAccess.get_file_as_bytes(path),"loading old v3 never rewrites its bytes")
	check(loaded.select_hero("mage") and loaded.equip_towers(["mage","archer"]),"configuration persists in the same v3 file")
	var again:=ArenaCampaign.new(path,true)
	check(again.selected_hero()=="mage" and again.tower_loadout()==["mage","archer"] and again.gems()==17 and again.level("mage")==4,"reload preserves configuration and existing progression")
	var bad:=legacy.data.duplicate(true);bad.equipped_towers=["unknown"]
	cfg.set_value("campaign","data",bad);cfg.save(path+".bad");bytes=FileAccess.get_file_as_bytes(path+".bad")
	check(ArenaCampaign.new(path+".bad",true).locked and bytes==FileAccess.get_file_as_bytes(path+".bad"),"present but invalid configuration is preserved and locked")
	var fail_save:=ArenaCampaign.new("user://missing-v010-folder/nested/profile.cfg",true)
	check(not fail_save.select_hero("mage") and fail_save.selected_hero()=="knight","failed write preserves selected hero")
	check(not fail_save.equip_towers(["mage"]) and fail_save.tower_loadout().size()==4,"failed write preserves tower loadout")
	var game: ArenaGame=load("res://scenes/arena.tscn").instantiate();game.campaign=state
	state.equip_towers(["mage","archer"]);root.add_child(game);current_scene=game;await frames()
	game.start_run(state.selected_hero(),"forest")
	check(game.hero.class_id=="ranger" and game.run_towers==["mage","archer"],"deployment snapshots selected hero and towers")
	check(game.available_towers()==["archer"],"equipped towers also obey wave unlocks")
	var gold:=game.gold
	check(not game.build_tower(0,"barracks") and game.gold==gold,"unequipped tower cannot consume gold")
	game.cycle=5
	check(game.available_towers()==["archer","mage"],"unlocks never restore unequipped towers")
	state.equip_towers(["barracks"])
	check(game.run_towers==["mage","archer"] and game.available_towers()==["archer","mage"],"out-of-run configuration does not alter a running battle")
	game.restart_run();await frames();game=current_scene as ArenaGame
	check(game.started and game.hero.class_id=="ranger" and game.run_towers==["mage","archer"],"restart retains the original run snapshot")
	game.return_to_menu();await frames();game=current_scene as ArenaGame
	check(not game.started and game.hud.frontend.page_id=="world","return from battle reaches the world map")
	for key in ArenaLevelCatalog.IDS:check(ArenaLevelCatalog.WORLD_NODES.has(key),"playable stage has authored world position "+key)
	game.audio.shutdown();await frames();OS.delay_msec(150);game.queue_free();await frames()
	print("V010 LOADOUT CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
