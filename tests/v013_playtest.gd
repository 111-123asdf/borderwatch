extends SceneTree
# Test-owned APPDATA only. Existing normal-save bytes must survive every preview action.
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V013 PROFILE FAIL: "+message)
func _initialize() -> void:
	var normal:=ArenaCampaign.new();var data:=normal.data.duplicate(true);data.gems=17;data.levels.mage=2
	check(normal._commit(data),"seed isolated normal profile")
	var original:=FileAccess.get_file_as_bytes(ArenaCampaign.SAVE_PATH)
	var preview:=ArenaCampaign.playtest()
	check(preview.path==ArenaCampaign.PLAYTEST_PATH and preview.path!=normal.path,"separate persistent preview path")
	check(preview.gems()==9999,"preview has enough diamonds immediately")
	for identity in ArenaDefinitions.HERO_IDS:
		check(preview.level(identity)==1,"preview hero starts unupgraded "+identity)
		for rank in range(2,6):check(preview.upgrade(identity) and preview.level(identity)==rank,"freely upgrade "+identity+str(rank))
	check(preview.gems()==9999-54,"all actual upgrade prices are preserved")
	check(FileAccess.get_file_as_bytes(ArenaCampaign.SAVE_PATH)==original,"preview never overwrites normal save")
	preview=ArenaCampaign.playtest();check(preview.gems()==9999 and preview.level("mage")==5,"reload replenishes currency and retains chosen upgrades")
	check(FileAccess.get_file_as_bytes(ArenaCampaign.SAVE_PATH)==original,"preview reload never reads/writes normal profile")
	print("V013 PROFILE CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
