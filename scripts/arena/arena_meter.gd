class_name ArenaMeter
extends Control
var max_value := 100.0:
	set(v): max_value=maxf(0.001,v);queue_redraw()
var value := 0.0:
	set(v): value=v;queue_redraw()
var show_percentage := false
func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	draw_style_box(get_theme_stylebox("background"),Rect2(Vector2.ZERO,size))
	var width:=size.x*clampf(value/max_value,0,1)
	if width>0: draw_style_box(get_theme_stylebox("fill"),Rect2(Vector2.ZERO,Vector2(width,size.y)))
