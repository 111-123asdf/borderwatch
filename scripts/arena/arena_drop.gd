class_name ArenaDrop
extends Node2D

const WeaponCatalog = preload("res://scripts/arena/arena_weapon_catalog.gd")
const WEAPON_AUTO_COLLECT_SECONDS := 8.0

var game: Node2D
var xp := 0
var gold_value := 0
var big := false
var cache := false
var weapon_key := ""
var camp_name := ""
var age := 0.0
var bob := 0.0

func _process(delta: float) -> void:
	bob += delta * 3.0
	if game.hero == null or game.game_over:
		return
	if not weapon_key.is_empty():
		# Weapon recovery waits while a level-up or other modal pauses combat.
		if not game.running: return
		age += delta
		if age >= WEAPON_AUTO_COLLECT_SECONDS:
			game.collect_drop(self)
			return
	var radius: float = game.hero.pickup_radius
	var distance: float = game.hero.position.distance_to(position)
	if distance < radius:
		var speed := clampf(distance * 3.2, 150.0, 520.0)
		position = position.move_toward(game.hero.position, speed * delta)
	if distance < 18.0:
		game.collect_drop(self)
	queue_redraw()

func _draw() -> void:
	if not weapon_key.is_empty():
		var weapon := WeaponCatalog.get_weapon(weapon_key)
		var color: Color = weapon.get("drop_color", Color("ffe9a6"))
		draw_circle(Vector2(0, sin(bob) * 2.0), 24, Color(color, 0.18))
		draw_arc(Vector2(0, sin(bob) * 2.0), 22, 0, TAU, 24, Color(color, 0.9), 2, true)
		if weapon.has("icon"):
			var icon: Texture2D = weapon.icon
			var icon_size: Vector2 = icon.get_size()
			var scale_factor := minf(36.0 / icon_size.x, 36.0 / icon_size.y)
			var dimensions := icon_size * scale_factor
			draw_texture_rect(icon, Rect2(Vector2(-dimensions.x * 0.5, -dimensions.y * 0.5 + sin(bob) * 2.0), dimensions), false)
		return
	var radius := 11.0 if big else 7.0
	var color := Color("ffd36e") if not big else Color("9fe8d8")
	if cache: color = Color("9fe8d8")
	draw_circle(Vector2(0, sin(bob) * 2.0), radius + 5, Color(color, 0.12))
	draw_circle(Vector2(0, sin(bob) * 2.0), radius, color)
	draw_circle(Vector2(-2, -2 + sin(bob) * 2.0), radius * 0.35, Color("fff6d8"))
	if cache:
		draw_rect(Rect2(-8, -6 + sin(bob) * 2.0, 16, 12), Color("244b48"))
		draw_rect(Rect2(-8, -6 + sin(bob) * 2.0, 16, 12), Color("d7fff2"), false, 2)
	if big:
		draw_arc(Vector2(0, sin(bob) * 2.0), radius + 8, 0, TAU, 24, Color(color, 0.6), 2, true)
