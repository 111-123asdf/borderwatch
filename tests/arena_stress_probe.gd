extends SceneTree

var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	game.gold = 99999
	var cells: Array[Vector2i] = []
	for ring in [3, 5, 7, 9]:
		for index in range(5):
			var angle: float = TAU * index / 5.0 + ring * 0.13
			var point: Vector2 = game.CORE + Vector2.RIGHT.rotated(angle) * (ring * 64.0)
			cells.append(game.world_to_cell(point))
	var kinds := ["bolt", "cannon", "frost", "arc", "venom", "laser", "banner"]
	var placed := 0
	for cell in cells:
		game.build_kind = kinds[placed % kinds.size()]
		if game.place_tower(game._nearest_build_cell(cell)):
			placed += 1
		if placed >= 20: break
	for index in range(120):
		var angle := TAU * index / 120.0
		var point: Vector2 = game.CORE + Vector2.RIGHT.rotated(angle) * (game.SPAWN_RADIUS + 40.0)
		game.spawn_enemy("torch", point, 500.0)
	var start := Time.get_ticks_usec()
	for index in range(300):
		await process_frame
	var elapsed_ms := (Time.get_ticks_usec() - start) / 1000.0
	print("STRESS " + JSON.stringify({
		"towers": game.towers.size(),
		"enemies": game.enemies.size(),
		"frames": 300,
		"elapsed_ms": snappedf(elapsed_ms, 1.0),
		"avg_ms": snappedf(elapsed_ms / 300.0, 3.0),
	}))
	game.queue_free()
	await process_frame
	quit()
