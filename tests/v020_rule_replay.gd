extends "res://tests/v06_playthrough.gd"
## Design experiment. Replay the same defense, changing only Creek wave 5's main queue.

var southern_defense := false

class CreekReplay extends ArenaGame:
	var lure_lane := -1
	var start_damage: Dictionary
	var start_core: float
	var layout: Array[String] = []
	var first_kills := {}

	func wave_packets(pattern: Dictionary) -> Array:
		var packets := super.wave_packets(pattern)
		if cycle != 5 or lure_lane < 0:
			return packets
		var vanguard := []
		var main := []
		for packet in packets:
			if packet.elite:
				packet.route = 1 - lure_lane
				packet.at = 0.0
				vanguard.append(packet)
			else:
				packet.route = lure_lane
				main.append(packet)
		return vanguard + main

	func begin_wave() -> void:
		var preparing := phase == "rest"
		super.begin_wave()
		if not preparing or phase != "spawn" or cycle != 5:
			return
		start_damage = damage_stats.duplicate()
		start_core = core_health
		for tower in towers:
			layout.append("%d:%s:%d" % [tower.site_id, tower.kind, tower.level])
		var counts := [0, 0]
		for packet in spawn_queue:
			counts[packet.route] += 1
		print("CREEK_DEPLOY ", JSON.stringify({"lanes": counts, "gold": gold, "core": core_health, "towers": layout}))

	func enemy_defeated(enemy: ArenaEnemy) -> void:
		if cycle == 5 and phase == "spawn" and not enemy.is_guard and enemy.route_id not in first_kills:
			first_kills[enemy.route_id] = snappedf(wave_elapsed, 0.1)
		super.enemy_defeated(enemy)

	func start_rest(duration: float) -> void:
		if cycle == 6:
			var damage := {}
			for source in damage_stats:
				damage[source] = roundi(damage_stats[source] - start_damage.get(source, 0.0))
			print("CREEK_RESULT ", JSON.stringify({"wave": wave_log.back(), "first_kills": first_kills,
				"core_lost": start_core - core_health, "damage": damage}))
		super.start_rest(duration)

func run() -> void:
	stage = "creek"
	southern_defense = OS.get_cmdline_user_args().has("--south-defense")
	var battle := CreekReplay.new()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lure="):
			var variants := {"base": -1, "north": 0, "south": 1}
			var variant := arg.trim_prefix("--lure=")
			if not variants.has(variant):
				battle.free()
				push_error("Expected --lure=base, north or south")
				quit(1)
				return
			battle.lure_lane = variants[variant]
	game = battle
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	current_scene = game
	await process_frame
	game.rng.seed = 60406
	game.start_run(hero_id, stage)
	Input.action_press("shoot")

func manage_towers() -> void:
	if not southern_defense or game.cycle > 5:
		super.manage_towers()
		return
	# Spend normal gold at four sites covering the southern approach. Bank the rest.
	var tower_types := ["cannon", "barracks", "mage", "archer"]
	for index in range(tower_types.size()):
		var site := 5 + index
		if game.site_tower(site) == null:
			game.build_tower(site, tower_types[index])
			return
	for site in range(5, 9):
		var tower := game.site_tower(site)
		if tower.level < 2 and tower.project_level == 0:
			tower.upgrade()
			return
