class_name ArenaCampaign
extends RefCounted

const SAVE_PATH:="user://campaign_v3.cfg"
const PLAYTEST_PATH:="user://playtest_v013.cfg"
const TOWER_TRIAL_PATH:="user://tower_lab_v020.cfg"
const PLAYTEST_GEMS:=9999
const COSTS:=[0,2,3,4,7]
const HP:=[0.0,0.0,0.03,0.03,0.06,0.12]
const ATTACK:=[0.0,0.0,0.0,0.03,0.03,0.09]
const DEFAULT_KEYBINDS:={"dodge":KEY_V,"recall":KEY_R,"portal":KEY_T}
var data: Dictionary={"gems":0,"levels":{"lord":1,"druid":1,"healer":1,"werewolf":1,"gunner":1},"cleared":{"forest":false,"creek":false,"saltport":false,"lighthouse":false,"ruins":false,"sanctum":false},"last_run":"","settled":{},"tutorial_done":false,"volume":0.8,"reduced_motion":false,"selected_hero":"lord","equipped_towers":["archer","mage","cannon","barracks"],"keybinds":{"dodge":KEY_V,"recall":KEY_R,"portal":KEY_T}}
var path: String
var persistent: bool
var locked:=false
var last_error:=""
static func playtest(save_path:=PLAYTEST_PATH) -> ArenaCampaign:
	# A separate opt-in preview profile. Never reads, migrates or overwrites normal saves.
	var profile:=ArenaCampaign.new(save_path,true)
	if not profile.locked:profile.data.gems=maxi(PLAYTEST_GEMS,profile.gems())
	return profile
func _init(save_path:=SAVE_PATH,persist:=true) -> void:
	path=save_path;persistent=persist
	if persistent:_load()
func gems() -> int:return int(data.gems)
func selected_hero() -> String:return ArenaDefinitions.resolve_hero_id(str(data.get("selected_hero","lord")))
func tower_loadout() -> Array[String]:
	var result: Array[String]=[]
	for key in data.get("equipped_towers",ArenaDefinitions.DEFAULT_TOWERS):result.append(str(key))
	return result
func tower_doctrine(kind: String) -> String:
	var choices: Dictionary = data.get("tower_doctrines",{})
	return str(choices.get(kind,ArenaDoctrines.AUTO_DEFAULT.get(kind,"")))
func select_tower_doctrine(kind: String, doctrine_id: String) -> bool:
	if locked or not ArenaDoctrines.is_for_tower(kind,doctrine_id):
		return false
	var candidate := data.duplicate(true)
	var choices: Dictionary = candidate.get("tower_doctrines",{})
	choices[kind] = doctrine_id
	candidate.tower_doctrines = choices
	return _commit(candidate)
func select_hero(hero_id: String) -> bool:
	if locked or not ArenaDefinitions.is_valid_hero_id(hero_id):return false
	var resolved := ArenaDefinitions.resolve_hero_id(hero_id)
	var candidate:=data.duplicate(true);candidate.selected_hero=resolved
	return _commit(candidate)
func equip_towers(keys: Array) -> bool:
	if locked or not _valid_towers(keys):return false
	var candidate:=data.duplicate(true);candidate.equipped_towers=keys.duplicate()
	return _commit(candidate)
func can_deploy(stage: String,defense:=false) -> bool:
	if stage not in ArenaLevelCatalog.IDS:return false
	var definition:=ArenaLevelCatalog.definition(stage)
	for key in tower_loadout():
		if (defense and stage=="forest") or int(definition.towers.get(key,99))<=1:return true
	return false
func _valid_towers(keys: Variant) -> bool:
	if typeof(keys)!=TYPE_ARRAY or keys.is_empty() or keys.size()>ArenaDefinitions.LOADOUT_LIMIT:return false
	var seen: Dictionary={}
	for key in keys:
		if typeof(key)!=TYPE_STRING or key not in ArenaDefinitions.TOWER_IDS or seen.has(key):return false
		seen[key]=true
	return true
func level(hero_id: String) -> int:return int(data.levels.get(ArenaDefinitions.resolve_hero_id(hero_id),1))
func price(hero_id: String) -> int:
	var current:=level(hero_id)
	return int(COSTS[current]) if current<5 else 0
func bonuses(hero_id: String) -> Dictionary:
	var rank:=level(hero_id)
	return {"health":HP[rank],"attack":ATTACK[rank],"passive":2 if rank==5 else (1 if rank>=3 else 0)}
func skill_unlocked(hero_id: String,slot: int) -> bool:
	return slot in [0,1] and level(hero_id)>=ArenaDefinitions.SKILL_UNLOCK_LEVELS[slot]
func upgrade(hero_id: String) -> bool:
	if locked or not ArenaDefinitions.is_valid_hero_id(hero_id):return false
	var resolved := ArenaDefinitions.resolve_hero_id(hero_id)
	if level(resolved)>=5 or gems()<price(resolved):return false
	var candidate:=data.duplicate(true)
	candidate.gems-=price(resolved);candidate.levels[resolved]+=1
	return _commit(candidate)
func victory_reward(stage: String) -> int:
	return 6 if bool(data.cleared.get(stage,false)) else 8
func settle(run_id: String,stage: String,won: bool,completed: int) -> Dictionary:
	if locked:return {"ok":false,"amount":0,"error":last_error}
	var max_waves := ArenaLevelCatalog.total_waves(stage)
	if run_id=="" or stage not in ArenaLevelCatalog.IDS or completed<0 or completed>max_waves or (won and completed!=max_waves):return {"ok":false,"amount":0,"error":"无效结算"}
	if data.settled.has(run_id):return {"ok":true,"amount":0,"duplicate":true}
	var ratio := float(completed) / float(maxi(1, max_waves))
	var amount: int=victory_reward(stage) if won else (3 if ratio>=0.75 else (2 if ratio>=0.50 else 0))
	var first: bool=won and not bool(data.cleared.get(stage,false))
	var candidate:=data.duplicate(true)
	candidate.gems+=amount;candidate.last_run=run_id;candidate.settled[run_id]=amount
	if won:candidate.cleared[stage]=true
	if not _commit(candidate):return {"ok":false,"amount":0,"error":last_error}
	return {"ok":true,"amount":amount,"first_clear":first}
func settings(volume: float,reduced: bool,bindings: Dictionary={}) -> bool:
	var candidate:=data.duplicate(true);candidate.volume=clampf(volume,0,1);candidate.reduced_motion=reduced
	if not bindings.is_empty():candidate.keybinds=bindings.duplicate()
	return _commit(candidate)
func keybind(action: String) -> int:
	var kb: Dictionary=data.get("keybinds",DEFAULT_KEYBINDS)
	return int(kb.get(action,DEFAULT_KEYBINDS.get(action,KEY_V)))
func keybind_label(action: String) -> String:
	return format_keybind(keybind(action))
static func format_keybind(code: int) -> String:
	if code==KEY_SPACE:return "Space"
	if code==KEY_SHIFT:return "Shift"
	var txt:=OS.get_keycode_string(code)
	return txt if not txt.is_empty() else "V"
func set_keybind(action: String,code: int) -> bool:
	if locked or not DEFAULT_KEYBINDS.has(action) or code<=0:return false
	var candidate:=data.duplicate(true)
	var kb: Dictionary=candidate.get("keybinds",DEFAULT_KEYBINDS.duplicate()).duplicate()
	kb[action]=code
	candidate.keybinds=kb
	return _commit(candidate)
func complete_tutorial() -> bool:
	var candidate:=data.duplicate(true);candidate.tutorial_done=true
	return _commit(candidate)
func _migrate_heroes(candidate: Dictionary) -> void:
	if candidate.get("levels") is Dictionary:
		var old_levels: Dictionary = candidate.levels
		var new_levels: Dictionary = {}
		for hid in ArenaDefinitions.HERO_IDS:
			new_levels[hid] = old_levels.get(hid, 1)
		for legacy in ArenaDefinitions.HERO_ALIASES:
			var target_id: String = ArenaDefinitions.HERO_ALIASES[legacy]
			if old_levels.has(legacy) and not old_levels.has(target_id):
				new_levels[target_id] = old_levels[legacy]
		candidate.levels = new_levels
	candidate.selected_hero = ArenaDefinitions.resolve_hero_id(str(candidate.get("selected_hero","lord")))
func _valid(candidate: Dictionary) -> bool:
	if candidate.get("selected_hero","lord") not in ArenaDefinitions.HERO_IDS or not _valid_towers(candidate.get("equipped_towers",ArenaDefinitions.DEFAULT_TOWERS)):return false
	if typeof(candidate.get("gems"))!=TYPE_INT or candidate.gems<0 or candidate.gems>1000000000:return false
	if typeof(candidate.get("levels"))!=TYPE_DICTIONARY or typeof(candidate.get("cleared"))!=TYPE_DICTIONARY:return false
	for key in ArenaDefinitions.HERO_IDS:
		if typeof(candidate.levels.get(key))!=TYPE_INT or candidate.levels[key]<1 or candidate.levels[key]>5:return false
	for key in ArenaLevelCatalog.IDS:
		if key in ["forest","creek"]:
			if typeof(candidate.cleared.get(key))!=TYPE_BOOL:return false
		elif candidate.cleared.has(key) and typeof(candidate.cleared.get(key))!=TYPE_BOOL:
			return false
	if candidate.has("keybinds"):
		if typeof(candidate.keybinds)!=TYPE_DICTIONARY:return false
		for act in DEFAULT_KEYBINDS:
			if candidate.keybinds.has(act) and (typeof(candidate.keybinds[act])!=TYPE_INT or int(candidate.keybinds[act])<=0):
				return false
	var choices: Variant = candidate.get("tower_doctrines",{})
	if not choices is Dictionary:
		return false
	for kind in choices:
		if not kind is String or not choices[kind] is String or not ArenaDoctrines.is_for_tower(kind,choices[kind]):
			return false
	return typeof(candidate.get("settled"))==TYPE_DICTIONARY and typeof(candidate.get("last_run"))==TYPE_STRING and typeof(candidate.get("volume"))==TYPE_FLOAT and is_finite(candidate.volume) and candidate.volume>=0 and candidate.volume<=1 and typeof(candidate.get("reduced_motion"))==TYPE_BOOL
func _commit(candidate: Dictionary) -> bool:
	for key in ArenaLevelCatalog.IDS:
		if not candidate.cleared.has(key):candidate.cleared[key]=false
	if not candidate.has("keybinds") or not (candidate.keybinds is Dictionary):
		candidate.keybinds=DEFAULT_KEYBINDS.duplicate()
	else:
		for act in DEFAULT_KEYBINDS:
			if not candidate.keybinds.has(act):candidate.keybinds[act]=DEFAULT_KEYBINDS[act]
	if locked or not _valid(candidate):last_error="养成数据无效，未写入";return false
	if persistent:
		var cfg:=ConfigFile.new();cfg.set_value("campaign","version",3);cfg.set_value("campaign","data",candidate)
		var temporary:=path+".tmp"
		var error:=cfg.save(temporary)
		if error==OK:error=DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(path))
		if error!=OK:last_error="保存失败，尚未扣费或入账，请重试";return false
	data=candidate;last_error="";return true
func _load() -> void:
	if not FileAccess.file_exists(path):return
	var cfg:=ConfigFile.new()
	if cfg.load(path)!=OK or cfg.get_value("campaign","version",0)!=3:
		locked=true;last_error="养成存档无法读取，原文件已保留";return
	var candidate: Variant=cfg.get_value("campaign","data",null)
	if candidate is Dictionary:
		_migrate_heroes(candidate)
	if typeof(candidate)!=TYPE_DICTIONARY or not _valid(candidate):
		locked=true;last_error="养成存档数据异常，原文件已保留";return
	data=candidate.duplicate(true)
	if not data.has("selected_hero"):data.selected_hero="lord"
	if not data.has("equipped_towers"):data.equipped_towers=ArenaDefinitions.DEFAULT_TOWERS.duplicate()
	if not data.has("keybinds") or not (data.keybinds is Dictionary):
		data.keybinds=DEFAULT_KEYBINDS.duplicate()
	else:
		for act in DEFAULT_KEYBINDS:
			if not data.keybinds.has(act):data.keybinds[act]=DEFAULT_KEYBINDS[act]
	for key in ArenaLevelCatalog.IDS:
		if not data.cleared.has(key):data.cleared[key]=false
