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
var hit_ids: Dictionary={}
var trail: Array[Vector2]=[]
var presentation: String=""
var feedback_tag: String="attack"
func _physics_process(delta: float) -> void:
	if not game.running or game.game_over:return
	life-=delta
	if life<=0:queue_free();return
	var old:=position
	if appearance=="magic" and source!="enemy" and is_instance_valid(target) and not target.dead:direction=(target.center()-position).normalized()
	position+=direction*speed*delta;trail.append(position)
	if trail.size()>5:trail.pop_front()
	if source=="enemy":
		if not game.hero.knocked_out and Geometry2D.get_closest_point_to_segment(game.hero.center(),old,position).distance_to(game.hero.center())<14:
			game.hero.take_hit(damage,damage_type);queue_free();return
	else:
		var low:=Vector2(minf(old.x,position.x),minf(old.y,position.y))
		var high:=Vector2(maxf(old.x,position.x),maxf(old.y,position.y))
		for enemy in game.projectile_candidates():
			if not is_instance_valid(enemy) or enemy.dead or hit_ids.has(enemy.get_instance_id()):continue
			var center: Vector2=enemy.center();var reach: float=enemy.radius+5
			if center.x<low.x-reach or center.x>high.x+reach or center.y<low.y-reach or center.y>high.y+reach:continue
			if Geometry2D.get_closest_point_to_segment(center,old,position).distance_squared_to(center)>reach*reach:continue
			hit_ids[enemy.get_instance_id()]=true
			if is_instance_valid(tower) and not enemy.dead:enemy.last_tower=tower
			if splash>0:game.area_damage(enemy.position,splash,damage,damage_type,source,0.0,0.0,pen,knockback,feedback_tag)
			else:enemy.take_hit(damage,damage_type,source,0.0,0.0,pen,feedback_tag)
			if is_instance_valid(enemy) and not enemy.dead:
				if mark>0:enemy.apply_mark(mark,mark_bonus)
				if freeze_stacks>0:enemy.frost_hit(slow_amount,slow_time,freeze_stacks,freeze_time)
				elif slow_amount>0:enemy.chill(slow_amount,slow_time)
				if knockback>0 and splash<=0:enemy.push_back(knockback)
			if pierce>0 and source=="hero": game.hero.note_pierce_hit()
			if burn>0:enemy.ignite(burn,3.0)
			if expose and is_instance_valid(enemy) and not enemy.dead:enemy.exposure=2.0
			if pierce<=0:queue_free();return
			pierce-=1
	queue_redraw()
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
	for index in range(1,trail.size()):draw_line(trail[index-1]-position,trail[index]-position,Color(colour,float(index)/trail.size()*0.4),2.0,true)
	draw_set_transform(Vector2.ZERO,direction.angle())
	if appearance in ["arrow","spear"]:
		draw_line(Vector2(-14,0),Vector2(4,0),Color("6e4a2f"),3)
		draw_colored_polygon(PackedVector2Array([Vector2(10,0),Vector2(3,-3),Vector2(3,3)]),colour)
		draw_line(Vector2(-12,-3),Vector2(-7,0),colour,2)
	else:
		draw_circle(Vector2.ZERO,7,Color("40334b"));draw_circle(Vector2.ZERO,5,colour);draw_circle(Vector2(-1,-1),2,Color("fff4d2"))
