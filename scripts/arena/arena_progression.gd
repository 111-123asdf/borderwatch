class_name ArenaProgression
extends RefCounted
const SAVE_PATH:="user://arena_progression_v2.cfg"
const LEGACY_PATH:="user://arena_progression_v1.cfg"
const HEROES:=["knight","ranger","mage"]
const STAT_KEYS:=["health","cooldown"]
const STAT_CAP:=5
const XP_PER_POINT:=80
const MAX_XP:=800
var entries: Dictionary={}
var persistent:=true
var path: String
var legacy: String
var locked:=false
var migrated:=false
var last_error: String=""
func _init(save_path:=SAVE_PATH,use_persistence:=true,legacy_path:=LEGACY_PATH) -> void:
	path=save_path;legacy=legacy_path;persistent=use_persistence
	for key in HEROES:entries[key]={"xp":0,"health":0,"cooldown":0}
	if persistent:_load()
func entry(key: String) -> Dictionary:return entries.get(key,{"xp":0,"health":0,"cooldown":0}).duplicate()
func points(key: String) -> int:
	var current:=entry(key)
	return maxi(0,int(current.xp)/80-int(current.health)-int(current.cooldown))
func bonuses(key: String) -> Dictionary:
	var current:=entry(key)
	return {"health":float(current.health)*3,"cooldown":float(current.cooldown)*0.02}
static func battle_reward(kills: int,waves: int,won: bool) -> int:return mini(120,maxi(kills,0)+maxi(waves,0)*8+(20 if won else 0))
func grant_experience(key: String,amount: int) -> int:
	if locked or key not in HEROES or amount<=0:return -1
	var candidate:=entries.duplicate(true);var actual:=mini(amount,MAX_XP-int(candidate[key].xp))
	if actual<=0:return 0
	candidate[key].xp+=actual
	if not _save(candidate):return -1
	entries=candidate;return actual
func upgrade(key: String,stat: String) -> bool:
	if locked or key not in HEROES or stat not in STAT_KEYS or points(key)<=0 or int(entries[key][stat])>=5:return false
	var candidate:=entries.duplicate(true);candidate[key][stat]+=1
	if not _save(candidate):return false
	entries=candidate;return true
func _load() -> void:
	var from_legacy:=not FileAccess.file_exists(path) and FileAccess.file_exists(legacy)
	var source: String=legacy if from_legacy else path
	if not FileAccess.file_exists(source):return
	var cfg:=ConfigFile.new()
	if cfg.load(source)!=OK or int(cfg.get_value("meta","version",0))!=(1 if from_legacy else 2):
		locked=true;last_error="成长档案损坏，已停止写入";return
	var candidate: Dictionary={}
	for hero in HEROES:
		var item: Dictionary={}
		for stat in (["xp","health","shield"] if from_legacy else ["xp","health","cooldown"]):
			if not cfg.has_section_key(hero,stat):locked=true;last_error="成长数据不完整";return
			var value: Variant=cfg.get_value(hero,stat,null)
			if typeof(value)!=TYPE_INT:locked=true;last_error="成长数据不完整";return
			item[stat]=value
		var secondary: String="shield" if from_legacy else "cooldown"
		if item.xp<0 or item.xp>800 or item.health<0 or item.health>5 or item[secondary]<0 or item[secondary]>5 or item.health+item[secondary]>int(item.xp)/80:
			locked=true;last_error="成长数据超出范围";return
		candidate[hero]={"xp":item.xp,"health":item.health,"cooldown":0 if from_legacy else item.cooldown}
	if from_legacy:
		if not _save(candidate):locked=true;return
		migrated=true
	entries=candidate
func _save(candidate: Dictionary) -> bool:
	if not persistent:return true
	if locked:return false
	var cfg:=ConfigFile.new();cfg.set_value("meta","version",2)
	for hero in HEROES:
		for stat in ["xp","health","cooldown"]:cfg.set_value(hero,stat,candidate[hero][stat])
	var temporary: String=path+".tmp"
	var error:=cfg.save(temporary)
	if error==OK:error=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))
	if error!=OK:last_error="成长档案写入失败";return false
	last_error="";return true
