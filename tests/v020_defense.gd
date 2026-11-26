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
	check(game.hud.context.find_child("Upgrade",true,false)==null,"formal campaign upgrades automatically")
	var pre_mid_gold := game.gold
	game.gold = 600
	check(game.build_tower(2,"mage") and game.unlock_site(7),"mid-wave build and unlock stay open")
	var mid_mage := game.site_tower(2)
	complete(mid_mage)
	check(mid_mage.upgrade(),"tower can pay to upgrade mid-wave")
	mid_mage.finish_project()
	check(mid_mage.level==2,"paid tower upgrade completes mid-wave")
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
	# A synchronous hit reaction can splash back onto its original target.
	game.event_bus.subscribe("hero_hit", func(payload):
		if payload.enemy == enemy:
			enemy.take_hit(1000000.0, ArenaCombat.Type.PHYSICAL, "tower")
	)
	var gold_before_hit := game.gold
	clear_enemy(enemy)
	check(game.kills == 1 and game.gold - gold_before_hit == 5, "a reentrant lethal hit only pays one bounty")
	check(game.passive_offers.is_empty(),"single enemy kill does not pop mid-wave clutter")
	game.spawn_queue.clear()
	game._physics_process(0.0)
	check(game.cycle==2 and game.phase=="rest","wave completion advances cleanly")
	var before := game.gold
	check(archer.sell() and barracks.sell() and game.gold==before+purchase and not archer.sell(),"consecutive sales refund exactly the amounts paid, once")
	check(game.build_tower(0,"archer"),"a sold site accepts a replacement")
	archer=game.site_tower(0)
	complete(archer)
	game.gold = 500
	check(archer.upgrade(),"begin paid tier two")
	archer.finish_project()
	check(archer.upgrade(),"begin paid tier three")
	archer.finish_project()
	check(archer.level == 3 and archer.doctrine_id == "sentinel", "L3 archer activates its doctrine on completion")
	var target := game.spawn_enemy("fox", 0)
	target.position = archer.position + Vector2(65.0, 0.0)
	var shots_before := game.actors.get_child_count()
	archer._fire_at(target)
	check(game.actors.get_child_count() > shots_before, "the specialized L3 tower can fire")
	var doctrine_gold := game.gold
	check(game.hud.context.find_child("ChooseDoctrine",true,false) == null, "the campaign has no manual doctrine picker")
	var shield_key := InputEventKey.new()
	shield_key.keycode = KEY_B
	shield_key.pressed = true
	game._unhandled_input(shield_key)
	check(game.core_shield == 0.0 and game.core_overdrive_clock == 0.0 and game.gold == doctrine_gold,"the former shield key spends no resources")
	game.core_hit(game.core_max + game.core_shield)
	check(game.game_over and not game.victory,"core destruction ends the run immediately")
	await cleanup()

	deploy("creek")
	game.cycle=3
	var creek_packets := game.wave_packets(game.wave_pattern())
	check(creek_packets.all(func(packet): return packet.kind != "two_headed_troll"), "creek reinforcements never spawn a troll in round three")
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

	deploy("saltport")
	game.cycle = game.total_waves()
	game.begin_wave()
	game.spawn_queue.clear()
	game.exit_ward_cd = 10.0
	game.add_core_shield(180.0)
	var crab := game.spawn_enemy("bloodshell_boss", 0)
	var escort := game.spawn_enemy("murloc_hunter", 0)
	crab.advance_road(game.enemy_road(crab).get_baked_length() + 1.0)
	check(game.required_boss_escaped and not game.boss_defeated and game.core_health > 0.0, "an escaped required miniboss is tracked after a shielded leak")
	game._physics_process(0.0)
	check(not game.game_over, "the failed boss objective still waits for the rest of the wave")
	clear_enemy(escort)
	game._physics_process(0.0)
	check(game.game_over and not game.victory and game.core_health == 0.0 and bool(game.settlement.ok), "the drained final wave settles an escaped required boss as a defeat")
	await cleanup()

	deploy("sanctum")
	game.cycle = 4
	var pattern := game.wave_pattern()
	var authored_packets := 0
	for group in pattern.schedule:
		authored_packets += int(group[1])
	var compared := false
	for run_seed in range(1, 32):
		game.rift_domain.run_seed = run_seed
		var open_packets := game.wave_packets(pattern)
		if not open_packets.any(func(packet): return packet.serial >= authored_packets and packet.route == 3):
			continue
		game.stage_gimmicks.rift_suppressed = 8.0
		var closed_packets := game.wave_packets(pattern)
		check(closed_packets.size() == open_packets.size() and closed_packets.all(func(packet): return packet.route < 3), "suppressed route diverts authored troops and seeded reinforcements")
		compared = true
		break
	check(compared, "the route fixture includes a seeded reinforcement that would take the suppressed lane")
	await cleanup()

	await test_support_casts()
	print("V020 DEFENSE CHECKS: %d, FAILURES: %d" % [checks,failures])
	quit(0 if failures==0 else 1)


func test_support_casts() -> void:
	deploy("forest")
	for wave in range(1, 6):
		game.cycle = wave
		var unit := game.spawn_enemy("fox", 0)
		check(is_equal_approx(unit.max_health, 65.0 * ArenaEnemy.DEFENSE_HP_MULTIPLIERS[wave - 1]), "defense HP follows wave %d" % wave)
		game.remove_enemy(unit)
	var shaman := game.spawn_enemy("turtle_shaman", 0)
	shaman.position = Vector2(490.0, 500.0)
	var regulars: Array[ArenaEnemy] = []
	for index in range(5):
		var ally := game.spawn_enemy("fox", 0)
		ally.position = shaman.position + Vector2(20.0 * (index + 1), 0.0)
		ally.health = ally.max_health * (0.20 + index * 0.10)
		regulars.append(ally)
	var boss := game.spawn_enemy("moth", 0)
	var second_boss := game.spawn_enemy("moth", 0)
	for unit in [boss, second_boss]:
		unit.position = shaman.position + Vector2(0.0, 20.0)
		unit.health = unit.max_health * (0.2 if unit == boss else 0.3)
	shaman.ability_clock = 0.0
	shaman._tick_special_behaviors(0.0)
	check(shaman.ability_windup == 1.0, "shaman telegraphs the heal for a full second")
	shaman.take_hit(1.0, ArenaCombat.Type.PHYSICAL, "hero", 0.3)
	check(shaman.ability_windup == 0.0 and shaman.ability_kind.is_empty(), "stagger interrupts the heal")
	shaman.ability_kind = "heal"
	shaman._finish_ability()
	for index in range(5):
		var expected := 0.20 + index * 0.10 + (0.18 if index < 4 else 0.0)
		check(is_equal_approx(regulars[index].health, regulars[index].max_health * expected), "heal prioritizes the four lowest-health normal enemies")
	check(is_equal_approx(boss.health, boss.max_health * 0.24) and is_equal_approx(second_boss.health, second_boss.max_health * 0.30), "heal covers only the weakest boss and restores four percent")

	var mage := game.spawn_enemy("conch_mage", 0)
	mage.position = shaman.position
	mage.ranged_clock = 20.0
	mage.ability_clock = 0.0
	mage._tick_special_behaviors(0.0)
	check(mage.ability_windup == 0.9, "shield spell offers a longer interrupt window")
	boss.barrier_shield = 180.0
	mage._finish_ability()
	check(boss.barrier_shield == 200.0, "support shields cap at 200")
	await cleanup()
