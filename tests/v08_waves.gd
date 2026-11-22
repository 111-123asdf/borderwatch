extends SceneTree
# Authored wave data, elite count, resistance coverage, leak tiers and wave dispatch.
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
	await check_wave_dispatch()
	game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	paused=false
	print("V08 WAVE CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
func check_elite_data() -> void:
	for stage in ["forest","creek"]:
		var total := ArenaLevelCatalog.total_waves(stage)
		for number in range(1,total+1):
			var expected:=0
			for group in ArenaLevelCatalog.wave(stage,number).units:
				var amount:=int(group[1]);var elite_count:=int(group[2]) if group.size()>2 else 0
				check(elite_count<=amount,"%s W%d elite count fits the group"%[stage,number])
				expected+=elite_count
			var profile:=ArenaLevelCatalog.wave_profile(stage,number)
			check(profile.elites==expected,"%s W%d profile matches authored elites"%[stage,number])
			check(expected>=0 and expected<=5,"%s W%d keeps elites between zero and five"%[stage,number])
	check(",".join(ArenaLevelCatalog.elite_kinds("forest",4))=="tusk_fighter","forest W4 authors a tusk_fighter elite")
	check(",".join(ArenaLevelCatalog.elite_kinds("creek",6))=="skunk_bombardier","creek W6 authors a skunk_bombardier elite")
	check(",".join(ArenaLevelCatalog.elite_kinds("creek",9))=="rottooth_hyena,throat_cutter,scout_vulture,skunk_bombardier","creek W9 authors four elites")
func check_profiles() -> void:
	check(ArenaLevelCatalog.wave_profile("forest",6).heavy>=0.4,"forest W6 is a heavy wave")
	check(ArenaLevelCatalog.wave_profile("creek",8).heavy>=0.4,"creek W8 is a heavy wave")
	check(ArenaLevelCatalog.wave_profile("forest",6).high_res>=0.15,"forest W6 introduces shaman resist pressure")
	check(ArenaLevelCatalog.wave_profile("creek",2).has_flying,"creek W2 introduces flying vultures")
	var forest7:=ArenaLevelCatalog.wave_profile("forest",7);var forest8:=ArenaLevelCatalog.wave_profile("forest",8)
	var creek8:=ArenaLevelCatalog.wave_profile("creek",8);var creek9:=ArenaLevelCatalog.wave_profile("creek",9);var creek10:=ArenaLevelCatalog.wave_profile("creek",10)
	check(forest8.non_boss>=1.15*forest7.non_boss,"forest W8 trash outgrows W7")
	check(creek9.non_boss>=creek8.non_boss,"creek W9 big horde scales up")
	check(not forest8.has_boss and creek10.has_boss and ArenaLevelCatalog.wave_profile("creek",6).has_mini_boss,"stage 1 has no boss; stage 2 has W6 mini-boss and W10 big boss")
func check_leaks() -> void:
	check(ArenaDefinitions.leak_damage("fox")==14 and ArenaDefinitions.leak_damage("wisp")==14,"legacy light enemies keep fourteen")
	check(ArenaDefinitions.leak_damage("pigsoldier")==12 and ArenaDefinitions.leak_damage("dreadeye_viper")==18,"beast light/ranged leak tiers")
	check(ArenaDefinitions.leak_damage("bear_vanguard")==36 and ArenaDefinitions.leak_damage("darksteel_boss")==120,"heavy bear and mini-boss leak tiers")
	check(ArenaDefinitions.leak_damage("pigsoldier",true)==24 and ArenaDefinitions.leak_damage("dreadeye_viper",true)==24,"elites leak for at least twenty-four")
	check(ArenaDefinitions.leak_damage("bear_vanguard",true)==36,"elite bear keeps the higher leak")
func check_wave_dispatch() -> void:
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);await process_frame
	game.start_run("knight","forest")
	game.cycle=2;game.phase="rest";game.phase_clock=10;game.begin_wave()
	check(game.enemies.is_empty() and not game.spawn_queue.is_empty(),"wave two uses the scheduled packets")
	game.cycle=5;game.phase="rest";game.begin_wave()
	check(game.enemies.is_empty() and game.spawn_queue==game.wave_packets(game.wave_pattern()),"wave five only dispatches the scheduled roster")
