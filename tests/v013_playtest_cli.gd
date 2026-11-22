extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V013 CLI FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func settle() -> void:
	for i in range(6):await process_frame
func run() -> void:
	create_timer(30).timeout.connect(func():push_error("V013 CLI TIMEOUT");quit(1))
	var normal:=ArenaCampaign.new();var seed_data:=normal.data.duplicate(true);seed_data.gems=29;seed_data.levels.healer=2;check(normal._commit(seed_data),"seed isolated normal save")
	var original:=FileAccess.get_file_as_bytes(ArenaCampaign.SAVE_PATH)
	var game: ArenaGame=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game;await settle()
	check(game.campaign.path==ArenaCampaign.PLAYTEST_PATH and game.campaign.persistent,"real CLI selects preview profile")
	check(game.campaign.gems()==9999 and game.campaign.level("healer")==1,"real preview starts funded and unupgraded")
	check(game.campaign.upgrade("gunner") and game.campaign.level("gunner")==2,"preview can actually buy an upgrade")
	game.return_to_menu();await settle();game=current_scene
	check(game.campaign.gems()==9999 and game.campaign.level("gunner")==2,"scene reload retains preview progress and funding")
	check(FileAccess.get_file_as_bytes(ArenaCampaign.SAVE_PATH)==original,"normal save bytes unaffected across preview scene reload")
	game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	print("V013 CLI CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
