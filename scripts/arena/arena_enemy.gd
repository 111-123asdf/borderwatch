class_name ArenaEnemy
extends Node2D
var game: Node2D
var kind: String="fox"
var route_id:=0
var progress:=0.0
var road_curve: Curve2D
var bridge_branch: String=""
var _last_draw_sig:=-1
var health:=65.0
var max_health:=65.0
var data: Dictionary={}
var dead:=false
var elite:=false
var rule_main := false
var rule_front := false
var rule_pushed := false
var is_guard:=false
var tower_weakness_clock:=0.0
var tower_frost_layers:=0
var tower_frost_clock:=0.0
var tower_frost_lock:=0.0
var tower_control_clock:=0.0
var tower_control_lock:=0.0
var tower_freezing:=false
var tower_shock_clock:=0.0
var tower_impact_offset:=Vector2.ZERO
var home:=Vector2.ZERO
var blocker: Node2D
var stun:=0.0
var slow:=0.0
var slow_amount:=0.45
var frost_stacks:=0
var marked:=0.0
var mark_bonus:=0.0
var last_tower: Node2D
var exposure:=0.0
var melee_clock:=0.0
var melee_windup:=0.0
var melee_target: Node2D
var ranged_clock:=1.0
var windup:=0.0
var aim:=Vector2.ZERO
var facing:=Vector2.RIGHT
var hurt_time:=0.0
var movement_speed:=0.0
var burn_clock:=0.0
var burn_dps:=0.0
var boss_phase:=0
var barrier_shield:=0.0
var fracture:=0.0
var slam_clock:=4.5
var visual: ArenaCreature
var radius:=19.0
func _ready() -> void:
	data=ArenaDefinitions.enemy(kind)
	var scale_hp: float=1.0 if is_guard else 1.0+0.11*maxi(0,game.cycle-1)
	max_health=float(data.health)*scale_hp*(1.65 if elite else 1.0);health=max_health
	visual=ArenaCreature.new();add_child(visual)
	var look: String="rune_warden" if kind=="breacher" else kind
	visual.configure(look,{"fox":43.0,"brute":67.0,"wisp":49.0,"spearman":58.0,"spore":51.0,"moth":115.0,"construct_hound":46.0,"rune_warden":68.0,"astral_prism":58.0,"rift_bomber":50.0,"void_harvester":78.0,"colossus":128.0}.get(kind,50.0))
	if kind=="moth":radius=40
	elif kind=="colossus":radius=42
	elif kind=="void_harvester":radius=26
	var information:=Control.new();information.position=Vector2(-25,-visual.base_height);information.size=Vector2(50,visual.base_height);information.mouse_filter=Control.MOUSE_FILTER_PASS
	information.tooltip_text=data.name+" · "+ArenaCombat.label(data.type)+"\n物理抗性 "+str(int(float(data.armour)*100))+"%\n法术抗性 "+str(int(float(data.resistance)*100))+"%"
	add_child(information)
func is_boss() -> bool:return bool(data.get("boss",false)) or kind in ["moth","colossus"]
func center() -> Vector2:return position+Vector2(0,-radius)
func block_weight() -> int:return maxi(int(data.capacity),2 if elite else 1)
func _update_draw_dirty() -> void:
	var sig: int=int(health)+(int(barrier_shield)<<12)+(1<<22 if marked>0.0 else 0)+(1<<23 if fracture>0.0 else 0)+(1<<24 if windup>0.0 else 0)+(1<<25 if stun>0.0 else 0)
	if game.condition_lab:
		var ranks: Dictionary=game.passive_ranks
		var threshold: float=game.hero.conditions.enemy_hp_threshold()
		sig=hash([sig,ranks.get("hunter",0),ranks.get("opener",0),threshold,ranks.get("breaker",0),health>=max_health*0.99,health<=max_health*threshold])
	if windup>0.0 or sig!=_last_draw_sig:
		_last_draw_sig=sig
		queue_redraw()
func speed_scale() -> float:
	var altar_slow: float=game.altar_slow_at(center()) if game!=null and not game.altars.is_empty() else 0.0
	var boss_boost: float=1.2 if kind=="colossus" and boss_phase>=2 else 1.0
	return boss_boost*(1.0-altar_slow)

func movement_factor() -> float:
	if tower_frost_layers<=0: return 1.0-(slow_amount if slow>0.0 else 0.0)
	var frost:=float(tower_frost_layers)*ArenaTowerTrial.FROST_STEP
	if is_boss(): frost=minf(0.30,frost*0.5)
	elif elite: frost*=0.7
	return 1.0-maxf(slow_amount if slow>0.0 else 0.0,frost)

func travel_velocity() -> Vector2:
	if is_guard or is_instance_valid(blocker) or windup>0.0 or melee_windup>0.0 or stun>0.0 or tower_control_clock>0.0:
		return Vector2.ZERO
	var road: Curve2D=game.enemy_road(self)
	var ahead:=road.sample_baked(minf(road.get_baked_length(),progress+4.0),true)
	return position.direction_to(ahead)*float(data.speed)*speed_scale()*movement_factor()

func tower_frost(freeze_time: float,layers:=1,limit:=ArenaTowerTrial.FROST_LIMIT) -> void:
	if tower_frost_lock>0.0 or tower_freezing: return
	tower_frost_layers+=layers
	tower_frost_clock=ArenaTowerTrial.FROST_TTL
	if tower_frost_layers>=limit:
		if accept_tower_control(freeze_time):
			tower_frost_layers=0
			tower_freezing=true
		else: tower_frost_layers=limit-1
	queue_redraw()

func tower_shock(duration: float, distance: float, origin: Vector2) -> void:
	if is_boss():
		if tower_control_lock<=0.0 and tower_control_clock<=0.0:
			tower_impact_offset=origin.direction_to(position)*distance*0.30
	else:
		push_back(distance*(0.50 if elite else 1.0))
	var repeat_scale:=0.6 if tower_shock_clock>0.0 else 1.0
	if accept_tower_control(duration*repeat_scale): tower_shock_clock=6.0

func accept_tower_control(duration: float) -> bool:
	if is_boss():
		if tower_control_lock>0.0 or tower_control_clock>0.0: return false
		tower_control_clock=ArenaTowerTrial.BOSS_CONTROL
	else:
		tower_control_clock=maxf(tower_control_clock,duration*(0.60 if elite else 1.0))
	queue_redraw()
	return true

func tick_tower_effects(delta: float) -> void:
	var had_status:=tower_weakness_clock>0.0 or tower_frost_layers>0 or tower_control_clock>0.0
	tower_weakness_clock=maxf(0.0,tower_weakness_clock-delta)
	tower_frost_clock=maxf(0.0,tower_frost_clock-delta)
	tower_frost_lock=maxf(0.0,tower_frost_lock-delta)
	tower_control_lock=maxf(0.0,tower_control_lock-delta)
	tower_shock_clock=maxf(0.0,tower_shock_clock-delta)
	if tower_frost_clock<=0.0: tower_frost_layers=0
	if tower_control_clock>0.0:
		tower_control_clock=maxf(0.0,tower_control_clock-delta)
		if tower_control_clock<=0.0:
			if is_boss(): tower_control_lock=ArenaTowerTrial.BOSS_CONTROL_LOCK
			if tower_freezing: tower_frost_lock=ArenaTowerTrial.FROST_LOCK
			tower_freezing=false
	if not tower_impact_offset.is_zero_approx():
		tower_impact_offset=tower_impact_offset.move_toward(Vector2.ZERO,35.0*delta)
		visual.position=tower_impact_offset
	if had_status: queue_redraw()

func damage_scale() -> float:
	return 1.0+0.06*maxi(0,game.cycle-1)
func _physics_process(delta: float) -> void:
	if not game.running or game.game_over or dead:return
	movement_speed=0.0
	if game.tower_lab or game.defense_rules or tower_control_clock>0.0 or tower_control_lock>0.0: tick_tower_effects(delta)
	if burn_clock>0:
		var tick: float=burndps_pick(delta)
		health-=tick;game.damage_stats["hero"]=float(game.damage_stats.get("hero",0))+tick
		burn_clock=maxf(0,burn_clock-delta)
		if health<=0:
			dead=true;game.enemy_defeated(self);return
	stun=maxf(0,stun-delta);slow=maxf(0,slow-delta);marked=maxf(0,marked-delta);exposure=maxf(0,exposure-delta);fracture=maxf(0,fracture-delta);melee_clock=maxf(0,melee_clock-delta);ranged_clock=maxf(0,ranged_clock-delta);hurt_time=maxf(0,hurt_time-delta)
	if kind=="colossus":slam_clock=maxf(0,slam_clock-delta)
	if stun>0 or tower_control_clock>0:windup=0;melee_windup=0;melee_target=null;visual.pause();queue_redraw();return
	if melee_windup>0:
		melee_windup=maxf(0,melee_windup-delta)
		if melee_windup<=0 and is_instance_valid(melee_target) and melee_target.can_block() and position.distance_to(melee_target.position)<58 and (melee_target!=game.hero or not game.hero.knocked_out):
			melee_target.take_hit(float(data.damage)*damage_scale()*(1.25 if elite else 1.0),int(data.type),true)
	if windup>0:
		windup=maxf(0,windup-delta)
		if windup<=0:release_ranged()
	if is_guard:
		var target: Vector2=home
		if not game.hero.knocked_out and game.hero.position.distance_to(home)<165:target=game.hero.position
		var move: Vector2=target-position
		if move.length()>27 and windup<=0 and melee_windup<=0:
			movement_speed=float(data.speed)*speed_scale()*(movement_factor() if game.tower_lab or game.defense_rules else 1.0)
			position+=move.normalized()*movement_speed*delta
			facing=move.normalized();visual.show_pose("walk",facing);visual.match_stride(movement_speed)
		if position.distance_to(game.hero.position)<38 and not game.hero.knocked_out:melee(game.hero)
	elif is_instance_valid(blocker) and blocker.can_block():
		facing=(blocker.position-position).normalized();visual.show_pose("attack",facing);melee(blocker)
	else:
		blocker=null
		if windup<=0 and melee_windup<=0:
			var distance: float=float(data.speed)*speed_scale()*movement_factor()*delta
			var previous := progress
			progress+=distance
			var road: Curve2D=game.enemy_road(self)
			if not game.selected_defense_cards.is_empty():
				game.orders.advance(self,previous,road)
			if progress>=road.get_baked_length():
				var extra: int=game.orders.leaked(self)
				game.core_hit(game.core_max if is_boss() else ArenaDefinitions.leak_damage(kind,elite)+extra);game.remove_enemy(self);return
			var next: Vector2=road.sample_baked(progress,true)
			movement_speed=distance/delta
			facing=(next-position).normalized();position=next;visual.show_pose("walk",facing);visual.match_stride(distance/delta)
	if ranged_clock<=0 and kind in ["wisp","spearman","spore","moth","astral_prism","rift_bomber","colossus"] and position.distance_to(game.hero.position)<(640 if is_boss() else 350) and not game.hero.knocked_out:
		aim=game.hero.center()+game.hero.velocity*0.12;windup=0.7 if kind=="spearman" else (0.75 if kind=="colossus" else 0.55);ranged_clock=3.2 if is_boss() else 3.0
		visual.show_pose("attack",(aim-position).normalized());visual.frame=0
	if kind=="moth":
		var phase:=2 if health<max_health*0.33 else (1 if health<max_health*0.66 else 0)
		if phase>boss_phase:
			boss_phase=phase
			for index in range(3):game.spawn_enemy("fox",route_id,maxf(0,progress-65-index*30))
			game.effect(position,90,Color("e9adbf"),"summon",0.8)
	elif kind=="colossus":
		_check_colossus_phase()
		if slam_clock<=0 and not game.hero.knocked_out and position.distance_to(game.hero.position)<480:
			slam_clock=4.8 if boss_phase<2 else 3.6
			var center_pt:Vector2=game.hero.position
			if boss_phase>=2:
				for k in range(3):
					var off:=Vector2.RIGHT.rotated(k*TAU/3.0+0.4)*85.0
					game.delayed_attack((center_pt+off).clamp(Vector2(60,110),game.world_size()-Vector2(60,40)),95,float(data.damage)*damage_scale()*1.15,1,"enemy",1.25,{"telegraph":"arcane_slam"})
			else:
				game.delayed_attack(center_pt,108,float(data.damage)*damage_scale()*1.35,1,"enemy",1.15,{"telegraph":"arcane_slam"})
	visual.modulate=Color.WHITE if visual.feedback.material!=null and game.feel.enabled else ((Color(1.05,1.0,0.95) if bool(game.campaign.data.reduced_motion) else Color(1.8,1.5,1.3)) if hurt_time>0 else Color.WHITE)
	_update_draw_dirty()
func _check_colossus_phase() -> void:
	if kind!="colossus" or dead:return
	var cphase:=2 if health<max_health*0.33 else (1 if health<max_health*0.67 else 0)
	while boss_phase<cphase:
		boss_phase+=1
		if boss_phase==1:
			barrier_shield=520.0
			for index in range(2):game.spawn_enemy("astral_prism",route_id,maxf(0,progress-55-index*35))
			game.effect(center(),110,Color("8be4ff"),"upgrade",0.8)
		elif boss_phase==2:
			slam_clock=0.35
			game.effect(center(),125,Color("d89cff"),"upgrade",0.9)

func melee(target: Node2D) -> void:
	if melee_clock>0 or not is_instance_valid(target):return
	melee_clock=1.15;visual.show_pose("attack",(target.position-position).normalized());visual.play("attack");visual.frame=0
	melee_target=target;melee_windup=0.3
func release_ranged() -> void:
	if not not game.hero.knocked_out:return
	match kind:
		"spore":
			game.delayed_attack(aim,67,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),1,"enemy",0.9,{"origin":center()})
		"moth":
			for index in range(12):
				var direction:=Vector2.RIGHT.rotated(TAU*index/12.0)
				game.fire_projectile(center(),center()+direction*600,float(data.damage)*damage_scale(),1,"enemy",{"speed":145.0})
		"colossus":
			var base_dir:=(aim-center()).angle()
			for index in range(5):
				var spread:=(index-2)*0.28
				var dir:=Vector2.RIGHT.rotated(base_dir+spread)
				game.fire_projectile(center(),center()+dir*640,float(data.damage)*damage_scale(),1,"enemy",{"speed":215.0})
		_:
			game.fire_projectile(center(),aim,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),int(data.type),"enemy",{"speed":460.0 if kind=="spearman" else (240.0 if kind in ["astral_prism","rift_bomber"] else 175.0),"appearance":"spear" if kind=="spearman" else "magic"})
func take_hit(amount: float,damage_type: int,source: String,stagger := 0.0,chill_time := 0.0,pen_bonus := 0.0,attack: String="attack",condition_hit: Dictionary={}) -> float:
	if dead:return 0
	if source=="hero" and elite and not is_boss() and condition_hit.get("rule_basic",false) and game.phase=="spawn" and game.orders.can_mark():
		game.orders.marked=self
		game.orders.mark_used=true
	if source=="tower" and game.orders.marked==self and condition_hit.get("auto_tower",false):
		amount*=1.6
	var low: bool=health<=max_health*game.hero.mod("execute_threshold")
	var pen:=pen_bonus
	if source=="hero":
		pen+=game.hero.armor_pen()
		if exposure>0 and game.hero.has_link("starlight","pierce"): pen+=0.10
	var vulnerability: float=([0.10,0.11,0.12][game.hero.passive_rank] if game.hero.class_id=="mage" else 0.10) if exposure>0 else 0.0
	var condition_result: Dictionary={}
	if source=="hero" and game.condition_lab and not condition_hit.is_empty() and amount>0.0:
		var hero: ArenaHero=game.hero
		condition_result=hero.conditions.resolve_hit(self,int(hero.data.type),hero.health,hero.max_health,condition_hit,game.rng)
		amount*=float(condition_result.multiplier)
	var damage:=ArenaCombat.resolve(amount,damage_type,float(data.armour),float(data.resistance),vulnerability,pen)
	if marked>0:damage*=1.0+mark_bonus
	var exploits_weakness:=source=="hero" and tower_weakness_clock>0.0 and damage>0.0
	if exploits_weakness: damage*=1.0+ArenaTowerTrial.WEAKNESS_BONUS
	if kind!="astral_prism" and game.has_method("prism_ward_reduction"):damage*=1.0-game.prism_ward_reduction(center())
	if source=="hero" and (elite or is_boss()) and game.has_keystone("execute_prism"):damage*=1.32
	if source in ["tower","soldier"] and game.has_keystone("fracture"):fracture=4.0
	var trigger_frac: bool=(source=="hero" and attack!="fracture_proc" and fracture>0.0 and game.has_keystone("fracture"))
	if trigger_frac:fracture=0.0
	if source!="enemy" and not is_boss() and game.has_keystone("execute_prism") and health-maxf(0.0,damage-barrier_shield)<=max_health*0.22:
		damage=health+barrier_shield
		game.gold+=4;game.add_resonance(6.0)
	var absorbed:=minf(barrier_shield,damage);barrier_shield-=absorbed
	var hp_damage:=minf(health,damage-absorbed)
	var total_dealt:=absorbed+hp_damage
	health-=hp_damage;hurt_time=0.12
	if exploits_weakness and total_dealt>0.0:
		tower_weakness_clock=0.0
		game.tower_trial_stats.weakness_used+=1
		game.effect(center(),15.0,Color("f1cd8b"),"hit",0.22)
		queue_redraw()
	_check_colossus_phase()
	if not is_boss():stun=maxf(stun,stagger);slow=maxf(slow,chill_time)
	game.damage_stats[source]=float(game.damage_stats.get(source,0))+total_dealt
	if source in ["hero","tower","soldier"] and attack!="resonance" and total_dealt>0:game.add_resonance_on_hit(total_dealt)
	game.feedback(center(),total_dealt,damage_type,health<=0,source,self,attack,condition_result)
	if trigger_frac and game.has_method("trigger_fracture_burst"):game.trigger_fracture_burst(center(),game.hero.attack_damage()*1.20)
	if health<=0:
		dead=true
		if source=="hero": game.hero.note_kill(low)
		game.enemy_defeated(self)
	return total_dealt
func apply_mark(time: float,bonus: float) -> void:
	if dead:return
	marked=maxf(marked,time);mark_bonus=maxf(mark_bonus,bonus)
func chill(amount: float,time: float) -> void:
	if dead:return
	slow_amount=amount;slow=maxf(slow,time)
func frost_hit(amount: float,time: float,stacks: int,freeze: float) -> void:
	if dead:return
	chill(amount,time);frost_stacks+=1
	if frost_stacks>=maxi(stacks,1):
		frost_stacks=0;stun=maxf(stun,freeze);game.effect(center(),24,Color("bfe6ff"),"hit",0.32)
func push_back(amount: float) -> void:
	if is_boss() or is_guard:return
	progress=maxf(0,progress-amount);position=game.enemy_road(self).sample_baked(progress,true)
func ignite(dps: float,duration: float) -> void:
	if dead:return
	burn_dps=maxf(burn_dps,dps);burn_clock=maxf(burn_clock,duration)
func expose(duration: float) -> void:
	if dead:return
	exposure=maxf(exposure,duration)
func burndps_pick(delta: float) -> float:
	var tick:=burn_dps*delta
	if exposure>0 and game.hero.has_link("starlight","burn"): tick*=1.2
	return minf(tick,health)
func _draw() -> void:
	if tower_weakness_clock>0.0 or tower_frost_layers>0 or tower_control_clock>0.0: draw_tower_status()
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.4));draw_circle(Vector2.ZERO,radius*0.8,Color(0.07,0.13,0.1,0.25));draw_set_transform(Vector2.ZERO)
	var full_cue: bool=game.condition_lab and (game.passive_rank("hunter")>0 or game.passive_rank("opener")>0) and health>=max_health*0.99
	var threshold: float=game.hero.conditions.enemy_hp_threshold() if game.condition_lab and is_instance_valid(game.hero) else 0.0
	var high_defence_cue: bool=game.condition_lab and is_instance_valid(game.hero) and game.passive_rank("breaker")>0 and ArenaConditions.high_defence(self,int(game.hero.data.type))
	if health<max_health or full_cue or high_defence_cue or threshold>0.0:
		draw_rect(Rect2(-18,-visual.base_height-5,36,3),Color("25372b"));draw_rect(Rect2(-18,-visual.base_height-5,36*health/max_health,3),Color("ce8274"))
		if full_cue: draw_rect(Rect2(-19,-visual.base_height-6,38,5),Color("fff4df"),false,1.0)
		if threshold>0.0:
			var mark_x: float=-18.0+36.0*threshold
			draw_line(Vector2(mark_x,-visual.base_height-7),Vector2(mark_x,-visual.base_height),Color("ffe0a0") if health<=max_health*threshold else Color("97917e"),1.0)
		if high_defence_cue:
			var shield:=ArenaMenuArt.utility("shield")
			if shield!=null: draw_texture_rect(shield,Rect2(-31,-visual.base_height-9,10,10),false)
	if barrier_shield>0.0:
		draw_rect(Rect2(-22,-visual.base_height-10,44*minf(1.0,barrier_shield/520.0),3),Color("7ce8ff"))
	if kind=="astral_prism":
		draw_set_transform(Vector2(0,-4),0.0,Vector2(1.0,0.58))
		draw_arc(Vector2.ZERO,135.0,0,TAU,36,Color(0.56,0.78,1.0,0.13),1.5,true)
		draw_set_transform(Vector2.ZERO)
	if elite or (game.condition_lab and is_boss()):draw_arc(Vector2(0,-visual.base_height),7,PI,TAU,12,Color("f6cc79"),2)
	if marked>0:draw_arc(Vector2(0,-visual.base_height*0.45),radius+7,0,TAU,28,Color(0.86,0.95,0.72,0.45),2,true)
	if fracture>0.0:
		var fc:=Vector2(0,-visual.base_height-13)
		draw_colored_polygon(PackedVector2Array([fc+Vector2(0,-6),fc+Vector2(5,0),fc+Vector2(0,6),fc+Vector2(-5,0)]),Color("f6c26b"))
	if windup>0 and kind=="spearman":
		var charge: float=1.0-clampf(windup/0.7,0.0,1.0)
		var glint:=Vector2(facing.x*14.0,-26.0)
		var star:=6.0+4.0*(1.0-charge)
		draw_line(glint-Vector2(star,0),glint+Vector2(star,0),Color(1.0,0.84,0.46,0.85),2.0,true)
		draw_line(glint-Vector2(0,star),glint+Vector2(0,star),Color(1.0,0.84,0.46,0.85),2.0,true)
		draw_circle(glint,3.0,Color(1.0,0.94,0.72,0.9))
		var offset: Vector2=aim-position
		draw_set_transform(offset,0.0,Vector2(1.0,0.58))
		draw_circle(Vector2.ZERO,16.0,Color(0.95,0.58,0.34,0.14))
		draw_arc(Vector2.ZERO,maxf(4.0,16.0*(1.0-charge*0.45)),0,TAU,24,Color(0.98,0.68,0.38,0.55),1.5,true)
		draw_set_transform(Vector2.ZERO)

func draw_tower_status() -> void:
	var y: float=-visual.base_height-12.0
	if tower_weakness_clock>0.0:
		var center:=Vector2(-5 if tower_frost_layers>0 or tower_control_clock>0.0 else 0,y)
		draw_polyline(PackedVector2Array([center+Vector2(-4,0),center+Vector2(0,4),center+Vector2(4,0),center+Vector2(0,-4),center+Vector2(-4,0)]),Color("edc182"),1.4,true)
		draw_line(center+Vector2(-4,6),center+Vector2(-4+8.0*tower_weakness_clock/ArenaTowerTrial.WEAKNESS_TIME,6),Color("edc182"),1.2,true)
	if tower_control_clock>0.0:
		var tint:=Color("b8eaff") if tower_freezing else Color("efdcb0")
		var point:=Vector2(6 if tower_weakness_clock>0.0 else 0,y)
		draw_arc(point,4.5,-PI*0.5,-PI*0.5+TAU*minf(1.0,tower_control_clock/1.2),18,tint,2.1,true)
	elif tower_frost_layers>0:
		var start:=2.0 if tower_weakness_clock>0.0 else -float(tower_frost_layers-1)*2.0
		for layer in range(tower_frost_layers): draw_circle(Vector2(start+layer*4.0,y),1.5,Color("b8eaff"))
	if windup>0 and kind in ["moth","colossus"]:
		var charge: float=1.0-clampf(windup/(0.75 if kind=="colossus" else 0.55),0.0,1.0)
		var ring_col:=Color(0.76,0.52,1.0,0.62) if kind=="colossus" else Color(0.92,0.58,0.68,0.52)
		draw_set_transform(Vector2(0,-6),0.0,Vector2(1.0,0.58))
		draw_circle(Vector2.ZERO,52.0*charge,Color(ring_col.r,ring_col.g,ring_col.b,0.14))
		for seg in range(10):
			var a0:=seg*(TAU/10.0)
			draw_arc(Vector2.ZERO,52.0,a0,a0+(TAU/10.0)*0.55,4,ring_col,2.0,true)
		draw_set_transform(Vector2.ZERO)
