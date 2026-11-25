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
var tower_kind: String=""
var tower_level:=1
var doctrine_id: String=""
var debuffs: Array=[]
var condition_hit: Dictionary={}
var trial_pierce_scales: Array[float]=[]
var trial_flight_left:=0.0
var arc_height:=0.0
var arc_origin:=Vector2.ZERO
var arc_total_dist:=1.0
var arc_traveled:=0.0
var visual_trail: Array[Vector2]=[]
var visual_offset:=Vector2.ZERO
var draw_dir:=Vector2.RIGHT
var stagger_on_hit:=0.0
var domain: String="defense"
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
	arc_traveled+=step
	if arc_height>0.5:
		if is_instance_valid(target) and not target.dead and pierce<=0:
			arc_total_dist=maxf(arc_total_dist,arc_traveled+position.distance_to(target.center()))
		var u:=clampf(arc_traveled/maxf(1.0,arc_total_dist),0.0,1.0)
		visual_offset=Vector2(0.0,-4.0*u*(1.0-u)*arc_height)
		var dy_du:=-4.0*(1.0-2.0*u)*arc_height
		var vel_vis:=direction*speed+Vector2(0.0,dy_du*(speed/maxf(1.0,arc_total_dist)))
		draw_dir=vel_vis.normalized() if vel_vis.length_squared()>0.001 else direction
	else:
		visual_offset=Vector2.ZERO
		draw_dir=direction
	trail.append(position)
	if trail.size()>5:trail.pop_front()
	visual_trail.append(position+visual_offset)
	if visual_trail.size()>6:visual_trail.pop_front()
	if source=="enemy":
		if game.hero.domain==domain and not game.hero.knocked_out and not hit_ids.has(game.hero.get_instance_id()) and Geometry2D.get_closest_point_to_segment(game.hero.center(),old,position).distance_to(game.hero.center())<14:
			if game.hero.is_perfect_dodge_active():
				hit_ids[game.hero.get_instance_id()]=true
				game.hero.trigger_perfect_dodge(null,direction)
			elif game.hero.protection>0.0:
				hit_ids[game.hero.get_instance_id()]=true
			else:
				game.hero.take_hit(damage,damage_type,false,direction)
				if not debuffs.is_empty():
					for db in debuffs:
						if db is Dictionary:
							game.hero.apply_debuff(str(db.get("kind","")), float(db.get("duration",0.0)), float(db.get("strength",0.0)))
				queue_free();return
		if game.hero.domain==domain:
			for beast in game.hero.companions:
				if is_instance_valid(beast) and beast.visible and beast.health>0 and Geometry2D.get_closest_point_to_segment(beast.center(),old,position).distance_squared_to(beast.center())<196.0:
					beast.take_hit(damage,damage_type)
					queue_free()
					return
	else:
		var focused:=int(condition_hit.get("focus_id",0))
		if domain == "rift" and game != null and game.rift_domain != null and source == "hero":
			if game.rift_domain.damage_barrels_in_radius(position, maxf(18.0, splash * 0.6), damage, domain) > 0:
				game.effect(position, 18.0, Color("7cf4ff"), "hit", 0.14)
				if pierce <= 0:
					queue_free()
					return
				pierce -= 1
		var low:=Vector2(minf(old.x,position.x),minf(old.y,position.y))
		var high:=Vector2(maxf(old.x,position.x),maxf(old.y,position.y))
		for enemy in game.projectile_candidates():
			if not is_instance_valid(enemy) or enemy.dead or enemy.domain!=domain or hit_ids.has(enemy.get_instance_id()):continue
			if focused!=0 and enemy.get_instance_id()!=focused: continue
			var center: Vector2=enemy.center();var reach: float=enemy.radius+5
			if center.x<low.x-reach or center.x>high.x+reach or center.y<low.y-reach or center.y>high.y+reach:continue
			if Geometry2D.get_closest_point_to_segment(center,old,position).distance_squared_to(center)>reach*reach:continue
			hit_ids[enemy.get_instance_id()]=true
			if is_instance_valid(tower) and not enemy.dead:enemy.last_tower=tower
			var contact:=Geometry2D.get_closest_point_to_segment(center,old,position)
			if splash>0:
				var splash_opts := condition_hit.duplicate()
				splash_opts["domain"] = domain
				game.area_damage(enemy.position,splash,damage,damage_type,source,stagger_on_hit,0.0,pen,knockback,feedback_tag,true,splash_opts)
			else:
				# The sweep can hit a different enemy before the selected target.
				enemy.take_hit(damage,damage_type,source,stagger_on_hit,0.0,pen,feedback_tag,direction,contact,condition_hit)
			if feedback_tag=="tower_spell":
				var fx_pos: Vector2=enemy.position if is_instance_valid(enemy) else contact
				if doctrine_id=="arcfire":
					game.effect(fx_pos,44.0,Color("ff8c38"),"tower_arcfire",0.28)
				elif doctrine_id=="frost":
					game.effect(fx_pos,44.0,Color("84e4ff"),"tower_frost_inner",0.28)
				else:
					var sp_col:=Color("c884ff") if doctrine_id=="breaker" else Color("7ce6ff")
					game.effect(contact,26.0,sp_col,"magic_impact_painted",0.22,direction)
			if is_instance_valid(enemy) and not enemy.dead:
				if mark>0:enemy.apply_mark(mark,mark_bonus)
				if freeze_stacks>0:enemy.frost_hit(slow_amount,slow_time,freeze_stacks,freeze_time)
				elif slow_amount>0:enemy.chill(slow_amount,slow_time)
				if knockback>0 and splash<=0:enemy.push_back(knockback)
			if burn>0:enemy.ignite(burn,3.0)
			if expose and is_instance_valid(enemy) and not enemy.dead:enemy.exposure=2.0
			if bounce>0 and splash<=0 and focused==0:
				var next_target: Node2D=game.nearest_unhit_enemy(position,210.0,hit_ids,domain) if game.has_method("nearest_unhit_enemy") else null
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
		enemy.take_hit(damage*trial_pierce_scales[scale_index],damage_type,source,0.0,0.0,pen,"pierce_arrow",direction,Vector2.INF,condition_hit)
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
	if source=="enemy" and appearance=="viper_arrow":
		for index in range(1,trail.size()):
			var u := float(index)/float(trail.size())
			draw_line(trail[index-1]-position,trail[index]-position,Color(0.28,0.95,0.45,u*0.70),1.6+u*3.0,true)
		draw_set_transform(Vector2.ZERO,direction.angle())
		draw_line(Vector2(-18,0),Vector2(8,0),Color("122a16"),5.2,true)
		draw_line(Vector2(-17,0),Vector2(6,0),Color("54e86c"),2.6,true)
		draw_colored_polygon(PackedVector2Array([Vector2(14,0),Vector2(3,-4.5),Vector2(3,4.5)]),Color("122a16"))
		draw_colored_polygon(PackedVector2Array([Vector2(13,0),Vector2(4,-3.0),Vector2(4,3.0)]),Color("a4ff8a"))
		draw_line(Vector2(-15,-4.0),Vector2(-9,0),Color("7cf496"),2.0,true)
		draw_line(Vector2(-15,4.0),Vector2(-9,0),Color("7cf496"),2.0,true)
		return
	if source=="enemy" and appearance=="feather_dart":
		for index in range(1,trail.size()):
			var u := float(index)/float(trail.size())
			draw_line(trail[index-1]-position,trail[index]-position,Color(0.86,0.72,0.52,u*0.48),1.2+u*2.0,true)
		draw_set_transform(Vector2.ZERO,direction.angle())
		draw_colored_polygon(PackedVector2Array([Vector2(11,0),Vector2(-3,-3.8),Vector2(-12,0),Vector2(-3,3.8)]),Color("3b291e"))
		draw_colored_polygon(PackedVector2Array([Vector2(10,0),Vector2(-1,-2.2),Vector2(-9,0),Vector2(-1,2.2)]),Color("ebd2a6"))
		return
	if source=="enemy" and appearance=="boulder":
		for index in range(1,trail.size()):
			var u := float(index)/float(trail.size())
			draw_line(trail[index-1]-position,trail[index]-position,Color(0.62,0.52,0.42,u*0.50),3.0+u*5.0,true)
		draw_set_transform(Vector2.ZERO,life*9.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-9,-6),Vector2(2,-10),Vector2(10,-3),Vector2(8,7),Vector2(-4,9),Vector2(-10,2)]),Color("3a2f28"))
		draw_colored_polygon(PackedVector2Array([Vector2(-7,-4),Vector2(1,-7),Vector2(7,-2),Vector2(6,5),Vector2(-3,6),Vector2(-7,1)]),Color("8f7b68"))
		draw_colored_polygon(PackedVector2Array([Vector2(-4,-4),Vector2(2,-5),Vector2(4,-1),Vector2(-2,1)]),Color("bfa890"))
		return
	if source=="enemy" and appearance=="magic":
		draw_set_transform(Vector2.ZERO,direction.angle())
		draw_colored_polygon(PackedVector2Array([Vector2(10,0),Vector2(0,-6),Vector2(-16,-3),Vector2(-9,1),Vector2(-14,5),Vector2(0,6)]),Color("5d3449"))
		draw_colored_polygon(PackedVector2Array([Vector2(8,0),Vector2(-1,-4),Vector2(-8,0),Vector2(-1,4)]),Color("f38975"))
		draw_line(Vector2(-4,0),Vector2(5,0),Color("ffddbd"),1.8,true)
		return
	if feedback_tag=="tower_arrow" or not trial_pierce_scales.is_empty():
		var is_pierce := not trial_pierce_scales.is_empty()
		var active_dir := draw_dir if arc_traveled > 0.0 else direction
		var has_arc := arc_height > 0.5
		var active_trail: Array[Vector2] = visual_trail if (has_arc and visual_trail.size() > 1) else trail
		var trail_col := Color("ffe675") if doctrine_id=="sentinel" else (Color("8cf0ff") if doctrine_id=="repeater" else (Color("ff7a30") if doctrine_id=="piercer" else (Color("f2b858") if doctrine_id=="hunter" else Color("f6d478"))))
		if has_arc:
			draw_set_transform(Vector2(0.0,12.0),0.0,Vector2(1.0,0.42))
			draw_circle(Vector2.ZERO,5.2,Color(0.06,0.05,0.07,0.28))
			draw_set_transform(Vector2.ZERO)
		if active_trail.size()>1:
			for index in range(1,active_trail.size()):
				var u := float(index)/float(active_trail.size())
				var w_t := (2.2 if is_pierce or doctrine_id in ["sentinel","piercer"] else 1.4) + u * (3.2 if doctrine_id=="piercer" else 2.2)
				draw_line(active_trail[index-1]-position,active_trail[index]-position,Color(trail_col.r,trail_col.g,trail_col.b,u*0.62),w_t,false)
		draw_set_transform(visual_offset,active_dir.angle())
		if is_pierce or doctrine_id in ["sentinel","piercer"]:
			for side: float in [-1.0,1.0]:
				draw_line(Vector2(-24.0,side*3.5),Vector2(-4.0,side*2.2),Color(1.0,0.98,0.85,0.45),1.2,false)
		if doctrine_id=="sentinel":
			draw_line(Vector2(-22,0),Vector2(14,0),Color("14111b"),5.2,false)
			draw_line(Vector2(-21,0),Vector2(12,0),Color("ffe066"),2.4,false)
			draw_colored_polygon(PackedVector2Array([Vector2(19,0),Vector2(8,-4.5),Vector2(11,0),Vector2(8,4.5)]),Color("14111b"))
			draw_colored_polygon(PackedVector2Array([Vector2(18,0),Vector2(9,-3.2),Vector2(12,0),Vector2(9,3.2)]),Color("fff9c8"))
			for side: float in [-1.0,1.0]:
				draw_line(Vector2(-20,side*4.0),Vector2(-13,0),Color("ffe882"),2.0,false)
		elif doctrine_id=="repeater":
			draw_line(Vector2(-12,0),Vector2(8,0),Color("14111b"),4.2,false)
			draw_line(Vector2(-11,0),Vector2(7,0),Color("a8d8ec"),2.0,false)
			draw_colored_polygon(PackedVector2Array([Vector2(14,0),Vector2(4,-3.8),Vector2(4,3.8)]),Color("14111b"))
			draw_colored_polygon(PackedVector2Array([Vector2(13,0),Vector2(5,-2.4),Vector2(5,2.4)]),Color("eef8ff"))
			draw_line(Vector2(-11,-3),Vector2(-6,0),Color("b4e8ff"),1.6,false)
			draw_line(Vector2(-11,3),Vector2(-6,0),Color("b4e8ff"),1.6,false)
		elif doctrine_id=="piercer":
			draw_line(Vector2(-22,0),Vector2(12,0),Color("14111b"),6.2,false)
			draw_line(Vector2(-21,0),Vector2(11,0),Color("6c6874"),3.2,false)
			draw_colored_polygon(PackedVector2Array([Vector2(20,0),Vector2(5,-5.5),Vector2(7,0),Vector2(5,5.5)]),Color("14111b"))
			draw_colored_polygon(PackedVector2Array([Vector2(18,0),Vector2(6,-4.0),Vector2(8,0),Vector2(6,4.0)]),Color("ff7a28"))
			draw_colored_polygon(PackedVector2Array([Vector2(16,0),Vector2(9,-2.0),Vector2(9,2.0)]),Color("fff4b0"))
			draw_line(Vector2(-20,-4),Vector2(-13,0),Color("ff9838"),2.0,false)
			draw_line(Vector2(-20,4),Vector2(-13,0),Color("ff9838"),2.0,false)
		else:
			draw_line(Vector2(-16,0),Vector2(10,0),Color("14111b"),4.6,false)
			draw_line(Vector2(-15,0),Vector2(8,0),Color("c68c48" if doctrine_id!="hunter" else "d89c42"),2.2,false)
			draw_colored_polygon(PackedVector2Array([Vector2(16,0),Vector2(5,-4.4),Vector2(7,0),Vector2(5,4.4)]),Color("14111b"))
			draw_colored_polygon(PackedVector2Array([Vector2(15,0),Vector2(6,-3.0),Vector2(8,0),Vector2(6,3.0)]),Color("f4fbff" if not is_pierce else "ffe9a2"))
			draw_line(Vector2(-15,-3.2),Vector2(-8,0),Color("fff5d6"),1.8,false)
			draw_line(Vector2(-15,3.2),Vector2(-8,0),Color("fff5d6"),1.8,false)
		draw_set_transform(Vector2.ZERO)
		return
	if feedback_tag=="tower_spell":
		var is_arc := doctrine_id == "arcfire"
		var is_break := doctrine_id == "breaker"
		var active_dir := draw_dir if arc_traveled > 0.0 else direction
		var has_arc := arc_height > 0.5
		var active_trail: Array[Vector2] = visual_trail if (has_arc and visual_trail.size() > 1) else trail
		var outer_c := Color("201228")
		var rim_c := Color("ff6220") if is_arc else (Color("9642ff") if is_break else Color("2b8cd8"))
		var mid_c := Color("ffb448") if is_arc else (Color("d488ff") if is_break else Color("6ef0ff"))
		var hot_c := Color("fff8cc") if is_arc else (Color("f8ecff") if is_break else Color("eeffff"))
		for index in range(1,active_trail.size()):
			var tail := float(index)/float(active_trail.size())
			var p0 := active_trail[index-1]-position
			var p1 := active_trail[index]-position
			draw_line(p0,p1,Color(rim_c.r,rim_c.g,rim_c.b,tail*0.65),2.8+tail*5.5,false)
			draw_line(p0,p1,Color(mid_c.r,mid_c.g,mid_c.b,tail*0.85),1.4+tail*3.0,false)
		for s_i in range(3):
			var sa := life * 16.0 + float(s_i) * (TAU / 3.0)
			var sp := (visual_offset - active_dir * (6.0 + float(s_i) * 5.0) + Vector2(cos(sa), sin(sa)) * 4.5).snapped(Vector2(2, 2))
			draw_rect(Rect2(sp - Vector2(2, 2), Vector2(4, 4)), rim_c)
			draw_rect(Rect2(sp - Vector2(1, 1), Vector2(2, 2)), hot_c)
		draw_set_transform(visual_offset,active_dir.angle())
		draw_colored_polygon(PackedVector2Array([Vector2(16,0),Vector2(0,-7.5),Vector2(-14,0),Vector2(0,7.5)]),outer_c)
		draw_colored_polygon(PackedVector2Array([Vector2(14,0),Vector2(0,-5.5),Vector2(-11,0),Vector2(0,5.5)]),rim_c)
		draw_colored_polygon(PackedVector2Array([Vector2(12,0),Vector2(1,-3.6),Vector2(-7,0),Vector2(1,3.6)]),mid_c)
		draw_colored_polygon(PackedVector2Array([Vector2(10,0),Vector2(2,-1.8),Vector2(-3,0),Vector2(2,1.8)]),hot_c)
		draw_set_transform(Vector2.ZERO)
		return
	if source=="hero" and presentation in ["gunner","gunner_crit","druid","healer"]:
		if presentation=="gunner_crit":
			for index in range(1,trail.size()):
				var u := float(index)/float(trail.size())
				draw_line(trail[index-1]-position,trail[index]-position,Color(0.28,0.85,1.0,u*0.72),2.0+u*5.5,true)
				draw_line(trail[index-1]-position,trail[index]-position,Color(0.92,0.99,1.0,u*0.92),1.0+u*2.4,true)
			draw_set_transform(Vector2.ZERO,direction.angle())
			draw_colored_polygon(PackedVector2Array([Vector2(18,0),Vector2(-4,-5.5),Vector2(-18,0),Vector2(-4,5.5)]),Color("38c8ff"))
			draw_colored_polygon(PackedVector2Array([Vector2(15,0),Vector2(-2,-2.8),Vector2(-12,0),Vector2(-2,2.8)]),Color("f2feff"))
			draw_set_transform(Vector2.ZERO)
			return
		elif presentation=="gunner":
			for index in range(1,trail.size()):
				var u := float(index)/float(trail.size())
				draw_line(trail[index-1]-position,trail[index]-position,Color(0.42,0.80,1.0,u*0.58),1.4+u*3.2,true)
			draw_set_transform(Vector2.ZERO,direction.angle())
			draw_rect(Rect2(-12,-2.2,22,4.4),Color("2a6ec4"))
			draw_rect(Rect2(-9,-1.2,18,2.4),Color("b8f0ff"))
			draw_circle(Vector2(10,0),2.4,Color("ffffff"))
			draw_set_transform(Vector2.ZERO)
			return
		elif presentation=="druid":
			for index in range(1,trail.size()):
				var u := float(index)/float(trail.size())
				draw_line(trail[index-1]-position,trail[index]-position,Color(0.32,0.86,0.44,u*0.55),1.8+u*4.2,true)
			draw_circle(Vector2.ZERO,8.5,Color(0.22,0.78,0.36,0.38))
			draw_circle(Vector2.ZERO,5.5,Color("58dc74"))
			draw_circle(Vector2(-1.4,-1.4),2.4,Color("e8ffd2"))
			return
		else:
			for index in range(1,trail.size()):
				var u := float(index)/float(trail.size())
				draw_line(trail[index-1]-position,trail[index]-position,Color(0.98,0.68,0.82,u*0.58),1.8+u*4.2,true)
			draw_circle(Vector2.ZERO,8.8,Color(0.98,0.64,0.82,0.38))
			draw_circle(Vector2.ZERO,5.6,Color("ff9cc8"))
			draw_circle(Vector2(-1.2,-1.2),2.5,Color("fff7d8"))
			return
	for index in range(1,trail.size()):
		var t_alpha:=float(index)/float(trail.size())
		draw_line(trail[index-1]-position,trail[index]-position,Color(0.08,0.06,0.10,t_alpha*0.42),4.0,true)
		draw_line(trail[index-1]-position,trail[index]-position,Color(colour,t_alpha*0.62),2.2,true)
	draw_set_transform(Vector2.ZERO,direction.angle())
	if appearance=="sword_wave":
		draw_colored_polygon(PackedVector2Array([Vector2(20,0),Vector2(4,-24),Vector2(-9,-16),Vector2(2,0),Vector2(-9,16),Vector2(4,24)]),Color("14111b"))
		draw_colored_polygon(PackedVector2Array([Vector2(17,0),Vector2(3,-20),Vector2(-6,-12),Vector2(5,0),Vector2(-6,12),Vector2(3,20)]),Color("ff5e48"))
		draw_colored_polygon(PackedVector2Array([Vector2(14,0),Vector2(4,-14),Vector2(-2,-6),Vector2(7,0),Vector2(-2,6),Vector2(4,14)]),Color("ffe87a"))
		draw_colored_polygon(PackedVector2Array([Vector2(12,0),Vector2(5,-8),Vector2(3,0),Vector2(5,8)]),Color("ffffff"))
	elif appearance in ["arrow","spear"]:
		draw_line(Vector2(-15,0),Vector2(6,0),Color("1a1412"),5.0)
		draw_line(Vector2(-14,0),Vector2(4,0),Color("8b613c"),2.8)
		draw_colored_polygon(PackedVector2Array([Vector2(11,0),Vector2(2,-4),Vector2(2,4)]),Color("1a1412"))
		draw_colored_polygon(PackedVector2Array([Vector2(10,0),Vector2(3,-2.8),Vector2(3,2.8)]),colour)
		draw_line(Vector2(-13,-3.5),Vector2(-7,0),Color("f7e4b4"),1.8)
	elif appearance=="lightning_bolt":
		var pts := PackedVector2Array([Vector2(-14,-2),Vector2(-5,3),Vector2(3,-4),Vector2(14,0)])
		draw_polyline(pts,Color("15283a"),5.0,false)
		draw_polyline(pts,Color("4eeaff"),2.8,false)
		draw_polyline(pts,Color("f4ffff"),1.2,false)
		draw_rect(Rect2(Vector2(-12,-6),Vector2(3,3)),Color("8cf4ff"))
		draw_rect(Rect2(Vector2(6,3),Vector2(3,3)),Color("f4ffff"))
	elif appearance=="void_bolt":
		draw_colored_polygon(PackedVector2Array([Vector2(13,0),Vector2(0,-6),Vector2(-12,0),Vector2(0,6)]),Color("1a0d26"))
		draw_colored_polygon(PackedVector2Array([Vector2(11,0),Vector2(0,-4.2),Vector2(-9,0),Vector2(0,4.2)]),Color("9d4eff"))
		draw_colored_polygon(PackedVector2Array([Vector2(8,0),Vector2(0,-2),Vector2(-5,0),Vector2(0,2)]),Color("f8c6ff"))
		draw_rect(Rect2(Vector2(-14,-3),Vector2(3,3)),Color("c478ff"))
	elif appearance=="water_bolt":
		draw_colored_polygon(PackedVector2Array([Vector2(12,0),Vector2(-2,-5),Vector2(-10,0),Vector2(-2,5)]),Color("102a38"))
		draw_colored_polygon(PackedVector2Array([Vector2(10,0),Vector2(-1,-3.4),Vector2(-8,0),Vector2(-1,3.4)]),Color("46e4e8"))
		draw_rect(Rect2(Vector2(-2,-1.5),Vector2(6,3)),Color("e6ffff"))
	elif appearance=="venom_bolt":
		draw_rect(Rect2(Vector2(-6,-5),Vector2(12,10)),Color("1e1228"))
		draw_rect(Rect2(Vector2(-4,-3),Vector2(8,6)),Color("72f05c"))
		draw_rect(Rect2(Vector2(-1,-2),Vector2(3,3)),Color("d8ffbf"))
	else:
		var outer_col:=Color("220d12") if source=="enemy" else Color("1d1626")
		draw_circle(Vector2.ZERO,8.2,outer_col)
		draw_circle(Vector2.ZERO,5.6,colour)
		draw_circle(Vector2(-1.2,-1.2),2.3,Color("fff6da"))
