extends SceneTree
var game: ArenaGame
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V015 STAGE3 FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func frames() -> void:
	await process_frame;await process_frame
func run() -> void:
	var def:=ArenaLevelCatalog.definition("ruins")
	check(str(def.get("perk_mode",""))=="keystone","stage 3 runs in keystone mode")
	check(str(def.get("boss_kind",""))=="colossus","stage 3 boss is colossus")
	check(Vector2(def.core).distance_to(Vector2(1120,560))<1.0,"stage 3 features central sanctum defense core (860,496)")
	check(Vector2(def.hero_spawn).distance_to(Vector2(1030,600))<1.0,"stage 3 hero_spawn matches shared contract")
	check(def.routes.size()==4,"stage 3 defines 4 main routes")
	check(Vector2(def.routes[0][0]).x<0 and Vector2(def.routes[1][0]).x<0,"routes 0 and 1 enter from NW/SW")
	check(Vector2(def.routes[2][0]).x>1600 and Vector2(def.routes[3][0]).x>1600,"routes 2 and 3 enter from SE/NE")
	var bg: Dictionary=def.get("bridge_gate",{})
	check(not bg.is_empty() and Vector2(bg.get("point",Vector2.ZERO)).distance_to(Vector2(480,800))<1.0,"bridge_gate configured at (592,688)")
	check(def.sites.size()==18 and def.get("site_traits",[]).size()==18 and def.get("site_roles",[]).size()==18,"stage 3 defines 13 sites with traits and roles")
	var required_paths: Array[String]=[
		str(def.map_art),str(def.preview_art),
		"res://assets/v017/towers.png",
		"res://assets/v016/fx_slash.png","res://assets/v016/fx_arcane_blast.png",
		"res://assets/v016/fx_lightning_arc.png","res://assets/v016/fx_frost_shatter.png",
		"res://assets/v016/fx_shield_break.png","res://assets/v016/fx_hit_spark.png",
		"res://assets/v016/fx_fire_brazier.png","res://assets/v016/fx_ground_slam.png",
		"res://assets/v016/fx_upgrade_sigil.png"
	]
	for path in required_paths:
		check(ResourceLoader.exists(path),"stage 3 art/scene exists: "+path)
	check(FileAccess.file_exists("res://assets/v016/fx_manifest.json"),"pixelfx fx_manifest.json exists")
	for kind in ["construct_hound","rune_warden","astral_prism","rift_bomber","void_harvester","colossus"]:
		check(ArenaCreature.sheet_path(kind)=="res://assets/v017/creature_"+kind+".png","v017 painted sheet resolved for "+kind)
		check(ResourceLoader.exists("res://assets/v016/creature_"+kind+"_emit.png"),"v016 emit mask exists for "+kind)
		var creature:=ArenaCreature.new();root.add_child(creature);creature.configure(kind)
		check(not creature.is_pixel_v016 and creature.texture_filter==CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,"painted sampling for "+kind)
		check(creature.construct_rig!=null and creature.construct_rig.configured and creature.construct_rig.pieces.size()>=2,"articulated rig mounted for "+kind)
		for anim in ["walk","attack","down"]:
			check(creature.sprite_frames.has_animation(anim) and creature.sprite_frames.get_frame_count(anim)==6,"stage 3 enemy anim "+kind+" "+anim)
		creature.queue_free()

	game=load("res://scenes/arena.tscn").instantiate()
	game.campaign=ArenaCampaign.playtest()
	root.add_child(game);current_scene=game;await frames()
	check(game.campaign.can_deploy("ruins"),"playtest campaign allows ruins deployment")

	game.start_run("knight","ruins");await frames()
	check(game.keystone_mode,"keystone mode active on ruins")
	check(game.altars.size()==1,"one automatic support altar instantiated")
	check(game.routes.size()==4,"game instantiates 4 routes on ruins")

	# Painted registered terrain and engine-rendered actors replace pixel TileMap assertions.
	check(game.tilemap_scene==null and game.ground.visible,"painted terrain active without old TileMap overlay")
	check(game.ground.texture.get_width()==2000 and game.ground.texture.get_height()==1125,"registered 1600x900 terrain")
	check(str(game.ground.texture.resource_path)==str(def.map_art),"runtime terrain matches level configuration")
	for kind in ArenaDefinitions.TOWER_IDS:
		for tier in range(1,4):
			check(ResourceLoader.exists("res://assets/v017/tower_"+kind+"_"+str(tier)+"_part.png"),"independent movable tower part "+kind+str(tier))
	check(game.atmosphere!=null,"ArenaAtmosphere mounted on ruins")
	if game.atmosphere!=null:
		check(str(game.atmosphere.get("level_id"))=="ruins","ArenaAtmosphere tracks ruins level_id")
		check(game.atmosphere.get("canvas_modulate")!=null,"ArenaAtmosphere creates CanvasModulate")
		check(game.atmosphere.get("particle_far")!=null and game.atmosphere.get("particle_near")!=null,"ArenaAtmosphere creates dual particle layers")
		check(game.atmosphere.get("post_rect")!=null,"ArenaAtmosphere creates post-process ColorRect")
	var effects: ArenaEffects=null
	for child in game.get_children():
		if child is ArenaEffects:effects=child;break
	check(effects!=null,"ArenaEffects mounted on game")
	if effects!=null:
		for key in ["slash","arcane_blast","lightning","frost","shield_break","hit","fire_brazier","slam","upgrade"]:
			check(effects.has_v016_fx(key),"pixelfx sheet loaded: "+key)
		check(effects.fx_meta.size()>=9,"pixelfx manifest parsed")
		var pxl:=effects.get_node_or_null("PixelFXLayer")
		var addl:=effects.get_node_or_null("AdditiveGlowLayer")
		check(pxl!=null and pxl.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"PixelFXLayer nearest filter active")
		check(addl!=null and addl.material!=null,"AdditiveGlowLayer material active")

	check(not game.navigation_path(game.hero.position,Vector2(def.altars[0])).is_empty(),"hero navigates to west altar")
	check(not game.has_method("toggle_altar_mode"),"manual altar mode switching removed")
	check(not game.navigation_path(game.hero.position,Vector2(def.camps[0])).is_empty(),"hero navigates to SW camp")
	check(not Rect2(14,808,388,78).has_point(Vector2(def.camps[0])),"SW camp is clear of bottom-left skill_dock HUD")
	var braziers: Array=def.get("braziers",[])
	check(braziers.size()==4 and not Rect2(14,808,388,78).has_point(Vector2(braziers[1])),"ruins braziers are clear of bottom-left skill_dock HUD")
	check(not game.navigation_path(game.hero.position,Vector2(def.camps[1])).is_empty(),"hero navigates to NE camp")

	# Zero mid-wave passive popup interruptions when leveling inside wave & wave 1 stays on routes 0..2
	game.begin_wave()
	var w1_has_r3:=false
	for pkt in game.spawn_queue:
		if int(pkt.route)==3:w1_has_r3=true
	check(not w1_has_r3,"wave 1 does not spawn on locked NE rift route 3")
	game.spawn_queue.clear()
	game.hero.add_xp(500);await frames()
	check(game.hero.level>=4,"hero leveled during combat")
	check(game.choice_queue==0 and not game.choice_open,"zero mid-wave passive popups on stage 3")

	# Locked sites (6 @ 180g, 11 @ 220g) & 13-site terrain traits (highground, choke, conduit)
	check(game.site_locked(10) and game.site_locked(15),"sites 6 and 11 start locked on ruins")
	check(game.unlock_price(10)==180 and game.unlock_price(15)==220,"locked_prices 180 and 220 enforced")
	game.gold=2500
	check(not game.build_tower(15,"archer"),"cannot build on locked site 11")
	check(game.unlock_site(10) and game.gold==2320,"unlocking site 6 spends 180 gold")
	check(not game.site_locked(10) and game.site_locked(15),"site 6 unlocked while site 11 stays locked")

	check(game.build_tower(8,"barracks"),"build choke barracks on site 4")
	var barracks: ArenaTower=game.site_tower(8)
	check(barracks!=null and barracks.site_trait()=="choke" and barracks.troops.size()==3,"choke barracks starts with 3 soldiers")
	check(absf(barracks.troops[0].max_health-118.0)<0.1,"choke trait grants +18% soldier health (118.0)")
	check(barracks.soldier_respawn_scale()==1.25,"choke trait grants 1.25x respawn scale (20% faster)")
	barracks.troops[0].dead=true;barracks.troops[0].respawn_clock=10.0
	barracks._physics_process(1.0)
	check(absf(barracks.troops[0].respawn_clock-9.75)<0.01,"choke barracks ticks down soldier respawn 25% faster")
	barracks.troops[0].dead=false;barracks.troops[0].respawn_clock=0.0

	check(game.build_tower(0,"archer"),"build highground archer on site 0")
	check(game.build_tower(1,"archer"),"build choke archer on site 1")
	var archer_hg:=game.site_tower(0)
	var archer_choke:=game.site_tower(1)
	check(archer_hg.site_trait()=="highground" and absf(archer_hg.attack_range()/archer_choke.attack_range()-1.18)<0.01,"highground trait grants +18% attack range")

	check(game.build_tower(5,"mage"),"build conduit mage on site 7")
	check(game.build_tower(3,"mage"),"build highground mage on site 3")
	var mage_conduit:=game.site_tower(5)
	var mage_hg:=game.site_tower(3)
	check(mage_conduit.site_trait()=="conduit" and absf(mage_hg.reload_time()/mage_conduit.reload_time()-1.14)<0.01,"conduit trait grants +14% attack speed")
	check(absf(mage_conduit.penetration()-0.12)<0.001,"conduit trait grants +0.12 penetration")

	# Milestone Rest Keystone choices after Waves 2, 4, 6
	game.cycle=3;game.start_rest(16);await frames()
	check(game.choice_open and game.choices.size()==3,"rest after wave 2 opens 3 keystone choices")
	var pick0:=game.choices[0]
	check(game.hud.modal.find_child("Keystone_"+pick0,true,false)!=null,"keystone modal renders button Keystone_"+pick0)
	check(game.choose_perk(pick0),"pick keystone #1 "+pick0)
	await frames()
	check(not game.choice_open and game.keystones.size()==1,"keystone #1 applied cleanly and unpaused")

	# Explicitly test Vanguard barracks +1 soldier and Fracture (avoid duplicating pick0)
	if "vanguard" not in game.keystones:
		game.choices=["vanguard","fracture","conduit"];game.choice_open=true;game.choice_queue=1;paused=true
		check(game.choose_perk("vanguard"),"pick vanguard keystone")
	check(barracks.troops.size()==4,"vanguard grants +1 soldier immediately")
	check(absf(barracks.troops[0].max_health-118.0*1.45)<0.2,"vanguard stacks multiplicatively with choke soldier health")
	if "fracture" not in game.keystones:
		game.choices=["fracture","conduit","orbit"];game.choice_open=true;game.choice_queue=1;paused=true
		check(game.choose_perk("fracture"),"pick fracture keystone")

	# Camp reward in keystone mode never interrupts with a 2nd-tier passive popup
	game.queue_camp_reward(0);await frames()
	check(game.camp_reward_open,"camp reward opens cleanly")
	check(game.choose_camp_reward(0,"hero"),"camp astral wish accepted")
	await frames()
	check(not game.choice_open and game.choice_queue==0,"camp reward awards instant power without queued popup")

	# Automatic support: no enemy means no wasted activation, active phase never charges.
	game.altars[0].charge=100.0;game.altars[0].active=0.0
	game._tick_stage3_systems(0.01)
	check(game.altars[0].charge==100.0 and game.altars[0].active==0.0,"full altar waits without target")
	var altar_target:=game.spawn_enemy("construct_hound",0,0.0);altar_target.position=def.altars[0]
	game._tick_stage3_systems(0.01)
	check(game.altars[0].active==12.0 and game.altars[0].charge==0.0,"enemy triggers automatic altar exactly once")
	check(is_equal_approx(game.altar_slow_at(Vector2(def.altars[0])),0.38),"stasis uses actual 38 percent slow")
	game._tick_stage3_systems(1.0)
	check(game.altars[0].charge==0.0,"active altar cannot recharge")
	game.remove_enemy(altar_target)
	# Wave 5 NE Rift Breach opens route 3 and activates atmosphere rift effect
	game.cycle=5;game.phase="rest";game.begin_wave();await frames()
	var w5_has_r3:=false
	for pkt in game.spawn_queue:
		if int(pkt.route)==3:w5_has_r3=true
	check(not w5_has_r3,"sealed passage cannot spawn enemies before physical breakthrough")
	if game.atmosphere!=null:
		check(not game.breach_open,"wave index alone cannot open the sealed passage")
	game.spawn_queue.clear()

	# Snapshot branches prevent both seal/unseal teleports, including pushed units.
	var fork:=Vector2(def.bridge_gate.fork)
	var offset:=game.routes[1].get_closest_offset(fork)
	var sw_enemy:=game.spawn_enemy("construct_hound",1,offset+80)
	var normal_curve:=game.enemy_road(sw_enemy)
	var old_position:=sw_enemy.position
	check(sw_enemy.bridge_branch=="short","existing unit commits short branch")
	check(game.trigger_bridge_gate(),"bridge seals")
	check(not game.trigger_bridge_gate(),"sealed bridge cannot consume cooldown twice")
	check(sw_enemy.position.distance_to(old_position)<0.01,"seal never teleports an existing unit")
	check(game.enemy_road(sw_enemy)==normal_curve,"existing short branch remains stable")
	var diverted:=game.spawn_enemy("construct_hound",1,offset+1)
	var detour:=game.enemy_road(diverted)
	check(diverted.bridge_branch=="detour" and detour.get_baked_length()>normal_curve.get_baked_length()*1.25,"new fork arrival commits longer route")
	diverted.position=detour.sample_baked(diverted.progress,true)
	var diverted_position:=diverted.position
	game.bridge_active_clock=0.01;game._tick_stage3_systems(0.05)
	check(not game.bridge_sealed,"seal expires")
	check(game.enemy_road(diverted)==detour and diverted.position.distance_to(diverted_position)<0.01,"unseal retains detour without teleport")
	var before_push:=diverted.progress;diverted.push_back(20)
	check(diverted.progress<before_push and diverted.position.distance_to(detour.sample_baked(diverted.progress,true))<0.01,"knockback follows selected branch")
	var later:=game.spawn_enemy("construct_hound",1,offset+1)
	check(game.enemy_road(later)==normal_curve and later.bridge_branch=="short","later arrival takes reopened short road")
	for unit in [sw_enemy,diverted,later]:game.remove_enemy(unit)
	# Enemies: Prism Ward (-12%), Fracture detonation, Bomber collapse telegraph, Colossus 3 phases
	var prism:=game.spawn_enemy("astral_prism",0,120.0)
	var warden:=game.spawn_enemy("rune_warden",0,130.0)
	check(game.prism_ward_reduction(warden.center())>0.1,"astral prism radiates ward reduction")
	warden.take_hit(50.0,0,"tower")
	check(warden.fracture>0.0,"tower hit engraves fracture mark")
	var delayed_before:=game.delayed.size()
	var bomber:=game.spawn_enemy("rift_bomber",1,120.0)
	bomber.take_hit(9999.0,0,"hero")
	check(game.delayed.size()==delayed_before+1,"rift_bomber queues death collapse telegraph")

	var boss:=game.spawn_enemy("colossus",1,240.0)
	boss.take_hit(boss.max_health*0.50,1,"hero")
	check(boss.boss_phase==1 and boss.barrier_shield>100.0,"colossus enters phase 2 rift barrier")
	boss.barrier_shield=0.0
	boss.take_hit(boss.max_health*0.55,1,"hero")
	check(boss.boss_phase==2,"colossus enters phase 3 starfall")

	# Resonance R strike
	game.resonance=100.0
	check(game.cast_resonance(boss.position),"resonance strike casts cleanly")
	check(game.resonance==0.0 and game.resonance_casts==1,"resonance spends meter and increments casts")

	# Verify Stages 1-2 classic perk behavior still triggers mid-wave Lv.2 choice
	var g2: ArenaGame=load("res://scenes/arena.tscn").instantiate()
	g2.campaign=ArenaCampaign.playtest()
	root.add_child(g2);await frames()
	g2.start_run("knight","forest");g2.hero.add_xp(100);await frames()
	check(not g2.keystone_mode and g2.choice_open,"stage 1 preserves normal mid-wave lv2 choice")
	g2.running=false;g2.audio.shutdown();g2.queue_free()

	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(120);game.queue_free();await frames()
	print("V015 STAGE3 CHECKS: %d, FAILURES: %d"%[checks,failures])
	quit(0 if failures==0 else 1)
