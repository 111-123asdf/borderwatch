extends "res://tests/v06_window.gd"
# Visual fixtures inject gold/wave/reward availability; not a normal-resource run.
func run() -> void:
	create_timer(60.0).timeout.connect(func():push_error("INTEGRATION WINDOW TIMEOUT");quit(1))
	if "--small" in OS.get_cmdline_user_args():suffix="small"
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);game.campaign.data.levels.knight=5
	root.add_child(game);current_scene=game;await frames()
	await press("StartCampaign");await press("被动图鉴");check(is_instance_valid(game.hud.codex) and paused,"pointer opens codex from world map")
	await press("CodexCard_power")
	check(game.hud.codex.selected_id=="power","codex card is selectable")
	await snapshot("integration-codex");await press("关闭图鉴")
	check(not paused and not game.hud.has_modal(),"pointer closes entry codex")
	await press("Level_forest");await press("Deploy")
	game.gold=6000;game.cycle=5;game.phase_clock=60
	await click(game.level_definition.sites[0]);await press("Build_archer");await press("Upgrade");await press("Upgrade")
	var tower:=game.site_tower(0)
	check(tower!=null and tower.awaiting_doctrine,"pointer opens level-three doctrine choice")
	await snapshot("integration-doctrine");await press("Doctrine_sentinel")
	check(tower.doctrine_id=="sentinel" and not tower.awaiting_doctrine,"pointer chooses doctrine")
	game.hud.close_context();game.queue_choice();await frames()
	check(game.choice_open,"new card choice opens")
	var key: String=game.choices[0];await snapshot("integration-choice");await press("Perk_"+key)
	check(game.hero.perk(key)==1 and not game.choice_open,"pointer applies new card")
	await key(KEY_H);check(paused,"handbook pauses")
	await press("被动图鉴");await key(KEY_ESCAPE)
	check(paused and not is_instance_valid(game.hud.codex),"escape closes codex into paused handbook")
	await key(KEY_ESCAPE);check(not paused and not game.hud.has_modal(),"escape resumes handbook")
	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(150);game.queue_free();await frames()
	print("V08 INTEGRATION WINDOW CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
