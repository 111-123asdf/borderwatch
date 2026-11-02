extends SceneTree

const Catalog = preload("res://scripts/arena/arena_weapon_catalog.gd")

# Deliberate fixture damage and direct fire calls exercise weapon behavior;
# they are not a natural playthrough or a balance assessment.
var checks := 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		push_error("WEAPON FAIL: " + message)

func projectiles(game: Node) -> Array:
	return game.get_children().filter(func(node): return node is ArenaProjectile and not node.hostile)

func clear_projectiles(game: Node) -> void:
	for projectile in projectiles(game):
		game.remove_child(projectile)
		projectile.queue_free()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# Only the implemented arena weapons are available; legacy Rules entries
	# do not automatically become playable. The expected values are the
	# established projectile baselines, not a balance adjustment.
	check(Catalog.IDS == ["pistol", "bow", "scatter", "sniper"], "Catalog contains the four implemented weapons in drop order")
	var expected_patterns := {
		"pistol": ["straight", 900.0, 0],
		"bow": ["straight", 900.0, 0],
		"scatter": ["spread", 900.0, 0],
		"sniper": ["piercing", 1100.0, 3],
	}
	for weapon_id in Catalog.IDS:
		var data: Dictionary = Catalog.get_weapon(weapon_id)
		var pattern: Array = expected_patterns[weapon_id]
		check(not String(data.get("name", "")).is_empty(), "%s has a display name" % weapon_id)
		var tiers: Array = data.get("tiers", [])
		check(tiers.size() == 3 and tiers.all(func(title): return not String(title).is_empty()), "%s has three named evolution tiers" % weapon_id)
		check(data.get("icon") is Texture2D and data.get("hand_texture") is Texture2D, "%s has drop and held textures" % weapon_id)
		check(String(data.get("attack_type", "")) == pattern[0], "%s keeps its attack pattern" % weapon_id)
		check(is_equal_approx(float(data.get("projectile_speed", 0.0)), float(pattern[1])) and int(data.get("base_pierce", -1)) == int(pattern[2]), "%s keeps projectile speed and pierce" % weapon_id)
	var game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	var hero: ArenaHero = game.hero
	check(hero.weapon_inventory == ["pistol"], "Knight begins with its own starter weapon")
	var drop_point: Vector2 = game.CORE + Vector2(650, 0)
	for index in range(5):
		var enemy: ArenaEnemy = game.spawn_enemy("torch", drop_point + Vector2(0, index * 10), 1.0)
		enemy.take_damage(5.0, "hero")
	var weapon_drop: ArenaDrop
	for drop in game.drops:
		if is_instance_valid(drop) and drop.weapon_key == "bow": weapon_drop = drop
	check(weapon_drop != null, "The fifth enemy produces a distinct shared weapon")
	if weapon_drop != null:
		game.expire_normal_drops()
		check(weapon_drop in game.drops, "Wave expiry does not discard a weapon")
		game.running = false
		weapon_drop._process(9.0)
		check(weapon_drop.age == 0.0 and "bow" not in hero.weapon_inventory, "Weapon auto-recovery waits while combat is paused")
		game.running = true
		weapon_drop._process(8.1)
		check("bow" in hero.weapon_inventory and hero.weapon_key == "pistol", "Uncollected bow enters inventory without forced equip")
		check(not hero.collect_weapon("bow") and hero.weapon_inventory.count("bow") == 1, "Duplicate recovery does not duplicate inventory")
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_Q
	key_event.pressed = true
	game._unhandled_input(key_event)
	check(hero.weapon_key == "bow", "Q cycles to the collected weapon")
	game.hud._show_weapon_inventory()
	check(is_instance_valid(game.hud.weapon_overlay) and paused, "Inventory opens and pauses the fight")
	var pistol_button := game.hud.weapon_overlay.find_child("Weapon_pistol", true, false) as Button
	if pistol_button != null: pistol_button.pressed.emit()
	check(hero.weapon_key == "pistol" and not paused, "Inventory equips a selected weapon and resumes")
	game.running = false
	for hero_id in ["knight", "ranger", "mage"]:
		hero.configure(hero_id)
		var active_skill := hero.skill_name
		for weapon in ArenaHero.AVAILABLE_WEAPONS:
			hero.collect_weapon(weapon)
			check(hero.equip_weapon(weapon), "%s can equip %s" % [hero_id, weapon])
			check(hero.class_id == hero_id and hero.skill_name == active_skill, "Equipment does not change the hero or active skill")
			clear_projectiles(game)
			hero.fire(null)
			var expected := 5 if weapon == "scatter" else 1
			check(projectiles(game).size() == expected, "%s fires %s with its own projectile pattern" % [hero_id, weapon])
			check(not projectiles(game).is_empty() and projectiles(game)[0].damage > 0.0, "Equipped weapon deals positive damage")
	hero.configure("knight")
	for weapon in ArenaHero.AVAILABLE_WEAPONS: hero.collect_weapon(weapon)
	hero.skill_time = 5.0
	for weapon in ArenaHero.AVAILABLE_WEAPONS:
		hero.equip_weapon(weapon)
		clear_projectiles(game)
		hero.fire(null)
		check(projectiles(game).size() == (10 if weapon == "scatter" else 2), "Knight's active duplicates %s" % weapon)
	hero.skill_time = 0.0
	# Assert emitted projectiles, not just registry metadata. Keep the existing
	# asymmetry: scatter ignores pierce bonuses; sniper ignores extra shots.
	hero.aim = Vector2.RIGHT
	hero.pierce_bonus = 2
	hero.multishot = 1
	for weapon in Catalog.IDS:
		hero.equip_weapon(weapon)
		clear_projectiles(game)
		hero.fire(null)
		var fired := projectiles(game)
		var data := Catalog.get_weapon(weapon)
		check(fired.all(func(p): return is_equal_approx(p.speed, float(data.projectile_speed))), "%s shots keep their configured speed" % weapon)
		var expected_pierce := 0 if weapon == "scatter" else (5 if weapon == "sniper" else 2)
		check(fired.all(func(p): return p.pierce == expected_pierce), "%s retains its original pierce behavior" % weapon)
		if weapon == "scatter":
			check(fired.size() == 6 and is_equal_approx(fired[0].direction.angle(), -0.32) and is_equal_approx(fired[5].direction.angle(), 0.32), "Scatter keeps its count and fan angles")
		elif weapon == "sniper":
			check(fired.size() == 1 and fired[0].direction.is_equal_approx(Vector2.RIGHT), "Sniper ignores extra-shot bonus and fires straight")
		else:
			check(fired.size() == 2 and is_equal_approx(fired[1].position.y - fired[0].position.y, -22.0), "%s keeps straight multishot spacing" % weapon)
	hero.pierce_bonus = 0
	hero.multishot = 0
	# Equip does not reset a weapon's own remaining cooldown, while switching
	# away allows the other weapon to use its separately elapsed cooldown.
	for key in hero.weapon_cooldowns: hero.weapon_cooldowns[key] = 0.0
	hero.equip_weapon("sniper")
	hero.fire(null)
	var sniper_cooldown := hero.fire_cooldown
	hero.equip_weapon("bow")
	check(is_zero_approx(hero.fire_cooldown), "Bow is not locked by sniper's cooldown")
	hero.fire(null)
	hero.equip_weapon("sniper")
	check(is_equal_approx(hero.fire_cooldown, sniper_cooldown) and sniper_cooldown > hero.weapon_cooldowns["bow"], "Switching back cannot bypass sniper cooldown")
	hero._advance_weapon_cooldowns(0.5)
	check(is_equal_approx(hero.fire_cooldown, sniper_cooldown - 0.5) and is_zero_approx(float(hero.weapon_cooldowns["bow"])), "All weapon cooldowns advance with game time")
	hero.equip_weapon("pistol")
	hero.apply_passive("pistol_caliber")
	hero.apply_passive("pistol_ricochet")
	var pistol_effects := hero.equipped_weapon_effects()
	check(is_equal_approx(float(pistol_effects.damage), 1.18) and int(pistol_effects.pierce) == 1 and hero.weapon_level == 2, "Pistol-specific damage, pierce and tier apply to pistol")
	hero.equip_weapon("bow")
	var bow_effects := hero.equipped_weapon_effects()
	check(is_equal_approx(float(bow_effects.damage), 1.0) and int(bow_effects.pierce) == 0 and hero.weapon_level == 1 and hero.weapon_tier_damage == 0.0, "Switching to bow removes pistol-specific effects and tier")
	hero.equip_weapon("pistol")
	check(is_equal_approx(float(hero.equipped_weapon_effects().damage), 1.18) and int(hero.equipped_weapon_effects().pierce) == 1 and hero.weapon_level == 2, "Returning to pistol restores its own effects and tier")
	hero.apply_passive("pistol_storm")
	hero.apply_passive("bow_rain")
	hero.equip_weapon("bow")
	hero.shots_fired = 5
	hero.weapon_shots["bow"] = 0
	clear_projectiles(game)
	hero.fire(null)
	check(projectiles(game).size() == 1, "Old pistol shots cannot trigger either weapon's capstone on the first bow shot")
	hero.weapon_shots["bow"] = 5
	clear_projectiles(game)
	hero.fire(null)
	check(projectiles(game).size() == 4, "Bow capstone triggers on its own sixth shot")
	hero.weapon_shots["pistol"] = 5
	hero.equip_weapon("pistol")
	clear_projectiles(game)
	hero.fire(null)
	check(projectiles(game).size() == 4, "Pistol capstone retains its own shot count after switching")
	var sniper_pool: Array[String]
	hero.equip_weapon("sniper")
	sniper_pool = ArenaUpgrades.build_pool(hero, "level")
	check("sniper_scope" in sniper_pool and "pistol_caliber" not in sniper_pool, "Weapon cards follow current equipment")
	var damage_before := hero.damage_mult
	hero.apply_passive("power")
	check(is_equal_approx(hero.damage_mult - damage_before, 0.15) and "+15%" in ArenaUpgrades.DEFS.power.desc, "Power card description matches its damage bonus")
	var speed_before := hero.attack_speed_mult
	hero.apply_passive("rapid")
	check(is_equal_approx(hero.attack_speed_mult - speed_before, 0.12) and "+12%" in ArenaUpgrades.DEFS.rapid.desc, "Rapid card description matches its speed bonus")
	var health_before := hero.max_health
	hero.apply_passive("vitality")
	check(is_equal_approx(hero.max_health - health_before, 30.0) and "+30" in ArenaUpgrades.DEFS.vitality.desc, "Vitality card description matches its health bonus")
	clear_projectiles(game)
	game.queue_free()
	await process_frame
	await create_timer(1.0, true, false, true).timeout
	print("ARENA WEAPON CHECKS: %d, FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
