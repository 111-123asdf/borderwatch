class_name ArenaMeter
extends Control
var max_value := 100.0:
	set(v): max_value=maxf(0.001,v);queue_redraw()
var value := 0.0:
	set(v): value=v;queue_redraw()
var show_percentage := false
var low_threshold := 0.0
var full_threshold := false
var step_thresholds := false
func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_style_box(get_theme_stylebox("background"),Rect2(Vector2.ZERO,size))
	var width:=size.x*clampf(value/max_value,0,1)
	if width>0: draw_style_box(get_theme_stylebox("fill"),Rect2(Vector2.ZERO,Vector2(width,size.y)))
	if step_thresholds:
		for step in range(1,10):
			var x:=size.x*float(step)/10.0
			draw_line(Vector2(x,4),Vector2(x,size.y-4),Color("ad9389"),1.0)
	if low_threshold>0.0: _threshold(low_threshold,value<max_value*low_threshold)
	if full_threshold: _threshold(0.99,value>=max_value*0.99)

func _threshold(at: float, active: bool) -> void:
	var x:=size.x*at
	draw_line(Vector2(x,0),Vector2(x,size.y),Color("fff3bc") if active else Color("99877d"),2.0)
