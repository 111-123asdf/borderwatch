extends SceneTree

# Support-line check: four bolt towers inside the hero's command aura must hold
# the first two waves even when the hero never attacks. The hero is the main
# damage dealer; this proves the tower/aura half is still meaningful support.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.sound.enabled = false
	game.gold = 600
	for index in [0, 1, 6, 7]:
		game.choose_build("bolt")
		game.try_build(Rules.BUILD_SITES[index])
	game.hero.position = Vector2(1100, 950)
	game.start_wave()
	var cores: Array = []
	var last_clear := 0
	while game.elapsed < 240 and game.completed_waves < 2 and game.hud.modal_kind != "result":
		if game.hud.modal_kind == "reward":
			var index: int = game.offered.find("command")
			game.hud.reward_buttons[maxi(0, index)].pressed.emit()
		await physics_frame
		if game.completed_waves > last_clear:
			last_clear = game.completed_waves
			cores.append(game.core_health)
			if game.completed_waves < 2: game.start_wave()
	paused = false
	var report := {"scenario": "aura_support_no_hero_attacks", "cores": cores, "gold": game.gold, "towers": game.towers.size(), "kills": game.stats.tower_kills, "elapsed": game.elapsed}
	var file := FileAccess.open("res://test-results/defense_balance.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	var success: bool = cores.size() >= 2 and cores[0] >= 220 and cores[1] >= 200 and game.stats.tower_kills > 20
	game.queue_free()
	await process_frame
	quit(0 if success else 1)
