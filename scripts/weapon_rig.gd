extends Node2D

var visual: ActorVisual
var standalone_key := ""

func _draw() -> void:
	if not standalone_key.is_empty():
		_draw_weapon(standalone_key, 0, 1)
		return
	if visual == null or visual.death_phase >= 0: return
	var direction := visual.action_direction if visual.action_phase > 0 else visual.direction
	var progress := 1 - visual.action_phase / visual.action_duration if visual.action_phase > 0 else 1.0
	var recoil := sin(progress / 0.45 * PI) * 8 if progress < 0.45 else exp(-(progress - 0.45) * 12) * -5
	var bob := -absf(sin(visual.walk_phase * PI / 3)) * 2 if visual.moving else sin(visual.idle_phase * 4)
	var shoulder := Vector2(0, -30 + bob)
	var hand := shoulder + direction * (20 - recoil)
	var second := shoulder + direction * (8 - recoil) + direction.orthogonal() * 8
	var cloth := Color("619cb1") if visual.hero_identity == "knight" else (Color("739f7d") if visual.hero_identity == "ranger" else Color("9e80bc"))
	draw_line(shoulder, hand, Color("263e4e"), 9, false)
	draw_line(shoulder, hand, cloth, 5, false)
	draw_circle(hand, 4.5, Color("edcc99"))
	draw_line(shoulder + Vector2(0, 5), second, cloth.darkened(0.3), 7, false)
	draw_circle(second, 4, Color("edcc99"))
	var angle := direction.angle()
	if visual.held_weapon in ["halberd", "sword"] and visual.action_phase > 0: angle += lerpf(-1.3, 1.2, progress)
	draw_set_transform(hand, angle)
	_draw_weapon(visual.held_weapon, recoil, progress)
	if visual.dual_active:
		draw_set_transform(second + direction.orthogonal() * 15, angle - 0.05)
		_draw_weapon(visual.held_weapon, recoil * 0.8, progress)
	draw_set_transform(Vector2.ZERO)

func _draw_weapon(key: String, recoil: float, progress: float) -> void:
	var color: Color = Rules.weapon(key).color
	match key:
		"bow", "storm":
			draw_arc(Vector2(-3, 0), 23, -1.15, 1.15, 14, Color("344c4c"), 7, false)
			draw_arc(Vector2(-3, 0), 23, -1.15, 1.15, 14, Color("d5ac6b") if key == "bow" else Color("a9a4d0"), 4, false)
			draw_polyline(PackedVector2Array([Vector2(6, -21), Vector2(-7 - recoil, 0), Vector2(6, 21)]), Color("e7dcc2"), 1.5, true)
			draw_line(Vector2(-12, 0), Vector2(29, 0), color, 3, false)
		"scatter":
			draw_line(Vector2(-17, 0), Vector2(15, 0), Color("36434c"), 8, false)
			draw_line(Vector2(-17, 0), Vector2(15, 0), Color("bd9868"), 4, false)
			draw_colored_polygon(PackedVector2Array([Vector2(31, 0), Vector2(19, -9), Vector2(10, 0), Vector2(19, 9)]), Color("355771"))
			draw_colored_polygon(PackedVector2Array([Vector2(28, 0), Vector2(19, -6), Vector2(13, 0), Vector2(19, 6)]), color)
			if progress < 0.45: draw_arc(Vector2(20, 0), 12 + progress * 12, 0, TAU, 16, Color(color, 0.6), 2, true)
		"sword", "halberd":
			var reach := 63.0 if key == "halberd" else 39.0
			draw_line(Vector2(-11, 0), Vector2(reach, 0), Color("344350"), 9, false)
			draw_line(Vector2(7, 0), Vector2(reach, 0), color, 5, false)
			draw_line(Vector2(5, -10), Vector2(5, 10), Color("d4b376"), 4, false)
			if key == "halberd": draw_colored_polygon(PackedVector2Array([Vector2(reach - 6, -15), Vector2(reach + 16, 0), Vector2(reach - 6, 12)]), color)
		"boomerang":
			draw_arc(Vector2(10, 0), 18, -1.9, 1.9, 14, Color("344d44"), 9, false)
			draw_arc(Vector2(10, 0), 18, -1.9, 1.9, 14, color, 5, false)
		_:
			var length := 24.0 if key == "pistol" else (53.0 if key == "sniper" else 40.0)
			var width := 17.0 if key in ["rocket", "gatling"] else 10.0
			draw_rect(Rect2(-12, -width * 0.5 - 2, length + 7, width + 4), Color("2a3c48"))
			draw_rect(Rect2(-9, -width * 0.5, length, width), Color("8d9ca7") if key != "rocket" else Color("a57351"))
			draw_rect(Rect2(-8, -width * 0.5, length - 3, 3), color)
			draw_rect(Rect2(-6, 3, 9, 13), Color("695945"))
			if key == "gatling":
				var clock: float = visual.idle_phase if visual != null else 0.0
				for barrel in range(3): draw_line(Vector2(5, -6 + barrel * 6), Vector2(34, -6 + barrel * 6), Color("d6b980") if int(clock * 22) % 3 == barrel else Color("546271"), 3, false)
			if key == "sniper":
				draw_rect(Rect2(1, -13, 19, 8), Color("314956"))
				draw_rect(Rect2(16, -12, 4, 5), Color("8be9df"))
			if key == "laser": draw_circle(Vector2(29, 0), 6, color)
