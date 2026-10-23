extends SceneTree

var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func capture(key: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/arena-" + key + ".png")

func _run() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.gold = 800
	var cells := [
		Vector2i(23, 20), Vector2i(17, 20), Vector2i(20, 23), Vector2i(20, 17),
	]
	for index in range(cells.size()):
		game.build_kind = ["bolt", "cannon", "frost", "bolt"][index]
		game.place_tower(cells[index])
	game.start_spawn()
	game.spawn_budget = 28
	for index in range(3):
		game.spawn_cluster()
	await create_timer(1.4).timeout
	await capture("field")
	Input.action_press("build")
	await create_timer(0.7).timeout
	await capture("build")
	Input.action_release("build")
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	quit()
