class_name ArenaCompanion
extends Node2D
## Persistent 3-view wolf companion for Druid (slot 0 = Frost Wolf tank, slot 1 = Ember Wolf striker).
var hero: Node2D
var slot := 0
var visual: ArenaActor
var health := 0.0
var recovery := 0.0
var boost := 0.0
var boost_visual_scale := 1.0
var orders_left := 0.0
var destination := Vector2.ZERO
var ordered_target: Node2D
var attack_target: Node2D
var cooldown := 0.0
var windup := 0.0
var second_lunge := false
var facing := Vector2.RIGHT
var path := PackedVector2Array()
var route_timer := 0.0

func _wolf_key() -> String:
	return "frost_wolf" if slot == 0 else "ember_wolf"

func _ready() -> void:
	visual = ArenaActor.new()
	add_child(visual)
	var key := _wolf_key()
	visual.configure(key, 60.0 if slot == 0 else 56.0, true)
	health = max_health()

func max_health() -> float:
	var base := 160.0 if slot == 0 else 105.0
	var prank: int = int(hero.passive_rank) if hero != null else 0
	return base * (1.0 + 0.10 * float(prank))

func center() -> Vector2:
	return position + Vector2(0, -24)

func can_block() -> bool:
	return slot == 0 and visible and recovery <= 0 and health > 0 and not hero.knocked_out

func block_capacity() -> int:
	return 1

func command(point: Vector2, target: Node2D) -> void:
	destination = point
	ordered_target = target
	orders_left = 5.0
	route_timer = 0.0

func heal_percent(ratio: float) -> void:
	if not visible or recovery > 0.0:
		return
	var before := health
	health = minf(max_health(), health + max_health() * ratio)
	if health > before + 0.5 and hero != null and hero.game != null:
		hero.game.effect(center(), 26.0, Color("86e896"), "upgrade", 0.35)

func awaken(duration := 7.0) -> void:
	recovery = 0.0
	if not visible:
		position = hero.position + Vector2(-24 if slot == 0 else 24, 8)
		show()
	health = max_health()
	boost = maxf(boost, duration)
	if hero != null and hero.game != null:
		var tint := Color("78e0ff") if slot == 0 else Color("ff8c42")
		hero.game.effect(position, 60.0, tint, "upgrade", 0.55)

func take_hit(amount: float, damage_type: int, _melee := false) -> float:
	if health <= 0 or not visible:
		return 0.0
	var reduce := 0.65 if (slot == 0 and boost > 0) else (0.85 if slot == 0 else 1.0)
	var taken := minf(health, ArenaCombat.resolve(amount, damage_type, 0.0, 0.0) * reduce)
	health -= taken
	visual.feedback.impact(visual, false, -facing)
	if health <= 0:
		recovery = 8.0
		hero.game.blocking.release(self)
		visual.show_state("down", facing, 0.45)
		windup = 0.0
		second_lunge = false
	return taken

func _physics_process(delta: float) -> void:
	var game: Node2D = hero.game
	if not game.running or game.game_over:
		return
	if hero.knocked_out:
		if visible:
			hide()
			game.blocking.release(self)
		recovery = 0.0
		windup = 0.0
		second_lunge = false
		boost = 0.0
		boost_visual_scale = 1.0
		orders_left = 0.0
		return
	visual.feedback.reduced = bool(game.campaign.data.reduced_motion)
	if recovery > 0:
		recovery = maxf(0.0, recovery - delta)
		visible = recovery > 7.4
		if recovery > 0:
			return
		hide()
	if not visible:
		position = hero.position + Vector2(-24 if slot == 0 else 24, 6)
		health = max_health()
		path.clear()
		route_timer = 0.0
		show()
	boost = maxf(0.0, boost - delta)
	var target_scale := 1.35 if boost > 0.0 else 1.0
	boost_visual_scale = move_toward(boost_visual_scale, target_scale, delta * 2.4)
	visual.feedback.base_scale = Vector2.ONE * (visual.visual_size * boost_visual_scale) / 132.0
	visual.scale = visual.feedback.base_scale
	orders_left = maxf(0.0, orders_left - delta)
	cooldown = maxf(0.0, cooldown - delta)
	queue_redraw()
	if windup > 0:
		windup = maxf(0.0, windup - delta)
		if windup <= 0:
			_strike()
		return
	var side: Vector2 = hero.facing.orthogonal() * (1.0 if slot == 0 else -1.0)
	var focus: Vector2 = hero.position + side * 38.0
	var limit := 200.0
	if orders_left > 0:
		focus = destination
		limit = 120.0
	var dom: String = hero.domain if "domain" in hero else "defense"
	var target: Node2D = ordered_target if orders_left > 0 and is_instance_valid(ordered_target) and not ordered_target.dead and ordered_target.domain == dom else game.nearest_enemy(focus, limit, true, dom)
	if slot == 0 and dom == "defense":
		for foe in game.blocking.assignments:
			if game.blocking.assignments[foe] == self and is_instance_valid(foe):
				target = foe
				break
	if is_instance_valid(target) and not target.dead:
		var gap := position.distance_to(Vector2(target.position))
		if gap <= (54.0 if boost > 0 else 48.0):
			if cooldown <= 0:
				attack_target = target
				facing = position.direction_to(target.position)
				var base_cd := 1.15 if slot == 0 else 0.74
				cooldown = base_cd / (1.40 if boost > 0 else 1.0)
				windup = 0.20 if boost > 0 else 0.24
				visual.show_state("attack", facing, windup * 1.8)
				visual.frame = 0
			return
		focus = target.position + (side * 0.30 if gap > 58.0 else Vector2.ZERO)
	_move_to(focus, delta)

func _move_to(point: Vector2, delta: float) -> void:
	if position.distance_to(point) < 12.0:
		visual.show_state("idle", facing)
		return
	var game: Node2D = hero.game
	var dom: String = hero.domain if "domain" in hero else "defense"
	var haste: float = (1.0 + float(game.rift_domain.rift_explore_haste())) if (dom == "rift" and game != null and game.rift_domain != null) else 1.0
	var speed: float = (210.0 if slot == 0 else 275.0) * (1.25 if boost > 0 else 1.0) * haste
	var goal := position.move_toward(point, speed * delta)
	route_timer = maxf(0.0, route_timer - delta)
	if dom == "rift":
		goal = game.rift_domain.clamp_rift_position(goal) if game.rift_domain != null else goal
		if position.distance_squared_to(goal) > 0.1:
			facing = position.direction_to(goal)
			position = goal
			visual.show_state("walk", facing)
			visual.stride(speed)
		return
	if game.walkable(goal) and game.walkable(position.lerp(point, 0.5)):
		path.clear()
	else:
		if route_timer <= 0:
			path = game.navigation_path(position, point)
			route_timer = 0.30
		while not path.is_empty() and position.distance_to(path[0]) < 6.0:
			path.remove_at(0)
		if path.is_empty():
			return
		goal = position.move_toward(path[0], speed * delta)
	if not game.walkable(goal):
		return
	facing = position.direction_to(goal)
	position = goal
	visual.show_state("walk", facing)
	visual.stride(speed)

func _strike() -> void:
	if not is_instance_valid(attack_target) or attack_target.dead or position.distance_to(attack_target.position) > 68.0:
		second_lunge = false
		return
	var dom: String = hero.domain if "domain" in hero else "defense"
	var amount: float = (22.0 if slot == 0 else 32.0) * hero.damage_scale() * (1.45 if boost > 0 else 1.0)
	attack_target.take_hit(amount, 0, "hero", 0.0, 0.0, 0.0, "beast_strike", facing)
	if slot == 0 and is_instance_valid(attack_target) and not attack_target.dead:
		# Frost Wolf chills target briefly
		attack_target.chill(0.25 if boost > 0 else 0.18, 1.8)
	elif slot == 1:
		# Ember Wolf triggers fiery claw splash around primary target
		var splash_r := 76.0 if boost > 0 else 56.0
		var splash_dmg := amount * (0.55 if boost > 0 else 0.42)
		for other in hero.game.domain_enemies(dom):
			if is_instance_valid(other) and other != attack_target and not other.dead and other.position.distance_to(attack_target.position) <= splash_r:
				other.take_hit(splash_dmg, 0, "hero", 0.0, 0.0, 0.0, "beast_strike", facing)
	var fx_col := Color("7be6ff") if slot == 0 else Color("ff7a36")
	hero.game.effect(position + facing * 26 + Vector2(0, -14), 42 if boost > 0 else 28, fx_col, "slash", 0.22, facing)
	if boost > 0:
		hero.game.audio.play("blade", -18)
	if slot == 1 and boost > 0 and not second_lunge and not attack_target.dead:
		second_lunge = true
		windup = 0.14
		visual.frame = 0
	else:
		second_lunge = false

func _draw() -> void:
	var s := boost_visual_scale
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, 17.0 * s, Color(0.08, 0.10, 0.14, 0.54))
	draw_set_transform(Vector2.ZERO)
	if boost > 0:
		var aura_col := Color("6ce0ff") if slot == 0 else Color("ff7834")
		var t_b := float(Time.get_ticks_msec()) * 0.005
		for k in range(3):
			var age := fmod(t_b + float(k) * 0.34, 1.0)
			var mp := Vector2(sin(t_b * 1.5 + float(k) * 2.1) * 14.0 * s, -4.0 - age * 26.0 * s).snapped(Vector2(2, 2))
			draw_rect(Rect2(mp - Vector2(2, 2), Vector2(4, 4)), Color("14111b", (1.0 - age) * 0.65))
			draw_rect(Rect2(mp - Vector2(1, 1), Vector2(2, 2)), Color(aura_col.r, aura_col.g, aura_col.b, (1.0 - age) * 0.92))
	if health < max_health() and health > 0:
		var bar_y := -visual.visual_size * s * 0.72 - 6.0
		draw_rect(Rect2(-15, bar_y, 30, 3.5), Color("222833"))
		draw_rect(Rect2(-15, bar_y, 30 * health / max_health(), 3.5), Color("7de2ff") if slot == 0 else Color("ff9e5c"))
