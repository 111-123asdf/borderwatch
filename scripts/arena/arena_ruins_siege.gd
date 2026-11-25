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
	for colour in [Color("787094"),Color("5e5678")]:
		var style:=StyleBoxFlat.new();style.bg_color=colour;style.border_color=Color("3a3052");style.set_border_width_all(2);style.set_corner_radius_all(3);stone_styles.append(style)
func point() -> Vector2:return game.level_definition.breach.point
func tick(delta: float) -> void:
	if game.game_over:return
	warning_clock=maxf(0.0,warning_clock-delta)
	if not warned and game.cycle>=3 and game.phase=="spawn":
		warned=true;clock=12.0;warning_clock=12.0
		guard=ArenaEnemy.new();guard.game=game;guard.kind="twilight_golem";guard.is_guard=true;guard.home=game.level_definition.breach.guard;guard.position=guard.home
		game.register_enemy(guard)
		game.numbers.append({"point":point()+Vector2(18,-68),"text":"破障石像蓄力","colour":Color("e3ad77"),"life":2.0})
	if warned and not opened:
		if not interrupted and (not is_instance_valid(guard) or guard.dead):
			interrupted=true;clock=12.0
			game.numbers.append({"point":point()+Vector2(0,-60),"text":"破障延缓至下一波","colour":Color("bddb9a"),"life":2.0})
		if not interrupted or game.cycle>=4:
			clock=maxf(0,clock-delta)
			if is_instance_valid(guard) and not guard.dead:
				guard.visual.show_pose("attack",Vector2.LEFT)
			if clock<=0:open_passage()
	if opened:
		reveal=move_toward(reveal,1.0,delta*1.5)
		if open_layer!=null:open_layer.visible=true;open_layer.modulate.a=reveal
		if intro_pending and game.phase=="spawn":
			intro_pending=false
			var pack: Array = ["void_eyeling", "void_eyeling", "twilight_avenger", "twilight_avenger", "twilight_golem"]
			for i in range(pack.size()):
				game.spawn_queue.append({"kind":pack[i],"route":2,"elite":false,"at":game.wave_elapsed+10.0+float(i)*1.0})
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
	draw_texture_rect(ArenaGrounding.shadow,Rect2(center+Vector2(-68,-14),Vector2(140,48)),false)
	var shake_off:=Vector2.ZERO
	if warned and not interrupted:
		var t:=Time.get_ticks_msec()*0.025
		shake_off=Vector2(sin(t)*1.8,cos(t*1.3)*1.2)*(1.0-clock/12.0)
	if ArenaGrounding.mechanisms!=null:
		if warned:
			var pulse:=0.55+0.45*sin(Time.get_ticks_msec()*0.008)
			for c_i in range(4):
				var ca := float(c_i) * (TAU / 4.0) + 0.4
				var c0 := (center + Vector2(cos(ca) * 14.0, sin(ca) * 8.0)).snapped(Vector2(2, 2))
				var c1 := (center + Vector2(cos(ca) * 44.0, sin(ca) * 22.0)).snapped(Vector2(2, 2))
				draw_line(c0, c1, Color("201028", 0.85), 4.0)
				draw_line(c0, c1, Color(0.86, 0.56, 1.0, 0.55 + 0.45 * pulse), 2.0)
		draw_texture_rect_region(ArenaGrounding.mechanisms,Rect2(center+shake_off-Vector2(66,58),Vector2(132,110)),Rect2(0,0,256,256),Color(0.64,0.54,0.78))
	else:
		for row in range(3):
			for column in range(5):
				var rect:=Rect2(center+Vector2(-52+column*21+(5 if row%2 else 0),-31+row*17),Vector2(22,19))
				draw_style_box(stone_style(row,column),rect)
	if warned:
		var pct := clampf(1.0 - clock / 12.0, 0.0, 1.0)
		var bar_o := (center + Vector2(-26, -48)).snapped(Vector2(2, 2))
		draw_rect(Rect2(bar_o - Vector2(1, 1), Vector2(54, 7)), Color("120e1a", 0.90))
		draw_rect(Rect2(bar_o, Vector2(52.0 * pct, 5.0)), Color("f4c27a"))
func stone_style(row: int,column: int) -> StyleBoxFlat:
	return stone_styles[(row+column)%2]
