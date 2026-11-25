class_name ArenaSoldier
extends Node2D
var game: Node2D
var tower: Node2D
var slot:=0
var health:=100.0
var max_health:=100.0
var dead:=false
var respawn_clock:=0.0
var attack_clock:=0.0
var contact_clock:=0.0
var contact_target: Node2D
var charge_ready:=true
var deployment_left := 0.0
var visual: ArenaCreature
var facing:=Vector2.RIGHT
var hurt_time:=0.0
var combat_delay:=5.0
var healing:=false
var redeploying:=false
var march_path := PackedVector2Array()
var marching_between_camps := false

func march_to_flag() -> void:
	redeploy()
	marching_between_camps=true
	march_path=game.complete_defense_path(position,tower.rally_point)
func _ready() -> void:
	visual=ArenaCreature.new();add_child(visual);refresh_visual();refresh_stats(true)
	deployment_left=0.46
func visual_key() -> String:
	if is_instance_valid(tower) and tower.doctrine_id in ["shield","hunter","charge"]:
		return "soldier_" + tower.doctrine_id
	return "soldier_base"
func refresh_visual() -> void:
	if is_instance_valid(visual):
		var vkey := visual_key()
		visual.configure(vkey, 52.0 if vkey == "soldier_shield" else 47.0)
		visual.show_pose("attack" if contact_clock > 0.0 else "walk", facing)
func soldier_mod(key: String,fallback := 0.0) -> float:
	return tower.doc_mod(key,fallback) if is_instance_valid(tower) else fallback
func refresh_stats(fill := false) -> void:
	var old:=max_health
	var base: float=tower.trial_stat("health") if game.tower_lab else (160.0+50.0*(tower.level-1))
	max_health=base*(1.0+soldier_mod("soldier_health"))
	health=max_health if fill else minf(max_health,health+max_health-old)
func block_capacity() -> int:
	if not game.tower_lab and is_instance_valid(tower) and tower.level >= 2:
		return maxi(2, int(soldier_mod("block_capacity", 2)))
	return maxi(1,int(soldier_mod("block_capacity",1)))
func taunt() -> bool: return game.tower_lab or soldier_mod("taunt")>0 or (is_instance_valid(tower) and tower.level>=2)
func taunt_radius() -> float: return 64.0 if game.tower_lab else 60.0
func can_engage(enemy: ArenaEnemy) -> bool:
	return not game.tower_lab or (not enemy.is_boss() and int(enemy.data.capacity)<=1 and enemy.position.distance_squared_to(tower.rally_point)<=14400.0)
func melee_damage() -> float:
	var base: float=tower.base_power() if game.tower_lab else 7.0+5.0*(tower.level-1)
	return base
func ranged() -> bool: return soldier_mod("soldier_range")>0
func attack_range() -> float: return soldier_mod("soldier_range",0.0)
func move_speed() -> float: return 110.0*(1.0+soldier_mod("soldier_speed"))
func can_block() -> bool: return not dead and not tower.destroyed and not redeploying
func redeploy() -> void:
	redeploying=true
	contact_clock=0.0
	contact_target=null
	game.blocking.release(self)
func _slot_offset() -> Vector2:
	if not is_instance_valid(tower):
		return Vector2.ZERO
	var across: Vector2 = tower.destination_across() if tower.has_method("destination_across") else tower.rally_across
	if across.is_zero_approx():
		across = Vector2.DOWN
	if slot < 3:
		return across * ((float(slot) - 1.0) * 18.0)
	var tang := Vector2(-across.y, across.x)
	return tang * 14.0 + across * ((float(slot % 2) - 0.5) * 20.0)

func _physics_process(delta: float) -> void:
	if not game.running or game.game_over:return
	if not is_instance_valid(tower) or tower.destroyed:game.soldiers.erase(self);queue_free();return
	attack_clock=maxf(0,attack_clock-delta);hurt_time=maxf(0,hurt_time-delta)
	deployment_left=maxf(0.0,deployment_left-delta)
	if contact_clock>0:
		contact_clock=maxf(0,contact_clock-delta)
		if contact_clock<=0 and not dead and is_instance_valid(contact_target) and not contact_target.dead and position.distance_to(contact_target.position)<65:
			var damage:=melee_damage()
			var stun: float=0.0
			if not game.tower_lab and charge_ready and soldier_mod("charge_stun")>0.0:
				stun=soldier_mod("charge_stun");charge_ready=false
			contact_target.take_hit(damage,0,"soldier",stun,0.0,0.0,"soldier_strike",facing)
			if is_instance_valid(tower) and tower.has_method("gain_auto_xp"):
				tower.gain_auto_xp(2.2)
	if dead:
		if not (is_instance_valid(tower) and tower.has_method("is_sealed") and tower.is_sealed()):
			respawn_clock=maxf(0,respawn_clock-delta)
		if respawn_clock<=0:
			deployment_left=0.46
			var origin: Vector2=tower.position if game.tower_lab else tower.rally_point
			dead=false;health=max_health;position=origin+(Vector2((slot-1)*20,8+slot%2*15) if game.tower_lab else _slot_offset());visual.show_pose("walk",facing)
			redeploying=game.tower_lab
			if is_instance_valid(tower):tower.fire_clock=0.32
			game.effect(position,22,Color("f3d184"),"upgrade",0.28)
			ArenaBattleArt.emit_world_dust(position,Vector2(0,-14.0),18.0,Color("dcd2be"))
		return
	var target: Node2D
	for enemy in game.blocking.assignments:
		if is_instance_valid(enemy) and game.blocking.assignments[enemy]==self:target=enemy;break
	if target==null and not redeploying and ranged():
		var reach:=attack_range();var nearest: Node2D
		for enemy in game.domain_enemies("defense"):
			if not is_instance_valid(enemy) or enemy.dead or enemy.is_guard or (enemy.has_method("is_submerged") and enemy.is_submerged()):continue
			var distance: float=position.distance_to(enemy.center())
			if distance<reach:reach=distance;nearest=enemy
		target=nearest
	elif target==null and not redeploying and not game.tower_lab:
		var flag_pos: Vector2=tower.rally_point
		var best_score:=INF;var passer: Node2D
		for enemy in game.domain_enemies("defense"):
			if not is_instance_valid(enemy) or enemy.dead or enemy.is_guard or (enemy.has_method("is_submerged") and enemy.is_submerged()):continue
			if enemy.has_method("is_flying") and enemy.is_flying():continue
			if enemy.position.distance_squared_to(flag_pos)>95.0*95.0:continue
			var d2: float=position.distance_squared_to(enemy.position)
			if d2>105.0*105.0:continue
			if d2<best_score:best_score=d2;passer=enemy
		target=passer
	combat_delay=maxf(0.0,combat_delay-delta)
	if target!=null or contact_clock>0:combat_delay=5.0
	healing=combat_delay<=0 and health<max_health
	if healing:health=minf(max_health,health+max_health*0.10*delta)
	var destination: Vector2=tower.rally_slot(slot) if game.tower_lab else tower.rally_point+_slot_offset()
	if marching_between_camps:
		while not march_path.is_empty() and position.distance_to(march_path[0])<4: march_path.remove_at(0)
		if not march_path.is_empty() and not game.walkable(march_path[0]): march_path.clear()
		if not march_path.is_empty(): destination=march_path[0]
		elif position.distance_to(tower.rally_point)>45:
			march_path=game.complete_defense_path(position,tower.rally_point)
			return
		else: marching_between_camps=false
	if target!=null:
		deployment_left=0.0
		facing=(target.position-position).normalized()
		var chasing_target := not ranged()
		if chasing_target and position.distance_to(target.position)>36.0:
			position=position.move_toward(target.position,move_speed()*delta)
			visual.show_pose("walk",facing)
		else: visual.show_pose("attack",facing)
		if attack_clock<=0 and (not chasing_target or position.distance_to(target.position)<=48.0):
			var healer_speed: float=game.hero.healer_soldier_speed_bonus(position)
			attack_clock=1.0/(1.0+healer_speed);visual.play("attack");visual.frame=0
			if ranged():
				var arrow_dist := position.distance_to(target.position)
				game.fire_projectile(position+Vector2(0,-22),target.center(),melee_damage(),0,"soldier",{"target":target,"appearance":"arrow","arc_height":clampf(arrow_dist*0.16,14.0,42.0),"slow_amount":soldier_mod("slow_amount"),"slow_time":soldier_mod("slow_time"),"tower_kind":"barracks","doctrine_id":"hunter","feedback":"tower_arrow"})
			else:
				contact_target=target;contact_clock=0.333
	elif position.distance_to(destination)>4:
		charge_ready=true
		var move: Vector2=position.direction_to(destination)
		position=position.move_toward(destination,move_speed()*delta)
		facing=move;visual.show_pose("walk",move)
	else:
		charge_ready=true
		visual.show_pose("walk",facing);visual.pause()
	if redeploying and not marching_between_camps and position.distance_squared_to(destination)<=16.0: redeploying=false
	var emerging := deployment_left/0.46
	var door: Vector2 = tower.to_global(tower.swivel)
	visual.position = (door-position)*emerging
	if contact_clock>0.0 and not bool(game.campaign.data.reduced_motion):
		var wind := 1.0-contact_clock/0.333
		visual.position += facing*(-3.0*sin(wind*PI)+5.0*pow(wind,3))
	if visual.feedback.material!=null and game.feel.enabled:
		visual.modulate=Color(1.0,1.0,1.0,0.45 if dead else 1.0)
	else:
		visual.modulate=(Color(1.05,1.0,0.95) if bool(game.campaign.data.reduced_motion) else Color(1.6,1.35,1.2)) if hurt_time>0 else Color.WHITE
	if hurt_time>0 or healing or health<max_health or (Engine.get_physics_frames()+get_instance_id())%6==0:
		queue_redraw()
func take_hit(amount: float, damage_type: int, _melee := true) -> float:
	if dead:return 0.0
	combat_delay=5.0;healing=false
	var reduction:=0.15 if tower.level==3 and not game.tower_lab else 0.0
	var taken:=minf(health,ArenaCombat.resolve(amount,damage_type,reduction,reduction));health-=taken;hurt_time=0.12
	if visual.feedback.material!=null and game.feel.enabled:
		visual.feedback.impact(visual,false)
	if health<=0:
		health=0;dead=true;respawn_clock=tower.trial_stat("respawn") if game.tower_lab or game.defense_rules else 10.0
		game.blocking.release(self);visual.show_pose("down",facing)
		ArenaBattleArt.emit_world_dust(position,Vector2(-facing.x*16.0,-10.0),20.0,Color("c8bfa8"))
	return taken
func _draw() -> void:
	draw_set_transform(visual.position if is_instance_valid(visual) else Vector2.ZERO,0,Vector2(1,0.4));draw_circle(Vector2.ZERO,12,Color(0.1,0.15,0.1,0.3));draw_set_transform(Vector2.ZERO)
	if not dead and health<max_health:
		draw_rect(Rect2(-13,-48,26,3),Color("24392c"));draw_rect(Rect2(-13,-48,26*health/max_health,3),Color("a9ce82"))
		if healing:
			draw_line(Vector2(18,-49),Vector2(18,-43),Color("b5e49d"),2);draw_line(Vector2(15,-46),Vector2(21,-46),Color("b5e49d"),2)
