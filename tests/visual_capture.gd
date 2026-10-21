extends SceneTree

var game: Node2D

func _initialize() -> void:
	call_deferred("_run")

func capture(key: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://test-results/0.3-" + key + ".png")

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await create_timer(0.4, true).timeout
	await capture("heroes")
	game.hud.tutorial_seen = false
	game.start_run()
	game.sound.enabled = false
	await create_timer(0.4, true).timeout
	await capture("tutorial")
	game.hud._finish_tutorial()
	game.gold = 500
	for index in range(2):
		game.choose_build("bolt")
		game.try_build(Rules.BUILD_SITES[index])
	await create_timer(0.8).timeout
	game.toast("", 0)
	await capture("base")
	game.hud.show_context(2, null)
	await create_timer(0.15, true).timeout
	await capture("construction")
	game.hud.close_context()
	for key in Rules.HEROES:
		game.hero.configure(key)
		game.hero.position = Rules.EXPLORATION_ROUTES[0][0] + Vector2(-80, 100)
		await create_timer(0.5).timeout
		game.hero.use_skill()
		game.hero.fire()
		await create_timer(0.12).timeout
		await capture(key)
	game.hero.configure("knight")
	game.hero.equip_weapon("gatling", 3)
	game.hero.energy = game.hero.max_energy
	game.hero.use_skill()
	for index in range(8):
		game.hero.fire()
		await create_timer(0.08).timeout
	await capture("dual-gatling")
	var shielded: Enemy = game.spawn_enemy("shielded", -1, -1, game.hero.position + Vector2(150, 0), 240)
	shielded.set_physics_process(false)
	await create_timer(0.4).timeout
	await capture("shielded")
	game.enemies.erase(shielded)
	shielded.queue_free()
	game.hud.show_inventory()
	await create_timer(0.15, true).timeout
	await capture("inventory")
	game.hud.close_modal()
	game.camps[0].cleared = true
	game.pending_rewards = 1
	game.open_reward()
	await create_timer(0.15, true).timeout
	await capture("reward")
	game.claim_relic(game.offered[0])
	game.hud.show_map()
	await create_timer(0.15, true).timeout
	await capture("map")
	game.hud.close_modal()
	game.completed_waves = 3
	for region in [1, 2]:
		game.hero.position = Rules.EXPLORATION_ROUTES[region][0] + Vector2(-80, 100)
		await create_timer(0.7).timeout
		await capture("stone-courtyard" if region == 1 else "star-ruins")
	game.hero.configure("ranger")
	game.hero.position = Rules.CORE + Vector2(-100, 150)
	game.wave = 6
	game.wave_active = true
	var boss: Enemy = game.spawn_enemy("boss", 0, -1, Vector2(1110, 576), 3500)
	await create_timer(0.7).timeout
	boss._boss_attack()
	await create_timer(0.75).timeout
	await capture("bullet-pattern")
	paused = false
	game.queue_free()
	await process_frame
	quit()
