class_name ArenaHeroArt
extends RefCounted
# Pixel-art v022 hero atlas & portrait bindings.
const POSE_ROOT := "res://assets/heroes_v022/"
const HEIGHTS := {
	"lord": 94.0,
	"druid": 84.0,
	"healer": 84.0,
	"werewolf": 88.0,
	"werewolf_beast": 94.0,
	"gunner": 82.0,
	"frost_wolf": 58.0,
	"ember_wolf": 58.0,
}

static func pose_atlas(identity: String, view: String) -> String:
	var key := identity if HEIGHTS.has(identity) else ArenaDefinitions.resolve_hero_id(identity)
	return POSE_ROOT + key + "_" + view + ".png"

static func height(identity: String, modern := true, multiplier := 1.3) -> float:
	var key := identity if HEIGHTS.has(identity) else ArenaDefinitions.resolve_hero_id(identity)
	var base: float = float(HEIGHTS.get(key, 84.0))
	return base * multiplier / 1.3 if modern else base * 0.92

static func portrait(identity: String) -> Texture2D:
	var key := ArenaDefinitions.resolve_hero_id(identity)
	return load(POSE_ROOT + "portrait_" + key + ".png")

static func small_portrait(identity: String) -> Texture2D:
	var key := ArenaDefinitions.resolve_hero_id(identity)
	var small_path := POSE_ROOT + "portrait_" + key + "_small.png"
	if ResourceLoader.exists(small_path):
		return load(small_path)
	return portrait(key)
