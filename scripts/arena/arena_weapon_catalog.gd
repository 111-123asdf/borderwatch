class_name ArenaWeaponCatalog
extends RefCounted

# Only weapons with implemented arena behavior belong here. Legacy Rules remains
# a separate source for the old mode and is unchanged by arena changes.
const IDS := ["pistol", "bow", "scatter", "sniper"]
const WEAPONS := {
	"pistol": {"damage": 24.0, "interval": 0.32, "reach": 620.0, "color": Color("f6d28b"), "name": "铜雀手枪", "tiers": ["铜雀手枪", "铜雀·连发", "铜雀·风暴"], "icon": preload("res://assets/original/weapon_pistol.png"), "hand_texture": preload("res://assets/original/weapon_pistol.png"), "hand_rect": Rect2(-23, -17, 48, 32), "attack_type": "straight", "projectile_speed": 900.0, "base_pierce": 0, "projectile_count": 1, "spread": 0.0, "distance": 800.0, "shot_spacing": 22.0, "drop_color": Color("ffe9a6")},
	"bow": {"damage": 22.0, "interval": 0.22, "reach": 650.0, "color": Color("e8d699"), "name": "疾风连弓", "tiers": ["疾风连弓", "疾风·贯羽", "疾风·箭雨"], "icon": preload("res://assets/original/ranger_bow_preview.png"), "hand_texture": preload("res://assets/original/ranger_bow_preview.png"), "hand_rect": Rect2(-26, -19, 52, 38), "attack_type": "straight", "projectile_speed": 900.0, "base_pierce": 0, "projectile_count": 1, "spread": 0.0, "distance": 800.0, "shot_spacing": 22.0, "drop_color": Color("ffe9a6")},
	"scatter": {"damage": 14.0, "interval": 0.48, "reach": 530.0, "color": Color("a9e8ef"), "name": "群星法杖", "tiers": ["群星法杖", "群星·散射", "群星·星环"], "icon": preload("res://assets/original/weapon_scatter.png"), "hand_texture": preload("res://assets/original/weapon_scatter.png"), "hand_rect": Rect2(-30, -14, 62, 28), "attack_type": "spread", "projectile_speed": 900.0, "base_pierce": 0, "projectile_count": 5, "spread": 0.32, "distance": 800.0, "dual_offset": 10.0, "drop_color": Color("ffe9a6")},
	"sniper": {"damage": 105.0, "interval": 1.1, "reach": 850.0, "color": Color("b2e7df"), "name": "远星狙击", "tiers": ["远星狙击", "远星·贯星", "远星·破晓"], "icon": preload("res://assets/original/weapon_sniper.png"), "hand_texture": preload("res://assets/original/weapon_sniper.png"), "hand_rect": Rect2(-36, -16, 74, 32), "attack_type": "piercing", "projectile_speed": 1100.0, "base_pierce": 3, "projectile_count": 1, "spread": 0.0, "distance": 800.0, "dual_offset": 10.0, "drop_color": Color("b2e7df")},
}

static func get_weapon(key: String) -> Dictionary:
	if not WEAPONS.has(key): return {}
	var definition: Dictionary = WEAPONS[key].duplicate(true)
	definition["id"] = key
	return definition
