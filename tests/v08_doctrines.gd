extends SceneTree
# Explicit fixtures for L3 doctrine data and behaviour. No natural-play claims.
var checks:=0
var failures:=0
var game: ArenaGame
var towers: Dictionary={}
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V08 FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func tower_for(kind: String) -> ArenaTower:
	game.gold=20000
	for index in range(game.level_definition.sites.size()):
		if game.site_tower(index)==null and game.build_tower(index,kind):return game.site_tower(index)
	return null
func run() -> void:
	check_data()
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);await process_frame
	game.progression=ArenaProgression.new("user://fixture-doctrine.cfg",false)
	game.start_run("knight","creek")
	game.cycle=5;game.phase="rest";game.phase_clock=60;game.rest_duration=60
	check_upgrade_flow()
	check_archer()
	check_mage()
	check_cannon()
	check_enemy_effects()
	check_zone()
	check_menu()
	check_barracks()
	game.choice_queue=0;game.choice_open=false
	game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	paused=false
	print("V08 DOCTRINE CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
func check_data() -> void:
	var seen: Dictionary={}
	check(ArenaDoctrines.LIST.size()==12,"twelve authored doctrines")
	for entry in ArenaDoctrines.LIST:
		var label:=str(entry.get("id",""))
		check(not seen.has(label),"doctrine id is unique: "+label)
		seen[label]=true
		check(str(entry.get("tower","")) in ArenaDefinitions.TOWER_IDS,label+" has a tower kind")
		check(str(entry.get("name",""))!="" and str(entry.get("role",""))!="",label+" names its role")
		check(str(entry.get("summary",""))!="" and str(entry.get("drawback",""))!="",label+" states effect and cost")
		var effects: Dictionary=entry.get("effects",{})
		check(not effects.is_empty(),label+" has effects")
		for effect_key in effects:check(str(effect_key) in ArenaDoctrines.EFFECT_KEYS,label+" uses known key "+str(effect_key))
		var pressure:=float(effects.get("damage_mult",1.0))/maxf(0.01,float(effects.get("interval_mult",1.0)))
		check(pressure<=2.0,label+" stays inside the power guardrail")
	for key in ["archer","mage","cannon","barracks"]:check(ArenaDoctrines.for_tower(key).size()==3,"three doctrines per "+key)
func check_upgrade_flow() -> void:
	var tower:=tower_for("archer");towers["archer"]=tower
	check(tower.upgrade() and tower.level==2 and not tower.awaiting_doctrine,"level two stays numeric")
	check(tower.upgrade() and tower.level==3 and tower.awaiting_doctrine and tower.doctrine_id=="","level three asks for a doctrine")
	check(not tower.choose_doctrine("frost"),"wrong tower kind is rejected")
	check(tower.choose_doctrine("sentinel") and tower.doctrine_id=="sentinel" and not tower.awaiting_doctrine,"doctrine applies once")
	check(not tower.choose_doctrine("repeater"),"doctrine cannot be replaced")

func check_archer() -> void:
	var tower: ArenaTower=towers["archer"]
	var reach:=float(tower.data.reach)+(tower.level-1)*16
	check(is_equal_approx(tower.attack_range(),reach*1.5),"sentinel raises range by half")
	check(is_equal_approx(tower.reload_time(),float(tower.data.interval)/(1.0+0.14*2.0)*1.25),"sentinel costs attack speed")
	check(tower.forced_target()=="strongest" and tower.target_mode=="strongest","sentinel forces strongest targeting")
	check(is_equal_approx(tower.doc_mod("mark_bonus"),0.15),"sentinel marks for extra damage")
	var repeater:=tower_for("archer")
	repeater.upgrade();repeater.upgrade("repeater")
	var repeater_reach:=float(repeater.data.reach)+(repeater.level-1)*16
	check(is_equal_approx(repeater.attack_range(),repeater_reach*0.85),"repeater trades range")
	check(is_equal_approx(repeater.reload_time(),float(repeater.data.interval)/(1.0+0.14*2.0)*0.625),"repeater buys attack speed")
	game.rng.seed=20261112
	var enemy:=game.spawn_enemy("fox",0,300)
	var triples:=0
	for index in range(120):
		var before:=game.actors.get_child_count()
		repeater.fire_shots(enemy,10.0)
		if game.actors.get_child_count()-before>1:triples+=1
	check(triples>=15 and triples<=45,"repeater triple volley fires about a quarter of the time")
	var piercer:=tower_for("archer")
	piercer.upgrade();piercer.upgrade("piercer")
	check(is_equal_approx(piercer.penetration(),0.4),"piercer ignores forty percent armour")
	var brute:=game.spawn_enemy("brute",0,320)
	var fox:=game.spawn_enemy("fox",0,340)
	check(is_equal_approx(piercer.doctrine_multiplier(brute),1.25),"piercer punishes heavy armour")
	check(is_equal_approx(piercer.doctrine_multiplier(fox),1.0),"piercer leaves light targets alone")
func check_mage() -> void:
	var tower:=tower_for("mage");towers["mage"]=tower
	tower.upgrade();tower.upgrade("frost")
	check(is_equal_approx(tower.doc_mod("damage_mult"),0.8),"frost pays damage")
	check(is_equal_approx(tower.penetration(),0.0),"frost has no penetration")
	check(is_equal_approx(tower.doc_mod("slow_amount"),0.3) and tower.doc_mod("freeze_time")==1.5,"frost carries slow and freeze")
	var breaker:=tower_for("mage")
	breaker.upgrade();breaker.upgrade("breaker")
	check(is_equal_approx(breaker.penetration(),0.4),"breaker ignores forty percent resistance")
	var wisp:=game.spawn_enemy("wisp",0,360)
	var fox:=game.spawn_enemy("fox",0,380)
	check(is_equal_approx(breaker.doctrine_multiplier(wisp),1.25),"breaker punishes high resistance")
	check(is_equal_approx(breaker.doctrine_multiplier(fox),1.0),"breaker ignores low resistance")
	var arcfire:=tower_for("mage")
	arcfire.upgrade();arcfire.upgrade("arcfire")
	check(arcfire.doc_mod("explode_radius")==60.0,"arcfire detonates on kill")
	var victim:=game.spawn_enemy("fox",0,500);var witness:=game.spawn_enemy("fox",0,520)
	victim.position=Vector2(700,500);witness.position=Vector2(720,500)
	var witness_health:=witness.health
	victim.last_tower=arcfire
	victim.take_hit(1000,1,"tower")
	check(witness.health<witness_health,"arcfire explosion hits nearby enemies")
func check_cannon() -> void:
	var tower:=tower_for("cannon");towers["cannon"]=tower
	var base_radius:=64.0+(3-1)*12
	tower.upgrade();tower.upgrade("siege")
	check(is_equal_approx(tower.splash_radius(),base_radius*0.6),"siege shrinks splash")
	var elite:=game.spawn_enemy("fox",0,400,true)
	check(is_equal_approx(tower.doctrine_multiplier(elite),1.5*1.4),"siege punishes elites")
	var frag:=tower_for("cannon")
	frag.upgrade();frag.upgrade("frag")
	check(is_equal_approx(frag.splash_radius(),base_radius*1.5),"frag widens splash")
	check(frag.doc_mod("knockback")==15.0,"frag knocks enemies back")
func check_enemy_effects() -> void:
	var marked:=game.spawn_enemy("brute",0,420)
	var plain:=game.spawn_enemy("brute",0,440)
	marked.apply_mark(2.0,0.15)
	check(marked.marked>0 and marked.mark_bonus==0.15,"mark is stored on the target")
	var marked_before:=marked.health;var plain_before:=plain.health
	marked.take_hit(100,0,"hero");plain.take_hit(100,0,"hero")
	var marked_loss:=marked_before-marked.health;var plain_loss:=plain_before-plain.health
	check(is_equal_approx(marked_loss,plain_loss*1.15),"mark raises every damage source by fifteen percent")
	var frozen:=game.spawn_enemy("fox",0,460)
	for index in range(4):frozen.frost_hit(0.3,2.0,5,1.5)
	check(frozen.frost_stacks==4 and frozen.stun<=0.0,"frost stacks do not freeze early")
	check(is_equal_approx(frozen.slow_amount,0.3) and frozen.slow>0,"frost slows before freezing")
	frozen.frost_hit(0.3,2.0,5,1.5)
	check(frozen.frost_stacks==0 and frozen.stun>=1.4,"fifth stack freezes the target")
func check_menu() -> void:
	var tower:=tower_for("archer")
	tower.upgrade();tower.upgrade()
	game.selected_site=tower.site_id;game.hud.show_context(tower.site_id)
	check(tower.awaiting_doctrine and game.hud.context.size.x>=480,"doctrine menu widens the tower panel")
	check(game.hud.context.find_child("Doctrine_sentinel",true,false)!=null,"doctrine menu lists the first card")
	check(game.hud.context.find_child("Doctrine_repeater",true,false)!=null and game.hud.context.find_child("Doctrine_piercer",true,false)!=null,"doctrine menu lists every option")
	check(game.choose_doctrine(tower.site_id,"piercer") and tower.doctrine_id=="piercer","menu choice applies through the game")
	check(not tower.awaiting_doctrine and game.hud.context.size.x<480,"menu returns to the normal tower panel")
	game.hud.close_context()
func check_zone() -> void:
	var fox:=game.spawn_enemy("fox",0,480)
	var point:=Vector2(600,600)
	fox.position=point
	var before:=fox.health
	game.add_zone(point,64,30.0,4.0,0,"tower")
	game._physics_process(0.3)
	check(fox.health<before,"burning ground ticks real damage")
	check(not game.zones.is_empty() and float(game.zones[0].life)<4.0,"zone keeps its remaining lifetime")
	game._physics_process(4.0)
	check(game.zones.is_empty(),"zone expires")
	var after:=fox.health
	game._physics_process(0.3)
	check(fox.health==after,"zone damage stops after expiry")
func check_barracks() -> void:
	for tower in game.towers.duplicate():tower.sell()
	game.hud.close_context();game.gold=20000
	var shield:=tower_for("barracks")
	check(shield.upgrade() and shield.upgrade() and shield.awaiting_doctrine,"barracks asks for a doctrine at level three")
	check(shield.choose_doctrine("shield") and shield.doctrine_id=="shield","shield doctrine applies")
	check(shield.troops.size()==3 and shield.troops[0].block_capacity()==2,"shield soldiers hold two each")
	check(shield.troops[0].taunt(),"shield soldiers taunt")
	check(is_equal_approx(shield.troops[0].max_health,210.0*1.5),"shield soldiers gain half health")
	var hunter:=tower_for("barracks")
	hunter.upgrade();hunter.upgrade("hunter")
	check(hunter.troops.size()==2 and hunter.troops[0].ranged(),"hunter keeps two ranged soldiers")
	check(is_equal_approx(hunter.troops[0].max_health,210.0*0.8),"hunter soldiers lose health")
	check(is_equal_approx(hunter.troops[0].attack_range(),180.0),"hunter soldiers reach further")
	var charge:=tower_for("barracks")
	charge.upgrade();charge.upgrade("charge")
	check(is_equal_approx(charge.troops[0].move_speed(),110.0*1.3),"charge soldiers move faster")
	check(is_equal_approx(charge.troops[0].soldier_mod("charge_stun"),1.0),"charge soldiers stun on contact")
	var soldier: ArenaSoldier=shield.troops[0]
	soldier.position=Vector2(500,500)
	var first:=game.spawn_enemy("fox",0,700);var second:=game.spawn_enemy("fox",0,720)
	first.position=soldier.position+Vector2(-12,0);second.position=soldier.position+Vector2(12,0)
	game.blocking.update()
	check(first.blocker==soldier and second.blocker==soldier,"shield soldier intercepts two attackers")
	var prey:=game.spawn_enemy("fox",0,740)
	prey.position=hunter.troops[0].position+Vector2(80,0)
	hunter.troops[0].attack_clock=0
	var before:=game.actors.get_child_count()
	hunter.troops[0]._physics_process(0.016)
	check(game.actors.get_child_count()>before,"hunter soldier shoots from range")
