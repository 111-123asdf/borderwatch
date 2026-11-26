class_name ArenaHero
extends CharacterBody2D
var game: Node2D
var class_id: String="lord"
var data: Dictionary={}
var health:=420.0
var max_health:=420.0
var cooldowns: Array[float]=[0.0,0.0]
var cooldown_totals: Array[float]=[0.0,0.0]
var attack_cooldown:=0.0
var domain: String="defense"
var combat_delay:=0.0
var knocked_out:=false
var revive_clock:=0.0
var protection:=0.0
var rolling:=0.0
var roll_direction:=Vector2.RIGHT
var facing:=Vector2.RIGHT
var action: String=""
var action_clock:=0.0
var action_duration:=0.6
var action_target:=Vector2.ZERO
var action_enemy: Node2D
var action_released:=false
var queued_attack_point:=Vector2.INF
var shots:=0
var empower_shot:=0
var visual: ArenaActor
var path: PackedVector2Array=[]
var war_cry:=0.0
var meta_cooldown:=0.0
var hurt_time:=0.0
var overheal_shield:=0.0
# New 5-hero dedicated state clocks
var lord_shield_clock:=0.0
var lord_thorn_tick:=0.0
var healer_blessing_clock:=0.0
var healer_blessing_pos:=Vector2.ZERO
var healer_sanctuary_clock:=0.0
var healer_sanctuary_pos:=Vector2.ZERO
var healer_sanctuary_tick:=0.0
var healer_nova_tick:=0.0
var werewolf_bloodlust_clock:=0.0
var werewolf_beast_clock:=0.0
var gunner_overdrive_clock:=0.0
# Universal short dodge & hero debuffs (v0.23) & Perfect Dodge Counter (v0.25)
const DODGE_CD := 4.5
const DODGE_DURATION := 0.14
const DODGE_SPEED := 420.0
const DODGE_IFRAME := 0.24
const PERFECT_DODGE_WINDOW := 0.22
const COUNTER_DURATION := 4.0
const COUNTER_MULT := 1.60
var dodge_cooldown := 0.0
var dodge_cooldown_total := 0.0
var dodge_left := 0.0
var dodge_direction := Vector2.RIGHT
var perfect_dodge_window := 0.0
var perfect_dodge_triggered := false
var counter_ready_clock := 0.0
var perfect_dodge_flash := 0.0
var perfect_dodge_count := 0
var debuff_slow_clock := 0.0
var debuff_slow_amount := 0.0
var debuff_poison_clock := 0.0
var debuff_poison_dps := 0.0
var debuff_poison_tick := 0.0
var debuff_bleed_clock := 0.0
var debuff_bleed_dps := 0.0
var debuff_bleed_tick := 0.0
var debuff_stun_clock := 0.0
var debuff_stun_immune := 0.0

var meta_level:=1
var meta_health:=0.0
var meta_attack:=0.0
var passive_rank:=0
var foot_clock:=0.0
var companions: Array[Node2D]=[]
var _healer_hit_cnt := 0
var _auto_target_preview: Node2D
static var _blade_cyan_tex: Texture2D
static var _blade_gold_tex: Texture2D

func _ready() -> void:
	collision_layer=2;collision_mask=1
	var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=12;shape.shape=circle;add_child(shape)
	visual=ArenaActor.new();add_child(visual)
	visual.frame_changed.connect(_animation_frame)
	visual.animation_finished.connect(_animation_finished)

func configure(key: String) -> void:
	var resolved := ArenaDefinitions.resolve_hero_id(key)
	for beast in companions:
		if is_instance_valid(beast):
			game.blocking.release(beast)
			beast.set_physics_process(false)
			beast.queue_free()
	companions.clear()
	class_id=resolved;data=ArenaDefinitions.hero(resolved)
	meta_level=game.campaign.level(resolved)
	var bonus: Dictionary=game.campaign.bonuses(resolved)
	meta_health=float(bonus.health);meta_attack=float(bonus.attack);passive_rank=int(bonus.passive)
	max_health=float(data.health)
	meta_cooldown=0.0
	lord_shield_clock=0.0;lord_thorn_tick=0.0
	healer_blessing_clock=0.0;healer_sanctuary_clock=0.0;healer_sanctuary_tick=0.0
	werewolf_bloodlust_clock=0.0;werewolf_beast_clock=0.0
	gunner_overdrive_clock=0.0;empower_shot=0;overheal_shield=0.0
	dodge_cooldown=0.0;dodge_left=0.0
	perfect_dodge_window=0.0;perfect_dodge_triggered=false;counter_ready_clock=0.0;perfect_dodge_flash=0.0;perfect_dodge_count=0
	clear_debuffs()
	recompute()
	health=max_health
	visual.configure(resolved,ArenaHeroArt.height(resolved,game.feel.enabled,game.feel.unit_scale),game.feel.enabled)
	visual.feedback.reduced=bool(game.campaign.data.reduced_motion)
	if resolved=="druid":
		for slot in range(2):
			var beast:=ArenaCompanion.new()
			beast.hero=self;beast.slot=slot;beast.position=position+Vector2(-24 if slot==0 else 24,8)
			game.actors.add_child(beast);companions.append(beast)

func skill_unlocked(slot: int) -> bool: return slot in [0,1] and meta_level>=ArenaDefinitions.SKILL_UNLOCK_LEVELS[slot]
func center() -> Vector2: return position+Vector2(0,-30)
func can_hit_flying() -> bool: return class_id in ["druid","healer","gunner"]
func block_capacity() -> int:
	if domain!="defense":return 0
	var lord_extra := 1 if (class_id=="lord" and lord_shield_clock>0.0) else 0
	return int(data.get("block",1))+lord_extra
func can_block() -> bool: return domain=="defense" and not knocked_out and rolling<=0 and dodge_left<=0 and debuff_stun_clock<=0 and velocity.length()<35

func max_shield_capacity() -> float:
	var base := 0.0
	if class_id == "lord":
		base = max_health * 0.60
	elif class_id == "healer":
		base = max_health * 0.45
	if game != null and game.passive_engine != null:
		base = maxf(base, max_health * game.passive_engine.max_shield_bonus_ratio())
	return base

func recompute() -> void:
	var r_hp: float = game.relic_engine.hero_max_hp_mult() if (game != null and game.relic_engine != null) else 1.0
	var target:=float(data.health)*(1.0+meta_health)*r_hp
	var delta:=target-max_health
	max_health=target
	if not knocked_out and absf(delta)>0.001: health=clampf(health+delta,0.0,max_health)
	overheal_shield=minf(overheal_shield,max_shield_capacity())

func damage_scale() -> float:
	var result:=1.0
	if war_cry>0: result*=1.35
	if class_id=="healer" and healer_blessing_clock>0.0 and position.distance_to(healer_blessing_pos)<=205.0:
		result*=1.15
	if class_id=="werewolf" and werewolf_beast_clock>0.0:
		result*=1.30
	if game != null and game.relic_engine != null:
		result *= game.relic_engine.hero_damage_mult()
	return result

func attack_damage() -> float:
	return float(data.damage)*(1.0+meta_attack)*damage_scale()

func attack_reach() -> float:
	var base := float(data.reach)
	if class_id == "werewolf" and werewolf_beast_clock > 0.0:
		base = 132.0
	elif class_id == "gunner" and gunner_overdrive_clock > 0.0:
		base = base * 1.25
	if class_id in ["lord", "werewolf"] and game != null and game.passive_engine != null:
		base *= game.passive_engine.melee_range_scale()
	return base

func _heal_self(amount: float, allow_shield := false) -> float:
	if knocked_out or amount <= 0.0: return 0.0
	var before := health
	health = minf(max_health, health + amount)
	var healed := health - before
	var over := amount - healed
	if allow_shield and over > 0.0:
		var cap := max_shield_capacity()
		if cap > 0.0:
			overheal_shield = minf(cap, overheal_shield + over)
	if class_id == "healer" and healed >= 5.0 and healer_nova_tick <= 0.0:
		healer_nova_tick = 1.6
		_emit_healer_radiant_nova(185.0, 0.95)
	return healed

func _emit_healer_radiant_nova(radius := 195.0, mult := 1.15) -> void:
	if game == null or knocked_out or game.game_over:
		return
	var dmg := attack_damage() * mult
	game.area_damage(position, radius, dmg, 1, "hero", 0.12, 0.0, 0.15, 0.0, "healer_nova", true, {"domain": domain, "passive_proc": true})
	for e in game.domain_enemies(domain):
		if is_instance_valid(e) and not e.dead and e.position.distance_to(position) <= radius:
			e.ignite(14.0, 2.2)
	game.effect(position, radius * 0.88, Color("ff9ed2"), "upgrade", 0.36)

func command_aura(point: Vector2) -> float:
	if knocked_out: return 0.0
	var value := 0.0
	if class_id == "healer" and healer_blessing_clock > 0.0 and point.distance_to(healer_blessing_pos) <= 210.0:
		value += 0.15
	return value

func healer_tower_speed_bonus(point: Vector2) -> float:
	if knocked_out or class_id != "healer":
		return 0.0
	var bonus := 0.0
	if healer_blessing_clock > 0.0 and point.distance_to(healer_blessing_pos) <= 210.0:
		bonus += 0.20
	if healer_sanctuary_clock > 0.0 and point.distance_to(healer_sanctuary_pos) <= 245.0:
		bonus += 0.25
	return bonus

func healer_soldier_speed_bonus(point: Vector2) -> float:
	if knocked_out or class_id != "healer":
		return 0.0
	var bonus := 0.10 if position.distance_to(point) <= 260.0 else 0.0
	if healer_blessing_clock > 0.0 and point.distance_to(healer_blessing_pos) <= 210.0:
		bonus += 0.20
	return bonus

func clear_debuffs() -> void:
	debuff_slow_clock = 0.0; debuff_slow_amount = 0.0
	debuff_poison_clock = 0.0; debuff_poison_dps = 0.0; debuff_poison_tick = 0.0
	debuff_bleed_clock = 0.0; debuff_bleed_dps = 0.0; debuff_bleed_tick = 0.0
	debuff_stun_clock = 0.0; debuff_stun_immune = 0.0

func apply_debuff(kind: String, duration: float, strength := 0.0) -> bool:
	if knocked_out or protection > 0.0 or game == null or game.game_over or duration <= 0.0:
		return false
	match kind:
		"slow":
			debuff_slow_amount = clampf(maxf(debuff_slow_amount, strength), 0.0, 0.55)
			debuff_slow_clock = maxf(debuff_slow_clock, duration)
		"poison":
			debuff_poison_dps = maxf(debuff_poison_dps, strength)
			debuff_poison_clock = maxf(debuff_poison_clock, duration)
		"bleed":
			debuff_bleed_dps = maxf(debuff_bleed_dps, strength)
			debuff_bleed_clock = maxf(debuff_bleed_clock, duration)
		"stun":
			if debuff_stun_immune > 0.0:
				return false
			debuff_stun_clock = maxf(debuff_stun_clock, minf(duration, 0.85))
			debuff_stun_immune = 3.0
			if action != "" and not action_released:
				cancel_action()
			path.clear()
			game.blocking.release(self)
		_:
			return false
	queue_redraw()
	return true

func active_debuffs() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if debuff_stun_clock > 0.0:
		items.append({"id":"stun","label":"晕眩","time":debuff_stun_clock,"color":Color("f5cd6a")})
	if debuff_poison_clock > 0.0:
		items.append({"id":"poison","label":"中毒","time":debuff_poison_clock,"color":Color("78e682")})
	if debuff_bleed_clock > 0.0:
		items.append({"id":"bleed","label":"流血","time":debuff_bleed_clock,"color":Color("ef6878")})
	if debuff_slow_clock > 0.0:
		items.append({"id":"slow","label":"减速","time":debuff_slow_clock,"color":Color("92b8ff")})
	return items

func is_perfect_dodge_active() -> bool:
	return not knocked_out and perfect_dodge_window > 0.0 and not perfect_dodge_triggered

func _check_immediate_perfect_dodge(origin_pos: Vector2) -> bool:
	if knocked_out or game == null or perfect_dodge_triggered:
		return false
	var origin_center := origin_pos + Vector2(0.0, -30.0)
	for enemy in game.domain_enemies(domain):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		if enemy.melee_target == self and enemy.melee_windup > 0.0 and enemy.melee_windup <= 0.26 and not enemy._melee_perfect_claimed:
			if enemy.is_hero_in_melee_cone(origin_pos, 10.0):
				enemy._melee_perfect_claimed = true
				trigger_perfect_dodge(enemy, enemy.melee_dir)
				return true
		if enemy.charge_left > 0.0 and enemy.position.distance_to(origin_pos) <= 92.0:
			trigger_perfect_dodge(enemy, enemy.facing)
			return true
	for node in game.actors.get_children():
		if node is ArenaProjectile and node.source == "enemy" and node.domain == domain:
			var proj := node as ArenaProjectile
			var to_hero := origin_center - proj.position
			if to_hero.length() <= 58.0 and (to_hero.length() <= 16.0 or proj.direction.dot(to_hero.normalized()) >= 0.35):
				if not proj.hit_ids.has(get_instance_id()):
					proj.hit_ids[get_instance_id()] = true
					trigger_perfect_dodge(null, proj.direction)
					return true
	for attack in game.delayed:
		if str(attack.get("source", "")) == "enemy" and float(attack.get("life", 99.0)) <= 0.26:
			var pt := Vector2(attack.get("point", Vector2.ZERO))
			var rad := float(attack.get("radius", 40.0))
			if origin_center.distance_to(pt) <= rad + 12.0 or origin_pos.distance_to(pt) <= rad + 12.0:
				var t_dir := (origin_center - pt).normalized() if origin_center.distance_to(pt) > 1.0 else Vector2.RIGHT
				trigger_perfect_dodge(null, t_dir)
				return true
	return false

func trigger_perfect_dodge(attacker: Node2D, threat_dir: Vector2) -> void:
	if perfect_dodge_triggered or knocked_out or game == null:
		return
	perfect_dodge_triggered = true
	perfect_dodge_count += 1
	perfect_dodge_flash = 0.30
	counter_ready_clock = COUNTER_DURATION
	dodge_cooldown = minf(dodge_cooldown, DODGE_CD * 0.30)
	if rolling > 0.0:
		cooldowns[0] = cooldowns[0] * 0.60
	attack_cooldown = minf(attack_cooldown, 0.06)
	var reduced := bool(game.campaign.data.reduced_motion) if game.campaign != null else false
	if not reduced and game.feel != null and game.feel.enabled:
		visual.feedback.stop_left = maxf(visual.feedback.stop_left, 0.045)
		if is_instance_valid(attacker) and attacker is ArenaEnemy and is_instance_valid(attacker.visual):
			attacker.visual.feedback.stop_left = maxf(attacker.visual.feedback.stop_left, 0.055)
		game.feel.trauma = minf(1.0, game.feel.trauma + 0.16)
	var dash_dir := dodge_direction if dodge_left > 0.0 else (roll_direction if rolling > 0.0 else (threat_dir.orthogonal() if not threat_dir.is_zero_approx() else facing))
	game.effect(center(), 56.0, Color("7cf0ff"), "perfect_dodge", 0.32, dash_dir)
	if not bool(game.get_meta("hide_damage_numbers", false)):
		game.numbers.append({"point": center() + Vector2(0.0, -36.0), "text": "极限闪避!", "colour": Color("7ef4ff"), "life": 0.72, "duration": 0.72, "critical": true})
	game.audio.play("crit", -8, 1.18)
	game.audio.play("phase", -16, 1.48)
	queue_redraw()

func can_dodge() -> bool:
	return not knocked_out and game != null and game.running and not game.game_over and dodge_cooldown <= 0.0 and dodge_left <= 0.0 and rolling <= 0.0 and debuff_stun_clock <= 0.0

func try_dodge(preferred_dir := Vector2.ZERO) -> bool:
	if not can_dodge():
		return false
	var pre_pos := position
	if action == "attack" or (action != "" and action_released):
		cancel_action()
	var move_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_dir.length() > 0.1:
		dodge_direction = move_dir.normalized()
	elif preferred_dir.length() > 0.1:
		dodge_direction = preferred_dir.normalized()
	else:
		dodge_direction = facing.normalized() if facing.length() > 0.05 else Vector2.RIGHT
	dodge_left = DODGE_DURATION
	var cd_scale: float = game.passive_engine.dodge_cd_scale() if game.passive_engine != null else 1.0
	if game.relic_engine != null:
		cd_scale *= game.relic_engine.hero_cd_scale()
	dodge_cooldown = DODGE_CD * cd_scale
	dodge_cooldown_total = dodge_cooldown
	protection = maxf(protection, DODGE_IFRAME)
	perfect_dodge_window = PERFECT_DODGE_WINDOW
	perfect_dodge_triggered = false
	path.clear()
	game.blocking.release(self)
	if game.feel.enabled:
		game.effect(position + Vector2(0, -14), 38, Color("c4f0ff"), "dodge_step", 0.24, dodge_direction)
		game.audio.play("ranger_roll", -15, 1.28)
	_check_immediate_perfect_dodge(pre_pos)
	if game.event_bus != null:
		game.event_bus.emit_event("hero_dodge", {"origin": pre_pos, "direction": dodge_direction, "domain": domain})
	queue_redraw()
	return true

func _handle_ko() -> void:
	health = 0; knocked_out = true; revive_clock = 15.0; velocity = Vector2.ZERO
	rolling = 0; dodge_left = 0.0; perfect_dodge_window = 0.0; perfect_dodge_triggered = false; counter_ready_clock = 0.0; perfect_dodge_flash = 0.0; path.clear(); queued_attack_point = Vector2.INF
	cancel_action(); clear_debuffs(); game.blocking.release(self)
	werewolf_beast_clock = 0.0; lord_shield_clock = 0.0; gunner_overdrive_clock = 0.0
	if class_id == "werewolf": visual.set_form("werewolf")
	visual.show_state("down", facing, 0.65)

func _apply_dot(amount: float, colour: Color) -> void:
	if knocked_out or amount <= 0.0:
		return
	var incoming := minf(health + overheal_shield, amount)
	var absorbed := minf(overheal_shield, incoming)
	overheal_shield -= absorbed
	health -= (incoming - absorbed)
	combat_delay = 5.0
	if incoming >= 1.0 and game != null:
		game.numbers.append({"point":center() + Vector2(randf_range(-10, 10), -10), "text":"-" + str(int(round(incoming))), "colour":colour, "life":0.5, "duration":0.5})
	if health <= 0.0:
		_handle_ko()

func cooldown_scale() -> float:
	var p_scale: float = game.passive_engine.skill_cd_scale() if (game != null and game.passive_engine != null) else 1.0
	var r_scale: float = game.relic_engine.hero_cd_scale() if (game != null and game.relic_engine != null) else 1.0
	return (1.0 - minf(0.30, meta_cooldown)) * p_scale * r_scale
func command_move(target: Vector2) -> bool:
	if knocked_out or debuff_stun_clock > 0.0: return false
	if domain == "rift":
		var route: PackedVector2Array = game.rift_domain.navigation_path(position,target) if game.rift_domain != null else PackedVector2Array([target])
		if route.is_empty():return false
		path = route
		return true
	var new_path: PackedVector2Array = game.navigation_path(position,target)
	if new_path.is_empty():return false
	path = new_path
	return true
func cancel_action() -> void:
	action="";action_enemy=null;action_clock=0;action_released=false;visual.feedback.stop_left=0.0
func _clamp_hero_pos() -> void:
	if domain == "rift" and game != null and game.rift_domain != null:
		position = game.rift_domain.clamp_rift_position(position)
	else:
		position = position.clamp(Vector2(15, 95), game.world_size() - Vector2(15, 20))
func _resolve_in_place_revive_pos(curr: Vector2) -> Vector2:
	if game == null:
		return curr
	if domain == "rift" and game.rift_domain != null:
		return game.rift_domain.clamp_rift_position(curr)
	var bounds: Rect2 = game.hero_move_bounds()
	var p := curr.clamp(bounds.position, bounds.end)
	if game.walkable(p):
		return p
	for rad: float in [24.0, 42.0, 64.0]:
		for k in range(8):
			var cand := (p + Vector2.from_angle(float(k) * (TAU / 8.0)) * rad).clamp(bounds.position, bounds.end)
			if game.walkable(cand):
				return cand
	return Vector2(game.level_definition.get("hero_spawn", p))

func _physics_process(delta: float) -> void:
	if not game.running or game.game_over: return
	var pointer_blocked: bool = game.input_blocked()
	if pointer_blocked: queued_attack_point=Vector2.INF
	for slot in range(2): cooldowns[slot]=maxf(0,cooldowns[slot]-delta)
	attack_cooldown=maxf(0,attack_cooldown-delta);combat_delay=maxf(0,combat_delay-delta)
	foot_clock=maxf(0.0,foot_clock-delta)
	healer_nova_tick=maxf(0.0,healer_nova_tick-delta)
	dodge_cooldown=maxf(0.0,dodge_cooldown-delta)
	perfect_dodge_window=maxf(0.0,perfect_dodge_window-delta)
	counter_ready_clock=maxf(0.0,counter_ready_clock-delta)
	perfect_dodge_flash=maxf(0.0,perfect_dodge_flash-delta)
	protection=maxf(0,protection-delta);war_cry=maxf(0,war_cry-delta);hurt_time=maxf(0,hurt_time-delta)
	lord_shield_clock=maxf(0.0,lord_shield_clock-delta)
	healer_blessing_clock=maxf(0.0,healer_blessing_clock-delta)
	healer_sanctuary_clock=maxf(0.0,healer_sanctuary_clock-delta)
	werewolf_bloodlust_clock=maxf(0.0,werewolf_bloodlust_clock-delta)
	gunner_overdrive_clock=maxf(0.0,gunner_overdrive_clock-delta)
	debuff_slow_clock=maxf(0.0,debuff_slow_clock-delta)
	if debuff_slow_clock<=0.0: debuff_slow_amount=0.0
	debuff_stun_clock=maxf(0.0,debuff_stun_clock-delta)
	debuff_stun_immune=maxf(0.0,debuff_stun_immune-delta)
	if debuff_poison_clock>0.0 and not knocked_out:
		debuff_poison_clock=maxf(0.0,debuff_poison_clock-delta)
		debuff_poison_tick+=delta
		if debuff_poison_tick>=0.5:
			debuff_poison_tick-=0.5
			_apply_dot(debuff_poison_dps*0.5, Color("7ee888"))
	if debuff_bleed_clock>0.0 and not knocked_out:
		debuff_bleed_clock=maxf(0.0,debuff_bleed_clock-delta)
		debuff_bleed_tick+=delta
		if debuff_bleed_tick>=0.5:
			debuff_bleed_tick-=0.5
			_apply_dot(debuff_bleed_dps*0.5, Color("f07080"))

	# Werewolf beast-form timer & seamless sprite-form toggle
	if class_id == "werewolf":
		if werewolf_beast_clock > 0.0:
			werewolf_beast_clock = maxf(0.0, werewolf_beast_clock - delta)
			if visual.active_form != "werewolf_beast":
				visual.set_form("werewolf_beast")
			if werewolf_beast_clock <= 0.0:
				visual.set_form("werewolf")
				game.effect(center(), 54.0, Color("9ce4ff"), "hit", 0.25)

	if knocked_out:
		if class_id == "werewolf" and visual.active_form != "werewolf":
			visual.set_form("werewolf")
		revive_clock=maxf(0,revive_clock-delta)
		if revive_clock<=0:
			knocked_out=false;health=max_health;protection=1.5
			position=_resolve_in_place_revive_pos(position)
			cancel_action();visual.show_state("idle",facing)
			if is_instance_valid(game) and not game.game_over:
				game.effect(position,44.0,Color("f6d68d"),"upgrade",0.48)
				ArenaBattleArt.emit_world_dust(position,Vector2(0,-16.0),22.0,Color("e4d6b4"))
		queue_redraw();return

	# Lord E blood-thorn periodic counter-damage ring while shield active
	if class_id == "lord" and lord_shield_clock > 0.0:
		lord_thorn_tick -= delta
		if lord_thorn_tick <= 0.0:
			lord_thorn_tick = 0.75
			var thorn_dmg := 18.0 * damage_scale()
			var hit_any := false
			for enemy in game.domain_enemies(domain):
				if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(position) <= 122.0:
					enemy.take_hit(thorn_dmg, 0, "hero", 0.0, 0.0, 0.0, "lord_thorn", position.direction_to(enemy.position))
					hit_any = true
			if hit_any:
				game.effect(position, 118.0, Color("d84c5c"), "blast", 0.24)

	# Healer E blooming sanctuary periodic heal + shield overflow + Radiant Burn Nova
	if class_id == "healer" and healer_sanctuary_clock > 0.0:
		healer_sanctuary_tick -= delta
		if healer_sanctuary_tick <= 0.0:
			healer_sanctuary_tick = 0.5
			var in_zone := position.distance_to(healer_sanctuary_pos) <= 245.0 or domain == "rift"
			if in_zone:
				var amt := max_health * 0.075
				var healed := _heal_self(amt, true)
				if healed > 1.0:
					game.numbers.append({"point":center()+Vector2(0,-18),"text":"+"+str(int(round(healed))),"colour":Color("8ff2a8"),"life":0.55,"duration":0.55})
				_emit_healer_radiant_nova(205.0, 1.05)
			if domain == "defense":
				for soldier in game.soldiers:
					if is_instance_valid(soldier) and not soldier.dead and soldier.position.distance_to(healer_sanctuary_pos) <= 245.0:
						soldier.health = minf(soldier.max_health, soldier.health + soldier.max_health * 0.14)

	if game.blocking.load_for(self)>0: combat_delay=5.0
	if combat_delay<=0: health=minf(max_health,health+max_health*0.08*delta)

	var move:=Input.get_vector("move_left","move_right","move_up","move_down")
	if move.length()>0.05: path.clear()
	elif not path.is_empty():
		while not path.is_empty() and position.distance_to(path[0])<10.0: path.remove_at(0)
		if not path.is_empty():
			move=(path[0]-position).normalized()
	if rolling>0:
		rolling=maxf(0,rolling-delta);velocity=roll_direction*540.0;move_and_slide()
		_clamp_hero_pos()
		if rolling<=0.0: velocity=Vector2.ZERO
		if rolling==0 and game.feel.enabled and not bool(game.campaign.data.reduced_motion):
			ArenaBattleArt.emit_world_dust(position,-roll_direction*32,21,Color("a4d8ff") if gunner_overdrive_clock>0 else Color("bcb198"))
		queue_redraw();return
	if dodge_left>0.0:
		dodge_left=maxf(0.0,dodge_left-delta);velocity=dodge_direction*DODGE_SPEED;move_and_slide()
		_clamp_hero_pos()
		if dodge_left==0.0 and game.feel.enabled and not bool(game.campaign.data.reduced_motion):
			ArenaBattleArt.emit_world_dust(position,-dodge_direction*24,18,Color("c8ecff"))
		queue_redraw();return
	if debuff_stun_clock>0.0:
		velocity=Vector2.ZERO
		visual.show_state("hurt",facing,0.24)
		queue_redraw();return
	if move.length()>0.1:
		if action=="" or action_released:
			facing=move.normalized()
		if action!="" and action_released and action_clock>=action_duration*0.75: cancel_action()
	if action!="":
		action_clock+=delta
		if not action_released and action_clock>=action_duration*ArenaActor.CONTACT_FRACTION: release_action()
		if action_clock>=action_duration: cancel_action()
	var planted: bool=action!="" and action!="attack" and not action_released
	var move_mult: float=1.0
	if class_id=="werewolf" and werewolf_beast_clock>0.0: move_mult*=1.20
	if class_id=="gunner" and gunner_overdrive_clock>0.0: move_mult*=1.20
	if game != null and game.passive_engine != null:
		move_mult *= (1.0 + game.passive_engine.hero_move_speed_bonus())
	if domain == "rift" and game != null and game.rift_domain != null:
		move_mult *= (1.0 + game.rift_domain.rift_explore_haste())
	if debuff_slow_clock>0.0: move_mult*=maxf(0.35, 1.0-debuff_slow_amount)
	var desired: Vector2=move*float(data.speed)*move_mult
	velocity=Vector2.ZERO if planted else velocity.move_toward(desired,(2600.0 if move.length()>0.1 else 4800.0)*delta)
	move_and_slide()
	_clamp_hero_pos()
	if action=="":
		visual.show_state("hurt" if hurt_time>0 else ("walk" if velocity.length()>5 else "idle"),facing,0.24)
		if hurt_time<=0 and velocity.length()>5: visual.stride(velocity.length())
	elif action=="attack" and not action_released and is_instance_valid(action_enemy) and not action_enemy.dead:
		action_target=action_enemy.center()
		if action_enemy.position.distance_to(position)>4.0:
			facing=(action_enemy.position-position).normalized()
	var can_primary: bool=not pointer_blocked and not game.suppress_primary
	var hold_shoot: bool=can_primary and (game.mouse_shoot_held or Input.is_action_pressed("shoot"))
	var player_whiff: bool=can_primary and (game.mouse_shoot_held or queued_attack_point!=Vector2.INF)
	var auto_ready: bool=not game.feel_lab and not game.tower_lab and not game.portal_transition_active() and not game.hud.has_modal()
	var aim_pt: Vector2 = queued_attack_point if queued_attack_point.is_finite() else (Vector2.INF if pointer_blocked else game.mouse_world())
	var enemy: Node2D = select_attack_target(aim_pt) if can_primary or auto_ready else null
	_auto_target_preview = enemy
	if (hold_shoot or player_whiff or auto_ready) and attack_cooldown<=0 and action=="":
		queued_attack_point=Vector2.INF
		if enemy!=null:
			begin_attack(enemy,aim_pt)
		elif player_whiff:
			begin_attack(null,aim_pt)
	var reduced:=bool(game.campaign.data.reduced_motion)
	visual.feedback.reduced=reduced
	visual.modulate=Color.WHITE if hurt_time>0 else Color(1,1,1,0.62 if not reduced and protection>0 and fmod(protection,0.16)<0.08 else 1.0)
	queue_redraw()

func attack_rate() -> float:
	var hero_bonus: float=0.0
	if class_id=="healer" and healer_blessing_clock>0.0 and (domain=="rift" or position.distance_to(healer_blessing_pos)<=210.0):
		hero_bonus+=0.20
	if class_id=="werewolf":
		if werewolf_bloodlust_clock>0.0: hero_bonus+=0.35
		if werewolf_beast_clock>0.0: hero_bonus+=0.55
	if game != null and game.passive_engine != null:
		hero_bonus += game.passive_engine.hero_attack_speed_bonus()
	if domain == "rift" and game != null and game.rift_domain != null and game.rift_domain.hero_speed_pad_clock > 0.0:
		hero_bonus += 0.12
	return 1.0+hero_bonus

func select_attack_target(aim_point: Vector2) -> Node2D:
	var reach := attack_reach()
	var can_aa := can_hit_flying()
	var has_aim:=aim_point!=Vector2.INF and aim_point.distance_to(position)>8.0
	var aim_dir:=(aim_point-position).normalized() if has_aim else facing
	var best: Node2D=null
	var best_score:=INF
	for enemy in game.domain_enemies(domain):
		if not is_instance_valid(enemy) or enemy.dead: continue
		if not can_aa and enemy.has_method("is_flying") and enemy.is_flying(): continue
		var d: float=center().distance_to(enemy.center())
		if d>reach: continue
		var dir: Vector2=(enemy.position-position).normalized()
		var align: float=1.0-0.42*maxf(0.0,dir.dot(aim_dir))
		var score: float=d*align
		if score<best_score: best_score=score;best=enemy
	return best

func begin_attack(enemy: Node2D, aim_point := Vector2.INF) -> bool:
	if knocked_out or debuff_stun_clock>0.0 or action!="" or attack_cooldown>0: return false
	var has_enemy: bool=is_instance_valid(enemy) and not enemy.dead
	if has_enemy and not can_hit_flying() and enemy.has_method("is_flying") and enemy.is_flying():
		has_enemy = false
		enemy = null
	if not has_enemy and aim_point==Vector2.INF: return false
	var target_pt: Vector2=enemy.center() if has_enemy else aim_point
	if target_pt.distance_to(position)>4.0:
		facing=(target_pt-position).normalized()
	action="attack";action_enemy=enemy if has_enemy else null;action_target=target_pt
	action_duration=minf(0.36,float(data.interval)/attack_rate()*0.72);action_clock=0;action_released=false
	attack_cooldown=float(data.interval)/attack_rate();combat_delay=5.0
	if class_id=="gunner" and game.feel.enabled: game.audio.play("ranger_draw",-22)
	if class_id in ["druid","healer"] and game.feel.enabled: game.audio.play("mage_gather",-20)
	visual.show_state("attack",facing,action_duration);visual.frame=0;return true

const SKILL_TARGET_RANGE := 430.0
const DRUID_ORDER_RADIUS := 96.0

func lord_slash_range() -> float:
	return 138.0 * (game.passive_engine.melee_range_scale() if game.passive_engine != null else 1.0)

func skill_target(point: Vector2) -> Vector2:
	var min_b := Vector2(0, 90)
	var max_b := Vector2(game.world_size())
	if domain == "rift":
		var rr: Rect2 = game.rift_domain.rift_world_rect() if game.rift_domain != null else Rect2(ArenaRiftDomain.RIFT_ORIGIN, Vector2(5600.0, 4200.0))
		min_b = rr.position + Vector2(40, 88)
		max_b = rr.end - Vector2(40, 30)
	return (position + (point-position).limit_length(SKILL_TARGET_RANGE)).clamp(min_b,max_b)

func can_cast(slot: int) -> bool:
	return skill_unlocked(slot) and not knocked_out and debuff_stun_clock <= 0.0 and game.running and not game.game_over and cooldowns[slot] <= 0.0 and (action not in ["small","ultimate"] or action_released)

func cast(slot: int, point: Vector2) -> bool:
	if not can_cast(slot):
		return false
	cancel_action()
	action_target = skill_target(point)
	if action_target.distance_to(position)>5.0:facing=position.direction_to(action_target)
	action="small" if slot==0 else "ultimate";action_clock=0;action_released=false
	action_duration=(0.30 if class_id=="gunner" else 0.44) if slot==0 else 0.62
	var base_cd := float(data.small_cd if slot==0 else data.ultimate_cd)
	if class_id=="gunner" and slot==0 and gunner_overdrive_clock>0.0:
		base_cd = ArenaDefinitions.GUNNER_OVERDRIVE_SLIDE_CD
	cooldowns[slot]=base_cd*cooldown_scale()
	cooldown_totals[slot] = cooldowns[slot]
	combat_delay=5.0
	if class_id=="gunner" and slot==0:
		roll_direction=Input.get_vector("move_left","move_right","move_up","move_down")
		if roll_direction.length()<0.1: roll_direction=facing
		rolling=0.26;protection=maxf(protection,0.32);empower_shot=1;game.blocking.release(self)
		perfect_dodge_window=PERFECT_DODGE_WINDOW;perfect_dodge_triggered=false
		if game.feel.enabled:
			game.effect(position+Vector2(0,-14),76,Color("68c6ff") if gunner_overdrive_clock>0 else Color("a8d2f0"),"gunner_slide",0.36,roll_direction)
			game.audio.play("ranger_roll",-11)
		_check_immediate_perfect_dodge(position)
	visual.show_state(action,facing,action_duration);visual.frame=0;return true
func _animation_frame() -> void:
	if game.feel.enabled and visual.animation.begins_with("walk") and visual.frame in [0,4] and foot_clock<=0:
		game.audio.play("footstep",-25);foot_clock=0.18
	if action!="" and not action_released and visual.frame>=ArenaActor.CONTACT_FRAME: release_action()
func _animation_finished() -> void:
	if not knocked_out and action!="" and action_released: cancel_action()

func _werewolf_lifesteal(dealt: float) -> void:
	if dealt <= 0.0: return
	var ratio := 0.0
	if werewolf_beast_clock > 0.0: ratio += 0.22
	if werewolf_bloodlust_clock > 0.0: ratio += 0.15
	if ratio > 0.0:
		_heal_self(dealt * ratio, false)

func release_action() -> void:
	if action_released or knocked_out or action=="": return
	action_released=true
	var power:=damage_scale()
	var hit:=attack_damage()
	var pe: ArenaPassiveEngine = game.passive_engine if game != null else null
	var ex_pierce: int = pe.extra_pierce() if pe != null else 0
	var ex_bounce: int = pe.extra_bounce() if pe != null else 0
	if action=="attack":
		shots+=1
		var basic_hit: Dictionary = {"rule_basic": true, "domain": domain, "per_attack": {}}
		var is_counter := counter_ready_clock > 0.0
		var is_crit: bool = is_counter or (pe != null and game.rng.randf() < pe.hero_crit_chance())
		var counter_stagger := 0.0
		if is_counter:
			counter_ready_clock = 0.0
			hit *= COUNTER_MULT
			basic_hit["crit"] = true
			basic_hit["counter"] = true
			counter_stagger = 0.40
		elif is_crit:
			hit *= pe.hero_crit_mult() if pe != null else 1.55
			basic_hit["crit"] = true
		var emit_origin := center() if class_id in ["lord", "werewolf"] else visual.emission_origin("attack")
		if game.event_bus != null:
			game.event_bus.emit_event("hero_attack", {"origin": emit_origin, "direction": facing, "damage": hit, "melee": class_id in ["lord", "werewolf"], "domain": domain})
		match class_id:
			"lord":
				var reach := attack_reach()
				var hit_primary: bool = is_instance_valid(action_enemy) and not action_enemy.dead and center().distance_to(action_enemy.center())<=reach+12.0
				if hit_primary:
					action_enemy.take_hit(hit,0,"hero",counter_stagger,0.0,0.0,"short_sword",facing,Vector2.INF,basic_hit)
				if domain == "rift" and game.rift_domain != null:
					game.rift_domain.damage_barrels_in_radius(position + facing * 48.0, reach * 0.65, hit, domain)
				# Wide frontal cleave for tank/swarm presence
				for foe in game.domain_enemies(domain):
					if is_instance_valid(foe) and foe!=action_enemy and not foe.dead and not (foe.has_method("is_flying") and foe.is_flying()):
						var rel: Vector2=foe.position-position
						if rel.length()<=reach+8.0 and (rel.length()<38.0 or rel.normalized().dot(facing)>0.15):
							foe.take_hit(hit*0.72,0,"hero",counter_stagger,0.0,0.0,"short_sword",facing,Vector2.INF,basic_hit)
				if is_counter:
					game.effect(position+facing*42.0+Vector2(0.0,-24.0),48.0,Color("ffe87a"),"hit",0.22,facing)
					game.audio.play("heavy_hit",-8,1.15)
				game.effect(position+facing*42+Vector2(0,-24),42.0*(pe.melee_range_scale() if pe != null else 1.0),Color("d94858"),"slash",0.18,facing)
				game.audio.play("blade",-5)
			"werewolf":
				var is_beast := werewolf_beast_clock > 0.0
				var reach := attack_reach()
				var total_dealt := 0.0
				if is_beast:
					# Wide ferocious ice-claw cleave hitting all enemies in frontal cone!
					if domain == "rift" and game.rift_domain != null:
						game.rift_domain.damage_barrels_in_radius(position + facing * 48.0, reach * 0.72, hit, domain)
					for foe in game.domain_enemies(domain):
						if not is_instance_valid(foe) or foe.dead or (foe.has_method("is_flying") and foe.is_flying()): continue
						var rel: Vector2 = foe.position - position
						if rel.length() <= reach and (rel.length() < 36.0 or rel.normalized().dot(facing) > 0.08):
							var d: float = foe.take_hit(hit, 0, "hero", counter_stagger, 0.0, 0.0, "werewolf_claw",facing,Vector2.INF,basic_hit)
							total_dealt += d
							if is_instance_valid(foe) and not foe.dead:
								foe.chill(0.24, 1.6)
					game.effect(position + facing * 48 + Vector2(0, -24), 58.0 * (pe.melee_range_scale() if pe != null else 1.0), Color("8ae8ff"), "slash", 0.22, facing)
					game.audio.play("heavy_hit", -11)
				else:
					if is_instance_valid(action_enemy) and not action_enemy.dead and center().distance_to(action_enemy.center()) <= reach + 12.0:
						var d: float = action_enemy.take_hit(hit, 0, "hero", counter_stagger, 0.0, 0.0, "werewolf_claw",facing,Vector2.INF,basic_hit)
						total_dealt += d
						if is_instance_valid(action_enemy) and not action_enemy.dead:
							action_enemy.chill(0.18, 1.3)
						var splash_r := 96.0 if werewolf_bloodlust_clock > 0.0 else 84.0
						var splash_ratio := 0.58 if werewolf_bloodlust_clock > 0.0 else 0.50
						for foe in game.domain_enemies(domain):
							if is_instance_valid(foe) and foe != action_enemy and not foe.dead and not (foe.has_method("is_flying") and foe.is_flying()) and foe.position.distance_to(action_enemy.position) <= splash_r:
								total_dealt += foe.take_hit(hit * splash_ratio, 0, "hero", counter_stagger, 0.0, 0.0, "werewolf_claw",facing,Vector2.INF,basic_hit)
					if domain == "rift" and game.rift_domain != null:
						game.rift_domain.damage_barrels_in_radius(position + facing * 44.0, reach * 0.65, hit, domain)
					game.effect(position + facing * 36 + Vector2(0, -22), 34, Color("9ce4ff"), "slash", 0.16, facing)
					game.audio.play("blade", -7)
				if is_counter:
					game.effect(position+facing*42.0+Vector2(0.0,-24.0),50.0,Color("ffe87a"),"hit",0.22,facing)
					game.audio.play("heavy_hit",-8,1.15)
				_werewolf_lifesteal(total_dealt)
			"gunner":
				var has_target: bool = is_instance_valid(action_enemy) and not action_enemy.dead
				var origin := visual.emission_origin("attack")
				var aim_dest: Vector2 = action_enemy.center() if has_target else origin + facing * attack_reach()
				var aim_dir := origin.direction_to(aim_dest)
				if aim_dir.is_zero_approx(): aim_dir = facing
				var shot_stagger := 0.30 if is_counter else 0.0
				if empower_shot > 0:
					empower_shot = 0
					var crit_mult := ArenaDefinitions.gunner_empower_multiplier(passive_rank)
					var emp_dmg := hit * crit_mult
					var twin := gunner_overdrive_clock > 0.0
					var count := 2 if twin else 1
					var perp := aim_dir.orthogonal()
					for s_i in range(count):
						var off := perp * ((float(s_i) - 0.5) * 14.0) if twin else Vector2.ZERO
						game.fire_projectile(origin + off, aim_dest + off, emp_dmg, 0, "hero", {
							"target": null, "speed": 960.0, "pierce": ArenaDefinitions.GUNNER_EMPOWER_PIERCE + ex_pierce, "bounce": ex_bounce, "splash": 68.0,
							"pen": 0.25, "stagger_on_hit": shot_stagger, "domain": domain,
							"appearance": "arrow", "presentation": "gunner_crit", "feedback": "pierce_arrow", "condition_hit": basic_hit
						})
					game.effect(origin, 28, Color("8be8ff"), "hit", 0.16, aim_dir)
					game.audio.play("heavy_hit", -12)
				else:
					game.fire_projectile(origin, aim_dest, hit, 0, "hero", {
						"target": action_enemy if (has_target and ex_pierce == 0) else null, "speed": 860.0,
						"pierce": 1 + ex_pierce, "bounce": ex_bounce,
						"stagger_on_hit": shot_stagger, "domain": domain,
						"appearance": "arrow", "presentation": "gunner", "feedback": "quick_arrow", "condition_hit": basic_hit
					})
					game.audio.play("ranger_release", -9)
			"druid":
				var has_target: bool = is_instance_valid(action_enemy) and not action_enemy.dead
				var origin := visual.emission_origin("attack")
				var aim_dest: Vector2 = action_enemy.center() if has_target else origin + facing * attack_reach()
				game.fire_projectile(origin, aim_dest, hit, 1, "hero", {
					"target": action_enemy if has_target else null, "splash": 72.0,
					"pierce": ex_pierce, "bounce": ex_bounce, "domain": domain,
					"stagger_on_hit": 0.30 if is_counter else 0.0,
					"appearance": "magic",
					"presentation": "druid", "feedback": "druid_orb", "condition_hit": basic_hit
				})
				game.audio.play("mage_cast", -9)
			"healer":
				var has_target: bool = is_instance_valid(action_enemy) and not action_enemy.dead
				var origin := visual.emission_origin("attack")
				var aim_dest: Vector2 = action_enemy.center() if has_target else origin + facing * attack_reach()
				game.fire_projectile(origin, aim_dest, hit, 1, "hero", {
					"target": action_enemy if (has_target and ex_pierce == 0) else null,
					"pierce": 1 + ex_pierce, "bounce": ex_bounce, "domain": domain,
					"stagger_on_hit": 0.30 if is_counter else 0.0,
					"appearance": "magic",
					"presentation": "healer", "feedback": "healer_orb", "condition_hit": basic_hit
				})
				_healer_hit_cnt += 1
				if _healer_hit_cnt % 4 == 0:
					_emit_healer_radiant_nova(150.0, 0.85)
				game.audio.play("mage_cast", -9)
	elif action=="small":
		match class_id:
			"lord":
				var q_dmg := hit * 2.45
				game.cone_damage(position, facing, lord_slash_range(), q_dmg, 0, "hero", 0.85, "small", {"domain": domain})
				game.effect(position + facing * 32, 122.0, Color("d84052"), "slash", 0.34, facing)
				game.audio.play("heavy_hit", -7)
			"druid":
				var target: Node2D = game.nearest_enemy(action_target, DRUID_ORDER_RADIUS, true, domain)
				for beast in companions:
					beast.command(action_target, target)
					beast.heal_percent(ArenaDefinitions.WOLF_ORDER_HEAL)
				game.effect(action_target, 56.0, Color("86e890"), "upgrade", 0.48)
				game.audio.play("mage_gather", -12, 1.15)
			"healer":
				_emit_healer_radiant_nova(205.0, 1.35)
				_heal_self(max_health * 0.14, true)
				healer_blessing_clock = 6.5
				healer_blessing_pos = position
				game.effect(position, 44.0, Color("f6a8c6"), "upgrade", 0.38)
				game.audio.play("mage_cast", -8)
			"werewolf":
				werewolf_bloodlust_clock = 6.0
				game.effect(position, 42.0, Color("7ee2ff"), "upgrade", 0.36)
				game.audio.play("phase", -10, 1.2)
			"gunner":
				if not game.feel.enabled:
					game.effect(position, 45, Color("88c8ff"), "roll", 0.3, roll_direction)
	elif action=="ultimate":
		match class_id:
			"lord":
				lord_shield_clock = 6.0
				lord_thorn_tick = 0.20
				overheal_shield = minf(max_shield_capacity(), overheal_shield + max_health * 0.45)
				game.effect(position, 46.0, Color("e0485a"), "upgrade", 0.40)
				game.audio.play("phase", -6)
			"druid":
				for beast in companions:
					beast.awaken(7.0)
				game.effect(position, 44.0, Color("76e888"), "upgrade", 0.40)
				game.audio.play("phase", -9, 0.85)
			"healer":
				healer_sanctuary_clock = 5.0
				healer_sanctuary_pos = position
				healer_sanctuary_tick = 0.05
				_emit_healer_radiant_nova(235.0, 1.55)
				game.effect(position, 48.0, Color("f8b4d0"), "upgrade", 0.42)
				game.audio.play("phase", -7, 1.15)
			"werewolf":
				werewolf_beast_clock = 8.0
				visual.set_form("werewolf_beast")
				game.area_damage(position, 125.0, hit * 1.45, 0, "hero", 0.4, 2.0, 0.0, 14.0, "werewolf_transform", false, {"domain": domain})
				game.effect(position, 82.0, Color("8eeeff"), "blast", 0.42)
				game.audio.play("heavy_hit", -6)
				game.audio.play("phase", -10, 0.78)
			"gunner":
				gunner_overdrive_clock = 6.0
				cooldowns[0] = 0.0
				empower_shot = 1
				game.effect(position, 42.0, Color("66d2ff"), "upgrade", 0.38)
				game.audio.play("phase", -7, 1.32)

func take_hit(amount: float, damage_type: int, melee := false, direction := Vector2.ZERO, direct_attack := true) -> float:
	if knocked_out or protection>0 or game.game_over: return 0.0
	var adjusted: float=amount
	if direct_attack and game.passive_engine != null:
		adjusted = game.passive_engine.guard_damage(adjusted)
	if melee and game.blocking.load_for(self)>0 and class_id=="lord":
		var lord_red: float = ArenaDefinitions.LORD_BLOCK_REDUCTION[passive_rank]
		adjusted *= 1.0 - lord_red
	if class_id=="lord" and lord_shield_clock>0.0:
		adjusted *= 0.65
	if war_cry>0: adjusted*=0.7
	var incoming:=minf(health+overheal_shield,ArenaCombat.resolve(adjusted,damage_type,0,0))
	var absorbed:=minf(overheal_shield,incoming);overheal_shield-=absorbed
	var taken:=incoming
	health-=(incoming-absorbed);combat_delay=5;hurt_time=0.24
	if incoming-absorbed>0 and game.has_method("note_hero_damage"): game.note_hero_damage(incoming-absorbed,position)
	game.audio.play("hurt");game.effect(center(),17,ArenaCombat.colour(damage_type),"hit",0.16)
	if game.feel.enabled:
		visual.feedback.impact(visual,false,direction)
		if class_id=="lord" and (lord_shield_clock>0 or (melee and game.blocking.load_for(self)>0)):
			game.effect(center(),18,Color("e85c6c"),"ward_contact",0.15,direction)
	if health<=0:
		_handle_ko()
	return taken

func _draw() -> void:
	draw_ellipse_shadow()
	if knocked_out: return
	var t_now := float(Time.get_ticks_msec()) * 0.004
	# Hero-specific organic pixel cues (zero cheap flat circles/rings)
	if class_id=="lord" and lord_shield_clock>0.0:
		for k in range(4):
			var a := t_now * 0.95 + float(k) * (PI * 0.5)
			var sp := Vector2(cos(a) * 24.0, -20.0 + sin(a) * 14.0).snapped(Vector2(2, 2))
			draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -5), sp + Vector2(4, 0), sp + Vector2(0, 5), sp + Vector2(-4, 0)]), Color("180c12", 0.88))
			draw_colored_polygon(PackedVector2Array([sp + Vector2(0, -3), sp + Vector2(2.5, 0), sp + Vector2(0, 3), sp + Vector2(-2.5, 0)]), Color("f45a6e"))
	elif class_id=="healer":
		if healer_sanctuary_clock>0.0:
			var sc := to_local(healer_sanctuary_pos)
			for p_i in range(16):
				var frac := (float(p_i) + 0.4) / 16.0
				var pr := 220.0 * sqrt(frac)
				var pa := float(p_i) * 2.39996 + t_now * 0.45
				var sway_y := sin(t_now * 1.4 + float(p_i)) * 6.0 - fmod(t_now * 4.5 + float(p_i) * 0.3, 12.0)
				var pp := (sc + Vector2(cos(pa) * pr, sin(pa) * pr * 0.56 + sway_y)).snapped(Vector2(2, 2))
				var p_col := Color("ffc2dc", 0.88) if p_i % 3 != 0 else Color("a8f4ba", 0.86)
				draw_rect(Rect2(pp - Vector2(3, 2), Vector2(6, 4)), Color("261422", 0.55))
				draw_rect(Rect2(pp - Vector2(2, 1.5), Vector2(4, 3)), p_col)
		elif healer_blessing_clock>0.0:
			var bc := to_local(healer_blessing_pos)
			for p_i in range(6):
				var age := fmod(t_now * 0.55 + float(p_i) * 0.17, 1.0)
				var pa := float(p_i) * 1.05 + t_now * 0.5
				var pp := (bc + Vector2(cos(pa) * 95.0 * (0.4 + 0.6 * fmod(float(p_i) * 0.37, 1.0)), sin(pa) * 52.0 - age * 14.0)).snapped(Vector2(2, 2))
				draw_rect(Rect2(pp - Vector2(2, 1.5), Vector2(4, 3)), Color("f8b8d6", (1.0 - age) * 0.82))
	elif class_id=="werewolf":
		if werewolf_beast_clock>0.0 or werewolf_bloodlust_clock>0.0:
			var w_col := Color("88ecff") if werewolf_beast_clock > 0.0 else Color("ff6e82")
			for i in range(4):
				var age := fmod(t_now * 0.9 + float(i) * 0.25, 1.0)
				var wp := Vector2(sin(t_now + float(i) * 1.7) * 18.0, -4.0 - age * 28.0).snapped(Vector2(2, 2))
				draw_rect(Rect2(wp - Vector2(2, 2), Vector2(4, 4)), Color("14111b", (1.0 - age) * 0.72))
				draw_rect(Rect2(wp - Vector2(1, 1), Vector2(2, 2)), Color(w_col.r, w_col.g, w_col.b, (1.0 - age) * 0.92))
	elif class_id=="gunner":
		if gunner_overdrive_clock>0.0:
			for i in range(4):
				var age := fmod(t_now * 1.2 + float(i) * 0.25, 1.0)
				var gp := Vector2(cos(float(i) * 1.6 + t_now) * 16.0, -6.0 - age * 26.0).snapped(Vector2(2, 2))
				draw_rect(Rect2(gp - Vector2(2, 2), Vector2(4, 4)), Color("141824", (1.0 - age) * 0.75))
				draw_rect(Rect2(gp - Vector2(1, 1), Vector2(2, 2)), Color("74d8ff" if i % 2 == 0 else "ffe97a", (1.0 - age) * 0.94))
		if empower_shot>0:
			var ep := Vector2(0.0, -visual.visual_size - 9.0).snapped(Vector2(2, 2))
			draw_line(ep - Vector2(5, 0), ep + Vector2(5, 0), Color("ffe97a"), 2.0, false)
			draw_line(ep - Vector2(0, 5), ep + Vector2(0, 5), Color("68d8ff"), 2.0, false)
			draw_rect(Rect2(ep - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)
	# Overhead shield bar if overheal_shield > 0
	if overheal_shield > 1.0:
		var bar_y := -visual.visual_size - 2.0
		var ratio := clampf(overheal_shield / maxf(1.0, max_health * 0.45), 0.0, 1.0)
		draw_rect(Rect2(-20, bar_y, 40, 4), Color(0.08, 0.10, 0.14, 0.85))
		draw_rect(Rect2(-20, bar_y, 40 * ratio, 4), Color("f26b7a") if class_id=="lord" else Color("98f5c4"))
	if debuff_slow_clock > 0.0:
		for s_i in [-1.0, 1.0]:
			var fp := Vector2(s_i * 10.0, 1.0).snapped(Vector2(2, 2))
			draw_colored_polygon(PackedVector2Array([fp + Vector2(-4, 2), fp + Vector2(0, -6), fp + Vector2(4, 2)]), Color("84adff", 0.90))
	if debuff_poison_clock > 0.0:
		var t_ms := float(Time.get_ticks_msec()) * 0.004
		for i in range(3):
			var p_off := Vector2(sin(t_ms + float(i) * 2.1) * 14.0, -14.0 - fmod(t_ms * 8.0 + float(i) * 9.0, 28.0)).snapped(Vector2(2, 2))
			draw_rect(Rect2(p_off - Vector2(2.5, 2.5), Vector2(5, 5)), Color("6ae874", 0.88))
	if debuff_bleed_clock > 0.0:
		for i in range(2):
			var b_off := Vector2(-8.0 + float(i) * 16.0, -10.0)
			draw_line(b_off, b_off + Vector2(0.0, 7.0), Color("ee4e62", 0.9), 2.2, true)
	if debuff_stun_clock > 0.0:
		var s_t := float(Time.get_ticks_msec()) * 0.008
		for i in range(3):
			var a := s_t + float(i) * (TAU / 3.0)
			var sp := Vector2(cos(a) * 14.0, -visual.visual_size - 6.0 + sin(a) * 4.0).snapped(Vector2(2, 2))
			draw_rect(Rect2(sp - Vector2(2.5, 2.5), Vector2(5, 5)), Color("ffe270"))
	if counter_ready_clock > 0.0:
		var pulse := 0.78 + 0.22 * sin(float(Time.get_ticks_msec()) * 0.014)
		for k in range(3):
			var age := fmod(t_now * 1.4 + float(k) * 0.33, 1.0)
			var cp := Vector2(sin(float(k) * 2.1 + t_now) * 14.0, -6.0 - age * 28.0).snapped(Vector2(2, 2))
			draw_rect(Rect2(cp - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.90, 0.48, (1.0 - age) * 0.92 * pulse))
		var star_pt := Vector2(0.0, -visual.visual_size - 12.0)
		draw_line(star_pt - Vector2(6.0, 0.0), star_pt + Vector2(6.0, 0.0), Color("ffe97a"), 2.0, false)
		draw_line(star_pt - Vector2(0.0, 6.0), star_pt + Vector2(0.0, 6.0), Color("ffe97a"), 2.0, false)
		draw_rect(Rect2(star_pt - Vector2(2.0, 2.0), Vector2(4, 4)), Color("7ef4ff"))
	# v0.31 Auto-aim Target Reticle Ring
	if is_instance_valid(_auto_target_preview) and not _auto_target_preview.dead and str(_auto_target_preview.domain) == domain and not game.feel_lab and not game.tower_lab:
		var t_loc := to_local(_auto_target_preview.position).snapped(Vector2(2, 2))
		var r_pulse := 16.0 + 2.5 * sin(t_now * 2.2)
		var ret_col := Color(data.colour, 0.72)
		draw_set_transform(t_loc, 0.0, Vector2(1.0, 0.56))
		draw_arc(Vector2.ZERO, r_pulse, 0.0, TAU, 24, Color("14111b", 0.65), 3.0, false)
		draw_arc(Vector2.ZERO, r_pulse, 0.0, TAU, 24, ret_col, 1.6, false)
		draw_set_transform(Vector2.ZERO)
	# v0.31 Orbiting Pixel Blades (from orbit_blades passive using custom pixel sprites)
	if game != null and game.passive_engine != null and game.passive_engine.rank("orbit_blades") > 0:
		var evo_b: bool = game.passive_engine.is_evo("orbit_blades")
		if _blade_cyan_tex == null and ResourceLoader.exists("res://assets/vfx_v031/vfx_blade_cyan.png"):
			_blade_cyan_tex = load("res://assets/vfx_v031/vfx_blade_cyan.png") as Texture2D
		if _blade_gold_tex == null and ResourceLoader.exists("res://assets/vfx_v031/vfx_blade_gold.png"):
			_blade_gold_tex = load("res://assets/vfx_v031/vfx_blade_gold.png") as Texture2D
		var b_tex: Texture2D = _blade_gold_tex if evo_b else _blade_cyan_tex
		var b_col := Color("ffe878") if evo_b else Color("7cf2ff")
		for wp: Vector2 in game.passive_engine.blade_positions(position):
			var lp := to_local(wp).snapped(Vector2(2, 2))
			var dir_v := lp.orthogonal().normalized()
			if b_tex != null:
				var b_sz := 44.0 if evo_b else 36.0
				draw_set_transform(lp, dir_v.angle())
				draw_texture_rect(b_tex, Rect2(-Vector2.ONE * b_sz * 0.5, Vector2.ONE * b_sz), false, Color(1.0, 1.0, 1.0, 0.96))
				draw_set_transform(Vector2.ZERO)
			else:
				var tip := lp + dir_v * (12.0 if evo_b else 9.0)
				var tail := lp - dir_v * (9.0 if evo_b else 7.0)
				var side := lp.normalized() * (6.0 if evo_b else 4.5)
				draw_colored_polygon(PackedVector2Array([tip, lp + side, tail, lp - side]), Color("101622"))
				draw_colored_polygon(PackedVector2Array([tip - dir_v * 2.0, lp + side * 0.72, tail + dir_v * 2.0, lp - side * 0.72]), b_col)
				draw_rect(Rect2(lp - Vector2(2, 2), Vector2(4, 4)), Color.WHITE)
	# v0.30 Overhead Crisis Alert while in Rift when Defense Core is endangered
	if domain == "rift" and game != null and game.rift_domain != null and game.rift_domain.alarm_level >= 2:
		var blink := 0.55 + 0.45 * sin(float(Time.get_ticks_msec()) * 0.018)
		var ay := -visual.visual_size - 24.0
		var tri := PackedVector2Array([Vector2(0, ay - 16), Vector2(12, ay + 4), Vector2(-12, ay + 4)])
		draw_colored_polygon(tri, Color("1a0810", 0.95))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(1.0, 0.25, 0.30, blink), 2.2)
		draw_rect(Rect2(-1.5, ay - 10.0, 3.0, 8.0), Color("ffe878", blink))
		draw_rect(Rect2(-1.5, ay - 0.5, 3.0, 3.0), Color("ffe878", blink))
func draw_ellipse_shadow() -> void:
	var visual_scale: float=game.feel.unit_scale if game.feel.enabled else 1.0
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.4));draw_circle(Vector2.ZERO,17*visual_scale,Color(0.08,0.14,0.1,0.35));draw_set_transform(Vector2.ZERO)
