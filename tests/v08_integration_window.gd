extends "res://tests/v06_window.gd"
# Visual fixtures inject gold/wave/reward availability; not a normal-resource run.
func run() -> void:
	create_timer(60.0).timeout.connect(func():push_error("INTEGRATION WINDOW TIMEOUT");quit(1))
	if "--small" in OS.get_cmdline_user_args():suffix="small"
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);game.campaign.data.levels["lord"]=5
	root.add_child(game);current_scene=game;await frames()
	await press("StartCampaign")
	check(game.hud.root.find_child("被动图鉴",true,false)==null,"world map removes legacy codex dock")
	await press("Level_forest");await press("Deploy")
	check(not paused and game.started,"deploy launches into battle without opening curse cards")
	game.gain_run_xp(120.0);await frames()
	check(not paused and game.passive_engine.pending_ups==1,"level up queues silently on PassiveReadyBadge")
	await press("PassiveReadyBadge")
	check(paused and game.passive_offers.size()==3,"[Tab]/badge opens 3 passive cards")
	var first_passive := str(game.passive_offers[0].id)
	await press("PassiveDetail_"+first_passive)
	var pop := game.hud.modal.find_child("PassiveDetailPopover",true,false) as Control
	check(pop!=null and pop.visible and paused,"PassiveDetail opens popover without selecting card")
	await snapshot("integration-choice")
	OS.delay_msec(600);await frames()
	await press("PassiveOffer_"+first_passive)
	check(not paused and game.passive_engine.rank(first_passive)==1,"clicking passive card applies and unpauses")
	check(game.hud.root.find_child("OwnedPassive_"+first_passive,true,false)!=null,"bottom-right badge shows selected passive")
	game.gold=6000;game.cycle=5;game.phase_clock=60
	await click(game.level_definition.sites[0]);await press("Build_archer")
	var tower:=game.site_tower(0);tower.finish_project()
	tower.gain_auto_xp(800.0)
	check(tower!=null and tower.level==3 and not tower.awaiting_doctrine,"automated tower levels up to L3 automatically without doctrine popups")
	await snapshot("integration-auto-tower")
	game.hud.close_context();await frames()
	await key(KEY_H);check(paused,"handbook pauses")
	check(game.hud.modal.find_child("被动图鉴",true,false)==null,"pause handbook removes legacy codex button")
	await snapshot("integration-pause")
	await key(KEY_ESCAPE);check(not paused and not game.hud.has_modal(),"escape resumes handbook")
	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(150);game.queue_free();await frames()
	print("V08 INTEGRATION WINDOW CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
