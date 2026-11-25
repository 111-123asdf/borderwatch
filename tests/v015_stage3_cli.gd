extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V015 CLI FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var game: ArenaGame=load("res://scenes/arena.tscn").instantiate()
	root.add_child(game);current_scene=game
	await process_frame;await process_frame;await process_frame
	check(game.started,"--stage=ruins auto-starts run on boot")
	check(game.level_id=="ruins","--stage=ruins loads stage 5 ruins directly")
	check(game.total_waves()==5 and game.rift_domain.theme_key=="void","v0.30 dual-domain void rift active via CLI launch")
	check(game.campaign.gems()==9999,"playtest currency active")
	check(game.routes.size()==3,"--stage=ruins loads 3 routes")
	check(game.level_definition.sites.size()==12,"--stage=ruins loads 12 sites")
	check(game.tilemap_scene==null and game.ground.visible,"--stage=ruins uses current pixel terrain, not the retired TileMap")
	check(game.atmosphere!=null,"--stage=ruins installs ArenaAtmosphere")
	game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(100);game.queue_free();await process_frame
	print("V015 STAGE3 CLI CHECKS: %d, FAILURES: %d"%[checks,failures])
	quit(0 if failures==0 else 1)
