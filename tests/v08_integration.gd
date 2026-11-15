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
	check(game.hud.root.find_child("被动图鉴",true,false)!=null,"world-map dock exposes the codex")
	check(game.hud.root.find_child("英雄训练",true,false)==null,"retired training stays removed")
	game.hud.show_codex();await frames()
	check(paused and game.hud.has_modal(),"codex blocks gameplay input")
	game.hud.codex._close();await frames()
	check(not paused and not game.hud.has_modal(),"closing entry codex restores entry state")
	game.start_run("knight","creek")
	game.hud.refresh_objective()
	var signature:=game.hud.last_objective
	check(game.hero.apply_perk("lifesteal"),"new card can be acquired")
	game.hud.refresh_objective()
	check(game.hud.last_objective==signature and game.hud.build_label.text.contains(str(ArenaPerks.card("lifesteal").name)),"growth summary refreshes without changing the objective")
	for offset in range(0,ArenaPerks.CARDS.size(),3):
		var keys: Array[String]=[]
		for index in range(offset,mini(offset+3,ArenaPerks.CARDS.size())):keys.append(str(ArenaPerks.CARDS[index].id))
		game.hud.show_choices(keys)
		for key in keys:check(game.hud.modal.find_child("Perk_"+key,true,false)!=null,"new UI renders card "+key)
	game.hud.close_modal()
	game.hud.show_pause();var pause_modal:=game.hud.modal
	game.queue_choice();await frames()
	check(paused and not game.choice_open and game.choice_queue==1 and game.hud.modal==pause_modal,"queued reward does not replace the pause menu")
	game.hud.show_codex();await frames();game.hud.codex._close();await frames()
	check(paused and game.hud.modal==pause_modal and not game.choice_open,"closing pause codex preserves pause and pending reward")
	game.hud.resume();await frames()
	check(game.choice_open and paused,"resume hands off to queued growth")
	check(game.choose_perk(game.choices[0]),"queued growth can be chosen")
	await frames()
	game.queue_camp_reward(0);game.queue_choice();await frames()
	check(game.camp_reward_open and not game.choice_open,"camp reward has priority without losing growth")
	var camp_modal:=game.hud.modal
	game.hud.show_pause();game.hud.show_codex()
	check(game.hud.modal==camp_modal and not is_instance_valid(game.hud.codex),"pause and codex cannot dismiss a camp reward")
	check(game.choose_camp_reward(0,"hero"),"camp hero reward is accepted")
	await frames()
	check(game.choice_open and game.choice_queue==2,"camp hero reward and queued growth both survive")
	check(game.choose_perk(game.choices[0]),"first stacked choice works")
	await frames()
	check(game.choice_open and game.choice_queue==1,"second stacked choice opens")
	check(game.choose_perk(game.choices[0]),"second stacked choice works")
	await frames()
	check(not paused and not game.hud.has_modal(),"all rewards close cleanly")
	game.built=1;game.cycle=2
	check(str(game.hud.objective_state().body).contains("第4波"),"guide describes new camp deadline")
	game.camps[0].overdue=true
	check(str(game.hud.objective_state().title).contains("图腾"),"guide reflects global camp pressure")
	check(game.hero.apply_perk("lifesteal") and game.hero.mod("shield_cap")>0,"approved temporary absorption effect remains available")
	game.running=false;game.audio.shutdown();paused=false;await frames();OS.delay_msec(150);game.queue_free();await frames()
	print("V08 INTEGRATION CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
