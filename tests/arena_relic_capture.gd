extends SceneTree

var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	await process_frame
	for drop in game.drops:
		if is_instance_valid(drop) and drop.weapon_key != "":
			game.hero.position = drop.position
			break
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/arena-relic.png")
	game.queue_free()
	await process_frame
	quit()
