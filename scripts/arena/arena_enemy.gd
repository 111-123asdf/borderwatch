class_name ArenaEnemy
extends Node2D

var game: Node2D
var kind := "torch"
var elite := false
var elite_mod := ""
var support_cooldown := 0.0
var locked_tower: ArenaTower
var locked_hero := false
var attack_windup := 0.0
var windup_tower: ArenaTower
var windup_explode := false
var weakness := ""
var affinity := ""
var boss_phase := 0
var burn_time := 0.0
var burn_dps := 0.0
var burn_tick := 0.0
var burn_source := "other"
var poison_time := 0.0
var poison_dps := 0.0
var poison_tick := 0.0
var poison_source := "other"
var last_source := "other"
var freeze_time := 0.0
var chill_stacks := 0
var health := 60.0
var max_health := 60.0
var speed := 72.0
var radius := 22.0
var dead := false
var slow_time := 0.0
var attack_cooldown := 0.0
var ranged_cooldown := 0.0
var boss_core_cooldown := 0.0
var boss_burst_cooldown := 1.5
var visual: ActorVisual
var hit_flash := 0.0
var knockback := Vector2.ZERO

func center() -> Vector2:
	return position + Vector2(0, -24 if kind != "boss" else -46)

func element_color(element: String) -> Color:
	match element:
		"fire": return Color("ff8a5c")
		"frost": return Color("8be8ff")
		"lightning": return Color("ffe36e")
	return Color.WHITE

func element_name(element: String) -> String:
	match element:
		"fire": return "火"
		"frost": return "冰"
		"lightning": return "雷"
	return element

func element_multiplier(element: String) -> float:
	var multiplier := 1.0
	if element != "" and element == weakness:
		multiplier += 0.50
	if element != "" and element == affinity:
		multiplier -= 0.35
	return multiplier

func apply_burn(dps: float, duration: float, source := "other") -> void:
	if game.hero != null and game.hero.passives.has("combustion"):
		dps *= 1.5
	burn_dps = maxf(burn_dps, dps * element_multiplier("fire"))
	burn_time = maxf(burn_time, duration)
	burn_tick = minf(burn_tick, 0.5)
	burn_source = source

func apply_knockback(direction: Vector2, force: float) -> void:
	if kind == "boss" or freeze_time > 0.0: return
	var factor := 0.55 if elite else 1.0
	knockback += direction.normalized() * force * factor

func apply_poison(dps: float, duration: float, source := "other") -> void:
	poison_dps = maxf(poison_dps, dps)
	poison_time = maxf(poison_time, duration)
	poison_tick = minf(poison_tick, 0.5)
	poison_source = source

func apply_frost(duration: float) -> void:
	slow_time = maxf(slow_time, duration * element_multiplier("frost"))
	chill_stacks += 1
	var threshold := 2 if game.hero != null and game.hero.passives.has("deepfreeze") else 3
	if chill_stacks >= threshold:
		chill_stacks = 0
		var extra := 0.5 if game.hero != null and game.hero.passives.has("deepfreeze") else 0.0
		extra += 0.5 if game.hero != null and game.hero.passives.has("absolute_zero") else 0.0
		freeze_time = maxf(freeze_time, 1.0 + extra)

func _ready() -> void:
	visual = ActorVisual.new()
	add_child(visual)
	var family := "torch"
	var color := "Red"
	var factor := 0.76
	if kind == "shooter":
		family = "archer"
	elif kind == "hound":
		family = "torch"
		factor = 0.7
		speed = 155.0
		radius = 18.0
	elif kind == "charger":
		family = "torch"
		factor = 0.82
		speed = 128.0
		radius = 20.0
	elif kind == "shaman":
		family = "archer"
		color = "Purple"
		factor = 0.84
		speed = 62.0
		radius = 22.0
	elif kind == "mortar":
		family = "barrel"
		color = "Blue"
		factor = 1.0
		speed = 42.0
		radius = 28.0
	elif kind == "splitter":
		family = "barrel"
		color = "Purple"
		factor = 0.92
		speed = 74.0
		radius = 26.0
	elif kind == "bomber":
		family = "barrel"
		color = "Purple"
		factor = 0.92
		speed = 58.0
		radius = 24.0
	elif kind == "brute":
		family = "barrel"
		color = "Blue"
		factor = 1.08
		speed = 46.0
		radius = 32.0
	elif kind == "sapper":
		family = "tnt"
		factor = 0.85
		speed = 96.0
		radius = 20.0
	elif kind == "barrel":
		family = "barrel"
		factor = 0.95
	elif kind == "shielded":
		family = "barrel"
		color = "Purple"
		factor = 1.0
		radius = 28.0
	elif kind == "armored":
		family = "barrel"
		color = "Blue"
		factor = 0.95
		radius = 26.0
	elif kind == "boss":
		family = "barrel"
		color = "Red"
		factor = 1.25
		radius = 40.0
		speed = 36.0
	visual.setup(family, color, factor)
	if elite:
		radius *= 1.3
		speed *= 0.90
		visual.scale = Vector2.ONE * 0.96
		if elite_mod == "swift":
			speed *= 1.28
		elif elite_mod == "tough":
			max_health *= 1.35
			health = max_health
	else:
		visual.scale = Vector2.ONE * 0.78

func _physics_process(delta: float) -> void:
	if dead or not game.running or game.game_over: return
	if game.hitstop > 0.0:
		queue_redraw()
		return
	if knockback.length_squared() > 1.0:
		position += knockback * delta
		knockback = knockback.move_toward(Vector2.ZERO, 520.0 * delta)
	slow_time = maxf(0.0, slow_time - delta)
	burn_time = maxf(0.0, burn_time - delta)
	poison_time = maxf(0.0, poison_time - delta)
	freeze_time = maxf(0.0, freeze_time - delta)
	burn_tick -= delta
	poison_tick -= delta
	if burn_time > 0.0 and burn_tick <= 0.0:
		burn_tick = 0.5
		take_damage(burn_dps * 0.5, burn_source)
		if dead: return
	if poison_time > 0.0 and poison_tick <= 0.0:
		poison_tick = 0.5
		take_damage(poison_dps * 0.5, poison_source)
		if dead: return
	if freeze_time > 0.0:
		queue_redraw()
		return
	hit_flash = maxf(0.0, hit_flash - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	ranged_cooldown = maxf(0.0, ranged_cooldown - delta)
	boss_core_cooldown = maxf(0.0, boss_core_cooldown - delta)
	boss_burst_cooldown = maxf(0.0, boss_burst_cooldown - delta)
	support_cooldown = maxf(0.0, support_cooldown - delta)
	if attack_windup > 0.0:
		attack_windup = maxf(0.0, attack_windup - delta)
		if attack_windup <= 0.0 and windup_tower != null and is_instance_valid(windup_tower):
			if windup_explode:
				game.enemy_explosion(position, 104.0, 18.0, 28.0)
				dead = true
				game.enemy_died(self)
				queue_free()
				return
			windup_tower.health -= 22.0
			game.hit_feedback(windup_tower.position, 22.0)
			game.rings.append({"point": windup_tower.position, "radius": 34.0, "life": 0.25})
			if windup_tower.health <= 0.0: game.tower_destroyed(windup_tower)
			windup_tower = null
	if kind in ["sapper", "bomber", "mortar"]:
		var tower: ArenaTower = locked_tower
		if tower == null or not is_instance_valid(tower) or position.distance_to(tower.position) > 520.0:
			tower = game.nearest_tower(position, 620.0 if kind == "mortar" else 380.0)
			locked_tower = tower
		if tower != null:
			var tower_direction := (tower.position - position).normalized()
			var tower_distance := position.distance_to(tower.position)
			if kind == "mortar":
				if tower_distance > 240.0:
					position += tower_direction * speed * delta
				elif attack_windup <= 0.0 and ranged_cooldown <= 0.0:
					ranged_cooldown = 2.2
					attack_windup = 0.45
					windup_tower = tower
					windup_explode = false
			elif kind == "bomber" and tower_distance < 58.0:
				if attack_windup <= 0.0:
					attack_windup = 0.45
					windup_tower = tower
					windup_explode = true
			else:
				position += tower_direction * speed * delta
				if tower_distance < 48.0:
					tower.health -= (34.0 if kind == "brute" else 30.0) * delta
					if tower.health <= 0.0: game.tower_destroyed(tower)
			visual.advance(delta, tower_direction * speed, tower_direction)
			queue_redraw()
			return
		locked_tower = null
	if kind == "shaman" and support_cooldown <= 0.0:
		support_cooldown = 2.4
		game.shaman_support(position)
	if kind == "boss":
		if health < max_health * 0.66 and boss_phase == 0:
			boss_phase = 1
			game.boss_summon(position)
			game.boss_phase_shift(position, boss_phase)
		elif health < max_health * 0.33 and boss_phase == 1:
			boss_phase = 2
			game.boss_summon(position)
			game.boss_phase_shift(position, boss_phase)
		if boss_burst_cooldown <= 0.0 and game.hero != null and position.distance_to(game.hero.position) < 650.0:
			boss_burst_cooldown = 3.6
			game.enemy_shot_radial(position + Vector2(0, -24), 9.0, 180.0, 12)
	var direction: Vector2 = game.flow_at(position)
	if kind in ["charger", "hound"] and game.hero != null and position.distance_to(game.hero.position) < 500.0:
		direction = (game.hero.position - position).normalized()
		locked_hero = true
	else:
		locked_hero = false
	if direction == Vector2.ZERO:
		direction = (game.CORE - position).normalized()
	var slow_factor := 0.55 if slow_time > 0.0 else 1.0
	var core_distance := position.distance_to(game.CORE)
	var boss_holding := kind == "boss" and core_distance < 300.0
	if not boss_holding:
		position += direction * speed * slow_factor * delta
	var visual_motion := Vector2.ZERO if boss_holding else direction * speed
	visual.advance(delta, visual_motion, direction)
	if kind in ["shooter", "boss", "bomber"] and game.hero != null:
		var shot_range := 430.0 if kind == "shooter" else (520.0 if kind == "boss" else 480.0)
		if position.distance_to(game.hero.position) < shot_range and ranged_cooldown <= 0.0:
			ranged_cooldown = 1.8 if kind == "shooter" else (1.3 if kind == "boss" else 2.1)
			var shot_damage := 9.0 if kind == "shooter" else (14.0 if kind == "boss" else 10.0)
			var count := 3 if kind == "shooter" else (5 if kind == "boss" else 3)
			if elite: count += 1
			var lead_target: Vector2 = game.hero.center() + game.hero.velocity * 0.18
			game.enemy_shot_arc(position + Vector2(0, -24), lead_target, shot_damage, 230.0 if kind != "bomber" else 190.0, count, 0.28)
	if kind == "boss":
		if core_distance < 300.0 and boss_core_cooldown <= 0.0:
			boss_core_cooldown = 1.0
			game.core_hit(22.0)
		queue_redraw()
		return
	if core_distance < 58.0:
		var leak := 28.0 if kind == "armored" else (36.0 if kind == "brute" else 14.0)
		game.core_hit(leak)
		game.enemy_escaped(self)
		dead = true
		queue_free()
		return
	if game.hero != null and game.hero.position.distance_to(position) < 34.0 and attack_cooldown <= 0.0:
		attack_cooldown = 1.0
		var contact := 14.0
		if kind == "boss": contact = 28.0
		elif kind == "brute": contact = 22.0
		elif kind == "charger": contact = 16.0
		game.hero.take_damage(contact)
	queue_redraw()

func take_damage(amount: float, source := "other") -> void:
	if dead: return
	if elite and elite_mod == "warding":
		amount *= 0.8
	if kind == "boss" and source == "tower":
		amount *= 0.65
	if freeze_time > 0.0 and game.hero != null and game.hero.passives.has("absolute_zero"):
		amount *= 1.3
	last_source = source
	game.record_damage(amount, source)
	health -= amount
	hit_flash = 0.1
	visual.hit_flash = 0.1
	if health <= 0.0:
		dead = true
		game.enemy_died(self)
		queue_free()

func _draw() -> void:
	if dead: return
	var width := 42.0 if kind != "boss" else 76.0
	var top := -44.0 if kind != "boss" else -70.0
	if health < max_health:
		draw_rect(Rect2(-width * 0.5, top, width, 5), Color("251f21"))
		draw_rect(Rect2(-width * 0.5, top, width * health / max_health, 5), Color("df8267"))
	if weakness != "":
		draw_string(ThemeDB.fallback_font, Vector2(-width * 0.5, top - 5), "弱%s" % element_name(weakness), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, element_color(weakness))
	if affinity != "":
		draw_arc(Vector2.ZERO, radius + 5, 0, TAU, 24, Color(element_color(affinity), 0.55), 2, true)
	if burn_time > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(width * 0.5 - 14, top - 5), "火", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, element_color("fire"))
	if poison_time > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(width * 0.5 - 30, top - 5), "毒", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("9fe86e"))
	if slow_time > 0.0:
		draw_string(ThemeDB.fallback_font, Vector2(width * 0.5 - 14, top - 18), "冰", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, element_color("frost"))
	if freeze_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 16, 0, TAU, 28, Color(0.7, 0.95, 1.0, 0.7), 3, true)
		draw_string(ThemeDB.fallback_font, Vector2(width * 0.5 - 14, top - 31), "冻", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.98, 1.0))
	if hit_flash > 0.0:
		var flash_alpha := hit_flash / 0.1
		draw_arc(Vector2.ZERO, radius + 3, 0, TAU, 24, Color(1.0, 0.96, 0.86, flash_alpha * 0.75), 2.5, true)
		draw_line(Vector2(-radius * 0.7, 0), Vector2(radius * 0.7, 0), Color(1.0, 0.9, 0.75, flash_alpha * 0.5), 1.5, true)
	if locked_tower != null and is_instance_valid(locked_tower):
		draw_line(Vector2.ZERO, locked_tower.position - position, Color(1.0, 0.35, 0.28, 0.55), 2, true)
	if locked_hero and game.hero != null:
		draw_line(Vector2.ZERO, game.hero.position - position, Color(1.0, 0.72, 0.35, 0.45), 1.5, true)
	if attack_windup > 0.0:
		draw_arc(Vector2.ZERO, radius + 20, 0, TAU * clampf(1.0 - attack_windup / 0.45, 0.0, 1.0), 24, Color(1.0, 0.35, 0.25, 0.9), 3, true)
	if kind == "shielded":
		draw_arc(Vector2.ZERO, 30, 0, TAU, 24, Color(0.65, 0.9, 1.0, 0.45), 3, true)
	elif kind == "armored":
		draw_arc(Vector2.ZERO, 29, 0, TAU, 24, Color(0.8, 0.85, 0.9, 0.5), 4, true)
	elif kind == "boss":
		draw_arc(Vector2.ZERO, 46, 0, TAU, 32, Color(0.9, 0.45, 0.35, 0.6), 4, true)
	if elite:
		draw_arc(Vector2.ZERO, radius + 8, 0, TAU, 24, Color(1.0, 0.85, 0.4, 0.7), 3, true)
		var mod_name: String = {"swift": "迅捷", "tough": "坚韧", "volatile": "爆裂", "warding": "护咒"}.get(elite_mod, "精英")
		draw_string(ThemeDB.fallback_font, Vector2(-width * 0.5, top - 18), "精英·" + mod_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("ffd36e"))
	if kind == "bomber":
		draw_arc(Vector2.ZERO, 28, 0, TAU, 20, Color(0.8, 0.55, 1.0, 0.45), 3, true)
	if burn_time > 0.0:
		draw_arc(Vector2.ZERO, radius + 13, 0, TAU, 20, Color(1.0, 0.45, 0.18, 0.55), 3, true)
