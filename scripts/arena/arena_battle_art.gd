class_name ArenaBattleArt
extends Node2D
const FOOTPRINT:=Vector2(96,48)
const HEIGHTS:={"archer":[110.0,137.0,163.0],"mage":[115.0,142.0,168.0],"cannon":[65.0,85.0,110.0],"barracks":[87.0,109.0,132.0]}
const WIDTHS:={"archer":[0.72,0.74,0.87],"mage":[0.74,0.76,0.90],"cannon":[0.74,0.74,0.88],"barracks":[0.76,0.76,0.90]}
const CONTACT:=[0.79,0.80,0.87]
var game: ArenaGame
var pad: Texture2D
static func map_path(key: String) -> String:
	return "res://assets/v09/map_"+key+".png"
static func towers_path() -> String:
	return "res://assets/v09/towers.png"
static func contact(kind: String,tier: int,cell: Vector2) -> Dictionary:
	return {"uv":Vector2(0.5,CONTACT[tier-1]),"scale":Vector2(FOOTPRINT.x/(cell.x*float(WIDTHS[kind][tier-1])),float(HEIGHTS[kind][tier-1])/(cell.y*(CONTACT[tier-1]-0.05)))}
func _ready() -> void:
	z_index=-10
	if ResourceLoader.exists("res://assets/v09/site_pad.png"):
		var atlas:=AtlasTexture.new();atlas.atlas=load("res://assets/v09/site_pad.png");atlas.region=Rect2(164,314,1276,443);pad=atlas
func _process(_delta: float) -> void:queue_redraw()
func _draw() -> void:
	if not game.started:return
	for index in range(game.level_definition.sites.size()):
		var point: Vector2=game.level_definition.sites[index]
		var occupied:=game.site_tower(index)!=null
		draw_set_transform(point+Vector2(2,5),0,Vector2(1,0.33))
		draw_circle(Vector2.ZERO,43,Color(0.12,0.16,0.07,0.10 if not occupied else 0.17))
		draw_set_transform(Vector2.ZERO)
		if not occupied:
			if pad!=null:draw_texture_rect(pad,Rect2(point-FOOTPRINT*0.5,FOOTPRINT),false,Color(0.72,0.73,0.66) if game.site_locked(index) else Color.WHITE)
			else:
				draw_set_transform(point,0,Vector2(1,0.60));draw_circle(Vector2.ZERO,47,Color("a38e65"));draw_circle(Vector2.ZERO,40,Color("b99d70"));draw_set_transform(Vector2.ZERO)
