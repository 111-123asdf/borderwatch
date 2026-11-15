extends SceneTree
# Actual funded preview entry; same profile mode shipped in Play.bat, no combat injection.
class DemoPointer extends Node2D:
	var pulse:=0.0
	func _process(delta: float) -> void:pulse=maxf(0,pulse-delta);queue_redraw()
	func _draw() -> void:
		draw_circle(Vector2.ZERO,4,Color("fff2c9"));draw_arc(Vector2.ZERO,10+10*pulse,0,TAU,32,Color(1.0,0.84,0.45,0.75),2,true)
var pointer: DemoPointer
var game: ArenaGame
var failures:=0
func _initialize() -> void:call_deferred("run")
func frames() -> void:await process_frame;await process_frame
func press(key_name: String) -> void:
	var b:=game.hud.root.find_child(key_name,true,false) as Button
	if b==null:push_error("Demo button missing: "+key_name);failures+=1;quit(1);return
	await click(b.get_global_rect().get_center())
func click(point: Vector2,which:=MOUSE_BUTTON_LEFT) -> void:
	var motion:=pointer.create_tween();motion.tween_property(pointer,"position",point,0.22).set_trans(Tween.TRANS_SINE);await motion.finished
	pointer.pulse=1.0
	var event:=InputEventMouseMotion.new();event.position=point;event.global_position=point;root.push_input(event,true)
	var button:=InputEventMouseButton.new();button.position=point;button.button_index=which;button.pressed=true;root.push_input(button,true)
	button=button.duplicate();button.pressed=false;root.push_input(button,true);await frames()
func step(key_name: String,pause_time:=1.5) -> void:
	await press(key_name);await create_timer(pause_time).timeout
func run() -> void:
	create_timer(90.0).timeout.connect(func():push_error("UI DEMO TIMEOUT");quit(1))
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game
	if game.campaign.path!=ArenaCampaign.PLAYTEST_PATH:push_error("Recording must use --playtest");quit(1);return
	var overlay:=CanvasLayer.new();overlay.layer=100;overlay.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(overlay);pointer=DemoPointer.new();pointer.position=Vector2(800,680);overlay.add_child(pointer)
	await create_timer(1.6).timeout;await capture("标题")
	await step("StartCampaign",1.5);await capture("世界地图");await step("HeroHall");await capture("骑士大厅")
	await step("Hall_ranger");await capture("游侠大厅");await step("HeroSkill_1",1.0);await step("HeroPassive",1.0)
	for i in range(4):await step("UpgradeHero",.65)
	await step("EquipHero",.8);await capture("游侠满级")
	await step("Hall_mage",1.1);await capture("法师大厅");await step("Back",.8)
	await step("TowerHall",.8);await step("Tower_mage",.8);await step("TowerTier_2",.7);await step("TowerTier_3",.8)
	for i in range(3):await step("TowerRoute_"+str(i),1.0)
	await capture("防御塔工坊");await step("Tower_barracks",.8);await step("TowerRoute_1",1.0);await step("Back",.8)
	await step("被动图鉴",1.2);await capture("成长图鉴");await step("CodexCard_chain",1.0);await step("CodexFilter_evo",1.0);await step("关闭图鉴",.8)
	await step("Level_forest",1.4);await capture("关卡预览");await step("CloseStage",.6);await step("Level_creek",1.2);await step("Deploy",1.6)
	var key:=InputEventKey.new();key.keycode=KEY_E;key.pressed=true;root.push_input(key,true);key=key.duplicate();key.pressed=false;root.push_input(key,true)
	await create_timer(3).timeout
	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(150);game.queue_free();overlay.queue_free();await frames();quit(0 if failures==0 else 1)
func capture(title: String) -> void:
	await RenderingServer.frame_post_draw
	var folder:=ProjectSettings.globalize_path("user://v013-preview");DirAccess.make_dir_recursive_absolute(folder);root.get_texture().get_image().save_png(folder+"/"+title+".png")
