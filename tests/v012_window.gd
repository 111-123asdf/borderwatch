extends "res://tests/v06_window.gd"
# Real window events, level-5 lab fixture. Not normal-resource completion.
func run() -> void:
	create_timer(100).timeout.connect(func():push_error("V012 WINDOW TIMEOUT");quit(1))
	if "--small" in OS.get_cmdline_user_args():suffix="small"
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false)
	for id in ArenaDefinitions.HERO_IDS:game.campaign.data.levels[id]=5
	root.add_child(game);current_scene=game;await frames()
	await press("StartCampaign");await press("HeroHall")
	for identity in ["ranger","mage"]:
		await press("Hall_"+identity);await snapshot("v012-portrait-"+identity)
		check(game.hud.hero_portrait(identity).resource_path=="res://assets/v012/portrait_"+identity+".png","new portrait "+identity)
	await press("Back");await press("Level_forest");await press("Deploy")
	game.feel_lab=true;game.phase="lab";game.lab=ArenaFeelLab.new();game.add_child(game.lab);game.lab.open(game);await frames()
	for identity in ["ranger","mage"]:
		await press("LabHero_"+identity)
		for i in range(8):await process_frame
		game=current_scene;await frames()
		check(game.hero.class_id==identity and game.feel_lab,"hero switch through real button "+identity)
		var ratio:=root.size.x/1600.0
		for name in ["LabHero_knight","LabHero_ranger","LabHero_mage","LabTargets","LabSkill","LabCry","LabExit"]:
			var button: Button=game.hud.root.find_child(name,true,false)
			check(button.size.y*ratio>=44,"44px actual hit target "+name)
			check(button.get_global_rect().end.y*ratio<=root.size.y+1,"button remains in viewport "+name)
		await snapshot("v012-lab-"+identity)
		var shots:=game.hero.shots;await press("LabTargets");check(game.hero.shots==0,"reset clears counter and UI does not shoot")
		var motion:=InputEventMouseMotion.new();motion.position=root.get_canvas_transform()*game.hero.position;motion.global_position=motion.position;root.push_input(motion,true);await frames()
		Input.action_press("shoot");await create_timer(1.5).timeout;Input.action_release("shoot")
		check(game.hero.shots>0,"held input fires real attack "+identity);await snapshot("v012-attack-"+identity)
		await press("LabTargets");await press("LabSkill");await create_timer(.18).timeout
		check(game.hero.cooldowns[0]>0,"actual skill "+identity);await snapshot("v012-small-"+identity)
		await press("LabTargets");await press("LabCry");await create_timer(.50).timeout
		check(game.hero.cooldowns[1]>0,"actual ultimate "+identity);await snapshot("v012-ultimate-"+identity)
		await create_timer(1.2).timeout;check(game.delayed.size()<=4 if identity=="ranger" else game.delayed.is_empty(),"delayed lab attack executes "+identity)
		await press("LabBaseline");check(not game.feel.enabled,"baseline switch "+identity);await snapshot("v012-old-"+identity)
		await press("LabBaseline");await press("LabReduced");await press("LabTargets");await press("LabCry");await create_timer(.5).timeout
		check(game.campaign.data.reduced_motion and game.camera.offset==Vector2.ZERO,"reduced motion "+identity);await press("LabReduced")
	await press("LabExit");for i in range(6):await process_frame
	game=current_scene;check(not game.feel_lab and game.hud.frontend.page_id=="world","exit opens normal world")
	game.audio.shutdown();await frames();OS.delay_msec(150);game.queue_free();await frames()
	print("V012 WINDOW CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
