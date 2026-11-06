class_name ArenaEnemy
extends Node2D
var game: Node2D
var kind: String="fox"
var route_id:=0
var progress:=0.0
var health:=65.0
var max_health:=65.0
var data: Dictionary={}
var dead:=false
var elite:=false
var is_guard:=false
var camp_id:=-1
var home:=Vector2.ZERO
var blocker: Node2D
var stun:=0.0
var slow:=0.0
var exposure:=0.0
var melee_clock:=0.0
var melee_windup:=0.0
var melee_target: Node2D
var ranged_clock:=1.0
var windup:=0.0
var aim:=Vector2.ZERO
var facing:=Vector2.RIGHT
var hurt_time:=0.0
var boss_phase:=0
var visual: ArenaCreature
var radius:=19.0
func _ready() -> void:
	data=ArenaDefinitions.enemy(kind)
	var scale_hp: float=1.0+0.13*maxi(0,game.cycle-1)
	if is_guard:scale_hp=0.75
	max_health=float(data.health)*scale_hp*(1.65 if elite else 1.0);health=max_health
	visual=ArenaCreature.new();add_child(visual);visual.configure(kind,{"fox":43.0,"brute":67.0,"wisp":49.0,"spearman":58.0,"spore":51.0,"moth":115.0}.get(kind,50.0))
	if kind=="moth":radius=40
	var information:=Control.new();information.position=Vector2(-25,-visual.base_height);information.size=Vector2(50,visual.base_height);information.mouse_filter=Control.MOUSE_FILTER_PASS
	information.tooltip_text=data.name+" · "+ArenaCombat.label(data.type)+"\n物理抗性 "+str(int(float(data.armour)*100))+"%\n法术抗性 "+str(int(float(data.resistance)*100))+"%"
	add_child(information)
func center() -> Vector2:return position+Vector2(0,-radius)
func block_weight() -> int:return maxi(int(data.capacity),2 if elite else 1)
func _physics_process(delta: float) -> void:
	if not game.running or game.game_over or dead:return
	stun=maxf(0,stun-delta);slow=maxf(0,slow-delta);exposure=maxf(0,exposure-delta);melee_clock=maxf(0,melee_clock-delta);ranged_clock=maxf(0,ranged_clock-delta);hurt_time=maxf(0,hurt_time-delta)
	if stun>0:windup=0;melee_windup=0;melee_target=null;visual.pause();queue_redraw();return
	if melee_windup>0:
		melee_windup=maxf(0,melee_windup-delta)
		if melee_windup<=0 and is_instance_valid(melee_target) and melee_target.can_block() and position.distance_to(melee_target.position)<58:
			melee_target.take_hit(float(data.damage)*(1.25 if elite else 1.0),int(data.type),true)
	if windup>0:
		windup=maxf(0,windup-delta)
		if windup<=0:release_ranged()
	if is_guard:
		var target: Vector2=home
		if not game.hero.knocked_out and game.hero.position.distance_to(home)<165:target=game.hero.position
		var move: Vector2=target-position
		if move.length()>27 and windup<=0 and melee_windup<=0:position+=move.normalized()*float(data.speed)*delta;facing=move.normalized();visual.show_pose("walk",facing);visual.match_stride(float(data.speed))
		if position.distance_to(game.hero.position)<38:melee(game.hero)
	elif is_instance_valid(blocker) and blocker.can_block():
		facing=(blocker.position-position).normalized();visual.show_pose("attack",facing);melee(blocker)
	else:
		blocker=null
		if windup<=0 and melee_windup<=0:
			var distance: float=float(data.speed)*(0.55 if slow>0 else 1.0)*delta
			progress+=distance
			var road: Curve2D=game.routes[route_id]
			if progress>=road.get_baked_length():
				game.core_hit(game.core_max if kind=="moth" else (36 if kind=="brute" else 14));game.remove_enemy(self);return
			var next: Vector2=road.sample_baked(progress,true)
			facing=(next-position).normalized();position=next;visual.show_pose("walk",facing);visual.match_stride(distance/delta)
	if not game.hero.knocked_out and position.distance_to(game.hero.position)<(610 if kind=="moth" else 350) and ranged_clock<=0 and kind in ["wisp","spearman","spore","moth"]:
		aim=game.hero.center()+game.hero.velocity*0.12;windup=0.7 if kind=="spearman" else 0.55;ranged_clock=3.4 if kind=="moth" else 3.0
		visual.show_pose("attack",(aim-position).normalized());visual.frame=0
	if kind=="moth":
		var phase:=2 if health<max_health*0.33 else (1 if health<max_health*0.66 else 0)
		if phase>boss_phase:
			boss_phase=phase
			for index in range(3):game.spawn_enemy("fox",route_id,maxf(0,progress-65-index*30))
			game.effect(position,90,Color("e9adbf"),"summon",0.8)
	visual.modulate=Color(1.8,1.5,1.3) if hurt_time>0 else Color.WHITE
	queue_redraw()
func melee(target: Node2D) -> void:
	if melee_clock>0 or not is_instance_valid(target):return
	melee_clock=1.15;visual.show_pose("attack",(target.position-position).normalized());visual.play("attack");visual.frame=0
	melee_target=target;melee_windup=0.3
func release_ranged() -> void:
	if game.hero.knocked_out:return
	match kind:
		"spore":
			game.delayed_attack(aim,67,float(data.damage),1,"enemy",0.9,{"origin":center()})
		"moth":
			for index in range(12):
				var direction:=Vector2.RIGHT.rotated(TAU*index/12.0)
				game.fire_projectile(center(),center()+direction*600,float(data.damage),1,"enemy",{"speed":145.0})
		_:
			game.fire_projectile(center(),aim,float(data.damage),int(data.type),"enemy",{"speed":460.0 if kind=="spearman" else 175.0,"appearance":"spear" if kind=="spearman" else "magic"})
func take_hit(amount: float,damage_type: int,source: String,stagger := 0.0,chill := 0.0) -> float:
	if dead:return 0
	var damage:=minf(health,ArenaCombat.resolve(amount,damage_type,float(data.armour),float(data.resistance),0.1 if exposure>0 else 0.0))
	health-=damage;hurt_time=0.12
	if kind!="moth":stun=maxf(stun,stagger);slow=maxf(slow,chill)
	game.damage_stats[source]=float(game.damage_stats.get(source,0))+damage
	game.feedback(center(),damage,damage_type,health<=0)
	if health<=0:
		dead=true;game.enemy_defeated(self)
	return damage
func push_back(amount: float) -> void:
	if kind=="moth" or is_guard:return
	progress=maxf(0,progress-amount);position=game.routes[route_id].sample_baked(progress,true)
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.4));draw_circle(Vector2.ZERO,radius*0.8,Color(0.07,0.13,0.1,0.25));draw_set_transform(Vector2.ZERO)
	if health<max_health:
		draw_rect(Rect2(-18,-visual.base_height-5,36,3),Color("25372b"));draw_rect(Rect2(-18,-visual.base_height-5,36*health/max_health,3),Color("ce8274"))
	if elite:draw_arc(Vector2(0,-visual.base_height),7,PI,TAU,12,Color("f6cc79"),2)
	if windup>0 and kind=="spearman":draw_line(Vector2(0,-20),aim-position,Color(1,0.55,0.22,0.75),2,true)
	if windup>0 and kind=="moth":draw_arc(Vector2(0,-35),56,0,TAU,32,Color(1,0.4,0.45,0.6),3,true)
