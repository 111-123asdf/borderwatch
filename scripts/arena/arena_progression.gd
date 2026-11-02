class_name ArenaProgression
extends RefCounted

# This file is intentionally separate from the older hero_progression.cfg.
const SAVE_PATH := "user://arena_progression_v1.cfg"
const HEROES := ["knight", "ranger", "mage"]
const STAT_KEYS := ["health", "shield"]
const STAT_CAP := 5
const XP_PER_POINT := 80
const MAX_XP := 800

var entries := {}
var persistent := true
var path := SAVE_PATH
var locked := false
var last_error := ""

func _init(save_path := SAVE_PATH, use_persistence := true) -> void:
	path = save_path
	persistent = use_persistence
	for key in HEROES: entries[key] = _default_entry()
	if persistent: _load_profile()

func _default_entry() -> Dictionary:
	return {"xp": 0, "health": 0, "shield": 0}

func entry(key: String) -> Dictionary:
	return entries.get(key, _default_entry()).duplicate()

func points(key: String) -> int:
	var current := entry(key)
	return maxi(0, int(current.xp) / XP_PER_POINT - int(current.health) - int(current.shield))

func bonuses(key: String) -> Dictionary:
	var current := entry(key)
	return {"health": int(current.health) * 3.0, "shield": int(current.shield) * 2.0}

static func battle_reward(kills: int, completed_cycles: int, won: bool) -> int:
	if kills <= 0 and completed_cycles <= 0: return 0
	return mini(120, maxi(0, kills) * 2 + maxi(0, completed_cycles) * 8 + (20 if won else 0))

# Returns the actual experience stored, or -1 if persistence failed.
func grant_experience(key: String, amount: int) -> int:
	if not entries.has(key) or amount <= 0: return 0
	if locked:
		last_error = "成长档案不可用，请先检查存档文件"
		return -1
	var candidate: Dictionary = entries.duplicate(true)
	var current: Dictionary = candidate[key]
	var actual := mini(amount, MAX_XP - int(current.xp))
	if actual <= 0: return 0
	current.xp = int(current.xp) + actual
	candidate[key] = current
	if not _save(candidate): return -1
	entries = candidate
	return actual

func upgrade(key: String, stat: String) -> bool:
	if not entries.has(key) or stat not in STAT_KEYS or locked: return false
	var current: Dictionary = entry(key)
	if points(key) <= 0 or int(current[stat]) >= STAT_CAP: return false
	var candidate: Dictionary = entries.duplicate(true)
	current[stat] = int(current[stat]) + 1
	candidate[key] = current
	if not _save(candidate): return false
	entries = candidate
	return true

func _load_profile() -> void:
	if not FileAccess.file_exists(path): return
	var config := ConfigFile.new()
	if config.load(path) != OK or config.get_value("meta", "version", 0) != 1:
		locked = true
		last_error = "成长档案损坏或版本不兼容，已停止写入"
		return
	var candidate := {}
	for key in HEROES:
		if not config.has_section(key):
			locked = true
			last_error = "成长档案不完整，已停止写入"
			return
		var current := _default_entry()
		for field in current:
			var value: Variant = config.get_value(key, field, null)
			if typeof(value) != TYPE_INT:
				locked = true
				last_error = "成长档案数据异常，已停止写入"
				return
			current[field] = value
		if int(current.xp) < 0 or int(current.xp) > MAX_XP or int(current.health) < 0 or int(current.health) > STAT_CAP or int(current.shield) < 0 or int(current.shield) > STAT_CAP or int(current.health) + int(current.shield) > int(current.xp) / XP_PER_POINT:
			locked = true
			last_error = "成长档案数据超出范围，已停止写入"
			return
		candidate[key] = current
	entries = candidate

func _save(candidate: Dictionary) -> bool:
	if not persistent:
		last_error = ""
		return true
	if locked:
		last_error = "成长档案不可用，请先检查存档文件"
		return false
	var config := ConfigFile.new()
	config.set_value("meta", "version", 1)
	for key in HEROES:
		for field in _default_entry(): config.set_value(key, field, candidate[key][field])
	var temporary := path + ".tmp"
	var error := config.save(temporary)
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if error != OK:
		last_error = "成长档案写入失败（%d）" % error
		return false
	last_error = ""
	return true
