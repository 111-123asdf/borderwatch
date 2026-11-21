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

func check_independent_effects() -> void:
	# Two fixture offers exercise the same effects under different card IDs.
	for refund_only in [true,false]:
		deploy("forest")
		var card := ArenaRuleDeck.card("reform","wave_build_lock")
		card.id = "fixture"
		if refund_only:
			card.curse_id = &"fixture_cost"
		else:
			card.blessing_id = &"fixture_blessing"
		game.rule_offers[0] = card
		check(game.choose_defense_rule("fixture"), "selection accepts the actual offered pair")
		card.curse_id = &"mutated_after_choice"
		check(game.selected_defense_cards[0].curse_id!=card.curse_id, "a chosen pair keeps its own terms")
		game.build_tower(0,"archer")
		var tower := game.site_tower(0)
		complete(tower)
		check((tower.sale_value()==tower.invested_gold)==refund_only, "preparation refund follows the blessing")
		game.begin_wave()
		check(game.can_change_towers()==refund_only, "construction during the wave follows the cost")
		if refund_only:
			check(tower.sale_value()<tower.invested_gold and tower.sell(), "a wave sale uses the ordinary refund")
		await cleanup()

func run() -> void:
	for stage in ArenaLevelCatalog.IDS:
		var definition := ArenaLevelCatalog.definition(stage)
		check(not definition.has("camps") and not definition.has("nest"),stage+" deploys only the surface encounter")
	deploy("forest")
	check(game.defense_rules and game.gold==280, "normal deployment uses the revised rules and ordinary forest route")
	check(paused and game.rule_offers.size()==3 and game.rule_offers.all(func(c): return game.hud.modal.find_child("DefenseRule_"+c.id,true,false)!=null),"three opening offers use the normal HUD and pause preparation")
	check(game.hud.experience==null,"normal play has no experience meter")
	game.begin_wave()
	check(game.phase=="rest" and not game.build_tower(0,"archer"),"opening offer must be resolved before construction or the next wave")
	check(not game.choose_defense_rule("unknown") and game.choose_defense_rule("reform") and not paused,"only a displayed rule can apply")
	check(game.available_towers().size()==4,"forest sample offers the four existing tower types")
	check(game.build_tower(0,"archer") and game.build_tower(1,"barracks"),"two jobs can run in parallel")
	var archer := game.site_tower(0)
	var barracks := game.site_tower(1)
	var purchase := 280-game.gold
	complete(archer)
	game.hud.show_context(0)
	check(game.hud.context.get_node("SellTower").text.contains(str(archer.invested_gold)),"tower menu displays the actual refund")
	game.begin_wave()
	check(game.hud.context.get_node("SellTower").disabled and not archer.sell() and not archer.upgrade(),"opening a wave locks the menu and backend at once")
	check(not game.build_tower(2,"mage") and not game.unlock_site(7),"wave lock also protects empty and locked sites")
	complete(barracks)
	check(barracks.project_level==0 and barracks.set_rally(game.nearest_road(barracks.position).point),"paid work completes and rally remains available during combat")
	var enemy := game.spawn_enemy("fox",0)
	var road: Curve2D = game.routes[0]
	enemy.position = barracks.rally_point
	game.blocking.update()
	var blocker := enemy.blocker
	check(blocker is ArenaSoldier, "a soldier actually engages at the original flag")
	check(barracks.set_rally(barracks.rally_point) and enemy.blocker==blocker, "confirming the same flag keeps the engagement")
	var next_flag := road.sample_baked(road.get_closest_offset(barracks.rally_point)+45.0,true)
	check(not barracks.set_rally(game.level_definition.core) and enemy.blocker==blocker, "an invalid flag leaves the current order intact")
	check(barracks.set_rally(next_flag) and enemy.blocker==null and barracks.troops.all(func(s): return not s.can_block()), "a new flag releases the old line even under the tower lock")
	# A ranged garrison has a target in reach throughout this move.
	barracks.doctrine_data={"effects":{"soldier_range":180}}
	for soldier in barracks.troops:
		soldier._physics_process(1.0)
	barracks.doctrine_data={}
	check(barracks.troops.all(func(s): return s.can_block() and s.position.distance_to(next_flag)<40), "the garrison reaches the new flag before engaging again")
	clear_enemy(enemy)
	check(game.kills==1 and game.hero.xp==0 and game.hero.level==1 and not game.choice_open,"kills keep normal rewards without experience or passive choices")
	game.spawn_queue.clear()
	game._physics_process(0.0)
	check(game.cycle==2 and game.phase=="rest" and game.picked_rules==["reform"] and game.rule_offers.size()==3 and game.rule_offers.all(func(c):return c.id!="reform"),"wave completion keeps the pair and offers distinct new blessings")
	game.choose_defense_rule(game.rule_offers[0].id)
	var forest_packets := game.wave_packets(game.wave_pattern())
	check(forest_packets.size()==11 and forest_packets.filter(func(packet): return packet.kind=="spearman").size()==2,"standard forest wave 2 introduces two spearmen")
	var before := game.gold
	check(archer.sell() and barracks.sell() and game.gold==before+purchase and not archer.sell(),"consecutive sales refund exactly the amounts paid, once")
	check(game.build_tower(0,"archer"),"a sold site accepts a replacement")
	archer=game.site_tower(0)
	complete(archer)
	game.gold=600
	var paid := archer.invested_gold+archer.upgrade_price()
	check(archer.upgrade(),"paid upgrade is scheduled")
	complete(archer)
	var gold_before_l3 := game.gold
	var l3_price := archer.upgrade_price()
	check(archer.upgrade() and game.gold==gold_before_l3-l3_price,"level three prepays the listed price")
	game.begin_wave()
	check(archer.cancel_project() and game.gold==gold_before_l3 and archer.invested_gold==paid,"canceling during combat refunds the pending upgrade once")
	game.spawn_queue.clear()
	game._physics_process(0.0)
	game.choose_defense_rule(game.rule_offers[0].id)
	check(archer.upgrade(),"the refunded gold can fund another upgrade")
	paid+=l3_price
	complete(archer)
	var options := ArenaDoctrines.for_tower(archer.kind)
	check(archer.choose_doctrine(str(options[0].id)),"timed level three work retains the existing doctrine choice")
	paid+=archer.branch_price(0)
	check(archer.upgrade_branch(0) and archer.sale_value()==paid,"completed upgrades and paid branches count toward the refund")
	check(game.build_tower(2,"cannon"),"cannon builds through the normal menu while preparing")
	var cannon:=game.site_tower(2)
	complete(cannon)
	game.begin_wave()
	check(not archer.upgrade_branch(0),"curse also locks doctrine branch purchases")
	var aim:=cannon.position+Vector2(30,0)
	check(cannon.set_bombard(aim),"setting a cannon point remains possible during waves")
	enemy=game.spawn_enemy("fox",0)
	enemy.position=aim
	cannon._physics_process(0.01)
	cannon._physics_process(0.4)
	check(game.delayed.any(func(attack): return attack.options.get("cannon",false) and attack.point==aim),"the cannon fires at the designated point")
	cannon.clear_bombard()
	check(not cannon.bombard_point.is_finite(),"automatic aim can be restored during waves")
	game.core_hit(game.core_max)
	check(game.game_over and not game.victory,"core destruction ends the run immediately")
	await cleanup()

	deploy("creek")
	check(game.choose_defense_rule("") and game.picked_rules.is_empty(),"opening comparison uses standard defenses")
	game.cycle=5
	var creek_packets := game.wave_packets(game.wave_pattern())
	var south := creek_packets.filter(func(packet): return packet.route==1)
	check(creek_packets.size()==26 and south.size()==6 and is_equal_approx(float(south[0].at),4.5),"only the secondary lane gets the three-second delay")
	game.begin_wave()
	check(game.build_tower(1,"archer"),"standard comparison allows construction during combat")
	game.cycle=8
	game.spawn_queue.clear()
	for unit in game.enemies.duplicate(): game.remove_enemy(unit)
	game._physics_process(0.0)
	check(game.game_over and game.victory,"clearing the last wave wins on a stage without an authored boss")
	await cleanup()

	deploy("ruins")
	game.choose_defense_rule("reform")
	game.cycle=5
	check(route_counts()==[11,10,10,0],"sealed northeast redistributes the main queue across all three existing roads")
	game.hud._process(1.0)
	var entry := game.world_to_hud(game.level_definition.routes[0][0])
	var expected_button := Vector2(clampf(entry.x,20,1530),clampf(entry.y,94,770))
	check(game.hud.wave_button.position.is_equal_approx(expected_button), "a split wave uses an open entrance for the call-wave control")
	game.breach_open=true
	check(route_counts()==[8,8,8,7],"open northeast participates in the same round-robin queue")
	game.cycle=8
	var packets := game.wave_packets(game.wave_pattern())
	var colossus := packets.filter(func(packet): return packet.kind=="colossus")
	check(packets.size()==49 and colossus.size()==1 and float(colossus[0].at)==20.0,"ruins has one colossus scheduled at 20 seconds")
	game.begin_wave()
	game._physics_process(0.0)
	check(not game.game_over,"a pending boss or wave enemy blocks victory")
	game.spawn_queue.clear()
	var boss := game.spawn_enemy("colossus",0)
	game._physics_process(0.0)
	check(not game.game_over,"a living boss blocks victory")
	clear_enemy(boss)
	game._physics_process(0.0)
	check(game.boss_defeated and not game.game_over,"boss defeat does not skip the enemies remaining in its wave")
	for unit in game.enemies.duplicate():
		if not unit.is_guard: clear_enemy(unit)
	game._physics_process(0.0)
	check(game.game_over and game.victory,"boss defeat and a finished last wave settle victory")
	await cleanup()

	await check_independent_effects()
	print("V020 DEFENSE CHECKS: %d, FAILURES: %d" % [checks,failures])
	quit(0 if failures==0 else 1)
