extends SceneTree
# Fixtures for the v0.20 passive prototype (data, draw, ranks, reroll).
var checks:=0
var failures:=0
var game: ArenaGame
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V020 PASSIVES FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check(ArenaPassives.CARDS.size()==12,"card count 12")
	var rng:=RandomNumberGenerator.new();rng.seed=1234
	var ranks: Dictionary={}
	var draw:=ArenaPassives.draw(rng,ranks,3)
	check(draw.size()==3,"draw 3")
	check(draw[0]!=draw[1] and draw[1]!=draw[2] and draw[0]!=draw[2],"draw unique")
	for id in draw:check(not ArenaPassives.card(id).is_empty(),"card exists "+id)
	for id in ArenaPassives.CARDS:
		ranks[str(id.id)]=2
	check(ArenaPassives.draw(rng,ranks,3).is_empty(),"maxed pool empty")
	ranks.clear()
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);await process_frame
	game.start_run("knight","forest")
	game.passive_lab=true
	game.choice_open=true;game.choices.assign(["chain","echo","combo"])
	check(game.choose_passive("chain"),"choose chain")
	check(game.passive_rank("chain")==1,"chain rank 1")
	check(not game.choice_open,"modal closed")
	game.choice_open=true;game.choices.assign(["chain","echo"])
	game.choose_passive("chain")
	check(game.passive_rank("chain")==2,"chain rank 2")
	game.choice_open=true;game.choices.assign(["chain"])
	game.choose_passive("chain")
	check(game.passive_rank("chain")==2,"rank capped at 2")
	game.passive_reroll_used=false
	game.choice_open=true;game.choices.assign(["echo"])
	check(game.reroll_passives(),"reroll works")
	check(game.passive_reroll_used,"reroll consumed")
	check(not game.reroll_passives(),"reroll only once")
	game.choice_queue=0;game.choice_open=false;game.running=false
	game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	paused=false
	print("V020 PASSIVES CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
