class_name ArenaDrop
extends Node2D

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
	age += delta
	bob += delta * 3.0
	if game.hero == null or game.game_over:
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
	var radius := 11.0 if big else 7.0
	var color := Color("ffd36e") if not big else Color("9fe8d8")
	if cache: color = Color("9fe8d8")
	draw_circle(Vector2(0, sin(bob) * 2.0), radius + 5, Color(color, 0.12))
	draw_circle(Vector2(0, sin(bob) * 2.0), radius, color)
	draw_circle(Vector2(-2, -2 + sin(bob) * 2.0), radius * 0.35, Color("fff6d8"))
	if cache:
		draw_rect(Rect2(-8, -6 + sin(bob) * 2.0, 16, 12), Color("244b48"))
		draw_rect(Rect2(-8, -6 + sin(bob) * 2.0, 16, 12), Color("d7fff2"), false, 2)
	if weapon_key != "":
		draw_arc(Vector2(0, sin(bob) * 2.0), radius + 12, 0, TAU, 24, Color("ffe9a6"), 2, true)
	if big:
		draw_arc(Vector2(0, sin(bob) * 2.0), radius + 8, 0, TAU, 24, Color(color, 0.6), 2, true)
