extends SceneTree

var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	game.spawn_warnings.append({"point": game.CORE + Vector2(0, -680), "life": 1.1, "radius": 74.0})
	game.spawn_warnings.append({"point": game.CORE + Vector2(-520, -380), "life": 1.1, "radius": 74.0})
	var hound: ArenaEnemy = game.spawn_enemy("hound", game.CORE + Vector2(330, -240), 90.0)
	var shaman: ArenaEnemy = game.spawn_enemy("shaman", game.CORE + Vector2(-300, -220), 180.0)
	var mortar: ArenaEnemy = game.spawn_enemy("mortar", game.CORE + Vector2(380, 240), 220.0)
	var splitter: ArenaEnemy = game.spawn_enemy("splitter", game.CORE + Vector2(-360, 260), 180.0)
	var elite: ArenaEnemy = game.spawn_enemy("armored", game.CORE + Vector2(0, 300), 260.0, true)
	elite.elite_mod = "volatile"
	elite.speed = 40.0
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/arena-enemies.png")
	game.queue_free()
	await process_frame
	quit()
