class_name ArenaHero
extends CharacterBody2D
var game: Node2D
var class_id: String="lord"
var data: Dictionary={}
var health:=420.0
var max_health:=420.0
var level:=1
var xp:=0
var xp_target:=60
var perks: Dictionary={}
var mods: Dictionary={}
var cooldowns: Array[float]=[0.0,0.0]
var attack_cooldown:=0.0
var push_attack := false
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
var echo_clock:=0.0
var enchant_clock:=0.0
var overload_clock:=0.0
var roll_boost_clock:=0.0
var combo_count:=0
var passive_combo_target: Node2D
var passive_combo_stacks:=0
var passive_combo_time:=-1.0
var passive_rebuke_clock:=0.0
var passive_q_clock:=0.0
var conditions: ArenaConditions
var condition_hit: Dictionary={}
var windup_hold:=0.0
var windup_ready:=false
var heavy_attack:=false
var death_saved:=false
var overheal_shield:=0.0
var rapid_count:=0
var last_target_id:=0
var block_boost_clock:=0.0
var revive_block_clock:=0.0
var revive_halved:=false
# New 5-hero dedicated state clocks
var lord_shield_clock:=0.0
var lord_thorn_tick:=0.0
var healer_blessing_clock:=0.0
var healer_blessing_pos:=Vector2.ZERO
var healer_sanctuary_clock:=0.0
var healer_sanctuary_pos:=Vector2.ZERO
var healer_sanctuary_tick:=0.0
var werewolf_bloodlust_clock:=0.0
var werewolf_beast_clock:=0.0
var gunner_overdrive_clock:=0.0
# Universal short dodge & hero debuffs (v0.23)
const DODGE_CD := 5.0
const DODGE_DURATION := 0.14
const DODGE_SPEED := 420.0
const DODGE_IFRAME := 0.22
var dodge_cooldown := 0.0
var dodge_left := 0.0
var dodge_direction := Vector2.RIGHT
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

const MILESTONE_LEVELS: Array[int]=[2,5,8]
const AWAKEN_SKIP_MULT: Array[String]=["execute_threshold","full_hp_threshold","combo_every","death_save","block_bonus","pierce_bonus","unyield","fortress","warmachine","warcredit","goldenage","citywall","overload","bloodrage","sworddance","starcore"]
var awakened_perks: Dictionary={}
var meta_level:=1
var meta_health:=0.0
var meta_attack:=0.0
var passive_rank:=0
var foot_clock:=0.0
var chrono_clock:=0.0
var chrono_hits:=0
var companions: Array[Node2D]=[]

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
	if game.condition_lab:
		conditions=ArenaConditions.new(game.passive_ranks)
		xp_target=45
	meta_health=float(bonus.health);meta_attack=float(bonus.attack);passive_rank=int(bonus.passive)
	max_health=float(data.health)
	meta_cooldown=0.0
	lord_shield_clock=0.0;lord_thorn_tick=0.0
	healer_blessing_clock=0.0;healer_sanctuary_clock=0.0;healer_sanctuary_tick=0.0
	werewolf_bloodlust_clock=0.0;werewolf_beast_clock=0.0
	gunner_overdrive_clock=0.0;empower_shot=0;overheal_shield=0.0
	dodge_cooldown=0.0;dodge_left=0.0
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

func skill_unlocked(slot: int) -> bool: return slot in [0,1] and meta_level>=(2 if slot==0 else 4)
func has_keystone(key: String) -> bool: return game!=null and game.has_keystone(key)
func center() -> Vector2: return position+Vector2(0,-30)
func can_hit_flying() -> bool: return class_id in ["druid","healer","gunner"]
func block_capacity() -> int:
	var lord_extra := 1 if (class_id=="lord" and lord_shield_clock>0.0) else 0
	return int(data.get("block",1))+lord_extra+int(mod("block_bonus"))+(1 if mod("fortress")>0 else 0)+(2 if has_keystone("bastion_ward") else 0)
func can_block() -> bool: return not knocked_out and rolling<=0 and dodge_left<=0 and debuff_stun_clock<=0 and velocity.length()<35 and game.orders.transfer_left<=0
func perk(key: String) -> int: return int(perks.get(key,0))
func mod(key: String) -> float: return float(mods.get(key,0.0))
func has_mod(key: String) -> bool: return mod(key)>0.0
func has_link(a: String, b: String) -> bool: return perk(a)>0 and perk(b)>0
func effective_perk_rank(key: String) -> int:
	var rank:=perk(key)
	if rank>0 and bool(awakened_perks.get(key,false)):
		var card: Dictionary=ArenaPerks.card(key)
		return maxi(rank,int(card.get("max",rank)))
	return rank

func max_shield_capacity() -> float:
	var base_cap := mod("shield_cap")
	if class_id == "lord":
		base_cap = maxf(base_cap, max_health * 0.60)
	elif class_id == "healer":
		base_cap = maxf(base_cap, max_health * 0.45)
	return base_cap

func recompute() -> void:
	mods={}
	for key in perks:
		var rank:=int(perks[key])
		var card: Dictionary=ArenaPerks.card(str(key))
		if card.is_empty(): continue
		var effects: Array=card.get("effects",[])
		var awakened:=bool(awakened_perks.get(str(key),false))
		var cap: int=effects.size() if awakened else mini(rank,effects.size())
		for index in range(cap):
			var effect: Dictionary=effects[index]
			for stat in effect:
				var mult: float=1.25 if awakened and not (str(stat) in AWAKEN_SKIP_MULT) else 1.0
				mods[stat]=float(mods.get(stat,0.0))+float(effect[stat])*mult
	for link in ArenaPerks.LINKS:
		if ArenaPerks.is_real_link(str(link.from),str(link.to)): continue
		if perk(str(link.from))>0 and perk(str(link.to))>0:
			for stat in link.bonus:
				mods[stat]=float(mods.get(stat,0.0))+float(link.bonus[stat])
	for item in ArenaPerks.SETS:
		var active:=false
		if item.has("members"):
			active=true
			for card_id in item.members:
				if perk(str(card_id))<=0: active=false;break
		elif item.has("axis"):
			active=_axis_count(str(item.axis))>=int(item.get("need",3))
		elif bool(item.get("cross",false)):
			var hits:=0
			for axis in ["blade","star","bulwark","command"]:
				if _axis_count(str(axis))>=2: hits+=1
			active=hits>=2
		if active:
			for stat in item.bonus:
				mods[stat]=float(mods.get(stat,0.0))+float(item.bonus[stat])
	if has_link("lifesteal","tough"): mods["shield_cap"]=mod("shield_cap")*1.5
	var level_growth:=0.04*float(maxi(0,level-1))
	var target:=float(data.health)*(1.0+meta_health+level_growth+mod("max_hp"))
	if conditions!=null:
		var ratio:=health/max_health
		max_health=target*(1.0+conditions.max_health_bonus())
		health=clampf(ratio*max_health,0.0,max_health)
		return
	var delta:=target-max_health
	max_health=target
	if not knocked_out and absf(delta)>0.001: health=clampf(health+delta,0.0,max_health)
	overheal_shield=minf(overheal_shield,max_shield_capacity())

func _axis_count(axis: String) -> int:
	var total:=0
	for key in perks:
		if int(perks[key])>0:
			var card: Dictionary=ArenaPerks.card(str(key))
			if str(card.get("axis",""))==axis: total+=1
	return total

func damage_scale() -> float:
	var result:=1.0+mod("damage")
	var low_threshold:=0.6 if has_link("bloodrage","battlewill") else 0.5
	if health<max_health*low_threshold: result+=mod("low_hp_damage")
	var bloodrage:=mod("bloodrage")
	if has_link("battlewill","bloodrage"): bloodrage+=0.2
	result+=bloodrage*clampf(1.0-health/max_health,0.0,1.0)
	if war_cry>0: result*=1.35
	if class_id=="healer" and healer_blessing_clock>0.0 and position.distance_to(healer_blessing_pos)<=205.0:
		result*=1.15
	if class_id=="werewolf" and werewolf_beast_clock>0.0:
		result*=1.30
	return result

func execute_threshold() -> float:
	return mod("execute_threshold")+(0.05 if has_link("pierce","execute") else 0.0)
func full_hp_threshold() -> float: return 0.7 if has_link("power","execute") else 1.0
func attack_damage_against(enemy: Node2D, base: float) -> float:
	var damage:=base
	if mod("full_hp_bonus")>0 and enemy.health>=enemy.max_health*full_hp_threshold():
		damage*=1.0+mod("full_hp_bonus")
	if enemy.health<enemy.max_health*execute_threshold(): damage*=1.0+mod("execute_bonus")
	if (enemy.elite or enemy.is_boss() or (enemy.has_method("is_mini_boss") and enemy.is_mini_boss())) and mod("elite_bonus")>0: damage*=1.0+mod("elite_bonus")
	if enchant_clock>0 and enemy.exposure>0 and has_link("enchant","starlight"): damage*=1.0+mod("enchant")*0.1
	if game.passive_lab:
		var break_rank: int=game.passive_rank("break")
		if break_rank>0 and enemy.slow>0.0: damage*=1.0+0.2*float(break_rank)
		var desperate_rank: int=game.passive_rank("desperate")
		if desperate_rank>0 and health<=max_health*0.4: damage*=1.0+0.3*float(desperate_rank)
		var combo_rank: int=game.passive_rank("combo")
		if combo_rank>0:
			if enemy==passive_combo_target and game.elapsed-passive_combo_time<2.0: passive_combo_stacks=mini(5,passive_combo_stacks+1)
			else: passive_combo_stacks=1
			passive_combo_target=enemy;passive_combo_time=game.elapsed
			damage*=1.0+0.06*float(passive_combo_stacks)*float(combo_rank)
	return damage

func attack_damage() -> float:
	var scale:=damage_scale()
	if echo_clock>0: scale+=mod("echo")*(2.0 if overload_clock>0 and has_link("echo","overload") else 1.0)
	if enchant_clock>0: scale+=mod("enchant")
	if overheal_shield>0 and has_link("lifesteal","combo"): scale+=0.15
	if has_keystone("overload_core"): scale*=1.0+0.08*float(mini(4,game.resonance_casts))
	var level_growth:=0.04*float(maxi(0,level-1))
	return float(data.damage)*(1.0+meta_attack+level_growth)*scale+mod("flat")

func attack_reach() -> float:
	var base := float(data.reach)
	if class_id == "werewolf" and werewolf_beast_clock > 0.0:
		return 128.0
	if class_id == "gunner" and gunner_overdrive_clock > 0.0:
		return base * 1.25
	return base

func armor_pen() -> float: return clampf(mod("armor_pen"),0.0,0.6)
func skill_scale() -> float:
	var result:=1.0+mod("skill")
	if has_link("focus","starlight"): result+=mod("cooldown")*0.3
	if overload_clock>0 and mod("overload")>0: result+=0.20
	if passive_q_clock>0.0 and action=="small" and game!=null and game.passive_lab: result*=1.4+0.2*float(maxi(0,game.passive_rank("doublecast")-1))
	return result

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
	return healed

func heal_on_kill() -> void:
	if knocked_out: return
	var heal:=mod("lifesteal")
	if heal<=0: return
	_heal_self(heal, mod("shield_cap") > 0.0)

func note_kill(low_health: bool) -> void:
	if not low_health: return
	if has_link("execute","combo"): combo_count+=1
	if has_link("execute","enchant"): enchant_clock=3.0
func note_pierce_hit() -> void:
	if has_link("piercearrow","combo"): combo_count+=1

func war_cry_radius() -> float: return 240.0+(80.0 if mod("war_cry_bonus")>0 else 0.0)
func command_radius() -> float: return 240.0+(40.0 if has_link("farsight","command") else 0.0)
func warcredit_stacks() -> int:
	if mod("warcredit")<=0: return 0
	return mini(5,int(game.kills/10))

func command_aura(point: Vector2) -> float:
	if knocked_out: return 0.0
	var value := 0.0
	if position.distance_to(point) <= command_radius():
		value = mod("command_aura")
		if has_link("warcredit","command"): value += 0.02 * float(warcredit_stacks())
		if war_cry > 0 and has_link("oath","command"): value *= 2.0
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

func citywall_reduction() -> float:
	if mod("citywall")<=0: return 0.0
	var reduction:=minf(0.08,0.02*float(game.towers.size()))
	if has_link("citywall","command"):
		var count:=0
		for tower in game.towers:
			if is_instance_valid(tower) and position.distance_to(tower.position)<=command_radius(): count+=1
		reduction+=0.01*float(count)
	return reduction

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

func try_dodge(preferred_dir := Vector2.ZERO) -> bool:
	if knocked_out or game == null or game.game_over or not game.running:
		return false
	if dodge_cooldown > 0.0 or dodge_left > 0.0 or rolling > 0.0 or debuff_stun_clock > 0.0:
		return false
	var move_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_dir.length() > 0.1:
		dodge_direction = move_dir.normalized()
	elif preferred_dir.length() > 0.1:
		dodge_direction = preferred_dir.normalized()
	else:
		dodge_direction = facing.normalized() if facing.length() > 0.05 else Vector2.RIGHT
	dodge_left = DODGE_DURATION
	dodge_cooldown = DODGE_CD
	protection = maxf(protection, DODGE_IFRAME)
	path.clear()
	game.blocking.release(self)
	if game.feel.enabled:
		game.effect(position + Vector2(0, -14), 38, Color("c4f0ff"), "dodge_step", 0.24, dodge_direction)
		game.audio.play("ranger_roll", -15, 1.28)
	queue_redraw()
	return true

func _handle_ko() -> void:
	if mod("death_save") > 0 and not death_saved:
		death_saved = true; health = 1.0; protection = 2.0
		if has_link("unyield", "revive"): revive_halved = true
		return
	var revive_time := maxf(1.0, 15.0 - mod("revive_reduce"))
	if revive_halved: revive_time *= 0.5
	health = 0; knocked_out = true; revive_clock = revive_time; velocity = Vector2.ZERO
	rolling = 0; dodge_left = 0.0; path.clear(); queued_attack_point = Vector2.INF
	cancel_action(); clear_debuffs(); game.blocking.release(self)
	if conditions!=null: conditions.reset_stance()
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

func cooldown_scale() -> float: return 1.0-minf(0.30,meta_cooldown+mod("cooldown"))
func command_move(target: Vector2) -> void:
	if knocked_out or debuff_stun_clock > 0.0: return
	path=game.navigation_path(position,target)
func cancel_action() -> void:
	push_attack=false
	action="";action_enemy=null;action_clock=0;action_released=false;visual.feedback.stop_left=0.0
	condition_hit={}
func _physics_process(delta: float) -> void:
	if not game.running or game.game_over or game.orders.transfer_left>0.0: return
	if game.input_blocked(): queued_attack_point=Vector2.INF
	for slot in range(2): cooldowns[slot]=maxf(0,cooldowns[slot]-delta)
	attack_cooldown=maxf(0,attack_cooldown-delta);combat_delay=maxf(0,combat_delay-delta)
	foot_clock=maxf(0.0,foot_clock-delta)
	dodge_cooldown=maxf(0.0,dodge_cooldown-delta)
	protection=maxf(0,protection-delta);war_cry=maxf(0,war_cry-delta);hurt_time=maxf(0,hurt_time-delta)
	echo_clock=maxf(0,echo_clock-delta);enchant_clock=maxf(0,enchant_clock-delta);overload_clock=maxf(0,overload_clock-delta);roll_boost_clock=maxf(0,roll_boost_clock-delta);chrono_clock=maxf(0.0,chrono_clock-delta)
	block_boost_clock=maxf(0,block_boost_clock-delta);revive_block_clock=maxf(0,revive_block_clock-delta)
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

	passive_rebuke_clock=maxf(0.0,passive_rebuke_clock-delta);passive_q_clock=maxf(0.0,passive_q_clock-delta)
	if knocked_out:
		if class_id == "werewolf" and visual.active_form != "werewolf":
			visual.set_form("werewolf")
		revive_clock=maxf(0,revive_clock-delta)
		if revive_clock<=0:
			knocked_out=false;health=max_health;protection=1.5;revive_block_clock=3.0
			position=game.level_definition.hero_spawn
			cancel_action();visual.show_state("idle",Vector2.LEFT)
		queue_redraw();return

	# Lord E blood-thorn periodic counter-damage ring while shield active
	if class_id == "lord" and lord_shield_clock > 0.0:
		lord_thorn_tick -= delta
		if lord_thorn_tick <= 0.0:
			lord_thorn_tick = 1.0
			var thorn_dmg := 16.0 * damage_scale()
			var hit_any := false
			for enemy in game.enemies:
				if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(position) <= 108.0:
					enemy.take_hit(thorn_dmg, 0, "hero", 0.0, 0.0, 0.0, "lord_thorn", position.direction_to(enemy.position))
					hit_any = true
			if hit_any:
				game.effect(position, 106.0, Color("d84c5c"), "blast", 0.24)

	# Healer E blooming sanctuary periodic heal + shield overflow
	if class_id == "healer" and healer_sanctuary_clock > 0.0:
		healer_sanctuary_tick -= delta
		if healer_sanctuary_tick <= 0.0:
			healer_sanctuary_tick = 0.5
			if position.distance_to(healer_sanctuary_pos) <= 245.0:
				var amt := max_health * 0.075
				var healed := _heal_self(amt, true)
				if healed > 1.0:
					game.numbers.append({"point":center()+Vector2(0,-18),"text":"+"+str(int(round(healed))),"colour":Color("8ff2a8"),"life":0.55,"duration":0.55})
			for soldier in game.soldiers:
				if is_instance_valid(soldier) and not soldier.dead and soldier.position.distance_to(healer_sanctuary_pos) <= 245.0:
					soldier.health = minf(soldier.max_health, soldier.health + soldier.max_health * 0.14)

	if game.blocking.load_for(self)>0: combat_delay=5.0
	if combat_delay<=0: health=minf(max_health,health+max_health*0.08*delta)
	if has_keystone("bastion_ward"): health=minf(max_health,health+max_health*0.025*delta)
	if mod("fortress")>0 and game.blocking.load_for(self)>0: health=minf(max_health,health+max_health*0.02*delta)

	var move:=Input.get_vector("move_left","move_right","move_up","move_down")
	if move.length()>0.05: path.clear()
	elif not path.is_empty():
		while not path.is_empty() and position.distance_to(path[0])<10.0: path.remove_at(0)
		if not path.is_empty():
			move=(path[0]-position).normalized()
	var previous_position:=position
	if rolling>0:
		rolling=maxf(0,rolling-delta);velocity=roll_direction*540.0;move_and_slide()
		position=position.clamp(Vector2(15,95),game.world_size()-Vector2(15,20))
		if rolling<=0.0: velocity=Vector2.ZERO
		if rolling==0 and game.feel.enabled and not bool(game.campaign.data.reduced_motion):
			ArenaBattleArt.emit_world_dust(position,-roll_direction*32,21,Color("a4d8ff") if gunner_overdrive_clock>0 else Color("bcb198"))
		if conditions!=null: conditions.update_movement(delta,0.0,true)
		queue_redraw();return
	if dodge_left>0.0:
		dodge_left=maxf(0.0,dodge_left-delta);velocity=dodge_direction*DODGE_SPEED;move_and_slide()
		position=position.clamp(Vector2(15,95),game.world_size()-Vector2(15,20))
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
	if chrono_clock>0.0: move_mult*=1.20
	if class_id=="werewolf" and werewolf_beast_clock>0.0: move_mult*=1.20
	if class_id=="gunner" and gunner_overdrive_clock>0.0: move_mult*=1.20
	if debuff_slow_clock>0.0: move_mult*=maxf(0.35, 1.0-debuff_slow_amount)
	var desired: Vector2=move*float(data.speed)*move_mult
	if conditions!=null: desired*=1.0+conditions.move_bonus(health/max_health)
	velocity=Vector2.ZERO if planted else velocity.move_toward(desired,(2600.0 if move.length()>0.1 else 4800.0)*delta)
	move_and_slide()
	position=position.clamp(Vector2(15,95),game.world_size()-Vector2(15,20))
	if conditions!=null:
		var wants_move:=move.length_squared()>0.01
		var action_displaces:=planted
		var input_speed:=position.distance_to(previous_position)/delta if wants_move and not action_displaces and delta>0.0 else 0.0
		conditions.update_movement(delta,input_speed,false,wants_move,action_displaces)
		conditions.scan_soldiers(position,game.soldiers,delta)
	if action=="":
		visual.show_state("hurt" if hurt_time>0 else ("walk" if velocity.length()>5 else "idle"),facing,0.24)
		if hurt_time<=0 and velocity.length()>5: visual.stride(velocity.length())
	elif action=="attack" and not action_released and is_instance_valid(action_enemy) and not action_enemy.dead:
		action_target=action_enemy.center()
		if action_enemy.position.distance_to(position)>4.0:
			facing=(action_enemy.position-position).normalized()
	var can_primary: bool=not game.input_blocked() and not game.suppress_primary
	var hold_shoot: bool=can_primary and (game.mouse_shoot_held or Input.is_action_pressed("shoot"))
	var player_whiff: bool=can_primary and (game.mouse_shoot_held or queued_attack_point!=Vector2.INF)
	if (hold_shoot or player_whiff) and attack_cooldown<=0 and action=="":
		var aim_pt: Vector2=queued_attack_point if queued_attack_point!=Vector2.INF else game.mouse_world()
		queued_attack_point=Vector2.INF
		var enemy: Node2D=select_attack_target(aim_pt)
		if enemy!=null:
			begin_attack(enemy,aim_pt)
		elif player_whiff:
			begin_attack(null,aim_pt)
	if game.passive_lab and game.passive_rank("windup")>0:
		if Input.is_action_pressed("shoot") and not game.input_blocked() and not game.suppress_primary:
			windup_hold+=delta
			if windup_hold>=0.8:windup_hold-=0.8;windup_ready=true
		else:windup_hold=0.0;windup_ready=false
	var reduced:=bool(game.campaign.data.reduced_motion)
	visual.feedback.reduced=reduced
	visual.modulate=Color.WHITE if hurt_time>0 else Color(1,1,1,0.62 if not reduced and protection>0 and fmod(protection,0.16)<0.08 else 1.0)
	queue_redraw()

func attack_rate() -> float:
	var chrono_bonus: float=0.55 if chrono_clock>0.0 else 0.0
	var altar_bonus: float=game.hero_overclock_bonus() if game!=null and game.has_method("hero_overclock_bonus") else 0.0
	var hero_bonus: float=0.0
	if class_id=="healer" and healer_blessing_clock>0.0 and position.distance_to(healer_blessing_pos)<=210.0:
		hero_bonus+=0.20
	if class_id=="werewolf":
		if werewolf_bloodlust_clock>0.0: hero_bonus+=0.35
		if werewolf_beast_clock>0.0: hero_bonus+=0.55
	return 1.0+mod("attack_speed")+(mod("roll_boost") if roll_boost_clock>0 else 0.0)+(0.4 if overload_clock>0 and mod("overload")>0 else 0.0)+chrono_bonus+altar_bonus+hero_bonus+(conditions.attack_speed_bonus() if conditions!=null else 0.0)

func rapid_every() -> int:
	return 4 if has_link("rapid","power") else 5

func select_attack_target(aim_point: Vector2) -> Node2D:
	var reach := attack_reach()
	var can_aa := can_hit_flying()
	var has_aim:=aim_point!=Vector2.INF and aim_point.distance_to(position)>8.0
	var aim_dir:=(aim_point-position).normalized() if has_aim else facing
	var best: Node2D=null
	var best_score:=INF
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		if not can_aa and enemy.has_method("is_flying") and enemy.is_flying(): continue
		var d: float=center().distance_to(enemy.center())
		if d>reach: continue
		var dir: Vector2=(enemy.position-position).normalized()
		var align: float=1.0-0.38*maxf(0.0,dir.dot(aim_dir))
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
	var target_id:=int(enemy.get_instance_id()) if has_enemy else 0
	if has_enemy and target_id!=last_target_id:
		if mod("combo_every")>0: combo_count=maxi(1,combo_count-1)
		else: combo_count=0
		last_target_id=target_id
	var target_pt: Vector2=enemy.center() if has_enemy else aim_point
	if target_pt.distance_to(position)>4.0:
		facing=(target_pt-position).normalized()
	action="attack";action_enemy=enemy if has_enemy else null;action_target=target_pt
	action_duration=minf(0.36,float(data.interval)/attack_rate()*0.72);action_clock=0;action_released=false
	if conditions!=null: condition_hit=conditions.attack_context()
	attack_cooldown=float(data.interval)/attack_rate();combat_delay=5.0
	if game.passive_lab and game.passive_rank("windup")>0 and windup_ready:
		windup_ready=false;heavy_attack=true
	if class_id=="gunner" and game.feel.enabled: game.audio.play("ranger_draw",-22)
	if class_id in ["druid","healer"] and game.feel.enabled: game.audio.play("mage_gather",-20)
	visual.show_state("attack",facing,action_duration);visual.frame=0;return true

func cast(slot: int, point: Vector2) -> bool:
	if slot<0 or slot>1 or knocked_out or debuff_stun_clock>0.0 or game.game_over or not game.running or cooldowns[slot]>0: return false
	if not skill_unlocked(slot): return false
	if action in ["small","ultimate"] and not action_released: return false
	cancel_action()
	var relative:=point-position
	if relative.length()>430: point=position+relative.normalized()*430
	action_target=point.clamp(Vector2(0,90),game.world_size());facing=(point-position).normalized() if relative.length()>5 else facing
	action="small" if slot==0 else "ultimate";action_clock=0;action_released=false
	action_duration=(0.30 if class_id=="gunner" else 0.44) if slot==0 else 0.62
	var base_cd := float(data.small_cd if slot==0 else data.ultimate_cd)
	if class_id=="gunner" and slot==0 and gunner_overdrive_clock>0.0:
		base_cd = 2.0
	cooldowns[slot]=base_cd*cooldown_scale()
	if conditions!=null: condition_hit=conditions.attack_context()
	if game.passive_lab:
		var ice_rank: int=game.passive_rank("icetrace")
		if ice_rank>0 and slot==0: game.add_zone(point,90.0+30.0*float(ice_rank-1),10.0*float(ice_rank),2.0,int(data.type),"hero")
		if slot==1 and game.passive_rank("doublecast")>0: passive_q_clock=1.5+0.5*float(game.passive_rank("doublecast")-1)
	combat_delay=5.0
	if role("echo")>0: echo_clock=3.0
	if role("enchant")>0: enchant_clock=3.0
	if slot==1 and role("overload")>0: overload_clock=6.0
	if slot==1 and has_link("overload","focus"):
		var recovery:=1.0+(1.0 if perk("focus")>0 else 0.0)
		cooldowns[0]=maxf(0.0,cooldowns[0]-recovery)
		cooldowns[1]=maxf(0.0,cooldowns[1]-recovery)
	if class_id=="gunner" and slot==0:
		roll_direction=Input.get_vector("move_left","move_right","move_up","move_down")
		if roll_direction.length()<0.1: roll_direction=facing
		rolling=0.26;protection=maxf(protection,0.32);empower_shot=1;game.blocking.release(self)
		if conditions!=null: conditions.update_movement(0.0,0.0,true)
		if game.passive_lab and game.passive_rank("afterimage")>0:
			game.add_slow_zone(position,80.0+30.0*float(game.passive_rank("afterimage")-1),1.5,0.5)
		if role("shadowstep")>0: roll_boost_clock=2.0
		if has_link("shadowstep","rapid"): rapid_count+=1
		if game.feel.enabled:
			game.effect(position+Vector2(0,-14),76,Color("68c6ff") if gunner_overdrive_clock>0 else Color("a8d2f0"),"gunner_slide",0.36,roll_direction)
			game.audio.play("ranger_roll",-11)
	if has_keystone("chrono") and slot==0: chrono_clock=4.5
	if has_keystone("conduit"): game.trigger_conduit(position,attack_damage()*1.1+45.0)
	visual.show_state(action,facing,action_duration);visual.frame=0;return true

func role(key: String) -> float: return mod(key)
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
	if push_attack and action=="attack":
		push_attack=false
		if not is_instance_valid(action_enemy) or not game.orders.push(action_enemy):
			attack_cooldown=0
		return
	var power:=damage_scale()
	var hit:=attack_damage()
	if heavy_attack:
		var windup_rank: int=game.passive_rank("windup")
		hit*=2.2+0.6*float(windup_rank-1);heavy_attack=false
		game.effect(action_target,70,Color("f0c26a"),"blast",0.3)
	var burn:=mod("burn")
	if action=="attack":
		shots+=1
		var basic_hit := condition_hit.duplicate()
		basic_hit["rule_basic"]=true
		if game.passive_lab and game.passive_rank("sweep")>0 and shots%3==0:
			var sweep_rank: int=game.passive_rank("sweep")
			var sweep_point: Vector2=action_enemy.center() if is_instance_valid(action_enemy) and not action_enemy.dead else position+facing*60.0
			game.area_damage(sweep_point,90.0+30.0*float(sweep_rank-1),hit*(0.8+0.2*float(sweep_rank-1)),int(data.type),"hero")
		rapid_count+=1
		if rapid_count>=rapid_every():
			rapid_count=0
			hit*=1.3
		combo_count+=1
		if mod("combo_every")>0 and combo_count % int(mod("combo_every"))==0:
			hit*=1.0+mod("combo_bonus")
			if has_link("combo","rapid"): rapid_count+=1
		match class_id:
			"lord":
				var hit_primary: bool = is_instance_valid(action_enemy) and not action_enemy.dead and center().distance_to(action_enemy.center())<=float(data.reach)+10
				if hit_primary:
					action_enemy.take_hit(attack_damage_against(action_enemy,hit),0,"hero",0.0,0.0,0.0,"short_sword",facing,Vector2.INF,basic_hit)
					if burn>0: action_enemy.ignite(burn,3.0)
				# Small frontal cleave for tank presence
				for foe in game.enemies:
					if is_instance_valid(foe) and foe!=action_enemy and not foe.dead and not (foe.has_method("is_flying") and foe.is_flying()):
						var rel: Vector2=foe.position-position
						if rel.length()<=float(data.reach)+4 and (rel.length()<28 or rel.normalized().dot(facing)>0.35):
							foe.take_hit(attack_damage_against(foe,hit*0.45),0,"hero",0.0,0.0,0.0,"short_sword",facing,Vector2.INF,basic_hit)
				game.effect(position+facing*42+Vector2(0,-24),34,Color("d94858"),"slash",0.18,facing)
				game.audio.play("blade",-5)
			"werewolf":
				var is_beast := werewolf_beast_clock > 0.0
				var reach := attack_reach()
				var total_dealt := 0.0
				if is_beast:
					# Wide ferocious ice-claw cleave hitting all enemies in 128px frontal cone!
					for foe in game.enemies.duplicate():
						if not is_instance_valid(foe) or foe.dead or (foe.has_method("is_flying") and foe.is_flying()): continue
						var rel: Vector2 = foe.position - position
						if rel.length() <= reach and (rel.length() < 34.0 or rel.normalized().dot(facing) > 0.12):
							var d: float = foe.take_hit(attack_damage_against(foe, hit), 0, "hero", 0.0, 0.0, 0.0, "werewolf_claw",facing,Vector2.INF,basic_hit)
							total_dealt += d
							if is_instance_valid(foe) and not foe.dead:
								foe.chill(0.22, 1.5)
								if burn > 0: foe.ignite(burn, 3.0)
					game.effect(position + facing * 48 + Vector2(0, -24), 56, Color("8ae8ff"), "slash", 0.22, facing)
					game.audio.play("heavy_hit", -11)
				else:
					if is_instance_valid(action_enemy) and not action_enemy.dead and center().distance_to(action_enemy.center()) <= reach + 10:
						var d: float = action_enemy.take_hit(attack_damage_against(action_enemy, hit), 0, "hero", 0.0, 0.0, 0.0, "werewolf_claw",facing,Vector2.INF,basic_hit)
						total_dealt += d
						if is_instance_valid(action_enemy) and not action_enemy.dead:
							action_enemy.chill(0.15, 1.2)
							if burn > 0: action_enemy.ignite(burn, 3.0)
						if werewolf_bloodlust_clock > 0.0:
							for foe in game.enemies:
								if is_instance_valid(foe) and foe != action_enemy and not foe.dead and not (foe.has_method("is_flying") and foe.is_flying()) and foe.position.distance_to(action_enemy.position) <= 68.0:
									total_dealt += foe.take_hit(hit * 0.35, 0, "hero", 0.0, 0.0, 0.0, "werewolf_claw",facing,Vector2.INF,basic_hit)
					game.effect(position + facing * 36 + Vector2(0, -22), 30, Color("9ce4ff"), "slash", 0.16, facing)
					game.audio.play("blade", -7)
				_werewolf_lifesteal(total_dealt)
			"gunner":
				var has_target: bool = is_instance_valid(action_enemy) and not action_enemy.dead
				var origin := visual.emission_origin("attack")
				var aim_dest: Vector2 = action_enemy.center() if has_target else origin + facing * attack_reach()
				var aim_dir := origin.direction_to(aim_dest)
				if aim_dir.is_zero_approx(): aim_dir = facing
				if empower_shot > 0:
					empower_shot = 0
					var crit_mult := 2.0 + 0.15 * float(passive_rank)
					var emp_dmg := (attack_damage_against(action_enemy, hit) if has_target else hit) * crit_mult
					var twin := gunner_overdrive_clock > 0.0
					var count := 2 if twin else 1
					var perp := aim_dir.orthogonal()
					for s_i in range(count):
						var off := perp * ((float(s_i) - 0.5) * 14.0) if twin else Vector2.ZERO
						game.fire_projectile(origin + off, aim_dest + off, emp_dmg, 0, "hero", {
							"target": null, "speed": 940.0, "pierce": 2 + int(mod("pierce_bonus")),
							"pen": 0.25, "bounce": 1 if has_keystone("refract") else 0,
							"appearance": "arrow", "burn": burn, "presentation": "gunner_crit", "feedback": "pierce_arrow", "condition_hit": basic_hit
						})
					game.effect(origin, 26, Color("8be8ff"), "hit", 0.16, aim_dir)
					game.audio.play("heavy_hit", -12)
				else:
					var shot_dmg := attack_damage_against(action_enemy, hit) if has_target else hit
					game.fire_projectile(origin, aim_dest, shot_dmg, 0, "hero", {
						"target": action_enemy if has_target else null, "speed": 840.0, "pierce": int(mod("pierce_bonus")),
						"bounce": 1 if has_keystone("refract") else 0,
						"appearance": "arrow", "burn": burn, "presentation": "gunner", "feedback": "quick_arrow", "condition_hit": basic_hit
					})
					game.audio.play("ranger_release", -9)
			"druid", "healer":
				var has_target: bool = is_instance_valid(action_enemy) and not action_enemy.dead
				var shot_dmg := attack_damage_against(action_enemy, hit) if has_target else hit
				var origin := visual.emission_origin("attack")
				var aim_dest: Vector2 = action_enemy.center() if has_target else origin + facing * attack_reach()
				game.fire_projectile(origin, aim_dest, shot_dmg, 1, "hero", {
					"target": action_enemy if has_target else null,
					"bounce": 1 if has_keystone("refract") else 0,
					"appearance": "magic", "burn": burn,
					"presentation": class_id, "feedback": "druid_orb" if class_id=="druid" else "healer_orb", "condition_hit": basic_hit
				})
				game.audio.play("mage_cast", -9)
		if mod("sworddance")>0 and game.rng.randf()<0.2:
			_sworddance(hit*0.6)
		if has_keystone("chrono") and chrono_clock>0.0:
			chrono_hits+=1
			if chrono_hits>=3:
				chrono_hits=0;cooldowns[1]=maxf(0.0,cooldowns[1]-1.5)
				var burst_pt: Vector2=action_enemy.position if is_instance_valid(action_enemy) and not action_enemy.dead else position+facing*75.0
				game.area_damage(burst_pt,95.0,hit*0.95,1,"hero",0.5)
				game.effect(burst_pt,95.0,Color("caa4ff"),"blast",0.35)
	elif action=="small":
		var skill:=skill_scale()
		match class_id:
			"lord":
				var q_dmg := hit * 2.2 * skill
				game.cone_damage(position, facing, 130.0, q_dmg, 0, "hero", 0.65, "small",condition_hit)
				_after_skill(position, 130.0, q_dmg)
				game.effect(position + facing * 32, 118.0, Color("d84052"), "slash", 0.34, facing)
				game.audio.play("heavy_hit", -7)
			"druid":
				var target: Node2D = game.nearest_enemy(action_target, 56.0)
				for beast in companions:
					beast.command(action_target, target)
					beast.heal_percent(0.30)
				game.effect(action_target, 56.0, Color("86e890"), "upgrade", 0.48)
				game.audio.play("mage_gather", -12, 1.15)
			"healer":
				var radius := 190.0
				game.area_damage(position, radius, 26.0 * power * skill, 1, "hero", 0.0, 0.0, 0.0, 0.0, "healer_blessing",true,condition_hit)
				healer_blessing_clock = 5.0
				healer_blessing_pos = position
				_after_skill(position, radius, 26.0 * power * skill)
				game.effect(position, 44.0, Color("f6a8c6"), "upgrade", 0.38)
				game.audio.play("mage_cast", -8)
			"werewolf":
				werewolf_bloodlust_clock = 5.0
				game.effect(position, 42.0, Color("7ee2ff"), "upgrade", 0.36)
				game.audio.play("phase", -10, 1.2)
			"gunner":
				if not game.feel.enabled:
					game.effect(position, 45, Color("88c8ff"), "roll", 0.3, roll_direction)
	elif action=="ultimate":
		var skill:=skill_scale()
		match class_id:
			"lord":
				lord_shield_clock = 6.0 + mod("war_cry_bonus")
				lord_thorn_tick = 0.25
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
				game.effect(position, 48.0, Color("f8b4d0"), "upgrade", 0.42)
				game.audio.play("phase", -7, 1.15)
			"werewolf":
				werewolf_beast_clock = 8.0
				visual.set_form("werewolf_beast")
				game.area_damage(position, 115.0, hit * 1.4 * skill, 0, "hero", 0.4, 2.0, 0.0, 14.0, "werewolf_transform",false,condition_hit)
				game.effect(position, 82.0, Color("8eeeff"), "blast", 0.42)
				game.audio.play("heavy_hit", -6)
				game.audio.play("phase", -10, 0.78)
			"gunner":
				gunner_overdrive_clock = 6.0
				cooldowns[0] = 0.0
				empower_shot = 1
				game.effect(position, 42.0, Color("66d2ff"), "upgrade", 0.38)
				game.audio.play("phase", -7, 1.32)

func _after_skill(point: Vector2, radius: float, amount: float) -> void:
	if perk("starlight")>0: _expose_area(point,radius,3.0)
	if perk("chain")>0: _chain_skill(amount)
func _expose_area(point: Vector2, radius: float, duration: float) -> void:
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(point)<=radius: enemy.expose(duration)
func _chain_skill(amount: float) -> void:
	var bounces:=maxi(1,perk("chain"))
	var origin:=action_target
	var hit: Array[Node2D]=[]
	for index in range(bounces):
		var target: ArenaEnemy
		var best:=260.0
		for enemy in game.enemies:
			if not is_instance_valid(enemy) or enemy.dead or enemy in hit: continue
			var distance: float=enemy.position.distance_to(origin)
			if distance<best: best=distance;target=enemy
		if target==null: break
		var ratio:=0.5 if bounces<=1 else 0.75
		target.take_hit(amount*ratio,1,"hero")
		if has_link("burn","chain"): target.ignite(mod("burn"),3.0)
		game.effect(target.center(),25,Color("a78bfa"),"hit",0.2)
		hit.append(target);origin=target.position
func _sworddance(amount: float) -> void:
	game.effect(position,55,Color("ffe9a6"),"slash",0.18,facing)
	if class_id in ["lord","werewolf"]:
		game.cone_damage(position,facing,100,amount,0,"hero")
	elif is_instance_valid(action_enemy) and not action_enemy.dead:
		game.fire_projectile(center(),action_enemy.center(),amount,int(data.type),"hero",{"target":action_enemy,"appearance":"arrow" if class_id=="gunner" else "magic"})

func take_hit(amount: float, damage_type: int, melee := false, direction := Vector2.ZERO) -> float:
	if knocked_out or protection>0 or game.game_over: return 0.0
	var adjusted: float=amount
	if melee and game.blocking.load_for(self)>0:
		if class_id=="lord":
			var lord_red: float = float([0.20, 0.22, 0.25][passive_rank])
			adjusted *= 1.0 - lord_red
		adjusted*=1.0-clampf(mod("block_reduction"),0.0,0.6)
		if has_link("tough","ironwall"): adjusted*=0.97
		if block_boost_clock>0 and has_link("shieldback","ironwall"): adjusted*=0.90
		if revive_block_clock>0 and has_link("revive","ironwall"): adjusted*=0.70
	if class_id=="lord" and lord_shield_clock>0.0:
		adjusted *= 0.65
	if war_cry>0: adjusted*=0.7
	if has_keystone("bastion_ward"): adjusted*=0.75
	adjusted*=1.0-citywall_reduction()
	if conditions!=null: adjusted*=1.0-conditions.reduction()
	var incoming:=minf(health+overheal_shield,ArenaCombat.resolve(adjusted,damage_type,0,0))
	var absorbed:=minf(overheal_shield,incoming);overheal_shield-=absorbed
	var taken:=incoming
	health-=(incoming-absorbed);combat_delay=5;hurt_time=0.24
	if incoming-absorbed>0 and game.has_method("note_hero_damage"): game.note_hero_damage(incoming-absorbed,position)
	if melee and mod("reflect")>0:
		var reflect:=mod("reflect")
		if has_link("ironwall","reflect"): reflect*=1.5
		var attacker: Node2D=game.nearest_enemy(center(),120.0)
		if attacker!=null and not attacker.dead: attacker.take_hit(taken*reflect,0,"hero")
		if has_link("shieldback","ironwall"): block_boost_clock=1.5
	game.audio.play("hurt");game.effect(center(),17,ArenaCombat.colour(damage_type),"hit",0.16)
	if game.passive_lab and passive_rebuke_clock<=0.0 and game.passive_rank("rebuke")>0:
		passive_rebuke_clock=1.0
		game.area_damage(center(),80.0,20.0*float(game.passive_rank("rebuke")),1,"hero")
	if game.feel.enabled:
		visual.feedback.impact(visual,false,direction)
		if class_id=="lord" and (lord_shield_clock>0 or (melee and game.blocking.load_for(self)>0)):
			game.effect(center(),18,Color("e85c6c"),"ward_contact",0.15,direction)
	if health<=0:
		_handle_ko()
	return taken

func add_xp(amount: int) -> void:
	xp+=amount
	while xp>=xp_target:
		xp-=xp_target;level+=1
		xp_target=(45+(level-1)*12) if (conditions!=null or game.passive_lab) else (60+(level-1)*25)
		recompute()
		_trigger_level_burst()
		if conditions!=null:
			if level>=2 and level<=11: game.queue_choice()
		elif not game.keystone_mode:
			if game.passive_lab:
				if level>=2 and level<=11:game.queue_choice()
			elif level in MILESTONE_LEVELS:game.queue_choice()
func _trigger_level_burst() -> void:
	if knocked_out: return
	health=minf(max_health,health+max_health*0.25)
	if game==null or game.game_over: return
	game.effect(position,115.0,Color("f6d68d"),"upgrade",0.55)
	for enemy in game.enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and not enemy.is_guard and not enemy.elite and not enemy.is_boss() and enemy.position.distance_to(position)<=115.0:
			enemy.push_back(22.0);enemy.stun=maxf(enemy.stun,0.28)

func apply_perk(key: String) -> bool:
	var card: Dictionary=ArenaPerks.card(key)
	if card.is_empty() or perk(key)>=int(card.max): return false
	perks[key]=perk(key)+1
	recompute()
	return true

func _draw() -> void:
	draw_ellipse_shadow()
	if knocked_out: return
	# Hero-specific active aura & buff visual cues on the ground
	if class_id=="lord" and lord_shield_clock>0.0:
		draw_set_transform(Vector2(0,-24),0.0,Vector2(1.0,0.88))
		draw_arc(Vector2.ZERO,32.0,0.0,TAU,32,Color("eb4d5e",0.86),3.0,true)
		draw_circle(Vector2.ZERO,30.0,Color("c83044",0.14))
		draw_set_transform(Vector2.ZERO)
	elif class_id=="healer":
		if healer_sanctuary_clock>0.0:
			var sc := to_local(healer_sanctuary_pos)
			var spin := float(Time.get_ticks_msec()) * 0.0018
			draw_set_transform(sc,0.0,Vector2(1.0,0.58))
			draw_circle(Vector2.ZERO,240.0,Color("f8b4d0",0.11))
			draw_arc(Vector2.ZERO,240.0,0.0,TAU,56,Color("f8b4d0",0.78),2.8,true)
			draw_arc(Vector2.ZERO,165.0,0.0,TAU,40,Color("98f0a8",0.58),2.0,true)
			for p_i in range(8):
				var pa := spin + float(p_i) * (TAU / 8.0)
				var pp := Vector2(cos(pa), sin(pa)) * 200.0
				draw_circle(pp, 6.0, Color("ffc2dc", 0.78))
				draw_circle(pp, 3.0, Color("fff8dc", 0.90))
			draw_set_transform(Vector2.ZERO)
		elif healer_blessing_clock>0.0:
			var bc := to_local(healer_blessing_pos)
			draw_set_transform(bc,0.0,Vector2(1.0,0.58))
			draw_arc(Vector2.ZERO,190.0,0.0,TAU,40,Color("f6c2d8",0.52),2.0,true)
			draw_set_transform(Vector2.ZERO)
	elif class_id=="werewolf":
		if werewolf_beast_clock>0.0:
			draw_set_transform(Vector2.ZERO,0.0,Vector2(1.0,0.45))
			draw_arc(Vector2.ZERO,28.0,0.0,TAU,28,Color("7ee8ff",0.88),2.6,true)
			draw_circle(Vector2.ZERO,26.0,Color("5ec4ff",0.18))
			draw_set_transform(Vector2.ZERO)
		elif werewolf_bloodlust_clock>0.0:
			draw_set_transform(Vector2.ZERO,0.0,Vector2(1.0,0.45))
			draw_arc(Vector2.ZERO,22.0,0.0,TAU,24,Color("e85d75",0.78),2.0,true)
			draw_set_transform(Vector2.ZERO)
	elif class_id=="gunner":
		if gunner_overdrive_clock>0.0:
			draw_set_transform(Vector2.ZERO,0.0,Vector2(1.0,0.45))
			draw_arc(Vector2.ZERO,24.0,0.0,TAU,28,Color("5ec8ff",0.90),2.5,true)
			draw_arc(Vector2.ZERO,18.0,0.0,TAU,20,Color("ffe680",0.75),1.5,true)
			draw_set_transform(Vector2.ZERO)
		if empower_shot>0:
			draw_circle(Vector2(0,-visual.visual_size-8.0),4.5,Color("ffe97a"))
			draw_arc(Vector2(0,-visual.visual_size-8.0),7.5,0.0,TAU,14,Color("68d8ff"),1.6,true)
	# Overhead shield bar if overheal_shield > 0
	if overheal_shield > 1.0:
		var bar_y := -visual.visual_size - 2.0
		var ratio := clampf(overheal_shield / maxf(1.0, max_health * 0.45), 0.0, 1.0)
		draw_rect(Rect2(-20, bar_y, 40, 4), Color(0.08, 0.10, 0.14, 0.85))
		draw_rect(Rect2(-20, bar_y, 40 * ratio, 4), Color("f26b7a") if class_id=="lord" else Color("98f5c4"))
	if debuff_slow_clock > 0.0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.48))
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 24, Color("84adff", 0.85), 2.2, true)
		draw_set_transform(Vector2.ZERO)
	if debuff_poison_clock > 0.0:
		var t_ms := float(Time.get_ticks_msec()) * 0.004
		for i in range(3):
			var p_off := Vector2(sin(t_ms + float(i) * 2.1) * 14.0, -14.0 - fmod(t_ms * 8.0 + float(i) * 9.0, 28.0))
			draw_circle(p_off, 3.0, Color("6ae874", 0.85))
	if debuff_bleed_clock > 0.0:
		for i in range(2):
			var b_off := Vector2(-8.0 + float(i) * 16.0, -10.0)
			draw_line(b_off, b_off + Vector2(0.0, 7.0), Color("ee4e62", 0.9), 2.2, true)
	if debuff_stun_clock > 0.0:
		var s_t := float(Time.get_ticks_msec()) * 0.008
		for i in range(3):
			var a := s_t + float(i) * (TAU / 3.0)
			var sp := Vector2(cos(a) * 14.0, -visual.visual_size - 6.0 + sin(a) * 4.0)
			draw_circle(sp, 3.2, Color("ffe270"))
	draw_arc(Vector2.ZERO,16,0,TAU,24,Color(data.get("colour",Color("b7e1d6")),0.85),1.5,true)

	if conditions==null: return
	if conditions.rank("lonewolf")>0 or conditions.rank("phalanx")>0:
		var supported: bool=(conditions.rank("lonewolf")>0 and conditions.nearby_soldiers==0) or (conditions.rank("phalanx")>0 and conditions.nearby_soldiers>=2)
		draw_arc(Vector2.ZERO,ArenaConditions.SOLDIER_RADIUS,0,TAU,64,Color(0.60,0.95,0.72,0.42) if supported else Color(0.74,0.82,0.85,0.20),1.5,true)
	if conditions.still_time>0.0:
		if conditions.rank("stillwater")>0: draw_stance_ring(1.5,21.0,Color("a1e6ff"))
		if conditions.rank("turtle")>0: draw_stance_ring(3.0,31.0,Color("e5b493"))
	if conditions.rapids_ready() or conditions.snapstop_ready():
		draw_circle(Vector2.ZERO,19,Color(1.0,0.74,0.32,0.16))
		draw_arc(Vector2.ZERO,26,0,TAU,32,Color("ffca72"),2.5,true)
func draw_stance_ring(required: float, radius: float, active_colour: Color) -> void:
	var progress:=minf(1.0,conditions.still_time/required)
	draw_arc(Vector2.ZERO,radius,-PI*0.5,-PI*0.5+TAU*progress,32,active_colour if progress>=1.0 else Color(active_colour,0.45),2.0,true)
func draw_ellipse_shadow() -> void:
	var visual_scale: float=game.feel.unit_scale if game.feel.enabled else 1.0
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.4));draw_circle(Vector2.ZERO,17*visual_scale,Color(0.08,0.14,0.1,0.35));draw_set_transform(Vector2.ZERO)
