extends "v06_window.gd"

func run() -> void:
	create_timer(45.0).timeout.connect(func():push_error("SALT PORT WINDOW TIMEOUT");quit(1))
	if "--small" in OS.get_cmdline_user_args():
		suffix="small"
	game=load("res://scenes/arena.tscn").instantiate()
	game.campaign=ArenaCampaign.new("",false)
	root.add_child(game)
	current_scene=game
	await frames()
	if "--render-assets" in OS.get_cmdline_user_args():
		await _render_assets()
	else:
		await _test_battle()
	game.running=false
	game.audio.shutdown()
	await frames()
	OS.delay_msec(150)
	game.queue_free()
	await frames()
	print("SALTPORT WINDOW CHECKS: %d, FAILURES: %d"%[checks,failures])
	quit(0 if failures==0 else 1)

func _render_assets() -> void:
	var folder := "user://saltport-art"
	DirAccess.make_dir_recursive_absolute(folder)
	game.start_run("lord","saltport")
	game.running=false
	game.hud.root.hide()
	game.hero.hide()
	await frames()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(folder+"/preview.png")==OK,"battlefield preview rendered from live map")
	var view := SubViewport.new()
	view.size=Vector2i(160,160)
	view.transparent_bg=true
	view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	for kind in ArenaSaltCreature.TYPES:
		var art := ArenaSaltCreature.new()
		art.identity=kind
		var battle_width: float=ArenaSaltCreature.TYPES[kind]
		art.scale=Vector2.ONE*(145.0/battle_width)
		art.position=Vector2(76,139)
		view.add_child(art)
		await frames()
		await RenderingServer.frame_post_draw
		check(view.get_texture().get_image().save_png(folder+"/"+kind+".png")==OK,"rendered enemy card "+kind)
		art.queue_free()
	view.queue_free()

func _test_battle() -> void:
	await press("StartCampaign")
	await press("Level_saltport")
	check(game.hud.frontend.stage=="saltport","world map selects fourth stage")
	await snapshot("saltport-selection")
	await press("Deploy")
	check(game.started and game.level_id=="saltport","new stage deploys through the front end")
	check(game.gold==280 and game.routes.size()==2,"normal starting resources and dual routes")
	var path := game.navigation_path(Vector2(590,405),Vector2(970,635))
	var distance := 0.0
	var last := Vector2(590,405)
	for point in path:
		distance+=last.distance_to(point)
		last=point
	check(distance>0 and distance<600,"hero can use cross-front footpath")
	await click(game.level_definition.sites[2])
	var choice: Button=game.hud.root.find_child("Build_archer",true,false)
	choice.grab_focus()
	await frames()
	check(game.hud.preview_tower=="archer","construction preview identifies the focused tower")
	await snapshot("saltport-range")
	await press("Build_archer")
	await click(game.level_definition.sites[6])
	await press("Build_archer")
	check(game.site_tower(2)!=null and game.site_tower(6)!=null and game.gold==140,"two real constructions with exact costs")
	await press("CallWave")
	check(game.wave_preview and ArenaLevelCatalog.wave("saltport",1).lanes==[0],"first preview highlights the west entrance")
	await press("CallWave")
	await create_timer(1.45).timeout
	var enemy := game.nearest_enemy(Vector2(5,235),150,false)
	check(enemy!=null and enemy.kind=="fiddler" and enemy.visual.salt_rig!=null,"first scheduled spawn uses its own rig")
	await snapshot("saltport-wave")
