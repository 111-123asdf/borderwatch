extends SceneTree
# Isolated persistence and explicit combat fixtures; never writes normal user saves.
var checks:=0
var failures:=0
var game: ArenaGame
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("CAMPAIGN FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var path: String="user://campaign-fixture-"+str(Time.get_ticks_usec())+".cfg"
	var state:=ArenaCampaign.new(path,true)
	check(state.gems()==0 and state.level("knight")==1,"new profiles start empty at level one")
	check(not state.upgrade("knight"),"insufficient currency does not upgrade")
	check(not state.skill_unlocked("knight",0) and not state.skill_unlocked("knight",1),"level one has no actives")
	var first:=state.settle("a","forest",true,8)
	check(bool(first.ok) and int(first.amount)==8 and state.gems()==8,"first clear awards eight shared gems")
	check(state.upgrade("knight") and state.level("knight")==2 and state.gems()==6,"level two costs two")
	check(state.skill_unlocked("knight",0) and not state.skill_unlocked("knight",1),"level two unlocks Q only")
	check(state.upgrade("knight") and state.gems()==3 and state.level("knight")==3,"level three costs three")
	check(not state.upgrade("knight") and state.gems()==3,"failed upgrade preserves wallet")
	check(int(state.settle("b","forest",true,8).amount)==6,"replay victory awards six")
	check(state.upgrade("knight") and state.gems()==4 and state.level("knight")==4,"level four costs five")
	check(state.skill_unlocked("knight",1),"level four unlocks ultimate")
	state.settle("c","forest",true,8)
	check(state.upgrade("knight") and state.gems()==2 and state.level("knight")==5,"level five costs eight")
	check(not state.upgrade("knight") and state.gems()==2,"max level cannot be charged")
	check(is_equal_approx(float(state.bonuses("knight").health),0.08) and is_equal_approx(float(state.bonuses("knight").attack),0.06),"permanent stats remain restrained")
	check(state.level("ranger")==1 and state.level("mage")==1,"other heroes keep independent levels")
	check(int(state.settle("a","forest",true,8).amount)==0 and state.gems()==2,"old run remains deduplicated after other runs")
	check(int(state.settle("d","creek",true,8).amount)==8,"each stage has its own first clear bonus")
	for waves in range(8):
		var expected:=0 if waves<4 else (2 if waves<6 else 3)
		check(int(state.settle("failure-"+str(waves),"forest",false,waves).amount)==expected,"failure reward threshold "+str(waves))
	var reloaded:=ArenaCampaign.new(path,true)
	check(not reloaded.locked and reloaded.data==state.data,"wallet and levels survive reload")
	var fail_save:=ArenaCampaign.new("user://missing-v09-folder/nested/profile.cfg",true)
	fail_save.data.gems=20;var unchanged:=fail_save.data.duplicate(true)
	check(not fail_save.upgrade("knight") and fail_save.data==unchanged,"save failure does not consume gems or level")
	check(not bool(fail_save.settle("bad-save","forest",true,8).ok) and fail_save.data==unchanged,"save failure does not grant or record rewards")
	var corrupt:=ConfigFile.new();corrupt.set_value("campaign","version",3);corrupt.set_value("campaign","data",{"gems":-1});corrupt.save(path+".bad")
	var bytes:=FileAccess.get_file_as_bytes(path+".bad");var bad:=ArenaCampaign.new(path+".bad",true)
	check(bad.locked and FileAccess.get_file_as_bytes(path+".bad")==bytes,"corrupt profile is preserved and locked")
	check(state.settings(0.5,true),"settings save without changing progression")
	check(ArenaCampaign.new(path,true).data.reduced_motion and is_equal_approx(float(state.data.volume),0.5),"settings survive reload")
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);root.add_child(game);await process_frame
	game.start_run("knight","forest")
	var h:=game.hero;var hp:=h.max_health;var damage:=h.attack_damage()
	check(not h.cast(0,h.position) and not h.cast(1,h.position) and h.cooldowns==[0.0,0.0],"locked skill attempts never spend cooldown")
	check(not game._card_available("oath") and not game._card_available("focus"),"locked skill cards stay out of level-one pool")
	for identity in ArenaDefinitions.HERO_IDS:
		for rank in range(1,6):
			game.campaign.data.levels[identity]=rank;h.configure(identity)
			check(game._card_available("focus")== (rank>=2),"generic skill cards follow unlocks "+identity+str(rank))
			var role_card: String={"knight":"oath","ranger":"shadowstep","mage":"starcore"}[identity]
			check(game._card_available(role_card)==(rank>=(2 if identity=="ranger" else 4)),"class skill card gate "+identity+str(rank))
	h.configure("knight")
	for rank in range(1,6):
		game.campaign.data.levels.knight=rank;h.configure("knight")
		var before:=h.max_health;h.recompute();h.recompute()
		check(is_equal_approx(h.max_health,before),"recompute never repeats permanent health "+str(rank))
		check(h.skill_unlocked(0)==(rank>=2) and h.skill_unlocked(1)==(rank>=4),"runtime skill gates "+str(rank))
	check(is_equal_approx(h.max_health,hp*1.08) and is_equal_approx(h.attack_damage(),damage*1.06),"level-five runtime bonuses apply once")
	game.build_tower(0,"barracks");var soldier: ArenaSoldier=game.soldiers[0]
	soldier.health=50;soldier.combat_delay=5;soldier._physics_process(4)
	check(is_equal_approx(soldier.health,50),"soldier waits through combat delay")
	soldier._physics_process(1)
	check(is_equal_approx(soldier.health,60),"soldier heals ten percent per second after delay")
	soldier.take_hit(1,0);var health:=soldier.health;soldier._physics_process(1)
	check(is_equal_approx(soldier.health,health),"taking damage interrupts recovery")
	soldier.combat_delay=0;soldier._physics_process(100)
	check(soldier.health==soldier.max_health,"recovery never exceeds max health")
	soldier.take_hit(9999,0);soldier._physics_process(5)
	check(soldier.dead and soldier.health==0,"dead soldier cannot regenerate")
	soldier._physics_process(5)
	check(not soldier.dead and soldier.health==soldier.max_health,"replacement still takes ten seconds")
	game.running=false;game.audio.shutdown();paused=false;await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	print("V09 CAMPAIGN CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
