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
var target_mode: String="first"
var troops: Array=[]
var body: Sprite2D
var moving_part: Sprite2D
var visual_clock:=0.0
var visual_target:=Vector2.RIGHT
var shot_count:=0
var streak_target: Node2D
var streak_count:=0
static var art_cache: Dictionary={}
func _ready() -> void:
	data=ArenaDefinitions.tower(kind);body=Sprite2D.new();body.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(body);refresh_art()
	var skin:=ArenaGrounding.material(game.level_id);body.material=skin;moving_part.material=skin
	var obstacle:=StaticBody2D.new();obstacle.collision_layer=1;obstacle.collision_mask=2
	var collision:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=25;collision.shape=circle;obstacle.add_child(collision);add_child(obstacle)
	var anchor: Vector2=game.nearest_road(position).point
	rally_point=anchor
	if kind=="barracks":
		sync_troops()
func refresh_art() -> void:
	var key: String=kind+str(level)
	if not art_cache.has(key):
		var path: String=ArenaBattleArt.towers_path()
		if ResourceLoader.exists(path):
			var atlas:=AtlasTexture.new();var sheet: Texture2D=load(path);atlas.atlas=sheet
			var column: int=ArenaDefinitions.TOWER_IDS.find(kind)
			atlas.region=Rect2(column*sheet.get_width()/4.0,(level-1)*sheet.get_height()/3.0,sheet.get_width()/4.0,sheet.get_height()/3.0)
			art_cache[key]=atlas
	if art_cache.has(key):
		body.texture=art_cache[key]
		var placement:=ArenaBattleArt.contact(kind,level,body.texture.get_size())
		body.scale=placement.scale;body.offset=(Vector2(0.5,0.5)-Vector2(placement.uv))*body.texture.get_size();body.position=Vector2.ZERO
		# Only a masked upper component moves. The feet/contact remain immobile.
		if moving_part==null:moving_part=Sprite2D.new();moving_part.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(moving_part)
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
	var base:=int(data.cost)*(level+1)/2+35
	return int(float(base)*(1.0-clampf(game.hero.mod("tower_upgrade"),0.0,0.5)))
func attack_range() -> float:
	var altar_range:=1.22 if (game.has_keystone("bastion_ward") and game.point_in_altar_aura(position)) else 1.0
	var trait_range:=1.18 if site_trait()=="highground" else 1.0
	return (float(data.reach)+(level-1)*16)*(1.0+game.hero.mod("tower_range"))*doc_mod("range_mult",1.0)*altar_range*trait_range
func reload_time() -> float:
	var overclock: float=game.altar_overclock_bonus(position) if game.has_method("altar_overclock_bonus") else 0.0
	var trait_speed: float=0.14 if site_trait()=="conduit" else 0.0
	return float(data.interval)/(1.0+0.14*(level-1))/(1.0+game.hero.mod("tower_speed"))*doc_mod("interval_mult",1.0)/(1.0+overclock)/(1.0+trait_speed)
func shot_power() -> float: return float(data.damage)*(1.0+0.6*(level-1))*game.support_scale(position)
func base_power() -> float: return float(data.damage)*(1.0+0.6*(level-1))
func splash_radius() -> float: return (64+(level-1)*12)*doc_mod("splash_mult",1.0)*(1.30 if game.has_keystone("refract") else 1.0)
func doc_mod(key: String,fallback := 0.0) -> float:
	var trait_bonus: float=0.18 if (key=="soldier_health" and kind=="barracks" and site_trait()=="choke") else 0.0
	if doctrine_data.is_empty():return fallback+trait_bonus
	var effects: Dictionary=doctrine_data.get("effects",{})
	var base: float=float(effects[key]) if effects.has(key) else fallback
	var b_list: Array=ArenaDoctrines.branches(doctrine_id)
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
	if destroyed or doctrine_id=="" or awaiting_doctrine:return false
	if index<0 or index>=branch_ranks.size():return false
	var rank:=branch_ranks[index]
	var branches:=ArenaDoctrines.branches(doctrine_id)
	if rank>=3 or index>=branches.size():return false
	var price:=branch_price(index)
	if game.gold<price:return false
	game.gold-=price
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
func upgrade(doctrine := "",use_token := false) -> bool:
	if level>=3 or destroyed:return false
	var token: bool=use_token and level==2 and int(game.doctrine_tokens)>0
	if not token and game.gold<upgrade_price():return false
	if token:game.doctrine_tokens-=1
	else:game.gold-=upgrade_price()
	level+=1;refresh_art()
	if level==3 and doctrine_id=="":
		var options: Array=ArenaDoctrines.for_tower(kind)
		if not options.is_empty():
			if doctrine!="" and _apply_doctrine(doctrine):awaiting_doctrine=false
			else:awaiting_doctrine=true;game.pending_doctrine_site=site_id
	for soldier in troops:
		if is_instance_valid(soldier):soldier.refresh_stats()
	game.effect(position,65,Color("f4d28b"),"upgrade",0.55);game.audio.play("tower")
	if is_instance_valid(game.hud):game.hud.refresh_context();game.hud.refresh_tokens()
	return true
func choose_doctrine(id: String) -> bool:
	if not awaiting_doctrine or destroyed:return false
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
		var soldier:=ArenaSoldier.new();soldier.game=game;soldier.tower=self;soldier.position=rally_point
		game.actors.add_child(soldier);game.soldiers.append(soldier);troops.append(soldier)
	for index in range(troops.size()):troops[index].slot=index
	for soldier in troops:soldier.refresh_stats()
func sell() -> bool:
	if destroyed:return false
	var spent_branches:=0
	for rank in branch_ranks:
		for step_i in range(rank):spent_branches+=ArenaDoctrines.branch_price(step_i)
	destroyed=true;game.gold+=int((float(data.cost)*0.6+float(level-1)*data.cost*0.25+float(spent_branches)*0.6)*(1.0+game.hero.mod("sell_bonus")))
	for soldier in troops:
		if is_instance_valid(soldier):game.blocking.release(soldier);game.soldiers.erase(soldier);soldier.queue_free()
	game.towers.erase(self);game.rebuild_navigation();queue_free();game.hud.close_context();return true
func set_rally(point: Vector2) -> bool:
	if kind!="barracks" or destroyed:return false
	var closest: Dictionary=game.nearest_road(point)
	if position.distance_to(closest.point)>145:return false
	rally_point=closest.point;game.effect(rally_point,25,Color("e9c37e"),"flag",0.5);return true
func _physics_process(delta: float) -> void:
	if not game.running or game.game_over or destroyed:return
	attack_clock=maxf(0,attack_clock-delta);fire_clock=maxf(0,fire_clock-delta)
	if kind=="barracks":
		if site_trait()=="choke":
			for soldier in troops:
				if is_instance_valid(soldier) and soldier.dead and soldier.respawn_clock>0.0:
					soldier.respawn_clock=maxf(0.0,soldier.respawn_clock-delta*0.25)
		_sync_tower_draw()
		return
	if timing.is_preparing():
		var cand: Node2D=timing.target
		var valid: bool=is_instance_valid(cand) and not cand.dead and position.distance_to(cand.position)<=attack_range()+18.0
		if not valid:
			cand=game.tower_target(self)
			if cand!=null:
				timing.target=cand;timing.target_point=cand.center()
				visual_target=(cand.center()-position).normalized()
			else:
				timing.cancel();attack_clock=0.06
				body.rotation=0.0;_sync_tower_draw();return
		else:
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
				var rel_s: float=0.09 if kind=="cannon" else 0.07
				var rec_s: float=0.30 if kind=="cannon" else 0.16
				visual_target=(enemy.center()-position).normalized()
				timing.begin(cycle,prep_s,rel_s,rec_s,enemy,enemy.center())
	# The foundation stays planted. Firing feedback belongs at the articulated upper mechanism, not the base.
	body.rotation=0.0
	_sync_tower_draw()
func _fire_at(enemy: Node2D) -> void:
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
	if kind=="cannon":fire_cannon(enemy,power)
	else:fire_shots(enemy,power)
	fire_clock=0.13;game.audio.play("tower",-16)
func trigger_bonus_salvo() -> bool:
	if destroyed or kind=="barracks":return false
	var enemy: Node2D=game.tower_target(self)
	if enemy==null:return false
	_fire_at(enemy)
	return true
func fire_shots(enemy: Node2D,power: float) -> void:
	var options: Dictionary={"target":enemy,"appearance":"magic" if kind=="mage" else "arrow","speed":760.0,"tower":self,"pen":penetration(),
		"bounce":1 if game.has_keystone("refract") else 0,
		"mark":doc_mod("mark_time"),"mark_bonus":doc_mod("mark_bonus"),
		"slow_amount":doc_mod("slow_amount"),"slow_time":doc_mod("slow_time"),
		"freeze_stacks":int(doc_mod("frost_stacks")),"freeze_time":doc_mod("freeze_time")}
	var shots:=1
	if doc_mod("triple_chance")>0.0 and game.rng.randf()<doc_mod("triple_chance"):
		shots=4 if doctrine_id=="repeater" and branch_rank(0)>=3 else 3
	var origin:=muzzle()
	game.effect(origin,9 if kind=="mage" else 7,ArenaCombat.colour(int(data.type)),"magic_impact_painted" if kind=="mage" else "hit",0.13)
	ArenaBattleArt.emit_world_dust(origin,(enemy.center()-origin).normalized()*26.0,16.0 if kind=="mage" else 12.0,Color("b4ecff") if kind=="mage" else Color("e9d8b8"))
	for index in range(shots):
		var spread: float=(index-(shots-1)*0.5)*0.09
		var aim: Vector2=origin+(enemy.center()-origin).rotated(spread)
		var shot_options: Dictionary=options.duplicate()
		if shots>1 and index!=int(shots/2):shot_options["target"]=null
		game.fire_projectile(origin,aim,power,int(data.type),"tower",shot_options)
func fire_cannon(enemy: Node2D,power: float) -> void:
	var aim_pos: Vector2=enemy.position
	if not enemy.is_guard and enemy.blocker==null and enemy.windup<=0 and enemy.melee_windup<=0 and enemy.stun<=0 and enemy.route_id>=0 and enemy.route_id<game.routes.size():
		var road: Curve2D=game.enemy_road(enemy)
		var slow_factor: float=(1.0-enemy.slow_amount) if enemy.slow>0 else 1.0
		var eff_speed: float=float(enemy.data.speed)*enemy.speed_scale()*slow_factor
		var predicted: float=clampf(enemy.progress+eff_speed*0.38,0.0,road.get_baked_length())
		aim_pos=road.sample_baked(predicted,true)
	var muz:=muzzle()
	game.effect(muz,16,Color("f2c176"),"hit",0.16)
	ArenaBattleArt.emit_world_dust(muz,visual_target*34.0+Vector2(0,-14.0),24.0,Color("c8b9a6"))
	ArenaBattleArt.emit_world_dust(muz+Vector2(-6,4),Vector2(-visual_target.x*16.0,-18.0),18.0,Color("a2988e"))
	game.delayed_attack(aim_pos,splash_radius(),power,0,"tower",0.38,{"origin":muzzle(),"cannon":true,
		"pen":penetration(),"knockback":doc_mod("knockback"),
		"burn_dps":doc_mod("burn_dps"),"burn_time":doc_mod("burn_time"),"burn_radius":doc_mod("burn_radius")})
func muzzle() -> Vector2:
	var placement:=ArenaBattleArt.contact(kind,level,Vector2(512,512))
	var bounds: Array=ArenaBattleArt.tower_metadata[kind+str(level)].bounds
	var height: float=(480.0-float(bounds[1]))*placement.scale.y
	return position+Vector2(0,-height*(0.60 if kind=="mage" else 0.68))
func _draw() -> void:
	if game.selected_site==site_id:
		draw_arc(Vector2.ZERO,attack_range(),0,TAU,72,Color(data.colour,0.3),2,true)
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
func armament_every() -> int: return 4 if game.hero.has_link("command","armament") else 5
func warmachine_bonus() -> float: return 0.2*float(mini(2,int(streak_count/3)))

func _process(delta: float) -> void:
	if moving_part==null or not game.running or game.game_over:return
	visual_clock+=delta
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
