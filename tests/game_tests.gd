extends SceneTree

var game: Node2D
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func fresh() -> void:
	paused = false
	if is_instance_valid(game):
		game.queue_free()
		await process_frame
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.sound.enabled = false

func _run() -> void:
	await fresh()
	check(game.wave == 0 and game.wave_clock == Rules.FIRST_WAVE, "First wave counts down from ninety seconds")
	var money: int = game.gold
	game.early_wave()
	check(game.hud.modal_kind == "confirm" and not game.wave_active and paused, "First wave requires a paused confirmation")
	game.hud.close_modal()
	game.start_wave()
	check(game.wave_active and game.gold == money, "Starting early never grants money")
	game.start_wave()
	check(game.wave == 1, "Cannot overlap active waves")
	check(not Rules.TOWERS.has("mine"), "Income building is removed")
	await fresh()
	game.wave_clock = 0.3
	game._physics_process(0.5)
	check(game.wave == 1 and game.wave_active, "First wave starts by itself when its countdown expires")
	await fresh()
	game.choose_build("bolt")
	check(game.try_build(Rules.CORE) == null, "Build is restricted to designated sites")
	check(game.gold == 180, "Failed build is atomic")
	var tower: Tower = game.try_build(Rules.BUILD_SITES[0])
	check(tower != null and game.gold == 80, "Site construction spends correct gold")
	game.choose_build("bolt")
	check(game.try_build(Rules.BUILD_SITES[0]) == null, "Cannot stack towers")
	game.hero.position = Rules.CAMPS[0]
	check(game.try_build(Rules.BUILD_SITES[1]) == null, "Construction requires hero in base")
	game.hero.position = Rules.CORE + Vector2(120, 112)
	var path: PackedVector2Array = game.navigation_path(game.hero.position, Rules.CORE - Vector2(100, 180))
	check(not path.is_empty(), "Click navigation finds a path around castle")
	for point in path:
		check(not Rect2(Rules.CORE + Vector2(-85, -125), Vector2(170, 80)).has_point(point), "Navigation avoids castle collision")
	var leading: Enemy = game.spawn_enemy("torch", 0, -1, Vector2(1300, 660), 999)
	var trailing: Enemy = game.spawn_enemy("torch", 0, -1, Vector2(1184, 576), 999)
	check(game.leading_enemy(tower.position, 400) == leading, "Towers prioritize enemies closest to core")
	game.selected = tower
	game.gold = 300
	game.upgrade_selected()
	check(tower.level == 2, "Tower can be upgraded with earned gold")
	var invested := tower.invested
	var gold_before: int = game.gold
	game.sell_selected()
	check(game.gold == gold_before + int(invested * 0.7), "Selling refunds only part of investment")
	check(game.towers.is_empty(), "Sold tower frees construction site")
	await fresh()
	check(game.unlocked_tower_kinds() == ["bolt"], "Only bolt towers are available before exploration")
	check(game.tower_limit() == 4, "Start line is limited to four towers")
	game.gold = 1000
	game.choose_build("cannon")
	check(game.try_build(Rules.BUILD_SITES[0]) == null and game.towers.is_empty(), "Cannon requires the first camp")
	for index in range(4):
		game.choose_build("bolt")
		game.try_build(Rules.BUILD_SITES[index])
	check(game.towers.size() == 4, "Four towers fit the starting line")
	game.choose_build("bolt")
	check(game.try_build(Rules.BUILD_SITES[4]) == null, "Tower slot limit blocks a fifth tower")
	game.camps[0].cleared = true
	check(game.tower_limit() == 6 and "cannon" in game.unlocked_tower_kinds(), "First camp adds two slots and unlocks cannon")
	await fresh()
	game.choose_build("bolt")
	tower = game.try_build(Rules.BUILD_SITES[0])
	game.hero.position = tower.position + Vector2(150, 0)
	var original_shield: float = game.hero.shield
	var bullet: Projectile = game.enemy_bullet(tower.center() - Vector2(10, 0), Vector2.RIGHT, 15, 300)
	bullet._physics_process(0.1)
	check(game.hero.shield == original_shield and game.towers.has(tower), "Enemy projectile crosses a tower without damaging it")
	game._resolve_hazard({"point": tower.center(), "radius": 75, "damage": 32})
	check(game.towers.has(tower) and tower.level == 1, "Boss ground attack cannot destroy an attack tower")
	game.hero.invulnerability = 0
	game._resolve_hazard({"point": game.hero.center(), "radius": 50, "damage": 32})
	check(game.hero.shield == original_shield - 32, "Hazards damage hero shield")
	check(game.core_health == game.core_max_health, "Hero-targeted hazards never damage core")
	game.hero.invulnerability = 0
	game.hero.take_damage(40)
	check(game.hero.shield == 0 and game.hero.health == 118, "Shield absorbs damage before health")
	game.hero.since_damage = 4
	game.hero._physics_process(0.5)
	check(game.hero.shield > 0, "Shield regenerates out of combat")
	game.hero.use_skill()
	check(game.hero.skill_cooldown > 0 and game.hero.skill_time > 0 and game.hero.dash_time == 0, "Knight active enables dual wield without universal dash")
	check(not game.hero.use_skill(), "Active respects its cooldown")
	await fresh()
	game.gain_experience(12)
	check(game.level == 2 and game.pending_rewards == 0 and game.hud.modal_kind.is_empty(), "Combat XP levels up without handing out a passive")
	game.camps[0].cleared = true
	game.hero.position = Rules.CAMPS[0]
	game.interact()
	check(game.pending_rewards == 1, "Clearing a camp grants one route choice")
	game._physics_process(0.01)
	check(game.hud.modal_kind == "reward" and paused, "Camp reward opens a paused choice")
	check(game.offered.size() == 2 and game.hud.reward_buttons.size() == 2, "Route choice offers exactly two exclusive cards")
	check(game.hud.atlas != null, "Passive illustrations are real imported images")
	var choice: String = game.offered[0]
	game.claim_relic("invalid")
	check(game.rank(choice) == 0 and paused, "Unsolicited reward is rejected")
	game.hud.reward_buttons[0].pressed.emit()
	check(game.rank(choice) == 1, "Card click applies the route")
	check(game.pending_rewards == 0, "Route choice is consumed")
	check(game.pending_group() == "lead", "Chosen route locks its group and advances to the next")
	if game.hud.modal_kind == "reward": game.hud.close_modal()
	game.pending_rewards = 0
	await fresh()
	var camp_gold_before: int = game.gold
	game.camps[0].cleared = true
	game.hero.position = Rules.CAMPS[0]
	game.interact()
	check(game.camps[0].chest_claimed and game.hero.weapon_id == "scatter" and game.hero.weapon_level == 1, "Camp treasure equips its weapon directly, with no warehouse")
	check(game.gold == camp_gold_before + Rules.CAMP_GOLD[0], "Camp treasure pays its gold exactly once")
	await fresh()
	game.hero.position = game.exploration_target(0) + Vector2(-120, 100)
	game._physics_process(0.01)
	check(game.camps[0].stage == 1 and game.enemies.size() == 4, "Approaching the camp starts one bounded encounter")
	check(game.camps[1].stage == 0, "Second camp waits until first wave is cleared")
	for enemy in game.enemies.duplicate(): enemy.take_damage(999, true, "hero")
	game._physics_process(0.01)
	check(game.camps[0].cleared and game.camps[0].progress == 1 and not game.camps[0].encounter_active, "One cleared node completes the camp")
	game.hero.position = Rules.CAMPS[0]
	game.interact()
	check(game.camps[0].chest_claimed and not game.camps[0].npc_rescued, "Cleared camp grants treasure and no NPC shop")
	var hero_visual: ActorVisual = game.hero.visual
	hero_visual.animated_frames.clear()
	for index in range(12): hero_visual.advance(0.05, Vector2(250, 0), Vector2.RIGHT)
	check(hero_visual.animated_frames.size() >= 6, "Walking changes actual full-body atlas poses")
	hero_visual.attack(Vector2.DOWN, 0.5)
	for index in range(10): hero_visual.advance(0.05, Vector2.ZERO, Vector2.DOWN)
	check(hero_visual.weapon_rig != null and hero_visual.family == "player", "Every hero weapon has an animated hand and recoil rig")
	await fresh()
	game.hero.position = Rules.CORE + Vector2(170, 170)
	game.hero.equip_weapon("sword", 1)
	var front: Enemy = game.spawn_enemy("torch", -1, -1, game.hero.position + Vector2(80, 0), 60)
	var behind: Enemy = game.spawn_enemy("torch", -1, -1, game.hero.position - Vector2(80, 0), 60)
	game.hero.aim = Vector2.RIGHT
	game.hero.combo = 3
	var hostile: Projectile = game.enemy_bullet(game.hero.center() + Vector2(40, 0), Vector2.LEFT, 10, 100)
	game.hero._release_attack()
	check(front.dead and not behind.dead, "Sword finisher damages forward cone rather than enemies behind hero")
	check(hostile.is_queued_for_deletion(), "Sword sweep clears bullets in front of hero")
	game.hero.equip_weapon("scatter", 1)
	await process_frame
	game.hero._release_attack()
	check(game.projectiles.get_child_count() == 5, "Base staff releases five star projectiles")
	for projectile in game.projectiles.get_children(): projectile.queue_free()
	await process_frame
	game.hero.equip_weapon("scatter", 3)
	game.hero._release_attack()
	check(game.projectiles.get_child_count() == 7, "Staff upgrade changes projectile mechanism rather than only damage")
	for projectile in game.projectiles.get_children(): projectile.queue_free()
	await process_frame
	game.hero.equip_weapon("storm", 3)
	game.hero._release_attack()
	var storm: Projectile = game.projectiles.get_child(0)
	check(storm.pierce == 1 and storm.chain_count == 2, "Thunder weapon combines penetration and chained targets")
	game.hero.health = 1
	game.hero.shield = 0
	game.hero.invulnerability = 0
	game.hero.take_damage(20)
	check(game.hero.respawn_time > 0 and game.core_health == 220, "Hero death costs core health and starts respawn")
	game.hero._physics_process(4.1)
	check(game.hero.health == game.hero.max_health and game.hero.shield == game.hero.max_shield, "Respawn restores hero health and shield")
	game.damage_core(999)
	check(game.hud.modal_kind == "result" and paused and not game.running, "Core destruction creates a stable paused defeat state")
	paused = false
	print("CHECKS: %d, FAILURES: %d" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
