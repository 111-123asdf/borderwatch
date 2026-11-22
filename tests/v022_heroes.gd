extends SceneTree
# Full v022 5-Hero Rebuild Suite: save migration, Lord, Druid+2 Wolves, Healer, Werewolf Transform, Gunner Overdrive.
var game: ArenaGame
var checks:=0
var failures:=0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("HERO FAIL: "+message)

func setup(key: String) -> void:
	game=load("res://scenes/arena.tscn").instantiate()
	game.campaign=ArenaCampaign.new("",false)
	game.campaign.data.levels[key]=5
	root.add_child(game)
	await process_frame
	game.start_run(key,"forest")
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	game.hero.position=Vector2(590,418)

func teardown() -> void:
	game.running=false
	game.audio.shutdown()
	await process_frame
	OS.delay_msec(150)
	game.queue_free()
	await process_frame

func run() -> void:
	# 1. Legacy v3 save migration: knight->lord, mage->healer, longbow->werewolf, ranger->gunner, druid->druid
	var old: Dictionary={
		"gems":17,
		"levels":{"knight":3,"ranger":2,"mage":4},
		"cleared":{"forest":true,"creek":false,"ruins":false,"saltport":false},
		"last_run":"","settled":{},"tutorial_done":true,"volume":0.8,"reduced_motion":false,
		"selected_hero":"mage","equipped_towers":["archer","mage","cannon","barracks"]
	}
	var path:="user://hero-migration-"+str(Time.get_ticks_usec())+".cfg"
	var config:=ConfigFile.new()
	config.set_value("campaign","version",3)
	config.set_value("campaign","data",old)
	check(config.save(path)==OK,"write legacy fixture")
	var before:=FileAccess.get_file_as_bytes(path)
	var migrated:=ArenaCampaign.new(path,true)
	check(not migrated.locked and migrated.level("lord")==3 and migrated.level("gunner")==2 and migrated.level("healer")==4,"migrate knight/ranger/mage levels")
	check(migrated.level("druid")==1 and migrated.level("werewolf")==1,"append druid & werewolf at lv1")
	check(migrated.gems()==17 and migrated.selected_hero()=="healer" and migrated.data.cleared.forest,"keep player gems, selected hero mapped & clear flags")
	check(FileAccess.get_file_as_bytes(path)==before,"loading alone leaves legacy save bytes intact")

	old.levels["longbow"]=4
	old.levels["healer"]=5
	old.selected_hero="longbow"
	config.set_value("campaign","data",old)
	check(config.save(path+".mixed")==OK,"write mixed generation fixture")
	var mixed:=ArenaCampaign.new(path+".mixed",true)
	check(not mixed.locked and mixed.level("healer")==5 and mixed.level("werewolf")==4 and mixed.selected_hero()=="werewolf","new keys win and longbow maps to werewolf")
	old.levels["gunner"]=true
	config.set_value("campaign","data",old)
	check(config.save(path+".invalid")==OK,"write invalid level fixture")
	var invalid:=ArenaCampaign.new(path+".invalid",true)
	check(invalid.locked,"migration preserves invalid types for validation")
	# 2. Lord (领主 冥翎) — Pure Heavy Shield Tank
	await setup("lord")
	var hero:=game.hero
	check(hero.block_capacity()==3 and hero.max_health>420.0,"lord starts as heavy 3-block tank")
	var foe_l:=game.spawn_enemy("fox",0,500.0);foe_l.position=hero.position+Vector2(65,0);foe_l.set_physics_process(false)
	check(hero.cast(0,foe_l.position),"lord Q casts")
	hero.release_action()
	check(foe_l.stun>0.0,"lord Q stuns enemies in front cone")
	hero.cancel_action()
	check(hero.cast(1,hero.position),"lord E casts")
	hero.release_action()
	check(hero.lord_shield_clock>0.0 and hero.overheal_shield>150.0 and hero.block_capacity()==4,"lord E grants big shield and +1 block")
	await teardown()

	# 3. Druid (德鲁伊) — Permanent Frost Wolf + Ember Wolf & 1.35x Awaken
	await setup("druid")
	hero=game.hero
	check(hero.companions.size()==2,"druid has exactly two wolf companions")
	check(hero.companions[0]._wolf_key()=="frost_wolf" and hero.companions[1]._wolf_key()=="ember_wolf","druid summons frost_wolf and ember_wolf")
	for beast in hero.companions:
		beast.position=hero.position
		beast.set_physics_process(false)
		beast.health=beast.max_health()*0.5
	check(hero.cast(0,hero.position+Vector2(40,0)),"druid Q command casts")
	hero.release_action()
	check(hero.companions.all(func(b):return b.orders_left>0 and b.health>b.max_health()*0.75),"druid Q commands and heals both wolves")
	hero.cancel_action()
	var frost: Node2D=hero.companions[0]
	frost.take_hit(5000.0,0,true)
	check(frost.recovery==8.0 and not frost.can_block(),"downed frost wolf releases block")
	check(hero.cast(1,hero.position),"druid E frenzy casts")
	hero.release_action()
	for beast in hero.companions:beast._physics_process(0.5)
	check(hero.companions.all(func(b):return b.boost>6.0 and b.boost_visual_scale>1.25 and b.health==b.max_health()),"druid E revives, full-heals and enlarges both wolves toward 1.35x")
	hero.knocked_out=true
	for beast in hero.companions:beast._physics_process(0.016)
	check(hero.companions.all(func(b):return not b.visible),"both wolves leave when druid is down")
	await teardown()

	# 4. Healer (爱神) — Support Aura, Tower/Soldier Haste & Sanctuary Heal/Shield
	await setup("healer")
	hero=game.hero
	game.gold=500;game.build_tower(0,"archer");var tower: ArenaTower=game.towers[0]
	tower.position=hero.position+Vector2(100,0)
	var base_reload:=tower.reload_time()
	check(hero.cast(0,hero.position),"healer Q casts")
	hero.release_action()
	check(hero.healer_blessing_clock>0.0 and tower.reload_time()<base_reload,"healer Q accelerates nearby towers")
	hero.cancel_action()
	hero.health=hero.max_health*0.8
	check(hero.cast(1,hero.position),"healer E sanctuary casts")
	hero.release_action()
	check(hero.healer_sanctuary_clock>0.0,"healer E opens blooming sanctuary")
	hero._physics_process(0.25)
	check(hero.health>hero.max_health*0.8 or hero.overheal_shield>0.0,"healer sanctuary heals self")
	await teardown()

	# 5. Werewolf (狼王 凛风) — Bruiser + Beast-Form Transformation + Lifesteal (No Shield!)
	await setup("werewolf")
	hero=game.hero
	check(hero.visual.active_form=="werewolf" and hero.block_capacity()==2,"werewolf starts in human form with block 2")
	check(hero.cast(0,hero.position),"werewolf Q bloodlust casts")
	hero.release_action()
	check(hero.werewolf_bloodlust_clock>0.0,"werewolf Q activates frost bloodlust")
	hero.cancel_action()
	check(hero.cast(1,hero.position),"werewolf E transform casts")
	hero.release_action()
	check(hero.werewolf_beast_clock>0.0 and hero.visual.active_form=="werewolf_beast" and hero.overheal_shield==0.0,"werewolf E transforms into giant white werewolf with zero shield")
	hero.health=hero.max_health*0.6
	var w1:=game.spawn_enemy("brute",0,500.0);w1.position=hero.position+Vector2(50,-10);w1.set_physics_process(false)
	var w2:=game.spawn_enemy("brute",0,500.0);w2.position=hero.position+Vector2(65,12);w2.set_physics_process(false)
	hero.cancel_action();hero.facing=Vector2.RIGHT;hero.attack_cooldown=0.0;hero.begin_attack(w1);hero.release_action()
	check(w1.health<w1.max_health and w2.health<w2.max_health,"beast form wide ice-claw cleave hits multiple enemies")
	check(hero.health>hero.max_health*0.6,"beast form cleave lifesteals")
	hero.werewolf_beast_clock=0.01;hero._physics_process(0.05)
	check(hero.visual.active_form=="werewolf","werewolf reverts cleanly to human form after ult")
	await teardown()

	# 6. Gunner (星衡) — High-Mobility Glass Cannon + Tactical Dash + Crit Overdrive + Short Chase
	await setup("gunner")
	hero=game.hero
	check(hero.companions.is_empty(),"gunner has no companions")
	check(hero.cast(0,hero.position+Vector2.RIGHT*100),"gunner Q dash casts")
	check(hero.rolling>0.0 and hero.protection>0.0 and hero.empower_shot==1,"gunner Q dashes with invulnerability and empowers next shot")
	hero.rolling=0.0;hero.cancel_action()
	check(hero.cast(1,hero.position),"gunner E overdrive casts")
	hero.release_action()
	check(hero.gunner_overdrive_clock>0.0 and hero.cooldowns[0]==0.0,"gunner E enters overdrive and resets Q cooldown")
	hero.cancel_action();hero.attack_cooldown=0.0
	var g_foe:=game.spawn_enemy("brute",0,500.0);g_foe.position=hero.position+Vector2(140,0);g_foe.set_physics_process(false)
	hero.begin_attack(g_foe);hero.release_action()
	var bolts: Array=game.actors.get_children().filter(func(n):return n is ArenaProjectile and n.presentation=="gunner_crit")
	check(bolts.size()==2 and bolts[0].pierce>=2,"overdrive empowered shot fires twin armor-piercing crit bolts")
	for b in bolts:b.queue_free()

	# Preserve short-chase and explicit click-to-attack invariants
	var road: Curve2D=game.routes[0]
	hero.position=Vector2(431,472)
	var offset:=road.get_closest_offset(Vector2(430,415))
	var chasers: Array[ArenaEnemy]=[]
	for i in range(4):
		var enemy:=game.spawn_enemy("fox",0,offset+i*6)
		enemy.set_physics_process(false)
		chasers.append(enemy)
	game.blocking.update()
	check(chasers.filter(func(a):return a.chase_left>0).size()==2,"two nearest eligible monsters short-chase")
	var runner: ArenaEnemy=chasers.filter(func(a):return a.chase_left>0)[0]
	var anchor:=road.sample_baked(runner.progress,true)
	runner._physics_process(0.2)
	check(runner.position.distance_to(anchor)>2,"short chase steps off road")
	hero.position=Vector2(610,470)
	for i in range(75):
		runner._physics_process(0.02)
		if not runner.chase_active():break
	check(not runner.chase_active() and runner.position.distance_to(anchor)<1.1,"released chaser walks back to original branch and advances")
	game.enemies.clear();hero.shots=0;hero.cancel_action();hero.attack_cooldown=0.0
	hero.queued_attack_point=hero.position+Vector2.RIGHT*130
	hero._physics_process(0.016)
	check(hero.action=="attack","one queued mouse click begins an attack")
	hero.release_action()
	hero.cancel_action()
	hero._physics_process(1.0)
	check(hero.shots==1 and hero.action=="","no new attack without another input")
	await teardown()

	print("V022 HERO CHECKS: %d, FAILURES: %d"%[checks,failures])
	quit(int(failures>0))
