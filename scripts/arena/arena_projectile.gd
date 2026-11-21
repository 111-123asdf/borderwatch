class_name ArenaProjectile
extends Node2D
var game: Node2D
var direction:=Vector2.RIGHT
var speed:=590.0
var damage:=20.0
var damage_type:=0
var source: String="hero"
var appearance: String="arrow"
var radius:=4.0
var life:=2.5
var pierce:=0
var expose:=false
var splash:=0.0
var burn:=0.0
var pen:=0.0
var mark:=0.0
var mark_bonus:=0.0
var slow_amount:=0.0
var slow_time:=0.0
var freeze_stacks:=0
var freeze_time:=0.0
var knockback:=0.0
var tower: Node2D
var target: Node2D
var bounce:=0
var hit_ids: Dictionary={}
var trail: Array[Vector2]=[]
var presentation: String=""
var feedback_tag: String="attack"
var condition_hit: Dictionary={}
var trial_pierce_scales: Array[float]=[]
var trial_flight_left:=0.0
func _physics_process(delta: float) -> void:
	if not game.running or game.game_over:return
	if not trial_pierce_scales.is_empty():
		advance_trial_arrow(delta)
		return
	life-=delta
	if life<=0:queue_free();return
	var old:=position
	var step:=speed*delta
	if source!="enemy" and is_instance_valid(target) and not target.dead and not hit_ids.has(target.get_instance_id()) and (pierce<=0 or hit_ids.is_empty()):
		var aim_vec: Vector2=target.center()-position
		var dist: float=aim_vec.length()
		if dist>0.001:direction=aim_vec/dist
		if pierce<=0 and dist<=step:step=dist
	position+=direction*step
	trail.append(position)
	if trail.size()>5:trail.pop_front()
	if source=="enemy":
		if not game.hero.knocked_out and Geometry2D.get_closest_point_to_segment(game.hero.center(),old,position).distance_to(game.hero.center())<14:
			game.hero.take_hit(damage,damage_type);queue_free();return
	else:
		var focused:=int(condition_hit.get("focus_id",0))
		var low:=Vector2(minf(old.x,position.x),minf(old.y,position.y))
		var high:=Vector2(maxf(old.x,position.x),maxf(old.y,position.y))
		for enemy in game.projectile_candidates():
			if not is_instance_valid(enemy) or enemy.dead or hit_ids.has(enemy.get_instance_id()):continue
			if focused!=0 and enemy.get_instance_id()!=focused: continue
			var center: Vector2=enemy.center();var reach: float=enemy.radius+5
			if center.x<low.x-reach or center.x>high.x+reach or center.y<low.y-reach or center.y>high.y+reach:continue
			if Geometry2D.get_closest_point_to_segment(center,old,position).distance_squared_to(center)>reach*reach:continue
			hit_ids[enemy.get_instance_id()]=true
			if is_instance_valid(tower) and not enemy.dead:enemy.last_tower=tower
			if splash>0:game.area_damage(enemy.position,splash,damage,damage_type,source,0.0,0.0,pen,knockback,feedback_tag,condition_hit)
			else:enemy.take_hit(damage,damage_type,source,0.0,0.0,pen,feedback_tag,condition_hit)
			if is_instance_valid(enemy) and not enemy.dead:
				if mark>0:enemy.apply_mark(mark,mark_bonus)
				if freeze_stacks>0:enemy.frost_hit(slow_amount,slow_time,freeze_stacks,freeze_time)
				elif slow_amount>0:enemy.chill(slow_amount,slow_time)
				if knockback>0 and splash<=0:enemy.push_back(knockback)
			if pierce>0 and source=="hero": game.hero.note_pierce_hit()
			if burn>0:enemy.ignite(burn,3.0)
			if expose and is_instance_valid(enemy) and not enemy.dead:enemy.exposure=2.0
			if bounce>0 and splash<=0 and focused==0:
				var next_target: Node2D=game.nearest_unhit_enemy(position,210.0,hit_ids) if game.has_method("nearest_unhit_enemy") else null
				if next_target!=null:
					bounce-=1;damage*=0.65;pen=clampf(pen+0.25,0.0,0.85);target=next_target;direction=(next_target.center()-position).normalized();life=maxf(life,1.0);game.effect(position,14,Color("b8f08a"),"hit",0.15);continue
			if pierce<=0:queue_free();return
			pierce-=1
	queue_redraw()

func advance_trial_arrow(delta: float) -> void:
	var distance:=minf(trial_flight_left,speed*delta)
	var origin:=position
	position+=direction*distance
	trial_flight_left-=distance
	trail.append(position)
	if trail.size()>5: trail.pop_front()
	var hits: Array[Dictionary]=[]
	for candidate in game.projectile_candidates():
		if not game.trial_tower_can_hit(candidate) or hit_ids.has(candidate.get_instance_id()): continue
		var enemy: ArenaEnemy=candidate
		var focused:=int(condition_hit.get("focus_id",0))
		if focused!=0 and enemy.get_instance_id()!=focused: continue
		var entry:=ArenaTowerTrial.arrow_contact(origin,direction,distance,enemy.center(),enemy.radius+radius)
		if not is_inf(entry): hits.append({"enemy":enemy,"entry":entry})
	hits.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.entry<b.entry)
	for hit in hits:
		var enemy: ArenaEnemy=hit.enemy
		if not game.trial_tower_can_hit(enemy): continue
		var scale_index:=hit_ids.size()
		hit_ids[enemy.get_instance_id()]=true
		if is_instance_valid(tower): enemy.last_tower=tower
		enemy.take_hit(damage*trial_pierce_scales[scale_index],damage_type,source,0.0,0.0,pen,"pierce_arrow",condition_hit)
		if bounce>0 and is_instance_valid(tower) and int(condition_hit.get("focus_id",0))==0:
			bounce=0
			game.refract_tower_hit(tower,enemy,damage,pen)
		game.tower_trial_stats.arrow_hits+=1
		if not enemy.dead:
			enemy.tower_weakness_clock=ArenaTowerTrial.WEAKNESS_TIME
			if mark>0: enemy.apply_mark(mark,mark_bonus)
		if hit_ids.size()==trial_pierce_scales.size():
			queue_free()
			return
	if trial_flight_left<=0.0: queue_free()
	else: queue_redraw()

func _draw() -> void:
	var colour:=Color("ff645a") if source=="enemy" else ArenaCombat.colour(damage_type)
	if source=="hero" and presentation in ["ranger","mage"] and game.feel.enabled:
		var arcane:=damage_type==1
		var tint:=Color("bda5fa") if arcane else (Color("c5e59d") if feedback_tag=="pierce_arrow" else Color("f7d895"))
		for index in range(1,trail.size()):draw_line(trail[index-1]-position,trail[index]-position,Color(tint,float(index)/trail.size()*0.48),3 if arcane else 2,true)
		draw_set_transform(Vector2.ZERO,direction.angle())
		var texture:=ArenaHeroVFX.frame("mage" if arcane else "ranger",0,int(life*12)%4 if arcane else (1 if feedback_tag=="pierce_arrow" else 0))
		if texture!=null:
			var dimensions:=Vector2(26,26) if arcane else Vector2(42,16)
			draw_texture_rect(texture,Rect2(-dimensions*0.5,dimensions),false)
		return
	for index in range(1,trail.size()):
		var t_alpha:=float(index)/float(trail.size())
		draw_line(trail[index-1]-position,trail[index]-position,Color(0.08,0.06,0.10,t_alpha*0.42),4.0,true)
		draw_line(trail[index-1]-position,trail[index]-position,Color(colour,t_alpha*0.62),2.2,true)
	draw_set_transform(Vector2.ZERO,direction.angle())
	if appearance in ["arrow","spear"]:
		draw_line(Vector2(-15,0),Vector2(6,0),Color("1a1412"),5.0)
		draw_line(Vector2(-14,0),Vector2(4,0),Color("8b613c"),2.8)
		draw_colored_polygon(PackedVector2Array([Vector2(11,0),Vector2(2,-4),Vector2(2,4)]),Color("1a1412"))
		draw_colored_polygon(PackedVector2Array([Vector2(10,0),Vector2(3,-2.8),Vector2(3,2.8)]),colour)
		draw_line(Vector2(-13,-3.5),Vector2(-7,0),Color("f7e4b4"),1.8)
	else:
		var outer_col:=Color("220d12") if source=="enemy" else Color("1d1626")
		draw_circle(Vector2.ZERO,8.2,outer_col)
		draw_circle(Vector2.ZERO,5.6,colour)
		draw_circle(Vector2(-1.2,-1.2),2.3,Color("fff6da"))
