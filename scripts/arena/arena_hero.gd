class_name ArenaHero
extends CharacterBody2D
var game: Node2D
var class_id: String="knight"
var data: Dictionary={}
var health:=320.0
var max_health:=320.0
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
var lunge_left:=0.0
var lunge_dir:=Vector2.RIGHT
var death_saved:=false
var overheal_shield:=0.0
var rapid_count:=0
var last_target_id:=0
var block_boost_clock:=0.0
var revive_block_clock:=0.0
var revive_halved:=false
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
func _ready() -> void:
	collision_layer=2;collision_mask=1
	var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=12;shape.shape=circle;add_child(shape)
	visual=ArenaActor.new();add_child(visual)
	visual.frame_changed.connect(_animation_frame)
	visual.animation_finished.connect(_animation_finished)
func configure(key: String) -> void:
	class_id=key;data=ArenaDefinitions.hero(key)
	if game.condition_lab:
		conditions=ArenaConditions.new(game.passive_ranks)
		xp_target=45
	meta_level=game.campaign.level(key)
	var bonus: Dictionary=game.campaign.bonuses(key)
	meta_health=float(bonus.health);meta_attack=float(bonus.attack);passive_rank=int(bonus.passive)
	max_health=float(data.health)
	meta_cooldown=0.0
	recompute()
	health=max_health
	visual.configure(key,ArenaHeroArt.height(key,game.feel.enabled,game.feel.unit_scale),game.feel.enabled)
	visual.feedback.reduced=bool(game.campaign.data.reduced_motion)
func skill_unlocked(slot: int) -> bool:return slot in [0,1] and meta_level>=(2 if slot==0 else 4)
func has_keystone(key: String) -> bool:return game!=null and game.has_keystone(key)
func center() -> Vector2: return position+Vector2(0,-30)
func block_capacity() -> int: return int(data.get("block",1))+int(mod("block_bonus"))+(1 if mod("fortress")>0 else 0)+(2 if has_keystone("bastion_ward") else 0)
func can_block() -> bool: return not knocked_out and rolling<=0 and velocity.length()<35 and game.orders.transfer_left<=0
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
	overheal_shield=minf(overheal_shield,mod("shield_cap"))
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
	return result
func execute_threshold() -> float:
	return mod("execute_threshold")+(0.05 if has_link("pierce","execute") else 0.0)
func full_hp_threshold() -> float: return 0.7 if has_link("power","execute") else 1.0
func attack_damage_against(enemy: Node2D, base: float) -> float:
	var damage:=base
	if mod("full_hp_bonus")>0 and enemy.health>=enemy.max_health*full_hp_threshold():
		damage*=1.0+mod("full_hp_bonus")
	if enemy.health<enemy.max_health*execute_threshold(): damage*=1.0+mod("execute_bonus")
	if (enemy.elite or enemy.kind=="moth") and mod("elite_bonus")>0: damage*=1.0+mod("elite_bonus")
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
func armor_pen() -> float: return clampf(mod("armor_pen"),0.0,0.6)
func skill_scale() -> float:
	var result:=1.0+mod("skill")
	if has_link("focus","starlight"): result+=mod("cooldown")*0.3
	if overload_clock>0 and mod("overload")>0: result+=0.20
	if passive_q_clock>0.0 and action=="small" and game!=null and game.passive_lab: result*=1.4+0.2*float(maxi(0,game.passive_rank("doublecast")-1))
	return result
func heal_on_kill() -> void:
	if knocked_out: return
	var heal:=mod("lifesteal")
	if heal<=0: return
	var before:=health
	health=minf(max_health,health+heal)
	var over:=heal-(health-before)
	var cap:=mod("shield_cap")
	if over>0 and cap>0: overheal_shield=minf(cap,overheal_shield+over)
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
	if knocked_out or position.distance_to(point)>command_radius(): return 0.0
	var value:=mod("command_aura")
	if has_link("warcredit","command"): value+=0.02*float(warcredit_stacks())
	if war_cry>0 and has_link("oath","command"): value*=2.0
	return value
func citywall_reduction() -> float:
	if mod("citywall")<=0: return 0.0
	var reduction:=minf(0.08,0.02*float(game.towers.size()))
	if has_link("citywall","command"):
		var count:=0
		for tower in game.towers:
			if is_instance_valid(tower) and position.distance_to(tower.position)<=command_radius(): count+=1
		reduction+=0.01*float(count)
	return reduction
func cooldown_scale() -> float: return 1.0-minf(0.30,meta_cooldown+mod("cooldown"))
func command_move(target: Vector2) -> void:
	if knocked_out: return
	path=game.navigation_path(position,target)
func cancel_action() -> void:
	push_attack=false
	action="";action_enemy=null;action_clock=0;action_released=false;visual.feedback.stop_left=0.0
	condition_hit={}
	lunge_left=0.0
func _physics_process(delta: float) -> void:
	if not game.running or game.game_over: return
	for slot in range(2): cooldowns[slot]=maxf(0,cooldowns[slot]-delta)
	attack_cooldown=maxf(0,attack_cooldown-delta);combat_delay=maxf(0,combat_delay-delta)
	foot_clock=maxf(0.0,foot_clock-delta)
	protection=maxf(0,protection-delta);war_cry=maxf(0,war_cry-delta);hurt_time=maxf(0,hurt_time-delta)
	echo_clock=maxf(0,echo_clock-delta);enchant_clock=maxf(0,enchant_clock-delta);overload_clock=maxf(0,overload_clock-delta);roll_boost_clock=maxf(0,roll_boost_clock-delta);chrono_clock=maxf(0.0,chrono_clock-delta)
	block_boost_clock=maxf(0,block_boost_clock-delta);revive_block_clock=maxf(0,revive_block_clock-delta)
	passive_rebuke_clock=maxf(0.0,passive_rebuke_clock-delta);passive_q_clock=maxf(0.0,passive_q_clock-delta)
	if knocked_out:
		revive_clock=maxf(0,revive_clock-delta)
		if revive_clock<=0:
			knocked_out=false;health=max_health;protection=1.5;revive_block_clock=3.0
			position=game.level_definition.hero_spawn
			cancel_action();visual.show_state("idle",Vector2.LEFT)
		queue_redraw();return
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
	var move_bounds: Rect2=game.hero_move_bounds()
	var previous_position:=position
	if rolling>0:
		rolling=maxf(0,rolling-delta);velocity=roll_direction*(700.0 if game.action_controls else 520.0);move_and_slide()
		position=position.clamp(move_bounds.position,move_bounds.end)
		if game.action_controls and rolling<=0.0: velocity=Vector2.ZERO
		if conditions!=null:
			conditions.update_movement(delta,0.0,true)
			conditions.scan_soldiers(position,game.soldiers,delta)
		queue_redraw();return
	if move.length()>0.1:
		facing=facing.slerp(move.normalized(),clampf(delta*12.0,0.0,1.0)).normalized()
		if not game.action_controls and action!="" and (action_released or (action=="attack" and move.length()>0.35)): cancel_action()
	if action!="":
		action_clock+=delta
		if not action_released and action_clock>=action_duration*ArenaMotion.release_fraction(class_id,action,visual.polished): release_action()
		if action_clock>=action_duration: cancel_action()
	if action=="attack" and is_instance_valid(action_enemy):
		var wanted: Vector2=(action_enemy.center()-position).normalized()
		facing=facing.slerp(wanted,clampf(delta*18.0,0.0,1.0)).normalized()
	lunge_left=maxf(0.0,lunge_left-delta)
	var planted: bool=action!="" and (action!="attack" or not game.action_controls) and not action_released
	var move_mult: float=1.20 if chrono_clock>0.0 else 1.0
	var desired: Vector2=move*float(data.speed)*move_mult
	if conditions!=null: desired*=1.0+conditions.move_bonus(health/max_health)
	if game.action_controls and action=="attack": desired*=0.35
	velocity=Vector2.ZERO if planted else velocity.move_toward(desired,(2500.0 if move.length()>0.1 else 4800.0)*delta)
	if lunge_left>0.0 and not planted: velocity=velocity.move_toward(lunge_dir*260.0,6000.0*delta)
	move_and_slide()
	position=position.clamp(move_bounds.position,move_bounds.end)
	if conditions!=null:
		var wants_move:=move.length_squared()>0.01
		var action_displaces:=planted or lunge_left>0.0
		var input_speed:=position.distance_to(previous_position)/delta if wants_move and not action_displaces and delta>0.0 else 0.0
		conditions.update_movement(delta,input_speed,false,wants_move,action_displaces)
		conditions.scan_soldiers(position,game.soldiers,delta)
	if action=="":
		visual.show_state("hurt" if hurt_time>0 else ("walk" if velocity.length()>5 else "idle"),facing,0.24)
		if hurt_time<=0 and velocity.length()>5:visual.stride(velocity.length())
	if Input.is_action_pressed("shoot") and not game.input_blocked() and not game.suppress_primary and attack_cooldown<=0 and action=="":
		var enemy: Node2D=game.nearest_enemy(center(),float(data.reach))
		if enemy!=null: begin_attack(enemy)
	if game.passive_lab and game.passive_rank("windup")>0:
		if Input.is_action_pressed("shoot") and not game.input_blocked() and not game.suppress_primary:
			windup_hold+=delta
			if windup_hold>=0.8:windup_hold-=0.8;windup_ready=true
		else:windup_hold=0.0;windup_ready=false
	var reduced:=bool(game.campaign.data.reduced_motion)
	visual.feedback.reduced=reduced
	visual.modulate=(Color.WHITE if visual.polished else (Color(1.05,1.0,0.95) if reduced else Color(2.1,1.6,1.4))) if hurt_time>0 else Color(1,1,1,0.62 if not reduced and protection>0 and fmod(protection,0.16)<0.08 else 1.0)
	queue_redraw()
func attack_rate() -> float:
	var chrono_bonus: float=0.55 if chrono_clock>0.0 else 0.0
	var altar_bonus: float=game.hero_overclock_bonus() if game!=null and game.has_method("hero_overclock_bonus") else 0.0
	var condition_bonus:=conditions.attack_speed_bonus() if conditions!=null else 0.0
	return 1.0+mod("attack_speed")+(mod("roll_boost") if roll_boost_clock>0 else 0.0)+(0.4 if overload_clock>0 and mod("overload")>0 else 0.0)+chrono_bonus+altar_bonus+condition_bonus
func rapid_every() -> int:
	return 4 if has_link("rapid","power") else 5
func begin_attack(enemy: Node2D) -> bool:
	if knocked_out or action!="" or attack_cooldown>0 or not is_instance_valid(enemy): return false
	var target_id:=int(enemy.get_instance_id())
	if target_id!=last_target_id:
		if mod("combo_every")>0: combo_count=maxi(1,combo_count-1)
		else: combo_count=0
		last_target_id=target_id
	facing=(facing.slerp((enemy.center()-position).normalized(),0.55) if game.action_controls else (enemy.center()-position).normalized()).normalized();action="attack";action_enemy=enemy;action_target=enemy.center()
	if conditions!=null: condition_hit=conditions.attack_context()
	action_duration=minf(0.56,float(data.interval)/attack_rate());action_clock=0;action_released=false
	if game.action_controls:
		action_duration=minf(0.46,action_duration)
		if float(data.reach)<=120.0:lunge_left=0.10;lunge_dir=facing
	attack_cooldown=float(data.interval)/attack_rate();combat_delay=5.0
	if game.passive_lab and game.passive_rank("windup")>0 and windup_ready:
		windup_ready=false;heavy_attack=true
	if class_id=="ranger" and game.feel.enabled:game.audio.play("ranger_draw",-18)
	if class_id=="mage" and game.feel.enabled:game.audio.play("mage_gather",-18)
	visual.show_state("attack",facing,action_duration);visual.frame=0;return true
func cast(slot: int, point: Vector2) -> bool:
	if slot<0 or slot>1 or knocked_out or game.game_over or not game.running or cooldowns[slot]>0: return false
	if not skill_unlocked(slot):return false
	if action in ["small","ultimate"] and not action_released:return false
	cancel_action()
	var relative:=point-position
	if relative.length()>430: point=position+relative.normalized()*430
	var aim_bounds: Rect2=game.hero_aim_bounds()
	action_target=point.clamp(aim_bounds.position,aim_bounds.end)
	facing=(point-position).normalized() if relative.length()>5 else facing
	action="small" if slot==0 else "ultimate";action_clock=0;action_released=false;action_duration=(0.34 if class_id=="ranger" else 0.48) if slot==0 else 0.72
	if conditions!=null: condition_hit=conditions.attack_context()
	cooldowns[slot]=float(data.small_cd if slot==0 else data.ultimate_cd)*cooldown_scale()
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
	if class_id=="ranger" and slot==0:
		roll_direction=Input.get_vector("move_left","move_right","move_up","move_down")
		if roll_direction.length()<0.1: roll_direction=facing
		rolling=0.27;protection=maxf(protection,0.36);empower_shot=0;game.blocking.release(self)
		if conditions!=null: conditions.update_movement(0.0,0.0,true)
		if game.passive_lab and game.passive_rank("afterimage")>0:
			game.add_slow_zone(position,80.0+30.0*float(game.passive_rank("afterimage")-1),1.5,0.5)
		if role("shadowstep")>0: roll_boost_clock=2.0
		if has_link("shadowstep","rapid"): rapid_count+=1
		if game.feel.enabled:
			game.effect(position,45,Color("b4d6a0"),"roll_painted",0.28,roll_direction);game.audio.play("ranger_roll",-14)
	if class_id=="mage" and game.feel.enabled:game.audio.play("mage_gather",-16)
	if has_keystone("chrono") and slot==0: chrono_clock=4.5
	if has_keystone("conduit"): game.trigger_conduit(position,attack_damage()*1.1+45.0)
	visual.show_state(action,facing,action_duration);visual.frame=0;return true
func role(key: String) -> float: return mod(key)
func _animation_frame() -> void:
	if game.feel.enabled and visual.animation.begins_with("walk") and visual.frame in [0,4] and foot_clock<=0:
		game.audio.play("footstep",-25);foot_clock=0.18
	if action!="" and not action_released and visual.frame>=ArenaMotion.release_frame(action,class_id): release_action()
func _animation_finished() -> void:
	if not knocked_out and action!="": cancel_action()
func release_action() -> void:
	if action_released or knocked_out or action=="": return
	action_released=true
	if action=="attack" and push_attack:
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
		if class_id=="ranger" and shots%3==0:hit*=1.0+float(passive_rank)*0.05
		rapid_count+=1
		if rapid_count>=rapid_every():
			rapid_count=0
			hit*=1.3
		combo_count+=1
		if mod("combo_every")>0 and combo_count % int(mod("combo_every"))==0:
			hit*=1.0+mod("combo_bonus")
			if has_link("combo","rapid"): rapid_count+=1
		if class_id=="knight":
			for enemy in game.enemies.duplicate():
				if not is_instance_valid(enemy) or enemy.dead: continue
				var offset: Vector2=enemy.position-position
				if offset.length()<100 and (offset.length()<25 or offset.normalized().dot(facing)>0.3):
					enemy.take_hit(attack_damage_against(enemy,hit),0,"hero",0.0,0.0,0.0,"attack",basic_hit)
			_ignite_cone(burn)
			game.effect(position+Vector2(0,-27),100,ArenaCombat.colour(0),"slash_painted" if game.feel.enabled else "slash",0.22,facing)
			game.audio.play("blade")
		else:
			if is_instance_valid(action_enemy) and not action_enemy.dead:
				var shot_damage:=attack_damage_against(action_enemy,hit)
				var pierce: int=(1 if shots%3==0 else 0) if class_id=="ranger" else 0
				pierce+=int(mod("pierce_bonus"))
				var origin:=visual.emission_origin("attack") if game.feel.enabled else center()
				var tag: String=("pierce_arrow" if pierce>0 else "arrow") if class_id=="ranger" else "star"
				game.fire_projectile(origin,action_enemy.center(),shot_damage,int(data.type),"hero",{"target":action_enemy,"pierce":pierce,"bounce":1 if has_keystone("refract") else 0,"expose":class_id=="mage","appearance":"arrow" if class_id=="ranger" else "magic","burn":burn,"presentation":class_id if game.feel.enabled else "","feedback":tag,"condition_hit":basic_hit})
			game.audio.play(("ranger_release" if class_id=="ranger" else "mage_cast") if game.feel.enabled else ("bow" if class_id=="ranger" else "shoot"))
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
			"knight":
				game.cone_damage(position,facing,145,85*power*skill,0,"hero",1.0,"small",condition_hit)
				_after_skill(position,145,85*power*skill)
				game.effect(position,145,Color("efbe78"),"slam_painted" if game.feel.enabled else "slam",0.45,facing);game.audio.play("explode")
			"ranger":
				if not game.feel.enabled:game.effect(position,45,Color("b4d6a0"),"roll",0.3,roll_direction)
			"mage":
				var radius:=125.0*(1.0+mod("frost_bonus"))
				var hits:=0
				for enemy in game.enemies:
					if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(position)<=radius: hits+=1
				game.area_damage(position,radius,65*power*skill,1,"hero",0,3.0,0.0,0.0,"frost",condition_hit)
				if hits>=3 and has_link("frostheart","focus"): cooldowns[0]=maxf(0.0,cooldowns[0]-1.0)
				_after_skill(position,radius,65*power*skill)
				game.effect(position,radius,Color("9adeff"),"frost_painted" if game.feel.enabled else "frost",0.6);game.audio.play("mage_frost" if game.feel.enabled else "crit")
	elif action=="ultimate":
		var skill:=skill_scale()
		match class_id:
			"knight":
				war_cry=6.0+mod("war_cry_bonus");game.war_cry_position=position;game.war_cry_clock=war_cry
				game.effect(position,230,Color("f2c36e"),"banner_painted" if game.feel.enabled else "banner",0.9);game.audio.play("phase")
			"ranger":
				for index in range(6):
					game.delayed_attack(action_target,135,30*power*skill,0,"hero",0.4+index*0.32,{"arrow_rain":true,"feedback":"arrow_rain","rain_index":index,"condition_hit":condition_hit})
				_after_skill(action_target,135,30*power*skill)
				game.audio.play("ranger_release" if game.feel.enabled else "bow")
			"mage":
				var meteor:=205*power*skill*(1.0+mod("meteor_bonus"))
				if has_link("starcore","starlight") and _exposed_near(action_target,155): meteor*=1.2
				game.delayed_attack(action_target,155,meteor,1,"hero",0.85,{"stun":1.2,"feedback":"meteor","condition_hit":condition_hit})
				_after_skill(action_target,155,meteor)
				game.effect(action_target,155,Color("caa4ff"),"meteor_painted" if game.feel.enabled else "meteor",0.85);game.audio.play("mage_meteor_charge" if game.feel.enabled else "phase")
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
func _exposed_near(point: Vector2, radius: float) -> bool:
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.exposure>0 and enemy.position.distance_to(point)<=radius: return true
	return false
func _ignite_cone(burn_dps: float) -> void:
	if burn_dps<=0: return
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var offset: Vector2=enemy.position-position
		if offset.length()<100 and (offset.length()<25 or offset.normalized().dot(facing)>0.3): enemy.ignite(burn_dps,3.0)
func _sworddance(amount: float) -> void:
	game.effect(position,55,Color("ffe9a6"),"slash",0.18,facing)
	if class_id=="knight":
		game.cone_damage(position,facing,100,amount,0,"hero")
	elif is_instance_valid(action_enemy) and not action_enemy.dead:
		game.fire_projectile(center(),action_enemy.center(),amount,int(data.type),"hero",{"target":action_enemy,"appearance":"arrow" if class_id=="ranger" else "magic"})
func take_hit(amount: float, damage_type: int, melee := false) -> float:
	if knocked_out or protection>0 or game.game_over: return 0.0
	var adjusted: float=amount
	if melee and game.blocking.load_for(self)>0:
		if class_id=="knight": adjusted*=1.0-[0.15,0.16,0.18][passive_rank]
		adjusted*=1.0-clampf(mod("block_reduction"),0.0,0.6)
		if has_link("tough","ironwall"): adjusted*=0.97
		if block_boost_clock>0 and has_link("shieldback","ironwall"): adjusted*=0.90
		if revive_block_clock>0 and has_link("revive","ironwall"): adjusted*=0.70
	if war_cry>0: adjusted*=0.7
	if has_keystone("bastion_ward"): adjusted*=0.75
	adjusted*=1.0-citywall_reduction()
	if conditions!=null: adjusted*=1.0-conditions.reduction()
	var incoming:=minf(health+overheal_shield,ArenaCombat.resolve(adjusted,damage_type,0,0))
	var absorbed:=minf(overheal_shield,incoming);overheal_shield-=absorbed
	var taken:=incoming
	health-=(incoming-absorbed);combat_delay=5;hurt_time=0.24
	if incoming-absorbed>0 and game.action_controls:game.shake=maxf(game.shake,1.2)
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
	if game.feel.enabled:visual.feedback.impact(visual)
	if health<=0:
		if mod("death_save")>0 and not death_saved:
			death_saved=true;health=1.0;protection=2.0
			if has_link("unyield","revive"): revive_halved=true
		else:
			var revive_time:=maxf(1.0,15.0-mod("revive_reduce"))
			if revive_halved: revive_time*=0.5
			health=0;knocked_out=true;revive_clock=revive_time;velocity=Vector2.ZERO;rolling=0;path.clear();cancel_action();game.blocking.release(self)
			if conditions!=null: conditions.reset_stance()
			visual.show_state("down",facing,0.65)
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
	if game==null or game.game_over:return
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
	draw_arc(Vector2.ZERO,16,0,TAU,24,Color("b7e1d6"),1.5,true)
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
