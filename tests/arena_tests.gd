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
	check("knight_bulwark" in level_pool and not ("ranger_tempo" in level_pool), "Class-specific upgrades filter by hero")
	check(ArenaUpgrades.weight_for("power", game.hero, 1) > ArenaUpgrades.weight_for("storm", game.hero, 1), "Early pool favors common cards")
	check(ArenaUpgrades.weight_for("storm", game.hero, 6) > ArenaUpgrades.weight_for("power", game.hero, 6), "Late pool favors epic cards")
	var pre_bulwark: float = game.hero.damage_reduction
	game.hero.apply_passive("knight_bulwark")
	check(game.hero.damage_reduction > pre_bulwark, "Knight class passive applies its effect")
	var pre_tier: int = game.hero.weapon_level
	game.hero.apply_passive("pistol_quickdraw")
	game.hero.apply_passive("pistol_ricochet")
	check(game.hero.weapon_level >= maxi(2, pre_tier), "Two weapon cards evolve the weapon")
	game.hero.apply_passive("pistol_storm")
	game.hero.apply_passive("pistol_caliber")
	check(game.hero.weapon_level == 3, "Four weapon cards unlock weapon tier 3")
	var tower_speed_before: float = game.tower_attack_speed_scale("bolt")
	game.hero.apply_passive("tower_bolt")
	check(game.tower_attack_speed_scale("bolt") > tower_speed_before, "Tower bolt passive speeds towers up")
	var tower_cost_before: int = game.tower_cost("bolt")
	game.hero.apply_passive("tower_engineer")
	check(game.tower_cost("bolt") < tower_cost_before, "Tower engineer passive discounts construction")
	game.hero.apply_passive("tower_command")
	check(game.tower_attack_speed_scale("cannon", game.hero.position) > 1.0, "Tower command speeds nearby towers")
	game.hero.passives["tower_link"] = 1
	game.hero.passives["tower_network"] = 1
	check("tower_fortress" in ArenaUpgrades.ready_synergies(game.hero), "Tower synergy is ready after prerequisites")
	game.hero.passives.erase("tower_link")
	game.hero.passives.erase("tower_network")
	var camp_pool := ArenaUpgrades.build_pool(game.hero, "camp")
	check(not ("power" in camp_pool), "Camp pool excludes common upgrades")
	game.hero.passives["burn"] = 1
	game.hero.passives["chain"] = 1
	var synergy_pool := ArenaUpgrades.build_pool(game.hero, "level")
	check("stormfire" in synergy_pool, "Synergy appears only after prerequisites")
	game.hero.passives.erase("burn")
	game.hero.passives.erase("chain")
	var rolled_choices := ArenaUpgrades.roll(game.hero, "level", 3, game.rng, true, true)
	var rolled_weapon := false
	var rolled_element := false
	for key in rolled_choices:
		if ArenaUpgrades.DEFS[key].has("weapon"): rolled_weapon = true
		if "元素" in ArenaUpgrades.DEFS[key].tags: rolled_element = true
	check(rolled_choices.size() == 3 and rolled_weapon and rolled_element, "Roll guarantees a weapon and element card")
	game.hero.add_xp(500)
	check(game.passive_selecting, "Level up opens a passive choice")
	var rerolls_before: int = game.passive_rerolls
	game.reroll_passive_choice()
	check(game.passive_rerolls == rerolls_before - 1 and game.passive_selecting, "Passive reroll refreshes the choice")
	while game.passive_selecting:
		game.choose_passive(game.passive_choices[0])
	check(game.hero.level > level_before, "Level up advances the hero")

	game.gold = 600
	game.build_kind = "bolt"
	var cell: Vector2i = game.world_to_cell(game.CORE + Vector2(260, 0))
	check(game.can_place(cell) == "", "A legal cell can host a tower")
	var tower = game.place_tower(cell)
	check(tower != null and game.towers.size() == 1, "Placing a tower consumes a slot")
	check(ArenaTower.STATS.size() == 7 and ArenaTower.TOWER_ORDER.size() == 7, "Seven tower types are available")
	game.build_kind = "banner"
	var banner_cell: Vector2i = cell + Vector2i(2, 0)
	game.place_tower(banner_cell)
	check(game.tower_support_bonus(game.towers[0]) > 0.0, "Banner aura buffs nearby towers")
	check(game.blocked[game.cell_index(cell)], "Tower blocks its grid cell")
	check(game.can_place(cell + Vector2i(1, 0)) == "不能挨着其他塔", "Towers cannot be adjacent")
	check(game.can_place(game.world_to_cell(game.CORE + Vector2(1200, 0))) == "超出建造范围", "Build radius is enforced")
	check(game.towers[0].upgrade() and game.towers[0].level == 2, "Towers can be upgraded with gold")
	var before_menu_build: int = game.towers.size()
	game.toggle_build_mode()
	game.build_cell = game._nearest_build_cell(Vector2i(25, 20))
	game.build_site_ok = true
	game.build_valid = true
	game.set_build_kind("bolt")
	game.hud.palette_buttons["bolt"].emit_signal("pressed")
	check(game.towers.size() == before_menu_build + 1, "Build menu icon places a tower")
	var before_second_build: int = game.towers.size()
	game.toggle_build_mode()
	game.build_cell = game._nearest_build_cell(Vector2i(26, 20))
	game.build_site_ok = true
	game.build_valid = true
	game.set_build_kind("bolt")
	game.hud.palette_buttons["bolt"].emit_signal("pressed")
	check(game.towers.size() == before_second_build + 1, "Build menu can be used again after a build")
	var before_manual_click: int = game.towers.size()
	game.toggle_build_mode()
	game.build_cell = game._nearest_build_cell(Vector2i(24, 24))
	game.set_build_kind("bolt")
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

	var armored_test: ArenaEnemy = game.spawn_enemy("armored", game.CORE + Vector2(700, 0), 100.0)
	check(armored_test.weakness == "lightning" and armored_test.element_multiplier("lightning") > 1.0, "Armored enemies are weak to lightning")
	game.enemy_escaped(armored_test)
	armored_test.queue_free()
	var brute_test: ArenaEnemy = game.spawn_enemy("brute", game.CORE + Vector2(700, 100), 100.0)
	brute_test.apply_burn(10.0, 3.0)
	check(brute_test.weakness == "fire" and brute_test.burn_dps > 10.0, "Fire weakness amplifies burn")
	game.enemy_escaped(brute_test)
	brute_test.queue_free()
	var freeze_test: ArenaEnemy = game.spawn_enemy("torch", game.CORE + Vector2(800, 200), 100.0)
	freeze_test.apply_frost(2.0)
	freeze_test.apply_frost(2.0)
	freeze_test.apply_frost(2.0)
	check(freeze_test.freeze_time > 0.0, "Three frost applications freeze an enemy")
	game.enemy_escaped(freeze_test)
	freeze_test.queue_free()
	game.hero.apply_passive("burn")
	game.hero.apply_passive("wildfire")
	var fire_source: ArenaEnemy = game.spawn_enemy("torch", game.CORE + Vector2(850, 0), 100.0)
	var fire_target: ArenaEnemy = game.spawn_enemy("torch", game.CORE + Vector2(880, 0), 100.0)
	fire_source.apply_burn(12.0, 3.0)
	fire_source.take_damage(9999.0)
	check(fire_target.burn_time > 0.0, "Wildfire spreads burn on death")
	game.enemy_escaped(fire_target)
	fire_target.queue_free()
	var build_check: Dictionary = game.build_report()
	check(build_check.has("grade") and build_check.has("boss_affinity") and build_check.has("warnings"), "Boss build report has grade, affinity and warnings")

	game.dry_weapon_choices = 2
	game.dry_element_choices = 2
	game.open_passive_choice("level")
	var soft_weapon := false
	var soft_element := false
	for key in game.passive_choices:
		if ArenaUpgrades.DEFS[key].has("weapon"): soft_weapon = true
		if "元素" in ArenaUpgrades.DEFS[key].tags: soft_element = true
	check(soft_weapon and soft_element, "Two dry levels trigger weapon and element pity")
	var banish_key: String = game.passive_choices[0]
	game.banish_passive_choice(banish_key)
	check(banish_key in game.banished_passives and not (banish_key in game.passive_choices), "Banish removes one card from the pool")
	game.choose_passive(game.passive_choices[0])
	game.hero.passives["burn"] = 1
	game.hero.passives["chain"] = 1
	var ready_synergies := ArenaUpgrades.ready_synergies(game.hero)
	check("stormfire" in ready_synergies, "Ready synergy enters the weighted pool")
	game.hero.passives.erase("burn")
	game.hero.passives.erase("chain")
	var gold_before_empty: int = game.gold
	var saved_passives: Dictionary = game.hero.passives.duplicate()
	for key in ArenaUpgrades.DEFS:
		game.hero.passives[key] = int(ArenaUpgrades.DEFS[key].max)
	game.open_passive_choice("level")
	check(not game.passive_selecting and game.gold > gold_before_empty, "Empty upgrade pool converts to gold instead of soft-locking")
	game.hero.passives = saved_passives

	game.hero.invulnerability = 0.0
	game.hero.take_damage(9999.0)
	check(game.game_over and not game.running, "Hero death ends the run")
	check(game.hud.result_panel.visible, "Death shows the result panel")

	print("ARENA CHECKS: %d, FAILURES: %d" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
