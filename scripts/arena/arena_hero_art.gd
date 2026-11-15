class_name ArenaHeroArt
extends RefCounted
# Art/feedback identities are independent of combat definitions and saved progression.
const MODERN:={
	"knight":{"folder":"v011","base_height":84.0,"badge":Rect2(0.30,0.02,0.46,0.31)},
	"ranger":{"folder":"v012","base_height":80.0,"badge":Rect2(0.25,0.02,0.50,0.35)},
	"mage":{"folder":"v012","base_height":86.0,"badge":Rect2(0.20,0.01,0.60,0.40)}}
static var metadata_cache: Dictionary={}
static func folder(identity: String) -> String:return "res://assets/"+str(MODERN[identity].folder)+"/"
static func atlas(identity: String,view: String,modern:=true) -> String:
	return (folder(identity) if modern else "res://assets/v09/")+identity+"_"+view+".png"
static func metadata(identity: String) -> Dictionary:
	if not metadata_cache.has(identity):
		var path:=folder(identity)+identity+"_frames.json"
		if not FileAccess.file_exists(path):return {}
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:metadata_cache[identity]=parsed
	return metadata_cache.get(identity,{})
static func height(identity: String,modern: bool,multiplier:=1.3) -> float:
	return float(MODERN[identity].base_height)*multiplier if modern else (84.0 if identity=="knight" else 80.0)
static func portrait(identity: String,modern:=true) -> Texture2D:
	return load((folder(identity) if modern else "res://assets/v09/")+"portrait_"+identity+".png")
static func badge(identity: String,modern:=true) -> Rect2:
	if modern:return MODERN[identity].badge
	return {"knight":Rect2(0.46,0.06,0.30,0.22),"ranger":Rect2(0.34,0.06,0.30,0.23),"mage":Rect2(0.40,0.12,0.30,0.23)}[identity]
