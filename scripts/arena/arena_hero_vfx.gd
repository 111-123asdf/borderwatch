class_name ArenaHeroVFX
extends RefCounted
static var cache: Dictionary={}
static func frame(hero: String,row: int,column: int) -> Texture2D:
	var key:=hero+str(row)+str(column)
	if not cache.has(key):
		var path: String="res://assets/v012/"+hero+"_fx.png"
		if not ResourceLoader.exists(path):return null
		var sheet: Texture2D=load(path);var image:=AtlasTexture.new();image.atlas=sheet
		var cell:=sheet.get_size()/4.0;image.region=Rect2(Vector2(column,row)*cell,cell);image.filter_clip=true;cache[key]=image
	return cache[key]
