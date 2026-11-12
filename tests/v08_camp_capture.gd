extends SceneTree
# Capture camp aura, guards and the three-way reward for art/layout review.
var game: ArenaGame
func _initialize() -> void:call_deferred("run")
func frames() -> void:
	await process_frame
	await process_frame
func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://camp-%s.png"%name)
func run() -> void:
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game
	await frames()
	game.progression=ArenaProgression.new("",false)
	game.start_run("knight","forest")
	await frames()
	game.cycle=2;game.phase="rest";game.phase_clock=10;game.begin_wave()
	await frames()
	await snap("aura")
	for enemy in game.enemies.duplicate():
		if enemy.is_guard and enemy.camp_id==0:enemy.take_hit(99999,0,"hero")
	await frames()
	await snap("reward")
	var card:=game.hud.modal.find_child("CampReward_token",true,false) as Button
	if card==null:
		push_error("camp reward card missing");game.audio.shutdown();quit(1);return
	game.choose_camp_reward(0,"token")
	await frames()
	await snap("token")
	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(120)
	game.queue_free();await frames();quit(0)
