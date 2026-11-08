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
var target: Node2D
var hit_ids: Dictionary={}
var trail: Array[Vector2]=[]
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
		for enemy in game.enemies.duplicate():
			if not is_instance_valid(enemy) or enemy.dead or hit_ids.has(enemy.get_instance_id()):continue
			if Geometry2D.get_closest_point_to_segment(enemy.center(),old,position).distance_to(enemy.center())>enemy.radius+5:continue
			hit_ids[enemy.get_instance_id()]=true
			if splash>0:game.area_damage(enemy.position,splash,damage,damage_type,source)
			else:enemy.take_hit(damage,damage_type,source)
			if pierce>0 and source=="hero": game.hero.note_pierce_hit()
			if burn>0:enemy.ignite(burn,3.0)
			if expose and is_instance_valid(enemy) and not enemy.dead:enemy.exposure=2.0
			if pierce<=0:queue_free();return
			pierce-=1
	queue_redraw()
func _draw() -> void:
	var colour:=Color("ff645a") if source=="enemy" else ArenaCombat.colour(damage_type)
	for index in range(1,trail.size()):draw_line(trail[index-1]-position,trail[index]-position,Color(colour,float(index)/trail.size()*0.4),2.0,true)
	draw_set_transform(Vector2.ZERO,direction.angle())
	if appearance in ["arrow","spear"]:
		draw_line(Vector2(-14,0),Vector2(4,0),Color("6e4a2f"),3)
		draw_colored_polygon(PackedVector2Array([Vector2(10,0),Vector2(3,-3),Vector2(3,3)]),colour)
		draw_line(Vector2(-12,-3),Vector2(-7,0),colour,2)
	else:
		draw_circle(Vector2.ZERO,7,Color("40334b"));draw_circle(Vector2.ZERO,5,colour);draw_circle(Vector2(-1,-1),2,Color("fff4d2"))
