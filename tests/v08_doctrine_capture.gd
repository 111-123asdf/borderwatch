extends SceneTree
# Capture the L3 doctrine panel for art/layout review. Not part of the rule suite.
var game: ArenaGame
func _initialize() -> void:call_deferred("run")
func frames() -> void:
	await process_frame
	await process_frame
func click(point: Vector2) -> void:
	root.warp_mouse(point);await frames()
	var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	root.push_input(event,true);await frames()
	event=event.duplicate();event.pressed=false;root.push_input(event,true);await frames()
func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://doctrine-%s.png"%name)
func run() -> void:
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game
	await frames()
	game.progression=ArenaProgression.new("",false)
	game.start_run("knight","forest")
	await frames()
	game.cycle=5;game.gold=6000;game.phase="rest";game.phase_clock=60
	game.build_tower(0,"archer")
	var tower: ArenaTower=game.site_tower(0)
	tower.upgrade();tower.upgrade()
	game.hud.show_context(0)
	await frames()
	await snap("panel")
	var card:=game.hud.context.find_child("Doctrine_sentinel",true,false) as Button
	if card==null:
		push_error("doctrine card missing");game.audio.shutdown();quit(1);return
	await click(card.get_global_rect().get_center())
	await snap("chosen")
	if tower.doctrine_id!="sentinel":
		push_error("doctrine not applied by click");game.audio.shutdown();quit(1);return
	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(120)
	game.queue_free();await frames();quit(0)
