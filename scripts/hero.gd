class_name Hero
extends CharacterBody2D

var game: Node2D
var visual: ActorVisual
var class_id := "knight"
var max_health := 120.0
var health := 120.0
var max_shield := 70.0
var shield := 70.0
var max_energy := 100.0
var energy := 100.0
var since_damage := 10.0
var weapon_id := "pistol"
var weapon_level := 1
var weapon_slots: Array[Dictionary] = [
	{"id": "pistol", "level": 1},
	{"id": "sword", "level": 1},
]
var active_weapon_slot := 0
var shot_cooldown := 0.0
var dash_cooldown := 0.0
var skill_cooldown := 0.0
var skill_level := 1
var skill_time := 0.0
var dash_time := 0.0
var dash_direction := Vector2.RIGHT
var invulnerability := 0.0
var recall_time := 0.0
var recall_cooldown := 0.0
var respawn_time := 0.0
var animation_time := 0.0
var facing := Vector2.RIGHT
var aim := Vector2.RIGHT
var attack_delay := 0.0
var attack_pending := false
var attack_weapon := ""
var attack_level := 1
var attack_dual := false
var combo := 0
var combo_timeout := 0.0
var shot_count := 0
var navigation := PackedVector2Array()
var navigation_target := Vector2.ZERO
var step_clock := 0.0
var trigger_heat := 0.0
var trigger_age := 0.0
var dry_clock := 0.0
var locked: Enemy

func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13
	collision.shape = circle
	add_child(collision)
	visual = ActorVisual.new()
	add_child(visual)
	configure("knight")

func configure(key: String) -> void:
	if not Rules.HEROES.has(key): return
	class_id = key
	var definition: Dictionary = Rules.HEROES[key]
	var global_bonus := {"health": 0.0, "shield": 0.0, "energy": 0.0, "damage": 0.0}
	if game != null and game.progression != null: global_bonus = game.progression.bonuses(key)
	max_health = definition.health + float(global_bonus.health)
	max_shield = definition.shield + float(global_bonus.shield)
	max_energy = definition.energy + float(global_bonus.energy)
	health = max_health
	shield = max_shield
	energy = max_energy
	skill_time = 0
	skill_cooldown = 0
	dash_time = 0
	dash_cooldown = 0
	_apply_weapon_slot()

func center() -> Vector2:
	return position + Vector2(0, -27)

func equip_weapon(key: String, upgrade_level: int) -> void:
	if key not in Rules.weapon_keys(): return
	weapon_slots[active_weapon_slot] = {"id": key, "level": clampi(upgrade_level, 1, 3)}
	_apply_weapon_slot()

func acquire_weapon(key: String, upgrade_level: int) -> void:
	if key not in Rules.weapon_keys(): return
	for index in range(weapon_slots.size()):
		if weapon_slots[index].id == key:
			weapon_slots[index].level = maxi(int(weapon_slots[index].level), clampi(upgrade_level, 1, 3))
			if index == active_weapon_slot: _apply_weapon_slot()
			else: switch_weapon(index)
			return
	var replacement := 1 - active_weapon_slot
	weapon_slots[replacement] = {"id": key, "level": clampi(upgrade_level, 1, 3)}
	switch_weapon(replacement)

func switch_weapon(slot := -1) -> bool:
	if respawn_time > 0: return false
	var target := 1 - active_weapon_slot if slot < 0 else clampi(slot, 0, weapon_slots.size() - 1)
	if target == active_weapon_slot: return false
	active_weapon_slot = target
	_apply_weapon_slot()
	if game != null and game.running:
		game.toast("切换武器 · %s +%d" % [Rules.weapon(weapon_id).name, weapon_level], 1.5)
	return true

func _apply_weapon_slot() -> void:
	weapon_id = String(weapon_slots[active_weapon_slot].id)
	weapon_level = int(weapon_slots[active_weapon_slot].level)
	attack_pending = false
	attack_delay = 0
	shot_cooldown = 0.16
	trigger_heat = 0
	if visual == null: return
	visual.setup("player", Rules.HEROES[class_id].color, 0.9, true)
	visual.held_weapon = weapon_id
	visual.hero_identity = class_id

func damage_scale() -> float:
	var global_damage := 0.0 if game.progression == null else float(game.progression.bonuses(class_id).damage)
	return game.hero_damage_scale() * (1 + global_damage) * (1 + (weapon_level - 1) * 0.22) * (1 + (game.level - 1) * 0.03)

func upgrade_price() -> int:
	return 40 + weapon_level * 30

func command_move(destination: Vector2) -> void:
	if respawn_time > 0: return
	navigation = game.navigation_path(position, destination)
	navigation_target = destination
	recall_time = 0
	game.effects.rings.append({"point": destination, "radius": 25.0, "color": Color("c9ecd1"), "life": 0.6, "total": 0.6})

func auto_target() -> Enemy:
	var reach: float = Rules.weapon(weapon_id).reach
	locked = game.nearest_target(center(), reach)
	if locked != null:
		var offset := locked.center() - center()
		var speed := 1000.0 if weapon_id == "sniper" else 780.0
		if weapon_id not in ["sword", "halberd", "laser"]:
			offset += locked.motion * minf(0.35, offset.length() / speed)
		aim = offset.normalized()
		facing = aim
	return locked

func _physics_process(delta: float) -> void:
	if not game.running: return
	animation_time += delta
	shot_cooldown = maxf(0, shot_cooldown - delta)
	skill_cooldown = maxf(0, skill_cooldown - delta)
	dash_cooldown = skill_cooldown if class_id == "ranger" else 0.0
	skill_time = maxf(0, skill_time - delta)
	invulnerability = maxf(0, invulnerability - delta)
	recall_cooldown = maxf(0, recall_cooldown - delta)
	combo_timeout = maxf(0, combo_timeout - delta)
	dry_clock = maxf(0, dry_clock - delta)
	trigger_age += delta
	if trigger_age > 0.15: trigger_heat = maxf(0, trigger_heat - delta * 3)
	energy = minf(max_energy, energy + float(Rules.HEROES[class_id].regen) * delta)
	since_damage += delta
	if since_damage > 3.2: shield = minf(max_shield, shield + delta * 16)
	if respawn_time > 0:
		respawn_time -= delta
		if respawn_time <= 0:
			position = Rules.CORE + Vector2(120, 95)
			health = max_health
			shield = max_shield
			energy = max_energy
			visual.death_phase = -1
			visual.sprite.modulate = Color.WHITE
			invulnerability = 2
		else: visual.advance(delta, Vector2.ZERO, facing)
		return
	var movement := Input.get_vector("left", "right", "up", "down")
	if movement.length() > 0.1:
		navigation.clear()
		game.hero_selected = false
	elif not navigation.is_empty():
		while not navigation.is_empty() and position.distance_to(navigation[0]) < 12: navigation.remove_at(0)
		if not navigation.is_empty(): movement = (navigation[0] - position).normalized()
	if movement.length() > 0.1 and not attack_pending: facing = movement.normalized()
	auto_target()
	if Input.is_action_just_pressed("skill"): use_skill()
	if recall_time > 0:
		if movement.length() > 0.1 or Input.is_action_pressed("shoot"): recall_time = 0
		else:
			recall_time -= delta
			if recall_time <= 0:
				position = Rules.CORE + Vector2(120, 95)
				recall_cooldown = 28
				navigation.clear()
				game.burst(center(), Color("89e7df"), 20)
	var speed: float = Rules.HEROES[class_id].speed * (1 + game.rank("haste") * 0.06)
	if attack_pending and weapon_id in ["sword", "halberd"]: speed *= 0.8
	if dash_time > 0:
		dash_time -= delta
		velocity = dash_direction * 650
		visual.rotation = sin((1 - dash_time / 0.22) * PI) * 0.3 * signf(dash_direction.x + 0.01)
		game.spark(center(), -dash_direction * 45, Color("b3eadf"), 0.18, 5)
	else:
		velocity = movement * speed
		visual.rotation = lerpf(visual.rotation, 0, minf(1, delta * 20))
	move_and_slide()
	position = position.clamp(Vector2(42, 65), Rules.WORLD_SIZE - Vector2(42, 42))
	step_clock -= delta
	if velocity.length() > 50 and step_clock <= 0:
		step_clock = 0.15
		game.spark(position + Vector2(randf_range(-6, 6), 3), -velocity * 0.1 + Vector2(0, -15), Color(0.75, 0.73, 0.55, 0.55), 0.24, 3)
	if class_id == "mage" and skill_time > 0:
		for bullet in game.projectiles.get_children():
			if bullet is Projectile and bullet.hostile and not bullet.is_queued_for_deletion() and bullet.position.distance_to(center()) < 58:
				energy = minf(max_energy, energy + 3 + skill_level)
				game.burst(bullet.position, Color("b3dced"), 3)
				bullet.queue_free()
	if attack_pending:
		attack_delay -= delta
		if attack_delay <= 0:
			attack_pending = false
			_release_attack()
	if Input.is_action_pressed("shoot") and not game.block_pointer and not game.hud.pointer_over_ui() and dash_time <= 0: fire()
	visual.dual_active = class_id == "knight" and skill_time > 0
	visual.advance(delta, velocity, aim if locked != null or attack_pending else facing)
	modulate.a = 0.7 if invulnerability > 0 and int(animation_time * 18) % 2 == 0 else 1.0
	queue_redraw()

func fire(_ignored_mouse := Vector2.ZERO) -> bool:
	trigger_age = 0
	if shot_cooldown > 0 or respawn_time > 0 or dash_time > 0: return false
	auto_target()
	if locked == null: aim = facing
	var definition := Rules.weapon(weapon_id)
	var cost: float = definition.energy
	if energy < cost:
		if dry_clock <= 0:
			game.toast("能量不足 · Tab换零耗能武器，或稍待恢复", 2)
			dry_clock = 2
		return false
	energy -= cost
	attack_dual = class_id == "knight" and skill_time > 0 and energy >= cost
	if attack_dual: energy -= cost
	var interval: float = definition.interval / (1 + game.rank("haste") * 0.15)
	if class_id == "engineer" and skill_time > 0: interval /= 1.35
	if weapon_id == "gatling":
		trigger_heat = minf(1, trigger_heat + 0.24)
		interval *= lerpf(3.5, 1, trigger_heat)
	shot_cooldown = interval
	if combo_timeout <= 0: combo = 0
	combo = (combo % 3) + 1
	combo_timeout = 1.0
	attack_weapon = weapon_id
	attack_level = weapon_level
	attack_delay = 0.12 if weapon_id in ["sword", "halberd"] else minf(0.075, interval * 0.32)
	attack_pending = true
	visual.attack(aim, maxf(0.12, interval))
	return true

func _release_attack() -> void:
	shot_count += 1
	var damage: float = Rules.weapon(weapon_id).damage * damage_scale()
	for hand in range(2 if attack_dual else 1):
		var origin := center() + aim.orthogonal() * (-9 if hand == 0 else 11)
		_attack(origin, damage)
	if attack_dual: game.spark(center() - aim.orthogonal() * 20, -aim * 20, Color("ffd89b"), 0.12, 6)

func _attack(origin: Vector2, damage: float) -> void:
	if weapon_id in ["sword", "halberd"]:
		var radius: float = Rules.weapon(weapon_id).reach * (1 + game.rank("pierce") * 0.15)
		var landed := false
		for enemy in game.enemies.duplicate():
			if not is_instance_valid(enemy) or enemy.dead or not game.line_of_sight(center(), enemy.center()): continue
			var offset: Vector2 = enemy.center() - center()
			if offset.length() < radius + enemy.radius and (offset.length() < 36 or absf(aim.angle_to(offset)) < 1.25):
				enemy.take_damage(damage * (1.45 if combo == 3 else 1), true, "hero")
				enemy.knockback += aim * (125 if combo == 3 else 70)
				landed = true
		game.sweep_bullets(center(), radius, aim)
		game.effects.slashes.append({"point": origin, "angle": aim.angle(), "radius": radius * 0.9, "life": 0.18, "total": 0.18, "color": Rules.weapon(weapon_id).color})
		if landed:
			game.shake(0.12 if combo < 3 else 0.2)
			game.sound.play("hit", 7)
		if game.rank("split") > 0 or (weapon_level >= 3 and combo == 3): game.fire_projectile(origin + aim * 35, aim, damage * (0.65 + game.rank("split") * 0.15), "crescent", true)
		if game.rank("blast") > 0 and combo == 3: game.radial_damage(origin + aim * 70, 85, damage * 0.3, "hero")
	elif weapon_id == "laser":
		var end: Vector2 = origin + aim * Rules.weapon(weapon_id).reach
		end = game.clipped_ray(origin, end)
		var hit := 0
		var targets: Array[Enemy] = []
		for enemy in game.enemies:
			if not enemy.dead: targets.append(enemy)
		targets.sort_custom(func(first: Enemy, second: Enemy): return first.center().distance_squared_to(origin) < second.center().distance_squared_to(origin))
		for enemy in targets:
			if enemy.dead: continue
			if enemy.center().distance_to(Geometry2D.get_closest_point_to_segment(enemy.center(), origin, end)) < enemy.radius + (8 if weapon_level >= 3 else 4):
				enemy.take_damage(damage, true, "hero")
				hit += 1
				if hit >= 4 + game.rank("pierce") + (2 if weapon_level >= 3 else 0): break
		game.effects.beams.append({"start": origin, "end": end, "life": 0.12, "color": Color("9aefed"), "width": 9.0 if weapon_level >= 3 else 5.0})
		game.sound.play("shoot", 12)
	else:
		var angles := [0.0]
		if weapon_id == "scatter": angles = [-0.24, -0.12, 0.0, 0.12, 0.24] if weapon_level < 3 else [-0.33, -0.22, -0.11, 0.0, 0.11, 0.22, 0.33]
		if weapon_id == "boomerang" and weapon_level >= 3: angles = [-0.12, 0.12]
		var primary_count := angles.size()
		for split_index in range(game.rank("split")):
			angles.append(-0.18 - split_index * 0.18)
			angles.append(0.18 + split_index * 0.18)
		for angle_index in range(angles.size()):
			var angle: float = angles[angle_index]
			var side_scale := 0.45 if weapon_id != "scatter" and angle_index >= primary_count else 1.0
			var bullet: Projectile = game.fire_projectile(origin + aim * 25, aim.rotated(angle), damage * side_scale, weapon_id, true)
			bullet.pierce += game.rank("pierce")
			if weapon_id == "storm":
				bullet.pierce += 1
				bullet.chain_count += 1 if weapon_level < 3 else 2
			if weapon_id == "sniper": bullet.pierce += 4 if weapon_level >= 3 else 3
			if weapon_id == "gatling" and weapon_level >= 3 and shot_count % 6 == 0: bullet.pierce += 1
		if (weapon_id == "bow" and weapon_level >= 3 and shot_count % 3 == 0) or (weapon_id == "pistol" and weapon_level >= 3 and shot_count % 4 == 0): game.fire_projectile(origin + aim * 12, aim.rotated(0.05), damage * 0.75, weapon_id, true)
		game.sound.play("boom" if weapon_id == "rocket" else "shoot", 9)
		game.spark(origin + aim * 30, aim * 80, Rules.weapon(weapon_id).color, 0.09, 9)

func use_skill() -> bool:
	if skill_cooldown > 0 or respawn_time > 0: return false
	var definition: Dictionary = Rules.HEROES[class_id]
	skill_cooldown = definition.cooldown * pow(0.85, game.rank("skill")) / (1 + (skill_level - 1) * 0.1)
	skill_time = definition.duration + ((skill_level - 1) * 0.5 + game.rank("skill") * 0.3 if class_id != "ranger" else 0.0)
	if class_id == "ranger":
		var movement := Input.get_vector("left", "right", "up", "down")
		if movement.length() < 0.1 and velocity.length() > 1: movement = velocity.normalized()
		dash_direction = movement.normalized() if movement.length() > 0.1 else facing
		dash_time = 0.22
		dash_cooldown = skill_cooldown
		invulnerability = maxf(invulnerability, 0.24 + game.rank("skill") * 0.02)
		attack_pending = false
		recall_time = 0
		navigation.clear()
		game.sound.play("dash", 4)
	elif class_id == "engineer":
		energy = minf(max_energy, energy + 40)
		shield = minf(max_shield, shield + 28)
		game.burst(center(), Color("f6c86f"), 18)
		game.sound.play("reward", 5)
	elif class_id == "vanguard":
		invulnerability = maxf(invulnerability, 0.35)
		game.sweep_bullets(center(), 230)
		game.radial_damage(center(), 220, 42.0 * damage_scale(), "hero")
		for enemy in game.enemies:
			if is_instance_valid(enemy) and not enemy.dead and enemy.center().distance_to(center()) < 220:
				enemy.knockback += (enemy.center() - center()).normalized() * 190
		game.burst(center(), Color("ffb27a"), 24)
		game.shake(0.25)
		game.sound.play("boom", 4)
	else:
		game.burst(center(), Color("e9ca8a") if class_id == "knight" else Color("c8b9ff"), 16)
		game.sound.play("reward", 5)
	game.stats.skills += 1
	return true

func take_damage(amount: float) -> void:
	if invulnerability > 0 or respawn_time > 0 or not game.running: return
	var shield_loss := minf(shield, amount)
	shield -= shield_loss
	health -= amount - shield_loss
	since_damage = 0
	invulnerability = 0.4
	recall_time = 0
	visual.hit_flash = 0.1
	game.sound.play("hurt", 5)
	game.shake(0.18)
	game.burst(center(), Color("9ddfed") if shield_loss > 0 else Color("e7ac89"), 6)
	if health <= 0:
		respawn_time = 4
		visual.death_phase = 0
		navigation.clear()
		attack_pending = false
		skill_time = 0
		game.damage_core(20)
		game.toast("倒下了 · 4秒后重新集结", 3)

func recall() -> void:
	if respawn_time > 0 or recall_cooldown > 0: return
	navigation.clear()
	recall_time = 2.2

func _draw() -> void:
	if respawn_time > 0: return
	draw_arc(Vector2(0, 2), 23, 0, TAU, 32, Color(0.65, 0.92, 0.82, 0.7), 1.5, true)
	if game.towers.size() > 0:
		draw_arc(Vector2(0, -8), 340 + 80 * game.rank("architect"), 0, TAU, 64, Color(0.55, 0.85, 0.8, 0.07), 2, true)
	if class_id == "mage" and skill_time > 0:
		draw_arc(Vector2(0, -27), 57, 0, TAU, 6, Color("b5c8ff"), 3, true)
		draw_circle(Vector2(0, -27), 57, Color(0.5, 0.7, 1, 0.08))
	if shield > 0 and since_damage < 0.2: draw_arc(Vector2(0, -25), 37, 0, TAU, 40, Color(0.6, 0.9, 1, 0.6), 2, true)
	if recall_time > 0: draw_arc(Vector2.ZERO, 33, -PI * 0.5, -PI * 0.5 + TAU * (1 - recall_time / 2.2), 48, Color("baf6eb"), 3, true)
	if game.hero_selected: draw_arc(Vector2.ZERO, 29, 0, TAU, 32, Color("f3d891"), 2.5, true)
	if is_instance_valid(locked) and not locked.dead:
		var point := to_local(locked.center())
		draw_arc(point, locked.radius + 8, -0.3, 0.3, 6, Color(1, 0.85, 0.55, 0.7), 2, true)
		draw_arc(point, locked.radius + 8, PI - 0.3, PI + 0.3, 6, Color(1, 0.85, 0.55, 0.7), 2, true)
