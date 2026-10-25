class_name ArenaMinimap
extends Control

var game

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game == null:
		return
	var pad := 10.0
	var inner := size - Vector2(pad * 2.0, pad * 2.0 + 22.0)
	var arena: Vector2 = game.ARENA_SIZE
	var scale_factor := minf(inner.x / arena.x, inner.y / arena.y)
	var origin := Vector2(pad, pad + 22.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.09, 0.08, 0.78))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.62, 0.75, 0.65, 0.55), false, 1.5)
	draw_string(ThemeDB.fallback_font, Vector2(10, 18), "小地图  热点 %s" % game._region_name(game.hot_region), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d6bd7a"))
	var map_rect := Rect2(origin, arena * scale_factor)
	draw_rect(map_rect, Color(0.16, 0.27, 0.21, 0.9))
	draw_rect(map_rect, Color(0.45, 0.62, 0.50, 0.35), false, 1)
	for warning in game.spawn_warnings:
		var point: Vector2 = origin + warning.point * scale_factor
		draw_arc(point, 8.0, 0, TAU, 20, Color(1.0, 0.45, 0.28, 0.85), 2.0, true)
	for tower in game.towers:
		if is_instance_valid(tower):
			draw_rect(Rect2(origin + tower.position * scale_factor - Vector2(2, 2), Vector2(4, 4)), Color("9fe8d8"))
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var color := Color("ffda78") if enemy.elite else Color("ff8064")
		var dot := 3.0 if enemy.kind == "boss" else (2.0 if enemy.elite else 1.4)
		draw_circle(origin + enemy.position * scale_factor, dot, color)
	if game.hero != null:
		var hero_point: Vector2 = origin + game.hero.position * scale_factor
		draw_circle(hero_point, 4.5, Color("8be8ff"))
		draw_arc(hero_point, 7.5, 0, TAU, 16, Color("8be8ff"), 1.5, true)
	var core_point: Vector2 = origin + game.CORE * scale_factor
	draw_circle(core_point, 5.0, Color("ffd36e"))
	draw_arc(core_point, 8.0, 0, TAU, 16, Color("fff0bd"), 1.5, true)
