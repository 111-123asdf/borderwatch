class_name ArenaTower
extends Node2D
const MAX_LEVEL:=3
var game: Node2D
var kind: String="archer"
var site_id:=0
var level:=1
var data: Dictionary={}
var destroyed:=false
var doctrine_id: String=""
var doctrine_data: Dictionary={}
var awaiting_doctrine:=false
var branch_ranks: Array[int]=[0,0]
const AttackTiming := preload("res://scripts/arena/arena_attack_timing.gd")
var attack_clock:=0.0
var fire_clock:=0.0
var timing: AttackTiming = AttackTiming.new()
var _draw_sig: int = -1
func _sync_tower_draw() -> void:
	var sel: int = 1 if game.selected_site==site_id else 0
	var sig: int = sel+(2 if awaiting_doctrine else 0)+(branch_ranks[0]<<2)+(branch_ranks[1]<<5)+(1<<8 if doctrine_id!="" else 0)
	if sig!=_draw_sig:
		_draw_sig=sig;queue_redraw()
var rally_point:=Vector2.ZERO
var rally_across:=Vector2.DOWN
var bombard_point:=Vector2.INF
var target_mode: String="first"
var troops: Array=[]
var body: Sprite2D
var moving_part: Sprite2D
var visual_clock:=0.0
var visual_target:=Vector2.RIGHT
var shot_count:=0
var streak_target: Node2D
var streak_count:=0
var focus_target: ArenaEnemy
var focus_layers:=0
const SNARE_ARM_TIME:=1.2
var project_level:=0
var project_clock:=0.0
var project_gold:=0
var project_doctrine:=""
var invested_gold:=0
static var art_cache: Dictionary={}
func _ready() -> void:
	data=game.tower_display_data(kind);body=Sprite2D.new();body.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(body);refresh_art()
	var skin:=ArenaGrounding.material(game.level_id);body.material=skin;moving_part.material=skin
	var obstacle:=StaticBody2D.new();obstacle.collision_layer=1;obstacle.collision_mask=2
	var collision:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=25;collision.shape=circle;obstacle.add_child(collision);add_child(obstacle)
	var near: Dictionary=game.nearest_road(position)
	var anchor: Vector2=near.point
	if game.tower_lab and kind=="barracks":
		var road: Curve2D=game.routes[near.route]
		var offset:=maxf(0.0,float(near.progress)-40.0)
		anchor=road.sample_baked(offset,true)
		orient_rally(road,offset)
	rally_point=anchor
	if kind=="snare": attack_clock=SNARE_ARM_TIME
	if project_level==1: modulate.a=0.52
	if kind=="barracks" and project_level!=1:
		sync_troops()
func refresh_art() -> void:
	var key: String=kind+str(level)
	if not art_cache.has(key):
		art_cache[key]=ArenaBattleArt.tower_texture(kind,level)
	if art_cache.has(key):
		body.texture=art_cache[key]
		var placement:=ArenaBattleArt.contact(kind,level,body.texture.get_size())
		body.scale=placement.scale;body.offset=(Vector2(0.5,0.5)-Vector2(placement.uv))*body.texture.get_size();body.position=Vector2.ZERO
		# Only a masked upper component moves. The feet/contact remain immobile.
		if moving_part==null:moving_part=Sprite2D.new();moving_part.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(moving_part)
		if ArenaBattleArt.TOWER_REGIONS.has(kind):
			if not moving_part.draw.is_connected(draw_mechanism): moving_part.draw.connect(draw_mechanism)
			moving_part.position=muzzle()-firing_position()
			return
		body.texture=load("res://assets/v017/tower_"+kind+"_"+str(level)+"_base.png")
		moving_part.texture=load("res://assets/v017/tower_"+kind+"_"+str(level)+"_part.png")
		moving_part.scale=placement.scale;moving_part.offset=body.offset

func site_trait() -> String:
	if game==null or game.level_definition.is_empty():return ""
	var traits: Array=game.level_definition.get("site_traits",[])
	if site_id>=0 and site_id<traits.size():return str(traits[site_id])
	return ""
static func trait_label(trait_id: String) -> String:
	return {"highground":"高台","choke":"隘口","conduit":"脉座"}.get(trait_id,"")
static func trait_summary(trait_id: String) -> String:
	return {"highground":"射程 +18%","choke":"兵营生命 +18% · 补员快 20%","conduit":"攻速 +14% · 穿透 +12%"}.get(trait_id,"")
func soldier_respawn_scale() -> float:
	return 1.25 if (kind=="barracks" and site_trait()=="choke") else 1.0
func upgrade_price() -> int:
	if game.tower_lab: return roundi(float(data.cost)*(1.6 if level==1 else 2.4))
	var base:=int(data.cost)*(level+1)/2+35
	return int(float(base)*(1.0-clampf(game.hero.mod("tower_upgrade"),0.0,0.5)))
func attack_range() -> float:
	var altar_range:=1.22 if (game.has_keystone("bastion_ward") and game.point_in_altar_aura(position)) else 1.0
	var trait_range:=1.18 if site_trait()=="highground" else 1.0
	if game.tower_lab: return trial_stat("reach")*trait_range
	return (float(data.reach)+(level-1)*16)*(1.0+game.hero.mod("tower_range"))*doc_mod("range_mult",1.0)*altar_range*trait_range
func reload_time() -> float:
	var overclock: float=game.altar_overclock_bonus(position) if game.has_method("altar_overclock_bonus") else 0.0
	var trait_speed: float=0.14 if site_trait()=="conduit" else 0.0
	if game.tower_lab: return trial_stat("cycle")/(1.0+trait_speed)
	return float(data.interval)/(1.0+0.14*(level-1))/(1.0+game.hero.mod("tower_speed"))*doc_mod("interval_mult",1.0)/(1.0+overclock)/(1.0+trait_speed)
func trial_stat(key: String) -> float: return ArenaTowerTrial.stat(kind,key,level)
func trial_arrow_range() -> float: return maxf(ArenaTowerTrial.ARCHER_FLIGHT,attack_range())
func trial_frost_inner() -> float: return attack_range()*ArenaTowerTrial.FROST_INNER_RATIO
func trial_shell_core() -> float: return splash_radius()*ArenaTowerTrial.SHELL_CORE_RATIO
func shot_power() -> float: return base_power()*game.support_scale(position)
func base_power() -> float: return trial_stat("power") if game.tower_lab else float(data.damage)*(1.0+0.6*(level-1))
func splash_radius() -> float:
	if game.tower_lab and kind=="cannon": return trial_stat("splash")
	var radius:=trial_stat("splash") if game.defense_rules and kind=="cannon" else float(64+(level-1)*12)
	return radius*doc_mod("splash_mult",1.0)*(1.30 if game.has_keystone("refract") else 1.0)
func doc_mod(key: String,fallback := 0.0) -> float:
	var trait_bonus: float=0.18 if (key=="soldier_health" and kind=="barracks" and site_trait()=="choke") else 0.0
	if doctrine_data.is_empty():return fallback+trait_bonus
	var effects: Dictionary=doctrine_data.get("effects",{})
	var base: float=float(effects[key]) if effects.has(key) else fallback
	var b_list: Array=ArenaDoctrines.branches(doctrine_id,kind)
	for index in range(mini(branch_ranks.size(),b_list.size())):
		var rank: int=branch_ranks[index]
		if rank<=0:continue
		var delta: Dictionary=b_list[index].get("delta",{})
		if delta.has(key):base+=float(delta[key])*float(rank)
	if key=="interval_mult":return maxf(0.25,base)
	if key=="frost_stacks":return maxf(1.0,base) if effects.has(key) or base>0.0 else base
	return base+trait_bonus
func branch_rank(index: int) -> int:
	return branch_ranks[index] if index>=0 and index<branch_ranks.size() else 0
func total_steps() -> int:
	return level+(1 if doctrine_id!="" else 0)+branch_ranks[0]+branch_ranks[1]
func branch_price(index: int) -> int:
	return ArenaDoctrines.branch_price(branch_rank(index))
func upgrade_branch(index: int) -> bool:
	if destroyed or not game.can_change_towers() or doctrine_id=="" or awaiting_doctrine:return false
	if index<0 or index>=branch_ranks.size():return false
	var rank:=branch_ranks[index]
	var branches:=ArenaDoctrines.branches(doctrine_id,kind)
	if rank>=3 or index>=branches.size():return false
	var price:=branch_price(index)
	if game.gold<price:return false
	game.gold-=price
	invested_gold+=price
	branch_ranks[index]=rank+1
	if kind=="barracks":sync_troops()
	game.effect(position,46,Color("f5cd6a") if index==0 else Color("7fd8ff"),"upgrade",0.45)
	queue_redraw()
	return true
func forced_target() -> String: return str(doctrine_data.get("effects",{}).get("target",""))
func penetration() -> float:
	var trait_pen: float=0.12 if site_trait()=="conduit" else 0.0
	return (doc_mod("armour_pen") if int(data.type)==0 else doc_mod("resist_pen"))+trait_pen
func doctrine_multiplier(enemy: Node2D) -> float:
	var result:=doc_mod("damage_mult",1.0)
	if doc_mod("bonus_armour")>0.0 and float(enemy.data.armour)>=ArenaDoctrines.HEAVY_ARMOUR:result*=1.0+doc_mod("bonus_armour")
	if doc_mod("bonus_resist")>0.0 and float(enemy.data.resistance)>=ArenaDoctrines.HIGH_RESIST:result*=1.0+doc_mod("bonus_resist")
	if doc_mod("bonus_elite")>0.0 and (enemy.elite or str(enemy.kind) in ["moth","colossus"]):result*=1.0+doc_mod("bonus_elite")
	return result
func upgrade(doctrine := "") -> bool:
	if level>=3 or destroyed or not game.can_change_towers():return false
	var price := upgrade_price()
	if project_level!=0 or game.gold<price: return false
	if game.timed_tower_work():
		start_project(level+1,price)
		project_doctrine=doctrine
		game.gold-=project_gold
		game.hud.refresh_context()
		return true
	game.gold-=price
	invested_gold+=price
	level+=1;refresh_art()
	_complete_upgrade(doctrine)
	return true

func _complete_upgrade(doctrine: String) -> void:
	if level==3 and doctrine_id=="":
		var options: Array=ArenaDoctrines.for_tower(kind)
		if not options.is_empty():
			if doctrine!="" and _apply_doctrine(doctrine):awaiting_doctrine=false
			else:awaiting_doctrine=true;game.pending_doctrine_site=site_id
	for soldier in troops:
		if is_instance_valid(soldier):soldier.refresh_stats()
	game.effect(position,65,Color("f4d28b"),"upgrade",0.55);game.audio.play("tower")
	if is_instance_valid(game.hud):game.hud.refresh_context()

func start_construction(cost: int) -> void:
	start_project(1,cost)

func start_project(next_level: int,cost: int) -> void:
	project_level=next_level
	project_clock=ArenaTowerTrial.BUILD_TIME
	project_gold=cost

func cancel_project() -> bool:
	if destroyed or project_level==0 or not game.can_manage_defense(): return false
	var was_building:=project_level==1
	game.gold+=project_gold
	project_level=0
	project_clock=0.0
	project_gold=0
	project_doctrine=""
	if was_building: retire()
	else: game.hud.refresh_context()
	return true

func finish_project() -> void:
	var was_building:=project_level==1
	var doctrine := project_doctrine
	level=project_level
	invested_gold+=project_gold
	project_level=0
	project_gold=0
	project_doctrine=""
	modulate.a=1.0
	if not was_building: refresh_art()
	if kind=="barracks": sync_troops()
	if not was_building and not game.tower_lab:
		_complete_upgrade(doctrine)
		return
	game.effect(position,46,Color("e1c68e"),"upgrade",0.42)
	game.audio.play("tower",-6)
	if game.selected_site==site_id: game.hud.refresh_context()
func choose_doctrine(id: String) -> bool:
	if not awaiting_doctrine or destroyed or not game.can_manage_defense():return false
	if not _apply_doctrine(id):return false
	awaiting_doctrine=false;game.pending_doctrine_site=-1
	game.effect(position,72,Color("9fd8f0"),"upgrade",0.7)
	return true
func _apply_doctrine(id: String) -> bool:
	var entry: Dictionary=ArenaDoctrines.by_id(id)
	if entry.is_empty() or str(entry.tower)!=kind or doctrine_id!="":return false
	doctrine_id=id;doctrine_data=entry
	var forced:=str(entry.effects.get("target",""))
	if forced!="":target_mode=forced
	if kind=="barracks":sync_troops()
	return true
func sync_troops() -> void:
	if kind!="barracks":return
	troops=troops.filter(func(soldier):return is_instance_valid(soldier))
	var target:=maxi(1,int(doc_mod("soldier_count",3))+(1 if game.has_keystone("vanguard") else 0))
	while troops.size()>target:
		var soldier: ArenaSoldier=troops.pop_back()
		game.blocking.release(soldier);game.soldiers.erase(soldier);soldier.queue_free()
	while troops.size()<target:
		var soldier:=ArenaSoldier.new();soldier.game=game;soldier.tower=self
		soldier.position=position if game.tower_lab else rally_point
		soldier.redeploying=game.tower_lab
		game.actors.add_child(soldier);game.soldiers.append(soldier);troops.append(soldier)
	for index in range(troops.size()):troops[index].slot=index
	for soldier in troops:soldier.refresh_stats()
func sell() -> bool:
	if destroyed or not game.can_change_towers() or project_level!=0:return false
	game.gold+=sale_value()
	retire()
	return true

func sale_value() -> int:
	if game.phase=="rest" and game.has_defense_effect(&"prep_refund"): return invested_gold
	if game.tower_lab: return floori(float(invested_gold)*0.6)
	var spent_branches:=0
	for rank in branch_ranks:
		for step_i in range(rank):spent_branches+=ArenaDoctrines.branch_price(step_i)
	return int((float(data.cost)*0.6+float(level-1)*data.cost*0.25+float(spent_branches)*0.6)*(1.0+game.hero.mod("sell_bonus")))

func retire() -> void:
	destroyed=true
	game.orders.tower_removed(self)
	for soldier in troops:
		if is_instance_valid(soldier):game.blocking.release(soldier);game.soldiers.erase(soldier);soldier.queue_free()
	game.towers.erase(self);game.rebuild_navigation();queue_free();game.hud.close_context()
func set_rally(point: Vector2) -> bool:
	if kind not in ["barracks","snare"] or destroyed or project_level==1 or not game.can_manage_defense():return false
	var destination := order_preview(point)
	if not destination.is_finite(): return false
	if rally_point.distance_to(destination)<1.0: return true
	if kind=="snare":
		rally_point=destination
		attack_clock=maxf(attack_clock,SNARE_ARM_TIME)
		queue_redraw()
		return true
	if game.tower_lab:
		var closest: Dictionary=game.nearest_road(destination)
		orient_rally(game.routes[closest.route],closest.progress)
	if game.tower_lab or game.defense_rules:
		for soldier: ArenaSoldier in troops: soldier.redeploy()
	rally_point=destination
	game.orders.rally_changed(self)
	game.effect(rally_point,25,Color("e9c37e"),"flag",0.5);return true

func orient_rally(road: Curve2D,progress: float) -> void:
	var ahead:=road.sample_baked(minf(road.get_baked_length(),progress+8.0),true)
	var behind:=road.sample_baked(maxf(0.0,progress-8.0),true)
	rally_across=behind.direction_to(ahead).orthogonal()

func rally_slot(slot: int) -> Vector2:
	return rally_point+rally_across*(float(slot)-1.0)*22.0

func ground_order_range() -> float:
	return float(data.reach) if kind=="barracks" and not game.tower_lab and not game.defense_rules else attack_range()

func order_preview(point: Vector2) -> Vector2:
	if project_level==1 or not point.is_finite(): return Vector2.INF
	if kind=="cannon":
		return point if Rect2(Vector2.ZERO,game.world_size()).has_point(point) and position.distance_to(point)<=attack_range() else Vector2.INF
	if kind not in ["barracks","snare"]: return Vector2.INF
	var nearby: Dictionary=game.nearest_road(point)
	if (game.tower_lab or kind=="snare") and point.distance_to(nearby.point)>ArenaTowerTrial.RALLY_CLICK_DISTANCE: return Vector2.INF
	if position.distance_to(nearby.point)>ground_order_range(): return Vector2.INF
	return nearby.point

func can_set_bombard() -> bool:
	return kind=="cannon" and (game.tower_lab or game.defense_rules)

func set_bombard(point: Vector2) -> bool:
	if not can_set_bombard() or destroyed or not game.can_manage_defense(): return false
	var preview:=order_preview(point)
	if not preview.is_finite(): return false
	if bombard_point.is_finite() and bombard_point.distance_squared_to(preview)<1.0: return true
	bombard_point=preview
	game.audio.play("tower",-18)
	queue_redraw()
	return true

func clear_bombard() -> void:
	if not can_set_bombard() or destroyed or not game.can_manage_defense(): return
	bombard_point=Vector2.INF
	queue_redraw()
	game.hud.refresh_context()
var fire_local := false
var support_camp: ArenaTower

func firing_position() -> Vector2:
	if game.phase=="rest" or game.orders.donor!=self or fire_local: return position
	var partner: ArenaTower=game.orders.receiver
	if is_instance_valid(partner) and not partner.destroyed: return partner.position
	return position if game.orders.has("alternate") else Vector2.INF

func destination_flag() -> Vector2:
	return support_camp.rally_point if is_instance_valid(support_camp) else rally_point

func windup_aim(enemy: ArenaEnemy,prep: float) -> Vector2:
	if not game.defense_rules or kind not in ["archer","cannon"]: return enemy.center()
	if bombard_point.is_finite(): return bombard_point
	var origin:=muzzle()
	var point:=enemy.center() if kind=="archer" else enemy.position
	var flight:=origin.distance_to(point)/trial_stat("speed") if kind=="archer" else 0.38
	var forecast:=point+enemy.travel_velocity()*(prep+flight)
	if kind=="cannon" and not order_preview(forecast).is_finite(): return point
	return forecast

func _physics_process(delta: float) -> void:
	if not game.running or game.game_over or destroyed:return
	if project_level!=0:
		project_clock=maxf(0.0,project_clock-delta)
		if project_clock<=0.0: finish_project()
		if project_level==1:
			queue_redraw()
			return
	attack_clock=maxf(0,attack_clock-delta);fire_clock=maxf(0,fire_clock-delta)
	if kind=="barracks":
		if not game.tower_lab and site_trait()=="choke":
			for soldier in troops:
				if is_instance_valid(soldier) and soldier.dead and soldier.respawn_clock>0.0:
					soldier.respawn_clock=maxf(0.0,soldier.respawn_clock-delta*0.25)
		if game.tower_lab and game.selected_site==site_id: queue_redraw()
		else: _sync_tower_draw()
		return
	if kind=="snare":
		if attack_clock<=0.0: try_snare()
		queue_redraw()
		return
	if kind=="lens" and (not is_instance_valid(focus_target) or not game.trial_tower_can_hit(focus_target) or position.distance_to(focus_target.position)>attack_range()):
		focus_target=null
		focus_layers=0
	if game.tower_lab:
		trial_attack(delta)
		return
	if timing.is_preparing():
		var cand: Node2D=timing.target
		var locked_aim: bool=game.defense_rules and kind in ["archer","cannon"]
		var valid: bool=is_instance_valid(cand) and not cand.dead and firing_position().is_finite() and (locked_aim or firing_position().distance_to(cand.position)<=attack_range()+18.0)
		if is_instance_valid(game.orders.marked) and cand!=game.orders.marked and not bombard_point.is_finite() and game.orders.marked.position.distance_to(firing_position())<=attack_range(): valid=false
		if valid and bombard_point.is_finite() and not locked_aim: valid=cand.position.distance_to(bombard_point)<=splash_radius()
		if not valid:
			cand=game.tower_target(self)
			if cand!=null:
				timing.target=cand;timing.target_point=windup_aim(cand,0.0)
				visual_target=muzzle().direction_to(timing.target_point)
			else:
				timing.cancel();attack_clock=0.06
				body.rotation=0.0;_sync_tower_draw();return
		elif not locked_aim:
			visual_target=(cand.center()-position).normalized()
		if timing.step(delta):
			var shot_target: Node2D=timing.target
			if is_instance_valid(shot_target) and not shot_target.dead:
				attack_clock=timing.post_cooldown
				_fire_at(shot_target)
			else:
				timing.cancel();attack_clock=0.06
	else:
		timing.step(delta)
		if attack_clock<=0:
			var enemy: Node2D=game.tower_target(self)
			if enemy!=null:
				var speed_link:=1.05 if game.hero.has_link("armament","command") and game.hero.command_aura(position)>0 else 1.0
				var cycle: float=reload_time()/speed_link
				var prep_s: float=minf(0.30,cycle*0.24) if kind=="cannon" else (minf(0.22,cycle*0.22) if kind=="mage" else minf(0.15,cycle*0.22))
				if game.defense_rules and kind=="archer": prep_s=minf(0.55,cycle*0.40)
				var rel_s: float=0.09 if kind=="cannon" else 0.07
				var rec_s: float=0.30 if kind=="cannon" else 0.16
				var aim:=windup_aim(enemy,prep_s)
				visual_target=muzzle().direction_to(aim)
				timing.begin(cycle,prep_s,rel_s,rec_s,enemy,aim)
	# The foundation stays planted. Firing feedback belongs at the articulated upper mechanism, not the base.
	body.rotation=0.0
	if game.defense_rules and kind in ["archer","cannon"]: queue_redraw()
	else: _sync_tower_draw()
func _fire_at(enemy: Node2D, bonus:=false) -> void:
	if not bonus and game.orders.borrowed_shot and self==game.orders.receiver:
		game.orders.borrowed_shot=false
		return
	if not bonus and self==game.orders.donor and not fire_local and game.phase!="rest" and game.orders.has("alternate"):
		if game.orders.borrowed_shot: return
		game.orders.borrowed_shot=true
	visual_target=(enemy.center()-muzzle()).normalized()
	var aura: float=game.hero.command_aura(position)
	var power: float=shot_power()
	if game.hero.mod("warcredit")>0:
		power*=1.0+0.05*float(game.hero.warcredit_stacks())
	if game.hero.mod("warmachine")>0:
		if enemy==streak_target: streak_count+=1
		else: streak_target=enemy;streak_count=1
		power*=1.0+warmachine_bonus()
	if game.hero.perk("armament")>0:
		shot_count+=1
		if shot_count>=armament_every(): shot_count=0;power*=1.5
	power*=1.0+aura
	power*=doctrine_multiplier(enemy)
	var aim:=timing.target_point if game.defense_rules and not bonus and timing.phase==AttackTiming.Phase.RELEASE else Vector2.INF
	match kind:
		"cannon": fire_cannon(enemy,power,aim)
		"storm": fire_chain(enemy,power)
		"lens": fire_lens(enemy,power)
		"mage":
			if game.defense_rules and doctrine_id!="breaker":
				if game.has_keystone("refract"): game.refract_tower_hit(self,enemy,power*(1.0 if firing_position().distance_to(enemy.position)<=trial_frost_inner() else ArenaTowerTrial.FROST_OUTER_POWER),penetration())
				fire_trial_pulse(power)
			else: fire_shots(enemy,power)
		_: fire_shots(enemy,power,aim)
	fire_clock=0.13;game.audio.play("tower",-16)
func trigger_bonus_salvo() -> bool:
	if destroyed or kind=="barracks" or project_level==1:return false
	if kind=="snare": return attack_clock<=0.0 and try_snare()
	if game.tower_lab:
		if kind=="mage": return fire_trial_pulse()
		var aim:=plan_trial_attack(0.0)
		if aim.is_empty(): return false
		fire_trial(aim.point)
		return true
	var enemy: Node2D
	var original_origin:=fire_local
	if self==game.orders.donor and game.phase!="rest":
		if not game.orders.has("alternate"): return false
		fire_local=true
		enemy=game.tower_target_from(self)
	else: enemy=game.tower_target(self)
	if enemy==null:
		fire_local=original_origin
		return false
	_fire_at(enemy,true)
	fire_local=original_origin
	return true

func trial_attack(delta: float) -> void:
	if kind=="mage":
		if attack_clock<=0.0 and fire_trial_pulse(): attack_clock=reload_time()
		_sync_tower_draw()
		return
	if timing.is_preparing():
		if timing.step(delta):
			attack_clock=timing.post_cooldown
			fire_trial(timing.target_point,true)
	else:
		timing.step(delta)
		if attack_clock<=0.0:
			var prep:=trial_stat("prep")*reload_time()/trial_stat("cycle")
			var aim:=plan_trial_attack(prep)
			if not aim.is_empty():
				var point: Vector2=aim.point
				visual_target=muzzle().direction_to(point)
				timing.begin(reload_time(),prep,0.06,trial_stat("recovery") if kind=="archer" else 0.30,aim.target,point)
	queue_redraw()

func plan_trial_attack(prep: float) -> Dictionary:
	var targets: Array[ArenaEnemy]=game.trial_tower_targets(self)
	var forecast: Array[Dictionary]=[]
	var origin:=muzzle()
	for enemy in targets:
		var point:=enemy.center() if kind=="archer" else enemy.position
		var flight:=origin.distance_to(point)/trial_stat("speed") if kind=="archer" else trial_stat("flight")
		forecast.append({"enemy":enemy,"point":point+enemy.travel_velocity()*(prep+flight)})
	if kind=="cannon" and bombard_point.is_finite():
		for row in forecast:
			if bombard_point.distance_squared_to(row.point)<=pow(trial_shell_core(),2.0):
				return {"point":bombard_point,"target":row.enemy}
		return {}
	var best: Dictionary={}
	var best_score:=-INF
	var best_priority:=-INF
	var best_remaining:=INF
	for candidate in forecast:
		var target: ArenaEnemy=candidate.enemy
		var point: Vector2=candidate.point
		if kind=="cannon" and not order_preview(point).is_finite(): continue
		var score:=line_coverage(origin,point,forecast) if kind=="archer" else blast_coverage(point,forecast)
		if score<=0.0: continue
		var priority:=target.health if kind=="archer" else 0.0
		var remaining: float=game.enemy_road(target).get_baked_length()-target.progress
		if score>best_score or (score==best_score and (priority>best_priority or (priority==best_priority and remaining<best_remaining))):
			best={"point":point,"target":target}
			best_score=score
			best_priority=priority
			best_remaining=remaining
	return best

func line_coverage(origin: Vector2,point: Vector2,forecast: Array[Dictionary]) -> float:
	var direction:=origin.direction_to(point)
	if direction.is_zero_approx(): return 0.0
	var count:=0
	var maximum:=5 if level==3 else 4
	var distance:=trial_arrow_range()
	for row in forecast:
		if is_inf(ArenaTowerTrial.arrow_contact(origin,direction,distance,row.point,row.enemy.radius+4.0)): continue
		count+=1
		if count==maximum: break
	return float(count)

func blast_coverage(point: Vector2,forecast: Array[Dictionary]) -> float:
	var score:=0.0
	var outer:=splash_radius()
	var center:=trial_shell_core()
	for row in forecast:
		var distance:=point.distance_to(row.point)
		if distance>outer: continue
		score+=lerpf(1.0,0.5,distance/outer)+(0.75 if distance<=center else 0.0)
	return score

func fire_trial(aim: Vector2,locked_ray:=false) -> void:
	var origin:=muzzle()
	var power:=shot_power()
	if kind=="archer":
		var direction:=visual_target if locked_ray else origin.direction_to(aim)
		game.fire_projectile(origin,origin+direction,power,ArenaCombat.Type.PHYSICAL,"tower",{
			"tower":self,"speed":trial_stat("speed"),"pen":penetration(),
			"trial_pierce_scales":ArenaTowerTrial.arrow_scales(level),"trial_flight_left":trial_arrow_range()})
		game.tower_trial_stats.arrows+=1
	else:
		var time:=trial_stat("flight")
		game.delayed_attack(aim,splash_radius(),power,ArenaCombat.Type.PHYSICAL,"tower",time,{
			"origin":origin,"cannon":true,"pen":penetration(),"stun":trial_stat("stun"),
			"tower_trial_shell":trial_stat("push"),"core_radius":trial_shell_core()})
	game.effect(origin,12,Color("e8c690"),"hit",0.15)
	fire_clock=0.13
	game.audio.play("tower",-16)

func focus_order_id() -> int:
	if not is_instance_valid(game.orders.marked) or bombard_point.is_finite(): return 0
	var marked: ArenaEnemy=game.orders.marked
	if marked.dead: return 0
	return marked.get_instance_id() if firing_position().distance_to(marked.position)<=attack_range() else 0

func fire_chain(first: ArenaEnemy,power: float) -> void:
	var current:=first
	var origin:=muzzle()
	var struck: Array[ArenaEnemy]=[]
	var reach:=doc_mod("chain_reach",105.0)
	var focused:=focus_order_id()!=0
	for hop in int(doc_mod("chain_count",3)):
		if current==null: break
		var end:=current.center()
		struck.append(current)
		game.effect(origin,origin.distance_to(end),data.colour,"tower_arc",0.20,origin.direction_to(end))
		current.last_tower=self
		current.take_hit(power,ArenaCombat.Type.MAGIC,"tower",0,0,penetration(),"arc",{"auto_tower":true})
		if focused: break
		origin=end
		power*=0.70
		current=null
		var nearest:=reach*reach
		for other: ArenaEnemy in game.enemies:
			if not game.trial_tower_can_hit(other) or other in struck: continue
			var distance:=end.distance_squared_to(other.center())
			if distance<nearest:
				current=other
				nearest=distance

func fire_lens(enemy: ArenaEnemy,power: float) -> void:
	focus_layers=mini(focus_layers+1,4) if enemy==focus_target else 0
	focus_target=enemy
	var origin:=muzzle()
	var end:=enemy.center()
	game.effect(origin,origin.distance_to(end),data.colour,"tower_beam",0.22,origin.direction_to(end))
	enemy.last_tower=self
	enemy.take_hit(power*(1.0+focus_layers*doc_mod("focus_step",0.35)),ArenaCombat.Type.MAGIC,"tower",0,0,penetration(),"beam",{"auto_tower":true})

func snare_radius() -> float:
	return (56.0+6.0*(level-1))*doc_mod("splash_mult",1.0)

func try_snare() -> bool:
	if position.distance_to(rally_point)>attack_range(): return false
	var nearby: Array[ArenaEnemy]=[]
	var radius:=snare_radius()
	var trigger:=false
	for enemy: ArenaEnemy in game.enemies:
		if not game.trial_tower_can_hit(enemy): continue
		var distance:=rally_point.distance_to(enemy.position)
		if distance<=radius:
			nearby.append(enemy)
			if distance<=radius*0.60: trigger=true
	if not trigger: return false
	attack_clock=reload_time()
	fire_clock=0.13
	var power: float=shot_power()*(1.0+game.hero.command_aura(position))
	for enemy in nearby:
		if not game.trial_tower_can_hit(enemy): continue
		enemy.last_tower=self
		enemy.take_hit(power*doctrine_multiplier(enemy),ArenaCombat.Type.PHYSICAL,"tower",0,0,penetration(),"snare")
		if not enemy.dead:
			if enemy.is_boss(): enemy.accept_tower_control(0.25)
			else: enemy.chill(0.25 if enemy.elite else 0.45,1.8)
	game.effect(rally_point,radius,data.colour,"snare_snap",0.35)
	game.audio.play("tower",-18)
	return true

func fire_trial_pulse(power: float=-1.0) -> bool:
	var targets: Array[ArenaEnemy]=game.trial_tower_targets(self)
	if targets.is_empty(): return false
	if power<0.0: power=shot_power()
	var origin:=firing_position()
	var inner:=trial_frost_inner()
	var focused:=focus_order_id()
	for enemy in targets:
		if focused!=0 and focused!=enemy.get_instance_id(): continue
		if not game.trial_tower_can_hit(enemy): continue
		var at_center:=origin.distance_squared_to(enemy.position)<=inner*inner
		enemy.last_tower=self
		enemy.take_hit(power*(1.0 if at_center else ArenaTowerTrial.FROST_OUTER_POWER),ArenaCombat.Type.MAGIC,"tower",0.0,0.0,penetration(),"tower_frost",{"auto_tower":true})
		if not enemy.dead and doctrine_id!="arcfire":
			if doctrine_id=="frost" and not enemy.is_boss(): enemy.chill(doc_mod("slow_amount"),doc_mod("slow_time"))
			enemy.tower_frost(doc_mod("freeze_time",trial_stat("freeze")),2 if at_center else 1,int(doc_mod("frost_stacks",ArenaTowerTrial.FROST_LIMIT)))
		game.tower_trial_stats.pulse_hits+=1
		if at_center: game.tower_trial_stats.inner_hits+=1
	game.tower_trial_stats.pulses+=1
	if doctrine_id=="arcfire": game.effect(origin,attack_range(),Color("ffa767"),"blast",0.42)
	else:
		game.effect(origin,attack_range(),Color("b6e5ef"),"tower_frost",0.52)
		game.effect(origin,inner,Color("d4f4ff"),"tower_frost_inner",0.52)
	fire_clock=0.13
	game.audio.play("tower",-12,1.14)
	return true
func fire_shots(enemy: Node2D,power: float,locked_aim:=Vector2.INF) -> void:
	var options: Dictionary={"target":enemy,"appearance":"magic" if kind=="mage" else "arrow","speed":760.0,"tower":self,"pen":penetration(),
		"bounce":1 if game.has_keystone("refract") else 0,"condition_hit":{"auto_tower":true},
		"mark":doc_mod("mark_time"),"mark_bonus":doc_mod("mark_bonus"),
		"slow_amount":doc_mod("slow_amount"),"slow_time":doc_mod("slow_time"),
		"freeze_stacks":int(doc_mod("frost_stacks")),"freeze_time":doc_mod("freeze_time")}
	if game.defense_rules and kind=="archer":
		options.trial_pierce_scales=ArenaTowerTrial.arrow_scales(level)
		options.trial_flight_left=maxf(attack_range()+80.0,trial_arrow_range())
		options.speed=trial_stat("speed")
	if game.defense_rules: options.condition_hit["focus_id"]=focus_order_id()
	var shots:=1
	if doc_mod("triple_chance")>0.0 and game.rng.randf()<doc_mod("triple_chance"):
		shots=4 if doctrine_id=="repeater" and branch_rank(0)>=3 else 3
	var origin:=muzzle()
	game.effect(origin,9 if kind=="mage" else 7,ArenaCombat.colour(int(data.type)),"magic_impact_painted" if kind=="mage" else "hit",0.13)
	ArenaBattleArt.emit_world_dust(origin,(enemy.center()-origin).normalized()*26.0,16.0 if kind=="mage" else 12.0,Color("b4ecff") if kind=="mage" else Color("e9d8b8"))
	for index in range(shots):
		var spread: float=(index-(shots-1)*0.5)*0.09
		var point: Vector2=enemy.center()
		if locked_aim.is_finite(): point=locked_aim
		elif game.defense_rules and kind=="archer": point+=enemy.travel_velocity()*origin.distance_to(point)/float(options.speed)
		var aim: Vector2=origin+(point-origin).rotated(spread)
		var shot_options: Dictionary=options.duplicate()
		if shots>1 and index!=int(shots/2):shot_options["target"]=null
		game.fire_projectile(origin,aim,power,int(data.type),"tower",shot_options)
func fire_cannon(enemy: Node2D,power: float,locked_aim:=Vector2.INF) -> void:
	var aim_pos: Vector2=enemy.position
	if bombard_point.is_finite():
		aim_pos=bombard_point
		visual_target=(aim_pos-muzzle()).normalized()
	elif locked_aim.is_finite(): aim_pos=locked_aim
	elif not enemy.is_guard and enemy.blocker==null and enemy.windup<=0 and enemy.melee_windup<=0 and enemy.stun<=0 and enemy.route_id>=0 and enemy.route_id<game.routes.size():
		var road: Curve2D=game.enemy_road(enemy)
		var slow_factor: float=(1.0-enemy.slow_amount) if enemy.slow>0 else 1.0
		var eff_speed: float=float(enemy.data.speed)*enemy.speed_scale()*slow_factor
		var predicted: float=clampf(enemy.progress+eff_speed*0.38,0.0,road.get_baked_length())
		aim_pos=road.sample_baked(predicted,true)
	var muz:=muzzle()
	game.effect(muz,16,Color("f2c176"),"hit",0.16)
	ArenaBattleArt.emit_world_dust(muz,visual_target*34.0+Vector2(0,-14.0),24.0,Color("c8b9a6"))
	ArenaBattleArt.emit_world_dust(muz+Vector2(-6,4),Vector2(-visual_target.x*16.0,-18.0),18.0,Color("a2988e"))
	var options: Dictionary={"origin":muzzle(),"cannon":true,
		"pen":penetration(),"knockback":doc_mod("knockback"),"condition_hit":{"auto_tower":not bombard_point.is_finite()},
		"burn_dps":doc_mod("burn_dps"),"burn_time":doc_mod("burn_time"),"burn_radius":doc_mod("burn_radius")}
	if game.defense_rules:
		options.merge({"core_radius":trial_shell_core(),"tower_trial_shell":trial_stat("push"),"stun":trial_stat("stun"),"tower":self,"focus_id":focus_order_id()})
	game.delayed_attack(aim_pos,splash_radius(),power,0,"tower",0.38,options)
func muzzle() -> Vector2:
	if ArenaBattleArt.TOWER_REGIONS.has(kind):
		var size:=body.texture.get_size()*body.scale
		var height:=0.74 if kind=="storm" else (0.76 if kind=="lens" else 0.60)
		return firing_position()+Vector2(size.x*(0.12 if kind=="lens" else 0.0),-size.y*height)
	var placement:=ArenaBattleArt.contact(kind,level,Vector2(512,512))
	var bounds: Array=ArenaBattleArt.tower_metadata[kind+str(level)].bounds
	var height: float=(480.0-float(bounds[1]))*placement.scale.y
	return firing_position()+Vector2(0,-height*(0.60 if kind=="mage" else 0.68))
func _draw() -> void:
	if project_level==1:
		draw_arc(Vector2(0,10),28.0,-PI*0.5,-PI*0.5+TAU*(1.0-project_clock/ArenaTowerTrial.BUILD_TIME),28,Color("e4c382"),2.0,true)
		return
	if (game.tower_lab or game.defense_rules) and kind=="archer" and timing.is_preparing():
		var origin:=muzzle()-position
		var end:=origin+visual_target*trial_arrow_range()
		draw_line(origin,end,Color(0.18,0.14,0.08,0.45),4.0,true)
		draw_line(origin,end,Color(0.95,0.84,0.59,0.24+timing.prep_progress()*0.40),1.5,true)
	if kind=="snare":
		var point:=rally_point-position
		var ink:=Color(data.colour,0.88 if attack_clock<=0.0 else 0.42)
		draw_arc(point,9,0.0,TAU,16,ink,1.6,true)
		draw_line(point+Vector2(-13,3),point+Vector2(12,-3),ink,2,true)
		if game.selected_site==site_id: draw_arc(point,snare_radius(),0.0,TAU,48,ink,1.4,true)
	if can_set_bombard():
		if (game.tower_lab or game.defense_rules) and timing.is_preparing(): draw_cannon_point(timing.target_point,0.32+0.37*timing.prep_progress())
		elif bombard_point.is_finite():
			if game.selected_site==site_id: draw_cannon_point(bombard_point,0.64)
			else: draw_arc(bombard_point-position,5.5,0.0,TAU,16,Color("f5cf91a6"),1.6,true)
	if game.selected_site==site_id:
		draw_arc(Vector2.ZERO,ground_order_range(),0,TAU,72,Color(data.colour,0.3),2,true)
		if (game.tower_lab or game.defense_rules) and kind=="mage" and doctrine_id!="breaker": draw_arc(Vector2.ZERO,trial_frost_inner(),0,TAU,58,Color("91cfdb96"),2.5,true)
		if game.tower_lab and kind=="barracks":
			for soldier: ArenaSoldier in troops:
				var point:=rally_slot(soldier.slot)-position
				var ink:=Color("efd49a") if soldier.can_block() else Color("efd49a66")
				draw_arc(point,5.0,0.0,TAU,14,ink,1.5,true)
	if awaiting_doctrine:
		# A small upgrade cue leaves the foundation visible instead of a floating halo.
		draw_polyline(PackedVector2Array([Vector2(-5,22),Vector2(0,17),Vector2(5,22)]),Color("e8c278"),2,true)
	if doctrine_id!="":
		for side in range(2):
			var rank: int=branch_ranks[side]
			for pip in range(3):
				var offset_x: float=(-25.0+pip*8.0) if side==0 else (9.0+pip*8.0)
				var curve_y: float=[26.0,28.5,29.5][pip] if side==0 else [29.5,28.5,26.0][pip]
				var dot:=Vector2(offset_x,curve_y)
				var tint:=Color("f5cd6a") if side==0 else Color("7fd8ff")
				draw_circle(dot,3.4,Color(0.11,0.13,0.16,0.72 if pip<rank else 0.36))
				draw_circle(dot,2.2,tint if pip<rank else Color(0.32,0.38,0.44,0.34))

func draw_cannon_point(point: Vector2,alpha: float) -> void:
	var center:=point-position
	var ink:=Color("f4c181")
	draw_arc(center,splash_radius(),0.0,TAU,48,Color(0.21,0.13,0.09,alpha*0.7),3.3,true)
	if game.tower_lab or game.defense_rules: draw_arc(center,trial_shell_core(),0.0,TAU,40,Color(0.21,0.13,0.09,alpha*0.82),4.6,true)
	draw_arc(center,splash_radius(),0.0,TAU,48,Color(ink,alpha*0.7),1.3,true)
	if game.tower_lab or game.defense_rules: draw_arc(center,trial_shell_core(),0.0,TAU,40,Color(ink,alpha),2.4,true)
	draw_line(center-Vector2(5,0),center+Vector2(5,0),Color(ink,alpha),1.4,true)
	draw_line(center-Vector2(0,5),center+Vector2(0,5),Color(ink,alpha),1.4,true)
func armament_every() -> int: return 4 if game.hero.has_link("command","armament") else 5
func warmachine_bonus() -> float: return 0.2*float(mini(2,int(streak_count/3)))

func draw_mechanism() -> void:
	var tint:=Color(data.colour)
	var cycle:=sin(visual_clock*3.0)
	var power:=clampf(fire_clock/0.13,0.0,1.0)
	match kind:
		"storm":
			moving_part.draw_arc(Vector2.ZERO,3.5+power*3.0,cycle,cycle+4.8,12,Color(tint,0.5+power*0.4),1.4,true)
		"lens":
			moving_part.draw_circle(Vector2.ZERO,2.0+float(focus_layers)*0.7,Color(tint,0.5+power*0.4))
		"snare":
			var axle:=Vector2.RIGHT.rotated(visual_clock*4.0 if attack_clock>0 else 0.0)
			moving_part.draw_line(-axle*3.5,axle*3.5,Color("e8bb7c"),1.5,true)

func _process(delta: float) -> void:
	if moving_part==null or not game.running or game.game_over:return
	visual_clock+=delta
	if ArenaBattleArt.TOWER_REGIONS.has(kind):
		if not game.campaign.data.reduced_motion or fire_clock>0.0: moving_part.queue_redraw()
		return
	var reduced:=bool(game.campaign.data.reduced_motion)
	var amp:=(0.35 if reduced else 1.0)*(1.0+0.12*float(level-1))
	var prep_p:=timing.prep_progress()
	var rel_p:=timing.release_progress()
	var rec_p:=timing.recover_progress()
	var aim_dir:=visual_target if visual_target.length()>0.1 else Vector2.RIGHT
	var recoil:=sin(clampf(fire_clock/0.13,0.0,1.0)*PI)
	match kind:
		"cannon":
			var windup_vec:=(-aim_dir*5.0+Vector2(0,2.5))*pow(prep_p,1.6)*amp
			var kick_vec:=Vector2.ZERO
			var rot_tilt:=-aim_dir.x*0.09*prep_p*amp
			if timing.phase==AttackTiming.Phase.RELEASE:
				kick_vec=aim_dir*3.2*(1.0-rel_p)*amp
				rot_tilt=aim_dir.x*0.06*(1.0-rel_p)*amp
			elif timing.phase==AttackTiming.Phase.RECOVER:
				var settle:=(1.0-rec_p)*cos(rec_p*PI*0.5)
				kick_vec=-aim_dir*7.5*settle*amp+Vector2(0,2.2*settle*amp)
				rot_tilt=-aim_dir.x*0.08*settle*amp
			elif recoil>0.01:
				kick_vec=-aim_dir*recoil*3.0*amp
			moving_part.position=windup_vec+kick_vec
			moving_part.rotation=rot_tilt
			moving_part.modulate=Color(1.0+0.25*prep_p*amp,1.0+0.18*prep_p*amp,1.0+0.05*prep_p*amp)
		"mage":
			var hover_y:=sin(visual_clock*1.8)*(0.3 if reduced else 1.2)
			var gather_y:=-6.8*pow(prep_p,1.4)*amp
			var jitter_x:=sin(visual_clock*28.0)*0.9*prep_p*amp
			var pulse_y:=0.0
			if timing.phase==AttackTiming.Phase.RELEASE:
				pulse_y=4.0*(1.0-rel_p)*amp
			elif timing.phase==AttackTiming.Phase.RECOVER:
				pulse_y=-2.5*(1.0-rec_p)*amp
			moving_part.position=Vector2(jitter_x,hover_y+gather_y+pulse_y-recoil)
			moving_part.rotation=0.0
			moving_part.modulate=Color(1.0+0.12*prep_p*amp,1.0+0.28*prep_p*amp,1.0+0.42*prep_p*amp)
		"archer":
			var draw_vec:=Vector2(-aim_dir.x*3.6,1.6)*pow(prep_p,1.5)*amp
			var snap_vec:=Vector2.ZERO
			var bow_tilt:=-aim_dir.x*0.075*prep_p*amp
			if timing.phase==AttackTiming.Phase.RELEASE:
				snap_vec=Vector2(aim_dir.x*2.8*(1.0-rel_p),-1.0*(1.0-rel_p))*amp
			elif timing.phase==AttackTiming.Phase.RECOVER:
				snap_vec=Vector2(-aim_dir.x*2.6*(1.0-rec_p),0.8*(1.0-rec_p))*amp
			elif recoil>0.01:
				snap_vec=Vector2(-aim_dir.x*recoil*1.3,-recoil*0.5)*amp
			moving_part.position=draw_vec+snap_vec
			moving_part.rotation=bow_tilt
			moving_part.modulate=Color(1.0+0.15*prep_p*amp,1.0+0.15*prep_p*amp,1.0+0.10*prep_p*amp)
		"barracks":
			var rally_pulse:=sin(clampf(fire_clock/0.28,0.0,1.0)*PI)*2.2*amp
			moving_part.position=Vector2(sin(visual_clock*2.4)*(0.2 if reduced else 0.8),-rally_pulse)
			moving_part.rotation=sin(visual_clock*2.1)*(0.01 if reduced else 0.035)
			moving_part.modulate=Color.WHITE
