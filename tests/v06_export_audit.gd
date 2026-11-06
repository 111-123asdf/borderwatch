extends SceneTree
var failures:=0
var checks:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("EXPORT FAIL: "+message)
func _initialize() -> void:
	check(ProjectSettings.get_setting("application/config/version")=="0.6.0","pack version")
	for file in ["weapon_rig.gd","actor_visual.gd","arena/arena_weapon_catalog.gd","arena/arena_drop.gd","arena/arena_minimap.gd"]:
		check(not ResourceLoader.exists("res://scripts/"+file),"retired script absent")
	for path in ["weapons","tiny_swords","ui"]:
		check(not DirAccess.dir_exists_absolute("res://assets/"+path),"retired resources absent")
	check(ResourceLoader.exists("res://assets/v06/portrait_mage.png"),"new portraits shipped")
	check(ResourceLoader.exists("res://scripts/arena/arena_motion.gd"),"current action planning shipped")
	check(not FileAccess.file_exists("res://docs/ART_GENERATION.json"),"development materials excluded")
	print("V06 EXPORT AUDIT CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
