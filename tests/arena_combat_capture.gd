extends SceneTree

var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	game.gold = 800
	game.build_kind = "cannon"
	game.place_tower(game.world_to_cell(game.CORE + Vector2(260, 0)))
	game.hero.position = game.CORE + Vector2(0, 220)
	for index in range(3):
		game.spawn_enemy("torch", game.CORE + Vector2(-180 + index * 150, 420), 180.0)
	game.start_spawn()
	await create_timer(0.2).timeout
	for index in range(5):
		var target = game.nearest_enemy(game.hero.position, 700.0)
		if target != null:
			game.hero.fire(target)
		await create_timer(0.11).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/arena-combat.png")
	game.queue_free()
	await process_frame
	quit()
