extends SceneTree
# Explicit fixtures for the extra tower site: locked, priced, unlocked, buildable.
var checks:=0
var failures:=0
var game: ArenaGame
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V08 ECONOMY FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);await process_frame
	game.progression=ArenaProgression.new("user://fixture-economy.cfg",false)
	game.start_run("knight","forest")
	var locked: int=int(game.level_definition.locked_sites[0])
	check(locked==7,"forest locks its final insurance site")
	check(game.site_locked(locked) and not game.site_locked(0),"only the authored site starts locked")
	game.gold=1000
	var before:=game.gold
	check(not game.build_tower(locked,"archer") and game.gold==before,"locked site refuses construction")
	check(game.unlock_price(locked)==200,"locked site keeps its authored price")
	game.selected_site=locked;game.hud.show_context(locked)
	check(game.hud.context.find_child("UnlockSite",true,false)!=null,"locked site offers an unlock button")
	game.hud.close_context()
	game.gold=150
	check(not game.unlock_site(locked) and game.gold==150,"unlock cannot go negative")
	game.gold=500
	check(game.unlock_site(locked) and game.gold==300,"unlock spends exactly once")
	check(not game.unlock_site(locked) and game.gold==300,"unlock cannot be repeated")
	game.selected_site=locked;game.hud.show_context(locked)
	check(game.hud.context.find_child("Build_archer",true,false)!=null,"unlocked site shows the build menu")
	game.hud.close_context()
	check(game.build_tower(locked,"archer") and game.site_tower(locked)!=null,"unlocked site builds normally")
	var creek:=ArenaLevelCatalog.definition("creek")
	check(int(creek.locked_sites[0])==9 and int(creek.locked_site_price)==200,"creek locks one site at the same price")
	game.choice_queue=0;game.choice_open=false
	game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	paused=false
	print("V08 ECONOMY CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
