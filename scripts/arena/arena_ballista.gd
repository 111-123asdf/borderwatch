class_name ArenaBallista
extends Node2D
## Kingdom-Rush-style articulated watchtower archer unit(s) rendered in code.
## Keeps `RELEASE_CENTER` in local space aligned with `rotation = aim.angle()`
## so projectile spawn and existing unit tests remain 100% exact.
const RELEASE_CENTER := Vector2(12, 0)
var tier := 1
var draw_amount := 0.0
var loaded := false
var release_flash := 0.0
var idle_clock := 0.0

func pose(aim: Vector2, tension: float, has_bolt: bool, rel_pulse := 0.0, clock := 0.0) -> void:
	var next_rot := aim.angle()
	if absf(angle_difference(rotation, next_rot)) > 0.004 or absf(tension - draw_amount) > 0.004 or has_bolt != loaded or absf(rel_pulse - release_flash) > 0.01 or int(clock * 12.0) != int(idle_clock * 12.0):
		rotation = next_rot
		draw_amount = tension
		loaded = has_bolt
		release_flash = rel_pulse
		idle_clock = clock
		queue_redraw()

func _draw() -> void:
	var aim_dir := Vector2.from_angle(rotation)
	var breath := sin(idle_clock * 3.2) * 0.8 if (draw_amount <= 0.02 and release_flash <= 0.02) else 0.0
	# Companion archers on Lv2 and Lv3 platforms (positioned inside adjacent window bays)
	if tier == 2:
		_draw_archer_unit(Vector2(-15.0, 2.0), aim_dir, clampf(draw_amount * 0.92, 0.0, 1.0), loaded, release_flash * 0.85, -breath, false)
	elif tier >= 3:
		_draw_archer_unit(Vector2(-19.0, 2.5), aim_dir, clampf(draw_amount * 0.88, 0.0, 1.0), loaded, release_flash * 0.8, -breath, false)
		_draw_archer_unit(Vector2(18.0, 2.5), aim_dir, clampf(draw_amount * 0.95, 0.0, 1.0), loaded, release_flash * 0.9, breath * 0.7, false)
	# Lead archer centered at swivel so his nocked arrow aligns with RELEASE_CENTER
	_draw_archer_unit(Vector2.ZERO, aim_dir, draw_amount, loaded, release_flash, breath, true)

func _draw_archer_unit(world_offset: Vector2, aim_dir: Vector2, tension: float, has_bolt: bool, rel: float, breath: float, is_lead: bool) -> void:
	var u_scale := 0.68
	var face_x := -1.0 if aim_dir.x < -0.05 else 1.0
	var local_origin := world_offset.rotated(-rotation)
	# Body recoil & lean in world space: leans back during draw, snaps back with squash on release
	var lean_x := -face_x * (tension * 3.0 + rel * 2.2)
	var squash_y := (1.0 - 0.08 * tension + 0.10 * rel) * u_scale
	var stretch_x := (1.0 + 0.06 * tension - 0.06 * rel) * u_scale

	# 1. Draw upright character torso, cloak, hood, and head in world-aligned space
	draw_set_transform(local_origin + Vector2(lean_x, breath + 2.0).rotated(-rotation), -rotation, Vector2(face_x * stretch_x, squash_y))
	var outline := Color("1f1916")
	var cloak_dark := Color("254427") if tier < 3 else Color("1f3f34")
	var cloak_mid := Color("3b6c36") if tier < 3 else Color("2e6850")
	var cloak_hi := Color("629c49") if tier < 3 else Color("54a478")
	var trim_gold := Color("ecc56a") if tier >= 2 else Color("b88b4a")
	var leather := Color("784c2c")
	var skin := Color("f2c69d")

	# Cloak & tunic silhouette (planted into the booth deck)
	var cape_sway := sin(idle_clock * 4.5 + world_offset.x * 0.1) * 1.8 + tension * 2.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9 - cape_sway, 16), Vector2(-11 - cape_sway * 0.6, 2), Vector2(-6, -7),
		Vector2(7, -6), Vector2(9, 15)
	]), outline)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7.5 - cape_sway, 14.5), Vector2(-9 - cape_sway * 0.5, 2), Vector2(-5, -5.5),
		Vector2(5.5, -4.5), Vector2(7.2, 13.5)
	]), cloak_dark)
	# Leather chest baldric & belt
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.5, -5), Vector2(5.5, -4.5), Vector2(6.2, 8), Vector2(-5.0, 8)
	]), cloak_mid)
	draw_line(Vector2(-4.5, -4.5), Vector2(4.8, 6.5), leather, 2.8, true)
	draw_line(Vector2(-5.2, 6.5), Vector2(6.0, 6.5), trim_gold, 2.2, true)
	# Back quiver tips peeking over back shoulder
	draw_line(Vector2(-7.5, -4.0), Vector2(-11.5, -13.0), leather, 3.2, true)
	draw_line(Vector2(-9.5, -10.5), Vector2(-12.8, -15.5), Color("fff2ca"), 2.0, true)
	draw_line(Vector2(-7.8, -11.0), Vector2(-10.5, -16.2), Color("fff2ca"), 1.8, true)

	# Head & Ranger Hood
	var head_c := Vector2(1.0, -11.5)
	draw_circle(head_c, 8.2, outline)
	draw_circle(head_c + Vector2(1.4, 0.5), 6.2, skin)
	# Determined eye & brow
	draw_circle(head_c + Vector2(4.0, -0.4), 1.2, Color("231a16"))
	draw_line(head_c + Vector2(2.2, -2.2), head_c + Vector2(5.4, -1.5), Color("3c281c"), 1.3, true)
	# Pointed ranger hood draping over head
	draw_colored_polygon(PackedVector2Array([
		head_c + Vector2(-9.5 - cape_sway * 0.4, -2.5),
		head_c + Vector2(-3.5, -8.2),
		head_c + Vector2(5.5, -6.5),
		head_c + Vector2(2.2, -1.8),
		head_c + Vector2(-3.5, 4.2),
		head_c + Vector2(-8.0, 2.5)
	]), cloak_mid)
	draw_polyline(PackedVector2Array([
		head_c + Vector2(-8.8 - cape_sway * 0.4, -2.2),
		head_c + Vector2(-3.0, -7.2),
		head_c + Vector2(4.8, -5.8)
	]), cloak_hi, 1.8, true)
	if tier >= 3:
		# Golden leaf crest on Lv3 elite ranger hood
		draw_line(head_c + Vector2(-1.0, -6.2), head_c + Vector2(4.2, -4.6), trim_gold, 1.8, true)

	# 2. Draw articulated Bow, Bowstring, Arms, and Arrow at a natural 2.5D perspective pitch over the railing!
	var pitch: float = clampf(atan2(aim_dir.y, maxf(0.15, absf(aim_dir.x))) * 0.38, -0.32, 0.36)
	var shoulder_world := world_offset + Vector2(lean_x + face_x * 2.5, breath - 2.0)
	draw_set_transform(shoulder_world.rotated(-rotation), -rotation + pitch * face_x, Vector2(face_x * u_scale, u_scale))

	var span := 11.5 + 1.4 * float(tier)
	var grip := Vector2(7.5 - rel * 2.0, 0.0)
	var string_pull := 9.5 * tension - rel * 1.8
	var notch := Vector2(1.0 - string_pull, 0.0)

	# Front bow-holding arm extending from shoulder to bow grip
	draw_line(Vector2(-1.0, 1.0), grip, outline, 4.4, true)
	draw_line(Vector2(-1.0, 1.0), grip, cloak_hi, 2.5, true)
	draw_circle(grip, 2.0, skin)

	# Recurve Bow Limbs (bending backward as `tension` increases)
	var bow_wood := Color("8c562b") if tier < 3 else Color("c99846")
	var bow_hi := Color("e6be7a") if tier < 3 else Color("fff0b8")
	for side: float in [-1.0, 1.0]:
		var mid: Vector2 = grip + Vector2(-1.2 - 1.6 * tension, side * span * 0.56)
		var tip: Vector2 = grip + Vector2(-5.5 - 4.0 * tension + rel * 1.5, side * (span - 1.5 * tension))
		var limb := PackedVector2Array([grip, mid, tip])
		draw_polyline(limb, outline, 4.5, true)
		draw_polyline(limb, bow_wood, 2.6, true)
		draw_line(mid, tip, bow_hi, 1.2, true)
		# Bowstring with release vibration
		var vib: float = sin(rel * PI * 4.0) * 1.8 * side if rel > 0.01 else 0.0
		draw_line(tip, notch + Vector2(vib, 0.0), Color("2b2320"), 2.0, true)
		draw_line(tip, notch + Vector2(vib, 0.0), Color("f5e9ce"), 1.1, true)

	# Nocked arrow on the bowstring during preparation
	if has_bolt:
		var arrow_tail := notch
		var arrow_tip := grip + Vector2(8.5, 0.0)
		draw_line(arrow_tail, arrow_tip, Color("241a18"), 3.4, true)
		draw_line(arrow_tail, arrow_tip, Color("d9a65c"), 1.7, true)
		draw_colored_polygon(PackedVector2Array([
			arrow_tip + Vector2(4.0, 0.0),
			arrow_tip + Vector2(-1.5, -2.8),
			arrow_tip + Vector2(-1.5, 2.8)
		]), Color("dce8f2"))
		for f_side: float in [-1.0, 1.0]:
			draw_line(arrow_tail + Vector2(0.0, f_side * 2.5), arrow_tail + Vector2(4.2, 0.0), Color("fff5d6"), 1.6, true)

	# Rear drawing arm & hand pulling the string back to the cheek
	var elbow := notch + Vector2(-4.5, 3.2)
	draw_polyline(PackedVector2Array([Vector2(-1.5, -0.5), elbow, notch]), outline, 4.0, true)
	draw_polyline(PackedVector2Array([Vector2(-1.5, -0.5), elbow, notch]), cloak_mid, 2.2, true)
	draw_circle(notch, 1.9, skin)

	# Crisp bow-release kinetic snap flash at bow grip
	if rel > 0.02:
		var flash_a := clampf(rel * 1.1, 0.0, 1.0)
		draw_line(grip + Vector2(2, -7 * rel), grip + Vector2(12 * rel, 0), Color(1.0, 0.95, 0.72, flash_a), 2.2, true)
		draw_line(grip + Vector2(2, 7 * rel), grip + Vector2(12 * rel, 0), Color(1.0, 0.95, 0.72, flash_a), 2.2, true)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func draw_bolt(canvas: CanvasItem) -> void:
	# High-contrast hand-painted arrow with dark outline, warm timber shaft, ivory fletching, and gleaming steel broadhead
	canvas.draw_line(Vector2(-15, 0), Vector2(10, 0), Color("241a18"), 4.2, true)
	canvas.draw_line(Vector2(-14, -0.4), Vector2(9, -0.4), Color("d9a65c"), 2.0, true)
	for side in [-1.0, 1.0]:
		canvas.draw_colored_polygon(PackedVector2Array([
			Vector2(-15, side * 3.8), Vector2(-9, side * 3.2), Vector2(-6, 0), Vector2(-12, 0)
		]), Color("241a18"))
		canvas.draw_line(Vector2(-14.2, side * 3.0), Vector2(-7.5, 0), Color("fff5d6"), 2.1, true)
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(15, 0), Vector2(5, -4.0), Vector2(7, 0), Vector2(5, 4.0)
	]), Color("262228"))
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(14, 0), Vector2(6, -2.8), Vector2(7.8, 0), Vector2(6, 2.8)
	]), Color("dce8f2"))
	canvas.draw_colored_polygon(PackedVector2Array([
		Vector2(14, -0.2), Vector2(6.5, -2.5), Vector2(8.5, 0.4)
	]), Color("fff9d2"))
