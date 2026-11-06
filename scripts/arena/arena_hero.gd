class_name ArenaHero
extends CharacterBody2D
var game: Node2D
var class_id: String="knight"
var data: Dictionary={}
var health:=320.0
var max_health:=320.0
var level:=1
var xp:=0
var xp_target:=80
var perks: Dictionary={}
var cooldowns: Array[float]=[0.0,0.0]
var attack_cooldown:=0.0
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
func _ready() -> void:
	collision_layer=2;collision_mask=1
	var shape:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=12;shape.shape=circle;add_child(shape)
	visual=ArenaActor.new();add_child(visual)
	visual.frame_changed.connect(_animation_frame)
	visual.animation_finished.connect(_animation_finished)
func configure(key: String) -> void:
	class_id=key;data=ArenaDefinitions.hero(key)
	var bonus: Dictionary=game.progression.bonuses(key)
	max_health=float(data.health)+float(bonus.health);health=max_health;meta_cooldown=float(bonus.cooldown)
	visual.configure(key,70.0 if key=="knight" else 66.0)
func center() -> Vector2: return position+Vector2(0,-30)
func block_capacity() -> int: return int(data.get("block",1))
func can_block() -> bool: return not knocked_out and rolling<=0 and velocity.length()<35
func perk(key: String) -> int: return int(perks.get(key,0))
func damage_scale() -> float: return (1.0+0.12*perk("power"))*(1.35 if war_cry>0 else 1.0)
func cooldown_scale() -> float: return 1.0-minf(0.30,meta_cooldown+0.08*perk("focus"))
func command_move(target: Vector2) -> void:
	if knocked_out: return
	path=game.navigation_path(position,target)
func cancel_action() -> void:
	action="";action_enemy=null;action_clock=0;action_released=false
func _physics_process(delta: float) -> void:
	if not game.running or game.game_over: return
	for slot in range(2): cooldowns[slot]=maxf(0,cooldowns[slot]-delta)
	attack_cooldown=maxf(0,attack_cooldown-delta);combat_delay=maxf(0,combat_delay-delta)
	protection=maxf(0,protection-delta);war_cry=maxf(0,war_cry-delta);hurt_time=maxf(0,hurt_time-delta)
	if knocked_out:
		revive_clock=maxf(0,revive_clock-delta)
		if revive_clock<=0:
			knocked_out=false;health=max_health;protection=1.5;position=game.level_definition.hero_spawn;cancel_action();visual.show_state("idle",Vector2.LEFT)
		queue_redraw();return
	if game.blocking.load_for(self)>0: combat_delay=5.0
	if combat_delay<=0: health=minf(max_health,health+max_health*0.08*delta)
	var move:=Input.get_vector("move_left","move_right","move_up","move_down")
	if move.length()>0.05: path.clear()
	elif not path.is_empty():
		while not path.is_empty() and position.distance_to(path[0])<10: path.remove_at(0)
		if not path.is_empty(): move=(path[0]-position).normalized()
	if rolling>0:
		rolling=maxf(0,rolling-delta);velocity=roll_direction*520;move_and_slide();queue_redraw();return
	if move.length()>0.1:
		facing=move.normalized()
		if action!="" and action_released: cancel_action()
	if action!="":
		action_clock+=delta
		# Animation frame events are primary; fixed-time fallback handles dropped render frames.
		if not action_released and action_clock>=action_duration*ArenaMotion.release_fraction(class_id,action): release_action()
		if action_clock>=action_duration: cancel_action()
	var planted: bool=action!="" and not action_released
	var desired: Vector2=move*float(data.speed)*(1.0+0.07*perk("haste"))
	velocity=Vector2.ZERO if planted else velocity.move_toward(desired,(2500.0 if move.length()>0.1 else 4800.0)*delta)
	move_and_slide()
	position=position.clamp(Vector2(15,95),ArenaLevelCatalog.SIZE-Vector2(15,20))
	if action=="":
		visual.show_state("hurt" if hurt_time>0 else ("walk" if velocity.length()>5 else "idle"),facing,0.24)
		if hurt_time<=0 and velocity.length()>5:visual.speed_scale=ArenaMotion.stride_scale(velocity.length(),visual.visual_size)
	if Input.is_action_pressed("shoot") and not game.input_blocked() and not game.suppress_primary and attack_cooldown<=0 and action=="":
		var enemy: Node2D=game.nearest_enemy(center(),float(data.reach))
		if enemy!=null: begin_attack(enemy)
	visual.modulate=Color(2.1,1.6,1.4) if hurt_time>0 else Color(1,1,1,0.62 if protection>0 and fmod(protection,0.16)<0.08 else 1.0)
	queue_redraw()
func begin_attack(enemy: Node2D) -> bool:
	if knocked_out or action!="" or attack_cooldown>0 or not is_instance_valid(enemy): return false
	facing=(enemy.position-position).normalized();action="attack";action_enemy=enemy;action_target=enemy.center()
	action_duration=minf(0.56,float(data.interval)/(1.0+0.1*perk("rapid")));action_clock=0;action_released=false
	attack_cooldown=float(data.interval)/(1.0+0.1*perk("rapid"));combat_delay=5.0
	visual.show_state("attack",facing,action_duration);visual.frame=0;return true
func cast(slot: int, point: Vector2) -> bool:
	if slot<0 or slot>1 or knocked_out or game.game_over or not game.running or cooldowns[slot]>0: return false
	if action in ["small","ultimate"] and not action_released:return false
	cancel_action()
	var relative:=point-position
	if relative.length()>430: point=position+relative.normalized()*430
	action_target=point.clamp(Vector2(0,90),ArenaLevelCatalog.SIZE);facing=(point-position).normalized() if relative.length()>5 else facing
	action="small" if slot==0 else "ultimate";action_clock=0;action_released=false;action_duration=0.48 if slot==0 else 0.72
	cooldowns[slot]=float(data.small_cd if slot==0 else data.ultimate_cd)*cooldown_scale()
	combat_delay=5.0
	if class_id=="ranger" and slot==0:
		roll_direction=Input.get_vector("move_left","move_right","move_up","move_down")
		if roll_direction.length()<0.1: roll_direction=facing
		rolling=0.27;protection=maxf(protection,0.36);empower_shot=perk("small");game.blocking.release(self)
	visual.show_state(action,facing,action_duration);visual.frame=0;return true
func _animation_frame() -> void:
	if action!="" and not action_released and visual.frame>=3: release_action()
func _animation_finished() -> void:
	if not knocked_out and action!="": cancel_action()
func release_action() -> void:
	if action_released or knocked_out or action=="": return
	action_released=true
	var power:=damage_scale()
	if action=="attack":
		shots+=1
		if class_id=="knight":
			game.cone_damage(position,facing,100,float(data.damage)*power,0,"hero")
			game.effect(position+Vector2(0,-20),100,ArenaCombat.colour(0),"slash",0.22,facing)
			game.audio.play("blade")
		else:
			if is_instance_valid(action_enemy) and not action_enemy.dead:
				var pierce: int=(1 if shots%3==0 else 0)+empower_shot if class_id=="ranger" else 0
				game.fire_projectile(center(),action_enemy.center(),float(data.damage)*power,int(data.type),"hero",{"target":action_enemy,"pierce":pierce,"expose":class_id=="mage","appearance":"arrow" if class_id=="ranger" else "magic"})
				empower_shot=0
			game.audio.play("bow" if class_id=="ranger" else "shoot")
	elif action=="small":
		var rank:=perk("small")
		match class_id:
			"knight":
				game.cone_damage(position,facing,145,85*power*(1+rank*0.22),0,"hero",1.0+rank*0.2)
				game.effect(position,145,Color("efbe78"),"slam",0.45,facing);game.audio.play("explode")
			"ranger": game.effect(position,45,Color("b4d6a0"),"roll",0.3,roll_direction)
			"mage":
				game.area_damage(position,125+rank*15,65*power,1,"hero",0,3.0)
				game.effect(position,125+rank*15,Color("9adeff"),"frost",0.6);game.audio.play("crit")
	elif action=="ultimate":
		var rank:=perk("ultimate")
		match class_id:
			"knight":
				war_cry=6+rank;game.war_cry_position=position;game.war_cry_clock=war_cry
				game.effect(position,230,Color("f2c36e"),"banner",0.9);game.audio.play("phase")
			"ranger":
				for index in range(6+rank):
					game.delayed_attack(action_target,135,30*power,0,"hero",0.4+index*0.32,{"arrow_rain":true})
				game.audio.play("bow")
			"mage":
				game.delayed_attack(action_target,155,205*power*(1+rank*0.2),1,"hero",0.85,{"stun":1.2})
				game.effect(action_target,155,Color("caa4ff"),"meteor",0.85);game.audio.play("phase")
func take_hit(amount: float, damage_type: int, melee := false) -> float:
	if knocked_out or protection>0 or game.game_over: return 0.0
	var adjusted: float=amount*(0.85 if melee and class_id=="knight" and game.blocking.load_for(self)>0 else 1.0)
	if war_cry>0: adjusted*=0.7
	var taken:=minf(health,ArenaCombat.resolve(adjusted,damage_type,0,0));health-=taken;combat_delay=5;hurt_time=0.24
	game.audio.play("hurt");game.effect(center(),17,ArenaCombat.colour(damage_type),"hit",0.16)
	if health<=0:
		health=0;knocked_out=true;revive_clock=15.0;velocity=Vector2.ZERO;rolling=0;path.clear();cancel_action();game.blocking.release(self)
		visual.show_state("down",facing,0.65)
	return taken
func add_xp(amount: int) -> void:
	xp+=amount
	while xp>=xp_target:
		xp-=xp_target;level+=1;xp_target=80+(level-1)*40;game.queue_choice()
func apply_perk(key: String) -> bool:
	if key not in ArenaDefinitions.PERKS or perk(key)>=int(ArenaDefinitions.PERKS[key].max): return false
	perks[key]=perk(key)+1
	if key=="vitality":
		var old:=max_health;max_health=float(data.health)*(1+0.12*perk("vitality"))+float(game.progression.bonuses(class_id).health);health+=max_health-old
	return true
func _draw() -> void:
	draw_ellipse_shadow()
	if knocked_out: return
	draw_arc(Vector2.ZERO,16,0,TAU,24,Color("b7e1d6"),1.5,true)
func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.4));draw_circle(Vector2.ZERO,17,Color(0.08,0.14,0.1,0.35));draw_set_transform(Vector2.ZERO)
