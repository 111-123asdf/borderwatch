extends SceneTree

var game: ArenaGame
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("BATTLE ORDERS FAIL: "+message)

func deploy(level: String) -> void:
	game = ArenaGame.new()
	game.campaign = ArenaCampaign.new("",false)
	root.add_child(game)
	current_scene = game
	game.start_run("knight",level)
	game.set_physics_process(false)

func cleanup() -> void:
	paused=false
	game.running=false
	game.audio.shutdown()
	await process_frame
	OS.delay_msec(150)
	game.queue_free()
	await process_frame

# Combat fixtures select a legal pair through the same handler as the card button.
func equip(id: String, cost: String) -> void:
	game.rule_offers.assign([ArenaRuleDeck.card(id,cost)])
	check(game.choose_defense_rule(id),"equip "+id+" / "+cost)

func remove_units() -> void:
	for e: ArenaEnemy in game.enemies.duplicate(): game.remove_enemy(e)

func kill(e: ArenaEnemy) -> void:
	e.take_hit(100000,1,"hero")

func run() -> void:
	deploy("creek")
	var o:=game.orders
	game.cycle=5
	var seen := {}
	var draws_unique := true
	for seed_no in range(100):
		game.rng.seed=seed_no
		o.deck.seen.clear()
		var offers:=o.deck.draw(game)
		var ids: Array=[]
		for c in offers:
			draws_unique=draws_unique and c.id not in ids
			ids.append(c.id)
			seen[c.curse_id]=true
	check(draws_unique,"100 seeded rounds show three distinct blessings per offer")
	check(seen.has("stake") and seen.has("waive") and seen.has("open_gate") and seen.has("flank"),"alternate costs are reachable through random draws")
	equip("lure","flank")
	equip("bounty","stake")
	equip("chest","risk_chest")
	game.hud.refresh_orders()
	game.hud.orders_button.pressed.emit()
	var menu:=game.hud.orders_panel
	check(menu.visible and menu.get_node("Order_lure").visible,"normal HUD exposes deployment orders")
	menu.get_node("Order_lure").pressed.emit()
	menu.get_node("Order_lure").pressed.emit()
	check(o.lure_lane==1,"preview input selects south")
	o.command("bounty")
	check(o.bounty_lane==1,"sign the southern contract")
	o.command("chest")
	check(o.chest_lane==1,"box offers only the route with five ordinary rewards")
	var packets:=game.wave_packets(game.wave_pattern())
	check(packets.size()==15 and packets.filter(func(p):return p.route==1).size()==14 and packets[0].elite and packets[0].at==0,"current creek queue redirects the ordinary column and its elite")
	check(packets.filter(func(p):return p.get("bounty",false)).size()==3,"three named tickets before launch")
	var before:=game.gold
	game.begin_wave()
	check(game.gold==before-60 and o.bounty_active,"one deposit at wave lock")
	game.begin_wave()
	check(game.gold==before-60,"repeated wave command cannot debit twice")
	game._physics_process(9)
	for e: ArenaEnemy in game.enemies.duplicate():
		if e.rule_front: kill(e)
	check(o.bounty_kills==3 and not o.bounty_active and game.gold==before+80,"first three kills settle once with the base drops in the box")
	check(o.chest_count==3 and o.cash_amount()==126,"three bear rewards accumulate without double credit")
	for e: ArenaEnemy in game.enemies.duplicate():
		if o.chest_count<5 and e.rule_main and not e.elite: kill(e)
	check(o.cash_amount()==270 and o.command("chest") and not o.command("chest"),"five-drop chest pays once")
	check(game.gold==before+350,"wallet includes exactly the contract and box")
	await cleanup()

	deploy("forest")
	o=game.orders
	equip("relay","handoff")
	equip("riposte","trade_strike")
	equip("wall","pledge")
	equip("beacon","expose_gate")
	var road: Curve2D=game.routes[0]
	var a:=road.sample_baked(540,true)
	var b:=road.sample_baked(820,true)
	check(o.command("flag_a") and o.choose_point(a) and o.command("flag_b") and o.choose_point(b),"two ground clicks plant walkable flags")
	game.hero.position=a
	game.begin_wave()
	var victim:=game.spawn_enemy("brute",0,540)
	var follower:=game.spawn_enemy("fox",0,450)
	game.blocking.update()
	check(victim.blocker==game.hero,"real blocking assigns the heavy to the knight")
	check(o.command("riposte") and o.choose_point(a),"explicit ground command replaces an attack")
	var hp:=victim.health
	game.hero.release_action()
	check(victim.rule_pushed and is_equal_approx(victim.progress,450) and victim.stun>0 and follower.stun>0 and victim.health==hp,"collision displaces, stuns both and forgoes damage")
	game.hero.cancel_action()
	game.hero.position=a
	check(o.command("relay") and not game.hero.can_block(),"handoff releases the old line")
	game.hero.command_move(b)
	o.tick(0.2)
	check(not o.transfer_used and o.transfer_left==0,"moving cancels a handoff without spending the use")
	game.hero.path.clear()
	check(o.command("relay"),"handoff can be retried")
	o.tick(1.21)
	check(game.hero.position.is_equal_approx(b) and o.transfer_used and not o.command("relay"),"one transfer per wave")
	var core:=game.core_health
	check(o.command("wall") and game.core_health==core-75,"raise wall with a real bond")
	var stop:=road.get_baked_length()-120
	var guard:=game.spawn_enemy("fox",0,stop-1)
	guard._physics_process(0.1)
	check(is_equal_approx(guard.progress,stop) and o.wall_hp<300,"enemy movement and attack hit the wall before the core")
	check(o.command("wall") and is_equal_approx(guard.progress,stop-100) and game.core_health==core and not o.command("wall"),"manual release returns the same bond and pushes along the road")
	check(o.command("beacon") and o.choose_point(a) and game.delayed.size()==3,"volley issues three timed impacts")
	var late:=game.spawn_enemy("fox",0,road.get_baked_length()-1)
	late._physics_process(0.2)
	check(game.core_health==core-54,"first leak during open gate deals extra 40")
	late=game.spawn_enemy("fox",0,road.get_baked_length()-1)
	late._physics_process(0.2)
	check(game.core_health==core-68,"second leak has normal damage")
	await cleanup()

	deploy("creek")
	o=game.orders
	game.cycle=8
	equip("lure","vanguard")
	equip("wall","open_gate")
	equip("bounty","waive")
	equip("chest","risk_chest")
	o.command("lure")
	o.command("lure")
	o.command("gate")
	o.command("bounty")
	o.command("chest")
	packets=game.wave_packets(game.wave_pattern())
	var ordinary:=packets.filter(o.main_ordinary)
	check(ordinary[0].at==ordinary[2].at and packets.filter(func(p):return p.elite)[0].at>0,"only the front three share the earliest departure")
	before=game.gold
	game.begin_wave()
	game._physics_process(0.01)
	check(game.gold==before and o.bounty_active,"waiver has no upfront debit")
	var front:=game.enemies.filter(func(e):return e.rule_front)
	check(front.size()==3,"ordinary enemies carry identities after simultaneous spawn")
	front[0].progress=o.bounty_line-1
	front[0]._physics_process(0.1)
	o.tick(0)
	check(not o.bounty_active,"first crossing fails the whole contract")
	for e in front: kill(e)
	check(game.gold==before and o.chest_count==0,"failed waived targets cannot fund a chest")
	var cash_unit:=game.spawn_enemy("fox",1)
	cash_unit.rule_main=true
	kill(cash_unit)
	var nonmain:=game.spawn_enemy("fox",1,game.routes[1].get_baked_length()-1)
	nonmain._physics_process(0.2)
	check(o.chest_open and o.chest_count==1,"unrelated reinforcement cannot steal the box")
	var thief:=game.spawn_enemy("fox",1,game.routes[1].get_baked_length()-1)
	thief.rule_main=true
	thief._physics_process(0.2)
	check(not o.chest_open and not o.cash_chest(),"leak closes the box without payout")
	core=game.core_health
	check(o.command("wall") and game.core_health==core and o.gate_lane==0,"one uncovered gate in lieu of the bond")
	var blocked:=game.spawn_enemy("fox",1,game.routes[1].get_baked_length()-441)
	blocked._physics_process(0.1)
	check(is_equal_approx(blocked.progress,game.routes[1].get_baked_length()-440),"other lane is held before the physical merge")
	await cleanup()

	deploy("ruins")
	equip("bridge","fixed_bridge")
	check(game.orders.command("bridge"),"set the bridge before the wave")
	game.begin_wave()
	game._tick_stage3_systems(18.0)
	check(game.bridge_sealed and not game.trigger_bridge_gate(),"wave-long bridge survives the old timer and manual toggle")
	await cleanup()
	await check_towers()
	await check_alternatives()
	print("BATTLE ORDERS CHECKS: %d, FAILURES: %d"%[checks,failures])
	quit(0 if failures==0 else 1)

func check_towers() -> void:
	deploy("creek")
	var o:=game.orders
	equip("battery","cede_arc")
	equip("muster","march")
	equip("mark","focus")
	game.gold=1000
	game.cycle=6
	for spec in [[0,"archer"],[5,"mage"],[1,"barracks"],[6,"barracks"]]:
		check(game.build_tower(spec[0],spec[1]),"construct support tower")
		game.site_tower(spec[0]).finish_project()
	var donor:=game.site_tower(0)
	var receiver:=game.site_tower(5)
	var origin:=game.site_tower(1)
	var camp:=game.site_tower(6)
	check(o.command("battery") and o.choose_point(donor.position) and o.choose_point(receiver.position),"link actual finished towers")
	check(o.command("muster") and o.choose_point(origin.position) and o.choose_point(camp.position),"marching order uses a reachable ground route")
	check(origin.support_camp==camp and origin.troops.all(func(s): return not s.can_block()),"entire squad leaves its old interception")
	for i in 300:
		for s in origin.troops: s._physics_process(0.1)
	check(origin.troops.all(func(s):return s.can_block() and s.position.distance_to(camp.rally_point)<46),"soldiers finish the march and can block at the new flag")
	game.begin_wave()
	var pos:=game.nearest_road(receiver.position)
	var target:=game.spawn_enemy("fox",pos.route,pos.progress,true)
	game.hero.position=target.position
	game.hero.begin_attack(target)
	game.hero.release_action()
	check(o.marked==target and game.tower_target(donor)==target,"basic hit marks the elite in the borrowed firing arc")
	donor._fire_at(target)
	var shots:=game.actors.get_children().filter(func(s):return s is ArenaProjectile and s.source=="tower")
	check(not shots.is_empty() and shots.back().position.distance_to(receiver.position)<110,"projectile starts from recipient rather than the donor")
	var auto_damage:=target.take_hit(10,1,"tower",0,0,0,"attack",Vector2.ZERO,Vector2.INF,{"auto_tower":true})
	var fixed_damage:=target.take_hit(10,1,"tower")
	check(is_equal_approx(auto_damage,16) and is_equal_approx(fixed_damage,10),"manual and automatic hits have distinct mark bonuses")
	receiver.sell()
	check(game.tower_target(donor)==null,"destroyed receiver leaves the donor idle until preparation")
	await cleanup()

func check_alternatives() -> void:
	deploy("forest")
	var o:=game.orders
	equip("relay","one_way")
	equip("battery","alternate")
	equip("bounty","stake")
	equip("beacon","expose_gate")
	equip("wall","pledge")
	game.gold=1000
	for i in 2:
		game.build_tower(i,"archer")
		game.site_tower(i).finish_project()
	var d:=game.site_tower(0)
	var r:=game.site_tower(1)
	check(o.command("battery") and o.choose_point(d.position) and o.choose_point(r.position),"alternate battery takes the same deployment orders")
	o.command("bounty")
	var road: Curve2D=game.routes[0]
	var a:=road.sample_baked(440,true)
	var b:=road.sample_baked(840,true)
	o.command("flag_a")
	o.choose_point(a)
	o.command("flag_b")
	o.choose_point(b)
	game.hero.position=a
	game.begin_wave()
	game.hero.position=b
	check(not o.command("relay"),"one-way transfer cannot depart from the receiving flag")
	game.hero.position=a
	check(o.command("relay") and game.hero.position==b and o.transfer_left==0,"advance deployment enables an instant transfer")
	game._physics_process(2.0)
	var fronts:=game.enemies.filter(func(e):return e.rule_front)
	for e in fronts:
		e.progress=o.bounty_line-1
		e._physics_process(0.1)
		kill(e)
	o.tick(0)
	check(o.bounty_kills==3 and not o.bounty_active,"lethal impact in the crossing frame counts for the contract")
	var target:=game.spawn_enemy("brute",0,road.get_closest_offset(r.position))
	d.fire_local=false
	d._fire_at(target)
	check(o.borrowed_shot,"borrowing spends the next live recipient shot")
	var count:=game.actors.get_child_count()
	r._fire_at(target)
	check(not o.borrowed_shot and game.actors.get_child_count()==count,"one recipient shot is skipped before the next borrow")
	check(o.command("beacon") and o.choose_point(target.position),"beacon accepts a road point")
	var hp:=target.health
	game._physics_process(1.9)
	check(is_equal_approx(target.health,hp),"no artillery damage before the first impact")
	game._physics_process(0.11)
	check(is_equal_approx(hp-target.health,70),"first shell inflicts 70 magic through normal damage resolution")
	var core:=game.core_health
	o.command("wall")
	var boss:=game.spawn_enemy("moth",0,road.get_baked_length()-121)
	boss._physics_process(0.2)
	check(o.wall_left==0 and game.core_health==core-75 and not o.command("wall"),"boss breaks shared wall, destroys its bond and consumes its use")
	await cleanup()
