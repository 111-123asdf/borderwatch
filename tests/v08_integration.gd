extends SceneTree
# Explicit fixtures for the combined main UI and PR10 gameplay. Not a playthrough.
var game: ArenaGame
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("INTEGRATION FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func frames() -> void:
	await process_frame;await process_frame
func run() -> void:
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game
	await frames()
	game.hud.frontend.levels();await frames()
	check(game.hud.root.find_child("被动图鉴",true,false)==null,"legacy world-map codex entry removed")
	check(game.hud.root.find_child("英雄训练",true,false)==null,"retired training stays removed")
	game.start_run("lord","creek");await frames()
	check(not paused and game.passive_offers.is_empty() and game.rift_domain!=null,"start_run deploys directly into dual-domain combat")
	game.gain_run_xp(120.0);await frames()
	check(not paused and game.passive_offers.is_empty() and game.passive_engine.pending_ups==1,"level up queues without interrupting combat")
	check(game.open_pending_passive_choice(),"open_pending_passive_choice opens queued passive modal");await frames()
	check(paused and game.passive_offers.size()==3,"level up opens 3 passive choices")
	var first_id := str(game.passive_offers[0].id)
	check(game.hud.modal.find_child("PassiveOffer_"+first_id,true,false)!=null,"passive card renders")
	check(game.hud.modal.find_child("PassiveDetail_"+first_id,true,false)!=null,"detail button renders")
	var detail_btn := game.hud.modal.find_child("PassiveDetail_"+first_id,true,false) as Button
	detail_btn.pressed.emit();await frames()
	var pop := game.hud.modal.find_child("PassiveDetailPopover",true,false) as Control
	check(pop!=null and pop.visible and paused and game.passive_offers.size()==3,"detail popover opens without selecting passive")
	check(game.choose_passive(first_id) and not paused,"choosing passive unpauses battle")
	check(game.passive_engine.rank(first_id)==1,"chosen passive persisted in ArenaPassiveEngine")
	game.hud.update_clock=0.0;game.hud._process(0.1);await frames()
	check(game.hud.root.find_child("OwnedPassive_"+first_id,true,false)!=null,"owned passive medallion strip renders chosen passive")
	game.hud.refresh_objective()
	var signature:=game.hud.last_objective
	game.hud.refresh_objective()
	check(game.hud.last_objective==signature,"objective stays coherent")
	game.hud.show_pause();await frames()
	check(paused and game.hud.has_modal(),"pause opens cleanly")
	check(game.hud.modal.find_child("被动图鉴",true,false)==null,"pause removes legacy codex button")
	game.hud.resume();await frames()
	check(not paused and not game.hud.has_modal(),"resume closes pause cleanly")
	game.built=1;game.cycle=2
	check(game.hud.objective_state().title.contains("第 2 轮"),"guide points to the next round")
	game.running=false;game.audio.shutdown();paused=false;await frames();OS.delay_msec(150);game.queue_free();await frames()
	print("V08 INTEGRATION CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
