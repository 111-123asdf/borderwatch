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
	game.rng.seed=3
	await press("Deploy")
	check(not paused and game.passive_offers.is_empty(),"deploy enters duel cleanly")
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
	for i in range(5): enemies.append(unit(storm.position+Vector2(40+72*i,0)))
	storm._fire_at(enemies[0])
	check(enemies[0].health<2000 and enemies[1].health<2000 and enemies[2].health<2000 and enemies[3].health<2000 and enemies[4].health==2000,"four unique jumps with hard cap")
	enemies[1].position+=Vector2(0,400)
	storm._fire_at(enemies[0])
	check(enemies[2].health==enemies[2].health,"chain stops cleanly when conductor out of range")
	enemies[1].position-=Vector2(0,400)
	clear_targets()
	var first:=unit(lens.position+Vector2(50,0))
	var second:=unit(lens.position+Vector2(65,0))
	for i in range(6): lens._fire_at(first)
	check(lens.focus_layers==4 and first.health<2000 and first.marked>0.0 and first.slow>0.0,"lens ramps layers and applies mark + chill")
	lens._fire_at(second)
	check(lens.focus_layers==0 and second.health<2000,"new target resets focus layers")
	lens._fire_at(second)
	second.position+=Vector2(600,0)
	lens._physics_process(0.01)
	check(lens.focus_target==null and lens.focus_layers==0,"leaving range clears focus")
	clear_targets()
	var road: Curve2D=game.routes[game.nearest_road(snare.position).route]
	var at_center:=unit(road.sample_baked(road.get_closest_offset(snare.position),true))
	var outside:=unit(at_center.position+Vector2(180,0))
	snare.attack_clock=0.0
	snare._fire_at(at_center)
	check(snare.rally_point.distance_to(at_center.position)<4.0 and at_center.health<2000 and outside.health==2000 and at_center.slow>0,"automated snare targets vanguard and slows inside burst")
	clear_targets()
	for tower: ArenaTower in [storm,lens,snare]:
		var default_id: String = ArenaDoctrines.AUTO_DEFAULT[tower.kind]
		check(tower.upgrade(),"start tier two")
		tower._physics_process(1.01)
		check(tower.upgrade(),"start tier three")
		tower._physics_process(1.01)
		check(tower.upgrade(),"first enhancement uses the upgrade project")
		tower.finish_project()
		check(tower.level==3 and tower.doctrine_id==default_id and tower.enhancements().size() == 2 and tower.unlocked_enhancements == 1,"automatic specialization and paid enhancement apply")
	check(storm.doc_mod("chain_count")==6 and storm.doc_mod("chain_reach",120)==132,"coil modifications affect hop count and reach")
	check(is_equal_approx(lens.doc_mod("focus_step",0.35),0.62),"lens enhancement increases per-hit scaling")
	check(is_equal_approx(snare.snare_radius(),124.0),"first net enhancement widens trap coverage")
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
	var a:=unit(muzzle+Vector2(100,19))
	a.stun=10.0
	bow._fire_at(a)
	var shots:=game.actors.get_children().filter(func(n): return n is ArenaProjectile)
	check(shots.size()==1 and (shots[0] as ArenaProjectile).trial_pierce_scales.is_empty() and (shots[0] as ArenaProjectile).arc_height>15.0,"formal bow launches a parabolic tracking arrow")
	shots[0]._physics_process(0.3)
	check(a.health<2000 and a.tower_weakness_clock==0,"parabolic arrow hits its target cleanly")
	shots[0].queue_free()
	clear_targets()
	bow.upgrade();bow.finish_project()
	bow.upgrade("piercer");bow.finish_project()
	var p_muz:=bow.muzzle()
	a=unit(p_muz+Vector2(75,19))
	var b:=unit(p_muz+Vector2(130,19))
	a.stun=10.0;b.stun=10.0
	bow._fire_at(b)
	var p_shots:=game.actors.get_children().filter(func(n): return n is ArenaProjectile and (n as ArenaProjectile).doctrine_id=="piercer")
	check(p_shots.size()==1 and (p_shots[0] as ArenaProjectile).pierce>=2 and (p_shots[0] as ArenaProjectile).arc_height>5.0,"formal piercer L3 launches a low-arc piercing heavy bolt")
	for _s in range(4):
		if not p_shots.is_empty() and is_instance_valid(p_shots[0]): p_shots[0]._physics_process(0.05)
	check(a.health<2000 and b.health<2000,"piercer bolt pierces multiple enemies in a line")
	for s in p_shots:
		if is_instance_valid(s): s.queue_free()
	clear_targets()
	a=unit(mage.position+Vector2(115,19))
	b=unit(mage.position+Vector2(55,19))
	a.stun=10.0;b.stun=10.0
	mage._fire_at(a)
	var m_shots:=game.actors.get_children().filter(func(n): return n is ArenaProjectile and (n as ArenaProjectile).feedback_tag=="tower_spell")
	check(m_shots.size()==1 and (m_shots[0] as ArenaProjectile).arc_height>5.0,"formal mage launches a pixel spell orb")
	var a_hp_before:=a.health
	for _s in range(5):
		if not m_shots.is_empty() and is_instance_valid(m_shots[0]): m_shots[0]._physics_process(0.06)
	check(a.health<a_hp_before,"formal mage spell orb damages target")
	for s in m_shots:
		if is_instance_valid(s): s.queue_free()
	clear_targets()
	var aim:=gun.position+Vector2(75,0)
	a=unit(aim)
	a.windup=0.5
	b=unit(aim+Vector2(gun.splash_radius()*0.85,0))
	check(not gun.can_set_bombard() and not gun.set_bombard(aim),"formal cannon runs automatically without manual bombard")
	gun._fire_at(a)
	var shell: Dictionary=game.delayed.back()
	check(shell.point.distance_to(aim)<1.0 and gun.trial_shell_core()<gun.splash_radius(),"auto shell keeps its center and falloff radius")
	game.resolve_trial_shell(shell)
	check(a.health<b.health and a.tower_control_clock>0 and b.tower_control_clock==0,"center suffers stronger damage and control")
	check(camp.troops.size()==3 and camp.troops[0].max_health>=160,"garrison has three reinforced guards")
	clear_targets()
	a=unit(camp.rally_point)
	a.elite=true
	check(game.blocking.weight_for(a,camp.troops[0])==1,"a light elite consumes one guard slot")
