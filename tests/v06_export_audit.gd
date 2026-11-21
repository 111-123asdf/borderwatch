extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("EXPORT FAIL: "+message)
func _initialize() -> void:
	check(ProjectSettings.get_setting("application/config/version")=="0.19.0","pack version")
	for file in ["arena_attack_timing", "arena_construct_rig", "arena_grounding"]:
		check(ResourceLoader.exists("res://scripts/arena/"+file+".gd"),"current presentation code ships "+file)
	for file in ["site_plinths", "ruins_mechanisms"]:
		check(ResourceLoader.exists("res://assets/v018/"+file+".png"),"current prop atlas ships "+file)
	check(ResourceLoader.exists("res://assets/v018/particles/smoke_07.png"),"world dust texture ships")
	for file in ["towers","rigs","layout","terrain_blocks","art_layers"]:
		check(FileAccess.file_exists("res://assets/v017/"+file+".json"),"v017 runtime metadata ships "+file)
	for file in ["map_ruins","map_ruins_open","towers","core_ruins"]:
		check(ResourceLoader.exists("res://assets/v017/"+file+".png"),"v017 current artwork ships "+file)
	check(ResourceLoader.exists("res://assets/v021/towers.png"),"new tower tiers ship")
	for kind in ArenaDefinitions.DEFAULT_TOWERS:
		for tier in range(1,4):
			for part in ["base","part"]:
				check(ResourceLoader.exists("res://assets/v017/tower_"+kind+"_"+str(tier)+"_"+part+".png"),"tower mechanism ships "+kind+str(tier)+part)
	for identity in ["ranger","mage"]:
		for view in ["side","down","up"]:check(ResourceLoader.exists(ArenaHeroArt.atlas(identity,view)),"v012 hero atlas ships "+identity+view)
		check(FileAccess.file_exists(ArenaHeroArt.folder(identity)+identity+"_frames.json"),"v012 anchors ship "+identity)
		check(ArenaHeroArt.portrait(identity)!=null,"v012 portrait ships "+identity)
		check(ResourceLoader.exists(ArenaHeroArt.folder(identity)+identity+"_fx.png"),"v012 painted VFX ships "+identity)
	for cue in ArenaAudio.HERO_CUES:check(ResourceLoader.exists("res://assets/v012/audio/"+cue+".ogg"),"CC0 hero sound ships "+cue)
	for view in ["side","down","up"]:check(ResourceLoader.exists("res://assets/v011/knight_"+view+".png"),"selected cartoon knight ships "+view)
	check(ResourceLoader.exists("res://assets/v011/portrait_knight.png"),"transparent young portrait ships")
	check(ResourceLoader.exists("res://assets/v011/physical_fx.png"),"painted physical effects ship")
	check(FileAccess.file_exists("res://assets/v011/knight_frames.json"),"authored atlas regions ship")
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
	check(ResourceLoader.exists("res://assets/v09/portrait_mage.png"),"new portraits shipped")
	check(ResourceLoader.exists("res://assets/v09/mage_side.png") and ResourceLoader.exists("res://assets/v09/site_pad.png"),"current animation and foundation shipped")
	check(not ResourceLoader.exists("res://assets/v06/knight_side.png"),"old cartoon hero atlas excluded")
	check(ResourceLoader.exists("res://scripts/arena/arena_motion.gd"),"current action planning shipped")
	check(not FileAccess.file_exists("res://docs/ART_GENERATION.json"),"development materials excluded")
	print("V06 EXPORT AUDIT CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
