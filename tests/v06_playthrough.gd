extends "v030_se_balance_proof.gd"

# Reuse the dual-domain strategy with a selectable campaign setup.
func run() -> void:
	var hero_id := "lord"
	var stage := "forest"
	var hero_level := 1
	var seed := 42
	var strategy := "dual"
	var benchmark := false
	var loadout: Array[String] = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hero="):
			hero_id = arg.trim_prefix("--hero=")
		elif arg.begins_with("--level="):
			stage = arg.trim_prefix("--level=")
		elif arg.begins_with("--hero-level="):
			hero_level = int(arg.trim_prefix("--hero-level="))
		elif arg.begins_with("--seed="):
			seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--strategy="):
			strategy = arg.trim_prefix("--strategy=")
		elif arg == "--benchmark":
			benchmark = true
		elif arg.begins_with("--towers="):
			loadout.assign(arg.trim_prefix("--towers=").split(","))
	var strategies := {"dual": "DualDomain_Synergy", "defense": "OnlyDefense_NoRift", "rift": "OnlyRift_NoRecall"}
	if seed <= 0 or not strategies.has(strategy) or not ArenaDefinitions.is_valid_hero_id(hero_id) or stage not in ArenaLevelCatalog.IDS or hero_level not in range(1, 6):
		push_error("Invalid playthrough hero, stage, level, seed, or strategy.")
		quit(1)
		return
	if not loadout.is_empty():
		var profile := ArenaCampaign.new("", false)
		if not profile.equip_towers(loadout) or not profile.can_deploy(stage, true):
			push_error("Invalid tower loadout for " + stage)
			quit(1)
			return
	var result := await _run_strategy(strategies[strategy], stage, ArenaDefinitions.resolve_hero_id(hero_id), hero_level, loadout, seed, benchmark)
	if result.is_empty():
		push_error("Playthrough ended before producing a result.")
		quit(1)
		return
	print("NORMAL ", hero_id, " ", stage, " ", JSON.stringify(result))
	var ran_to_completion: bool = result.game_over and result.settled and int(result.built) > 0
	if result.victory:
		ran_to_completion = ran_to_completion and result.cycle == result.total_waves and result.core_hp > 0
	else:
		ran_to_completion = ran_to_completion and result.core_hp <= 0
	if not loadout.is_empty() and strategy != "rift":
		ran_to_completion = ran_to_completion and loadout.all(func(kind): return kind in result.tower_kinds)
	if not ran_to_completion:
		push_error("Playthrough failed to reach a valid settlement with the requested loadout.")
	quit(0 if ran_to_completion else 1)
