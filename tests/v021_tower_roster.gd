extends "v06_window.gd"

func unit(point: Vector2) -> ArenaEnemy:
	var enemy:=game.spawn_enemy("fox",0,100)
	enemy.position=point
	enemy.max_health=2000
	enemy.health=2000
	return enemy

func clear_targets() -> void:
	for enemy in game.enemies.duplicate(): game.remove_enemy(enemy)

func run() -> void:
	var review:="--review" in OS.get_cmdline_user_args()
	game=load("res://scenes/arena.tscn").instantiate()
	game.campaign=ArenaCampaign.new("",false)
	root.add_child(game)
	current_scene=game
	await frames()
	var campaign:=game.campaign
	check(campaign.tower_loadout()==ArenaDefinitions.DEFAULT_TOWERS,"old four form the default loadout")
	check(not campaign.equip_towers(["storm","storm"]),"duplicate equipment rejected")
	check(not campaign.equip_towers(["storm","lens","snare","mage","archer"]),"a fifth kind is rejected")
	await press("StartCampaign")
	await press("TowerHall")
	for kind in ArenaDefinitions.TOWER_IDS:
		check(game.hud.menu.find_child("Tower_"+kind,true,false)!=null,"workshop offers "+kind)
	for swap in [["storm","archer"],["lens","mage"],["snare","cannon"]]:
		await press("Tower_"+swap[0])
		await press("EquipTower")
		check(campaign.tower_loadout().size()==4 and swap[0] not in campaign.tower_loadout(),"replacement waits for a slot")
		if swap[0]=="storm":
			await press("CancelReplacement")
			check(campaign.tower_loadout()==ArenaDefinitions.DEFAULT_TOWERS,"cancel keeps each slot")
			await press("EquipTower")
		await press("Replace_"+swap[1])
		check(swap[0] in campaign.tower_loadout() and swap[1] not in campaign.tower_loadout(),"confirmed atomic swap")
	if review: await snapshot("v021-workshop")
	await press("Back")
	await press("Level_forest")
	await press("Deploy")
	game.choose_defense_rule("")
	game.set_physics_process(false)
	var chosen:=["storm","lens","snare","barracks"]
	check(game.run_towers==chosen,"deployment keeps the selected order")
	game.hud.show_context(0)
	check(game.hud.context.find_children("Build_*","Button",false,false).size()==4,"exactly four build buttons")
	check(not game.build_tower(0,"archer"),"backend rejects unequipped tower")
	game.campaign.equip_towers(ArenaDefinitions.DEFAULT_TOWERS)
	check(game.run_towers==chosen and "archer" not in game.available_towers(),"mid-run loadout is immutable")
	game.hud.close_context()
	game.gold=5000
	clear_targets()
	for index in chosen.size():
		check(game.build_tower(index,chosen[index]),"build "+chosen[index])
		game.site_tower(index)._physics_process(1.01)
		game.site_tower(index).set_physics_process(false)
	if review: await snapshot("v021-deployed")
	var storm:=game.site_tower(0)
	var lens:=game.site_tower(1)
	var snare:=game.site_tower(2)
	var enemies: Array[ArenaEnemy]=[]
	for i in range(4): enemies.append(unit(storm.position+Vector2(40+72*i,0)))
	storm._fire_at(enemies[0])
	check(is_equal_approx(2000-enemies[0].health,28) and is_equal_approx(2000-enemies[1].health,19.6) and is_equal_approx(2000-enemies[2].health,13.72) and enemies[3].health==2000,"three unique jumps with falloff and a hard cap")
	enemies[1].position+=Vector2(0,400)
	storm._fire_at(enemies[0])
	check(is_equal_approx(2000-enemies[2].health,13.72),"chain cannot skip a missing conductor")
	enemies[1].position-=Vector2(0,400)
	game.orders.marked=enemies[0]
	var previous:=enemies[1].health
	storm._fire_at(enemies[0])
	check(enemies[1].health==previous,"a mark in range suppresses side jumps")
	game.orders.marked=null
	clear_targets()
	var first:=unit(lens.position+Vector2(50,0))
	var second:=unit(lens.position+Vector2(65,0))
	for i in range(6): lens._fire_at(first)
	check(lens.focus_layers==4 and is_equal_approx(2000-first.health,17*(1+1.35+1.7+2.05+2.4+2.4)),"beam ramps and caps at 2.4 times base damage")
	lens._fire_at(second)
	check(lens.focus_layers==0 and is_equal_approx(2000-second.health,17),"new target starts at base power")
	lens._fire_at(second)
	second.position+=Vector2(600,0)
	lens._physics_process(0.01)
	check(lens.focus_target==null and lens.focus_layers==0,"leaving range clears focus")
	clear_targets()
	var road: Curve2D=game.routes[game.nearest_road(snare.position).route]
	var destination:=road.sample_baked(road.get_closest_offset(snare.rally_point)+36,true)
	check(snare.set_rally(destination) and not snare.set_rally(Vector2(-500,-500)),"snare accepts a road point and rejects a distant click")
	var at_center:=unit(snare.rally_point)
	var rim:=unit(snare.rally_point+Vector2(49,0))
	var outside:=unit(snare.rally_point+Vector2(85,0))
	snare._physics_process(0.1)
	check(at_center.health==2000,"relocated trap must arm")
	snare._physics_process(1.3)
	check(at_center.health<2000 and rim.health<2000 and outside.health==2000 and at_center.slow>0,"trap hits and slows only inside its burst")
	previous=at_center.health
	snare._physics_process(0.1)
	check(at_center.health==previous and not snare.trigger_bonus_salvo(),"reloading trap cannot retrigger")
	clear_targets()
	for tower: ArenaTower in [storm,lens,snare]:
		var routes:=ArenaDoctrines.for_tower(tower.kind)
		check(routes.size()==3,"three doctrines for "+tower.kind)
		for entry in routes: check(ArenaDoctrines.branches(entry.id).size()==2,"two upgrades for "+entry.id)
		check(tower.upgrade(),"start tier two")
		tower._physics_process(1.01)
		check(tower.upgrade(routes[0].id),"start tier three")
		tower._physics_process(1.01)
		check(tower.level==3 and tower.doctrine_id==routes[0].id and tower.upgrade_branch(0),"tier, doctrine and purchased branch take effect")
	check(storm.doc_mod("chain_count")==5 and storm.doc_mod("chain_reach",105)==120,"coil modifications affect hop count and reach")
	check(is_equal_approx(lens.doc_mod("focus_step",0.35),0.63),"lens branch increases per-hit scaling")
	check(snare.snare_radius()>95,"trap branch enlarges the capture area")
	await close_game()
	check_formal_towers()
	await close_game()
	print("V021 ROSTER CHECKS: %d, FAILURES: %d"%[checks,failures])
	quit(0 if failures==0 else 1)

func close_game() -> void:
	game.running=false
	game.audio.shutdown()
	await frames()
	OS.delay_msec(150)
	game.queue_free()
	await frames()

func check_formal_towers() -> void:
	game=load("res://scenes/arena.tscn").instantiate()
	game.campaign=ArenaCampaign.new("",false)
	root.add_child(game)
	current_scene=game
	game.start_run("knight","forest")
	game.choose_defense_rule("")
	game.gold=5000
	game.set_physics_process(false)
	clear_targets()
	for index in ArenaDefinitions.DEFAULT_TOWERS.size():
		check(game.build_tower(index,ArenaDefinitions.DEFAULT_TOWERS[index]),"construct default fortification")
		game.site_tower(index)._physics_process(1.01)
		game.site_tower(index).set_physics_process(false)
	var bow:=game.site_tower(0)
	var mage:=game.site_tower(1)
	var gun:=game.site_tower(2)
	var camp:=game.site_tower(3)
	var muzzle:=bow.muzzle()
	var a:=unit(muzzle+Vector2(75,19))
	var b:=unit(muzzle+Vector2(130,19))
	a.stun=10.0
	b.stun=10.0
	bow._fire_at(b)
	var shots:=game.actors.get_children().filter(func(n): return n is ArenaProjectile)
	check(shots.size()==1 and shots[0].trial_pierce_scales.size()==4,"formal bow launches a piercing shot")
	shots[0]._physics_process(0.4)
	check(a.health<2000 and b.health<2000 and b.tower_weakness_clock>0,"one bow shot marks both enemies in a line")
	var hit:=b.take_hit(10,0,"hero")
	check(is_equal_approx(hit,13) and b.tower_weakness_clock==0,"first hero hit consumes the bow opening")
	a._physics_process(3.1)
	check(a.tower_weakness_clock==0,"unclaimed weaknesses expire in normal play")
	clear_targets()
	a=unit(mage.position+Vector2(45,0))
	b=unit(mage.position+Vector2(mage.attack_range()*0.85,0))
	mage._fire_at(a)
	check(a.tower_frost_layers==2 and b.tower_frost_layers==1,"formal frost pulse has inner and outer zones")
	mage._fire_at(a)
	check(a.tower_control_clock>0 and b.tower_frost_layers==2,"inner zone freezes earlier")
	game.orders.marked=a
	var old_hp:=b.health
	mage._fire_at(a)
	check(b.health==old_hp,"frost pulse respects focused fire")
	game.orders.marked=null
	game.keystone_mode=true
	game.keystones.append("refract")
	var count:=game.actors.get_child_count()
	mage._fire_at(a)
	check(game.actors.get_child_count()==count+1 and game.actors.get_child(-1) is ArenaProjectile,"refracting pulse creates a single echo projectile")
	clear_targets()
	var aim:=gun.position+Vector2(75,0)
	a=unit(aim)
	b=unit(aim+Vector2(gun.splash_radius()*0.85,0))
	check(gun.set_bombard(aim),"formal cannon accepts a fixed position")
	gun._fire_at(a)
	var shell: Dictionary=game.delayed.back()
	check(shell.point==aim and gun.trial_shell_core()<gun.splash_radius(),"manual shell keeps its center and falloff radius")
	game.resolve_trial_shell(shell)
	check(a.health<b.health and a.tower_control_clock>0 and b.tower_control_clock==0,"center suffers stronger damage and control")
	check(camp.troops.size()==3 and camp.troops[0].max_health>=160,"garrison has three reinforced guards")
	clear_targets()
	a=unit(camp.rally_point)
	a.elite=true
	check(game.blocking.weight_for(a,camp.troops[0])==1,"a light elite consumes one guard slot")
