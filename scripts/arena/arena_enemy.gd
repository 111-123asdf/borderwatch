class_name ArenaEnemy
extends Node2D
var game: Node2D
var domain: String="defense"
var is_rift_mob:=false
var is_bounty_elite:=false
var rift_room_id: String=""
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
var is_swarm_fodder:=false
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
var melee_windup_total:=0.30
var melee_dir:=Vector2.RIGHT
var melee_reach:=58.0
var melee_arc_cos:=0.42
var melee_recovery:=0.0
var _melee_perfect_claimed:=false
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
var submerged:=false
var lighthouse_exposed:=0.0
var storm_haste_clock:=0.0
var leap_clock:=0.0
var leap_duration:=0.48
var leap_from:=Vector2.ZERO
var leap_to:=Vector2.ZERO
var seal_cast_clock:=8.5
var summon_clock:=5.5
var rift_warp_done:=false
var _miniboss_split_done:=false
var visual: ArenaCreature
var radius:=19.0

func is_submerged() -> bool:
	return submerged

func start_ambush_leap(from_pt: Vector2, to_pt: Vector2, dur := 0.48) -> void:
	leap_from = from_pt
	leap_to = to_pt
	leap_duration = maxf(0.1, dur)
	leap_clock = leap_duration
	position = from_pt
	facing = (to_pt - from_pt).normalized() if to_pt.distance_to(from_pt) > 2.0 else Vector2.RIGHT

func _ready() -> void:
	data=ArenaDefinitions.enemy(kind)
	var scale_hp: float=1.0
	if is_rift_mob:
		var f_idx: int = int(game.rift_domain.floor_index) if (game != null and game.rift_domain != null) else 1
		var base_r_mult := 1.35 if is_boss() else (1.15 if is_mini_boss() else (1.85 if is_bounty_elite else 0.52))
		scale_hp = base_r_mult * (1.0 + 0.14 * maxi(0, f_idx - 1) + 0.08 * maxi(0, game.cycle - 1))
	elif not is_guard:
		var fodder_mult := 0.72 if is_swarm_fodder else 1.0
		scale_hp = (1.0 + 0.26 * maxi(0, game.cycle - 1)) * fodder_mult
	max_health=float(data.health)*scale_hp*(1.55 if (elite and not is_bounty_elite and not is_mini_boss()) else 1.0);health=max_health
	visual=ArenaCreature.new();add_child(visual)
	var look: String="brute" if kind=="captain" else ("twilight_golem" if kind=="breacher" else str(data.get("visual_kind",kind)))
	var heights := {
		"fox":43.0,"brute":67.0,"wisp":49.0,"spearman":58.0,"spore":51.0,"moth":115.0,"captain":82.0,"breacher":88.0,
		"murloc_hunter":48.0,"tide_rider":64.0,"water_sprite":54.0,"storm_wyrm":62.0,"tide_warrior":62.0,"wind_captain":64.0,
		"conch_mage":60.0,"water_elder":64.0,"tempest_elemental":84.0,"bluegale":76.0,"bloodshell_crab":92.0,"bloodshell_boss":116.0,"leviathan":140.0,
		"void_eyeling":44.0,"void_gazer":56.0,"twilight_harasser":58.0,"spectral_cutter":58.0,"twilight_avenger":62.0,"avenger_rider":76.0,
		"venom_spitter":60.0,"soul_reaver":72.0,"twilight_golem":88.0,"vile_eyenest":80.0,"bloodsoil_behemoth":96.0,"bloodsoil_boss":118.0,"baj_nimen":136.0,
		"pigsoldier":58.0,"rottooth_hyena":54.0,"throat_cutter":56.0,"scout_vulture":60.0,"skunk_bombardier":58.0,
		"turtle_shaman":60.0,"dreadeye_viper":64.0,"tusk_fighter":66.0,"bear_woodsman":78.0,"bear_vanguard":84.0,
		"darksteel_guard":92.0,"darksteel_boss":114.0,"two_headed_troll":136.0
	}
	visual.configure(look, float(heights.get(kind, 50.0)))
	if kind in ["moth","two_headed_troll","leviathan","baj_nimen"]:radius=42
	elif kind in ["darksteel_boss","bloodshell_boss","bloodsoil_boss"]:radius=34
	elif kind in ["captain","darksteel_guard","bear_vanguard","bloodshell_crab","tempest_elemental","bloodsoil_behemoth","twilight_golem","vile_eyenest","soul_reaver","avenger_rider","bluegale"]:radius=26
	elif kind in ["bear_woodsman","tide_warrior","wind_captain","water_elder","conch_mage","tide_rider","twilight_avenger"]:radius=22
	if kind in ["darksteel_guard","darksteel_boss","tempest_elemental","bloodshell_crab","bloodshell_boss","twilight_golem","bloodsoil_behemoth","bloodsoil_boss"]:
		ability_clock=3.0
	elif kind in ["turtle_shaman","water_elder","conch_mage","soul_reaver"]:
		ability_clock=2.4
	elif kind in ["bear_vanguard","bluegale"]:
		ability_clock=2.2
	elif kind=="leviathan":
		seal_cast_clock=7.0
		slam_clock=3.2
	elif kind=="baj_nimen":
		slam_clock=3.0
	elif kind=="vile_eyenest":
		summon_clock=5.0
	var information:=Control.new();information.position=Vector2(-25,-visual.base_height);information.size=Vector2(50,visual.base_height);information.mouse_filter=Control.MOUSE_FILTER_PASS
	var trait_str := str(data.get("trait",""))
	information.tooltip_text=data.name+" · "+ArenaCombat.label(data.type)+"\n物理抗性 "+str(int(float(data.armour)*100))+"% · 法术抗性 "+str(int(float(data.resistance)*100))+"%"+("\n"+trait_str if trait_str!="" else "")
	add_child(information)

func is_boss() -> bool:
	return kind in ["moth","two_headed_troll","leviathan","baj_nimen"] or bool(data.get("boss",false))

func is_mini_boss() -> bool:
	return bool(data.get("mini_boss",false))

func is_flying() -> bool:
	return bool(data.get("flying",false))

func is_unstoppable() -> bool:
	return is_boss() or is_mini_boss() or kind in ["darksteel_guard","bloodshell_crab","bloodsoil_behemoth","twilight_golem"]

func center() -> Vector2:
	return position+Vector2(0,-radius - (24.0 if is_flying() else 0.0))

func block_weight() -> int:
	return maxi(int(data.capacity),2 if elite else 1)

func _update_draw_dirty() -> void:
	var sig: int=int(health)+(int(barrier_shield)<<12)+(1<<22 if marked>0.0 else 0)+(1<<24 if windup>0.0 else 0)+(1<<25 if stun>0.0 else 0)
	sig = sig | ((1 if slow>0 else 0)<<26) | ((1 if burn_clock>0 else 0)<<27) | ((1 if ability_windup>0.0 else 0)<<28) | ((1 if enraged else 0)<<29) | ((1 if roar_buff_clock>0.0 or storm_haste_clock>0.0 else 0)<<30) | ((1 if (melee_windup>0.0 and melee_target==game.hero) or submerged or lighthouse_exposed>0.0 else 0)<<31)
	if windup>0.0 or melee_windup>0.0 or melee_recovery>0.0 or ability_windup>0.0 or charge_left>0.0 or leap_clock>0.0 or submerged or lighthouse_exposed>0.0 or storm_haste_clock>0.0 or sig!=_last_draw_sig:
		_last_draw_sig=sig
		queue_redraw()
func speed_scale() -> float:
	var boss_boost: float=1.18 if (kind in ["two_headed_troll","leviathan","baj_nimen"] and boss_phase>=2) else 1.0
	var woodsman_boost: float=1.40 if (kind=="bear_woodsman" and enraged) else 1.0
	var roar_boost: float=1.25 if roar_buff_clock>0.0 else 1.0
	var storm_boost: float=1.28 if (storm_haste_clock>0.0 and lighthouse_exposed<=0.0) else 1.0
	var sub_boost: float=1.20 if (submerged and kind in ["tide_rider","water_sprite","murloc_hunter"]) else 1.0
	var light_slow: float=0.72 if lighthouse_exposed>0.0 else 1.0
	return boss_boost*woodsman_boost*roar_boost*storm_boost*sub_boost*light_slow

func chase_active() -> bool:
	return chase_left>0.0 or returning

func can_chase() -> bool:
	if submerged or leap_clock>0.0 or elite or is_guard or is_flying() or is_unstoppable() or chase_recovery>0 or returning or stun>0 or windup>0 or melee_windup>0 or melee_recovery>0 or ability_windup>0 or charge_left>0:
		return false
	if kind not in ["fox","brute","murloc_hunter","tide_warrior","void_eyeling","twilight_avenger","pigsoldier","rottooth_hyena","tusk_fighter"]:
		return false
	var hero_position: Vector2=game.hero.position
	if not game.walkable(position.lerp(hero_position,0.5)):
		return false
	return game.bridge_gate_config.is_empty() or position.distance_to(game.bridge_gate_point())>125.0

func try_shadow_step(soldier: Node2D) -> bool:
	if kind not in ["throat_cutter","wind_captain","spectral_cutter"] or dash_used or stun>0.0 or not (soldier is ArenaSoldier) or game==null:
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
	if returning and melee_windup<=0 and melee_recovery<=0:
		# This is the same traversed segment returning to the saved road progress.
		_step_to(anchor,delta,false)
		if position.distance_squared_to(anchor)<1.0:
			position=anchor
			returning=false
			chase_recovery=3.2

func _is_juggernaut() -> bool:
	return not is_flying() and not is_boss() and not is_mini_boss() and int(data.get("capacity", 1)) >= 99

func movement_factor() -> float:
	if tower_frost_layers<=0:
		var raw_s := (slow_amount if slow>0.0 else 0.0)
		return 1.0 - (minf(0.28, raw_s) if _is_juggernaut() else raw_s)
	var frost:=float(tower_frost_layers)*ArenaTowerTrial.FROST_STEP
	if is_boss(): frost=minf(0.30,frost*0.5)
	elif _is_juggernaut(): frost=minf(0.28,frost*0.55)
	elif elite: frost*=0.7
	var slow_eff := minf(0.28, slow_amount) if (slow>0.0 and _is_juggernaut()) else (slow_amount if slow>0.0 else 0.0)
	return 1.0-maxf(slow_eff,frost)

func travel_velocity() -> Vector2:
	if is_guard or is_instance_valid(blocker) or windup>0.0 or melee_windup>0.0 or melee_recovery>0.0 or stun>0.0 or tower_control_clock>0.0:
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
	if is_boss() or _is_juggernaut():
		if tower_control_lock<=0.0 and tower_control_clock<=0.0:
			tower_impact_offset=origin.direction_to(position)*distance*0.30
	else:
		push_back(distance*(0.50 if elite else 1.0))
	var repeat_scale:=0.6 if tower_shock_clock>0.0 else 1.0
	if accept_tower_control(duration*repeat_scale): tower_shock_clock=6.0

func accept_tower_control(duration: float) -> bool:
	if is_boss() or _is_juggernaut():
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
	if is_rift_mob and game.active_domain!="rift":
		return
	movement_speed=0.0
	if leap_clock>0.0:
		leap_clock=maxf(0.0,leap_clock-delta)
		var lt := 1.0 - clampf(leap_clock/maxf(0.1,leap_duration),0.0,1.0)
		var ground_p := leap_from.lerp(leap_to,lt)
		var arc_y := sin(lt*PI)*44.0
		position=ground_p
		visual.position=Vector2(0.0,-arc_y)
		visual.show_pose("walk",facing)
		if leap_clock<=0.0:
			position=leap_to
			visual.position=tower_impact_offset
			var splash_col := Color("b068ff") if game.level_id in ["ruins","sanctum"] else Color("66e8f2")
			game.effect(position,36.0,splash_col,"blast",0.35)
			ArenaBattleArt.emit_world_dust(position,Vector2(0,-14.0),24.0,splash_col)
		queue_redraw()
		return
	if game.tower_lab or game.defense_rules or tower_control_clock>0.0 or tower_control_lock>0.0: tick_tower_effects(delta)
	if burn_clock>0:
		var tick: float=burndps_pick(delta)
		health-=tick;game.damage_stats["hero"]=float(game.damage_stats.get("hero",0))+tick
		burn_clock=maxf(0,burn_clock-delta)
		if health<=0:
			dead=true;game.enemy_defeated(self);return
	stun=maxf(0,stun-delta);slow=maxf(0,slow-delta);marked=maxf(0,marked-delta);exposure=maxf(0,exposure-delta);melee_clock=maxf(0,melee_clock-delta);melee_recovery=maxf(0.0,melee_recovery-delta);ranged_clock=maxf(0,ranged_clock-delta);hurt_time=maxf(0,hurt_time-delta)
	chase_recovery=maxf(0.0,chase_recovery-delta)
	ability_clock=maxf(0.0,ability_clock-delta)
	roar_anim_left=maxf(0.0,roar_anim_left-delta)
	roar_buff_clock=maxf(0.0,roar_buff_clock-delta)
	boulder_clock=maxf(0.0,boulder_clock-delta)
	lighthouse_exposed=maxf(0.0,lighthouse_exposed-delta)
	storm_haste_clock=maxf(0.0,storm_haste_clock-delta)
	seal_cast_clock=maxf(0.0,seal_cast_clock-delta)
	summon_clock=maxf(0.0,summon_clock-delta)
	if kind in ["two_headed_troll","leviathan","baj_nimen"]:slam_clock=maxf(0,slam_clock-delta)
	var was_submerged := submerged
	submerged = not is_flying() and not is_guard and game.stage_gimmicks!=null and game.stage_gimmicks.has_method("is_enemy_submerged") and game.stage_gimmicks.is_enemy_submerged(self)
	if submerged and not was_submerged:
		game.blocking.release_enemy(self)
	if stun>0 or tower_control_clock>0.0:
		windup=0;melee_windup=0;melee_recovery=0.0;_melee_perfect_claimed=false;melee_target=null;ability_windup=0.0;ability_kind="";charge_left=0.0
		visual.position=tower_impact_offset
		visual.pause();queue_redraw();return

	if kind=="two_headed_troll" and boss_phase>=2:
		_troll_regen_tick+=delta
		if _troll_regen_tick>=0.5:
			_troll_regen_tick-=0.5
			health=minf(max_health,health+7.0)

	if melee_windup>0:
		melee_windup=maxf(0,melee_windup-delta)
		if melee_windup>0.0 and melee_target==game.hero and visual.sprite_frames!=null and visual.sprite_frames.has_animation("attack"):
			var wp: float = 1.0 - clampf(melee_windup / maxf(0.05, melee_windup_total), 0.0, 1.0)
			var f_max: int = maxi(0, mini(2, visual.sprite_frames.get_frame_count("attack") - 1))
			visual.pause()
			visual.frame = clampi(int(floorf(wp * float(f_max + 1))), 0, f_max)
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

	var movement_paused: bool = windup>0.0 or melee_windup>0.0 or melee_recovery>0.0 or salt_slam_left>0.0 or ability_windup>0.0 or charge_left>0.0 or roar_anim_left>0.0
	if is_rift_mob:
		_tick_rift_pursuit(delta, movement_paused)
		var reduced_r: bool = bool(game.campaign.data.reduced_motion) if (game != null and game.campaign != null and game.campaign.data != null) else false
		visual.position = tower_impact_offset
		visual.modulate = (Color(1.05, 1.0, 0.95) if reduced_r else Color(1.8, 1.5, 1.3)) if hurt_time > 0.0 else Color.WHITE
		_update_draw_dirty()
		return
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
			var road:=advance_road(distance)
			if road==null: return
			var next: Vector2=road.sample_baked(progress,true)
			movement_speed=distance/maxf(0.001,delta)
			facing=(next-position).normalized();position=next;visual.show_pose("walk",facing);visual.match_stride(distance/maxf(0.001,delta))

	_tick_special_behaviors(delta)
	var reduced_fx: bool = bool(game.campaign.data.reduced_motion) if (game != null and game.campaign != null and game.campaign.data != null) else false
	var wind_offset := Vector2.ZERO
	var wind_mod := Color.WHITE
	if melee_windup > 0.0 and melee_target == game.hero:
		var wp: float = 1.0 - clampf(melee_windup / maxf(0.05, melee_windup_total), 0.0, 1.0)
		var urgent_w := melee_windup <= 0.22
		if not reduced_fx:
			wind_offset = -melee_dir * (6.5 * wp) + Vector2(0.0, -2.5 * sin(wp * PI))
		wind_mod = Color(1.42, 1.28, 0.92) if urgent_w else Color(1.24, 0.88, 0.80)
	visual.position = tower_impact_offset + wind_offset
	if hurt_time > 0.0 and (visual.feedback.material == null or not game.feel.enabled):
		visual.modulate = Color(1.05, 1.0, 0.95) if reduced_fx else Color(1.8, 1.5, 1.3)
	else:
		visual.modulate = wind_mod
	_update_draw_dirty()

func _tick_rift_pursuit(delta: float, movement_paused: bool) -> void:
	if not is_instance_valid(game.hero) or game.hero.knocked_out or game.hero.domain != "rift":
		visual.show_pose("idle", facing)
		return
	var target_pt: Vector2 = game.hero.position
	var dist: float = position.distance_to(target_pt)
	if dist <= 40.0:
		melee(game.hero)
		return
	if not movement_paused:
		var sep := Vector2.ZERO
		for other in game.domain_enemies("rift"):
			if other == self or not is_instance_valid(other) or other.dead:
				continue
			var gap: Vector2 = position - other.position
			var d2: float = gap.length_squared()
			if d2 > 0.01 and d2 < 900.0:
				sep += gap.normalized() * (1.0 - sqrt(d2) / 30.0)
		var dir: Vector2 = (target_pt - position).normalized()
		var move_dir: Vector2 = (dir + sep * 0.65).normalized()
		var spd: float = float(data.speed) * (1.05 if not is_bounty_elite else 0.92) * speed_scale() * movement_factor()
		var next: Vector2 = position + move_dir * spd * delta
		if game.rift_domain != null:
			next = game.rift_domain.clamp_mob_to_room(next, rift_room_id)
		if next.distance_squared_to(position) > 0.01:
			facing = position.direction_to(next)
			position = next
			movement_speed = spd
			visual.show_pose("walk", facing)
			visual.match_stride(spd)
	if not game.hero.knocked_out and ranged_clock <= 0.0 and dist <= 290.0 and kind in ["dreadeye_viper", "conch_mage", "water_elder", "twilight_harasser", "venom_spitter", "void_gazer"]:
		aim = game.hero.center() + game.hero.velocity * 0.08
		windup = 0.55
		ranged_clock = 3.6
		visual.show_pose("attack", (aim - position).normalized())
		visual.frame = 0

func advance_road(distance: float) -> Curve2D:
	progress+=distance
	var road: Curve2D=game.enemy_road(self)
	if progress>=road.get_baked_length()-22.0 and game.try_exit_ward_teleport(self,road):
		return road
	if progress<road.get_baked_length(): return road
	var leak_dmg := int(game.core_max) if is_boss() else ArenaDefinitions.leak_damage(kind, elite)
	if not is_boss() and is_swarm_fodder:
		leak_dmg = maxi(6, int(round(float(leak_dmg) * 0.75)))
	game.core_hit(leak_dmg)
	game.remove_enemy(self)
	return null

func _tick_special_behaviors(delta: float) -> void:
	if submerged:
		return
	var busy := windup>0.0 or ability_windup>0.0 or charge_left>0.0 or roar_anim_left>0.0 or melee_windup>0.0 or melee_recovery>0.0
	if not game.hero.knocked_out and not busy and ranged_clock<=0.0:
		if kind=="dreadeye_viper" and position.distance_to(game.hero.position)<=385.0:
			aim=game.hero.center();aim_locked=false;windup=0.72;ranged_clock=3.1
			visual.show_pose("attack",(aim-position).normalized());visual.frame=0;return
		elif kind=="scout_vulture" and position.distance_to(game.hero.position)<=245.0:
			aim=game.hero.center()+game.hero.velocity*0.08;windup=0.38;ranged_clock=2.6
			visual.show_pose("attack",(aim-position).normalized());visual.frame=0;return
		elif kind in ["storm_wyrm","void_gazer","bluegale"] and position.distance_to(game.hero.position)<=320.0:
			aim=game.hero.center()+game.hero.velocity*0.10;windup=0.42;ranged_clock=2.7
			visual.show_pose("attack",(aim-position).normalized());visual.frame=0;return
		elif kind=="tide_warrior" and not is_instance_valid(blocker) and position.distance_to(game.hero.position)<=250.0:
			aim=game.hero.center()+game.hero.velocity*0.08;windup=0.45;ranged_clock=2.8
			visual.show_pose("attack",(aim-position).normalized());visual.frame=0;return
		elif kind in ["conch_mage","water_elder","twilight_harasser","soul_reaver","vile_eyenest"] and position.distance_to(game.hero.position)<=335.0:
			aim=game.hero.center()+game.hero.velocity*0.10;windup=0.52;ranged_clock=2.9
			visual.show_pose("attack",(aim-position).normalized());visual.frame=0;return
		elif kind in ["wisp","spearman","spore","moth","baj_nimen"] and position.distance_to(game.hero.position)<(640 if is_boss() else 350):
			aim=game.hero.center()+game.hero.velocity*0.12;windup=0.7 if kind=="spearman" else (0.70 if kind=="baj_nimen" else 0.55);ranged_clock=3.0 if is_boss() else 3.0
			visual.show_pose("attack",(aim-position).normalized());visual.frame=0;return

	if kind in ["skunk_bombardier","venom_spitter"] and not busy and ranged_clock<=0.0:
		var bomb_target := _pick_skunk_target()
		if bomb_target != Vector2.INF:
			aim=bomb_target;windup=0.55;ranged_clock=4.6
			visual.show_pose("attack",(aim-position).normalized());visual.frame=0;return

	if kind in ["turtle_shaman","water_elder"] and not busy and ability_clock<=0.0:
		if _has_injured_ally(155.0):
			ability_kind="heal";ability_windup=0.60;ability_clock=9.5
			visual.show_pose("attack",facing);visual.play("attack");visual.frame=0;return

	if kind in ["conch_mage","soul_reaver"] and not busy and ability_clock<=0.0:
		if _has_injured_ally(170.0):
			ability_kind="ally_shield";ability_windup=0.55;ability_clock=5.0
			visual.show_pose("skill",facing);visual.play("skill");visual.frame=0;return

	if kind=="tempest_elemental" and not busy and ability_clock<=0.0:
		var has_target: bool = is_instance_valid(blocker) or (not game.hero.knocked_out and position.distance_to(game.hero.position)<=175.0)
		if has_target:
			var t_pt: Vector2 = game.hero.position if (not game.hero.knocked_out and position.distance_to(game.hero.position)<=175.0) else blocker.position
			ability_kind="storm_strike";ability_windup=0.75;ability_clock=4.6
			game.delayed_attack(t_pt,86.0,float(data.damage)*damage_scale()*1.3,1,"enemy",0.75,{"telegraph":"storm_strike","hits_soldiers":true,"debuff":{"kind":"slow","duration":1.8,"strength":0.35},"fx_kind":"lightning","fx_color":Color("58ecff")})
			visual.show_pose("skill",facing);visual.play("skill");visual.frame=0;return

	if kind=="bluegale" and not busy and ability_clock<=0.0:
		ability_kind="storm_haste";ability_windup=0.55;ability_clock=5.2
		visual.show_pose("skill",facing);visual.play("skill");visual.frame=0;return

	if kind=="vile_eyenest" and not busy and summon_clock<=0.0:
		ability_kind="hatch_eyeling";ability_windup=0.65;summon_clock=6.0
		visual.show_pose("skill",facing);visual.play("skill");visual.frame=0;return

	if kind in ["bear_vanguard","bloodshell_crab","bloodshell_boss","twilight_golem","bloodsoil_behemoth","bloodsoil_boss"] and not busy and ability_clock<=0.0:
		var has_target: bool = is_instance_valid(blocker) or (not game.hero.knocked_out and position.distance_to(game.hero.position)<=135.0)
		if has_target:
			var is_ruins_crystal := kind in ["twilight_golem","bloodsoil_behemoth","bloodsoil_boss"]
			ability_kind="heavy_slam";ability_windup=0.75;ability_clock=3.4 if is_mini_boss() else 4.2
			var slam_pt := position + facing * 28.0
			var rad := 108.0 if is_mini_boss() else (96.0 if elite else 88.0)
			var t_name := "crystal_spikes" if is_ruins_crystal else ("boss_slam" if is_mini_boss() else "bear_slam")
			var fx_c := Color("d664ff") if is_ruins_crystal else Color("e8a864")
			var st_dur := 0.55 if is_ruins_crystal or kind in ["bloodshell_crab","bloodshell_boss"] else 0.0
			var db_arr: Variant = [{"kind":"slow","duration":1.8,"strength":0.35}]
			if st_dur > 0.0: db_arr = [{"kind":"slow","duration":1.8,"strength":0.35},{"kind":"stun","duration":st_dur}]
			game.delayed_attack(slam_pt,rad,float(data.damage)*damage_scale()*(1.45 if is_mini_boss() else 1.28),1 if is_ruins_crystal else 0,"enemy",0.75,{"telegraph":t_name,"hits_soldiers":true,"debuff":db_arr,"fx_kind":"slam","fx_color":fx_c})
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
	elif kind=="leviathan":
		_check_leviathan_phase()
		if seal_cast_clock<=0.0:
			seal_cast_clock=9.5 if boss_phase>=2 else 12.0
			_leviathan_seal_towers(3 if boss_phase>=2 else 2)
		if slam_clock<=0.0 and not busy:
			var hero_near: bool = not game.hero.knocked_out and position.distance_to(game.hero.position)<=220.0
			var soldier_near := false
			for s in game.soldiers:
				if is_instance_valid(s) and not s.dead and position.distance_to(s.position)<=140.0:
					soldier_near=true;break
			if hero_near or soldier_near:
				slam_clock=3.8 if boss_phase>=2 else 4.6
				var anchor_pt: Vector2 = game.hero.position if hero_near else position + facing * 48.0
				game.delayed_attack(anchor_pt,112.0,float(data.damage)*damage_scale()*1.35,1,"enemy",0.85,{"telegraph":"boss_slam","hits_soldiers":true,"debuff":{"kind":"slow","duration":2.0,"strength":0.35},"fx_kind":"abyss_burst","fx_color":Color("48d4ce")})
	elif kind=="baj_nimen":
		_check_baj_nimen_phase()
		if slam_clock<=0.0:
			slam_clock=3.5 if boss_phase>=2 else 4.6
			_baj_nimen_starfall(3 if boss_phase>=1 else 1)
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
	elif kind_done=="ally_shield":
		var best_ally: ArenaEnemy = null
		var best_hp := 2.0
		for other in game.enemies:
			if other == self or not is_instance_valid(other) or other.dead or other.is_guard:
				continue
			if position.distance_to(other.position) <= 170.0 and other.health / maxf(1.0, other.max_health) < best_hp:
				best_hp = other.health / maxf(1.0, other.max_health)
				best_ally = other
		if is_instance_valid(best_ally):
			var shield_amt := 75.0 if kind == "conch_mage" else 85.0
			best_ally.barrier_shield = minf(260.0, best_ally.barrier_shield + shield_amt)
			best_ally.health = minf(best_ally.max_health, best_ally.health + best_ally.max_health * 0.10)
			game.effect(best_ally.center(), 42.0, Color("7ce8ff") if kind == "conch_mage" else Color("c476ff"), "upgrade", 0.4)
		if kind == "soul_reaver":
			game.spawn_enemy("void_eyeling", route_id, maxf(0.0, progress - 24.0))
	elif kind_done=="storm_haste":
		for other in game.enemies:
			if not is_instance_valid(other) or other.dead or other.is_guard:
				continue
			if position.distance_to(other.position) <= 190.0:
				other.storm_haste_clock = maxf(other.storm_haste_clock, 3.6)
		game.effect(position, 145.0, Color("56e8ff"), "lightning", 0.50)
	elif kind_done=="hatch_eyeling":
		for idx in range(2):
			game.spawn_enemy("void_eyeling", route_id, maxf(0.0, progress - 22.0 - float(idx) * 20.0))
		game.effect(center(), 46.0, Color("c46cff"), "summon", 0.45)
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

func _leviathan_seal_towers(count: int) -> void:
	if game == null:
		return
	var cands: Array = []
	for t in game.towers:
		if not is_instance_valid(t) or t.destroyed or t.is_sealed() or t.is_seal_warning():
			continue
		cands.append(t)
	if cands.is_empty():
		return
	cands.sort_custom(func(a, b): return position.distance_squared_to(a.position) < position.distance_squared_to(b.position))
	var chosen := mini(count, cands.size())
	for i in range(chosen):
		var tower: ArenaTower = cands[i]
		tower.apply_seal(7.5, 3.0)
		game.effect(tower.position, 48.0, Color("48d4ce"), "abyss_burst", 0.55)
		game.numbers.append({"point": tower.position + Vector2(0, -48), "text": "触手封锁!", "colour": Color("7af2de"), "life": 1.1, "duration": 1.1})
	game.audio.play("heavy_hit", -10)

func _baj_nimen_starfall(count: int) -> void:
	if game == null:
		return
	var targets: Array[Vector2] = []
	if not game.hero.knocked_out:
		targets.append(game.hero.position)
	for s in game.soldiers:
		if is_instance_valid(s) and not s.dead and targets.size() < count:
			targets.append(s.position)
	while targets.size() < count:
		var road: Curve2D = game.enemy_road(self)
		var off := float(targets.size()) * 95.0 + 40.0
		targets.append(road.sample_baked(minf(road.get_baked_length() - 40.0, progress + off), true))
	for i in range(mini(count, targets.size())):
		var pt: Vector2 = targets[i].clamp(Vector2(60, 100), Vector2(game.world_size()) - Vector2(60, 40))
		game.delayed_attack(pt, 96.0, float(data.damage) * damage_scale() * 1.25, 1, "enemy", 1.15, {
			"telegraph": "abyss_starfall", "hits_soldiers": true,
			"debuff": {"kind": "slow", "duration": 1.8, "strength": 0.35},
			"fx_kind": "starfall", "fx_color": Color("cf74ff")
		})
	game.audio.play("mage_cast", -10)

func _check_leviathan_phase() -> void:
	if kind != "leviathan" or dead:
		return
	var lphase := 2 if health < max_health * 0.33 else (1 if health < max_health * 0.66 else 0)
	while boss_phase < lphase:
		boss_phase += 1
		visual.show_pose("skill", facing); visual.play("skill"); visual.frame = 0
		if game.feel.enabled:
			game.feel.trauma = minf(1.0, game.feel.trauma + 0.34)
		if boss_phase == 1:
			_leviathan_seal_towers(2)
			for i in range(3): game.spawn_enemy("murloc_hunter", route_id, maxf(0.0, progress - 40.0 - float(i) * 24.0))
			for i in range(2): game.spawn_enemy("water_sprite", route_id, maxf(0.0, progress - 65.0 - float(i) * 28.0))
			game.effect(center(), 145.0, Color("48e4dc"), "abyss_burst", 0.75)
		elif boss_phase == 2:
			_leviathan_seal_towers(3)
			for i in range(2): game.spawn_enemy("tide_warrior", route_id, maxf(0.0, progress - 45.0 - float(i) * 28.0))
			game.spawn_enemy("bluegale", route_id, maxf(0.0, progress - 70.0))
			game.effect(center(), 165.0, Color("5ef2ea"), "abyss_burst", 0.85)

func _check_baj_nimen_phase() -> void:
	if kind != "baj_nimen" or dead:
		return
	var bphase := 2 if health < max_health * 0.33 else (1 if health < max_health * 0.66 else 0)
	while boss_phase < bphase:
		boss_phase += 1
		visual.show_pose("skill", facing); visual.play("skill"); visual.frame = 0
		if game.feel.enabled:
			game.feel.trauma = minf(1.0, game.feel.trauma + 0.36)
		if boss_phase == 1:
			barrier_shield = 680.0
			_baj_nimen_starfall(3)
			for i in range(2): game.spawn_enemy("twilight_harasser", route_id, maxf(0.0, progress - 42.0 - float(i) * 26.0))
			for i in range(2): game.spawn_enemy("void_eyeling", route_id, maxf(0.0, progress - 62.0 - float(i) * 20.0))
			game.effect(center(), 150.0, Color("cb76ff"), "void_warp", 0.80)
		elif boss_phase == 2:
			barrier_shield = 420.0
			_baj_nimen_starfall(3)
			if game.stage_gimmicks != null and game.stage_gimmicks.has_method("trigger_boss_rift_warp"):
				game.stage_gimmicks.trigger_boss_rift_warp(self)
			game.effect(center(), 170.0, Color("ff78f4"), "void_warp", 0.85)

func _check_miniboss_phase() -> void:
	if _miniboss_split_done or dead or health >= max_health * 0.50:
		return
	if kind == "bloodshell_boss":
		_miniboss_split_done = true
		for i in range(2): game.spawn_enemy("murloc_hunter", route_id, maxf(0.0, progress - 35.0 - float(i) * 24.0))
		game.effect(center(), 92.0, Color("56e4dc"), "abyss_burst", 0.6)
	elif kind == "bloodsoil_boss":
		_miniboss_split_done = true
		for i in range(2): game.spawn_enemy("void_eyeling", route_id, maxf(0.0, progress - 32.0 - float(i) * 20.0))
		game.spawn_enemy("twilight_avenger", route_id, maxf(0.0, progress - 52.0))
		game.effect(center(), 98.0, Color("d45cff"), "blast", 0.6)

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

func _is_heavy_melee() -> bool:
	return is_boss() or is_mini_boss() or elite or kind in ["brute","tusk_fighter","bear_vanguard","bear_woodsman","darksteel_guard","captain","tide_warrior","tempest_elemental","bloodshell_crab","twilight_avenger","avenger_rider","soul_reaver","twilight_golem","bloodsoil_behemoth"]

func is_hero_in_melee_cone(point: Vector2, pad := 0.0) -> bool:
	var rel: Vector2 = point - position
	var dist: float = rel.length()
	if dist > melee_reach + pad:
		return false
	if dist <= 18.0:
		return true
	return rel.normalized().dot(melee_dir) >= melee_arc_cos

func _can_start_hero_melee() -> bool:
	if game == null:
		return true
	var active: int = 0
	var has_heavy: bool = false
	for other in game.enemies:
		if other == self or not is_instance_valid(other) or other.dead:
			continue
		if other.melee_target == game.hero and other.melee_windup > 0.0:
			active += 1
			if other._is_heavy_melee():
				has_heavy = true
	if has_heavy:
		return false
	if _is_heavy_melee():
		return active < 1
	return active < 2

func melee(target: Node2D) -> void:
	if melee_clock>0.0 or melee_windup>0.0 or melee_recovery>0.0 or not is_instance_valid(target):return
	if game != null and target == game.hero:
		if is_rift_mob and game.hero.domain != "rift":
			return
		if not is_rift_mob and game.hero.domain != "defense":
			return
		if not _can_start_hero_melee():
			melee_clock = 0.28 + float(get_instance_id() % 4) * 0.06
			return
		var heavy := _is_heavy_melee()
		var raw: Vector2 = target.position - position
		melee_dir = raw.normalized() if raw.length_squared() > 1.0 else facing
		facing = melee_dir
		melee_reach = 70.0 if (kind == "bear_woodsman" and enraged) else (66.0 if heavy else 58.0)
		melee_arc_cos = 0.15 if (kind == "bear_woodsman" and enraged) else (0.34 if heavy else 0.42)
		melee_windup_total = 0.58 if (kind == "bear_woodsman" and enraged) else (0.74 if heavy else 0.54)
		melee_windup = melee_windup_total
		melee_clock = 1.05 if (kind == "bear_woodsman" and enraged) else (1.55 if heavy else 1.35)
		melee_target = target
		_melee_perfect_claimed = false
		visual.show_pose("attack", melee_dir)
		visual.pause()
		visual.frame = 0
		queue_redraw()
		return
	melee_clock=0.78 if (kind=="bear_woodsman" and enraged) else 1.15
	visual.show_pose("attack",(target.position-position).normalized());visual.play("attack");visual.frame=0
	melee_target=target;melee_windup_total=0.26 if (kind=="bear_woodsman" and enraged) else 0.3;melee_windup=melee_windup_total

func _resolve_melee() -> void:
	var damage:=float(data.damage)*damage_scale()*(1.25 if elite else 1.0)
	if game != null and melee_target == game.hero:
		var heavy := _is_heavy_melee()
		melee_recovery = 0.36 if heavy else 0.26
		if visual.sprite_frames != null and visual.sprite_frames.has_animation("attack"):
			visual.play("attack")
			visual.frame = mini(3, visual.sprite_frames.get_frame_count("attack") - 1)
		game.effect(position + melee_dir * (melee_reach * 0.45) + Vector2(0.0, -18.0), melee_reach * 0.72, Color("ff7856") if heavy else Color("f6c27a"), "slash", 0.16, melee_dir)
		if kind == "bear_woodsman" and enraged:
			for s in game.soldiers:
				if is_instance_valid(s) and not s.dead and position.distance_to(s.position) <= 70.0:
					s.take_hit(damage, int(data.type), true)
		if not game.hero.knocked_out and game.hero.domain == domain and is_hero_in_melee_cone(game.hero.position):
			if game.hero.is_perfect_dodge_active() and not _melee_perfect_claimed:
				_melee_perfect_claimed = true
				game.hero.trigger_perfect_dodge(self, melee_dir)
			elif game.hero.protection <= 0.0:
				game.hero.take_hit(damage, int(data.type), true, melee_dir)
				if kind == "rottooth_hyena":
					game.hero.apply_debuff("bleed", 2.0, 5.0)
				elif kind in ["throat_cutter","wind_captain","spectral_cutter"]:
					game.hero.apply_debuff("bleed", 3.0, 8.0)
				elif kind == "water_sprite":
					game.hero.apply_debuff("slow", 1.8, 0.28)
		melee_target = null
		queue_redraw()
		return
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
		melee_target = null
		return
	if is_instance_valid(melee_target) and position.distance_to(melee_target.position)<58 and melee_target.can_block():
		melee_target.take_hit(damage,int(data.type),true)
	melee_target = null

func release_ranged() -> void:
	if game.hero.knocked_out and kind not in ["skunk_bombardier","venom_spitter"]:return
	match kind:
		"spore":
			game.delayed_attack(aim,67,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),1,"enemy",0.9,{"origin":center(),"domain":domain})
		"skunk_bombardier","venom_spitter":
			game.delayed_attack(aim,84.0,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),1,"enemy",0.85,{
				"origin":center(),"telegraph":"toxic_bomb","domain":domain,
				"debuff":[{"kind":"slow","duration":2.0,"strength":0.30},{"kind":"poison","duration":3.0,"strength":7.0}],
				"spawn_zone":{"kind":"toxic_cloud","radius":92.0,"duration":4.8,"dps":7.0},
				"fx_color":Color("5ce86e") if kind=="skunk_bombardier" else Color("a856ff")
			})
		"dreadeye_viper":
			var dir := (aim - center()).normalized()
			if dir.is_zero_approx():dir = facing
			game.fire_projectile(center(),center()+dir*700.0,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),int(data.type),"enemy",{
				"speed":680.0,"appearance":"viper_arrow","domain":domain,
				"debuffs":[{"kind":"poison","duration":3.5,"strength":6.0},{"kind":"slow","duration":2.5,"strength":0.28}]
			})
		"scout_vulture":
			var dir_v := (aim - center()).normalized()
			if dir_v.is_zero_approx():dir_v = facing
			game.fire_projectile(center(),center()+dir_v*420.0,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),0,"enemy",{
				"speed":380.0,"appearance":"feather_dart","domain":domain
			})
		"two_headed_troll":
			var dir_t := (aim - center()).normalized()
			if dir_t.is_zero_approx():dir_t = facing
			game.fire_projectile(center(),center()+dir_t*640.0,float(data.damage)*damage_scale()*1.1,0,"enemy",{
				"speed":330.0,"appearance":"boulder","domain":domain,
				"debuffs":[{"kind":"slow","duration":2.2,"strength":0.35}]
			})
		"moth":
			for index in range(12):
				var direction:=Vector2.RIGHT.rotated(TAU*index/12.0)
				game.fire_projectile(center(),center()+direction*600,float(data.damage)*damage_scale(),1,"enemy",{"speed":145.0,"domain":domain})
		"baj_nimen":
			var base_dir:=(aim-center()).angle()
			for index in range(3):
				var spread:=(index-1)*0.24
				var dir_b:=Vector2.RIGHT.rotated(base_dir+spread)
				game.fire_projectile(center(),center()+dir_b*660.0,float(data.damage)*damage_scale(),1,"enemy",{"speed":285.0,"appearance":"void_bolt","domain":domain})
		"storm_wyrm","bluegale":
			game.fire_projectile(center(),aim,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),1,"enemy",{"speed":410.0,"appearance":"lightning_bolt","domain":domain})
		"tide_warrior":
			game.fire_projectile(center(),aim,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),0,"enemy",{"speed":440.0,"appearance":"spear","domain":domain})
		"conch_mage","water_elder":
			game.fire_projectile(center(),aim,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),1,"enemy",{"speed":280.0,"appearance":"water_bolt","domain":domain})
		"void_gazer","twilight_harasser","soul_reaver","vile_eyenest":
			game.fire_projectile(center(),aim,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),1,"enemy",{"speed":320.0,"appearance":"void_bolt","domain":domain})
		_:
			game.fire_projectile(center(),aim,float(data.damage)*damage_scale()*(1.25 if elite else 1.0),int(data.type),"enemy",{"speed":460.0 if kind=="spearman" else 185.0,"appearance":"spear" if kind=="spearman" else "magic","domain":domain})

func take_hit(amount: float,damage_type: int,source: String,stagger := 0.0,chill_time := 0.0,pen_bonus := 0.0,attack: String="attack", incoming := Vector2.ZERO, contact := Vector2.INF, condition_hit: Dictionary={}) -> float:
	if dead:return 0
	var pen:=pen_bonus
	var vulnerability: float=([0.10,0.11,0.12][game.hero.passive_rank] if game.hero.class_id=="healer" else 0.10) if exposure>0 else 0.0
	var condition_result: Dictionary={}
	if source=="hero" and bool(condition_hit.get("crit",false)):
		condition_result["crit"]=true
	var damage:=ArenaCombat.resolve(amount,damage_type,float(data.armour),float(data.resistance),vulnerability,pen)
	if marked>0:damage*=1.0+mark_bonus
	if source=="hero" and game != null and game.passive_engine != null:
		damage *= game.passive_engine.controlled_enemy_damage_mult(self)
	if source in ["hero", "tower"] and game != null and game.relic_engine != null:
		damage *= game.relic_engine.boss_elite_damage_mult(self)
		if source == "tower" and game.relic_engine.tower_burn_dps() > 0.0:
			ignite(game.relic_engine.tower_burn_dps(), 3.0)
	if lighthouse_exposed>0.0:damage*=1.20
	var exploits_weakness:=source=="hero" and tower_weakness_clock>0.0 and damage>0.0
	if exploits_weakness: damage*=1.0+ArenaTowerTrial.WEAKNESS_BONUS
	var absorbed:=minf(barrier_shield,damage);barrier_shield-=absorbed
	var hp_damage:=minf(health,damage-absorbed)
	var total_dealt:=absorbed+hp_damage
	health-=hp_damage;hurt_time=0.12
	if exploits_weakness and total_dealt>0.0:
		tower_weakness_clock=0.0
		game.tower_trial_stats.weakness_used+=1
		game.effect(center(),15.0,Color("f1cd8b"),"hit",0.22)
		queue_redraw()
	_check_leviathan_phase()
	_check_baj_nimen_phase()
	_check_miniboss_phase()
	_check_troll_phase()
	if kind=="soul_reaver" and not dash_used and health>0.0 and health<max_health*0.55 and barrier_shield<=0.0:
		dash_used=true
		barrier_shield=120.0
		game.effect(center(),52.0,Color("c476ff"),"upgrade",0.45)
	if kind=="bear_woodsman" and not enraged and health>0.0 and health<max_health*0.65:
		enraged=true
		game.effect(center(),62.0,Color("ff7048"),"blast",0.42)
		game.audio.play("heavy_hit",-12)
	if not is_boss():
		var stun_mult := 0.25 if _is_juggernaut() else (0.35 if is_mini_boss() else 1.0)
		var eff_stagger := stagger * stun_mult
		if eff_stagger>0.0:
			stun=maxf(stun,eff_stagger)
		slow=maxf(slow,chill_time)
		if eff_stagger>0.0 and charge_left<=0.0:
			melee_windup=0.0
			melee_recovery=0.0
			_melee_perfect_claimed=false
			melee_target=null
			windup=0.0
			ability_windup=0.0
			ability_kind=""
			queue_redraw()
	game.damage_stats[source]=float(game.damage_stats.get(source,0))+total_dealt
	var impact_point := center() if contact == Vector2.INF else contact
	game.feedback(impact_point,total_dealt,damage_type,health<=0,source,self,attack,incoming,absorbed > 0 and hp_damage <= 0,condition_result)
	if source=="hero" and not bool(condition_hit.get("passive_proc",false)) and game != null and game.event_bus != null:
		game.event_bus.emit_event("hero_hit", {"enemy": self, "damage": total_dealt, "crit": bool(condition_hit.get("crit", false))})
	if health<=0:
		dead=true
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
	return minf(tick,health)

func _draw() -> void:
	if submerged:
		var t_sub := float(Time.get_ticks_msec()) * 0.006
		for w_i in range(6):
			var wx := (-18.0 + float(w_i) * 7.2 + sin(t_sub + float(w_i)) * 2.5)
			var wy := -6.0 + cos(t_sub * 1.3 + float(w_i) * 1.4) * 2.5
			var wp := Vector2(wx, wy).snapped(Vector2(2, 2))
			draw_rect(Rect2(wp - Vector2(3, 1.5), Vector2(6, 3)), Color("113244", 0.78))
			draw_rect(Rect2(wp - Vector2(2, 1), Vector2(4, 2)), Color("8ff6ff", 0.90) if w_i % 2 == 0 else Color("43b8c8", 0.85))
	else:
		draw_set_transform(Vector2.ZERO,0,Vector2(1,0.4))
		draw_circle(Vector2.ZERO,radius*(0.65 if is_flying() else 0.8),Color(0.07,0.13,0.1,0.32 if is_flying() else 0.25))
		draw_set_transform(Vector2.ZERO)
	if storm_haste_clock > 0.0:
		var st_t := float(Time.get_ticks_msec()) * 0.007
		for s_i in range(4):
			var sa := st_t + float(s_i) * (TAU / 4.0)
			var sp := Vector2(cos(sa) * (radius * 0.75), -14.0 - float(s_i % 2) * 10.0 + sin(sa * 2.0) * 4.0).snapped(Vector2(2, 2))
			draw_rect(Rect2(sp - Vector2(2, 2), Vector2(4, 4)), Color("122838", 0.80))
			draw_rect(Rect2(sp - Vector2(1, 1), Vector2(2, 2)), Color("74f6ff", 0.95))
	if lighthouse_exposed > 0.0:
		var lt_t := float(Time.get_ticks_msec()) * 0.005
		for l_i in range(4):
			var la := lt_t + float(l_i) * (TAU / 4.0)
			var lp := Vector2(cos(la) * (radius * 0.82), -visual.base_height * 0.55 + sin(la * 2.0) * 6.0).snapped(Vector2(2, 2))
			draw_rect(Rect2(lp - Vector2(2, 2), Vector2(4, 4)), Color("ffe882", 0.92))
	if enraged or roar_buff_clock > 0.0:
		var ember_t := float(Time.get_ticks_msec()) * 0.005
		var ember_c := Color("ff623e") if enraged else Color("ffbe58")
		for e_i in range(4):
			var phase_e := fmod(ember_t + float(e_i) * 0.37, 1.0)
			var ex := cos(float(e_i) * 1.7 + ember_t * 0.8) * (radius * 0.65)
			var ey := -6.0 - phase_e * (visual.base_height * 0.72)
			var ea := (1.0 - phase_e) * 0.88
			var pt := Vector2(ex, ey).snapped(Vector2(2, 2))
			draw_rect(Rect2(pt - Vector2(2, 2), Vector2(4, 4)), Color(0.10, 0.06, 0.08, ea * 0.8))
			draw_rect(Rect2(pt - Vector2(1, 1), Vector2(2, 2)), Color(ember_c.r, ember_c.g, ember_c.b, ea))
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
	if health<max_health:
		draw_rect(Rect2(-18,hp_y,36,3),Color("25372b"));draw_rect(Rect2(-18,hp_y,36*health/max_health,3),Color("ce8274"))
	if barrier_shield>0.0:
		draw_rect(Rect2(-22,hp_y-5,44*minf(1.0,barrier_shield/520.0),3),Color("7ce8ff"))
	if elite:
		var cy := hp_y + 4.0
		draw_colored_polygon(PackedVector2Array([Vector2(-6, cy), Vector2(-6, cy - 5), Vector2(-3, cy - 2), Vector2(0, cy - 6), Vector2(3, cy - 2), Vector2(6, cy - 5), Vector2(6, cy)]), Color("f6cc79"))
	if is_bounty_elite:
		var b_t := float(Time.get_ticks_msec()) * 0.005
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, radius + 10.0, 0.0, TAU, 24, Color("ffe474", 0.72 + 0.25 * sin(b_t * 2.0)), 2.2)
		draw_set_transform(Vector2.ZERO)
		if game != null and game.rift_domain != null and game.rift_domain._tex_chest_closed != null:
			draw_texture_rect(game.rift_domain._tex_chest_closed, Rect2(-14.0, hp_y - 30.0, 28.0, 28.0), false)
	if marked>0:
		var mk := Vector2(0.0, hp_y - 7.0).snapped(Vector2(2, 2))
		draw_colored_polygon(PackedVector2Array([mk + Vector2(0, -5), mk + Vector2(5, 0), mk + Vector2(0, 5), mk + Vector2(-5, 0)]), Color("14111b", 0.85))
		draw_colored_polygon(PackedVector2Array([mk + Vector2(0, -3), mk + Vector2(3, 0), mk + Vector2(0, 3), mk + Vector2(-3, 0)]), Color("ffe484"))
	if windup>0 and kind=="dreadeye_viper":
		var charge: float=1.0-clampf(windup/0.72,0.0,1.0)
		var origin_off := Vector2(facing.x*18.0,-32.0)
		var target_off := aim - position
		var laser_col := Color(1.0,0.94,0.84,0.85) if aim_locked else Color(1.0,0.34,0.28,0.46+0.26*charge)
		draw_line(origin_off, target_off, laser_col, 2.0 if aim_locked else 1.4, false)
		var pt := origin_off.snapped(Vector2(2, 2))
		var gs := 6.0 if aim_locked else 4.0
		draw_line(pt - Vector2(gs, 0), pt + Vector2(gs, 0), Color("b8ff8e"), 2.0, false)
		draw_line(pt - Vector2(0, gs), pt + Vector2(0, gs), Color("b8ff8e"), 2.0, false)
		draw_rect(Rect2(pt - Vector2(1.5, 1.5), Vector2(3, 3)), Color.WHITE)
	if ability_windup>0.0 and ability_kind=="heal":
		var h_p := 1.0 - clampf(ability_windup/0.60,0.0,1.0)
		for i in range(6):
			var ha := float(i) * (TAU / 6.0) + h_p * 2.4
			var hpos := Vector2(cos(ha) * 18.0, -10.0 - h_p * 30.0 - float(i % 2) * 8.0).snapped(Vector2(2, 2))
			var col_h := Color("9effaa", 0.90)
			draw_line(hpos - Vector2(3, 0), hpos + Vector2(3, 0), col_h, 2.0, false)
			draw_line(hpos - Vector2(0, 3), hpos + Vector2(0, 3), col_h, 2.0, false)
	if ability_windup>0.0 and ability_kind=="rhino_charge":
		var c_p := 1.0 - clampf(ability_windup/0.90,0.0,1.0)
		var c_dir := (ability_target - position).normalized()
		if c_dir.is_zero_approx(): c_dir = facing
		var eye_pt := (Vector2(c_dir.x * 16.0, -visual.base_height * 0.56)).snapped(Vector2(2, 2))
		var e_len := 7.0 + 4.0 * c_p
		draw_line(eye_pt - Vector2(e_len, 0), eye_pt + Vector2(e_len, 0), Color("ff4438"), 2.2, false)
		draw_line(eye_pt - Vector2(0, e_len * 0.7), eye_pt + Vector2(0, e_len * 0.7), Color("ffe6a4"), 1.6, false)
		for k in range(5):
			var dist := 18.0 + float(k) * 20.0
			var jx := sin(float(k) * 3.1) * 7.0
			var pebble := (c_dir * dist + c_dir.orthogonal() * jx).snapped(Vector2(2, 2))
			var pa := clampf(c_p * 1.15 - float(k) * 0.12, 0.18, 0.86)
			draw_rect(Rect2(pebble - Vector2(2, 2), Vector2(4, 3)), Color(0.28, 0.22, 0.18, pa))
			draw_rect(Rect2(pebble - Vector2(1, 3), Vector2(2, 2)), Color(0.85, 0.72, 0.54, pa * 0.8))
	if windup>0 and kind=="spearman":
		var charge: float=1.0-clampf(windup/0.7,0.0,1.0)
		var glint:=(Vector2(facing.x*14.0,-26.0)).snapped(Vector2(2,2))
		var star:=6.0+4.0*(1.0-charge)
		draw_line(glint-Vector2(star,0),glint+Vector2(star,0),Color(1.0,0.88,0.52,0.90),2.0,false)
		draw_line(glint-Vector2(0,star),glint+Vector2(0,star),Color(1.0,0.88,0.52,0.90),2.0,false)
		draw_rect(Rect2(glint-Vector2(1.5,1.5),Vector2(3,3)),Color("fff6c8"))
	if melee_windup>0.0 and melee_target==game.hero:
		var heavy := _is_heavy_melee()
		var mp := 1.0 - clampf(melee_windup / maxf(0.05, melee_windup_total), 0.0, 1.0)
		if heavy:
			for d_i in range(3):
				var back := (-melee_dir * (10.0 + float(d_i) * 5.0 * mp) + Vector2(float(d_i - 1) * 5.0, -2.0 * mp)).snapped(Vector2(2, 2))
				draw_rect(Rect2(back - Vector2(2, 1.5), Vector2(4, 3)), Color(0.68, 0.60, 0.48, 0.55 * (1.0 - mp * 0.4)))

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
	if windup>0 and kind in ["moth","baj_nimen","leviathan"]:
		var charge: float=1.0-clampf(windup/0.70,0.0,1.0)
		var ring_col:=Color(0.76,0.52,1.0,0.82) if kind=="baj_nimen" else (Color(0.38,0.92,0.88,0.82) if kind=="leviathan" else Color(0.92,0.58,0.68,0.78))
		for k in range(6):
			var a := float(k) * (TAU / 6.0) + charge * 2.2
			var dist := 34.0 * (1.0 - charge * 0.72)
			var mp := (Vector2(cos(a) * dist, -visual.base_height * 0.48 + sin(a) * dist * 0.55)).snapped(Vector2(2, 2))
			draw_rect(Rect2(mp - Vector2(2, 2), Vector2(4, 4)), Color("14111b", 0.75))
			draw_rect(Rect2(mp - Vector2(1, 1), Vector2(2, 2)), ring_col)
