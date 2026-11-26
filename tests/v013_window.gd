extends "res://tests/v06_window.gd"
# Actual window events. Gems/ranks are explicitly injected for UI verification only.
func run() -> void:
	create_timer(100).timeout.connect(func():push_error("V013 WINDOW TIMEOUT");quit(1))
	if "--small" in OS.get_cmdline_user_args():suffix="small"
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);game.campaign.data.gems=9999
	root.add_child(game);current_scene=game;await frames();await snapshot("v013-title")
	check(game.hud.menu.find_children("*","Button",true,false).size()==3,"title has exactly start/settings/exit")
	var menu:=game.hud.menu
	check(root.gui_get_focus_owner()==menu.get_node("StartCampaign"),"title starts with keyboard focus")
	await key(KEY_TAB)
	check(root.gui_get_focus_owner()==menu.get_node("Settings"),"Tab reaches settings")
	await key(KEY_ENTER)
	check(game.hud.has_modal(),"Enter opens settings from the title")
	await press("CloseSettings")
	menu.get_node("Settings").grab_focus()
	await key(KEY_TAB)
	check(root.gui_get_focus_owner()==menu.get_node("ExitGame"),"Tab reaches exit")
	await key(KEY_TAB)
	check(root.gui_get_focus_owner()==menu.get_node("StartCampaign"),"Tab cycles back to start")
	game.campaign.data.cleared["saltport"]=true
	game.campaign.data.levels["gunner"]=3
	game.campaign.select_hero("gunner")
	game.hud.frontend.entry()
	await frames()
	check(game.hud.menu.get_node("TitleProgress").text.ends_with("1 / 6"),"Saltport counts toward the six-stage total")
	var hero_label:=game.hud.menu.find_children("*","Label",false,false).any(func(label):return label.text=="%s · LV.3"%ArenaDefinitions.HEROES["gunner"].name)
	check(hero_label,"title displays current five-hero roster selection and permanent level")
	await snapshot("v013-title-progress")
	game.campaign.select_hero("lord")
	game.campaign.data.levels["gunner"]=1
	game.campaign.data.cleared["saltport"]=false
	await key(KEY_ENTER)
	check(game.hud.frontend.page_id=="world","Enter opens the world map from the title")
	await snapshot("v013-world")
	check(game.hud.menu.find_child("WorldDock",true,false)==null,"long full-width dock removed")
	var tray: Control=game.hud.menu.find_child("WorldLoadout",true,false)
	check(tray!=null and tray.size.x<600,"equipped tray stays compact")
	await press("Level_forest");await snapshot("v013-stage");await key(KEY_ESCAPE)
	await press("HeroHall");var menu_id:=game.hud.menu.get_instance_id();var scenery:=game.hud.menu.find_child("Scenery",true,false).get_instance_id();var card_id:=game.hud.frontend.card.get_instance_id()
	check(game.hud.menu.find_children("*","CPUParticles2D",true,false).is_empty(),"hall has no screen dust")
	for identity in ArenaDefinitions.HERO_IDS:
		await press("Hall_"+identity)
		check(game.hud.menu.get_instance_id()==menu_id and game.hud.menu.find_child("Scenery",true,false).get_instance_id()==scenery,"hero switch preserves shell/background "+identity)
		check(game.hud.frontend.card.get_instance_id()==card_id and is_equal_approx(game.hud.menu.modulate.a,1),"hero card remains stable, no full-screen fade "+identity)
		check(game.hud.frontend.card.find_child("CardClip",true,false).clip_contents,"portrait contained by clipped card")
		check(not game.hud.frontend.skill_body.text.is_empty(),"skill description visible without hover")
		for index in range(5):check(not (game.hud.menu.find_child("HeroRank_"+str(index+1),true,false) is Button),"rank stars are display-only")
		await press("HeroSkill_1");check(game.hud.frontend.skill_title.text.begins_with(str(ArenaDefinitions.HEROES[identity].ultimate)),"click updates ultimate description "+identity)
		await press("HeroPassive");check(game.hud.frontend.skill_title.text=="职业天赋","passive button actually changes detail")
		await snapshot("v013-hero-"+identity)
	await press("Hall_gunner");var gold:=game.campaign.gems();await press("UpgradeHero")
	check(game.campaign.level("gunner")==2 and game.campaign.gems()==gold-2,"upgrade charges actual configured price")
	check(game.hud.frontend.card.get_instance_id()==card_id and game.hud.menu.get_instance_id()==menu_id,"upgrade does not recreate card or page")
	check(game.campaign.selected_hero()=="lord","browsing/upgrading does not silently equip")
	await press("EquipHero");check(game.campaign.selected_hero()=="gunner","explicit equip updates saved selection")
	await press("Back");await press("TowerHall");menu_id=game.hud.menu.get_instance_id();scenery=game.hud.menu.find_child("Scenery",true,false).get_instance_id()
	for identity in ArenaDefinitions.TOWER_IDS:
		await press("Tower_"+identity)
		for tier in range(1,4):
			await press("TowerTier_"+str(tier));check(game.hud.frontend.preview_tier==tier,"tier really selects art "+identity+str(tier))
			check(game.hud.menu.get_instance_id()==menu_id and game.hud.menu.find_child("Scenery",true,false).get_instance_id()==scenery,"tier/roster preserve shell")
		var doctrines := ArenaDoctrines.for_tower(identity)
		for route in range(doctrines.size()):
			await press("TowerRoute_"+str(route))
			var doctrine: Dictionary = doctrines[route]
			check(game.hud.frontend.route_name.text == doctrine.name and game.hud.frontend.route_body.text == ArenaDoctrines.field_summary(doctrine.id), "workshop presents the selected specialization " + str(doctrine.id))
			var enhancements := ArenaDoctrines.enhancements(doctrine.id)
			var cards := game.hud.frontend.enhancement_list
			check(cards.get_child_count() == enhancements.size(), "workshop shows only the selected specialization's enhancements " + str(doctrine.id))
			for index in range(enhancements.size()):
				var card := cards.get_node("Enhancement_%d" % index)
				check(card.get_node("Title").text == enhancements[index].name and card.get_node("Effect").text == enhancements[index].summary, "workshop matches the enhancement data " + str(doctrine.id))
		check(game.campaign.tower_doctrine(identity) == ArenaDoctrines.AUTO_DEFAULT[identity], "previewing does not change the saved automatic choice")
		await snapshot("v013-tower-"+identity)
	await press("Back")
	# Keys are real input events: Space retired, E releases the unlocked ultimate.
	game.campaign.data.levels["lord"]=5;game.campaign.select_hero("lord")
	await press("Level_forest");await press("Deploy");await key(KEY_SPACE)
	check(game.hero.cooldowns[1]==0,"retired Space no longer casts")
	await key(KEY_E);check(game.hero.cooldowns[1]>0,"E casts actual ultimate")
	await snapshot("v013-battle-E")
	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(150);game.queue_free();await frames()
	print("V013 WINDOW CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
