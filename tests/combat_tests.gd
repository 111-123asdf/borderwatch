extends SceneTree

var game: Node2D
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("FAIL: " + message)

func clear_projectiles() -> void:
	for bullet in game.projectiles.get_children(): bullet.queue_free()
	await process_frame

func reset_field() -> void:
	for enemy in game.enemies.duplicate():
		game.enemies.erase(enemy)
		enemy.queue_free()
	await clear_projectiles()
	game.hero.position = Vector2(3300, 950)
	game.hero.navigation.clear()
	game.hero.velocity = Vector2.ZERO

func shoot(key: String, level := 1) -> void:
	await clear_projectiles()
	game.hero.equip_weapon(key, level)
	game.hero.attack_dual = false
	game.hero.aim = Vector2.RIGHT
	game.hero._release_attack()

func _run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.sound.enabled = false
	game.set_physics_process(false)
	game.hero.set_physics_process(false)
	await reset_field()
	var hero: Hero = game.hero
	var near: Enemy = game.spawn_enemy("torch", -1, -1, hero.position + Vector2(110, 0), 999)
	var far: Enemy = game.spawn_enemy("torch", -1, -1, hero.position + Vector2(0, 200), 999)
	near.set_physics_process(false)
	far.set_physics_process(false)
	check(hero.auto_target() == near, "Automatic targeting chooses nearest live visible enemy")
	var original := hero.position
	hero.shot_cooldown = 0
	hero.fire(hero.position - Vector2(900, 0))
	check(hero.aim.x > 0.99 and hero.position == original and hero.navigation.is_empty(), "Mouse position does not aim or auto chase")
	near.dead = true
	check(hero.auto_target() == far, "A dead target is immediately replaced")
	await reset_field()
	var cover: Rect2 = game.world.cover_rects[1]
	hero.position = cover.position + Vector2(-70, 50)
	var blocked: Enemy = game.spawn_enemy("torch", -1, -1, hero.position + Vector2(200, 0), 999)
	var visible_enemy: Enemy = game.spawn_enemy("torch", -1, -1, hero.position + Vector2(0, 240), 999)
	check(not game.line_of_sight(hero.center(), blocked.center()), "Cover blocks targeting rays")
	check(hero.auto_target() == visible_enemy, "Visible target wins over a closer occluded enemy")
	var route: PackedVector2Array = game.navigation_path(cover.get_center() - Vector2(160, 0), cover.get_center() + Vector2(160, 0))
	check(not route.is_empty() and Array(route).all(func(point): return not cover.has_point(point)), "Movement routes around physical cover")
	await reset_field()
	check(not InputMap.has_action("dash"), "There is no universal dash action")
	check(Rules.HEROES.size() == 5 and Rules.weapon_keys().size() == 11, "Five heroes and eleven weapon mechanisms are available")
	for key in Rules.HEROES:
		hero.configure(key)
		hero.invulnerability = 0
		hero.velocity = Vector2.LEFT * 200
		hero.facing = Vector2.RIGHT
		check(hero.max_health == Rules.HEROES[key].health and hero.max_energy == Rules.HEROES[key].energy, key + " has its own health and energy")
		check(hero.use_skill() and not hero.use_skill(), key + " active respects cooldown")
		check(is_equal_approx(hero.skill_cooldown, Rules.HEROES[key].cooldown), key + " uses its stated cooldown")
		if key == "ranger":
			check(hero.dash_time > 0 and hero.invulnerability > 0 and hero.dash_direction.x < 0, "Only ranger rolls with movement direction and invulnerability")
		elif key == "vanguard":
			check(hero.dash_time == 0 and hero.invulnerability > 0, "Vanguard pulse grants brief protection without becoming a roll")
		else:
			check(hero.dash_time == 0 and hero.invulnerability == 0, key + " cannot dash or gain generic invulnerability")
		hero.visual.animated_frames.clear()
		for step in range(20): hero.visual.advance(0.05, Vector2.RIGHT * 250, Vector2.RIGHT)
		var row: int = 1 if Rules.HEROES[key].color == "Yellow" else (2 if Rules.HEROES[key].color == "Purple" else 0)
		check(hero.visual.animated_frames.size() >= 6 and hero.visual.animated_frames.all(func(frame): return frame / 6 == row), key + " runs through its own atlas row")
	hero.equip_weapon("sniper", 2)
	hero.configure("mage")
	check(hero.weapon_id == "sniper" and hero.weapon_level == 2, "Changing hero never changes the equipped weapon")
	hero.configure("knight")
	hero.equip_weapon("sniper", 1)
	hero.energy = 100
	hero.use_skill()
	hero.shot_cooldown = 0
	check(hero.fire(), "Knight can shoot during dual wield")
	hero._release_attack()
	check(game.projectiles.get_child_count() == 2 and hero.energy == 88, "Knight duplicates current weapon and pays energy twice")
	hero.attack_pending = false
	hero._physics_process(5.1)
	check(hero.skill_time == 0 and not hero.visual.dual_active, "Dual wield ends after its duration")
	await clear_projectiles()
	hero.shot_cooldown = 0
	hero.energy = 0
	check(not hero.fire(), "Energy weapon cannot fire when empty")
	hero.equip_weapon("pistol", 1)
	hero.shot_cooldown = 0
	check(hero.fire() and hero.energy == 0, "Zero-cost sidearm works without energy")
	hero.attack_pending = false
	hero._physics_process(1)
	check(hero.energy >= 3, "Energy regenerates without collecting a consumable")
	await clear_projectiles()
	hero.configure("mage")
	hero.energy = 20
	hero.invulnerability = 0
	hero.use_skill()
	var bullet: Projectile = game.enemy_bullet(hero.center() + Vector2(45, 0), Vector2.LEFT, 14, 180)
	var shield_before := hero.shield
	bullet._physics_process(0.01)
	check(bullet.is_queued_for_deletion() and hero.energy == 24 and hero.shield == shield_before, "Mage barrier converts nearby enemy bullets into energy")
	game._resolve_hazard({"point": hero.center(), "radius": 60, "damage": 20})
	check(hero.shield == shield_before - 20, "Mage barrier does not negate ground hazards")
	hero.configure("engineer")
	hero.energy = 0
	hero.shield = 0
	check(hero.use_skill() and hero.energy == 40 and hero.shield == 28 and hero.skill_time > 0, "Engineer overcharge restores resources and starts its attack-speed window")
	hero.configure("vanguard")
	hero.invulnerability = 0
	var pulse_target: Enemy = game.spawn_enemy("torch", -1, -1, hero.position + Vector2(100, 0), 999)
	var pulse_bullet: Projectile = game.enemy_bullet(hero.center() + Vector2(50, 0), Vector2.LEFT, 10, 180)
	check(hero.use_skill() and pulse_target.health < 999 and pulse_target.knockback.length() > 0 and pulse_bullet.is_queued_for_deletion(), "Vanguard nova damages and knocks enemies back while clearing bullets")
	hero.configure("knight")
	await shoot("scatter")
	check(game.projectiles.get_child_count() == 5, "Staff releases a five-way fan")
	await shoot("scatter", 3)
	check(game.projectiles.get_child_count() == 7, "Staff evolution widens fan to seven")
	await shoot("sniper")
	check(game.projectiles.get_child(0).pierce == 3 and game.projectiles.get_child(0).speed == 1250, "Sniper has high velocity and three penetrations")
	await shoot("rocket", 3)
	var rocket: Projectile = game.projectiles.get_child(0)
	check(rocket.splash >= 105 and rocket.speed < 500, "Rocket uses slower explosive projectile")
	var victim: Enemy = game.spawn_enemy("torch", -1, -1, hero.position + Vector2(170, 0), 999)
	rocket.position = victim.center()
	hero.equip_weapon("pistol", 1)
	rocket._impact(victim)
	check(game.projectiles.get_child_count() == 4 and victim.health < 999, "Evolved rocket keeps its upgrade after switching weapons mid-flight")
	await shoot("boomerang", 3)
	check(game.projectiles.get_child_count() == 2, "Evolved throwing weapon emits two wheels")
	check(game.projectiles.get_child(0).damage >= Rules.weapon("boomerang").damage, "Evolved primary wheels retain full damage, not side-shot damage")
	var wheel: Projectile = game.projectiles.get_child(0)
	wheel.position = hero.center() + Vector2(100, 0)
	wheel.struck.append(123)
	wheel.clock = 0.57
	wheel._physics_process(0.02)
	check(wheel.returning and not wheel.struck.has(123) and wheel.direction.x < 0, "Returning wheel homes back and may hit enemies on both legs")
	bullet = game.enemy_bullet(wheel.position, Vector2.UP, 10, 180)
	wheel._physics_process(0.001)
	check(bullet.is_queued_for_deletion(), "Wheel contact clears hostile bullets")
	await reset_field()
	var front: Enemy = game.spawn_enemy("torch", -1, -1, hero.position + Vector2(170, 0), 999)
	var behind: Enemy = game.spawn_enemy("torch", -1, -1, hero.position - Vector2(80, 0), 999)
	bullet = game.enemy_bullet(hero.center() + Vector2(155, 0), Vector2.LEFT, 10, 180)
	hero.equip_weapon("halberd", 1)
	hero.aim = Vector2.RIGHT
	hero._release_attack()
	check(front.health < 999 and behind.health == 999 and bullet.is_queued_for_deletion(), "Long blade reaches farther and clears only its forward cone")
	await reset_field()
	front = game.spawn_enemy("torch", -1, -1, hero.position + Vector2(200, 0), 999)
	await shoot("laser", 3)
	check(front.health < 999 and game.projectiles.get_child_count() == 0 and not game.effects.beams.is_empty(), "Laser applies instant beam damage rather than another projectile")
	hero.equip_weapon("gatling", 3)
	var intervals: Array[float] = []
	for step in range(5):
		hero.shot_cooldown = 0
		hero.fire()
		intervals.append(hero.shot_cooldown)
	check(intervals.front() > intervals.back() * 2 and is_equal_approx(intervals.back(), 0.065), "Gatling accelerates from spin-up into rapid fire")
	await reset_field()
	var boss: Enemy = game.spawn_enemy("boss", -1, -1, hero.position + Vector2(-300, -100), 9999)
	boss.set_physics_process(false)
	boss.emergence = 0
	boss.attack_cooldown = 999
	boss._boss_attack()
	check(game.projectiles.get_child_count() == 14, "Boss ring deliberately leaves two gaps rather than a sealed sixteen-shot ring")
	var angles: Array[float] = []
	for shot in game.projectiles.get_children(): angles.append(fposmod(shot.direction.angle(), TAU))
	angles.sort()
	var largest_gap: float = angles.front() + TAU - angles.back()
	for index in range(1, angles.size()): largest_gap = maxf(largest_gap, angles[index] - angles[index - 1])
	check(largest_gap > 0.77, "Ring contains a readable forty-five-degree escape gap")
	await clear_projectiles()
	boss._boss_attack()
	check(boss.salvo_remaining == 3 and game.projectiles.get_child_count() == 0, "Boss switches to three timed fan salvos")
	boss._physics_process(0.01)
	check(game.projectiles.get_child_count() == 5, "Fan begins with five projectiles")
	boss._physics_process(0.12)
	check(game.projectiles.get_child_count() == 5, "Fan salvos have a real movement interval")
	boss._physics_process(0.12)
	boss._physics_process(0.23)
	check(game.projectiles.get_child_count() == 15 and boss.salvo_remaining == 0, "Three distinct fan beats finish without continuous random spam")
	await clear_projectiles()
	boss._boss_attack()
	check(game.projectiles.get_children().any(func(shot): return shot.turn_speed != 0), "Third boss pattern uses curved red projectiles")
	check(game.world.cover_rects.size() == 19 and Rules.WORLD_SIZE.x >= 6000, "Expanded world contains eighteen encounter covers plus castle")
	await reset_field()
	var shielded: Enemy = game.spawn_enemy("shielded", -1, -1, hero.position + Vector2(300, 0), 1000)
	shielded.set_physics_process(false)
	shielded.take_damage(100, false, "tower")
	check(is_equal_approx(shielded.health, 980.0), "Towers only chip shielded elites")
	shielded.take_damage(100, true, "hero")
	check(is_equal_approx(shielded.health, 880.0), "Hero damage is full against shielded elites")
	var armored: Enemy = game.spawn_enemy("armored", -1, -1, hero.position + Vector2(-300, 0), 1000)
	armored.set_physics_process(false)
	armored.take_damage(100, false, "hero")
	check(is_equal_approx(armored.health, 1000.0), "Armored elites ignore hero attacks")
	armored.take_damage(100, false, "bolt")
	check(is_equal_approx(armored.health, 900.0), "Tower damage is full against armored elites")
	await reset_field()
	game.hero.position = Rules.CORE + Vector2(120, 112)
	game.gold = 500
	game.choose_build("bolt")
	var aura_tower: Tower = game.try_build(Rules.BUILD_SITES[0])
	aura_tower.in_aura = false
	aura_tower.shoot(Vector2.RIGHT)
	var plain_damage: float = game.projectiles.get_child(0).damage
	await clear_projectiles()
	aura_tower.in_aura = true
	aura_tower.shoot(Vector2.RIGHT)
	var aura_damage: float = game.projectiles.get_child(0).damage
	check(aura_damage > plain_damage, "Command aura increases tower damage")
	await clear_projectiles()
	game.core_health = 200
	game.hero.position = Rules.CORE
	game._physics_process(1.0)
	check(game.core_health == 200, "Core damage is permanent; there is no passive repair")
	var saved_wave: int = game.wave
	game.wave = 2
	check("铁甲" in game.wave_preview_text(), "Wave preview names the armored problem before wave three")
	game.wave = saved_wave
	await reset_field()
	game.completed_waves = 3
	for region in range(3):
		hero.position = game.exploration_target(region)
		game._update_camps(0)
		check(game.camps[region].encounter_active and game.enemies.any(func(enemy): return enemy.camp == region), "Region %d has a gated encounter" % region)
		for enemy in game.enemies.duplicate(): enemy.take_damage(9999, true, "hero")
		game._update_camps(0)
		check(game.camps[region].cleared and game.camps[region].progress == 1, "Region %d clears after its single node" % region)
		hero.position = Rules.CAMPS[region]
		game.interact()
		check(game.camps[region].chest_claimed, "Region %d treasure can be claimed" % region)
		game.shortcut_cooldown = 0
		game.interact()
		check(hero.position.distance_to(Rules.CORE) < 300, "Region %d unlocks return shortcut" % region)
	paused = false
	var threat := Threat.new()
	check(is_equal_approx(threat.scale_for(1), 1.0), "Threat: wave one carries no extra pressure")
	check(threat.enemy_health(6, 100.0) > threat.enemy_health(3, 100.0), "Threat: pressure grows with wave number")
	threat.note_camp_cleared()
	check(threat.scale_for(1) > 1.0, "Threat: clearing a camp adds pressure")
	check(is_equal_approx(game.threat.enemy_health(6, 100.0), 100.0 * game.threat.scale_for(6)), "Threat: roster health derives from the shared pressure")
	print("COMBAT CHECKS: %d, FAILURES: %d" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
