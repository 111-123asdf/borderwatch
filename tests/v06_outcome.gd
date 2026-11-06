extends SceneTree
var game: ArenaGame
var phase:=0
var elapsed:=0.0
var waiting:=false
var failures:=0
func _initialize() -> void:call_deferred("run")
func run() -> void:
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game;await process_frame
	game.progression=ArenaProgression.new("",false);game.start_run("mage","creek")
func _process(delta: float) -> bool:
	if waiting or game==null:return false
	elapsed+=delta
	if phase==0:
		if game.choice_open:game.choose_perk(game.choices[0])
		if game.game_over:
			if game.victory or game.core_health!=0:failures+=1
			print("NATURAL FAILURE elapsed=",int(elapsed)," wave=",game.cycle," core=",game.core_health)
			waiting=true;restart.call_deferred()
		elif elapsed>650:failures+=1;waiting=true;done.call_deferred()
	return false
func restart() -> void:
	game.restart_run();await process_frame;await process_frame;await process_frame;game=current_scene
	if not game.started or game.level_id!="creek" or game.hero.class_id!="mage" or game.gold!=280 or game.hero.level!=1 or game.cycle!=1:failures+=1
	game.return_to_menu();await process_frame;await process_frame;game=current_scene
	if game.started or not is_instance_valid(game.hud.menu):failures+=1
	await done()
func done() -> void:
	game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	print("V06 OUTCOME CHECKS: 3, FAILURES: ",failures);quit(0 if failures==0 else 1)
