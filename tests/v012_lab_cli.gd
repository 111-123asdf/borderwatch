extends SceneTree
# Real reload with an existing isolated profile; compare every byte before/after.
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V012 LAB FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func run() -> void:
	create_timer(35).timeout.connect(func():push_error("V012 LAB TIMEOUT");quit(1))
	var profile:=ArenaCampaign.new();var candidate:=profile.data.duplicate(true);candidate.gems=17;candidate.levels.mage=2;candidate.selected_hero="mage"
	check(profile._commit(candidate),"seed isolated existing profile")
	var original:=FileAccess.get_file_as_bytes(ArenaCampaign.SAVE_PATH)
	var game: ArenaGame=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game;await settle()
	for identity in ["ranger","mage","knight"]:
		game.lab.select_hero(identity);await settle();game=current_scene
		check(game.feel_lab and game.hero.class_id==identity and game.hero.meta_level==5,"switch actual lab hero "+identity)
		check(not game.campaign.persistent and game.hero.cooldowns==[0.0,0.0],"fresh nonpersistent fixture "+identity)
		check(game.gold==ArenaGame.START_GOLD and game.kills==0,"switch resets resources and kills "+identity)
		check(FileAccess.get_file_as_bytes(ArenaCampaign.SAVE_PATH)==original,"switch preserves normal save bytes "+identity)
	game.return_to_menu();await settle();game=current_scene
	check(not game.feel_lab and game.campaign.persistent and game.campaign.gems()==17,"return restores normal profile")
	check(game.campaign.selected_hero()=="mage" and game.campaign.level("mage")==2,"fixture never overwrites configured hero/rank")
	check(FileAccess.get_file_as_bytes(ArenaCampaign.SAVE_PATH)==original,"return preserves original bytes")
	game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	print("V012 LAB CLI CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
