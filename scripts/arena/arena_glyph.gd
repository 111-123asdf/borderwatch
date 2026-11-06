class_name ArenaGlyph
extends Control
var kind := "coin"
var tint := Color("e7c47b")
var progress := 1.0
func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var c := size*0.5
	var r := minf(size.x,size.y)*0.37
	var dark := Color("162f31")
	match kind:
		"coin":
			draw_circle(c,r+2,dark); draw_circle(c,r,tint); draw_arc(c,r*0.7,0,TAU,24,Color("fff1a9"),2); draw_line(c-Vector2(0,r*0.5),c+Vector2(0,r*0.5),dark,2)
		"heart":
			draw_circle(c+Vector2(-r*0.43,-r*0.3),r*0.59,tint);draw_circle(c+Vector2(r*0.43,-r*0.3),r*0.59,tint)
			draw_colored_polygon(PackedVector2Array([c+Vector2(-r,-r*0.1),c+Vector2(r,-r*0.1),c+Vector2(0,r)]),tint)
		"physical":
			draw_colored_polygon(PackedVector2Array([c+Vector2(r,-r),c+Vector2(r*0.65,-r*0.05),c+Vector2(-r*0.4,r*0.65),c+Vector2(-r*0.65,r*0.4),c+Vector2(r*0.05,-r*0.65)]),tint)
			draw_line(c+Vector2(-r*0.7,r*0.1),c+Vector2(-r*0.1,r*0.7),tint,4);draw_line(c+Vector2(-r*0.4,r*0.4),c+Vector2(-r,r),tint,4)
		"magic":
			draw_colored_polygon(PackedVector2Array([c+Vector2(0,-r),c+Vector2(r*0.3,-r*0.2),c+Vector2(r,0),c+Vector2(r*0.3,r*0.2),c+Vector2(0,r),c+Vector2(-r*0.3,r*0.2),c+Vector2(-r,0),c+Vector2(-r*0.3,-r*0.2)]),tint)
		"flag":
			draw_line(c+Vector2(-r*0.5,r),c+Vector2(-r*0.5,-r),tint,3);draw_colored_polygon(PackedVector2Array([c+Vector2(-r*0.5,-r),c+Vector2(r,-r*0.6),c+Vector2(-r*0.5,0)]),tint)
		"move":
			for n in [-0.4,0.4]:draw_arc(c+Vector2(n*r,0),r*0.6,-PI*0.5,PI*0.5,12,tint,3)
		"skill":draw_arc(c,r,0,TAU,24,tint,3);draw_line(c,c+Vector2(0,-r*0.7),tint,3);draw_line(c,c+Vector2(r*0.6,0),tint,3)
		"frost":
			for angle in range(3):
				var ray:=Vector2.RIGHT.rotated(angle*PI/3)*r
				draw_line(c-ray,c+ray,tint,2,true)
				for end in [-1,1]:
					var tip: Vector2=ray*end
					draw_line(c+tip,c+tip*0.55+tip.orthogonal()*0.22,tint,2,true);draw_line(c+tip,c+tip*0.55-tip.orthogonal()*0.22,tint,2,true)
		"meteor":
			draw_circle(c+Vector2(-r*0.35,r*0.35),r*0.53,tint)
			for n in range(3):draw_line(c+Vector2(-r*0.15+n*r*0.3,r*0.4-n*r*0.3),c+Vector2(r*(0.25+n*0.3),-r*(0.45+n*0.15)),tint,3,true)
		"rain":
			for n in range(3):
				var p:=c+Vector2((n-1)*r*0.65,-r)
				draw_line(p,p+Vector2(-r*0.3,r*1.6),tint,2,true);draw_colored_polygon(PackedVector2Array([p+Vector2(-r*0.3,r*1.9),p+Vector2(-r*0.55,r*1.35),p+Vector2(0,r*1.45)]),tint)
		"core": draw_colored_polygon(PackedVector2Array([c+Vector2(0,-r),c+Vector2(r*0.65,0),c+Vector2(0,r),c+Vector2(-r*0.65,0)]),tint)
		"wave":
			draw_circle(c,r,tint);draw_circle(c+Vector2(-r*0.4,-r*0.15),r*0.2,dark);draw_circle(c+Vector2(r*0.4,-r*0.15),r*0.2,dark)
			draw_rect(Rect2(c+Vector2(-r*0.5,r*0.35),Vector2(r,r*0.3)),dark)
		"upgrade":
			draw_line(c+Vector2(0,r),c+Vector2(0,-r),tint,4);draw_polyline(PackedVector2Array([c+Vector2(-r*0.7,-r*0.2),c+Vector2(0,-r),c+Vector2(r*0.7,-r*0.2)]),tint,4)
		"sell":
			draw_rect(Rect2(c-Vector2(r,r*0.3),Vector2(r*2,r*1.1)),tint,false,2);draw_line(c+Vector2(-r,-r*0.6),c+Vector2(r,-r*0.6),tint,3)
		"target": draw_arc(c,r,0,TAU,24,tint,2);draw_line(c-Vector2(r*1.3,0),c+Vector2(r*1.3,0),tint,2);draw_line(c-Vector2(0,r*1.3),c+Vector2(0,r*1.3),tint,2)
		"build":
			draw_line(c+Vector2(-r*0.6,r),c+Vector2(r*0.25,-r*0.5),tint,5)
			draw_line(c+Vector2(-r*0.4,-r*0.8),c+Vector2(r*0.9,0),tint,8)
		"pause":
			for x in [-0.45,0.45]: draw_rect(Rect2(c+Vector2(x*r-2,-r),Vector2(4,r*2)),tint)
		_: draw_arc(c,r,0,TAU,24,tint,2)
	if progress < 1.0:
		draw_arc(c,r+4,-PI/2,-PI/2+TAU*clampf(progress,0,1),40,Color("fff4bf"),2)
