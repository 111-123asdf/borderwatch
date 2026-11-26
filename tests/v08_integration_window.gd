extends "res://tests/v06_window.gd"
# Visual fixtures inject gold/wave/reward availability; not a normal-resource run.
func run() -> void:
	create_timer(60.0).timeout.connect(func():push_error("INTEGRATION WINDOW TIMEOUT");quit(1))
	if "--small" in OS.get_cmdline_user_args():suffix="small"
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);game.campaign.data.levels["lord"]=5
	root.add_child(game);current_scene=game;await frames()
	await press("StartCampaign")
	await press("PassiveHall")
	check(game.hud.frontend.page_id == "passives" and game.hud.menu.find_children("Passive_*","Button",true,false).size() == 29, "world map opens a directory with all active passives")
	await press("Passive_spellbreak")
	var passive_title := game.hud.menu.find_child("PassiveTitle",true,false) as Label
	check(passive_title.text == "断咏" and game.hud.menu.find_child("PassiveRank_3",true,false) != null, "passive browser shows the selected card and its evolution")
	await snapshot("integration-passive-library")
	await press("Back")
	await press("TowerHall")
	await press("TowerRoute_1")
	check(game.hud.frontend.route_name.text == "连弩阵" and game.campaign.tower_doctrine("archer") == "sentinel", "an alternate specialization can be previewed independently")
	await press("EquipDoctrine")
	check(game.campaign.tower_doctrine("archer") == "repeater", "setting the automatic specialization saves it")
	await snapshot("integration-tower-workshop")
	await press("Back")
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
	game.gold=315;game.cycle=5;game.phase="rest";game.phase_clock=60
	await click(game.level_definition.sites[0]);await press("Build_archer")
	var tower:=game.site_tower(0)
	await create_timer(3.0*ArenaTowerTrial.BUILD_TIME+0.2).timeout
	check(tower!=null and tower.level==3 and tower.doctrine_id=="repeater" and not paused,"the saved specialization applies automatically at L3")
	var spec := game.hud.context.get_node("TowerSpecialization")
	var growth := game.hud.context.get_node("TowerEnhancements")
	check(spec.get_node("Title").text == "连弩阵" and growth.has_node("Enhancement_0/Status"), "battle separates the active specialization from enhancement status")
	var price: int = ArenaDoctrines.ENHANCEMENT_PRICES[0]
	game.gold = price - 1
	await create_timer(0.16).timeout
	check(tower.project_level == 0 and tower.unlocked_enhancements == 0, "insufficient gold leaves the enhancement pending")
	game.gold = price
	await create_timer(0.16).timeout
	check(tower.project_level > ArenaTower.MAX_LEVEL and tower.unlocked_enhancements == 0 and game.gold == 0, "available gold starts enhancement construction automatically")
	await create_timer(ArenaTowerTrial.BUILD_TIME).timeout
	check(tower.unlocked_enhancements == 1 and is_equal_approx(tower.doc_mod("triple_chance"),0.43), "the enhancement activates when construction completes")
	check(game.hud.context.get_node("TowerEnhancements/Enhancement_0/Status").text.begins_with("已生效"), "battle shows the newly active enhancement")
	check(game.hud.root.find_child("ChargeAegis",true,false)==null, "the former shield button is absent in battle")
	await snapshot("integration-auto-tower")
	game.hud.close_context();await frames()
	await key(KEY_H);check(paused,"handbook pauses")
	await snapshot("integration-pause")
	await key(KEY_ESCAPE);check(not paused and not game.hud.has_modal(),"escape resumes handbook")
	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(150);game.queue_free();await frames()
	print("V08 INTEGRATION WINDOW CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
