extends SceneTree
# Explicit state fixtures for product rules. No natural-play claims.
var checks:=0
var failures:=0
var game: ArenaGame
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V06 FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check(is_equal_approx(ArenaCombat.resolve(100,0,0.6,0.2),40),"physical uses armour")
	check(is_equal_approx(ArenaCombat.resolve(100,1,0.6,0.2),80),"magic uses magic resistance")
	check(is_equal_approx(ArenaCombat.resolve(100,1,0,0.2,0.1),88),"magic exposure applies only to magic")
	check(is_equal_approx(ArenaCombat.resolve(100,0,0,0,0.1),100),"physical ignores magic exposure")
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game;await process_frame
	check(game.hud.root.find_child("开始守望",true,false)!=null,"entry keeps the direct start action")
	check(game.hud.root.find_child("英雄训练",true,false)==null,"entry has no retired hero training action")
	game.start_run("knight","forest")
	check(game.routes.size()==1 and game.level_definition.sites.size()==8,"first level authored road and sites")
	check(game.available_towers()==["archer","barracks"],"first wave introduces archers and barracks")
	var before:=game.gold
	check(not game.build_tower(0,"mage") and game.gold==before,"locked tower cannot consume currency")
	check(not game.build_tower(99,"archer") and game.gold==before,"only authored sites can build")
	check(game.build_tower(0,"barracks"),"barracks builds at a fixed site")
	check(game.soldiers.size()==3,"barracks supplies three soldiers")
	check(not game.build_tower(0,"archer"),"occupied site cannot be overwritten")
	var tower: ArenaTower=game.towers[0];var has_hp:=false
	for property in tower.get_property_list():
		if property.name in ["health","max_health"]:has_hp=true
	check(not has_hp,"tower has no hit points")
	var has_resource:=false
	for property in game.hero.get_property_list():
		if property.name in ["energy","max_energy","shield","max_shield","weapon_inventory"]:has_resource=true
	var has_progression:=false
	for property in game.get_property_list():
		if property.name=="progression":has_progression=true
	check(not has_resource and not has_progression,"hero has no retired weapon or metaprogression resources")
	game.gold=2000
	check(tower.upgrade() and tower.upgrade() and tower.level==3,"tower reaches level three")
	check(not tower.upgrade(),"tower cannot exceed level three")
	game.cycle=3;check("mage" in game.available_towers(),"magic tower unlocks in wave three")
	game.cycle=5;check("cannon" in game.available_towers(),"cannon unlocks in wave five")
	var brute:=game.spawn_enemy("brute",0,200);var fox:=game.spawn_enemy("fox",0,210);var overflow:=game.spawn_enemy("fox",0,220)
	game.hero.position=brute.position+Vector2(10,0);game.hero.velocity=Vector2.ZERO
	game.blocking.update()
	check(game.blocking.load_for(game.hero)==3,"knight blocks three capacity including heavy")
	check(overflow.blocker==null,"excess enemies continue unblocked")
	var old:=brute.health;brute.take_hit(20,0,"hero");var physical:=old-brute.health
	old=brute.health;brute.take_hit(20,1,"hero");check(old-brute.health>physical*2,"magic clearly counters heavy armour")
	game.hero.cooldowns=[7.0,29.0];game.hero.protection=0;game.hero.take_hit(10000,0,true)
	check(game.hero.knocked_out and not game.game_over,"hero knockout does not fail the level")
	check(game.blocking.load_for(game.hero)==0,"knockout immediately releases all blocking")
	check(not game.hero.cast(0,Vector2.ZERO),"knocked-out hero cannot cast")
	game.hero._physics_process(15.0)
	check(not game.hero.knocked_out and game.hero.health==game.hero.max_health,"hero revives after fifteen seconds")
	check(is_equal_approx(game.hero.cooldowns[1],14.0),"revive does not reset skill cooldowns")
	game.hero.protection=0;game.hero.health=100;game.hero.combat_delay=5
	game.hero._physics_process(4)
	check(game.hero.health==100,"combat prevents early regeneration")
	game.hero._physics_process(2)
	check(game.hero.health>100,"out-of-combat hero regenerates")
	game.phase="rest";game.phase_clock=10;game.rest_duration=20;game.rewarded=false;game.wave_preview=false
	before=game.gold;game.request_wave();check(game.wave_preview and game.gold==before,"first click previews only")
	game.request_wave();check(game.phase=="spawn" and game.gold==before+6,"second click grants proportional reward once")
	game.request_wave();check(game.gold==before+6,"wave reward cannot be farmed")
	var boss:=game.spawn_enemy("moth",0,200);game.hero.position=boss.position
	game.blocking.update();check(boss.blocker==null,"boss cannot be blocked")
	var soldier: ArenaSoldier=game.soldiers[0];soldier.take_hit(10000,0,true)
	check(soldier.dead and is_equal_approx(soldier.respawn_clock,10),"soldier defeat schedules replacement")
	soldier._physics_process(10);check(not soldier.dead and soldier.health==soldier.max_health,"soldier returns without replacing the building")
	var routepoint:=game.routes[0].sample_baked(brute.progress,true);brute.push_back(20)
	check(brute.position.is_equal_approx(game.routes[0].sample_baked(brute.progress,true)) and brute.progress>=0,"knockback remains on road")
	check(routepoint.distance_to(brute.position)>1,"knockback actually changes route progress")
	game.choice_queue=0;game.choice_open=false
	game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	get_tree_safe()
	print("V06 RULE CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
func get_tree_safe() -> void:paused=false
