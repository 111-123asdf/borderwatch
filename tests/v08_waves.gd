extends SceneTree
# Authored wave data, elite count, resistance coverage, leak tiers and raid budget.
var checks:=0
var failures:=0
var game: ArenaGame
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V08 WAVE FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	check_elite_data()
	check_profiles()
	check_leaks()
	await check_raid()
	game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	paused=false
	print("V08 WAVE CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
func check_elite_data() -> void:
	for stage in ["forest","creek"]:
		for number in range(1,9):
			var expected:=0
			for group in ArenaLevelCatalog.wave(stage,number).units:
				var amount:=int(group[1]);var elite_count:=int(group[2]) if group.size()>2 else 0
				check(elite_count<=amount,"%s W%d elite count fits the group"%[stage,number])
				expected+=elite_count
			var profile:=ArenaLevelCatalog.wave_profile(stage,number)
			check(profile.elites==expected,"%s W%d profile matches authored elites"%[stage,number])
			check(expected>=0 and expected<=4,"%s W%d keeps elites between zero and four"%[stage,number])
	check(",".join(ArenaLevelCatalog.elite_kinds("forest",4))=="brute","forest W4 authors a brute elite")
	check(",".join(ArenaLevelCatalog.elite_kinds("creek",6))=="brute,wisp","creek W6 authors brute and wisp elites")
	check(",".join(ArenaLevelCatalog.elite_kinds("creek",8))=="brute,brute,wisp,spearman","creek W8 authors four elites")
func check_profiles() -> void:
	check(ArenaLevelCatalog.wave_profile("forest",6).heavy>=0.4,"forest W6 is a heavy wave")
	check(ArenaLevelCatalog.wave_profile("creek",3).heavy>=0.4,"creek W3 is a heavy wave")
	check(ArenaLevelCatalog.wave_profile("forest",7).high_res>=0.3,"forest W7 is the high-resist wave")
	check(ArenaLevelCatalog.wave_profile("creek",2).high_res>=0.3,"creek W2 is a high-resist wave")
	var forest7:=ArenaLevelCatalog.wave_profile("forest",7);var forest8:=ArenaLevelCatalog.wave_profile("forest",8)
	var creek7:=ArenaLevelCatalog.wave_profile("creek",7);var creek8:=ArenaLevelCatalog.wave_profile("creek",8)
	check(forest8.non_boss>=1.2*forest7.non_boss,"forest W8 trash outgrows W7")
	check(creek8.non_boss>=1.2*creek7.non_boss,"creek W8 trash outgrows W7")
	check(forest8.hp>forest8.non_boss and creek8.hp==creek8.non_boss,"only forest carries a boss")
func check_leaks() -> void:
	check(ArenaDefinitions.leak_damage("fox")==14 and ArenaDefinitions.leak_damage("wisp")==14,"light enemies leak for fourteen")
	check(ArenaDefinitions.leak_damage("spearman")==18 and ArenaDefinitions.leak_damage("spore")==18,"mid enemies leak for eighteen")
	check(ArenaDefinitions.leak_damage("brute")==36,"brute keeps the heavy leak")
	check(ArenaDefinitions.leak_damage("fox",true)==24 and ArenaDefinitions.leak_damage("spore",true)==24,"elites leak for at least twenty-four")
	check(ArenaDefinitions.leak_damage("brute",true)==36,"elite brute keeps the higher leak")
func check_raid() -> void:
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);await process_frame
	game.progression=ArenaProgression.new("user://fixture-waves.cfg",false)
	game.start_run("knight","forest")
	game.cycle=2;game.phase="rest";game.phase_clock=10;game.begin_wave()
	var guards:=game.enemies.size()
	game.cycle=5;game.phase="rest";game.phase_clock=10;game.begin_wave()
	var spawned:=game.enemies.size()-guards
	check(spawned==6,"each uncleared camp sends three foxes")
	var raid_hp:=3.0*float(ArenaDefinitions.enemy("fox").health)*(1.0+0.11*4.0)
	check(raid_hp<=0.15*ArenaLevelCatalog.wave_profile("forest",5).hp,"raid stays under fifteen percent of wave five")
