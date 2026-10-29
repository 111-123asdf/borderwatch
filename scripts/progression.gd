class_name HeroProgression
extends RefCounted

const SAVE_PATH := "user://hero_progression.cfg"
const STAT_KEYS := ["health", "shield", "energy", "damage"]
const STAT_CAP := 10

var heroes := {}
var persistent := true

func _init(load_from_disk := true) -> void:
	persistent = load_from_disk
	for key in Rules.HEROES:
		heroes[key] = _default_entry()
	if persistent: load_profile()

func _default_entry() -> Dictionary:
	return {"level": 1, "xp": 0, "points": 0, "health": 0, "shield": 0, "energy": 0, "damage": 0}

func entry(hero_id: String) -> Dictionary:
	return heroes.get(hero_id, _default_entry())

func experience_target(hero_id: String) -> int:
	return 80 + (int(entry(hero_id).level) - 1) * 40

func bonuses(hero_id: String) -> Dictionary:
	var current := entry(hero_id)
	return {
		"health": int(current.health) * 6.0,
		"shield": int(current.shield) * 4.0,
		"energy": int(current.energy) * 6.0,
		"damage": int(current.damage) * 0.04,
	}

func grant_experience(hero_id: String, amount: int) -> int:
	if not heroes.has(hero_id) or amount <= 0: return 0
	var current: Dictionary = heroes[hero_id]
	current.xp = int(current.xp) + amount
	var levels := 0
	while int(current.xp) >= 80 + (int(current.level) - 1) * 40:
		current.xp -= 80 + (int(current.level) - 1) * 40
		current.level += 1
		current.points += 1
		levels += 1
	heroes[hero_id] = current
	save_profile()
	return levels

func upgrade(hero_id: String, stat: String) -> bool:
	if not heroes.has(hero_id) or stat not in STAT_KEYS: return false
	var current: Dictionary = heroes[hero_id]
	if int(current.points) <= 0 or int(current[stat]) >= STAT_CAP: return false
	current.points -= 1
	current[stat] = int(current[stat]) + 1
	heroes[hero_id] = current
	save_profile()
	return true

func load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK: return
	for hero_id in Rules.HEROES:
		var current := _default_entry()
		for field in current:
			current[field] = maxi(0, int(config.get_value(hero_id, field, current[field])))
		current.level = maxi(1, int(current.level))
		for stat in STAT_KEYS: current[stat] = mini(STAT_CAP, int(current[stat]))
		heroes[hero_id] = current

func save_profile() -> void:
	if not persistent: return
	var config := ConfigFile.new()
	for hero_id in heroes:
		var current: Dictionary = heroes[hero_id]
		for field in current: config.set_value(hero_id, field, current[field])
	config.save(SAVE_PATH)
