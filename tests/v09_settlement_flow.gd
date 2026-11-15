extends SceneTree
# Forced outcome fixture tests actual disk save + scene reload, not a natural victory.
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("SETTLEMENT FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func frames() -> void:
	await process_frame;await process_frame;await process_frame
func run() -> void:
	if not OS.get_environment("APPDATA").replace("\\","/").contains("/test-results/"):
		push_error("Settlement fixture requires isolated APPDATA under test-results");quit(1);return
	var legacy: Dictionary={}
	for name in ["arena_progression_v1.cfg","arena_progression_v2.cfg"]:
		legacy[name]=FileAccess.get_file_as_bytes("user://"+name) if FileAccess.file_exists("user://"+name) else PackedByteArray()
	var game: ArenaGame=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game;await frames()
	var before:=game.campaign.gems();var expected:=6 if game.campaign.data.cleared.forest else 8
	game.start_run("knight","forest");game.cycle=8;game.finish(true)
	check(bool(game.settlement.ok) and game.campaign.gems()==before+expected,"result credits the saved wallet")
	var balance:=game.campaign.gems();game.finish(true)
	check(game.campaign.gems()==balance,"reopening finish cannot duplicate reward")
	game.open_hero_hall();await frames();game=current_scene as ArenaGame
	check(game!=null and not game.started and game.hud.root.find_child("UpgradeHero",true,false)!=null,"result opens the hero hall through a real scene reload")
	check(game.campaign.gems()==balance,"saved gems survive hall reload")
	var rank:=game.campaign.level("knight");var cost:=game.campaign.price("knight")
	if rank<5 and balance>=cost:
		game.hud.frontend.upgrade_hero()
		check(game.campaign.level("knight")==rank+1 and game.campaign.gems()==balance-cost,"hall upgrade saves exact new level and cost")
		balance-=cost;rank+=1
	game.return_to_menu();await frames();game=current_scene as ArenaGame
	check(game.campaign.gems()==balance and game.campaign.level("knight")==rank,"menu reload preserves the upgrade")
	game.start_run("knight","forest")
	check(game.hero.meta_level==rank and game.hero.skill_unlocked(0)==(rank>=2),"next deployment uses the saved hero unlocks")
	for name in legacy:
		var now:=FileAccess.get_file_as_bytes("user://"+str(name)) if FileAccess.file_exists("user://"+str(name)) else PackedByteArray()
		check(now==legacy[name],"legacy save bytes unchanged "+str(name))
	game.running=false;game.audio.shutdown();paused=false;await frames();OS.delay_msec(150);game.queue_free();await frames()
	print("V09 SETTLEMENT CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
