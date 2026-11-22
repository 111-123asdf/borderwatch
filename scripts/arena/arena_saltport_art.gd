class_name ArenaSaltportArt
extends Node2D
## Registered terrain painting with live water, windmill and y-sorted props.

const SALT := Color("f5e8c9")
const WOOD := Color("744d37")
var game: Node2D
var part := "land"
var phase := 0.0
var prop_art: Texture2D
var prop_width := 0.0

static func install(arena: Node2D) -> void:
	var land := ArenaSaltportArt.new()
	land.game=arena
	land.z_index=-25
	var surface := ShaderMaterial.new()
	surface.shader=preload("res://scripts/shaders/saltport_water.gdshader")
	land.material=surface
	land.prop_art=preload("res://assets/saltport/terrain.png")
	arena.add_child(land)
	for feature in [
		["pump",ArenaSaltport.CORE,162.0], ["mill",Vector2(552,261),46.0],
		["warehouse",Vector2(1103,269),105.0], ["warehouse",Vector2(1283,281),95.0],
		["dock",Vector2(1110,887),93.0], ["dock",Vector2(1459,865),94.0],
		["salt_cart",Vector2(335,561),70.0], ["salt_cart",Vector2(881,825),65.0],
		["shore_ledge",Vector2(832,865),105.0], ["shore_ledge",Vector2(1511,671),112.0],
		["rocks",Vector2(180,90),105.0], ["saltgrass",Vector2(783,620),41.0],
		["saltgrass",Vector2(1354,804),62.0], ["saltgrass",Vector2(853,346),47.0]
	]:
		var prop := ArenaSaltportArt.new()
		prop.game=arena
		prop.part=feature[0]
		prop.position=feature[1]
		prop.prop_width=feature[2]
		prop.prop_art=load("res://assets/saltport/"+prop.part+".png")
		arena.actors.add_child(prop)

func _ready() -> void:
	set_process(part in ["land","mill","pump"])

func _process(delta: float) -> void:
	if part=="land":
		var water := material as ShaderMaterial
		water.set_shader_parameter("animate",0.0 if bool(game.campaign.data.reduced_motion) else 1.0)
		if game.running and not game.game_over:
			phase=fposmod(phase+delta,TAU*20)
			water.set_shader_parameter("water_clock",phase)
		return
	if game.running and not game.game_over and not bool(game.campaign.data.reduced_motion):
		phase=fposmod(phase+delta,TAU*20)
		queue_redraw()

func _draw() -> void:
	match part:
		"land": draw_texture_rect(prop_art,Rect2(0,0,1600,900),false)
		"mill":
			_draw_prop()
			_sails(Vector2(0,-62),phase*0.65)
		"pump":
			_draw_prop()
			_sails(Vector2(34,-97),phase*0.50)
		_: _draw_prop()

func _draw_prop() -> void:
	var size := prop_art.get_size() * (prop_width / prop_art.get_width())
	ArenaGrounding.ensure_textures()
	draw_texture_rect(ArenaGrounding.shadow,Rect2(Vector2(-size.x*0.51,-size.y*0.15),Vector2(size.x*1.14,size.y*0.26)),false)
	draw_texture_rect(prop_art,Rect2(Vector2(-size.x*0.5,-size.y*0.94),size),false)

func _sails(center: Vector2, angle: float) -> void:
	draw_line(center,center+Vector2(0,52),WOOD,5,true)
	for blade in range(4):
		var spoke := Vector2.from_angle(angle+blade*TAU/4.0)
		var a := center+spoke*5
		var b := center+spoke*28
		draw_line(a,b,WOOD,2.7,true)
		draw_colored_polygon(PackedVector2Array([a+spoke*5,b,b+spoke.orthogonal()*8,a+spoke.orthogonal()*5]),SALT)
	draw_circle(center,4,WOOD,true,-1,true)

static func draw_site(canvas: CanvasItem, center: Vector2, index: int, occupied: bool, active: bool) -> void:
	var plinth: Texture2D=preload("res://assets/saltport/pad_wood.png") if index<6 else preload("res://assets/saltport/pad_stone.png")
	var width := 98.0 if occupied else 91.0
	var height := width*plinth.get_height()/plinth.get_width()
	var foot := Rect2(center+Vector2(-width/2.0,-height*0.53),Vector2(width,height))
	canvas.draw_texture_rect(ArenaGrounding.shadow,foot.grow(9),false)
	canvas.draw_texture_rect(plinth,foot,false,Color(1.12,1.04,0.85) if active else Color.WHITE)
	if not occupied:
		canvas.draw_set_transform(center+Vector2(0,-4),0.0,Vector2(1,0.52))
		canvas.draw_arc(Vector2.ZERO,12,0,TAU,24,Color(0.97,0.86,0.64,0.75 if active else 0.5),1.7,true)
		canvas.draw_set_transform(Vector2.ZERO)
