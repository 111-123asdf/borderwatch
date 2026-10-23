extends SceneTree

var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	game.gold = 9999
	var cells := [Vector2i(23, 20), Vector2i(17, 20), Vector2i(20, 23), Vector2i(20, 17), Vector2i(24, 23), Vector2i(16, 17)]
	for index in range(cells.size()):
		game.build_kind = ["bolt", "cannon", "frost"][index % 3]
		game.place_tower(cells[index])
	game.cycle = 6
	game.start_spawn()
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/arena-boss.png")
	game.queue_free()
	await process_frame
	quit()
