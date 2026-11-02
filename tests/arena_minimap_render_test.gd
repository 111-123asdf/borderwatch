extends SceneTree

# Graphics fixture: creates and expires drops explicitly to check the minimap.
# It does not represent a natural exploration or a completed game.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _pixel(point: Vector2) -> Color:
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image().get_pixelv(Vector2i(point))

func _run() -> void:
	var game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	game.running = false
	game.expire_normal_drops()
	var minimap: Control = game.hud.minimap
	var world_point := Vector2(520, 560)
	var inner := minimap.size - Vector2(20, 42)
	var map_scale: float = minf(inner.x / game.ARENA_SIZE.x, inner.y / game.ARENA_SIZE.y)
	var marker_screen := minimap.get_global_rect().position + Vector2(10, 32) + world_point * map_scale
	var ground := await _pixel(marker_screen)
	game.spawn_drop(world_point, 20, 30, true, true)
	var cache := await _pixel(marker_screen)
	if cache.r < 0.7 or cache.g < 0.55 or cache.b < 0.25 or cache.is_equal_approx(ground):
		failures.append("cache marker is not visible on the real minimap")
	game.expire_normal_drops()
	var expired := await _pixel(marker_screen)
	if not expired.is_equal_approx(ground):
		failures.append("expired cache marker remains on the map")
	game.spawn_drop(world_point, 6, 5, false, false)
	var ordinary := await _pixel(marker_screen)
	if not ordinary.is_equal_approx(ground):
		failures.append("ordinary pickups clutter the minimap")
	for failure in failures:
		push_error("MINIMAP RENDER FAIL: " + failure)
	print("ARENA MINIMAP RENDER: %d failures" % failures.size())
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
