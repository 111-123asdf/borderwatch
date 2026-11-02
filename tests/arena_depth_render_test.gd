extends SceneTree

# Visual regression fixture: uses deliberately overlapped coloured markers to
# verify the renderer's actual ordering. This is not a natural playthrough.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _marker(parent: Node2D, color: Color, offset_y: float) -> ColorRect:
	var marker := ColorRect.new()
	marker.position = Vector2(-30, -30 + offset_y)
	marker.size = Vector2(60, 60)
	marker.color = color
	parent.add_child(marker)
	return marker

func _pixel_at(world: Vector2) -> Color:
	await process_frame
	await RenderingServer.frame_post_draw
	var point: Vector2 = root.get_canvas_transform() * world
	return root.get_texture().get_image().get_pixelv(Vector2i(point))

func _expect_color(actual: Color, expected: Color, message: String) -> void:
	if absf(actual.r - expected.r) > 0.05 or absf(actual.g - expected.g) > 0.05 or absf(actual.b - expected.b) > 0.05:
		failures.append(message)
		push_error("DEPTH FAIL: %s; got %s" % [message, actual])

func _run() -> void:
	var game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	game.running = false
	game.hud.hide()
	game.camera.position = game.CORE
	game.camera.zoom = Vector2.ONE
	game.get_node("CoreVisualAnchor").hide()
	game.hero.visual.hide()

	var tower := ArenaTower.new()
	tower.game = game
	tower.kind = "bolt"
	tower.position = game.CORE
	game.add_child(tower)
	tower.body.hide()
	_marker(tower, Color.BLUE, 0)

	game.hero.position = game.CORE + Vector2(0, 20)
	var hero_marker := _marker(game.hero, Color.RED, -20)
	_expect_color(await _pixel_at(game.CORE), Color.RED, "hero with lower feet is in front of tower")
	game.hero.position = game.CORE - Vector2(0, 20)
	hero_marker.position.y = -10
	_expect_color(await _pixel_at(game.CORE), Color.BLUE, "hero with higher feet is behind tower")
	hero_marker.hide()

	var enemy: ArenaEnemy = game.spawn_enemy("torch", game.CORE + Vector2(0, 20), 1000.0)
	enemy.visual.hide()
	var enemy_marker := _marker(enemy, Color.GREEN, -20)
	_expect_color(await _pixel_at(game.CORE), Color.GREEN, "enemy with lower feet is in front of tower")
	enemy.position = game.CORE - Vector2(0, 20)
	enemy_marker.position.y = -10
	_expect_color(await _pixel_at(game.CORE), Color.BLUE, "enemy with higher feet is behind tower")
	enemy.dead = true
	enemy_marker.hide()
	game.hero.position = game.CORE - Vector2(0, 60)

	var ally: ArenaProjectile = game.spawn_projectile(game.CORE, game.CORE + Vector2.RIGHT, 1.0, Color.MAGENTA, 0.0, 0.0, 0.0)
	_expect_color(await _pixel_at(game.CORE), Color.MAGENTA, "friendly projectile remains visible above tower")
	ally.queue_free()
	await process_frame
	var hostile: ArenaProjectile = game.enemy_shot(game.CORE, game.CORE + Vector2.RIGHT, 1.0, 0.0)
	hostile.color = Color.CYAN
	_expect_color(await _pixel_at(game.CORE), Color.CYAN, "enemy projectile remains visible above tower")

	print("ARENA DEPTH RENDER: %d failures" % failures.size())
	game.queue_free()
	await process_frame
	await create_timer(1.0, true, false, true).timeout
	quit(0 if failures.is_empty() else 1)
