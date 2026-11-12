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
var visual: ArenaCreature
var facing:=Vector2.RIGHT
var hurt_time:=0.0
func _ready() -> void:
	visual=ArenaCreature.new();add_child(visual);visual.configure("soldier",43.0);refresh_stats(true)
func soldier_mod(key: String,fallback := 0.0) -> float:
	return tower.doc_mod(key,fallback) if is_instance_valid(tower) else fallback
func refresh_stats(fill := false) -> void:
	var old:=max_health
	max_health=(100.0+55.0*(tower.level-1))*(1.0+soldier_mod("soldier_health"))
	health=max_health if fill else minf(max_health,health+max_health-old)
func block_capacity() -> int: return maxi(1,int(soldier_mod("block_capacity",1)))
func taunt() -> bool: return soldier_mod("taunt")>0
func ranged() -> bool: return soldier_mod("soldier_range")>0
func attack_range() -> float: return soldier_mod("soldier_range",0.0)
func move_speed() -> float: return 110.0*(1.0+soldier_mod("soldier_speed"))
func can_block() -> bool: return not dead and not tower.destroyed
func _physics_process(delta: float) -> void:
	if not game.running or game.game_over:return
	if not is_instance_valid(tower) or tower.destroyed:game.soldiers.erase(self);queue_free();return
	attack_clock=maxf(0,attack_clock-delta);hurt_time=maxf(0,hurt_time-delta)
	if contact_clock>0:
		contact_clock=maxf(0,contact_clock-delta)
		if contact_clock<=0 and not dead and is_instance_valid(contact_target) and not contact_target.dead and position.distance_to(contact_target.position)<65:
			var damage: float=(7+5*(tower.level-1))*game.support_scale(position)
			var stun: float=0.0
			if charge_ready and soldier_mod("charge_stun")>0.0:
				stun=soldier_mod("charge_stun");charge_ready=false
			contact_target.take_hit(damage,0,"soldier",stun)
			game.effect(contact_target.center(),9,Color("e7c89a"),"hit",0.12)
	if dead:
		respawn_clock=maxf(0,respawn_clock-delta)
		if respawn_clock<=0:dead=false;health=max_health;position=tower.rally_point+Vector2((slot-1)*20,8+slot%2*15);visual.show_pose("walk",facing)
		return
	var target: Node2D
	for enemy in game.blocking.assignments:
		if is_instance_valid(enemy) and game.blocking.assignments[enemy]==self:target=enemy;break
	if target==null and ranged():
		var reach:=attack_range();var nearest: Node2D
		for enemy in game.enemies:
			if not is_instance_valid(enemy) or enemy.dead or enemy.is_guard:continue
			var distance: float=position.distance_to(enemy.center())
			if distance<reach:reach=distance;nearest=enemy
		target=nearest
	var destination: Vector2=tower.rally_point+Vector2((slot-1)*20,8+slot%2*15)
	if target!=null:
		facing=(target.position-position).normalized();visual.show_pose("attack",facing)
		if attack_clock<=0:
			attack_clock=1.0;visual.play("attack");visual.frame=0
			if ranged():
				game.fire_projectile(position+Vector2(0,-22),target.center(),(7+5*(tower.level-1))*game.support_scale(position),0,"soldier",{"target":target,"appearance":"arrow","slow_amount":soldier_mod("slow_amount"),"slow_time":soldier_mod("slow_time")})
			else:
				contact_target=target;contact_clock=0.333
	elif position.distance_to(destination)>4:
		charge_ready=true
		var move: Vector2=(destination-position).normalized();position+=move*move_speed()*delta;facing=move;visual.show_pose("walk",move)
	else:
		charge_ready=true
		visual.show_pose("walk",facing);visual.pause()
	visual.modulate=Color(2,1.5,1.3) if hurt_time>0 else Color.WHITE
	queue_redraw()
func take_hit(amount: float, damage_type: int, _melee := true) -> float:
	if dead:return 0.0
	var reduction:=0.15 if tower.level==3 else 0.0
	var taken:=minf(health,ArenaCombat.resolve(amount,damage_type,reduction,reduction));health-=taken;hurt_time=0.12
	if health<=0:
		health=0;dead=true;respawn_clock=10;game.blocking.release(self);visual.show_pose("down",facing)
	return taken
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.4));draw_circle(Vector2.ZERO,12,Color(0.1,0.15,0.1,0.3));draw_set_transform(Vector2.ZERO)
	if not dead and health<max_health:
		draw_rect(Rect2(-13,-48,26,3),Color("24392c"));draw_rect(Rect2(-13,-48,26*health/max_health,3),Color("a9ce82"))
