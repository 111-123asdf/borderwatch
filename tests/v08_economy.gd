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
	game.gold = 500
	var before_purchase := game.gold
	check(game.build_tower(0, "archer"), "build an archer to test resale")
	var tower := game.site_tower(0)
	tower.finish_project()
	for tier in range(2,4):
		check(tower.upgrade(), "pay for tier %d" % tier)
		tower.finish_project()
	check(tower.upgrade(), "pay for the first specialization enhancement project")
	tower.finish_project()
	var paid := before_purchase-game.gold
	var refund := floori(paid*ArenaTower.SALE_REFUND_RATIO)
	check(tower.level == 3 and tower.invested_gold == paid and tower.sale_value() == refund, "resale accounts for paid upgrades and enhancement")
	check(tower.sell() and game.gold == before_purchase-paid+refund and not tower.sell(), "one resale returns 60 percent of paid cost")
	for example in [[1, 4], [2, 3], [5, 1]]:
		game.cycle = int(example[0])
		var previous := game.gold
		var foe := game.spawn_enemy("pigsoldier", 0)
		foe.take_hit(1000.0, ArenaCombat.Type.PHYSICAL, "hero")
		check(game.gold - previous == int(example[1]), "bounty scales down with defense wave %d" % game.cycle)
	var previous := game.gold
	var boss := game.spawn_enemy("darksteel_boss", 0)
	boss.take_hit(10000.0, ArenaCombat.Type.MAGIC, "hero")
	check(game.gold - previous == 11, "late boss remains worth more than a regular unit")
	game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	paused=false
	print("V08 ECONOMY CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
