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
		var level := ArenaLevelCatalog.definition(stage)
		var total := ArenaLevelCatalog.total_waves(stage)
		for number in range(1,total+1):
			var pattern := ArenaLevelCatalog.wave(stage,number)
			var expected:=0
			var preview_counts := {}
			for group in pattern.units:
				var amount:=int(group[1]);var elite_count:=int(group[2]) if group.size()>2 else 0
				check(elite_count<=amount,"%s W%d elite count fits the group"%[stage,number])
				expected+=elite_count
				var kind := str(group[0])
				preview_counts[kind] = preview_counts.get(kind,Vector2i.ZERO) + Vector2i(amount,elite_count)
			var scheduled_counts := {}
			for packet in ArenaLevelCatalog.plan_wave(pattern,level,number,-1,null,95.0):
				var kind := str(packet.kind)
				scheduled_counts[kind] = scheduled_counts.get(kind,Vector2i.ZERO) + Vector2i(1,int(packet.elite))
			check(preview_counts==scheduled_counts,"%s W%d preview matches the scheduled enemies and elites"%[stage,number])
			var profile:=ArenaLevelCatalog.wave_profile(stage,number,pattern)
			check(profile.elites==expected,"%s W%d profile matches authored elites"%[stage,number])
			check(expected>=0 and expected<=28,"%s W%d keeps elites bounded"%[stage,number])
	check(ArenaLevelCatalog.elite_kinds("forest",3).size()>=1,"forest W3 authors elite units")
	check(ArenaLevelCatalog.elite_kinds("creek",3).size()>=1,"creek W3 authors elite units")
	check(ArenaLevelCatalog.elite_kinds("creek",5).size()>=1,"creek W5 authors elite units")
func check_profiles() -> void:
	check(ArenaLevelCatalog.wave_profile("forest",4).heavy>=0.35,"forest W4 is a heavy wave")
	check(ArenaLevelCatalog.wave_profile("creek",4).heavy>=0.35,"creek W4 is a heavy wave")
	check(ArenaLevelCatalog.wave_profile("forest",3).high_res>=0.05,"forest W3 introduces shaman resist pressure")
	check(ArenaLevelCatalog.wave_profile("creek",2).has_flying,"creek W2 introduces flying vultures")
	var forest4:=ArenaLevelCatalog.wave_profile("forest",4);var forest5:=ArenaLevelCatalog.wave_profile("forest",5)
	var creek4:=ArenaLevelCatalog.wave_profile("creek",4);var creek5:=ArenaLevelCatalog.wave_profile("creek",5)
	check(forest5.non_boss>=forest4.non_boss,"forest W5 Siege matches or outgrows W4")
	check(creek5.non_boss>=10,"creek W5 includes escort pack alongside boss")
	check(not forest5.has_boss and creek5.has_boss and ArenaLevelCatalog.wave_profile("creek",3).has_mini_boss,"stage 1 has no boss; stage 2 has W3 mini-boss and W5 big boss")
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
