extends SceneTree

var checks := 0
var failures := 0
var game: ArenaGame

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("V020 DEFENSE FAIL: "+message)

func deploy(stage: String) -> void:
	game=load("res://scenes/arena.tscn").instantiate()
	game.campaign=ArenaCampaign.new("",false)
	root.add_child(game)
	current_scene=game
	game.rng.seed=1
	game.start_run("knight",stage)
	game.set_physics_process(false)

func cleanup() -> void:
	paused=false
	game.running=false
	game.audio.shutdown()
	await process_frame
	OS.delay_msec(150)
	game.queue_free()
	await process_frame

func complete(tower: ArenaTower) -> void:
	tower._physics_process(ArenaTowerTrial.BUILD_TIME+0.01)

func clear_enemy(enemy: ArenaEnemy) -> void:
	enemy.take_hit(1000000.0,ArenaCombat.Type.PHYSICAL,"hero")

func route_counts() -> Array[int]:
	var counts: Array[int]=[0,0,0,0]
	for packet in game.wave_packets(game.wave_pattern()):
		counts[packet.route]+=1
	return counts

func run() -> void:
	for stage in ArenaLevelCatalog.IDS:
		var definition := ArenaLevelCatalog.definition(stage)
		check(not definition.has("camps") and not definition.has("nest"),stage+" deploys only the surface encounter")
	deploy("forest")
	check(game.gold==ArenaGame.START_GOLD and not paused and game.passive_offers.is_empty(), "normal deployment uses START_GOLD and enters seamlessly without pause")
	check(game.available_towers().size()==4,"forest sample offers the four equipped tower types")
	check(game.build_tower(0,"archer") and game.build_tower(1,"barracks"),"two jobs can run in parallel")
	var archer := game.site_tower(0)
	var barracks := game.site_tower(1)
	complete(archer)
	game.hud.show_context(0)
	check(game.hud.context.get_node("SellTower").text.contains(str(archer.sale_value())),"tower menu displays the actual refund")
	game.begin_wave()
	check(not game.hud.context.get_node("SellTower").disabled and game.can_sell_towers(),"opening a wave keeps tower selling enabled")
	check(game.hud.context.find_child("Upgrade",true,false)==null,"formal campaign uses auto-leveling instead of manual Upgrade")
	var pre_mid_gold := game.gold
	game.gold = 600
	check(game.build_tower(2,"mage") and game.unlock_site(7),"mid-wave build and unlock stay open")
	var mid_mage := game.site_tower(2)
	complete(mid_mage)
	mid_mage.gain_auto_xp(300.0)
	check(mid_mage.level>=2,"automated tower evolves via combat XP")
	mid_mage.retire()
	game.unlocked_sites.erase(7)
	game.gold = pre_mid_gold
	game.hud.show_context(0)
	complete(barracks)
	var purchase := archer.sale_value() + barracks.sale_value()
	check(barracks.project_level==0 and barracks.set_rally(game.nearest_road(barracks.position).point),"paid work completes and rally remains available during combat")
	var enemy := game.spawn_enemy("fox",0)
	var road: Curve2D = game.routes[0]
	enemy.position = barracks.rally_point
	game.blocking.update()
	var blocker := enemy.blocker
	check(blocker is ArenaSoldier, "a soldier engages at the original flag")
	var next_flag := road.sample_baked(road.get_closest_offset(barracks.rally_point)+45.0,true)
	check(not barracks.set_rally(game.level_definition.core) and enemy.blocker==blocker, "an invalid flag leaves the current order intact")
	check(barracks.set_rally(next_flag) and enemy.blocker==null and barracks.troops.all(func(s): return not s.can_block()), "a new flag releases the old line")
	for soldier in barracks.troops:
		soldier._physics_process(1.0)
	check(barracks.troops.all(func(s): return s.can_block() and s.position.distance_to(next_flag)<40), "the garrison reaches the new flag before engaging again")
	clear_enemy(enemy)
	check(game.kills==1 and game.passive_offers.is_empty(),"single enemy kill does not pop mid-wave clutter")
	game.spawn_queue.clear()
	game._physics_process(0.0)
	check(game.cycle==2 and game.phase=="rest","wave completion advances cleanly")
	var before := game.gold
	check(archer.sell() and barracks.sell() and game.gold==before+purchase and not archer.sell(),"consecutive sales refund exactly the amounts paid, once")
	check(game.build_tower(0,"archer"),"a sold site accepts a replacement")
	archer=game.site_tower(0)
	complete(archer)
	archer.gain_auto_xp(900.0)
	check(archer.level==3 and archer.doctrine_id==ArenaTower.AUTO_DEFAULT_DOCTRINE["archer"],"auto-evolved L3 archer applies default control doctrine automatically")
	check(game.charge_core_aegis() and game.core_shield>=180.0 and game.core_overdrive_clock>0.0,"Core Aegis shields core and overdrives towers")
	game.core_hit(game.core_max + game.core_shield)
	check(game.game_over and not game.victory,"core destruction ends the run immediately")
	await cleanup()

	deploy("creek")
	game.cycle=3
	var creek_packets := game.wave_packets(game.wave_pattern())
	check(creek_packets.filter(func(packet): return packet.kind=="darksteel_boss").size()>=1,"creek round 3 spawns darksteel_boss")
	game.cycle=5
	var last_packets:=game.wave_packets(game.wave_pattern())
	check(last_packets.filter(func(packet):return packet.kind=="two_headed_troll").size()==1,"the last authored queue contains one troll boss")
	game.begin_wave()
	game.spawn_queue.clear()
	game._physics_process(0.0)
	check(not game.game_over,"clearing the queue without the troll cannot settle victory")
	var troll:=game.spawn_enemy("two_headed_troll",0)
	clear_enemy(troll)
	for unit in game.enemies.duplicate(): clear_enemy(unit)
	game._physics_process(0.0)
	check(game.game_over and game.victory,"round 5 and the troll settle creek")
	await cleanup()

	deploy("ruins")
	game.cycle=5
	var expected_ruins_total := game.wave_packets(game.wave_pattern()).size()
	var sealed_counts := route_counts()
	check(sealed_counts[2]==0 and sealed_counts[0]+sealed_counts[1]==expected_ruins_total,"sealed northeast redistributes the main queue across existing roads")
	game.hud._process(1.0)
	var entry := game.world_to_hud(game.level_definition.routes[0][0])
	var expected_button := Vector2(clampf(entry.x,20,1530),clampf(entry.y,94,770))
	check(game.hud.wave_button.position.is_equal_approx(expected_button), "a split wave uses an open entrance for the call-wave control")
	game.breach_open=true
	var open_counts := route_counts()
	check(open_counts[2]>0 and open_counts[0]+open_counts[1]+open_counts[2]==expected_ruins_total,"open northeast participates in the scheduled queue")
	var packets := game.wave_packets(game.wave_pattern())
	var boss_pkts := packets.filter(func(packet): return packet.kind=="bloodsoil_boss")
	check(boss_pkts.size()>=1,"ruins round 5 schedules bloodsoil_boss")
	game.begin_wave()
	game._physics_process(0.0)
	check(not game.game_over,"a pending boss or wave enemy blocks victory")
	game.spawn_queue.clear()
	var boss := game.spawn_enemy("bloodsoil_boss",0)
	game._physics_process(0.0)
	check(not game.game_over,"a living boss blocks victory")
	clear_enemy(boss)
	game._physics_process(0.0)
	check(game.boss_defeated and not game.game_over,"boss defeat does not skip remaining wave enemies")
	for unit in game.enemies.duplicate():
		if not unit.is_guard: clear_enemy(unit)
	game._physics_process(0.0)
	check(game.game_over and game.victory,"boss defeat and finished round 5 settle victory")
	await cleanup()

	print("V020 DEFENSE CHECKS: %d, FAILURES: %d" % [checks,failures])
	quit(0 if failures==0 else 1)
