extends SceneTree
# Explicit state fixtures for UI dimensions, bridge drainage and repeated reward guards.
var checks:=0
var failures:=0
func check(value: bool,message: String) -> void:
	checks+=1
	if not value:failures+=1;push_error("V017 FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game: ArenaGame=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false)
	root.add_child(game);current_scene=game;await process_frame;game.start_run("knight","ruins");await process_frame
	check(game.hud.root.get_node("HeroPod").size.x<=300,"hero HUD compact")
	check(game.hud.root.get_node("CorePod").size.x<=210,"core HUD compact")
	check(game.hud.wave_button.size==Vector2(48,48),"small icon retains usable click area")
	check(game.altars.size()==1 and not game.has_method("toggle_altar_mode"),"single automatic altar has no switching interface")
	check(game.level_definition.blocked.size()>40,"painted abyss has physical collision")
	check(game.ground.material!=null,"painted abyss shimmer is engine-rendered")
	var offset:=game.routes[1].get_closest_offset(Vector2(game.level_definition.bridge_gate.fork))
	var unit:=game.spawn_enemy("construct_hound",1,offset+2)
	game.enemy_road(unit);game.trigger_bridge_gate();game._tick_stage3_systems(0.5)
	check(game.bridge_lift==0.0,"bridge waits for committed short-route unit")
	unit.progress=game.bridge_normal_curve.get_closest_offset(game.bridge_gate_point())+100
	unit.position=game.enemy_road(unit).sample_baked(unit.progress,true);game._tick_stage3_systems(0.5)
	check(game.bridge_lift>0.9,"empty bridge raises after drainage")
	check(not game.walkable(game.bridge_gate_point()),"raised deck blocks hero navigation")
	game.bridge_active_clock=0.001;game._tick_stage3_systems(1.0)
	check(not game.bridge_sealed and game.bridge_lift==0 and game.walkable(game.bridge_gate_point()),"expired bridge lowers and restores navigation")
	var late:=game.spawn_enemy("construct_hound",1,offset-1)
	game.enemy_road(late);check(late.bridge_branch=="","approach remains undecided before fork")
	late.progress=offset+1;game.enemy_road(late);check(late.bridge_branch=="short","arrival after reopening chooses short route")
	game.remove_enemy(unit);game.remove_enemy(late)
	game.gold=100;game.phase="rest";game.phase_clock=15;game.rest_duration=16;game.wave_preview=false;game.rewarded=false
	game.request_wave();check(game.gold==100,"first click only previews")
	game.request_wave();check(game.gold<=112 and game.gold>100,"confirmed early wave pays at most 12")
	var paid:=game.gold;game.request_wave();check(game.gold==paid,"cannot receive early reward twice")
	check(game.world_size()==Vector2(2000,1125),"large battlefield is independent of viewport dimensions")
	game.camera.toggle_overview();check(game.camera.overview and game.camera.zoom.x<1,"overview fits whole map")
	game.camera.focus(Vector2(1870,310));check(not game.camera.overview and game.camera.zoom==Vector2.ONE,"focus restores tactical scale")
	var screen:=game.world_to_hud(Vector2(1870,310))
	check(Rect2(0,0,1600,900).has_point(screen),"offscreen site can be brought into view")
	var back:=game.get_viewport().get_canvas_transform().affine_inverse()*screen
	check(back.distance_to(Vector2(1870,310))<0.01,"camera projection preserves pointer coordinates")
	var camera_before:=game.camera.position
	var drag:=InputEventMouseButton.new();drag.button_index=MOUSE_BUTTON_MIDDLE;drag.pressed=true;game.camera._input(drag)
	var motion:=InputEventMouseMotion.new();motion.relative=Vector2(180,0);game.camera._input(motion)
	drag.pressed=false;game.camera._input(drag)
	check(game.camera.position.x<camera_before.x,"middle drag pans the camera")
	check(game.camera.position.x>=800 and game.camera.position.x<=1200,"pan respects map bounds")
	var camp_remaining: int=game.camps[1].remaining
	game.cycle=4;game.phase="spawn";game.siege.tick(0.01)
	check(game.siege.warned and is_instance_valid(game.siege.guard),"wave four introduces a charging breacher")
	check(not game.breach_open and not game.walkable(game.siege.point()),"sealed road is physically closed")
	game.siege.guard.take_hit(99999,1,"hero");game.siege.tick(0.01)
	check(game.siege.interrupted and game.camps[1].remaining==camp_remaining,"killing breacher delays breach without corrupting camp progress")
	game.siege.tick(15.0);check(not game.breach_open,"early kill buys the remainder of wave four")
	game.cycle=5;game.siege.tick(11.0);check(not game.breach_open,"delayed breach still gives twelve-second warning")
	game.siege.tick(1.1);check(game.breach_open and game.siege.opened,"physical breakthrough opens new road")
	check(game.walkable(game.siege.point()),"opened road restores navigation")
	var arrivals:=0;var earliest:=INF
	for packet in game.spawn_queue:
		if int(packet.route)==3:arrivals+=1;earliest=minf(earliest,float(packet.at))
	check(arrivals==5 and earliest>=game.wave_elapsed+9.9,"new route gives ten seconds before first arrivals")
	game.siege.open_passage();var after:=0
	for packet in game.spawn_queue:
		if int(packet.route)==3:after+=1
	check(after==arrivals,"repeated opening cannot duplicate reinforcements")
	check(game.siege.open_layer!=null and game.siege.open_layer.modulate.a>0,"road reveal is layered and animated")
	game.running=false;game.audio.shutdown();await process_frame
	# Fixed-FPS tests can advance simulated timers faster than the audio mix thread.
	# Give stopped voices real wall-clock time before destroying their resources.
	OS.delay_msec(200);game.queue_free();await process_frame;await process_frame;await process_frame;await process_frame
	print("V017 RULE CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
