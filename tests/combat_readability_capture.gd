extends SceneTree
## Fixed-camera visual fixture. Enemies, road progress and hero level are injected.
## -- --rescue=active or --rescue=hold compares identical incoming enemies.
var game: ArenaGame
var elapsed := 0.0
var spawned := 0
var mode := "towers"
var capture_dir := ProjectSettings.globalize_path("res://test-results/four-towers-capture")
var blocked: Dictionary = {}
var staggered: Dictionary = {}
var furthest := 0.0
var leaks := 0
var previous_hp := 750.0
var watching := false
var used_q := false
var used_e := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--rescue="):
			mode = arg.trim_prefix("--rescue=")
	if mode=="four_towers" and DirAccess.make_dir_recursive_absolute(capture_dir)!=OK:
		push_error("Cannot create capture directory: "+capture_dir)
		quit(1)
		return
	call_deferred("_setup")

func _setup() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	game.campaign.data.levels.lord = 5
	root.add_child(game)
	await process_frame
	game.rng.seed = 180019
	game.start_run("lord", "ruins")
	game.phase = "sample"
	game.gold = 9999
	game.cycle = 5
	if mode == "four_towers":
		game.build_tower(3, "archer")
		game.site_tower(3).upgrade()
		game.build_tower(5, "cannon")
		game.site_tower(5).upgrade()
		game.build_tower(4, "mage")
		game.site_tower(4).upgrade()
		game.build_tower(2, "barracks")
		game.site_tower(2).upgrade()
		var road0: Curve2D = game.routes[0]
		var base_d := road0.get_closest_offset(Vector2(760, 290))
		for k_i in range(6):
			var kind_name: String = ["construct_hound", "rune_warden", "rift_bomber"][k_i % 3]
			var e := game.spawn_enemy(kind_name, 0, base_d + float(k_i) * 36.0)
			e.max_health *= 3.0
			e.health = e.max_health
	else:
		if mode == "towers":
			game.build_tower(3, "archer")
		game.build_tower(5, "archer")
	game.hero.position = Vector2(1100, 690)
	game.camera.focus(Vector2(910, 485))
	watching = true

func _physics_process(delta: float) -> bool:
	if not watching:
		return false
	elapsed += delta
	game.camera.focus(Vector2(910, 485))
	var interval := 1.8 if spawned < 3 else 0.58
	var next_time := 0.3 + spawned * interval if spawned < 3 else 5.7 + (spawned - 3) * interval
	if spawned < 15 and elapsed >= next_time:
		var road: Curve2D = game.routes[0]
		var distance := road.get_closest_offset(Vector2(900,350) if mode == "towers" else Vector2(830,525))
		game.spawn_enemy("construct_hound", 0, distance)
		spawned += 1
	if mode == "active":
		if elapsed < 0.3:
			game.hero.command_move(Vector2(947,558))
		Input.action_press("shoot")
		var enemy := game.nearest_enemy(game.hero.center(), 140.0, false)
		if enemy != null:
			if elapsed >= 5.8 and not used_q:
				used_q = game.hero.cast(0, enemy.position)
			elif elapsed >= 3.0 and not used_e:
				used_e = game.hero.cast(1, enemy.position)
	for enemy in game.enemies:
		if enemy.is_guard:
			continue
		furthest = maxf(furthest, enemy.progress / game.enemy_road(enemy).get_baked_length())
		if enemy.blocker == game.hero:
			blocked[enemy.get_instance_id()] = true
		if enemy.stun > 0:
			staggered[enemy.get_instance_id()] = true
	# Identical non-elite hounds in this fixture each cost 14 core health.
	if game.core_health < previous_hp:
		leaks += roundi((previous_hp - game.core_health) / 14.0)
		previous_hp = game.core_health
	if mode == "four_towers":
		if elapsed >= 1.35 and not root.has_meta("salvo_triggered"):
			root.set_meta("salvo_triggered", true)
			game.site_tower(3).trigger_bonus_salvo()
			game.site_tower(4).trigger_bonus_salvo()
			game.site_tower(5).trigger_bonus_salvo()
		if elapsed >= 1.52 and not root.has_meta("captured_showcase"):
			root.set_meta("captured_showcase", true)
			var img := root.get_viewport().get_texture().get_image()
			if img != null:
				img.save_png(capture_dir.path_join("four-towers.png"))
		if elapsed >= 1.78 and not root.has_meta("captured_blast"):
			root.set_meta("captured_blast", true)
			var img2 := root.get_viewport().get_texture().get_image()
			if img2 != null:
				img2.save_png(capture_dir.path_join("cannon-blast.png"))
			watching = false
			call_deferred("_finish")
			return false
	if elapsed >= 15.6:
		watching = false
		Input.action_release("shoot")
		print("SAMPLE ", mode, " kills=", game.kills, " leaks=", leaks, " blocked=", blocked.size(), " staggered=", staggered.size(), " furthest_seen=", snappedf(furthest,0.001), " core=", game.core_health, " Q=", used_q, " E=", used_e, " damage=",game.damage_stats)
		call_deferred("_finish")
	return false

func _finish() -> void:
	game.running = false
	game.audio.shutdown()
	game.queue_free()
	await process_frame
	quit()
