class_name ArenaRuinsSiege
extends Node2D
## One readable mid-battle topology change. Killing the breacher buys one wave.
var game: ArenaGame
var warned:=false
var interrupted:=false
var opened:=false
var clock:=0.0
var warning_clock:=0.0
var reveal:=0.0
var intro_pending:=false
var guard: ArenaEnemy
var open_layer: Sprite2D
var stone_styles: Array[StyleBoxFlat]=[]
func _ready() -> void:
	z_index=3
	for colour in [Color("a5a197"),Color("939196")]:
		var style:=StyleBoxFlat.new();style.bg_color=colour;style.border_color=Color("575c67");style.set_border_width_all(2);style.set_corner_radius_all(3);stone_styles.append(style)
	if ResourceLoader.exists("res://assets/v017/map_ruins_open.png"):
		var file:=FileAccess.open("res://assets/v017/art_layers.json",FileAccess.READ)
		var data: Dictionary=JSON.parse_string(file.get_as_text());var rect: Array=data.breach_rect
		open_layer=Sprite2D.new();open_layer.texture=load("res://assets/v017/map_ruins_open.png");open_layer.position=Vector2(float(rect[0])+float(rect[2])*0.5,float(rect[1])+float(rect[3])*0.5);open_layer.modulate.a=0;open_layer.visible=false;open_layer.z_index=-19;open_layer.material=game.ground.material;game.terrain.add_child(open_layer)
func point() -> Vector2:return game.level_definition.breach.point
func tick(delta: float) -> void:
	if game.game_over:return
	warning_clock=maxf(0.0,warning_clock-delta)
	if not warned and game.cycle>=4 and game.phase=="spawn":
		warned=true;clock=12.0;warning_clock=12.0
		guard=ArenaEnemy.new();guard.game=game;guard.kind="breacher";guard.is_guard=true;guard.siege_guard=true;guard.home=game.level_definition.breach.guard;guard.position=guard.home;game.actors.add_child(guard);game.enemies.append(guard);game.enemy_revision+=1
		game.numbers.append({"point":point()+Vector2(0,-70),"text":"破障者蓄力","colour":Color("e3ad77"),"life":2.0})
	if warned and not opened:
		if not interrupted and (not is_instance_valid(guard) or guard.dead):
			interrupted=true;clock=12.0
			game.numbers.append({"point":point()+Vector2(0,-60),"text":"破障延缓至下一波","colour":Color("bddb9a"),"life":2.0})
		if not interrupted or game.cycle>=5:
			clock=maxf(0,clock-delta)
			if is_instance_valid(guard) and not guard.dead:
				guard.visual.show_pose("attack",Vector2.LEFT)
			if clock<=0:open_passage()
	if opened:
		reveal=move_toward(reveal,1.0,delta*1.5)
		if open_layer!=null:open_layer.visible=true;open_layer.modulate.a=reveal
		if intro_pending and game.phase=="spawn":
			intro_pending=false
			for i in range(5):game.spawn_queue.append({"kind":"rune_warden" if i>=3 else "construct_hound","route":3,"elite":false,"at":game.wave_elapsed+10.0+i*1.0})
			game.spawn_queue.sort_custom(func(a,b):return a.at<b.at)
	queue_redraw()
func open_passage() -> void:
	if opened:return
	opened=true;warned=true;warning_clock=8.0;game.breach_open=true;intro_pending=true
	game.effect(point(),90,Color("cbb7a0"),"blast",0.65);game.audio.play("explode",-13)
	game.numbers.append({"point":point()+Vector2(0,-60),"text":"东北支路开启","colour":Color("e6c494"),"life":2.0})
	if is_instance_valid(guard) and not guard.dead:game.remove_enemy(guard)
	game.rebuild_navigation()
	if game.atmosphere!=null:game.atmosphere.trigger_rift_breach(point())
func _draw() -> void:
	if opened:return
	var center:=point()
	ArenaGrounding.ensure_textures()
	draw_texture_rect(ArenaGrounding.shadow,Rect2(center+Vector2(-72,-14),Vector2(148,54)),false)
	var shake_off:=Vector2.ZERO
	if warned and not interrupted:
		var t:=Time.get_ticks_msec()*0.025
		shake_off=Vector2(sin(t)*1.8,cos(t*1.3)*1.2)*(1.0-clock/12.0)
	if ArenaGrounding.mechanisms!=null:
		if warned:
			var pulse:=0.55+0.45*sin(Time.get_ticks_msec()*0.008)
			draw_set_transform(center+Vector2(0,4),0.0,Vector2(1.0,0.52))
			draw_circle(Vector2.ZERO,64.0,Color(0.96,0.68,0.28,0.14+0.12*pulse))
			draw_arc(Vector2.ZERO,62.0,0.0,TAU,36,Color(0.98,0.78,0.38,0.52),2.2,true)
			draw_set_transform(Vector2.ZERO)
		draw_texture_rect_region(ArenaGrounding.mechanisms,Rect2(center+shake_off-Vector2(74,68),Vector2(148,124)),Rect2(0,0,256,256))
	else:
		for row in range(3):
			for column in range(5):
				var rect:=Rect2(center+Vector2(-52+column*21+(5 if row%2 else 0),-31+row*17),Vector2(22,19))
				draw_style_box(stone_style(row,column),rect)
	if warned:
		draw_arc(center+Vector2(0,-42),22,-PI/2,-PI/2+TAU*(1.0-clock/12.0),32,Color("f4c27a"),3.2,true)
func stone_style(row: int,column: int) -> StyleBoxFlat:
	return stone_styles[(row+column)%2]
