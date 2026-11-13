extends SceneTree
var game: ArenaGame
var checks:=0
var failures:=0
var suffix:="large"
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("WINDOW FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func frames() -> void:
	await process_frame;await process_frame
func click(point: Vector2,which:=MOUSE_BUTTON_LEFT) -> void:
	root.warp_mouse(point);await frames()
	var event:=InputEventMouseButton.new();event.position=point;event.button_index=which;event.pressed=true;root.push_input(event,true)
	await frames();event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func key(code: Key) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true;root.push_input(event,true);await frames();event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func press(name: String) -> void:
	var button: Button=game.hud.root.find_child(name,true,false)
	for attempt in range(10):
		if button!=null:break
		await process_frame
		button=game.hud.root.find_child(name,true,false)
	check(button!=null,"button exists "+name)
	if button!=null:await click(button.get_global_rect().get_center())
func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw;var folder:=ProjectSettings.globalize_path("user://v06-review");DirAccess.make_dir_recursive_absolute(folder);root.get_texture().get_image().save_png(folder+"/window-"+suffix+"-"+name+".png")
func run() -> void:
	if "--small" in OS.get_cmdline_user_args():suffix="small"
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game;await frames()
	await snapshot("entry");await press("开始守望");await snapshot("heroes");await press("Hero_mage");await snapshot("levels");await press("Level_creek")
	check(game.started and game.level_id=="creek" and game.hero.class_id=="mage","menu to selected hero and map")
	await click(game.level_definition.sites[0]);await press("Build_archer")
	check(game.site_tower(0)!=null and game.gold==210,"actual pointer builds and spends exact cost")
	await snapshot("build");await press("Upgrade");check(game.site_tower(0).level==2,"pointer upgrades")
	check(game.hero.shots==0,"UI clicks do not fire weapon")
	await click(Vector2(1200,600),MOUSE_BUTTON_RIGHT);check(game.selected_site==-1,"right click closes context")
	await press("Skill_1");check(game.targeting_slot==1 and game.hero.cooldowns[1]==0,"skill click requests target")
	await click(Vector2(1200,600),MOUSE_BUTTON_RIGHT);check(game.targeting_slot==-1 and game.hero.cooldowns[1]==0,"right click cancels without spending")
	await click(Vector2(1300,580),MOUSE_BUTTON_RIGHT);check(not game.hero.path.is_empty(),"right click commands movement")
	await key(KEY_ESCAPE);check(paused,"escape pauses")
	await snapshot("pause");await key(KEY_ESCAPE);check(not paused,"escape resumes")
	await press("CallWave");check(game.wave_preview,"first call previews");await snapshot("preview")
	await press("CallWave");check(game.phase=="spawn" and game.rewarded,"second call confirms")
	await create_timer(1.2).timeout;await snapshot("battle")
	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(150);game.queue_free();await frames()
	print("V06 WINDOW CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
