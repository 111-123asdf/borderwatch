class_name Art
extends RefCounted

const ROOT := "res://assets/tiny_swords/Tiny Swords (Update 010)/"
static var cache: Dictionary = {}

static func texture(relative_path: String) -> Texture2D:
	if not cache.has(relative_path):
		cache[relative_path] = load(ROOT + relative_path)
	return cache[relative_path]

static func sprite(relative_path: String, dimensions := Vector2i.ONE, frame_index := 0) -> Sprite2D:
	var visual := Sprite2D.new()
	visual.texture = texture(relative_path)
	visual.hframes = dimensions.x
	visual.vframes = dimensions.y
	visual.frame = frame_index
	return visual
