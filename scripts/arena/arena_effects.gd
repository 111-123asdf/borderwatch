class_name ArenaEffects
extends Node2D
var game: Node2D
func _process(_delta: float) -> void:queue_redraw()
func _draw() -> void:
	for item in game.effects:
		var p: float=1.0-item.life/item.duration;var colour: Color=Color(item.colour,(1.0-p)*0.8);var point: Vector2=item.point;var r: float=item.radius
		match item.kind:
			"hit":
				for index in range(5):
					var vector:=Vector2.RIGHT.rotated(index*TAU/5)
					draw_line(point+vector*r*p,point+vector*r*(p+0.4),colour,2,true)
			"slash":
				var a: float=Vector2(item.direction).angle();draw_arc(point,r*0.9,a-1.15+p*1.6,a-0.4+p*1.6,24,colour,5,true)
			"meteor":draw_circle(point+Vector2(-160*(1-p),-400*(1-p)),20*(1-p)+5,colour)
			_:
				draw_arc(point,r*(0.3+p*0.7),0,TAU,40,colour,3,true)
				if item.kind in ["blast","slam","frost"]:
					for index in range(8):
						var vector:=Vector2.RIGHT.rotated(index*TAU/8)
						draw_line(point+vector*r*p*0.7,point+vector*r*p,colour,2,true)
	for item in game.delayed:
		var p: float=1.0-item.life/item.duration;var colour:=Color("ff6655") if item.source=="enemy" else ArenaCombat.colour(item.type)
		draw_arc(item.point,item.radius,0,TAU,48,Color(colour,0.7),2,true)
		draw_arc(item.point,item.radius*(1-p),0,TAU,40,Color(colour,0.45),2,true)
		if item.options.has("origin"):
			var point: Vector2=Vector2(item.options.origin).lerp(item.point,p)+Vector2(0,-sin(p*PI)*100)
			draw_circle(point,7,colour);draw_circle(point-Vector2(2,2),2,Color("fff1b0"))
		elif bool(item.options.get("arrow_rain",false)):
			for index in range(5):
				var point: Vector2=item.point+Vector2((index-2)*34,-180*(1-p))
				draw_line(point,point+Vector2(0,15),colour,2,true)
	for item in game.numbers:
		draw_string(ThemeDB.fallback_font,item.point,item.text,HORIZONTAL_ALIGNMENT_CENTER,-1,13,Color(item.colour,minf(1,item.life*3)))
