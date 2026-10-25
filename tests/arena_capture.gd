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
	game.start_with_hero("knight")
	game.hero.apply_passive("knight_bulwark")
	game.hero.apply_passive("pistol_quickdraw")
	game.hero.apply_passive("pistol_ricochet")
	game.hero.apply_passive("power")
	game.hero.apply_passive("burn")
	game.hero.apply_passive("chain")
	game.hero.apply_passive("crit")
	game.hero.apply_passive("swift")
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
	game.toggle_build_mode()
	await create_timer(0.55).timeout
	var preview_screen: Vector2 = game.get_viewport().get_canvas_transform() * game.cell_center(Vector2i(24, 20))
	Input.warp_mouse(preview_screen)
	await create_timer(0.35).timeout
	await capture("build")
	game.select_tower(game.towers[0])
	await create_timer(0.2).timeout
	await capture("tower")
	game.toggle_build_mode()
	await create_timer(0.2).timeout
	game.queue_free()
	await process_frame
	quit()
