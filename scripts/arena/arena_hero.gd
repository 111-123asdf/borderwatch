class_name ArenaHero
extends CharacterBody2D

var game: Node2D
var visual: ActorVisual
var class_id := "knight"
var health := 120.0
var max_health := 120.0
var shield := 60.0
var max_shield := 60.0
var shield_regen := 3.0
var shield_regen_delay := 0.0
var speed := 270.0
var aim := Vector2.RIGHT
var facing := Vector2.RIGHT
var fire_cooldown := 0.0
var skill_cooldown := 0.0
var skill_cooldown_max := 12.0
var skill_time := 0.0
var skill_name := "火力双生"
var weapon_key := "pistol"
var weapon_level := 1
var dash_time := 0.0
var dash_direction := Vector2.RIGHT
var barrier_time := 0.0
var invulnerability := 0.0
var xp := 0
var level := 1
var xp_target := 35
var gold_gained := 0
var hurt_flash := 0.0
var passives := {}
var damage_mult := 1.0
var attack_speed_mult := 1.0
var crit_chance := 0.0
var pierce_bonus := 0
var splash_bonus := 0.0
var slow_bonus := 0.0
var pickup_radius := 230.0
var speed_mult := 1.0
var skill_cd_mult := 1.0
var gold_mult := 1.0
var xp_mult := 1.0
var multishot := 0
var shots_fired := 0
var storm_cooldown := 0.0
var burn_dps := 0.0
var slow_damage_bonus := 0.0
var execute_threshold := 0.35
var crit_multiplier := 2.0
var close_damage_bonus := 0.0
var damage_reduction := 0.0
var dual_duration_bonus := 0.0
var shield_damage_bonus := 0.0
var shield_break_shock := false
var tempo_bonus := 0.0
var tempo_time := 0.0
var dash_trail := false
var full_health_bonus := 0.0
var dash_cd_mult := 1.0
var barrier_duration_bonus := 0.0
var barrier_damage_bonus := 0.0
var barrier_reflect := false
var mage_echo := false
var weapon_tier_damage := 0.0
var weapon_tier_speed := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 13.0
	collision.shape = shape
	add_child(collision)
	visual = ActorVisual.new()
	add_child(visual)
	configure("knight")

func configure(key: String) -> void:
	if not Rules.HEROES.has(key): key = "knight"
	class_id = key
	var data: Dictionary = Rules.HEROES[key]
	max_health = float(data.health)
	health = max_health
	max_shield = float(data.shield)
	shield = max_shield
	shield_regen = float(data.regen)
	shield_regen_delay = 0.0
	speed = float(data.speed) * 1.20
	if key == "ranger":
		max_health += 25.0
		health = max_health
		max_shield += 15.0
		shield = max_shield
	elif key == "mage":
		max_health += 35.0
		health = max_health
		max_shield += 25.0
		shield = max_shield
	else:
		max_health += 25.0
		health = max_health
		max_shield += 15.0
		shield = max_shield
	skill_cooldown_max = float(data.cooldown)
	skill_cooldown = 0.0
	skill_name = String(data.skill)
	skill_time = 0.0
	barrier_time = 0.0
	dash_time = 0.0
	weapon_key = String(data.start)
	weapon_level = 1
	visual.setup("player", String(data.color), 1.05, true)
	visual.hero_identity = key
	visual.held_weapon = weapon_key

func center() -> Vector2:
	return position + Vector2(0, -28)

func weapon_definition() -> Dictionary:
	return Rules.weapon(weapon_key)

func class_damage_scale() -> float:
	if class_id == "ranger": return 1.40
	if class_id == "mage": return 1.45
	return 1.0

func equip_weapon(key: String, upgrade_level := 1) -> void:
	if not Rules.weapon_keys().has(key): return
	weapon_key = key
	weapon_level = clampi(upgrade_level, 1, 3)
	visual.held_weapon = key
	game.hud.toast("宝匣：%s Lv.%d" % [Rules.weapon(key).name, weapon_level], 2)

func apply_passive(key: String) -> void:
	passives[key] = int(passives.get(key, 0)) + 1
	match key:
		"swift": speed_mult += 0.10
		"power": damage_mult += 0.15
		"rapid": attack_speed_mult += 0.12
		"crit": crit_chance = minf(0.75, crit_chance + 0.15)
		"pierce": pierce_bonus += 1
		"blast": splash_bonus += 30.0
		"frost": slow_bonus += 1.0
		"magnet": pickup_radius += 80.0
		"aegis":
			max_shield += 30.0
			shield = max_shield
		"vitality":
			max_health += 30.0
			health = minf(max_health, health + 30.0)
		"focus": skill_cd_mult = maxf(0.35, skill_cd_mult * 0.90)
		"greed": gold_mult += 0.15
		"scholar": xp_mult += 0.15
		"multishot": multishot += 1
		"burn": burn_dps += 6.0
		"pistol_caliber": damage_mult += 0.18
		"pistol_akimbo": multishot += 1
		"pistol_quickdraw": attack_speed_mult += 0.10
		"pistol_ricochet": pierce_bonus += 1
		"pistol_storm": pass
		"bow_broadhead":
			damage_mult += 0.20
			pierce_bonus += 1
		"bow_hunter": slow_damage_bonus += 0.30
		"bow_rapid": attack_speed_mult += 0.12
		"bow_pierce": pierce_bonus += 1
		"bow_marksman":
			crit_chance = minf(0.85, crit_chance + 0.10)
			crit_multiplier += 0.50
		"bow_rain": pass
		"scatter_wide": multishot += 1
		"scatter_frost": slow_bonus += 0.8
		"scatter_close": close_damage_bonus += 0.20
		"scatter_reload": attack_speed_mult += 0.12
		"scatter_barrage": pass
		"juggernaut": damage_reduction = minf(0.6, damage_reduction + 0.20)
		"tower_doctrine": skill_cd_mult = maxf(0.35, skill_cd_mult * 0.90)
		"knight_bulwark": damage_reduction = minf(0.6, damage_reduction + 0.06)
		"knight_riposte": shield_break_shock = true
		"knight_dual": dual_duration_bonus += 1.5
		"knight_bastion": shield_damage_bonus += 0.20
		"ranger_tempo": tempo_bonus += 0.15
		"ranger_trail": dash_trail = true
		"ranger_mark": full_health_bonus += 0.20
		"ranger_evasion": dash_cd_mult = maxf(0.4, dash_cd_mult * 0.65)
		"mage_barrier": barrier_duration_bonus += 0.5
		"mage_overcharge": barrier_damage_bonus += 0.25
		"mage_reflect": barrier_reflect = true
		"mage_echo": mage_echo = true
		"chain", "nova", "execute", "deathblast", "storm", "lifesteal", "dash_reset", "overload", "tower_link", "tower_bolt", "tower_cannon", "tower_frost", "tower_network", "tower_commander", "tower_engineer", "tower_arc", "tower_venom", "tower_laser", "tower_banner", "tower_fortress", "tower_overclock", "tower_winter", "tower_command", "stormfire", "shatter", "executioner", "tempest", "reaper", "pyroclasm", "chainfrost", "permafrost", "thermal_shock", "wildfire", "deepfreeze", "conductive":
			pass
	_update_weapon_tier()

func _update_weapon_tier() -> void:
	var owned := 0
	for key in passives:
		if not ArenaUpgrades.DEFS.has(key): continue
		var data: Dictionary = ArenaUpgrades.DEFS[key]
		if data.has("weapon") and String(data.weapon) == weapon_key:
			owned += 1
	var next_tier := 1
	if owned >= 4: next_tier = 3
	elif owned >= 2: next_tier = 2
	weapon_tier_damage = [0.0, 0.12, 0.20][next_tier - 1]
	weapon_tier_speed = [0.0, 0.08, 0.12][next_tier - 1]
	if next_tier != weapon_level:
		weapon_level = next_tier
		if game != null and game.hud != null:
			game.hud.toast("武器进化：%s" % weapon_title(), 2)

func weapon_title() -> String:
	var names := {
		"pistol": ["铜雀手枪", "铜雀·连发", "铜雀·风暴"],
		"bow": ["疾风连弓", "疾风·贯羽", "疾风·箭雨"],
		"scatter": ["群星法杖", "群星·散射", "群星·星环"],
	}
	var titles: Array = names.get(weapon_key, ["武器", "武器·觉醒", "武器·终式"])
	return String(titles[clampi(weapon_level - 1, 0, titles.size() - 1)])

func _physics_process(delta: float) -> void:
	if not game.running or game.game_over: return
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	skill_cooldown = maxf(0.0, skill_cooldown - delta)
	storm_cooldown = maxf(0.0, storm_cooldown - delta)
	skill_time = maxf(0.0, skill_time - delta)
	tempo_time = maxf(0.0, tempo_time - delta)
	barrier_time = maxf(0.0, barrier_time - delta)
	invulnerability = maxf(0.0, invulnerability - delta)
	hurt_flash = maxf(0.0, hurt_flash - delta)
	shield_regen_delay = maxf(0.0, shield_regen_delay - delta)
	if shield_regen_delay <= 0.0:
		shield = minf(max_shield, shield + shield_regen * delta)
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if Input.is_action_just_pressed("skill") and skill_cooldown <= 0.0:
		use_skill(movement)
	if dash_time > 0.0:
		dash_time -= delta
		velocity = dash_direction * 620.0
	else:
		var desired_velocity := movement * speed * speed_mult
		var acceleration := 3000.0 if movement.length() > 0.1 else 3800.0
		velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	move_and_slide()
	position = position.clamp(Vector2(50, 50), game.ARENA_SIZE - Vector2(50, 50))
	if movement.length() > 0.1:
		facing = movement.normalized()
	var reach := float(weapon_definition().get("reach", 650.0))
	var target: ArenaEnemy = game.nearest_enemy(center(), maxf(150.0, reach))
	if target != null:
		aim = (target.position - center()).normalized()
		facing = aim
		if Input.is_action_pressed("shoot") and not game.build_mode and fire_cooldown <= 0.0:
			fire(target)
	if passives.has("storm") and storm_cooldown <= 0.0 and target != null:
		var storm_stacks := int(passives.get("storm", 1))
		storm_cooldown = maxf(3.0, 6.0 - float(storm_stacks - 1))
		game.storm_strike(target, 48.0 + level * 3.0 + (storm_stacks - 1) * 12.0)
		if passives.has("tempest"):
			game.frost_nova(target.position, 110.0, 28.0 + level * 2.0, 2.0)
	visual.dual_active = class_id == "knight" and skill_time > 0.0
	visual.advance(delta, velocity, facing)
	queue_redraw()

func fire(target: ArenaEnemy) -> void:
	var definition := weapon_definition()
	var tempo := 1.0 + (tempo_bonus if tempo_time > 0.0 else 0.0)
	fire_cooldown = float(definition.interval) / (attack_speed_mult * tempo * (1.0 + weapon_tier_speed))
	var direction := aim
	if is_instance_valid(target):
		direction = (target.position - center()).normalized()
		aim = direction
	var base_damage: float = float(definition.damage) * (1.0 + (level - 1) * 0.05) * game.hero_damage_scale() * class_damage_scale() * damage_mult * (1.0 + weapon_tier_damage)
	if class_id == "knight" and shield > 0.0:
		base_damage *= 1.0 + shield_damage_bonus
	if class_id == "ranger" and is_instance_valid(target) and target.health >= target.max_health * 0.95:
		base_damage *= 1.0 + full_health_bonus
	if class_id == "mage" and barrier_time > 0.0:
		base_damage *= 1.0 + barrier_damage_bonus
	if is_instance_valid(target) and target.slow_time > 0.0:
		base_damage *= 1.0 + slow_damage_bonus
	if is_instance_valid(target) and target.position.distance_to(center()) < 300.0:
		base_damage *= 1.0 + close_damage_bonus
	var critical := randf() < crit_chance
	if critical:
		base_damage *= crit_multiplier
	if passives.has("overload"):
		var every := maxi(4, 8 - (int(passives["overload"]) - 1) * 2)
		if (shots_fired + 1) % every == 0:
			base_damage *= 2.0
	var execute_bonus := 0.6 + 0.3 * (int(passives.get("execute", 1)) - 1) if passives.has("execute") else 0.0
	var threshold := 0.50 if passives.has("executioner") else 0.35
	var shatter := passives.has("shatter")
	var weapon_color: Color = definition.color
	var dual := class_id == "knight" and skill_time > 0.0
	shots_fired += 1
	visual.attack(direction, 0.18)
	if weapon_key == "sword":
		game.damage_radius(center() + direction * 55, float(definition.reach), base_damage * (2.0 if dual else 1.0))
		return
	if weapon_key == "scatter":
		var pellets := 5 + multishot
		for index in range(pellets):
			var t := 0.0 if pellets <= 1 else float(index) / float(pellets - 1)
			var angle := lerpf(-0.32, 0.32, t)
			game.spawn_projectile(center(), center() + direction.rotated(angle) * 800.0, base_damage, weapon_color, splash_bonus, slow_bonus, 900.0, 0, execute_bonus, burn_dps, critical, threshold, shatter)
		_trigger_weapon_capstone(direction, base_damage, weapon_color)
		_trigger_on_hit(target, base_damage)
		return
	if weapon_key == "sniper":
		game.spawn_projectile(center(), center() + direction * 800.0, base_damage, weapon_color, splash_bonus, slow_bonus, 1100.0, 3 + pierce_bonus, execute_bonus, burn_dps, critical, threshold, shatter)
		_trigger_on_hit(target, base_damage)
		return
	if weapon_key == "boomerang":
		for angle in [-0.12, 0.12]:
			game.spawn_projectile(center(), center() + direction.rotated(angle) * 800.0, base_damage, weapon_color, splash_bonus, slow_bonus, 700.0, pierce_bonus, execute_bonus, burn_dps, critical, threshold, shatter)
		_trigger_on_hit(target, base_damage)
		return
	var shots := (2 if dual else 1) + multishot
	for index in range(shots):
		var offset := (index - (shots - 1) * 0.5) * 22.0
		game.spawn_projectile(center() + direction.orthogonal() * offset, center() + direction * 800.0 + direction.orthogonal() * offset, base_damage, weapon_color, splash_bonus, slow_bonus, 900.0, pierce_bonus, execute_bonus, burn_dps, critical, threshold, shatter)
	_trigger_weapon_capstone(direction, base_damage, weapon_color)
	_trigger_on_hit(target, base_damage)

func _trigger_weapon_capstone(direction: Vector2, base_damage: float, color: Color) -> void:
	var execute_bonus := 0.6 + 0.3 * (int(passives.get("execute", 1)) - 1) if passives.has("execute") else 0.0
	if passives.has("pistol_storm") and shots_fired % 6 == 0:
		for angle in [-0.18, 0.0, 0.18]:
			game.spawn_projectile(center(), center() + direction.rotated(angle) * 800.0, base_damage * 0.8, color, splash_bonus, slow_bonus, 950.0, pierce_bonus, execute_bonus, burn_dps, false, 0.35, passives.has("shatter"))
	if passives.has("bow_rain") and shots_fired % 6 == 0:
		for angle in [-0.22, 0.0, 0.22]:
			game.spawn_projectile(center(), center() + direction.rotated(angle) * 800.0, base_damage * 0.7, color, splash_bonus, slow_bonus, 850.0, 1, execute_bonus, burn_dps, false, 0.35, passives.has("shatter"))
	if passives.has("scatter_barrage") and shots_fired % 5 == 0:
		for index in range(6):
			var angle := TAU * float(index) / 6.0
			game.spawn_projectile(center(), center() + Vector2.RIGHT.rotated(angle) * 800.0, base_damage * 0.55, color, splash_bonus, slow_bonus, 850.0, 0, execute_bonus, burn_dps, false, 0.35, passives.has("shatter"))

func _trigger_on_hit(target: ArenaEnemy, base_damage: float) -> void:
	if passives.has("chain"):
		var chain_stacks := int(passives.get("chain", 1))
		var interval := maxi(1, 3 - (chain_stacks - 1))
		if shots_fired % interval == 0:
			game.chain_strike(center(), base_damage * (0.6 + 0.1 * (chain_stacks - 1)), 2 + chain_stacks - 1)
	if passives.has("mage_echo") and is_instance_valid(target) and shots_fired % 4 == 0:
		game.damage_radius(target.position, 80.0, base_damage * 0.5)
	if passives.has("nova") and is_instance_valid(target):
		var nova_stacks := int(passives.get("nova", 1))
		var interval := maxi(3, 6 - nova_stacks)
		if shots_fired % interval == 0:
			game.frost_nova(target.position, 90.0 + 15.0 * (nova_stacks - 1), base_damage * (0.35 + 0.05 * (nova_stacks - 1)), 2.0)

func use_skill(movement: Vector2) -> void:
	skill_cooldown = skill_cooldown_max * skill_cd_mult
	if class_id == "ranger":
		skill_cooldown *= dash_cd_mult
		dash_time = 0.18
		invulnerability = maxf(invulnerability, 0.24 + (0.10 if passives.has("ranger_evasion") else 0.0))
		dash_direction = movement.normalized() if movement.length() > 0.1 else facing
		tempo_time = 3.0
		if dash_trail:
			game.frost_nova(center(), 110.0, 28.0 + level * 2.0, 1.5)
		game.hud.toast("掠影翻滚：短暂无敌", 1)
	elif class_id == "mage":
		barrier_time = 3.5 + barrier_duration_bonus
		game.clear_hostile_projectiles()
		if barrier_reflect:
			game.damage_radius(center(), 130.0, 40.0 + level * 3.0)
		game.hud.toast("星纹结界：清弹 %.1f 秒" % barrier_time, 1)
	else:
		skill_time = 5.0 + dual_duration_bonus
		game.hud.toast("火力双生：%.1f 秒双持" % skill_time, 1)

func take_damage(amount: float) -> void:
	if invulnerability > 0.0 or game.game_over: return
	amount *= 1.0 - damage_reduction
	var shield_before := shield
	var shield_loss := minf(shield, amount)
	shield -= shield_loss
	health -= amount - shield_loss
	shield_regen_delay = 3.0
	invulnerability = 0.35
	hurt_flash = 0.12
	if shield_before > 0.0 and shield <= 0.0:
		game.shake(8.0)
		game.hud.toast("护盾破碎", 1.2)
		if shield_break_shock:
			game.damage_radius(center(), 140.0, 50.0 + level * 4.0)
	else:
		game.hud.toast("护盾吸收", 0.6)
	if health <= 0.0:
		health = 0.0
		game.hero_died()

func add_xp(amount: int) -> void:
	xp += int(amount * xp_mult)
	while xp >= xp_target:
		xp -= xp_target
		level += 1
		xp_target += 25
		game.queue_level_choice()

func _draw() -> void:
	draw_arc(Vector2(0, 2), 21, 0, TAU, 32, Color(0.65, 0.92, 0.82, 0.65), 1.5, true)
	if shield > 0.0:
		var ratio := shield / max_shield
		draw_arc(Vector2(0, -24), 31, -PI * 0.8, -PI * 0.8 + PI * 1.6 * ratio, 28, Color(0.55, 0.85, 1.0, 0.65), 2.5, true)
	if barrier_time > 0.0:
		draw_arc(Vector2(0, -10), 62, 0, TAU, 40, Color(0.65, 0.85, 1.0, 0.55), 3, true)
	if hurt_flash > 0.0:
		draw_circle(Vector2(0, -28), 28, Color(1.0, 0.35, 0.3, 0.25))
