class_name ArenaHeroSkillFX
extends RefCounted

const ROOT := "res://assets/hero_poses/fx/"
const AMBER := Color("f3ce89")

const COPPER := Color("ca8b61")

const LEAF := Color("c0cb86")

static var materials: Dictionary={}

static func texture(key: String) -> Texture2D:
	if not materials.has(key):
		var path:=ROOT+key+".png"
		if not ResourceLoader.exists(path):
			return null
		materials[key]=load(path)
	return materials[key]

static func paint(layer: CanvasItem, key: String, at: Vector2, width: float, angle: float, opacity: float, flat:=1.0) -> void:
	var image:=texture(key)
	if image==null or opacity<0.01:
		return
	var size:=Vector2(width,width*float(image.get_height())/float(image.get_width())*flat)
	layer.draw_set_transform(at,angle)
	layer.draw_texture_rect(image,Rect2(-size*0.5,size),false,Color(1,1,1,clampf(opacity,0.0,1.0)))
	layer.draw_set_transform(Vector2.ZERO)

static func strip(layer: CanvasItem, at: Vector2, direction: Vector2, size: Vector2, color: Color) -> void:
	var normal:=direction.orthogonal()*size.y
	layer.draw_colored_polygon(PackedVector2Array([
		at-direction*size.x,at-direction*size.x*0.17-normal,at+direction*size.x*0.32,at-direction*size.x*0.17+normal
	]),color)

static func shards(layer: CanvasItem, at: Vector2, direction: Vector2, t: float, size: float, tint: Color, count: int) -> void:
	var age:=clampf(t,0.0,1.0)
	var ease:=1.0-pow(1.0-age,3)
	for i in range(count):
		var ratio:=float(i)/maxf(1.0,count-1)
		var bearing:=direction.rotated((ratio-0.5)*2.5)
		var splash:=size*(0.44+0.56*fposmod(float(i)*0.618,1.0))
		var pt:=at+bearing*splash*ease+Vector2(0,(age*age-age)*splash*0.48)
		var dimensions:=Vector2(5.0+splash*0.13,1.0+splash*0.038)*(1.0-age*0.65)
		strip(layer,pt,bearing,dimensions,Color(tint,(1.0-age)*0.86))

static func draw_gunner_slide(layer: CanvasItem, item: Dictionary, progress: float, reduced: bool) -> void:
	var direction: Vector2=Vector2(item.direction).normalized()
	if direction.is_zero_approx():direction=Vector2.RIGHT
	var point: Vector2=item.point+direction*(16.0+36.0*progress)
	var fading:=1.0-smoothstep(0.16,1.0,progress)
	paint(layer,"wind",point,52.0+float(item.radius)*progress,direction.angle(),fading*(0.62 if reduced else 0.9),0.52)
	if not reduced:
		shards(layer,point,direction,progress,34,COPPER,8)

static func draw_companion_orders(layer: CanvasItem, hero: ArenaHero, reduced: bool) -> void:
	for beast in hero.companions:
		if not beast.visible or beast.orders_left<4.18:
			continue
		var start: Vector2=beast.position+Vector2(0,-19)
		var finish: Vector2=beast.destination
		if is_instance_valid(beast.ordered_target) and not beast.ordered_target.dead:
			finish=beast.ordered_target.position
		var bearing:=start.direction_to(finish)
		var guide:=start.lerp(finish,0.55)+bearing.orthogonal()*(27.0 if beast.slot==0 else -27.0)
		var age:=1.0-clampf((beast.orders_left-4.18)/0.82,0.0,1.0)
		for i in range(2 if reduced else 4):
			var u:=clampf(age-float(i)*0.09,0.0,1.0)
			var spot:=start.lerp(guide,u).lerp(guide.lerp(finish,u),u)
			var tint:=AMBER if beast.slot==0 else LEAF
			strip(layer,spot,bearing,Vector2(11.0-float(i),2.1),Color(tint,(1.0-age)*0.75))
		paint(layer,"leaves",start,25.0+24.0*age,bearing.angle(),(1.0-age)*0.64)
