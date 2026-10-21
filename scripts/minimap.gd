extends Control

var game: Node2D

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var offset := Vector2(10, 10)
	var map_size := size - Vector2(20, 20)
	var factor := map_size / Rules.WORLD_SIZE
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	for route in Rules.PATHS:
		var points := PackedVector2Array()
		for point in route:
			points.append(offset + point * factor)
		draw_polyline(points, Color("9f9373"), 3, true)
	draw_arc(offset + Rules.CORE * factor, 490 * factor.x, 0, TAU, 48, Color(0.65, 0.8, 0.7, 0.2), 1, true)
	draw_circle(offset + Rules.CORE * factor, 5, Color("87e5d9"))
	for tower in game.towers:
		draw_circle(offset + tower.position * factor, 2.5, Rules.TOWERS[tower.kind].color)
	for camp_index in range(3):
		var previous: Vector2 = Rules.CORE
		for node_index in range(3):
			var node: Vector2 = Rules.EXPLORATION_ROUTES[camp_index][node_index]
			draw_line(offset + previous * factor, offset + node * factor, Color("637c71"), 2, true)
			var tint := Color("91d3ae") if game.camps[camp_index].progress > node_index else Color("d6b772")
			if game.completed_waves < Rules.CAMP_UNLOCK[camp_index]: tint = Color("4b5b60")
			draw_circle(offset + node * factor, 4, tint)
			previous = node
		var point: Vector2 = offset + Rules.CAMPS[camp_index] * factor
		var color := Color("eec67b") if not game.camps[camp_index].chest_claimed else Color("6d8b87")
		draw_rect(Rect2(point - Vector2.ONE * 4, Vector2.ONE * 8), color, false, 2)
		var text := "%s · %d/3" % [Rules.CAMP_NAMES[camp_index], game.camps[camp_index].progress]
		var caption := point + Vector2(-105, 25)
		draw_string(get_theme_default_font(), caption, text, HORIZONTAL_ALIGNMENT_LEFT, 210, 16, Color("e4d6af"))
		if game.completed_waves < Rules.CAMP_UNLOCK[camp_index]:
			draw_string(get_theme_default_font(), caption + Vector2(0, 21), "守住第%d波后开放" % Rules.CAMP_UNLOCK[camp_index], HORIZONTAL_ALIGNMENT_LEFT, 210, 14, Color("8aa2a0"))
		elif game.camps[camp_index].chest_claimed:
			draw_string(get_theme_default_font(), caption + Vector2(0, 21), "已开启 · E捷径回营", HORIZONTAL_ALIGNMENT_LEFT, 210, 14, Color("8fcdb5"))
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.lane < 0: continue
		draw_circle(offset + enemy.position * factor, 4 if enemy.kind == "boss" else 1.5, Color("e98875"))
	var hero_point: Vector2 = game.hero.position
	draw_circle(offset + hero_point * factor, 4, Color("f1f4df"))
	draw_arc(offset + hero_point * factor, 7, 0, TAU, 16, Color("c7eee5"), 1, true)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.16, 0.18, 0.94)
	style.set_border_width_all(1)
	style.border_color = Color("4b6966")
	style.set_corner_radius_all(7)
	return style
