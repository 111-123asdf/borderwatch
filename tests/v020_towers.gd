extends SceneTree

var checks:=0
var failures:=0
var game: ArenaGame

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("V020 TOWER FAIL: "+message)

func fixture_enemy(kind: String,point: Vector2,progress:=340.0,elite:=false) -> ArenaEnemy:
	var enemy:=game.spawn_enemy(kind,0,progress,elite)
	enemy.position=point
	return enemy

func clear_enemies() -> void:
	for enemy in game.enemies.duplicate(): game.remove_enemy(enemy)

func complete(tower: ArenaTower) -> void:
	tower._physics_process(ArenaTowerTrial.BUILD_TIME+0.001)

func run() -> void:
	game=load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	game.start_run("knight","forest")
	await process_frame
	check(game.tower_lab,"the CLI starts the separate tower trial")
	check(game.campaign.path==ArenaCampaign.TOWER_TRIAL_PATH and game.gold==280,"trial profile is isolated and starts with the normal budget")
	check(game.available_towers()==ArenaDefinitions.DEFAULT_TOWERS,"all four offers are available immediately")
	check(game.build_tower(0,"archer") and game.build_tower(2,"barracks"),"two builds can run concurrently")
	var archer:=game.site_tower(0)
	var barracks:=game.site_tower(2)
	check(archer.project_level==1 and barracks.project_level==1 and game.gold==130 and game.soldiers.is_empty(),"prepayment does not deploy unfinished towers")
	game.hud.show_context(0)
	check(game.hud.context.get_node_or_null("CancelTowerWork")!=null,"the tower menu exposes cancellation")
	barracks._physics_process(0.55)
	check(barracks.troops.is_empty() and not archer.trigger_bonus_salvo(),"the work timer gates both soldiers and attacks")
	check(archer.cancel_project() and game.gold==200 and game.site_tower(0)==null and barracks.project_level==1,"cancel restores the full price and only frees its own site")
	check(not archer.cancel_project(),"cancellation cannot refund twice")
	check(game.build_tower(0,"archer"),"a player can immediately reorder the canceled build")
	archer=game.site_tower(0)
	complete(archer)
	complete(barracks)
	check(archer.invested_gold==70 and barracks.invested_gold==80 and barracks.troops.size()==3,"completion commits payment and exactly three soldiers")
	check(is_equal_approx(archer.reload_time(),2.2) and archer.upgrade_price()==112,"archer cadence and L2 price follow the implementation decisions")
	var old_power:=archer.base_power()
	check(archer.upgrade() and archer.level==1 and archer.project_level==2 and game.gold==18,"upgrading prepays while still operating at its current level")
	archer.attack_clock=2.0
	archer._physics_process(0.6)
	check(archer.base_power()==old_power and archer.attack_clock<2.0,"existing attack cooldown keeps advancing during the work")
	check(archer.cancel_project() and game.gold==130 and archer.invested_gold==70,"upgrade cancellation returns only the uncommitted payment")
	check(archer.upgrade(),"the same upgrade can be ordered again")
	archer.attack_clock=2.0
	complete(archer)
	check(archer.level==2 and archer.attack_clock>0.9 and archer.upgrade_price()==168 and archer.invested_gold==182,"L2 completes without resetting a running cooldown")
	check(not archer.upgrade() and archer.level==2 and archer.project_level==0,"an unaffordable third level cannot start construction")
	game.gold+=780
	check(game.build_tower(3,"mage") and game.build_tower(4,"cannon"),"base-price mage and cannon work through the same tower menu")
	var mage:=game.site_tower(3)
	var cannon:=game.site_tower(4)
	complete(mage)
	complete(cannon)

	var muzzle:=archer.muzzle()
	var targets: Array[ArenaEnemy]=[]
	for index in range(4,-1,-1):
		var enemy:=fixture_enemy("fox",muzzle+Vector2(45.0+index*43.0,19.0))
		enemy.stun=100.0
		targets.push_front(enemy)
	targets[4].health=200.0
	var loner:=fixture_enemy("brute",muzzle+Vector2(110,130))
	loner.health=400.0
	loner.stun=100.0
	archer.attack_clock=0.0
	archer._physics_process(0.01)
	check(archer.timing.target==targets[4] and archer.timing.is_preparing(),"the line through the group wins over a higher-HP isolated target")
	var committed_ray:=archer.visual_target
	targets[4].position+=Vector2(800,0)
	archer._physics_process(0.1)
	check(archer.timing.is_preparing() and archer.visual_target==committed_ray and game.tower_trial_stats.arrows==0,"the telegraphed line stays locked if the original target moves away")
	archer._physics_process(0.90)
	var arrow: ArenaProjectile
	for actor in game.actors.get_children():
		if actor is ArenaProjectile and not actor.trial_pierce_scales.is_empty(): arrow=actor
	check(arrow!=null and arrow.target==null,"the standard archer timing releases a non-homing arrow")
	if arrow!=null:
		arrow._physics_process(0.28)
		check(arrow.direction.is_equal_approx(committed_ray) and arrow.hit_ids.size()==4 and arrow.is_queued_for_deletion(),"the arrow follows the shown line and still hits the four remaining targets")
		for index in range(4):
			var expected:=65.0-archer.base_power()*ArenaTowerTrial.arrow_scales(2)[index]
			check(is_equal_approx(targets[index].health,expected),"piercing falloff follows front-to-back collision order")
		check(targets[4].health==200.0 and targets[0].tower_weakness_clock==3.0,"the fifth enemy is untouched and damage marks the first survivor")
		check(is_equal_approx(targets[0].take_hit(10.0,ArenaCombat.Type.PHYSICAL,"tower"),10.0) and targets[0].tower_weakness_clock>0.0,"allied tower damage leaves the opening for the hero")
		check(is_equal_approx(targets[0].take_hit(10.0,ArenaCombat.Type.MAGIC,"hero"),13.0) and targets[0].tower_weakness_clock==0.0,"the hero consumes the opening with one amplified hit")
		check(is_equal_approx(targets[0].take_hit(5.0,ArenaCombat.Type.PHYSICAL,"hero"),5.0) and game.tower_trial_stats.weakness_used==1,"a second unmarked hit receives no bonus")
	clear_enemies()

	var frost_targets: Array[ArenaEnemy]=[
		fixture_enemy("fox",mage.position+Vector2(24,0)),
		fixture_enemy("fox",mage.position+Vector2(245,0))]
	var outside:=fixture_enemy("fox",mage.position+Vector2(251,0))
	for enemy in frost_targets: enemy.health=250.0
	mage._physics_process(0.01)
	check(frost_targets[0].health==237.0 and frost_targets[0].tower_frost_layers==2 and frost_targets[1].health==243.5 and frost_targets[1].tower_frost_layers==1 and outside.health==65.0,"the center does full damage and adds two layers while the rim does half and adds one")
	check(game.tower_trial_stats.pulses==1 and game.tower_trial_stats.pulse_hits==2 and game.tower_trial_stats.inner_hits==1,"pulse coverage records each ring")
	for enemy in frost_targets: enemy.tick_tower_effects(2.5)
	mage._physics_process(2.5)
	var frozen:=frost_targets[0]
	check(frozen.tower_frost_layers==0 and is_equal_approx(frozen.tower_control_clock,1.2) and frost_targets[1].tower_frost_layers==2,"the center freezes after two pulses while the rim still only slows")
	frozen.tick_tower_effects(1.2)
	var before:=frozen.health
	mage._physics_process(2.5)
	check(frozen.health<before and frozen.tower_frost_layers==0 and frozen.tower_frost_lock==3.0,"damage continues during the post-freeze frost immunity")
	check(frost_targets[1].tower_frost_layers==0 and frost_targets[1].tower_control_clock>0.0,"the third outside pulse can freeze a target held at the rim")
	frozen.tick_tower_effects(3.0)
	frozen.tower_frost(1.2)
	check(frozen.tower_frost_layers==1 and is_equal_approx(frozen.movement_factor(),0.92),"the next frost layer slows after immunity ends")
	frozen.tick_tower_effects(4.0)
	check(frozen.tower_frost_layers==0,"unrefreshed frost layers expire")
	clear_enemies()

	var closest:=game.nearest_road(cannon.position)
	var p:=float(closest.progress)
	var road:=game.routes[0]
	var mobile:=fixture_enemy("fox",road.sample_baked(p,true),p)
	var launch:=mobile.position
	cannon._physics_process(0.01)
	var warned_aim:=cannon.timing.target_point
	mobile.position+=Vector2(55,100)
	cannon._physics_process(0.81)
	check(game.delayed.size()==1 and mobile.health==65.0,"the cannon schedules flight before any impact")
	if game.delayed.size()==1:
		var shell: Dictionary=game.delayed[0]
		var aim: Vector2=shell.point
		check(is_equal_approx(float(shell.life),0.7) and aim==warned_aim and is_equal_approx(aim.distance_to(launch),73.0*(0.8+0.7)),"the cannon displays and keeps its lead through windup and flight")
		mobile.position=aim
		var edge:=fixture_enemy("fox",aim+Vector2(84.5,0),p)
		var beyond:=fixture_enemy("fox",aim+Vector2(86,0),p)
		game._physics_process(0.71)
		check(is_equal_approx(mobile.health,35.0) and edge.health>49.0 and edge.health<50.0 and beyond.health==65.0,"the impact uses radial falloff and an 85-pixel radius")
		check(is_equal_approx(mobile.progress,p-12.0) and is_equal_approx(mobile.tower_control_clock,0.35),"impact pushes on the assigned road and applies a short stun")
		check(edge.progress==p and edge.tower_control_clock==0.0 and game.tower_trial_stats.shell_core_hits==1,"edge damage stacks without hard control outside the inner circle")
		mobile.tick_tower_effects(0.35)
		mobile.tower_shock(0.35,12.0,aim)
		check(is_equal_approx(mobile.tower_control_clock,0.21),"the next cannon stun inside six seconds is shorter")
	clear_enemies()
	game.hud.show_context(cannon.site_id)
	var order:=game.hud.context.get_node_or_null("TowerGroundOrder") as Button
	check(order!=null,"the selected cannon offers a ground order")
	if order!=null:
		order.pressed.emit()
		var point:=cannon.position+Vector2(105,0)
		var click:=InputEventMouseButton.new()
		click.button_index=MOUSE_BUTTON_LEFT
		click.pressed=true
		click.position=game.world_to_hud(cannon.position+Vector2(900,0))
		game._unhandled_input(click)
		check(game.rally_site==cannon.site_id and not cannon.bombard_point.is_finite(),"rejecting an out-of-range order leaves placement active")
		click.position=game.world_to_hud(point)
		game._unhandled_input(click)
		check(game.rally_site==-1 and cannon.bombard_point.is_equal_approx(point),"a valid click stores the fixed point")
		var bypass:=fixture_enemy("fox",point+Vector2(65,0))
		bypass.stun=100.0
		cannon.attack_clock=0.0
		cannon._physics_process(0.01)
		check(not cannon.timing.is_preparing(),"fixed fire waits while an enemy is only in the outer ring")
		bypass.position=point
		cannon._physics_process(0.01)
		check(cannon.timing.is_preparing() and cannon.timing.target_point.is_equal_approx(point),"a target entering the inner ring commits the shot")
		game.hud.show_context(cannon.site_id)
		var automatic:=game.hud.context.get_node_or_null("ResetBombard") as Button
		if automatic!=null: automatic.pressed.emit()
		check(automatic!=null and not cannon.bombard_point.is_finite() and cannon.timing.target_point.is_equal_approx(point),"returning to automatic leaves the committed shot alone")
		bypass.position+=Vector2(110,0)
		cannon._physics_process(0.81)
		game._physics_process(0.71)
		check(bypass.health==65.0 and game.tower_trial_stats.shells==2 and game.tower_trial_stats.shell_hits==1,"a committed shell can miss when its target leaves")
		game.hud.close_context()
	clear_enemies()

	var station:=barracks.rally_point
	var troop:=barracks.troops[0] as ArenaSoldier
	check(troop.max_health==160.0 and is_equal_approx(troop.melee_damage(),4.5),"a first-level garrison supplies 160 HP and 4.5 damage per soldier")
	check(barracks.troops.all(func(soldier): return not soldier.can_block()),"fresh soldiers cannot block until they reach their slots")
	for soldier in barracks.troops: soldier._physics_process(2.0)
	check(barracks.troops.all(func(soldier): return soldier.can_block() and soldier.position.distance_to(barracks.rally_slot(soldier.slot))<=4.0),"the soldiers walk into three slots across the road")
	var elite:=fixture_enemy("fox",troop.position+Vector2(62,0),340.0,true)
	var heavy:=fixture_enemy("brute",station+Vector2(15,0))
	var boss:=fixture_enemy("moth",station+Vector2(30,0))
	game.blocking.update()
	check(elite.blocker is ArenaSoldier and heavy.blocker==null and boss.blocker==null and game.blocking.load_for(elite.blocker)==1,"the garrison stops a light elite and lets heavies and bosses through")
	var front:=elite.blocker as ArenaSoldier
	if front!=null:
		front._physics_process(0.4)
		check(front.position.distance_to(elite.position)<=45.0,"a taunting soldier closes into actual attack range")
		front.take_hit(400.0,ArenaCombat.Type.PHYSICAL)
		check(front.dead and front.respawn_clock==8.0 and elite.blocker==null,"a casualty releases the route immediately and queues an eight-second replacement")
		front._physics_process(7.99)
		check(front.dead,"the soldier stays down until replacement is ready")
		front._physics_process(0.02)
		check(not front.dead and front.health==160.0 and front.position.distance_to(barracks.position)<35.0,"the replacement returns from the barracks at full health")
		check(not front.can_block(),"the replacement also has to reach the line")
	var next_flag:=road.sample_baked(road.get_closest_offset(station)+76.0,true)
	check(barracks.set_rally(next_flag) and barracks.troops.all(func(soldier): return not soldier.can_block()),"changing the flag breaks the old line during redeployment")
	var arriving:=fixture_enemy("fox",barracks.rally_point)
	game.blocking.update()
	check(arriving.blocker==null,"the new point cannot intercept while soldiers march")
	for soldier in barracks.troops: soldier._physics_process(2.0)
	game.blocking.update()
	check(arriving.blocker is ArenaSoldier,"the new line only begins intercepting on arrival")
	var boss_progress:=boss.progress
	boss.tower_shock(1.0,12.0,boss.position-Vector2(5,0))
	check(is_equal_approx(boss.tower_control_clock,0.4) and boss.progress==boss_progress and is_equal_approx(boss.tower_impact_offset.length(),3.6),"boss impact is capped and never rolls back road progress")
	boss.tick_tower_effects(0.4)
	check(boss.tower_control_lock==4.0 and not boss.accept_tower_control(1.2),"boss hard-control immunity starts once the effect ends")
	boss.tick_tower_effects(4.0)
	check(boss.accept_tower_control(1.2),"boss can be stopped again when the immunity expires")
	check(elite.accept_tower_control(1.0) and is_equal_approx(elite.tower_control_clock,0.60),"elites take sixty percent of hard-control duration")
	clear_enemies()

	check(archer.upgrade(),"the paid L3 order uses the existing tower action")
	complete(archer)
	check(archer.level==3 and not archer.awaiting_doctrine and archer.invested_gold==350 and ArenaTowerTrial.arrow_scales(3).size()==5,"L3 increases the core mechanic without opening the old doctrine picker")
	var sale_gold:=game.gold
	check(archer.sell() and game.gold-sale_gold==210,"sale returns sixty percent of the completed paid investment")
	check(not archer.sell(),"the retired tower cannot return gold twice")
	game.level_definition.site_traits=["","","choke","highground","conduit"]
	for soldier in barracks.troops: soldier.refresh_stats()
	check(is_equal_approx(troop.max_health,188.8) and is_equal_approx(mage.attack_range(),295.0),"site traits multiply the garrison's health and pulse radius")
	check(is_equal_approx(cannon.reload_time(),3.0/1.14) and is_equal_approx(cannon.penetration(),0.12),"the conduit trait affects cadence and penetration")
	game.running=false
	game.audio.shutdown()
	await process_frame
	OS.delay_msec(150)
	game.queue_free()
	await process_frame
	paused=false
	print("V020 TOWER CHECKS: %d, FAILURES: %d"%[checks,failures])
	quit(0 if failures==0 else 1)
