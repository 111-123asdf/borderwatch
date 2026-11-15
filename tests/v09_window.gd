extends "res://tests/v06_window.gd"
# UI/layout fixtures inject gems, hero level, gold and wave for coverage, not normal play.
func run() -> void:
	create_timer(100.0).timeout.connect(func():push_error("V09 WINDOW TIMEOUT");quit(1))
	if "--small" in OS.get_cmdline_user_args():suffix="small"
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false)
	root.add_child(game);current_scene=game;await frames()
	await snapshot("v09-entry")
	await press("StartCampaign");await press("HeroHall");check(game.campaign.level("knight")==1,"hero hall opens at level one")
	var up: Button=game.hud.root.find_child("UpgradeHero",true,false)
	check(up!=null and up.disabled,"upgrade is disabled without gems")
	await snapshot("v09-hall")
	game.campaign.data.gems=20;game.hud.frontend.hall();await frames()
	await press("UpgradeHero");check(game.campaign.level("knight")==2 and game.campaign.gems()==18,"UI upgrade charges exact gems and unlocks Q")
	await press("Back");await snapshot("v09-levels")
	check(not game.started and game.hud.root.find_child("Hero_knight",true,false)==null,"world map has no repeated hero preparation")
	await press("Level_forest");await snapshot("v09-prepare")
	check(not game.started,"choosing a stage does not start combat")
	await press("Deploy")
	check(game.started and game.hero.meta_level==2 and game.level_id=="forest","deploy keeps chosen hero, level and stage")
	await key(KEY_E);check(game.hero.cooldowns[1]==0 and game.hero.action!="ultimate","locked ultimate cannot fire from keyboard")
	game.gold=12000;game.cycle=5;game.phase_clock=60
	var ids: Array=["archer","mage","cannon","barracks"]
	for index in range(4):
		await click(game.level_definition.sites[index]);await press("Build_"+str(ids[index]));game.hud.close_context()
	check(game.towers.size()==4,"all four buildings can be placed")
	await snapshot("v09-towers-1")
	for tower in game.towers:tower.upgrade()
	game.hud.close_context();await frames();await snapshot("v09-towers-2")
	for tower in game.towers:
		tower.upgrade();tower.choose_doctrine(str(ArenaDoctrines.for_tower(tower.kind)[0].id))
	game.hud.close_context();await frames();await snapshot("v09-towers-3")
	for tower in game.towers:
		var placement:=ArenaBattleArt.contact(tower.kind,tower.level,tower.body.texture.get_size())
		var anchor: Vector2=(Vector2(placement.uv)-Vector2(0.5,0.5))*tower.body.texture.get_size()
		check((anchor+tower.body.offset).length()<0.01,"building is anchored at its ground contact "+tower.kind)
	var tower: ArenaTower=game.towers[0];var point:=tower.position;tower.sell();await frames()
	check(game.site_tower(0)==null and game.level_definition.sites[0]==point,"selling restores the same empty ground")
	await snapshot("v09-sold")
	game.running=false
	game.hero.meta_level=5
	for identity in ArenaDefinitions.HERO_IDS:
		game.campaign.data.levels[identity]=5;game.hero.configure(identity)
		for view in [Vector2.RIGHT,Vector2.DOWN,Vector2.UP]:
			game.hero.visual.show_state("attack",view,0.7);await create_timer(0.42).timeout
			await snapshot("v09-"+identity+"-"+("side" if view==Vector2.RIGHT else ("down" if view==Vector2.DOWN else "up")))
	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(150);game.queue_free();await frames()
	print("V09 WINDOW CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
