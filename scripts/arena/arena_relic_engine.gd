class_name ArenaRelicEngine
extends RefCounted
## Cross-Domain Rift Relic & Forge Enhancement Engine (v0.32).
## Caps at MAX_RELICS = 6 so deep multi-floor diving stays balanced yet addictive,
## directly linking Rift dungeon exploration to Defense tower power & Hero scaling.

const MAX_RELICS := 6

const RELICS := {
	"ember_ordnance": {
		"id": "ember_ordnance", "name": "余烬弹药箱", "tag": "塔防联动",
		"desc": "全防御塔攻击附加灼烧（26/秒，持续3秒），溅射范围 +15%",
		"icon": "res://assets/ui_v032/relic_ember_ordnance.png"
	},
	"chrono_prism": {
		"id": "chrono_prism", "name": "时序棱镜", "tag": "双域急速",
		"desc": "全防御塔攻速 +18%；英雄主动技能与闪避冷却 -15%",
		"icon": "res://assets/ui_v032/relic_chrono_prism.png"
	},
	"orbital_beacon": {
		"id": "orbital_beacon", "name": "星穹支援信标", "tag": "回防震击",
		"desc": "每次从裂隙瞬回防线 [R]，自动朝防线最前锋敌群降下天基激光",
		"icon": "res://assets/ui_v032/relic_orbital_beacon.png"
	},
	"aegis_reactor": {
		"id": "aegis_reactor", "name": "圣盾反应堆", "tag": "护盾联动",
		"desc": "裂隙每击杀 12 只怪物，自动为基地充能 +25 圣盾并恢复英雄 5% 生命",
		"icon": "res://assets/ui_v032/relic_aegis_reactor.png"
	},
	"chain_detonator": {
		"id": "chain_detonator", "name": "晶核引爆器", "tag": "爆裂割草",
		"desc": "爆裂水晶桶伤害 +60%，且英雄每击杀 8 敌在目标点引爆 120 范围紫晶震波",
		"icon": "res://assets/ui_v032/relic_chain_detonator.png"
	},
	"titan_breaker": {
		"id": "titan_breaker", "name": "巨兽破甲徽", "tag": "首领克星",
		"desc": "英雄与全防御塔对精英、小首领和关底 Boss 的伤害提升 +28%",
		"icon": "res://assets/ui_v032/relic_titan_breaker.png"
	},
	"vampiric_chalice": {
		"id": "vampiric_chalice", "name": "猩红圣杯", "tag": "战神续航",
		"desc": "英雄最大生命 +22%、伤害 +15%，击杀敌人缩减大招冷却 0.35 秒",
		"icon": "res://assets/ui_v032/relic_vampiric_chalice.png"
	},
	"gilded_compass": {
		"id": "gilded_compass", "name": "鎏金罗盘", "tag": "财富加速",
		"desc": "双域金币与经验获取 +30%，防线提前召潮 [F] 赏金额外 +50%",
		"icon": "res://assets/ui_v032/relic_gilded_compass.png"
	},
}

const ORDER := [
	"ember_ordnance", "chrono_prism", "orbital_beacon", "aegis_reactor",
	"chain_detonator", "titan_breaker", "vampiric_chalice", "gilded_compass"
]

var game: Node2D
var owned: Array[String] = []
var forge_tower_power_bonus: float = 0.0
var forge_tower_speed_bonus: float = 0.0
var altar_hero_dmg_bonus: float = 0.0

var _rift_kill_counter: int = 0
var _detonator_kill_counter: int = 0
var _proc_guard: int = 0


func bind(owner_game: Node2D, bus: ArenaEventBus) -> void:
	game = owner_game
	if bus == null:
		return
	bus.subscribe("enemy_killed", _on_enemy_killed)
	bus.subscribe("domain_recall", _on_domain_recall)


func reset() -> void:
	owned.clear()
	forge_tower_power_bonus = 0.0
	forge_tower_speed_bonus = 0.0
	altar_hero_dmg_bonus = 0.0
	_rift_kill_counter = 0
	_detonator_kill_counter = 0
	_proc_guard = 0


func has_relic(id: String) -> bool:
	return id in owned


func can_add_relic() -> bool:
	return owned.size() < MAX_RELICS


func grant_relic(id: String) -> bool:
	if not RELICS.has(id) or id in owned or owned.size() >= MAX_RELICS:
		return false
	owned.append(id)
	if is_instance_valid(game) and is_instance_valid(game.hero):
		game.hero.recompute()
		var spec: Dictionary = RELICS[id]
		game.numbers.append({
			"point": game.hero.center() + Vector2(0.0, -44.0),
			"text": "★ 遗物·" + str(spec.name) + "!",
			"colour": Color("ffe678"),
			"life": 1.30,
			"duration": 1.30,
			"critical": true
		})
		game.effect(game.hero.position, 64.0, Color("ffe678"), "upgrade", 0.45)
	if is_instance_valid(game) and is_instance_valid(game.hud) and game.hud.has_method("refresh_owned_relics"):
		game.hud.refresh_owned_relics()
	return true


func grant_random_relic(rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[String] = []
	for id: String in ORDER:
		if id not in owned:
			pool.append(id)
	if pool.is_empty() or owned.size() >= MAX_RELICS:
		return {}
	var pick := str(pool[rng.randi_range(0, pool.size() - 1)])
	if grant_relic(pick):
		return RELICS[pick].duplicate(true)
	return {}


func owned_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in owned:
		if RELICS.has(id):
			out.append(RELICS[id].duplicate(true))
	return out


func tower_speed_bonus() -> float:
	return forge_tower_speed_bonus + (0.18 if has_relic("chrono_prism") else 0.0)


func tower_power_mult() -> float:
	return 1.0 + forge_tower_power_bonus


func tower_splash_mult() -> float:
	return 1.15 if has_relic("ember_ordnance") else 1.0


func tower_burn_dps() -> float:
	return 26.0 if has_relic("ember_ordnance") else 0.0


func hero_damage_mult() -> float:
	return 1.0 + altar_hero_dmg_bonus + (0.15 if has_relic("vampiric_chalice") else 0.0)


func hero_max_hp_mult() -> float:
	return 1.22 if has_relic("vampiric_chalice") else 1.0


func hero_cd_scale() -> float:
	return 0.85 if has_relic("chrono_prism") else 1.0


func boss_elite_damage_mult(enemy: Node2D) -> float:
	if not has_relic("titan_breaker") or not is_instance_valid(enemy):
		return 1.0
	if enemy.elite or enemy.is_boss() or (enemy.has_method("is_mini_boss") and enemy.is_mini_boss()):
		return 1.28
	return 1.0


func gold_xp_mult() -> float:
	return 1.30 if has_relic("gilded_compass") else 1.0


func early_wave_bonus_mult() -> float:
	return 1.50 if has_relic("gilded_compass") else 1.0


func barrel_damage_mult() -> float:
	return 1.60 if has_relic("chain_detonator") else 1.0


func _on_enemy_killed(payload: Dictionary) -> void:
	if _proc_guard > 0 or game == null or game.game_over or not is_instance_valid(game.hero):
		return
	var dom := str(payload.get("domain", "defense"))
	var pos: Vector2 = payload.get("position", game.hero.position)
	var hero: ArenaHero = game.hero

	if has_relic("aegis_reactor") and dom == "rift":
		_rift_kill_counter += 1
		if _rift_kill_counter >= 12:
			_rift_kill_counter = 0
			game.add_core_shield(25.0)
			if not hero.knocked_out:
				hero._heal_self(hero.max_health * 0.05, true)
			game.numbers.append({
				"point": hero.center() + Vector2(0.0, -32.0),
				"text": "圣盾反应堆 +25盾!",
				"colour": Color("7fe8ff"),
				"life": 0.90,
				"duration": 0.90
			})

	if has_relic("vampiric_chalice"):
		hero.cooldowns[1] = maxf(0.0, hero.cooldowns[1] - 0.35)

	if has_relic("chain_detonator"):
		_detonator_kill_counter += 1
		if _detonator_kill_counter >= 8:
			_detonator_kill_counter = 0
			_proc_guard += 1
			game.area_damage(pos, 120.0, hero.attack_damage() * 1.45, 1, "hero", 0.25, 0.0, 0.2, 0.0, "relic_blast", true, {"domain": dom, "passive_proc": true})
			_proc_guard -= 1
			game.effect(pos, 110.0, Color("c474ff"), "blast", 0.30)


func _on_domain_recall(_payload: Dictionary) -> void:
	if game == null or game.game_over or not is_instance_valid(game.hero):
		return
	if not has_relic("orbital_beacon"):
		return
	var best_e: Node2D = null
	var best_p := -1.0
	for e in game.domain_enemies("defense"):
		if is_instance_valid(e) and not e.dead and not e.is_guard and float(e.progress) > best_p:
			best_p = float(e.progress)
			best_e = e
	if best_e != null and game.passive_engine != null:
		game.passive_engine.active_beams.append({
			"pos": best_e.position,
			"target": best_e,
			"life": 1.60,
			"duration": 1.60,
			"tick": 0.0,
			"radius": 88.0,
			"damage": game.hero.attack_damage() * 0.95,
			"domain": "defense",
			"evo": true
		})
		game.numbers.append({
			"point": best_e.position + Vector2(0.0, -36.0),
			"text": "★ 支援信标天基扫射!",
			"colour": Color("ffe678"),
			"life": 1.05,
			"duration": 1.05,
			"critical": true
		})
		game.audio.play("phase", -9.0, 1.35)
