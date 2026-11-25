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
	check(not def.has("perk_mode") and not def.has("altars"),"stage 5 removes legacy keystone perk_mode and altars")
	check(str(def.get("boss_kind",""))=="bloodsoil_boss","stage 5 boss is bloodsoil_boss")
	check(Vector2(def.core).distance_to(Vector2(1520,470))<1.0,"stage 5 features east edge exit (1520,470)")
	check(Vector2(def.hero_spawn).distance_to(Vector2(1380,470))<1.0,"stage 5 hero_spawn matches shared contract")
	check(def.routes.size()==3,"stage 5 defines 3 main routes")
	check(Vector2(def.routes[0][0]).x<0 and Vector2(def.routes[1][0]).x<0,"routes 0 and 1 enter from NW/SW")
	check(Vector2(def.routes[2][0]).y<0,"route 2 enters from NE cliff")
	var bg: Dictionary=def.get("bridge_gate",{})
	check(not bg.is_empty() and Vector2(bg.get("point",Vector2.ZERO)).distance_to(Vector2(495,675))<1.0,"bridge_gate configured at (495,675)")
	var landmarks: int = def.get("site_traits",[]).count("highground") + def.get("site_traits",[]).count("conduit") + def.get("site_traits",[]).count("choke")
	check(def.sites.size()==12 and def.get("site_traits",[]).size()==12 and def.get("site_roles",[]).size()==12 and landmarks<=2,"stage 5 defines 12 sites with <=2 landmarks and roles")
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
		check(ResourceLoader.exists(path),"stage 5 art/scene exists: "+path)
	check(FileAccess.file_exists("res://assets/v016/fx_manifest.json"),"pixelfx fx_manifest.json exists")
	for kind in ["void_eyeling","twilight_avenger","venom_spitter","soul_reaver","twilight_golem","bloodsoil_behemoth"]:
		check(ArenaCreature.sheet_path(kind)=="res://assets/monsters_v029_ruins/creature_"+kind+".png","v029 pixel sheet resolved for "+kind)
		var creature:=ArenaCreature.new();root.add_child(creature);creature.configure(kind)
		check(creature.is_pixel_v023 and creature.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"pixel nearest sampling for "+kind)
		for anim in ["walk","attack","down"]:
			check(creature.sprite_frames.has_animation(anim) and creature.sprite_frames.get_frame_count(anim)==6,"stage 5 enemy anim "+kind+" "+anim)
		creature.queue_free()

	game=load("res://scenes/arena.tscn").instantiate()
	game.campaign=ArenaCampaign.playtest()
	root.add_child(game);current_scene=game;await frames()
	check(game.campaign.can_deploy("ruins"),"playtest campaign allows ruins deployment")

	game.start_run("knight","ruins");await frames()
	check(game.total_waves()==5 and game.rift_domain.theme_key=="void","ruins uses 5-round void rift")
	check(game.routes.size()==3,"game instantiates 3 routes on ruins")

	check(game.tilemap_scene==null and game.ground.visible,"pixel terrain active without old TileMap overlay")
	check(game.ground.texture.get_width()==1600 and game.ground.texture.get_height()==900,"registered 1600x900 pixel terrain")
	check(str(game.ground.texture.resource_path)==str(def.map_art),"runtime terrain matches level configuration")
	for kind in ArenaDefinitions.DEFAULT_TOWERS:
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

	check(not game.navigation_path(game.hero.position,game.bridge_gate_point()).is_empty(),"hero navigates to west drawbridge zone")
	check(not game.has_method("toggle_altar_mode"),"manual altar mode switching removed")
	var braziers: Array=def.get("braziers",[])
	check(braziers.size()==4 and not Rect2(14,808,388,78).has_point(Vector2(braziers[1])),"ruins braziers are clear of bottom-left skill_dock HUD")

	# Zero mid-wave passive popup interruptions & wave 1 stays on routes 0..1
	game.begin_wave()
	var w1_has_r2:=false
	for pkt in game.spawn_queue:
		if int(pkt.route)==2:w1_has_r2=true
	check(not w1_has_r2,"wave 1 does not spawn on locked NE rift route 2")
	game.spawn_queue.clear()
	check(game.passive_offers.is_empty(),"zero mid-wave popups on stage 5")

	# Locked sites (9 @ 180g, 10 @ 220g) & 12-site terrain traits (highground, choke, conduit)
	check(game.site_locked(9) and game.site_locked(10),"sites 9 and 10 start locked on ruins")
	check(game.unlock_price(9)==180 and game.unlock_price(10)==220,"locked_prices 180 and 220 enforced")
	game.gold=2500
	check(not game.build_tower(10,"archer"),"cannot build on locked site 10")
	check(game.unlock_site(9) and game.gold==2320,"unlocking site 9 spends 180 gold")
	check(not game.site_locked(9) and game.site_locked(10),"site 9 unlocked while site 10 stays locked")

	game.level_definition.site_traits[5] = "choke"
	check(game.build_tower(5,"barracks"),"build choke barracks on site 5")
	var barracks: ArenaTower=game.site_tower(5)
	barracks.finish_project()
	var base_l1_hp:=ArenaTowerTrial.stat("barracks","health",1)
	check(barracks!=null and barracks.site_trait()=="choke" and barracks.troops.size()==3,"choke barracks starts with 3 soldiers")
	check(absf(barracks.troops[0].max_health-base_l1_hp*1.18)<0.2,"choke trait grants +18% soldier health")
	check(barracks.soldier_respawn_scale()==1.25,"choke trait grants 1.25x respawn scale (20% faster)")
	barracks.troops[0].dead=true;barracks.troops[0].respawn_clock=10.0
	barracks._physics_process(1.0)
	check(absf(barracks.troops[0].respawn_clock-9.75)<0.01,"choke barracks ticks down soldier respawn 25% faster")
	barracks.troops[0].dead=false;barracks.troops[0].respawn_clock=0.0

	check(game.build_tower(0,"archer"),"build highground archer on site 0")
	check(game.build_tower(1,"archer"),"build baseline archer on site 1")
	var archer_hg:=game.site_tower(0)
	var archer_plain:=game.site_tower(1)
	archer_hg.finish_project();archer_plain.finish_project()
	check(archer_hg.site_trait()=="highground" and absf(archer_hg.attack_range()/archer_plain.attack_range()-1.18)<0.01,"highground trait grants +18% attack range")

	check(game.build_tower(2,"mage"),"build conduit mage on site 2")
	check(game.build_tower(3,"mage"),"build highground mage on site 3")
	var mage_conduit:=game.site_tower(2)
	var mage_hg:=game.site_tower(3)
	mage_conduit.finish_project();mage_hg.finish_project()
	check(mage_conduit.site_trait()=="conduit" and absf(mage_hg.reload_time()/mage_conduit.reload_time()-1.14)<0.01,"conduit trait grants +14% attack speed")
	check(absf(mage_conduit.penetration()-0.12)<0.001,"conduit trait grants +0.12 penetration")

	# Round 2 rest stays seamless without popup interruptions
	game.cycle=2;game.start_rest(16);await frames()
	check(not paused and game.passive_offers.is_empty(),"rest opens cleanly without popup interruptions")
	# Round 5 sealed passage before physical breach
	game.cycle=5;game.phase="rest";game.begin_wave();await frames()
	var w5_has_r2:=false
	for pkt in game.spawn_queue:
		if int(pkt.route)==2:w5_has_r2=true
	check(not w5_has_r2,"sealed passage cannot spawn enemies before physical breakthrough")
	if game.atmosphere!=null:
		check(not game.breach_open,"wave index alone cannot open the sealed passage")
	game.spawn_queue.clear()

	# Snapshot branches prevent both seal/unseal teleports, including pushed units.
	var fork:=Vector2(def.bridge_gate.fork)
	var offset:=game.routes[1].get_closest_offset(fork)
	var sw_enemy:=game.spawn_enemy("void_eyeling",1,offset+80)
	var normal_curve:=game.enemy_road(sw_enemy)
	var old_position:=sw_enemy.position
	check(sw_enemy.bridge_branch=="short","existing unit commits short branch")
	check(game.trigger_bridge_gate(),"bridge seals")
	check(not game.trigger_bridge_gate(),"sealed bridge cannot consume cooldown twice")
	check(sw_enemy.position.distance_to(old_position)<0.01,"seal never teleports an existing unit")
	check(game.enemy_road(sw_enemy)==normal_curve,"existing short branch remains stable")
	var diverted:=game.spawn_enemy("void_eyeling",1,offset+1)
	var detour:=game.enemy_road(diverted)
	check(diverted.bridge_branch=="detour" and detour.get_baked_length()>normal_curve.get_baked_length()*1.15,"new fork arrival commits longer route")
	diverted.position=detour.sample_baked(diverted.progress,true)
	var diverted_position:=diverted.position
	game.bridge_active_clock=0.01;game._tick_stage3_systems(0.05)
	check(not game.bridge_sealed,"seal expires")
	check(game.enemy_road(diverted)==detour and diverted.position.distance_to(diverted_position)<0.01,"unseal retains detour without teleport")
	var before_push:=diverted.progress;diverted.push_back(20)
	check(diverted.progress<before_push and diverted.position.distance_to(detour.sample_baked(diverted.progress,true))<0.01,"knockback follows selected branch")
	var later:=game.spawn_enemy("void_eyeling",1,offset+1)
	check(game.enemy_road(later)==normal_curve and later.bridge_branch=="short","later arrival takes reopened short road")
	for unit in [sw_enemy,diverted,later]:game.remove_enemy(unit)
	# Enemies: twilight_avenger death curse, bloodsoil_boss split, baj_nimen 3 phases
	var delayed_before:=game.delayed.size()
	var avenger:=game.spawn_enemy("twilight_avenger",1,120.0)
	avenger.take_hit(9999.0,0,"hero")
	check(game.delayed.size()==delayed_before+1,"twilight_avenger queues death curse telegraph")

	var mini:=game.spawn_enemy("bloodsoil_boss",0,240.0)
	var count_before:=game.enemies.size()
	mini.take_hit(mini.max_health*0.85,1,"hero")
	check(game.enemies.size()>=count_before+3,"bloodsoil_boss summons reinforcement pack at half HP")

	var boss:=game.spawn_enemy("baj_nimen",1,240.0)
	boss.take_hit(boss.max_health*0.50,1,"hero")
	check(boss.boss_phase==1 and boss.barrier_shield>100.0,"baj_nimen enters phase 2 starfall barrier")
	boss.barrier_shield=0.0
	boss.take_hit(boss.max_health*0.55,1,"hero")
	check(boss.boss_phase==2,"baj_nimen enters phase 3 rift overload")

	game.running=false;game.audio.shutdown();await frames();OS.delay_msec(120);game.queue_free();await frames()
	print("V015 STAGE3 CHECKS: %d, FAILURES: %d"%[checks,failures])
	quit(0 if failures==0 else 1)
