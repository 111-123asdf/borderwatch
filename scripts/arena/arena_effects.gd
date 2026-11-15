class_name ArenaEffects
extends Node2D
var game: Node2D
var painted: Texture2D
func _ready() -> void:
	if ResourceLoader.exists("res://assets/v011/physical_fx.png"):painted=load("res://assets/v011/physical_fx.png")
func _process(_delta: float) -> void:queue_redraw()
func _paint(hero: String,row: int,column: int,point: Vector2,dimensions: Vector2,alpha:=1.0,angle:=0.0) -> void:
	var texture:=ArenaHeroVFX.frame(hero,row,clampi(column,0,3))
	if texture==null:return
	draw_set_transform(point,angle);draw_texture_rect(texture,Rect2(-dimensions*0.5,dimensions),false,Color(1,1,1,alpha));draw_set_transform(Vector2.ZERO)
func _draw() -> void:
	if game.started and game.feel.enabled and game.war_cry_clock>0:
		var supported: Array=game.towers+game.soldiers+[game.hero]
		for unit in supported:
			if not is_instance_valid(unit) or unit.position.distance_to(game.war_cry_position)>=game.hero.war_cry_radius():continue
			var marker: Vector2=unit.position+Vector2(0,8)
			draw_line(marker+Vector2(-6,1),marker+Vector2(0,-5),Color("f5ce7b"),2,true)
			draw_line(marker+Vector2(0,-5),marker+Vector2(6,1),Color("f5ce7b"),2,true)
	for item in game.effects:
		var p: float=1.0-item.life/item.duration;var colour: Color=Color(item.colour,(1.0-p)*0.8);var point: Vector2=item.point;var r: float=item.radius
		match item.kind:
			"arrow_impact_painted","magic_impact_painted":
				_paint("mage" if item.kind=="magic_impact_painted" else "ranger",1,int(p*4),point,Vector2.ONE*r*2,1.0-p*p)
			"roll_painted":
				if not bool(game.campaign.data.reduced_motion):_paint("ranger",2,int(p*4),point,Vector2(r*2,r),1.0-p,Vector2(item.direction).angle())
			"frost_painted":
				_paint("mage",2,int(p*4),point,Vector2.ONE*r*2,1.0-p*p)
				draw_arc(point,r,0,TAU,48,Color(0.65,0.88,1.0,(1.0-p)*0.3),1.5,true)
			"meteor_painted":
				var travel:=Vector2(-r*0.9*(1.0-p),-350*(1.0-p))
				_paint("mage",3,0 if p<0.6 else 1,point+travel,Vector2.ONE*(55+p*25),0.9)
			"meteor_impact":
				_paint("mage",3,2 if p<0.45 else 3,point,Vector2.ONE*r*2,1.0-p*p)
			"rain_impact":
				for index in range(5):
					var offset:=Vector2.RIGHT.rotated(index*TAU/5.0)*r*0.55
					_paint("ranger",1,int(p*4),point+offset,Vector2.ONE*32,1.0-p)
			"slash_painted","impact_painted","slam_painted","banner_painted":
				if painted!=null:
					var row: int={"slash_painted":0,"impact_painted":1,"slam_painted":2,"banner_painted":3}[item.kind]
					var cell:=painted.get_size()/4.0
					var column:=mini(3,int(p*4.0))
					var angle: float=Vector2(item.direction).angle() if row==0 else 0.0
					draw_set_transform(point,angle)
					var dimensions:=Vector2(r*2.0,r*2.0)
					if row==2:dimensions.y*=0.6
					if row==3:dimensions=Vector2(r*1.4,r*0.85)
					draw_texture_rect_region(painted,Rect2(-dimensions*0.5,dimensions),Rect2(Vector2(column,row)*cell,cell),Color(1,1,1,1.0-p*p))
					draw_set_transform(Vector2.ZERO)
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
		if game.feel.enabled and item.source=="hero" and bool(item.options.get("arrow_rain",false)):
			if int(item.options.get("rain_index",0))==0:draw_arc(item.point,item.radius,0,TAU,48,Color(0.9,0.83,0.5,0.4),1.5,true)
			if float(item.life)<=0.25:
				var fall:=clampf(1.0-float(item.life)/0.25,0.0,1.0)
				_paint("ranger",3,int(fall*4),Vector2(item.point)+Vector2(0,-140*(1-fall)),Vector2(item.radius*1.5,130),0.85)
			continue
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
		var font_size:=24 if game.feel.enabled else 13
		var size:=ThemeDB.fallback_font.get_string_size(item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		var origin: Vector2=item.point-Vector2(size.x*0.5,0)
		var alpha:=minf(1,item.life*4)
		draw_string_outline(ThemeDB.fallback_font,origin,item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,3,Color(0.12,0.08,0.05,alpha))
		draw_string(ThemeDB.fallback_font,origin,item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(item.colour,alpha))
