extends SceneTree

var game: Node2D
var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("ARENA FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	check(game.hero != null, "Arena creates a hero")
	check(game.core_health == game.core_max, "Arena creates a core")
	check(game.spawn_points.size() == 8, "Arena has eight spawn regions")
	check(game.flow_at(game.CORE + Vector2(300, 0)).length() > 0.0, "Flow field points toward the core")

	var camp_drop: ArenaDrop
	for drop in game.drops:
		if is_instance_valid(drop) and drop.cache:
			camp_drop = drop
	check(camp_drop != null, "The first rest spawns a camp chest")
	if camp_drop != null:
		game.hero.position = camp_drop.position
		await create_timer(0.25).timeout
		check(game.camps_cleared == 1, "Collecting a camp chest advances camp progression")
		check(game.passive_selecting, "Camp chest opens a powerful passive choice")
		var passive_key: String = game.passive_choices[0]
		game.choose_passive(passive_key)
		check(not game.passive_selecting, "Choosing a camp passive resumes the run")
		check(game.hero.passives.size() > 0 or "lone" in game.relics or "swarm" in game.relics or "vanguard" in game.relics or "command" in game.relics or "raid" in game.relics or "hold" in game.relics, "Camp passive applies")

	var level_before: int = game.hero.level
	var level_pool := ArenaUpgrades.build_pool(game.hero, "level")
	check("pistol_akimbo" in level_pool and not ("bow_hunter" in level_pool), "Weapon-specific upgrades filter by weapon")
	var camp_pool := ArenaUpgrades.build_pool(game.hero, "camp")
	check(not ("power" in camp_pool), "Camp pool excludes common upgrades")
	game.hero.passives["burn"] = 1
	game.hero.passives["chain"] = 1
	var synergy_pool := ArenaUpgrades.build_pool(game.hero, "level")
	check("stormfire" in synergy_pool, "Synergy appears only after prerequisites")
	game.hero.passives.erase("burn")
	game.hero.passives.erase("chain")
	game.hero.add_xp(500)
	check(game.passive_selecting, "Level up opens a passive choice")
	while game.passive_selecting:
		game.choose_passive(game.passive_choices[0])
	check(game.hero.level > level_before, "Level up advances the hero")

	game.gold = 600
	game.build_kind = "bolt"
	var cell: Vector2i = game.world_to_cell(game.CORE + Vector2(260, 0))
	check(game.can_place(cell) == "", "A legal cell can host a tower")
	var tower = game.place_tower(cell)
	check(tower != null and game.towers.size() == 1, "Placing a tower consumes a slot")
	check(game.blocked[game.cell_index(cell)], "Tower blocks its grid cell")
	check(game.can_place(cell + Vector2i(1, 0)) == "不能挨着其他塔", "Towers cannot be adjacent")
	check(game.can_place(game.world_to_cell(game.CORE + Vector2(1000, 0))) == "超出建造范围", "Build radius is enforced")
	check(game.towers[0].upgrade() and game.towers[0].level == 2, "Towers can be upgraded with gold")
	var before_menu_build: int = game.towers.size()
	game.toggle_build_mode()
	game.build_cell = game._nearest_build_cell(Vector2i(25, 20))
	game.build_site_ok = true
	game.build_valid = true
	game.hud.palette_buttons["bolt"].emit_signal("pressed")
	check(game.towers.size() == before_menu_build + 1, "Build menu icon places a tower")
	var before_second_build: int = game.towers.size()
	game.toggle_build_mode()
	game.build_cell = game._nearest_build_cell(Vector2i(26, 20))
	game.build_site_ok = true
	game.build_valid = true
	game.hud.palette_buttons["bolt"].emit_signal("pressed")
	check(game.towers.size() == before_second_build + 1, "Build menu can be used again after a build")
	var before_manual_click: int = game.towers.size()
	game.toggle_build_mode()
	game.build_cell = game._nearest_build_cell(Vector2i(24, 24))
	await create_timer(0.1).timeout
	var click_button: Button = game.hud.palette_buttons["bolt"]
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = click_button.get_global_rect().get_center()
	game._unhandled_input(click_event)
	check(game.towers.size() == before_manual_click + 1, "Build menu click event places a tower")
	var before_confirmed = game.towers.size()
	game.number_build("bolt")
	check(game.towers.size() == before_confirmed and game.build_mode, "First number key only enters build mode")
	game.number_build("bolt")
	check(game.towers.size() == before_confirmed + 1, "Second press of the same number builds")

	game.hero.position = game.CORE + Vector2(160, 0)
	var gold_before: int = game.gold
	var drop = game.spawn_drop(game.hero.position, 10, 5, false)
	await create_timer(0.35).timeout
	check(is_instance_valid(drop) == false, "Drops are collected on contact")
	check(game.gold >= gold_before + 5, "Collected gold reaches the hero wallet")

	var core_before: float = game.core_health
	game.hero.set_physics_process(false)
	for placed in game.towers:
		placed.active = false
	var leaked = game.spawn_enemy("torch", game.CORE, 30.0)
	await create_timer(0.25).timeout
	check(game.enemies.is_empty(), "Leaked enemies are removed from the live array")
	check(game.core_health < core_before, "Leaked enemies damage the core")

	game.towers[0].active = true
	var tower_health_before: float = game.towers[0].health
	var sapper = game.spawn_enemy("sapper", game.towers[0].position + Vector2(30, 0), 1000.0)
	await create_timer(0.25).timeout
	check(game.towers[0].health < tower_health_before, "Sappers damage towers")
	game.enemy_escaped(sapper)
	sapper.queue_free()

	var shield_before: float = game.hero.shield
	var shooter = game.spawn_enemy("shooter", game.hero.position + Vector2(70, 0), 1000.0)
	await create_timer(0.6).timeout
	check(game.hero.shield < shield_before or game.hero.health < game.hero.max_health, "Shooters threaten the hero")
	game.enemy_escaped(shooter)
	shooter.queue_free()

	game.spawn_budget = 4
	game.start_spawn()
	game.spawn_cluster()
	check(game.enemies.size() > 0, "Spawn director creates enemies")
	check(game.flow_at(game.spawn_points[0]).length() > 0.0, "Spawned enemies have a flow direction")

	game.hero.invulnerability = 0.0
	game.hero.take_damage(9999.0)
	check(game.game_over and not game.running, "Hero death ends the run")
	check(game.hud.result_panel.visible, "Death shows the result panel")

	print("ARENA CHECKS: %d, FAILURES: %d" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
