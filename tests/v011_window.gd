extends "res://tests/v06_window.gd"
# Window/presentation fixtures, deliberately isolated from real player profiles.
func run() -> void:
	create_timer(90).timeout.connect(func():push_error("V011 WINDOW TIMEOUT");quit(1))
	if "--small" in OS.get_cmdline_user_args():suffix="small"
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);game.campaign.data.levels["lord"]=5
	root.add_child(game);current_scene=game;await frames()
	await press("StartCampaign");await press("HeroHall");await snapshot("v011-hero")
	check(game.hud.hero_portrait("lord").resource_path==ArenaHeroArt.POSE_ROOT+"portrait_lord.png","hero screen uses new v022 pixel portrait")
	await press("Back");await press("Level_forest");await press("Deploy")
	game.feel_lab=true;game.phase="lab";game.lab=ArenaFeelLab.new();game.add_child(game.lab);game.lab.open(game)
	await frames();await snapshot("v011-lab")
	check(game.hero.visual.has_complete_set(),"new lord keeps seven states and three directions")
	var real_scale: float=root.size.x/1600.0
	for name in ["LabTargets","LabSkill","LabCry","LabExit"]:
		var button: Button=game.hud.root.find_child(name,true,false)
		check(button.size.y*real_scale>=44.0,"lab button has usable size "+name)
	var collision: CollisionShape2D
	for child in game.hero.get_children():
		if child is CollisionShape2D:collision=child
	var radius: float=collision.shape.radius
	await press("LabScale");check(is_equal_approx(game.hero.visual.visual_size,ArenaHeroArt.height("lord",true,1.0)),"smaller visual size comparison")
	await press("LabScale");check(is_equal_approx(game.hero.visual.visual_size,ArenaHeroArt.height("lord",true)),"larger visual comparison")
	check(collision.shape.radius==radius,"comparison never changes collider")
	await press("LabBaseline");check(not game.feel.enabled and not game.audio.sampled,"baseline uses old animation/audio/feedback")
	await snapshot("v011-baseline");await press("LabBaseline")
	await press("LabTargets");var shots:=game.hero.shots;await frames();check(game.hero.shots==shots,"lab UI click does not attack")
	await press("LabReduced");check(game.campaign.data.reduced_motion,"reduced setting applies only in fixture")
	await press("LabSkill");await create_timer(0.35).timeout;check(game.hero.cooldowns[0]>0,"skill button triggers real skill cooldown")
	await snapshot("v011-slam-reduced");await press("LabReduced")
	await press("LabTargets");await press("LabCry");await create_timer(0.45).timeout
	check(game.hero.lord_shield_clock>0 and game.hero.overheal_shield>0,"blood-thorn shield is an actual tank defensive buff")
	await snapshot("v011-cry")
	await key(KEY_ESCAPE);check(paused,"pause works in lab");await key(KEY_ESCAPE);check(not paused,"resume works in lab")
	game.feel.clear(game);check(game.camera.offset==Vector2.ZERO,"feedback cleanup restores full-map camera")
	var hero_instance:=game.hero.get_instance_id();game.restart_run();await frames()
	check(game.hero.get_instance_id()==hero_instance and game.running and not game.game_over,"lab restart resets fixture without leaking reload metadata")
	check(not has_meta("restart_hero"),"lab restart cannot force a normal run after returning")
	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(150);game.queue_free();await frames()
	print("V011 WINDOW CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
