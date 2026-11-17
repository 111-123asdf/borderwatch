class_name ArenaGrounding
extends RefCounted
## Shared engine material, sculpted 2.5D stone tower plinths, and ruins mechanism rendering.
static var shadow: Texture2D
static var dust: Texture2D
static var plinths: Texture2D
static var mechanisms: Texture2D

static func material(level: String) -> ShaderMaterial:
	var mat:=ShaderMaterial.new();mat.shader=preload("res://scripts/shaders/battle_material.gdshader")
	mat.set_shader_parameter("environment_tint",Color(0.94,0.98,1.03) if level=="ruins" else Color(1.01,1.0,0.96))
	mat.set_shader_parameter("saturation",0.80 if level=="ruins" else 0.95)
	mat.set_shader_parameter("exposure",1.08 if level=="ruins" else 1.0)
	return mat

static func ensure_textures() -> void:
	if shadow==null:
		var image:=Image.create(128,64,false,Image.FORMAT_RGBA8);var patch:=Image.create(128,64,false,Image.FORMAT_RGBA8)
		for y in range(64):
			for x in range(128):
				var d:=Vector2((x-64.0)/64.0,(y-32.0)/32.0).length()
				var alpha:=pow(maxf(0.0,1.0-d),1.6)
				image.set_pixel(x,y,Color(0.10,0.12,0.16,alpha*0.42))
				var grain:=0.65+0.35*sin(x*2.17+y*3.31)*sin(y*1.73-x*0.57)
				patch.set_pixel(x,y,Color(0.57,0.55,0.52,maxf(0.0,1.0-d)*grain*0.32))
		shadow=ImageTexture.create_from_image(image);dust=ImageTexture.create_from_image(patch)
	if plinths==null and ResourceLoader.exists("res://assets/v018/site_plinths.png"):
		plinths=load("res://assets/v018/site_plinths.png")
	if mechanisms==null and ResourceLoader.exists("res://assets/v018/ruins_mechanisms.png"):
		mechanisms=load("res://assets/v018/ruins_mechanisms.png")

static func draw_contact(canvas: CanvasItem,point: Vector2,occupied: bool,ruins: bool,seed_id: int,trait_id: String="",locked: bool=false,hovered: bool=false,selected: bool=false) -> void:
	ensure_textures()
	var t_col: Color = Color("c9a255") if trait_id == "highground" else (Color("c86f4c") if trait_id == "choke" else (Color("56b9cc") if trait_id == "conduit" else Color("a89c86")))
	# Ground contact shadow beneath both open plinths and built towers
	canvas.draw_texture_rect(shadow, Rect2(point + Vector2(-56, -15), Vector2(112, 42)), false, Color(1, 1, 1, 0.96 if occupied else 0.68))
	if occupied:
		if trait_id != "":
			canvas.draw_set_transform(point + Vector2(0, 3), 0.0, Vector2(1.0, 0.56))
			canvas.draw_arc(Vector2.ZERO, 44.0, 0.0, TAU, 32, Color(t_col, 0.34), 2.2, true)
			canvas.draw_set_transform(Vector2.ZERO)
		return

	# Embedded ground-flush stone plinth (2.5D elliptical masonry, never floating UI button)
	var stone_outer: Color = Color("4f5360") if ruins else Color("5c5342")
	var stone_body: Color = Color("6b6f7c") if ruins else Color("857a62")
	var stone_inner: Color = Color("424652") if ruins else Color("564e3e")
	var bevel_light: Color = Color("9aa0ae") if ruins else Color("b5aa8c")
	if locked:
		stone_body = Color("525560") if ruins else Color("635a4b")
		stone_inner = Color("323642") if ruins else Color("403a30")

	var wobble: float = sin(float(seed_id) * 1.7) * 0.04
	canvas.draw_set_transform(point + Vector2(0, 3), wobble, Vector2(1.0, 0.56))

	# Recessed dirt/dust skirt anchoring stone slab to ground
	canvas.draw_circle(Vector2(0, 3), 47.0, Color(0.08, 0.09, 0.12, 0.36))
	if trait_id == "highground":
		# Stepped octagonal/terrace plinth conveying low elevation ridge
		var step_outer := PackedVector2Array([Vector2(-44, -8), Vector2(-22, -40), Vector2(22, -40), Vector2(44, -8), Vector2(44, 18), Vector2(20, 42), Vector2(-20, 42), Vector2(-44, 18)])
		canvas.draw_colored_polygon(step_outer, stone_outer)
		var step_top := PackedVector2Array([Vector2(-38, -12), Vector2(-18, -36), Vector2(18, -36), Vector2(38, -12), Vector2(38, 10), Vector2(16, 33), Vector2(-16, 33), Vector2(-38, 10)])
		canvas.draw_colored_polygon(step_top, stone_body)
		canvas.draw_polyline(PackedVector2Array([Vector2(-37, -12), Vector2(-18, -35), Vector2(18, -35), Vector2(37, -12)]), Color(bevel_light, 0.48), 2.0, true)
		canvas.draw_circle(Vector2(0, -1), 24.0, stone_inner)
	else:
		# Flush circular hammered stone curb
		canvas.draw_circle(Vector2(0, 2), 43.0, stone_outer)
		canvas.draw_circle(Vector2(0, 0), 40.0, stone_body)
		canvas.draw_arc(Vector2(0, 0), 39.0, PI * 1.05, PI * 1.95, 22, Color(bevel_light, 0.42), 2.0, true)
		canvas.draw_circle(Vector2(0, 1), 27.0, stone_inner)
		canvas.draw_arc(Vector2(0, 1), 27.5, 0.0, TAU, 28, Color(0.12, 0.13, 0.17, 0.65), 1.8, true)

	# Carved stone joint lines (subtle masonry weathering)
	for k in range(4):
		var a := float(k) * (TAU * 0.25) + 0.38
		canvas.draw_line(Vector2.RIGHT.rotated(a) * 28.0, Vector2.RIGHT.rotated(a) * 40.0, Color(0.14, 0.15, 0.20, 0.55), 1.8)

	# Sculpted textless inlaid trait relief or locked iron cross-straps
	if locked:
		canvas.draw_line(Vector2(-24, -18), Vector2(24, 20), Color("292b33"), 5.5, true)
		canvas.draw_line(Vector2(24, -18), Vector2(-24, 20), Color("292b33"), 5.5, true)
		canvas.draw_line(Vector2(-22, -17), Vector2(22, 19), Color("676a75"), 2.0, true)
		canvas.draw_line(Vector2(22, -17), Vector2(-22, 19), Color("676a75"), 2.0, true)
		# Recessed keyhole emblem in stone center
		canvas.draw_circle(Vector2(0, -2), 7.5, Color("1f222a"))
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(-4, 0), Vector2(4, 0), Vector2(6, 12), Vector2(-6, 12)]), Color("1f222a"))
		canvas.draw_circle(Vector2(0, -2), 4.0, Color("8d8371") if not hovered else Color("e7c87d"))
	elif trait_id == "highground":
		# Carved chevron / bow sight groove
		var g_alpha: float = 0.85 if (hovered or selected) else 0.55
		canvas.draw_arc(Vector2(0, 4), 16.0, PI * 1.15, PI * 1.85, 16, Color(t_col, g_alpha), 2.8, true)
		canvas.draw_polyline(PackedVector2Array([Vector2(-10, -2), Vector2(0, -14), Vector2(10, -2)]), Color(t_col, g_alpha), 2.6, true)
		canvas.draw_line(Vector2(0, -14), Vector2(0, 12), Color(t_col, g_alpha * 0.85), 2.2, true)
	elif trait_id == "choke":
		# Iron border rivets + carved crossed shield-blade inlay
		for k in range(6):
			var p_riv := Vector2.RIGHT.rotated(float(k) * TAU / 6.0) * 33.5
			canvas.draw_circle(p_riv, 2.6, Color("8e6a56"))
		var c_alpha: float = 0.85 if (hovered or selected) else 0.56
		canvas.draw_line(Vector2(-11, -11), Vector2(11, 11), Color(t_col, c_alpha), 3.0, true)
		canvas.draw_line(Vector2(11, -11), Vector2(-11, 11), Color(t_col, c_alpha), 3.0, true)
		canvas.draw_circle(Vector2.ZERO, 5.5, Color(t_col, c_alpha * 0.9))
	elif trait_id == "conduit":
		# Carved obsidian arcane triangle groove with quiet breath
		var breath: float = 0.42 + 0.14 * sin(Time.get_ticks_msec() * 0.003 + float(seed_id) * 0.9)
		var r_alpha: float = 0.90 if (hovered or selected) else breath
		canvas.draw_polyline(PackedVector2Array([Vector2(0, -16), Vector2(15, 11), Vector2(-15, 11), Vector2(0, -16)]), Color(t_col, r_alpha), 2.6, true)
		canvas.draw_circle(Vector2(0, 1), 4.5, Color("9ceeff", r_alpha))
	else:
		# Quiet carved build notch in center of ordinary site
		var b_alpha: float = 0.72 if (hovered or selected) else 0.34
		canvas.draw_line(Vector2(-8, 0), Vector2(8, 0), Color(bevel_light, b_alpha), 2.4, true)
		canvas.draw_line(Vector2(0, -8), Vector2(0, 8), Color(bevel_light, b_alpha), 2.4, true)

	# Hover & Selected ground highlights (never floating UI cards)
	if selected:
		canvas.draw_arc(Vector2.ZERO, 44.5, 0.0, TAU, 40, Color("f6d47a", 0.92), 3.0, true)
		canvas.draw_arc(Vector2.ZERO, 39.5, 0.0, TAU, 36, Color(t_col, 0.65), 1.6, true)
	elif hovered:
		canvas.draw_arc(Vector2.ZERO, 43.0, 0.0, TAU, 36, Color(t_col if trait_id != "" else Color("e8d29b"), 0.68), 2.2, true)
	canvas.draw_set_transform(Vector2.ZERO)
