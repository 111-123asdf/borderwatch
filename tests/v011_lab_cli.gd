extends SceneTree
# Real CLI entry and scene reload, isolated APPDATA. Never points at a user profile.
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("LAB CLI FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	create_timer(30).timeout.connect(func():push_error("LAB CLI TIMEOUT");quit(1))
	var game: ArenaGame=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame;await process_frame;await process_frame
	check(game.feel_lab and game.started and game.phase=="lab","CLI opens shared-runtime lab")
	check(game.hero.meta_level==5 and not game.campaign.persistent,"lab level is explicitly in-memory")
	check(not FileAccess.file_exists(ArenaCampaign.SAVE_PATH),"lab start never writes campaign")
	var id:=game.get_instance_id();game.restart_run();await process_frame
	check(current_scene.get_instance_id()==id and game.hero.health==game.hero.max_health,"restart resets without a second runtime")
	game.return_to_menu();await process_frame;await process_frame;await process_frame
	game=current_scene
	check(not game.feel_lab and not game.started and game.campaign.persistent,"return drops fixture and opens normal profile")
	check(game.campaign.level("knight")==1 and game.campaign.gems()==0,"fixture ranks and rewards do not leak into normal profile")
	check(game.hud.frontend.page_id=="world","return destination is actual world map")
	check(not FileAccess.file_exists(ArenaCampaign.SAVE_PATH),"return preserves absence of save until a real user action")
	game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	print("V011 LAB CLI CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
