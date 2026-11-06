extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("SAVE FAIL: "+message)
func _initialize() -> void:
	var folder:="user://v06-save-test-"+str(Time.get_ticks_usec());DirAccess.make_dir_recursive_absolute(folder)
	var old:=folder+"/legacy.cfg";var next:=folder+"/current.cfg"
	var cfg:=ConfigFile.new();cfg.set_value("meta","version",1)
	for hero in ArenaProgression.HEROES:
		cfg.set_value(hero,"xp",480);cfg.set_value(hero,"health",2);cfg.set_value(hero,"shield",3)
	cfg.save(old)
	var original:=FileAccess.get_file_as_bytes(old)
	var current:=ArenaProgression.new(next,true,old)
	check(current.migrated and not current.locked,"valid legacy migrates to v2")
	check(current.entry("knight")=={"xp":480,"health":2,"cooldown":0},"XP and health retained, old shield spent points refunded")
	check(current.points("knight")==4,"refund available as unspent points")
	check(original==FileAccess.get_file_as_bytes(old),"legacy save untouched")
	check(current.upgrade("knight","cooldown"),"new cooldown training can spend refunded point")
	check(is_equal_approx(current.bonuses("knight").cooldown,0.02),"cooldown training is two percent")
	var reloaded:=ArenaProgression.new(next,true,old)
	check(reloaded.entry("knight")==current.entry("knight"),"atomic overwrite can reload")
	check(not current.upgrade("knight","shield"),"retired shield training rejected")
	var bad:=folder+"/bad.cfg";var broken:=ConfigFile.new();broken.set_value("meta","version",2);broken.save(bad)
	var bytes:=FileAccess.get_file_as_bytes(bad);var locked:=ArenaProgression.new(bad,true,old)
	check(locked.locked and not locked.upgrade("mage","health"),"invalid save locks writes")
	check(locked.grant_experience("mage",80)==-1 and bytes==FileAccess.get_file_as_bytes(bad),"invalid save not overwritten")
	var cap:=ArenaProgression.new("",false);cap.entries.knight={"xp":800,"health":5,"cooldown":5}
	check(not cap.upgrade("knight","health") and cap.grant_experience("knight",120)==0,"max ranks and XP enforced")
	print("V06 SAVE CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
