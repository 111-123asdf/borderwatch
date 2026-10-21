extends Node2D

var kind := "cannon"
var clock := 0.0

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	if kind == "cannon":
		draw_circle(Vector2.ZERO, 17, Color("243745"))
		draw_circle(Vector2.ZERO, 13, Color("8a8fa5"))
		draw_rect(Rect2(-5, -10, 36, 20), Color("243745"))
		draw_rect(Rect2(-3, -7, 31, 14), Color("797f9b"))
		draw_rect(Rect2(-2, -7, 28, 4), Color("bbc0ce"))
		draw_rect(Rect2(22, -12, 9, 24), Color("303e51"))
		draw_rect(Rect2(23, -9, 5, 18), Color("c0a77e"))
	elif kind == "bolt":
		draw_circle(Vector2.ZERO, 13, Color("304a47"))
		draw_line(Vector2(-14, -22), Vector2(9, 0), Color("d0a568"), 6, false)
		draw_line(Vector2(9, 0), Vector2(-14, 22), Color("d0a568"), 6, false)
		draw_line(Vector2(-14, -22), Vector2(-14, 22), Color("f1e3b6"), 1.5, true)
		draw_line(Vector2(-18, 0), Vector2(23, 0), Color("3c5357"), 8, false)
		draw_line(Vector2(-18, 0), Vector2(23, 0), Color("adc7bd"), 3, false)
	else:
		draw_circle(Vector2.ZERO, 22 + sin(clock * 3) * 2, Color(0.57, 0.93, 1, 0.08))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -24), Vector2(13, 0), Vector2(0, 19), Vector2(-13, 0)]), Color("304959"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -19), Vector2(9, 0), Vector2(0, 14), Vector2(-9, 0)]), Color("a0e3eb"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -19), Vector2(0, 14), Vector2(-9, 0)]), Color("62b5d2"))
