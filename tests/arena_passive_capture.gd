extends SceneTree

var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	game.hero.apply_passive("tower_bolt")
	game.hero.apply_passive("tower_cannon")
	game.build_kind = "cannon"
	game.place_tower(game.world_to_cell(game.CORE + Vector2(260, 0)))
	game.place_tower(game.world_to_cell(game.CORE + Vector2(-260, 0)))
	game.passive_selecting = true
	var choices: Array[String] = ["tower_bolt", "tower_cannon", "tower_mixed"]
	game.passive_choices = choices
	game.hud.show_passive_choice(game.passive_choices, "level", 3, 1)
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/arena-passive.png")
	game.queue_free()
	await process_frame
	quit()
