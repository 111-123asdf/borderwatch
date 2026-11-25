extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("EXPORT FAIL: "+message)
func _initialize() -> void:
	check(ProjectSettings.get_setting("application/config/version")=="0.32.0","pack version")
	for stage in ["saltport","lighthouse","ruins","sanctum"]:
		check(ResourceLoader.exists("res://assets/maps_v029/map_"+stage+".png"),"v029 map ships "+stage)
	for kind in ["murloc_hunter","tide_rider","water_sprite","storm_wyrm","tide_warrior","wind_captain","conch_mage","water_elder","tempest_elemental","bluegale","bloodshell_crab","leviathan"]:
		check(ResourceLoader.exists("res://assets/monsters_v029_coast/creature_"+kind+".png"),"v029 coast atlas ships "+kind)
		check(ResourceLoader.exists("res://assets/monsters_v029_coast/portrait_"+kind+".png"),"v029 coast portrait ships "+kind)
	for kind in ["void_eyeling","void_gazer","twilight_harasser","spectral_cutter","twilight_avenger","avenger_rider","venom_spitter","soul_reaver","twilight_golem","vile_eyenest","bloodsoil_behemoth","baj_nimen"]:
		check(ResourceLoader.exists("res://assets/monsters_v029_ruins/creature_"+kind+".png"),"v029 ruins atlas ships "+kind)
		check(ResourceLoader.exists("res://assets/monsters_v029_ruins/portrait_"+kind+".png"),"v029 ruins portrait ships "+kind)
	for file in ["arena_attack_timing", "arena_stage_gimmicks", "arena_grounding", "arena_rift_pcg", "arena_relic_engine"]:
		check(ResourceLoader.exists("res://scripts/arena/"+file+".gd"),"current presentation code ships "+file)
	check(ResourceLoader.exists("res://assets/rift_v032/tiles_wilds_floor.png"),"v032 modular floor tiles ship")
	for file in ["site_plinths", "ruins_mechanisms"]:
		check(ResourceLoader.exists("res://assets/v018/"+file+".png"),"current prop atlas ships "+file)
	check(ResourceLoader.exists("res://assets/v018/particles/smoke_07.png"),"world dust texture ships")
	for file in ["towers"]:
		check(ResourceLoader.exists("res://assets/v017/"+file+".png"),"v017 current artwork ships "+file)
	check(ResourceLoader.exists("res://assets/v021/towers.png"),"new tower tiers ship")
	for kind in ArenaDefinitions.DEFAULT_TOWERS:
		for tier in range(1,4):
			for part in ["base","part"]:
				check(ResourceLoader.exists("res://assets/v017/tower_"+kind+"_"+str(tier)+"_"+part+".png"),"tower mechanism ships "+kind+str(tier)+part)
	for actor_id in ["lord","druid","healer","werewolf","werewolf_beast","gunner","frost_wolf","ember_wolf"]:
		for view in ArenaActor.VIEWS:
			check(ResourceLoader.exists(ArenaHeroArt.pose_atlas(actor_id,view)),"v022 pixel pose atlas ships "+actor_id+"_"+view)
	for identity in ArenaDefinitions.HERO_IDS:
		check(ResourceLoader.exists(ArenaHeroArt.POSE_ROOT+"portrait_"+identity+".png"),"v022 portrait ships "+identity)
		check(ResourceLoader.exists(ArenaHeroArt.POSE_ROOT+"portrait_"+identity+"_small.png"),"v022 small portrait ships "+identity)
		check(ArenaHeroArt.portrait(identity)!=null,"v022 portrait loads "+identity)
	for kind in ["fox","brute","spearman","spore"]:
		check(ResourceLoader.exists("res://assets/hero_poses/creature_"+kind+".png"),"woodland creature atlas ships "+kind)
	for kind in ["pigsoldier","rottooth_hyena","tusk_fighter","dreadeye_viper","turtle_shaman","bear_vanguard","throat_cutter","scout_vulture","skunk_bombardier","bear_woodsman","darksteel_guard","two_headed_troll"]:
		check(ResourceLoader.exists("res://assets/monsters_v023/creature_"+kind+".png"),"v023 beast atlas ships "+kind)
		check(ResourceLoader.exists("res://assets/monsters_v023/portrait_"+kind+".png"),"v023 beast portrait ships "+kind)
	for material in ["wind","leaves"]:
		check(ArenaHeroSkillFX.texture(material)!=null,"hand-painted hero skill material ships "+material)
	for cue in ArenaAudio.HERO_CUES:check(ResourceLoader.exists("res://assets/v012/audio/"+cue+".ogg"),"CC0 hero sound ships "+cue)
	check(ResourceLoader.exists("res://assets/v011/physical_fx.png"),"painted physical effects ship")
	check(not FileAccess.file_exists("res://assets/v011/knight_frames.json"),"retired hero frame metadata excluded")
	for kind in ArenaAudio.FILES:
		for file in ArenaAudio.FILES[kind]:check(ResourceLoader.exists("res://assets/v011/audio/"+str(file)+".ogg"),"selected CC0 sound ships "+str(file))
	check(not ResourceLoader.exists("res://assets/v011/knight_design.png"),"unused concept sheet excluded")
	for file in ["title","world_atlas","hall_bg","ui_icons","ui_controls","ui_skin","perk_icons","widget_dark","widget_paper","widget_amber","widget_blue","widget_green"]:check(ResourceLoader.exists("res://assets/v013/"+file+".png"),"current cartoon front-end asset ships "+file)
	check(FileAccess.file_exists("res://assets/v013/regions.json"),"inspected UI regions ship")
	check(not ResourceLoader.exists("res://assets/v010/headquarters.png"),"unused old courtyard excluded from executable")
	for file in ["weapon_rig.gd","actor_visual.gd","arena/arena_weapon_catalog.gd","arena/arena_drop.gd","arena/arena_minimap.gd","arena/arena_camp.gd","arena/arena_nest.gd"]:
		check(not ResourceLoader.exists("res://scripts/"+file),"retired script absent")
	for path in ["weapons","tiny_swords","ui","v020"]:
		check(not DirAccess.dir_exists_absolute("res://assets/"+path),"retired resources absent")
	for item in ["v09/portrait_mage.png","v09/mage_side.png","v011/knight_side.png","v012/ranger_side.png"]:
		check(not ResourceLoader.exists("res://assets/"+item),"retired hero artwork excluded "+item)
	check(ResourceLoader.exists("res://assets/v09/site_pad.png"),"current foundation ships")
	check(not ResourceLoader.exists("res://assets/v06/knight_side.png"),"old cartoon hero atlas excluded")
	check(ResourceLoader.exists("res://scripts/arena/arena_motion.gd"),"current action planning shipped")
	check(not FileAccess.file_exists("res://docs/ART_GENERATION.json"),"development materials excluded")
	print("V06 EXPORT AUDIT CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
