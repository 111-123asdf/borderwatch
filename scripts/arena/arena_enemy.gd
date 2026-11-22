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
var chase_left:=0.0
var chase_recovery:=0.0
var returning:=false
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
var salt_slam_left:=0.0
var salt_move_clock:=0.0
# v0.23 Beast Legion capability state
var ability_clock:=2.4
var ability_windup:=0.0
var ability_kind:=""
var ability_target:=Vector2.ZERO
var aim_locked:=false
var dash_used:=false
var enraged:=false
var charge_left:=0.0
var roar_anim_left:=0.0
var roar_buff_clock:=0.0
var boulder_clock:=3.6
var _troll_regen_tick:=0.0
var visual: ArenaCreature
var radius:=19.0

func _ready() -> void:
	data=ArenaDefinitions.enemy(kind)
	var scale_hp: float=1.0 if is_guard else 1.0+0.11*maxi(0,game.cycle-1)
	max_health=float(data.health)*scale_hp*(1.65 if elite else 1.0);health=max_health
	visual=ArenaCreature.new();add_child(visual)
	var look: String="brute" if kind=="captain" else ("rune_warden" if kind=="breacher" else str(data.get("visual_kind",kind)))
	var heights := {
		"fox":43.0,"brute":67.0,"wisp":49.0,"spearman":58.0,"spore":51.0,"moth":115.0,"captain":82.0,
		"construct_hound":46.0,"rune_warden":68.0,"astral_prism":58.0,"rift_bomber":50.0,"void_harvester":78.0,"colossus":128.0,
		"fiddler":35.0,"mudshrimp":37.0,"salt_hermit":62.0,"anchor_crab":116.0,
		"pigsoldier":58.0,"rottooth_hyena":54.0,"throat_cutter":56.0,"scout_vulture":60.0,"skunk_bombardier":58.0,
		"turtle_shaman":60.0,"dreadeye_viper":64.0,"tusk_fighter":66.0,"bear_woodsman":78.0,"bear_vanguard":84.0,
		"darksteel_guard":92.0,"darksteel_boss":114.0,"two_headed_troll":136.0
	}
	visual.configure(look, float(heights.get(kind, 50.0)))
	if kind=="moth":radius=40
	elif kind in ["colossus","anchor_crab","two_headed_troll"]:radius=42
	elif kind=="darksteel_boss":radius=34
	elif kind in ["captain","void_harvester","darksteel_guard","bear_vanguard"]:radius=26
	elif kind in ["salt_hermit","bear_woodsman"]:radius=23
	if kind in ["darksteel_guard","darksteel_boss"]:
		ability_clock=3.0
	elif kind=="turtle_shaman":
		ability_clock=2.2
	elif kind=="bear_vanguard":
		ability_clock=2.0
	var information:=Control.new();information.position=Vector2(-25,-visual.base_height);information.size=Vector2(50,visual.base_height);information.mouse_filter=Control.MOUSE_FILTER_PASS
	var trait_str := str(data.get("trait",""))
	information.tooltip_text=data.name+" · "+ArenaCombat.label(data.type)+"\n物理抗性 "+str(int(float(data.armour)*100))+"% · 法术抗性 "+str(int(float(data.resistance)*100))+"%"+("\n"+trait_str if trait_str!="" else "")
	add_child(information)

func is_boss() -> bool:
	return kind in ["moth","colossus","anchor_crab","two_headed_troll"] or bool(data.get("boss",false))

func is_mini_boss() -> bool:
	return bool(data.get("mini_boss",false))

func is_flying() -> bool:
	return bool(data.get("flying",false))

func is_unstoppable() -> bool:
	return is_boss() or is_mini_boss() or kind=="darksteel_guard"

func center() -> Vector2:
	return position+Vector2(0,-radius - (24.0 if is_flying() else 0.0))

func block_weight() -> int:
	return maxi(int(data.capacity),2 if elite else 1)

func _update_draw_dirty() -> void:
	var sig: int=int(health)+(int(barrier_shield)<<12)+(1<<22 if marked>0.0 else 0)+(1<<23 if fracture>0.0 else 0)+(1<<24 if windup>0.0 else 0)+(1<<25 if stun>0.0 else 0)
	if game.condition_lab and is_instance_valid(game.hero) and game.hero.conditions!=null:
		var ranks: Dictionary=game.passive_ranks
		var threshold: float=game.hero.conditions.enemy_hp_threshold()
		sig=hash([sig,ranks.get("hunter",0),ranks.get("opener",0),threshold,ranks.get("breaker",0),health>=max_health*0.99,health<=max_health*threshold])
	sig = sig | ((1 if slow>0 else 0)<<26) | ((1 if burn_clock>0 else 0)<<27) | ((1 if ability_windup>0.0 else 0)<<28) | ((1 if enraged else 0)<<29) | ((1 if roar_buff_clock>0.0 else 0)<<30)
	if windup>0.0 or ability_windup>0.0 or charge_left>0.0 or sig!=_last_draw_sig:
		_last_draw_sig=sig
		queue_redraw()
func speed_scale() -> float:
	var altar_slow: float=game.altar_slow_at(center()) if game!=null and not game.altars.is_empty() else 0.0
	var boss_boost: float=1.2 if (kind in ["colossus","two_headed_troll"] and boss_phase>=2) else 1.0
	var woodsman_boost: float=1.40 if (kind=="bear_woodsman" and enraged) else 1.0
	var roar_boost: float=1.25 if roar_buff_clock>0.0 else 1.0
	return boss_boost*woodsman_boost*roar_boost*(1.0-altar_slow)

func chase_active() -> bool:
	return chase_left>0.0 or returning

func can_chase() -> bool:
	if elite or is_guard or is_flying() or is_unstoppable() or chase_recovery>0 or returning or stun>0 or windup>0 or melee_windup>0 or ability_windup>0 or charge_left>0:
		return false
	if kind not in ["fox","brute","construct_hound","fiddler","mudshrimp","pigsoldier","rottooth_hyena","tusk_fighter"]:
		return false
	var hero_position: Vector2=game.hero.position
	if not game.walkable(position.lerp(hero_position,0.5)):
		return false
	return game.bridge_gate_config.is_empty() or position.distance_to(game.bridge_gate_point())>125.0

func try_shadow_step(soldier: Node2D) -> bool:
	if kind!="throat_cutter" or dash_used or stun>0.0 or not (soldier is ArenaSoldier) or game==null:
		return false
	dash_used=true
	var road: Curve2D = game.enemy_road(self)
	if road==null:return false
	game.effect(center(),32.0,Color("7b6ea8"),"dodge_step",0.26,facing)
	progress=minf(maxf(0.0,road.get_baked_length()-14.0),progress+68.0)
	var next: Vector2 = road.sample_baked(progress,true)
	if next.distance_squared_to(position)>1.0:
		facing=(next-position).normalized()
	position=next
	visual.show_pose("walk",facing)
	queue_redraw()
	return true

func _step_to(point: Vector2,delta: float,use_obstacles:=true) -> bool:
	var speed:=float(data.speed)*speed_scale()*movement_factor()
	var next:=position.move_toward(point,speed*delta)
	if use_obstacles and not game.walkable(next):
		return false
	if next.distance_squared_to(position)>0.01:
		facing=position.direction_to(next)
		position=next
		visual.show_pose("walk",facing)
		visual.match_stride(speed)
	return true

func _chase(delta: float) -> void:
	var anchor: Vector2=game.enemy_road(self).sample_baked(progress,true)
	if chase_left>0:
		chase_left=maxf(0,chase_left-delta)
		var point: Vector2=game.hero.position
		if game.hero.knocked_out or point.distance_to(anchor)>85.0 or chase_left<=0:
			chase_left=0.0
			returning=true
		elif melee_windup<=0:
			if position.distance_to(point)<=44.0:
				melee(game.hero)
			elif not _step_to(point,delta):
				chase_left=0.0
				returning=true
	if returning and melee_windup<=0:
		# This is the same traversed segment returning to the saved road progress.
		_step_to(anchor,delta,false)
		if position.distance_squared_to(anchor)<1.0:
			position=anchor
			returning=false
			chase_recovery=3.2

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
	chase_recovery=maxf(0.0,chase_recovery-delta)
	ability_clock=maxf(0.0,ability_clock-delta)
	roar_anim_left=maxf(0.0,roar_anim_left-delta)
	roar_buff_clock=maxf(0.0,roar_buff_clock-delta)
	boulder_clock=maxf(0.0,boulder_clock-delta)
	if kind in ["colossus","two_headed_troll"]:slam_clock=maxf(0,slam_clock-delta)
	if stun>0 or tower_control_clock>0.0:
		windup=0;melee_windup=0;melee_target=null;ability_windup=0.0;ability_kind="";charge_left=0.0
		visual.pause();queue_redraw();return

	if kind=="two_headed_troll" and boss_phase>=2:
		_troll_regen_tick+=delta
		if _troll_regen_tick>=0.5:
			_troll_regen_tick-=0.5
			health=minf(max_health,health+7.0)

	if melee_windup>0:
		melee_windup=maxf(0,melee_windup-delta)
		if melee_windup<=0:
			_resolve_melee()

	if windup>0:
		windup=maxf(0,windup-delta)
		if kind=="dreadeye_viper" and windup>0.14 and not game.hero.knocked_out:
			aim=game.hero.center()
			aim_locked=false
		elif kind=="dreadeye_viper":
			aim_locked=true
		if windup<=0:
			aim_locked=false
			release_ranged()

	if ability_windup>0.0:
		ability_windup=maxf(0.0,ability_windup-delta)
		if ability_windup<=0.0:
			_finish_ability()

	if charge_left>0.0:
		charge_left=maxf(0.0,charge_left-delta)
		var c_spd := 290.0 if is_mini_boss() else 260.0
		var road:=advance_road(c_spd*delta)
		if road==null: return
		var next := road.sample_baked(progress,true)
		if next.distance_squared_to(position)>0.2:
			facing=(next-position).normalized()
		position=next
		visual.show_pose("skill",facing)
		if charge_left<=0.0:
			_rhino_charge_impact()

	var movement_paused: bool = windup>0.0 or melee_windup>0.0 or salt_slam_left>0.0 or ability_windup>0.0 or charge_left>0.0 or roar_anim_left>0.0
	if is_guard:
		var target: Vector2=home
		if not game.hero.knocked_out and game.hero.position.distance_to(home)<165:target=game.hero.position
		var move: Vector2=target-position
		if move.length()>27 and not movement_paused:position+=move.normalized()*float(data.speed)*speed_scale()*movement_factor()*delta;facing=move.normalized();visual.show_pose("walk",facing);visual.match_stride(float(data.speed)*speed_scale()*movement_factor())
		if position.distance_to(game.hero.position)<38 and not game.hero.knocked_out:melee(game.hero)
	elif is_instance_valid(blocker) and blocker.can_block():
		if not movement_paused:
			if position.distance_to(blocker.position)>43.0:
				_step_to(blocker.position,delta)
			else:
				melee(blocker)
	elif chase_active():
		_chase(delta)
	else:
		blocker=null
		if not movement_paused:
			var distance: float=float(data.speed)*speed_scale()*movement_factor()*delta
			if kind=="mudshrimp":distance*=_shrimp_speed(delta)
			var road:=advance_road(distance)
			if road==null: return
			var next: Vector2=road.sample_baked(progress,true)
			movement_speed=distance/maxf(0.001,delta)
			facing=(next-position).normalized();position=next;visual.show_pose("walk",facing);visual.match_stride(distance/maxf(0.001,delta))

	_tick_special_behaviors(delta)
	visual.modulate=Color.WHITE if visual.feedback.material!=null and game.feel.enabled else ((Color(1.05,1.0,0.95) if bool(game.campaign.data.reduced_motion) else Color(1.8,1.5,1.3)) if hurt_time>0 else Color.WHITE)
	_update_draw_dirty()

func advance_road(distance: float) -> Curve2D:
	var previous:=progress
	progress+=distance
	var road: Curve2D=game.enemy_road(self)
	if not game.selected_defense_cards.is_empty():
		game.orders.advance(self,previous,road)
	if progress<road.get_baked_length(): return road
	var extra: int=game.orders.leaked(self)
	game.core_hit(game.core_max if is_boss() else ArenaDefinitions.leak_damage(kind,elite)+extra)
	game.remove_enemy(self)
	return null

func _tick_special_behaviors(delta: float) -> void:
	var busy := windup>0.0 or ability_windup>0.0 or charge_left>0.0 or roar_anim_left>0.0 or melee_windup>0.0
	if not game.hero.knocked_out and not busy and ranged_clock<=0.0:
		if kind=="dreadeye_viper" and position.distance_to(game.hero.position)<=385.0:
			aim=game.hero.center();aim_locked=false;windup=0.72;ranged_clock=3.1
			visual.show_pose("attack",(aim-position).normalized());visual.frame=0;return
		elif kind=="scout_vulture" and position.distance_to(game.hero.position)<=245.0:
			aim=game.hero.center()+game.hero.velocity*0.08;windup=0.38;ranged_clock=2.6
			visual.show_pose("attack",(aim-position).normalized());visual.frame=0;return
		elif kind in ["wisp","spearman","spore","moth","astral_prism","rift_bomber","colossus"] and position.distance_to(game.hero.position)<(640 if is_boss() else 350):
			aim=game.hero.center()+game.hero.velocity*0.12;windup=0.7 if kind=="spearman" else (0.75 if kind=="colossus" else 0.55);ranged_clock=3.2 if is_boss() else 3.0
			visual.show_pose("attack",(aim-position).normalized());visual.frame=0;return

	if kind=="skunk_bombardier" and not busy and ranged_clock<=0.0:
		var bomb_target := _pick_skunk_target()
		if bomb_target != Vector2.INF:
			aim=bomb_target;windup=0.55;ranged_clock=4.6
			visual.show_pose("attack",(aim-position).normalized());visual.frame=0;return

	if kind=="turtle_shaman" and not busy and ability_clock<=0.0:
		if _has_injured_ally(150.0):
			ability_kind="heal";ability_windup=0.60;ability_clock=4.5
			visual.show_pose("attack",facing);visual.play("attack");visual.frame=0;return

	if kind=="bear_vanguard" and not busy and ability_clock<=0.0:
		var has_target: bool = is_instance_valid(blocker) or (not game.hero.knocked_out and position.distance_to(game.hero.position)<=120.0)
		if has_target:
			ability_kind="bear_slam";ability_windup=0.75;ability_clock=3.5 if elite else 4.2
			var slam_pt := position + facing * 26.0
			var rad := 96.0 if elite else 88.0
			game.delayed_attack(slam_pt,rad,float(data.damage)*damage_scale()*(1.35 if elite else 1.25),0,"enemy",0.75,{"telegraph":"bear_slam","hits_soldiers":true,"debuff":{"kind":"slow","duration":1.8,"strength":0.35},"fx_kind":"slam","fx_color":Color("e8a864")})
			visual.show_pose("attack",facing);visual.play("attack");visual.frame=0;return

	if kind in ["darksteel_guard","darksteel_boss"] and not busy and ability_clock<=0.0:
		var hero_close: bool = not game.hero.knocked_out and position.distance_to(game.hero.position)<=250.0
		var soldier_close := false
		for s in game.soldiers:
			if is_instance_valid(s) and not s.dead and position.distance_to(s.position)<=175.0:
				soldier_close=true;break
		if hero_close or soldier_close:
			ability_kind="rhino_charge";ability_windup=0.90;ability_clock=4.6 if is_mini_boss() else 5.4
			var road: Curve2D=game.enemy_road(self)
			ability_target=road.sample_baked(minf(road.get_baked_length()-12.0,progress+125.0),true)
			facing=(ability_target-position).normalized() if ability_target.distance_to(position)>4.0 else facing
			visual.show_pose("skill",facing);visual.frame=0;return

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
	elif kind=="two_headed_troll":
		_check_troll_phase()
		if not busy:
			var hero_near: bool = not game.hero.knocked_out and position.distance_to(game.hero.position)<=260.0
			var soldier_near := false
			for s in game.soldiers:
				if is_instance_valid(s) and not s.dead and position.distance_to(s.position)<=140.0:
					soldier_near=true;break
			if slam_clock<=0.0 and (hero_near or soldier_near):
				slam_clock=3.4 if boss_phase>=2 else 4.2
				ability_kind="troll_slam";ability_windup=0.45
				visual.show_pose("attack",facing);visual.play("attack");visual.frame=0
				var anchor_pt: Vector2 = game.hero.position if hero_near else position + facing * 55.0
				if boss_phase>=2:
					for k in range(3):
						var off := Vector2.RIGHT.rotated(k*TAU/3.0+0.35)*88.0
						var pt := (anchor_pt+off).clamp(Vector2(60,110),game.world_size()-Vector2(60,40))
						game.delayed_attack(pt,92.0,float(data.damage)*damage_scale()*1.15,0,"enemy",0.90,{"telegraph":"boss_slam","hits_soldiers":true,"debuff":{"kind":"slow","duration":2.0,"strength":0.30},"fx_kind":"slam","fx_color":Color("f25848")})
				else:
					game.delayed_attack(anchor_pt,115.0,float(data.damage)*damage_scale()*1.40,0,"enemy",0.85,{"telegraph":"boss_slam","hits_soldiers":true,"debuff":{"kind":"slow","duration":2.0,"strength":0.30},"fx_kind":"slam","fx_color":Color("f25848")})
				return
			if boulder_clock<=0.0 and not game.hero.knocked_out and position.distance_to(game.hero.position)<=560.0:
				boulder_clock=5.0
				aim=game.hero.center()+game.hero.velocity*0.12
				windup=0.52
				visual.show_pose("attack",(aim-position).normalized());visual.play("attack");visual.frame=0
				return
	if kind=="anchor_crab":_anchor_slam(delta)

func _pick_skunk_target() -> Vector2:
	if not game.hero.knocked_out and position.distance_to(game.hero.position)<=230.0:
		return game.hero.position + game.hero.velocity * 0.20
	var best_tower: ArenaTower = null
	var best_d2 := 320.0 * 320.0
	for tower in game.towers:
		if not is_instance_valid(tower) or tower.destroyed or tower.jam_clock > 0.4:
			continue
		var d2 := position.distance_squared_to(tower.position)
		if tower.kind != "barracks" and d2 < best_d2:
			best_d2 = d2; best_tower = tower
	if best_tower != null:
		return best_tower.position
	if not game.hero.knocked_out and position.distance_to(game.hero.position)<=340.0:
		return game.hero.position
	return Vector2.INF

func _has_injured_ally(rad: float) -> bool:
	var r2 := rad * rad
	for other in game.enemies:
		if not is_instance_valid(other) or other.dead or other.is_guard:
			continue
		if position.distance_squared_to(other.position) <= r2 and (other.health < other.max_health * 0.96 or other.slow > 0.0):
			return true
	return false

func _finish_ability() -> void:
	var kind_done := ability_kind
	ability_kind=""
	if kind_done=="heal":
		var healed_any := false
		for other in game.enemies:
			if not is_instance_valid(other) or other.dead or other.is_guard:
				continue
			if position.distance_to(other.position) <= 155.0:
				var mult := 0.08 if (other.is_boss() or other.is_mini_boss()) else 0.16
				var before: float = other.health
				other.health = minf(other.max_health, other.health + other.max_health * mult)
				other.slow = 0.0
				var diff: float = other.health - before
				if diff >= 1.0:
					healed_any = true
					game.numbers.append({"point":other.center()+Vector2(0,-14),"text":"+"+str(int(round(diff))),"colour":Color("74f290"),"life":0.55,"duration":0.55})
		game.effect(position,150.0,Color("56e888"),"upgrade",0.55)
		if healed_any:game.audio.play("mage_cast",-14)
	elif kind_done=="rhino_charge":
		charge_left=0.48 if is_mini_boss() else 0.42
		visual.show_pose("skill",facing);visual.play("skill");visual.frame=2
		game.audio.play("heavy_hit",-14)

func _rhino_charge_impact() -> void:
	var impact_pt := position + facing * 24.0
	var rad := 98.0 if is_mini_boss() else 84.0
	game.delayed_attack(impact_pt,rad,float(data.damage)*damage_scale()*(1.55 if is_mini_boss() else 1.35),0,"enemy",0.04,{"telegraph":"bear_slam","hits_soldiers":true,"debuff":{"kind":"stun","duration":0.70},"fx_kind":"slam","fx_color":Color("f48454")})
	ArenaBattleArt.emit_world_dust(impact_pt,Vector2(-facing.x*25.0,-16.0),28.0,Color("c8bda2"))
	if game.feel.enabled:
		game.feel.trauma = minf(1.0, game.feel.trauma + (0.32 if is_mini_boss() else 0.18))

func _shrimp_speed(delta: float) -> float:
	salt_move_clock=fposmod(salt_move_clock+delta,2.10)
	if salt_move_clock>=1.65:return 1.95
	if salt_move_clock>=1.18:return 0.38
	return 0.86

func _anchor_slam(delta: float) -> void:
	salt_slam_left=maxf(0,salt_slam_left-delta)
	slam_clock=maxf(0,slam_clock-delta)
	if slam_clock>0 or game.hero.knocked_out or position.distance_to(game.hero.position)>190:
		return
	slam_clock=4.4 if health>max_health*0.40 else 3.2
	salt_slam_left=0.9
	var target := position.move_toward(game.hero.position,88)
	game.delayed_attack(target,84.0,float(data.damage)*damage_scale()*1.45,0,"enemy",salt_slam_left,{"telegraph":"anchor_slam"})
	game.audio.play("heavy_hit",-22)

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

func _check_troll_phase() -> void:
	if kind!="two_headed_troll" or dead:return
	var tphase:=2 if health<max_health*0.33 else (1 if health<max_health*0.66 else 0)
	while boss_phase<tphase:
		boss_phase+=1
		roar_anim_left=0.90
		visual.show_pose("skill",facing);visual.play("skill");visual.frame=0
		game.audio.play("heavy_hit",-6)
		if game.feel.enabled:
			game.feel.trauma = minf(1.0, game.feel.trauma + 0.36)
		if boss_phase==1:
			for index in range(4):
				game.spawn_enemy("pigsoldier",route_id,maxf(0.0,progress-45.0-index*22.0))
			for index in range(3):
				game.spawn_enemy("rottooth_hyena",route_id,maxf(0.0,progress-65.0-index*26.0))
			for ally in game.enemies:
				if is_instance_valid(ally) and not ally.dead and not ally.is_guard and ally.position.distance_to(position)<=260.0:
					ally.roar_buff_clock=8.0
			game.effect(center(),155.0,Color("ff8448"),"blast",0.75)
		elif boss_phase==2:
			for index in range(3):
				game.spawn_enemy("rottooth_hyena",route_id,maxf(0.0,progress-45.0-index*25.0))
			slam_clock=0.45
			game.effect(center(),175.0,Color("f24c48"),"blast",0.85)

func melee(target: Node2D) -> void:
	if melee_clock>0 or not is_instance_valid(target):return
	melee_clock=0.78 if (kind=="bear_woodsman" and enraged) else 1.15
	visual.show_pose("attack",(target.position-position).normalized());visual.play("attack");visual.frame=0
	melee_target=target;melee_windup=0.26 if (kind=="bear_woodsman" and enraged) else 0.3

func _resolve_melee() -> void:
	var damage:=float(data.damage)*damage_scale()*(1.25 if elite else 1.0)
	if kind=="bear_woodsman" and enraged:
		var hit_any := false
		if not game.hero.knocked_out and position.distance_to(game.hero.position)<=70.0:
			game.hero.take_hit(damage,int(data.type),true,position.direction_to(game.hero.position))
			hit_any=true
		for s in game.soldiers:
			if is_instance_valid(s) and not s.dead and position.distance_to(s.position)<=70.0:
				s.take_hit(damage,int(data.type),true)
				hit_any=true
		if hit_any:
			game.effect(position+facing*24.0+Vector2(0,-20.0),52.0,Color("f69a5c"),"slash",0.20,facing)
		return
	if is_instance_valid(melee_target) and position.distance_to(melee_target.position)<58 and (melee_target==game.hero or melee_target.can_block()):
		if melee_target==game.hero:
			var had_prot: bool = game.hero.protection > 0.0
			game.hero.take_hit(damage,int(data.type),true,position.direction_to(game.hero.position))
			if not had_prot:
				if kind=="rottooth_hyena":
					game.hero.apply_debuff("bleed",2.0,5.0)
				elif kind=="throat_cutter":
					game.hero.apply_debuff("bleed",3.0,8.0)
		else:
			melee_target.take_hit(damage,int(data.type),true)

func release_ranged() -> void:
	if game.hero.knocked_out and kind!="skunk_bombardier":return
	match kind:
		"spore":
			game.delayed_attack(aim,67,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),1,"enemy",0.9,{"origin":center()})
		"skunk_bombardier":
			game.delayed_attack(aim,84.0,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),1,"enemy",0.85,{
				"origin":center(),"telegraph":"toxic_bomb",
				"debuff":[{"kind":"slow","duration":2.0,"strength":0.30},{"kind":"poison","duration":3.0,"strength":7.0}],
				"spawn_zone":{"kind":"toxic_cloud","radius":92.0,"duration":4.8,"dps":7.0},
				"fx_color":Color("5ce86e")
			})
		"dreadeye_viper":
			var dir := (aim - center()).normalized()
			if dir.is_zero_approx():dir = facing
			game.fire_projectile(center(),center()+dir*700.0,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),int(data.type),"enemy",{
				"speed":680.0,"appearance":"viper_arrow",
				"debuffs":[{"kind":"poison","duration":3.5,"strength":6.0},{"kind":"slow","duration":2.5,"strength":0.28}]
			})
		"scout_vulture":
			var dir_v := (aim - center()).normalized()
			if dir_v.is_zero_approx():dir_v = facing
			game.fire_projectile(center(),center()+dir_v*420.0,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),0,"enemy",{
				"speed":380.0,"appearance":"feather_dart"
			})
		"two_headed_troll":
			var dir_t := (aim - center()).normalized()
			if dir_t.is_zero_approx():dir_t = facing
			game.fire_projectile(center(),center()+dir_t*640.0,float(data.damage)*damage_scale()*1.1,0,"enemy",{
				"speed":330.0,"appearance":"boulder",
				"debuffs":[{"kind":"slow","duration":2.2,"strength":0.35}]
			})
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

func take_hit(amount: float,damage_type: int,source: String,stagger := 0.0,chill_time := 0.0,pen_bonus := 0.0,attack: String="attack", incoming := Vector2.ZERO, contact := Vector2.INF, condition_hit: Dictionary={}) -> float:
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
	var vulnerability: float=([0.10,0.11,0.12][game.hero.passive_rank] if game.hero.class_id=="healer" else 0.10) if exposure>0 else 0.0
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
	if source=="hero" and (elite or is_boss() or is_mini_boss()) and game.has_keystone("execute_prism"):damage*=1.32
	if source in ["tower","soldier"] and game.has_keystone("fracture"):fracture=4.0
	var trigger_frac: bool=(source=="hero" and attack!="fracture_proc" and fracture>0.0 and game.has_keystone("fracture"))
	if trigger_frac:fracture=0.0
	if source!="enemy" and not is_boss() and not is_mini_boss() and game.has_keystone("execute_prism") and health-maxf(0.0,damage-barrier_shield)<=max_health*0.22:
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
	_check_troll_phase()
	if kind=="bear_woodsman" and not enraged and health>0.0 and health<max_health*0.65:
		enraged=true
		game.effect(center(),62.0,Color("ff7048"),"blast",0.42)
		game.audio.play("heavy_hit",-12)
	if not is_boss():
		var stun_mult := 0.35 if is_mini_boss() else 1.0
		var eff_stagger := stagger * stun_mult
		if eff_stagger>0.0:
			stun=maxf(stun,eff_stagger)
		slow=maxf(slow,chill_time)
		if eff_stagger>0.0 and charge_left<=0.0:
			melee_windup=0.0
			melee_target=null
			windup=0.0
			ability_windup=0.0
			ability_kind=""
	game.damage_stats[source]=float(game.damage_stats.get(source,0))+total_dealt
	if source in ["hero","tower","soldier"] and attack!="resonance" and total_dealt>0:game.add_resonance_on_hit(total_dealt)
	var impact_point := center() if contact == Vector2.INF else contact
	game.feedback(impact_point,total_dealt,damage_type,health<=0,source,self,attack,incoming,absorbed > 0 and hp_damage <= 0,condition_result)
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
		frost_stacks=0
		if not is_boss():
			stun=maxf(stun,freeze * (0.35 if is_mini_boss() else 1.0))
		game.effect(center(),24,Color("bfe6ff"),"hit",0.32)
func push_back(amount: float) -> void:
	if is_unstoppable() or is_guard or is_flying():return
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
	if visual.salt_rig==null:
		draw_set_transform(Vector2.ZERO,0,Vector2(1,0.4))
		draw_circle(Vector2.ZERO,radius*(0.65 if is_flying() else 0.8),Color(0.07,0.13,0.1,0.32 if is_flying() else 0.25))
		draw_set_transform(Vector2.ZERO)
	if enraged:
		draw_set_transform(Vector2.ZERO,0,Vector2(1,0.45))
		draw_arc(Vector2.ZERO,radius+6.0,0,TAU,24,Color("ff5a3c",0.82),2.4,true)
		draw_circle(Vector2.ZERO,radius+4.0,Color("ff4428",0.14))
		draw_set_transform(Vector2.ZERO)
	if roar_buff_clock>0.0:
		draw_set_transform(Vector2.ZERO,0,Vector2(1,0.45))
		draw_arc(Vector2.ZERO,radius+4.0,0,TAU,20,Color("ffa848",0.70),1.8,true)
		draw_set_transform(Vector2.ZERO)
	if slow>0 or stun>0:
		var tint := Color("a6eaff") if slow>0 else Color("f3c36e")
		for side in [-1,1]:
			var foot := Vector2(side*radius*0.66,-1)
			draw_polyline(PackedVector2Array([foot+Vector2(-4,2),foot+Vector2(0,-5),foot+Vector2(4,2)]),tint,1.8,true)
	if burn_clock>0:
		for i in range(3):
			var ember := Vector2((i-1)*5,-4-i*2)
			draw_line(ember,ember+Vector2(2,-4),Color("f1a157"),2,true)
	var hp_y := -visual.base_height - (28.0 if is_flying() else 5.0)
	if tower_weakness_clock>0.0 or tower_frost_layers>0 or tower_control_clock>0.0: draw_tower_status()
	var full_cue: bool=game.condition_lab and (game.passive_rank("hunter")>0 or game.passive_rank("opener")>0) and health>=max_health*0.99
	var threshold: float=game.hero.conditions.enemy_hp_threshold() if game.condition_lab and is_instance_valid(game.hero) else 0.0
	var high_defence_cue: bool=game.condition_lab and is_instance_valid(game.hero) and game.passive_rank("breaker")>0 and ArenaConditions.high_defence(self,int(game.hero.data.type))
	if health<max_health or full_cue or high_defence_cue or threshold>0.0:
		draw_rect(Rect2(-18,hp_y,36,3),Color("25372b"));draw_rect(Rect2(-18,hp_y,36*health/max_health,3),Color("ce8274"))
		if full_cue: draw_rect(Rect2(-19,-visual.base_height-6,38,5),Color("fff4df"),false,1.0)
		if threshold>0.0:
			var mark_x: float=-18.0+36.0*threshold
			draw_line(Vector2(mark_x,-visual.base_height-7),Vector2(mark_x,-visual.base_height),Color("ffe0a0") if health<=max_health*threshold else Color("97917e"),1.0)
		if high_defence_cue:
			var shield:=ArenaMenuArt.utility("shield")
			if shield!=null: draw_texture_rect(shield,Rect2(-31,hp_y-4,10,10),false)
	if barrier_shield>0.0:
		draw_rect(Rect2(-22,hp_y-5,44*minf(1.0,barrier_shield/520.0),3),Color("7ce8ff"))
	if kind=="astral_prism":
		draw_set_transform(Vector2(0,-4),0.0,Vector2(1.0,0.58))
		draw_arc(Vector2.ZERO,135.0,0,TAU,36,Color(0.56,0.78,1.0,0.13),1.5,true)
		draw_set_transform(Vector2.ZERO)
	if elite or (game.condition_lab and is_boss()):draw_arc(Vector2(0,hp_y+5),7,PI,TAU,12,Color("f6cc79"),2)
	if marked>0:draw_arc(Vector2(0,-visual.base_height*0.45),radius+7,0,TAU,28,Color(0.86,0.95,0.72,0.45),2,true)
	if fracture>0.0:
		var fc:=Vector2(0,hp_y-8)
		draw_colored_polygon(PackedVector2Array([fc+Vector2(0,-6),fc+Vector2(5,0),fc+Vector2(0,6),fc+Vector2(-5,0)]),Color("f6c26b"))
	if windup>0 and kind=="dreadeye_viper":
		var charge: float=1.0-clampf(windup/0.72,0.0,1.0)
		var origin_off := Vector2(facing.x*18.0,-32.0)
		var target_off := aim - position
		var laser_col := Color(1.0,0.94,0.84,0.95) if aim_locked else Color(1.0,0.28,0.28,0.55+0.35*charge)
		draw_line(origin_off, target_off, laser_col, 2.8 if aim_locked else 1.8, true)
		draw_set_transform(target_off, 0.0, Vector2(1.0, 0.65))
		draw_arc(Vector2.ZERO, maxf(6.0, 20.0*(1.0-charge*0.65)), 0, TAU, 20, laser_col, 2.0, true)
		draw_set_transform(Vector2.ZERO)
		draw_circle(origin_off, 4.0 if aim_locked else 3.0, Color("a4ff8a"))
	if ability_windup>0.0 and ability_kind=="heal":
		var h_p := 1.0 - clampf(ability_windup/0.60,0.0,1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.58))
		draw_arc(Vector2.ZERO, 150.0 * h_p, 0, TAU, 36, Color(0.45,0.96,0.56,0.72), 2.4, true)
		draw_arc(Vector2.ZERO, 30.0, 0, TAU, 20, Color("98ffaa",0.85), 2.0, true)
		draw_set_transform(Vector2.ZERO)
	if ability_windup>0.0 and ability_kind=="rhino_charge":
		var c_p := 1.0 - clampf(ability_windup/0.90,0.0,1.0)
		var end_off := ability_target - position
		var perp := end_off.normalized().orthogonal() * 24.0 if end_off.length()>1.0 else Vector2(0,24.0)
		var lane := PackedVector2Array([-perp, end_off - perp, end_off + perp, perp])
		draw_colored_polygon(lane, Color(0.96, 0.24, 0.22, 0.14 + 0.14 * c_p))
		draw_polyline(PackedVector2Array([-perp, end_off - perp, end_off + perp, perp, -perp]), Color(1.0, 0.44, 0.34, 0.78), 2.2, true)
		draw_line(Vector2.ZERO, end_off * c_p, Color(1.0, 0.85, 0.45, 0.85), 3.0, true)
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
