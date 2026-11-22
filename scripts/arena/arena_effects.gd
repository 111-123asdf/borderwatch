class_name ArenaEffects
extends Node2D

const RUINS_BRAZIERS := [
	Vector2(1028.0, 429.0),
	Vector2(1217.0, 430.0),
	Vector2(1030.0, 615.0),
	Vector2(1204.0, 616.0),
	Vector2(540.0, 20.0),
	Vector2(1688.0, 36.0),
	Vector2(373.0, 1002.0),
	Vector2(1634.0, 932.0),
]

const KENNEY_PARTICLES := {
	"smoke": "res://assets/v018/particles/smoke_04.png",
	"spark": "res://assets/v018/particles/spark_05.png",
	"flare": "res://assets/v018/particles/flare_01.png",
	"magic": "res://assets/v018/particles/magic_05.png",
	"fire": "res://assets/v018/particles/fire_01.png",
	"circle": "res://assets/v018/particles/circle_05.png",
}

const V016_SHEETS := {
	"slash": {"path": "res://assets/v016/fx_slash.png", "cols": 8, "pivot": Vector2(32, 32), "tint": 0.25},
	"arcane_blast": {"path": "res://assets/v016/fx_arcane_blast.png", "cols": 8, "pivot": Vector2(32, 32), "tint": 0.28},
	"lightning": {"path": "res://assets/v016/fx_lightning_arc.png", "cols": 8, "pivot": Vector2(32, 32), "tint": 0.30},
	"frost": {"path": "res://assets/v016/fx_frost_shatter.png", "cols": 8, "pivot": Vector2(32, 42), "tint": 0.20},
	"shield_break": {"path": "res://assets/v016/fx_shield_break.png", "cols": 8, "pivot": Vector2(32, 32), "tint": 0.25},
	"hit": {"path": "res://assets/v016/fx_hit_spark.png", "cols": 8, "pivot": Vector2(32, 32), "tint": 0.32},
	"fire_brazier": {"path": "res://assets/v016/fx_fire_brazier.png", "cols": 12, "pivot": Vector2(32, 59), "tint": 0.15, "fps": 8.0},
	"slam": {"path": "res://assets/v016/fx_ground_slam.png", "cols": 8, "pivot": Vector2(32, 50), "tint": 0.22},
	"upgrade": {"path": "res://assets/v016/fx_upgrade_sigil.png", "cols": 8, "pivot": Vector2(32, 54), "tint": 0.30},
}

var game: Node2D
var painted: Texture2D
var fx_sheets: Dictionary = {}
var kenney_tex: Dictionary = {}
var fx_meta: Dictionary = {}
var ambient_braziers: Array = []

var _pixel_layer: Node2D
var _glow_layer: Node2D
var _glow_tex: Texture2D
var _clock := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/v011/physical_fx.png"):
		painted = load("res://assets/v011/physical_fx.png")
	_load_v016_assets()
	_glow_tex = _build_radial_glow_texture()
	_setup_render_layers()


func _setup_render_layers() -> void:
	# Keep nearest-neighbor pixel FX and additive glow isolated from dark text outlines and ground decals.
	_pixel_layer = Node2D.new()
	_pixel_layer.name = "PixelFXLayer"
	_pixel_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pixel_layer.z_index = 0
	_pixel_layer.draw.connect(_draw_pixel_layer)
	add_child(_pixel_layer)

	_glow_layer = Node2D.new()
	_glow_layer.name = "AdditiveGlowLayer"
	_glow_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_glow_layer.z_index = 1
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer.material = add_mat
	_glow_layer.draw.connect(_draw_glow_layer)
	add_child(_glow_layer)


func _load_v016_assets() -> void:
	var manifest_path := "res://assets/v016/fx_manifest.json"
	if FileAccess.file_exists(manifest_path):
		var raw := FileAccess.get_file_as_string(manifest_path)
		var parsed: Variant = JSON.parse_string(raw)
		if parsed is Dictionary and parsed.has("sheets") and parsed.sheets is Dictionary:
			fx_meta = parsed.sheets
	for key in V016_SHEETS:
		var spec: Dictionary = V016_SHEETS[key]
		var path := str(spec.path)
		if ResourceLoader.exists(path):
			var tex := load(path) as Texture2D
			if tex != null:
				fx_sheets[key] = tex
	for k in KENNEY_PARTICLES:
		var kpath := str(KENNEY_PARTICLES[k])
		if ResourceLoader.exists(kpath):
			var ktex := load(kpath) as Texture2D
			if ktex != null:
				kenney_tex[k] = ktex


func has_v016_fx(key: String) -> bool:
	return fx_sheets.has(key) and fx_sheets[key] != null


func set_braziers(points: Array) -> void:
	ambient_braziers = points.duplicate()


func _build_radial_glow_texture() -> Texture2D:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var half := (size - 1) * 0.5
	for y in range(size):
		for x in range(size):
			var dx := (x - half) / half
			var dy := (y - half) / half
			var d := sqrt(dx * dx + dy * dy)
			var a := 0.0
			if d < 1.0:
				var u := 1.0 - d
				a = u * u * (0.6 + 0.4 * u)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


func _process(delta: float) -> void:
	_clock += delta
	var has_active: bool = game != null and (not game.effects.is_empty() or not game.delayed.is_empty() or not game.numbers.is_empty())
	if has_active:
		queue_redraw()
	if has_active or Engine.get_process_frames() % 2 == 0:
		if is_instance_valid(_pixel_layer):
			_pixel_layer.queue_redraw()
		if is_instance_valid(_glow_layer):
			_glow_layer.queue_redraw()


func _is_reduced_motion() -> bool:
	if game == null or game.campaign == null:
		return false
	var data: Variant = game.campaign.data
	if data is Dictionary:
		return bool(data.get("reduced_motion", false))
	if data != null:
		return bool(data.get("reduced_motion"))
	return false


func _paint(hero: String, row: int, column: int, point: Vector2, dimensions: Vector2, alpha := 1.0, angle := 0.0) -> void:
	var texture := ArenaHeroVFX.frame(hero, row, clampi(column, 0, 3))
	if texture == null:
		return
	draw_set_transform(point, angle)
	draw_texture_rect(texture, Rect2(-dimensions * 0.5, dimensions), false, Color(1, 1, 1, alpha))
	draw_set_transform(Vector2.ZERO)


func _resolve_sheet_key(kind: String) -> String:
	match kind:
		"hit", "hit_spark":
			return "hit"
		"slash":
			return "slash"
		"blast", "arcane_blast", "summon", "meteor":
			return "arcane_blast"
		"frost", "frost_shatter":
			return "frost"
		"slam", "ground_slam":
			return "slam"
		"upgrade", "upgrade_sigil", "banner", "flag":
			return "upgrade"
		"lightning", "lightning_arc", "chain_lightning", "conduit":
			return "lightning"
		"shield_break", "barrier_break":
			return "shield_break"
		"fire_brazier", "brazier":
			return "fire_brazier"
		_:
			return ""


func _sheet_cols(key: String, tex: Texture2D) -> int:
	var spec: Dictionary = V016_SHEETS.get(key, {})
	var cell_h := maxf(1.0, float(tex.get_height()))
	var detected := int(round(tex.get_width() / cell_h))
	return maxi(1, detected if detected > 0 else int(spec.get("cols", 8)))


func _sheet_pivot(key: String) -> Vector2:
	var spec: Dictionary = V016_SHEETS.get(key, {})
	return Vector2(spec.get("pivot", Vector2(32, 32)))


func _sheet_dimensions(kind: String, r: float) -> Vector2:
	var size_px := 64.0
	match kind:
		"hit":
			size_px = clampf(maxf(r * 3.1, 36.0), 34.0, 92.0)
		"slash":
			size_px = maxf(r * 2.45, 72.0)
		"blast", "summon", "meteor":
			size_px = maxf(r * 2.35, 84.0)
		"frost":
			size_px = maxf(r * 2.2, 72.0)
		"slam":
			size_px = maxf(r * 2.25, 92.0)
		"upgrade", "banner":
			size_px = clampf(r * 1.35, 64.0, 96.0)
		"flag":
			size_px = maxf(r * 2.2, 54.0)
		"lightning", "chain_lightning", "conduit":
			return Vector2(maxf(r * 2.7, 84.0), maxf(r * 2.1, 64.0))
		"shield_break", "barrier_break":
			size_px = maxf(r * 2.5, 76.0)
		"fire_brazier", "brazier":
			size_px = maxf(r * 2.0, 56.0)
		_:
			size_px = maxf(r * 2.2, 64.0)
	return Vector2(size_px, size_px)


func _sheet_angle(kind: String, item: Dictionary) -> float:
	if kind in ["slash", "lightning", "chain_lightning", "conduit"]:
		var dir := Vector2(item.get("direction", Vector2.RIGHT))
		if dir.length_squared() > 0.0001:
			return dir.angle()
	return 0.0


func _sheet_frame_index(key: String, kind: String, cols: int, p: float) -> int:
	if kind in ["fire_brazier", "brazier"]:
		var fps := float(V016_SHEETS.get(key, {}).get("fps", 8.0))
		return int(floor(_clock * fps)) % cols
	return clampi(int(floor(p * float(cols))), 0, cols - 1)


func _draw_sheet_frame(target: Node2D, key: String, kind: String, point: Vector2, r: float, p: float, alpha: float, tint: Color, angle: float, scale_mul := 1.0) -> void:
	var tex := fx_sheets.get(key) as Texture2D
	if tex == null:
		return
	var cols := _sheet_cols(key, tex)
	var col := _sheet_frame_index(key, kind, cols, p)
	var cell_w := float(tex.get_width()) / float(cols)
	var cell_h := float(tex.get_height())
	var pivot := _sheet_pivot(key)
	var dim := _sheet_dimensions(kind, r) * scale_mul
	var top_left := Vector2(-dim.x * (pivot.x / cell_w), -dim.y * (pivot.y / cell_h))
	target.draw_set_transform(point, angle)
	target.draw_texture_rect_region(
		tex,
		Rect2(top_left, dim),
		Rect2(Vector2(float(col) * cell_w, 0.0), Vector2(cell_w, cell_h)),
		Color(tint.r, tint.g, tint.b, alpha*0.58)
	)
	target.draw_set_transform(Vector2.ZERO)


func _ambient_brazier_points() -> Array:
	if not ambient_braziers.is_empty():
		return ambient_braziers
	if game == null:
		return []
	var custom: Variant = game.get("braziers")
	if custom is Array and not custom.is_empty():
		return custom
	if str(game.get("level_id")) == "ruins":
		return RUINS_BRAZIERS
	var lvl: Variant = game.get("level_definition")
	if lvl is Dictionary and lvl.has("braziers") and lvl.braziers is Array:
		return lvl.braziers
	return []


func _draw() -> void:
	if game == null or not game.started:
		return
	if game.feel.enabled and game.hero.class_id=="druid":
		ArenaHeroSkillFX.draw_companion_orders(self,game.hero,_is_reduced_motion())
	_draw_legacy_and_painted_effects()
	_draw_delayed_indicators()
	_draw_floating_numbers()


func _draw_legacy_and_painted_effects() -> void:
	var reduced := _is_reduced_motion()
	for item in game.effects:
		var dur := maxf(0.01, float(item.duration))
		var p: float = clampf(1.0 - float(item.life) / dur, 0.0, 1.0)
		var colour: Color = Color(item.colour, (1.0 - p) * 0.85)
		var point: Vector2 = item.point
		var r: float = item.radius
		if item.kind=="gunner_slide":
			ArenaHeroSkillFX.draw_gunner_slide(self,item,p,reduced)
			continue
		if item.kind=="dodge_step":
			_draw_dodge_step(point, Vector2(item.direction), r, p, item.colour, reduced)
			continue
		match item.kind:
			"pixel_contact", "shield_contact":
				_draw_pixel_contact(item,p)
			"shaft_contact", "edge_contact", "ward_contact":
				_draw_contact(item,p,reduced)
			"cannon_blast":
				_draw_cannon_blast(point, r, p, reduced, item.get("meta", {}))
			"tower_arc", "tower_arc_fork", "tower_arc_relay", "tower_arc_surge":
				_draw_tower_arc(item, p, reduced)
			"storm_hit":
				_draw_storm_hit(item, p, reduced)
			"tower_beam", "tower_beam_focus", "tower_beam_sweep", "tower_beam_far_lens":
				_draw_tower_beam(item, p, reduced)
			"lens_hit":
				_draw_lens_hit(item, p, reduced)
			"snare_snap":
				_draw_snare_snap(item, p, reduced)
			"tower_frost", "tower_frost_inner", "tower_arcfire":
				_draw_tower_pulse(item, p, reduced)
			"arrow_impact_painted", "magic_impact_painted":
				if item.kind == "magic_impact_painted":
					_draw_magic_impact_extra(point, r, p, reduced)
				_paint("mage" if item.kind == "magic_impact_painted" else "ranger", 1, int(p * 4), point, Vector2.ONE * r * 2, 1.0 - p * p, Vector2(item.direction).angle())
			"slash_painted", "impact_painted", "slam_painted", "banner_painted":
				if painted != null:
					var row: int = {"slash_painted": 0, "impact_painted": 1, "slam_painted": 2, "banner_painted": 3}[item.kind]
					var cell := painted.get_size() / 4.0
					var column := mini(3, int(p * 4.0))
					var angle: float = Vector2(item.direction).angle() if row in [0,1,2] else 0.0
					if row == 0:
						_draw_blade_sweep(point,angle,r,p,reduced)
					elif row == 2:
						var beat := sqrt(p)
						draw_arc(point + Vector2(item.direction)*r*0.1,r*(0.22+0.75*beat),angle-1.20,angle+1.20,22,Color(0.98,0.81,0.52,0.80*(1-p)),3.8*(1-p)+0.5,true)
					elif row == 3:
						draw_arc(point,r*(0.18+0.82*smoothstep(0,0.8,p)),0,TAU,64,Color(0.95,0.82,0.5,0.48*(1-p)),2.2,true)
					draw_set_transform(point, angle)
					var dimensions := Vector2(r * 2.0, r * 2.0)
					if row == 2:
						dimensions.y *= 0.6
					if row == 3:
						dimensions = Vector2(r * 1.4, r * 0.85)
					draw_texture_rect_region(painted, Rect2(-dimensions * 0.5, dimensions), Rect2(Vector2(column, row) * cell, cell), Color(1, 1, 1, 1.0 - p * p))
					draw_set_transform(Vector2.ZERO)
			_:
				var sheet_key := _resolve_sheet_key(str(item.kind))
				if sheet_key != "" and has_v016_fx(sheet_key):
					# Pixel sprite sheet & additive glow render on dedicated child layers.
					continue
				_draw_fallback_geometry(str(item.kind), point, r, p, colour, item)


func _draw_fallback_geometry(kind: String, point: Vector2, r: float, p: float, colour: Color, item: Dictionary) -> void:
	match kind:
		"hit":
			for index in range(5):
				var vector := Vector2.RIGHT.rotated(index * TAU / 5.0)
				draw_line(point + vector * r * p, point + vector * r * (p + 0.4), colour, 2.0, true)
		"slash":
			var a: float = Vector2(item.direction).angle()
			draw_arc(point, r * 0.9, a - 1.15 + p * 1.6, a - 0.4 + p * 1.6, 24, colour, 5.0, true)
		"meteor":
			draw_circle(point + Vector2(-160.0 * (1.0 - p), -400.0 * (1.0 - p)), 20.0 * (1.0 - p) + 5.0, colour)
		"lightning", "chain_lightning", "conduit":
			var dir := Vector2(item.direction)
			var norm := dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
			var perp := Vector2(-norm.y, norm.x)
			var half_len := maxf(r * 0.9, 26.0)
			var pts := PackedVector2Array()
			for step in range(6):
				var u := float(step) / 5.0 - 0.5
				var jit := sin((u + p) * 23.0 + float(step) * 2.1) * 9.0 * (1.0 - absf(u * 2.0))
				pts.append(point + norm * (u * 2.0 * half_len) + perp * jit)
			draw_polyline(pts, Color(colour.r, colour.g, colour.b, (1.0 - p) * 0.9), 3.0, true)
			draw_polyline(pts, Color(1.0, 1.0, 1.0, (1.0 - p) * 0.85), 1.3, true)
		"shield_break", "barrier_break":
			draw_arc(point, r * (0.4 + p * 0.65), 0, TAU, 32, Color(0.55, 0.88, 1.0, 1.0 - p), 3.0, true)
			draw_arc(point, r * (0.25 + p * 0.8), 0, TAU, 24, Color(1.0, 0.88, 0.55, (1.0 - p) * 0.8), 1.8, true)
		"fire_brazier", "brazier":
			var flick := 0.85 + 0.15 * sin(_clock * 11.0 + point.x)
			draw_circle(point + Vector2(0, -10), r * 0.45 * flick, Color(1.0, 0.55, 0.18, 0.7))
			draw_circle(point + Vector2(0, -12), r * 0.25 * flick, Color(1.0, 0.9, 0.55, 0.9))
		"upgrade":
			draw_set_transform(point, 0.0, Vector2(1.0, 0.58))
			draw_circle(Vector2.ZERO, r * (0.2 + p * 0.8), Color(colour, 0.14 * (1.0 - p)))
			draw_arc(Vector2.ZERO, r * (0.3 + p * 0.7), 0, TAU, 40, colour, 3.0, true)
			draw_set_transform(Vector2.ZERO)
			for index in range(6):
				var ray := Vector2.RIGHT.rotated(index * TAU / 6.0 + p * 0.6)
				draw_line(point + ray * r * 0.35 * p, point + ray * r * 0.75 * p - Vector2(0, 22 * p), Color("fff3be", (1.0 - p) * 0.85), 2.0, true)
		_:
			draw_arc(point, r * (0.3 + p * 0.7), 0, TAU, 40, colour, 3.0, true)
			if kind in ["blast", "slam", "frost"]:
				for index in range(8):
					var vector := Vector2.RIGHT.rotated(index * TAU / 8.0)
					draw_line(point + vector * r * p * 0.7, point + vector * r * p, colour, 2.0, true)


func _draw_pixel_layer() -> void:
	if game == null or not game.started or _pixel_layer == null:
		return
	for pt in _ambient_brazier_points():
		if has_v016_fx("fire_brazier"):
			_draw_sheet_frame(_pixel_layer, "fire_brazier", "fire_brazier", Vector2(pt), 24.0, 0.0, 0.96, Color.WHITE, 0.0)
	for item in game.effects:
		var kind := str(item.kind)
		var sheet_key := _resolve_sheet_key(kind)
		if sheet_key == "" or not has_v016_fx(sheet_key):
			continue
		var dur := maxf(0.01, float(item.duration))
		var p: float = clampf(1.0 - float(item.life) / dur, 0.0, 1.0)
		var alpha := 1.0 if kind in ["fire_brazier", "brazier"] else clampf(1.0 - pow(p, 2.4), 0.0, 1.0)
		var tint_w := float(V016_SHEETS.get(sheet_key, {}).get("tint", 0.25))
		var base_col: Color = Color(item.colour)
		var tint := Color.WHITE.lerp(Color(base_col.r, base_col.g, base_col.b, 1.0), tint_w)
		var angle := _sheet_angle(kind, item)
		_draw_sheet_frame(_pixel_layer, sheet_key, kind, item.point, float(item.radius), p, alpha, tint, angle)


func _draw_glow_layer() -> void:
	if game == null or not game.started or _glow_layer == null:
		return
	var reduced := _is_reduced_motion()
	var glow_mul := 0.45 if reduced else 1.0

	# 1. Ambient brazier warm flickering aura + Kenney CC0 flame & rising sparks
	var fire_tex := kenney_tex.get("fire") as Texture2D
	var flare_tex := kenney_tex.get("flare") as Texture2D
	for pt in _ambient_brazier_points():
		var p_vec := Vector2(pt)
		var flick := 1.0 if reduced else (0.86 + 0.14 * sin(_clock * 12.0 + p_vec.x * 0.17))
		if fire_tex != null:
			var sway := 0.0 if reduced else sin(_clock * 7.5 + p_vec.y * 0.13) * 0.12
			_glow_layer.draw_set_transform(p_vec + Vector2(0, -14), sway, Vector2(0.88 + 0.12 * flick, 1.0 + 0.16 * flick))
			_glow_layer.draw_texture_rect(fire_tex, Rect2(Vector2(-26, -30), Vector2(52, 52)), false, Color(1.0, 0.66, 0.24, 0.62 * glow_mul))
			_glow_layer.draw_set_transform(Vector2.ZERO)
		elif has_v016_fx("fire_brazier"):
			_draw_sheet_frame(_glow_layer, "fire_brazier", "fire_brazier", p_vec, 24.0, 0.0, 0.36 * glow_mul * flick, Color("ffb35c"), 0.0, 1.08)
		if flare_tex != null and not reduced:
			for e_idx in range(2):
				var ep := fmod(_clock * (0.85 + 0.25 * float(e_idx)) + p_vec.x * 0.03 + float(e_idx) * 0.5, 1.0)
				var ex := sin(_clock * 4.0 + float(e_idx) * 2.1 + p_vec.x) * 9.0 * ep
				var ey := -12.0 - ep * 34.0
				var ea := (1.0 - ep) * 0.65 * glow_mul
				_glow_layer.draw_texture_rect(flare_tex, Rect2(p_vec + Vector2(ex - 9.0, ey - 9.0), Vector2(18, 18)), false, Color(1.0, 0.82, 0.38, ea))
		if _glow_tex != null:
			_glow_layer.draw_texture_rect(_glow_tex, Rect2(p_vec + Vector2(-56, -68), Vector2(112, 112)), false, Color(1.0, 0.58, 0.22, 0.32 * glow_mul * flick))

	# 2. Active effects additive bloom + Kenney CC0 smooth magic/smoke/spark bursts
	var magic_tex := kenney_tex.get("magic") as Texture2D
	var circle_tex := kenney_tex.get("circle") as Texture2D
	var spark_tex := kenney_tex.get("spark") as Texture2D
	for item in game.effects:
		var kind := str(item.kind)
		var sheet_key := _resolve_sheet_key(kind)
		var dur := maxf(0.01, float(item.duration))
		var p: float = clampf(1.0 - float(item.life) / dur, 0.0, 1.0)
		var fade := clampf(1.0 - p * p, 0.0, 1.0)
		var col := Color(item.colour)
		if sheet_key != "" and has_v016_fx(sheet_key):
			var angle := _sheet_angle(kind, item)
			var add_tint := Color.WHITE.lerp(Color(col.r, col.g, col.b, 1.0), 0.55)
			var add_alpha := (0.16 if kind == "upgrade" else (0.42 if kind in ["blast", "lightning", "shield_break"] else 0.34)) * fade * glow_mul
			_draw_sheet_frame(_glow_layer, sheet_key, kind, item.point, float(item.radius), p, add_alpha, add_tint, angle, 1.04)
		if circle_tex != null and kind in ["blast", "slam", "frost", "shield_break"]:
			var cr := maxf(float(item.radius) * (0.45 + 0.72 * p), 28.0)
			_glow_layer.draw_set_transform(item.point, p * 1.4, Vector2(1.0, 0.65 if kind in ["slam", "upgrade"] else 1.0))
			_glow_layer.draw_texture_rect(circle_tex, Rect2(-Vector2.ONE * cr, Vector2.ONE * cr * 2.0), false, Color(col.r, col.g, col.b, 0.38 * fade * glow_mul))
			_glow_layer.draw_set_transform(Vector2.ZERO)
		if magic_tex != null and kind in ["frost", "summon", "shield_break"]:
			var mr := maxf(float(item.radius) * (0.6 + 0.5 * p), 32.0)
			_glow_layer.draw_set_transform(item.point, -p * 2.1)
			_glow_layer.draw_texture_rect(magic_tex, Rect2(-Vector2.ONE * mr, Vector2.ONE * mr * 2.0), false, Color(col.r, col.g, col.b, 0.34 * fade * glow_mul))
			_glow_layer.draw_set_transform(Vector2.ZERO)
		if spark_tex != null and kind in ["hit", "slash", "blast", "lightning"]:
			var sr := maxf(float(item.radius) * (0.55 + 0.45 * p), 24.0)
			_glow_layer.draw_set_transform(item.point, _sheet_angle(kind, item) + p * 0.8)
			_glow_layer.draw_texture_rect(spark_tex, Rect2(-Vector2.ONE * sr, Vector2.ONE * sr * 2.0), false, Color(1.0, 0.94, 0.76, 0.45 * fade * glow_mul))
			_glow_layer.draw_set_transform(Vector2.ZERO)
		if _glow_tex != null and not (kind in ["roll_painted", "arrow_impact_painted", "cannon_blast", "tower_arc", "tower_arc_fork", "tower_arc_relay", "tower_arc_surge", "tower_beam", "tower_beam_focus", "tower_beam_sweep", "tower_beam_far_lens", "snare_snap", "tower_frost", "tower_frost_inner", "tower_arcfire"]):
			var halo_r := maxf(float(item.radius) * (0.75 + 0.25 * p), 24.0)
			var halo_alpha := (0.14 if kind == "upgrade" else (0.28 if kind in ["blast", "shield_break", "frost", "lightning", "storm_hit", "lens_hit"] else 0.16)) * fade * glow_mul
			var center_pt := Vector2(item.point)
			_glow_layer.draw_texture_rect(_glow_tex, Rect2(center_pt - Vector2.ONE * halo_r, Vector2.ONE * halo_r * 2.0), false, Color(col.r, col.g, col.b, halo_alpha))
		elif _glow_tex != null and kind.begins_with("tower_beam"):
			var end_pt := Vector2(item.point) + Vector2(item.direction).normalized() * float(item.radius)
			var layers := int(item.get("meta", {}).get("layers", 0))
			var b_rad := 24.0 + float(layers) * 6.0
			_glow_layer.draw_texture_rect(_glow_tex, Rect2(end_pt - Vector2.ONE * b_rad, Vector2.ONE * b_rad * 2.0), false, Color(1.0, 0.88, 0.42, 0.48 * fade * glow_mul))

	# 3. Ground telegraph center convergence glow (additive, ground-squashed)
	for item in game.delayed:
		if item.source != "enemy":
			continue
		var dur := maxf(0.01, float(item.duration))
		var p := clampf(1.0 - float(item.life) / dur, 0.0, 1.0)
		var telegraph_tag := str(item.options.get("telegraph", ""))
		var ruin_telegraph := telegraph_tag in ["arcane_slam", "rift_collapse"]
		var glow_col := Color(0.55, 0.85, 1.0) if telegraph_tag == "rift_collapse" else (Color(0.78, 0.54, 1.0) if ruin_telegraph else (Color(0.45, 0.92, 0.44) if telegraph_tag == "toxic_bomb" else (Color(1.0, 0.42, 0.28) if telegraph_tag in ["boss_slam", "bear_slam"] else Color(1.0, 0.68, 0.36))))
		if _glow_tex != null:
			var pulse := 1.0 if reduced else (0.85 + 0.15 * sin(_clock * 10.0 + p * 8.0))
			var core_r := maxf(18.0, float(item.radius) * (0.35 + 0.55 * p))
			_glow_layer.draw_set_transform(item.point, 0.0, Vector2(1.0, 0.58))
			_glow_layer.draw_texture_rect(_glow_tex, Rect2(-Vector2.ONE * core_r, Vector2.ONE * core_r * 2.0), false, Color(glow_col.r, glow_col.g, glow_col.b, (0.14 + 0.28 * p) * pulse * glow_mul))
			_glow_layer.draw_set_transform(Vector2.ZERO)


func _draw_delayed_indicators() -> void:
	var reduced := _is_reduced_motion()
	for item in game.delayed:
		var dur := maxf(0.01, float(item.duration))
		var p: float = clampf(1.0 - float(item.life) / dur, 0.0, 1.0)
		var colour := Color(0.95, 0.58, 0.34) if item.source == "enemy" else ArenaCombat.colour(item.type)

		if item.source == "enemy":
			_draw_enemy_telegraph(item, p, reduced)
		else:
			_draw_friendly_telegraph(item, p, colour)

		if item.options.has("origin"):
			var orig_pt := Vector2(item.options.origin)
			var dest_pt := Vector2(item.point)
			var ground_pt: Vector2 = orig_pt.lerp(dest_pt, p)
			var dist := orig_pt.distance_to(dest_pt)
			var peak_h := clampf(dist * 0.38, 82.0, 148.0)
			var height_frac := 4.0 * p * (1.0 - p)
			var arc_pt := ground_pt + Vector2(0.0, -height_frac * peak_h)
			var shell_scale := 1.0 + (0.16 if reduced else 0.38) * height_frac

			# 1. Converging Ground Shadow (shrinks/softens at apex, sharpens and converges on landing)
			var shad_r := lerpf(11.5, 6.5, height_frac)
			var shad_a := lerpf(0.56, 0.22, height_frac)
			draw_set_transform(ground_pt, 0.0, Vector2(1.0, 0.42))
			draw_circle(Vector2.ZERO, shad_r * 1.25, Color(0.08, 0.06, 0.08, shad_a * 0.55))
			draw_circle(Vector2.ZERO, shad_r, Color(0.11, 0.09, 0.11, shad_a))
			draw_set_transform(Vector2.ZERO)

			# 2. Parabolic Smoke Trail & Ballistic Ribbon behind the shell
			var trail_steps := 5
			var prev_pt := arc_pt
			for s_i in range(1, trail_steps + 1):
				var tp := maxf(0.0, p - float(s_i) * 0.048)
				var tg := orig_pt.lerp(dest_pt, tp)
				var th := 4.0 * tp * (1.0 - tp) * peak_h
				var t_arc := tg + Vector2(0.0, -th)
				var u_fade := 1.0 - float(s_i) / float(trail_steps + 1)
				draw_line(prev_pt, t_arc, Color(0.95, 0.72, 0.38, u_fade * 0.52), 2.0 + 3.2 * u_fade, true)
				var puff_r := (4.2 + float(s_i) * 1.5) * (0.85 + 0.15 * height_frac)
				draw_circle(t_arc, puff_r, Color(0.76, 0.70, 0.64, u_fade * 0.36))
				prev_pt = t_arc

			# 3. Heavy Spinning Cast-Iron Mortar Bomb + Live Burning Fuse Spark
			var tangent := (dest_pt - orig_pt) + Vector2(0.0, -4.0 * (1.0 - 2.0 * p) * peak_h)
			var spin_ang := tangent.angle() + p * 8.5
			var is_toxic_bomb := str(item.options.get("telegraph", "")) == "toxic_bomb"
			var shell_doc := str(item.options.get("doctrine_id", ""))
			if is_toxic_bomb:
				var flask_r := 7.6 * shell_scale
				draw_circle(arc_pt, flask_r + 1.8, Color("1a2218"))
				draw_circle(arc_pt, flask_r, Color("48c958"))
				draw_circle(arc_pt + Vector2(-flask_r * 0.2, -flask_r * 0.2), flask_r * 0.6, Color("b4ff96"))
				draw_set_transform(arc_pt, spin_ang)
				draw_rect(Rect2(-flask_r * 0.3, -flask_r * 1.35, flask_r * 0.6, flask_r * 0.55), Color("7a5838"))
				draw_circle(Vector2(0, -flask_r * 1.45), 2.8 * shell_scale, Color("9cff78"))
				draw_set_transform(Vector2.ZERO)
			elif shell_doc == "burning":
				var pot_r := 8.8 * shell_scale
				draw_circle(arc_pt, pot_r + 2.0, Color("14111b"))
				draw_circle(arc_pt, pot_r, Color("b82a18"))
				draw_circle(arc_pt + Vector2(-pot_r * 0.2, -pot_r * 0.2), pot_r * 0.66, Color("ff7a28"))
				draw_circle(arc_pt + Vector2(-pot_r * 0.3, -pot_r * 0.3), pot_r * 0.32, Color("fff2a0"))
			elif shell_doc == "frag":
				var frag_r := 8.6 * shell_scale
				draw_circle(arc_pt, frag_r + 2.0, Color("14111b"))
				draw_circle(arc_pt, frag_r, Color("9a7230"))
				draw_set_transform(arc_pt, spin_ang)
				draw_rect(Rect2(-frag_r * 0.8, -frag_r * 0.25, frag_r * 1.6, frag_r * 0.5), Color("f0be58"))
				draw_rect(Rect2(-frag_r * 0.25, -frag_r * 0.8, frag_r * 0.5, frag_r * 1.6), Color("ffd878"))
				draw_set_transform(Vector2.ZERO)
			else:
				var bomb_r := (10.6 if shell_doc == "siege" else 8.8) * shell_scale
				draw_circle(arc_pt, bomb_r + 2.0, Color("14111b"))
				draw_circle(arc_pt, bomb_r, Color("343640"))
				draw_circle(arc_pt + Vector2(-bomb_r * 0.18, -bomb_r * 0.18), bomb_r * 0.76, Color("5c6070"))
				draw_set_transform(arc_pt, spin_ang)
				draw_line(Vector2(-bomb_r * 0.88, 0), Vector2(bomb_r * 0.88, 0), Color("e4ae48" if shell_doc == "siege" else "a87e4c"), 2.4 * shell_scale, false)
				draw_circle(Vector2(-bomb_r * 0.32, -bomb_r * 0.32), bomb_r * 0.28, Color("e6ded5"))
				var fuse_end := Vector2(-bomb_r * 1.18, -bomb_r * 0.35)
				draw_line(Vector2(-bomb_r * 0.75, -bomb_r * 0.15), fuse_end, Color("4a3525"), 2.0, false)
				draw_circle(fuse_end, 4.0 * shell_scale, Color(1.0, 0.55, 0.16, 0.88))
				draw_circle(fuse_end, 2.2 * shell_scale, Color("fff8c4"))
				draw_set_transform(Vector2.ZERO)
func _draw_cannon_blast(point: Vector2, r: float, p: float, reduced: bool, meta: Dictionary = {}) -> void:
	var doc := str(meta.get("doctrine", ""))
	var is_burn := doc == "burning"
	var is_siege := doc == "siege"
	var is_frag := doc == "frag"
	var blast_scale := 1.18 if is_siege else 1.0
	var fade := clampf(1.0 - p, 0.0, 1.0)
	# 1. Ground Scorch Crater & Ember Fissures (persists and fades smoothly)
	draw_set_transform(point, 0.0, Vector2(1.0, 0.56))
	var crater_r := r * 0.62 * blast_scale
	draw_circle(Vector2.ZERO, crater_r * 1.15, Color(0.11, 0.09, 0.08, 0.48 * fade))
	draw_circle(Vector2.ZERO, crater_r * 0.78, Color(0.06, 0.05, 0.05, 0.60 * fade))
	if p < 0.55:
		var ember_a := (1.0 - p / 0.55) * 0.88
		draw_circle(Vector2.ZERO, crater_r * 0.45 * (1.0 - p), Color(1.0, 0.36 if is_burn else 0.52, 0.12, ember_a))
		draw_arc(Vector2.ZERO, crater_r * (0.45 + 0.55 * sqrt(p / 0.55)), 0.0, TAU, 36, Color(1.0, 0.52 if is_burn else 0.82, 0.24, ember_a), 3.4, false)
	# Ground shockwave ring (dual ring for frag/siege)
	if p < 0.48:
		var sw_p := p / 0.48
		var sw_r := r * blast_scale * (0.28 + 0.86 * sqrt(sw_p))
		draw_arc(Vector2.ZERO, sw_r, 0.0, TAU, 44, Color(1.0, 0.90, 0.62, (1.0 - sw_p) * 0.92), 3.8 * (1.0 - sw_p) + 1.0, false)
		if is_frag or is_siege:
			draw_arc(Vector2.ZERO, sw_r * 0.72, 0.0, TAU, 36, Color(1.0, 0.65, 0.28, (1.0 - sw_p) * 0.85), 2.5, false)
	draw_set_transform(Vector2.ZERO)

	# 2. Brief 1-2 Frame Hot Core Flash + Expanding Fireball & Rolling Black Smoke
	if p < 0.12:
		var fl_a := (1.0 - p / 0.12)
		draw_circle(point + Vector2(0, -8), r * 0.38 * blast_scale * (0.7 + 0.4 * p / 0.12), Color(1.0, 0.92, 0.68, 0.84 * fl_a))
	if p < 0.72:
		var fp := p / 0.72
		var smoke_fade := clampf(1.0 - fp * fp, 0.0, 1.0)
		for k in range(6):
			var ka := float(k) * (TAU / 6.0) + 0.35
			var spread := r * blast_scale * (0.18 + 0.56 * sqrt(fp))
			var puff_pos := point + Vector2(cos(ka) * spread, sin(ka) * spread * 0.55 - fp * 22.0)
			var puff_sz := (14.0 + (k % 2) * 4.5) * (0.85 + 0.55 * fp)
			draw_circle(puff_pos, puff_sz, Color(0.18, 0.15, 0.16, 0.66 * smoke_fade))
			if fp < 0.58:
				var fire_a := (1.0 - fp / 0.58)
				draw_circle(puff_pos.lerp(point + Vector2(0, -6), 0.38), puff_sz * 0.74, Color(1.0, (0.30 if is_burn else 0.46) + 0.24 * (k % 2), 0.12, 0.86 * fire_a))
				draw_circle(puff_pos.lerp(point + Vector2(0, -10), 0.58), puff_sz * 0.44, Color(1.0, 0.92, 0.54, 0.90 * fire_a))

	# 3. Parabolic Bouncing Shrapnel & Rock Debris Chunks
	if not reduced and p < 0.82:
		var dp := p / 0.82
		var count := 10 if (is_frag or is_siege) else 6
		for s_i in range(count):
			var sa := float(s_i) * (TAU / float(count)) + 0.22
			var reach := r * blast_scale * (0.42 + 0.16 * float(s_i % 3)) * dp
			var ground_d := point + Vector2(cos(sa) * reach, sin(sa) * reach * 0.58)
			var bounce_h := absf(sin(dp * PI * 2.15)) * (30.0 - float(s_i % 2) * 7.0) * (1.0 - dp * 0.72)
			var chunk_pt := ground_d + Vector2(0.0, -bounce_h)
			var c_fade := clampf(1.0 - dp * 0.85, 0.0, 1.0)
			draw_circle(ground_d, 2.6, Color(0.08, 0.07, 0.07, 0.38 * c_fade))
			draw_set_transform(chunk_pt, dp * 9.0 + float(s_i))
			var inner_c := Color(1.0, 0.76, 0.32, c_fade) if (is_frag or is_burn) else Color(0.68, 0.56, 0.44, c_fade)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-3.8, -2.2), Vector2(3.6, -3.0), Vector2(4.2, 2.4), Vector2(-2.6, 3.4)
			]), Color(0.14, 0.11, 0.12, c_fade))
			draw_colored_polygon(PackedVector2Array([
				Vector2(-2.6, -1.5), Vector2(2.4, -2.0), Vector2(2.8, 1.4), Vector2(-1.8, 2.2)
			]), inner_c)
			draw_set_transform(Vector2.ZERO)

func _draw_tower_arc(item: Dictionary, p: float, reduced: bool) -> void:
	var dir := Vector2(item.direction).normalized()
	if dir.is_zero_approx(): dir = Vector2.RIGHT
	var seg_len := maxf(8.0, float(item.radius))
	var start := Vector2(item.point)
	var end := start + dir * seg_len
	var doc := str(item.get("meta", {}).get("doctrine", ""))
	var is_surge := doc == "surge"
	var is_relay := doc == "relay"
	var fade := clampf(1.0 - p * p, 0.0, 1.0)
	var outer_col := Color("122248")
	var mid_col := Color("9a6cff") if is_relay else Color("42d8ff")
	var core_col := Color("ffffff")
	var seed_val := float(int(start.x + end.y) % 29)
	var tick := floorf(_clock * (18.0 if not reduced else 6.0))
	var perp := Vector2(-dir.y, dir.x)
	var steps := 8 if seg_len > 90.0 else 6
	var pts := PackedVector2Array([start])
	for i in range(1, steps):
		var u := float(i) / float(steps)
		var env := sin(u * PI)
		var jitter := sin(u * 13.0 + seed_val + tick * 2.7) * (13.0 if is_surge else 9.5) * env
		pts.append((start.lerp(end, u) + perp * jitter).snapped(Vector2(2, 2)))
	pts.append(end)
	var w_mul := 1.45 if is_surge else (0.95 if is_relay else 1.1)
	draw_polyline(pts, Color(outer_col.r, outer_col.g, outer_col.b, 0.9 * fade), 6.2 * w_mul, false)
	draw_polyline(pts, Color(mid_col.r, mid_col.g, mid_col.b, fade), 3.6 * w_mul, false)
	draw_polyline(pts, Color(core_col.r, core_col.g, core_col.b, fade), 1.6 * w_mul, false)
	# Branch forks
	if not reduced and pts.size() >= 5:
		for b_idx in [2, pts.size() - 3]:
			var bp := pts[b_idx]
			var side := 1.0 if (int(b_idx + tick) % 2 == 0) else -1.0
			var b1 := (bp + dir * 12.0 + perp * side * 14.0).snapped(Vector2(2, 2))
			var b2 := (b1 + dir * 10.0 + perp * side * 7.0).snapped(Vector2(2, 2))
			draw_polyline(PackedVector2Array([bp, b1, b2]), Color(outer_col.r, outer_col.g, outer_col.b, 0.8 * fade), 3.4, false)
			draw_polyline(PackedVector2Array([bp, b1, b2]), Color(mid_col.r, mid_col.g, mid_col.b, fade), 1.8, false)
			draw_polyline(PackedVector2Array([bp, b1]), Color(core_col.r, core_col.g, core_col.b, fade), 1.0, false)

func _draw_storm_hit(item: Dictionary, p: float, reduced: bool) -> void:
	var pt := Vector2(item.point).snapped(Vector2(2, 2))
	var r := float(item.radius) * (0.65 + 0.55 * sqrt(p))
	var fade := clampf(1.0 - p * p, 0.0, 1.0)
	var doc := str(item.get("meta", {}).get("doctrine", ""))
	var mid := Color("a878ff") if doc == "relay" else Color("48dcff")
	var rays := 4 if reduced else 6
	for k in range(rays):
		var a := float(k) * (TAU / float(rays)) + 0.3
		var p1 := (pt + Vector2.from_angle(a) * (r * 0.48) + Vector2(sin(a * 3.0) * 4.0, 0.0)).snapped(Vector2(2, 2))
		var p2 := (pt + Vector2.from_angle(a) * r).snapped(Vector2(2, 2))
		draw_polyline(PackedVector2Array([pt, p1, p2]), Color(0.07, 0.13, 0.28, fade * 0.85), 4.0, false)
		draw_polyline(PackedVector2Array([pt, p1, p2]), Color(mid.r, mid.g, mid.b, fade), 2.2, false)
		draw_line(pt, p1, Color(1, 1, 1, fade), 1.2, false)
	draw_circle(pt, 5.5 * fade, Color(1, 1, 1, fade))

func _draw_tower_beam(item: Dictionary, p: float, reduced: bool) -> void:
	var dir := Vector2(item.direction).normalized()
	if dir.is_zero_approx(): dir = Vector2.RIGHT
	var seg_len := maxf(8.0, float(item.radius))
	var start := Vector2(item.point)
	var end := start + dir * seg_len
	var meta: Dictionary = item.get("meta", {})
	var layers := clampi(int(meta.get("layers", 0)), 0, 4)
	var doc := str(meta.get("doctrine", ""))
	var fade := clampf(1.0 - p * p, 0.0, 1.0)
	var core_w := (2.6 + float(layers) * 1.15) * (1.15 if doc == "focus" else (0.85 if doc == "far_lens" else 1.0)) * fade
	var outer_col := Color("3b1808")
	var rim_col := Color("d6ecff") if doc == "sweep" else Color("ff9218")
	var hot_col := Color("fffacc")
	draw_line(start, end, Color(outer_col.r, outer_col.g, outer_col.b, 0.85 * fade), core_w + 5.0, false)
	draw_line(start, end, Color(rim_col.r, rim_col.g, rim_col.b, 0.95 * fade), core_w + 2.4, false)
	draw_line(start, end, Color(hot_col.r, hot_col.g, hot_col.b, fade), core_w, false)
	draw_line(start, end, Color(1, 1, 1, fade), maxf(1.2, core_w * 0.48), false)
	# High-energy focus rings along sniper beam / high layers
	if doc == "far_lens" or layers >= 2:
		var step_d := 22.0 + float(p * 18.0)
		var perp := Vector2(-dir.y, dir.x)
		var ring_p := start + dir * minf(seg_len * 0.45, step_d)
		var rr := 6.0 + float(layers) * 1.4
		draw_line(ring_p - perp * rr, ring_p + perp * rr, Color(1.0, 0.92, 0.56, fade * 0.88), 2.0, false)
	if not reduced:
		var pulse_pt := start.lerp(end, fmod(p * 1.6, 1.0)).snapped(Vector2(2, 2))
		draw_rect(Rect2(pulse_pt - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1, fade))

func _draw_lens_hit(item: Dictionary, p: float, reduced: bool) -> void:
	var pt := Vector2(item.point).snapped(Vector2(2, 2))
	var layers := clampi(int(item.get("meta", {}).get("layers", 0)), 0, 4)
	var fade := clampf(1.0 - p, 0.0, 1.0)
	var sz := (12.0 + float(layers) * 4.5) * (0.7 + 0.45 * p)
	var rot := 0.0 if reduced else p * 2.4
	draw_circle(pt, sz * 0.42, Color(1.0, 0.86, 0.34, 0.85 * fade))
	for k in range(4):
		var a := rot + float(k) * (PI * 0.25)
		var v := Vector2.from_angle(a) * sz
		draw_line(pt - v, pt + v, Color(0.24, 0.11, 0.04, 0.82 * fade), 4.0, false)
		draw_line(pt - v, pt + v, Color(1.0, 0.78, 0.24, 0.95 * fade), 2.2, false)
		draw_line(pt - v * 0.55, pt + v * 0.55, Color(1, 1, 1, fade), 1.4, false)

func _draw_snare_snap(item: Dictionary, p: float, reduced: bool) -> void:
	var pt := Vector2(item.point)
	var meta: Dictionary = item.get("meta", {})
	var doc := str(meta.get("doctrine", ""))
	var fade := clampf(1.0 - p, 0.0, 1.0)
	# Taut rope / barbed chain pull line from workshop winch to snare site in early snap
	if meta.has("origin") and p < 0.48:
		var orig := Vector2(meta.origin)
		var line_fade := 1.0 - p / 0.48
		var rope_dark := Color("14111b")
		var rope_col := Color("b8c4d8") if doc == "barb" else (Color("f4c458") if doc == "ratchet" else Color("e0b26c"))
		var mid := orig.lerp(pt, 0.5) + Vector2(0, sin(p * 42.0) * 4.0)
		draw_polyline(PackedVector2Array([orig, mid, pt]), Color(rope_dark.r, rope_dark.g, rope_dark.b, 0.85 * line_fade), 4.5, false)
		draw_polyline(PackedVector2Array([orig, mid, pt]), Color(rope_col.r, rope_col.g, rope_col.b, 0.95 * line_fade), 2.2, false)
	# Trap burst sprite sheet frame
	var trap_name := "snare_barb" if doc == "barb" else ("snare_ratchet" if doc == "ratchet" else "snare_net")
	var cols := 4 if trap_name == "snare_net" else 2
	var f_idx := clampi(int(floor(p * 3.0)) + 1 if cols == 4 else (0 if p < 0.18 else 1), 0, cols - 1)
	var tex := ArenaBattleArt.prop_frame_texture(trap_name, f_idx, cols)
	if tex != null:
		var sz := (Vector2(66.0, 50.0) if trap_name == "snare_net" else Vector2(68.0, 50.0)) * (0.92 + 0.16 * sin(minf(p, 0.5) * PI))
		draw_texture_rect(tex, Rect2(pt - sz * 0.5, sz), false, Color(1, 1, 1, clampf(fade * 1.4, 0.0, 1.0)))
	if not reduced:
		draw_set_transform(pt, 0.0, Vector2(1.0, 0.58))
		draw_arc(Vector2.ZERO, float(item.radius) * (0.45 + 0.55 * sqrt(p)), 0.0, TAU, 32, Color(0.95, 0.88, 0.62, 0.72 * fade), 2.2, false)
		draw_set_transform(Vector2.ZERO)

func _draw_tower_pulse(item: Dictionary, p: float, reduced: bool) -> void:
	var pt := Vector2(item.point)
	var r := maxf(16.0, float(item.radius))
	var kind := str(item.kind)
	var is_fire := kind == "tower_arcfire"
	var is_inner := kind == "tower_frost_inner"
	var fade := clampf(1.0 - p * p, 0.0, 1.0)
	var exp_r := r * (0.32 + 0.68 * sqrt(p))
	var dark_c := Color("241008" if is_fire else "12203a")
	var mid_c := Color("ff7a20" if is_fire else ("58d8ff" if is_inner else "70c8f8"))
	var hi_c := Color("fff4b0" if is_fire else "eeffff")
	draw_arc(pt, exp_r, 0.0, TAU, 40, Color(dark_c.r, dark_c.g, dark_c.b, 0.72 * fade), 6.0 if not is_inner else 4.5, false)
	draw_arc(pt, exp_r, 0.0, TAU, 40, Color(mid_c.r, mid_c.g, mid_c.b, 0.90 * fade), 3.4 if not is_inner else 2.6, false)
	draw_arc(pt, exp_r, 0.0, TAU, 40, Color(hi_c.r, hi_c.g, hi_c.b, 0.82 * fade), 1.4, false)
	if is_inner:
		return
	var shards := 6 if reduced else 10
	for k in range(shards):
		var a := float(k) * (TAU / float(shards)) + (0.4 if is_fire else 0.0)
		var dist := exp_r * 0.86
		var sp := (pt + Vector2.from_angle(a) * dist).snapped(Vector2(2, 2))
		var tang := Vector2.from_angle(a) * (8.0 * fade + 3.0)
		var perp := Vector2(-tang.y, tang.x) * 0.45
		draw_colored_polygon(PackedVector2Array([sp + tang, sp + perp, sp - tang * 0.6, sp - perp]), Color(dark_c.r, dark_c.g, dark_c.b, fade))
		draw_colored_polygon(PackedVector2Array([sp + tang * 0.8, sp + perp * 0.65, sp - tang * 0.4, sp - perp * 0.65]), Color(hi_c.r, hi_c.g, hi_c.b, fade))


func _draw_magic_impact_extra(point: Vector2, r: float, p: float, reduced: bool) -> void:
	var fade := clampf(1.0 - p * p, 0.0, 1.0)
	if fade <= 0.05:
		return
	draw_set_transform(point + Vector2(0, 6), 0.0, Vector2(1.0, 0.55))
	var ring_r := maxf(4.0, r * (0.35 + 0.85 * sqrt(p)))
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32, Color(0.58, 0.78, 1.0, 0.76 * fade), 2.4, true)
	draw_arc(Vector2.ZERO, maxf(2.5, ring_r * 0.68), 0.0, TAU, 24, Color(0.92, 0.96, 1.0, 0.68 * fade), 1.4, true)
	draw_set_transform(Vector2.ZERO)
	if not reduced and fade > 0.14:
		var shard_len := maxf(2.2, 4.5 * fade)
		for i in range(5):
			var a := float(i) * (TAU / 5.0) + p * 1.6
			var dist := r * (0.25 + 0.95 * sqrt(p))
			var sp := point + Vector2(cos(a) * dist, sin(a) * dist * 0.68 - p * 10.0)
			var tang := Vector2.from_angle(a) * shard_len
			var perp := Vector2(-tang.y, tang.x) * 0.58
			draw_colored_polygon(PackedVector2Array([sp + tang, sp + perp, sp - tang, sp - perp]), Color(0.86, 0.95, 1.0, 0.88 * fade))


# A tapered sweep follows the fast portion of the strike. Its trailing end
# narrows while its leading edge stays aligned with the attack direction.
func _draw_blade_sweep(point: Vector2, angle: float, radius: float, p: float, reduced: bool) -> void:
	if p >= 0.74:
		return
	var edge := angle + lerpf(-0.6,1.0,sqrt(p/0.74))
	var points := PackedVector2Array()
	for i in range(11):
		var u := i/10.0
		points.append(point + Vector2.from_angle(edge-1.32*(1-u))*radius*(0.60+0.18*u))
	for i in range(10,-1,-1):
		var u := i/10.0
		points.append(point + Vector2.from_angle(edge-1.32*(1-u))*radius*(0.60+0.10*u))
	draw_colored_polygon(points,Color(1.0,0.86,0.60,(0.36 if reduced else 0.78)*(1-p)))

func _draw_pixel_contact(item: Dictionary, life: float) -> void:
	var direction: Vector2=item.direction.normalized()
	if direction.is_zero_approx():direction=Vector2.RIGHT
	var tangent:=direction.orthogonal()
	var point: Vector2=Vector2(item.point).snapped(Vector2(2,2))
	var colour: Color=item.colour
	colour.a*=life
	var spread:=float(item.radius)*(1.0-life)
	for index in range(5 if not _is_reduced_motion() else 3):
		var offset: float=float(index)-2.0
		var pos: Vector2=(point+direction*spread+tangent*offset*(3.0+spread*0.35)).snapped(Vector2(2,2))
		draw_rect(Rect2(pos,Vector2(4,3)),colour if index%2==0 else colour.darkened(0.25))
	if item.kind=="shield_contact" and life>0.45:
		draw_line(point-tangent*13,point+tangent*13,colour,3.0)

func _draw_contact(item: Dictionary, p: float, reduced: bool) -> void:
	var direction := Vector2(item.direction)
	if direction.is_zero_approx():
		direction = Vector2.RIGHT
	var fade := 1.0-p
	draw_set_transform(item.point,direction.angle())
	if item.kind=="ward_contact":
		draw_arc(Vector2(7,0),13.0+p*4.0,PI*0.56,PI*1.44,12,Color(0.66,0.90,1.0,fade),2.5,true)
	else:
		var reach := (10.0 if reduced else 22.0)*sqrt(p)
		if item.kind=="shaft_contact":
			# Embedded vibrating arrow shaft + white fletching feathers sticking out of the victim
			var vib: float = (0.0 if reduced else sin(p * PI * 5.5) * 2.5 * fade)
			var tail := Vector2(-19.0 + 3.0 * p, vib)
			var tip := Vector2(2.0, 0.0)
			draw_line(tail, tip, Color(0.16, 0.12, 0.10, fade * 0.92), 4.0, true)
			draw_line(tail, tip, Color(0.88, 0.66, 0.36, fade * 0.96), 2.0, true)
			for side: float in [-1.0, 1.0]:
				draw_line(tail + Vector2(0.0, side * 3.5), tail + Vector2(6.5, 0.0), Color(1.0, 0.96, 0.82, fade * 0.95), 2.1, true)
			draw_circle(tip, 4.2 * fade, Color(1.0, 0.96, 0.78, fade * 0.88))
		elif item.kind=="edge_contact":
			# Crisp crescent sword slash arc for soldier melee hits
			draw_arc(Vector2(-2.0, 0.0), 12.0 + 6.0 * p, -0.95, 0.95, 14, Color(1.0, 0.95, 0.78, fade * 0.9), 2.8 * fade + 0.8, true)
		for sign_y: float in [-1.0, 1.0]:
			var ray := Vector2(0.7,sign_y*0.72)
			draw_line(ray*(2+reach*0.55),ray*(8+reach),Color(1,0.92,0.72,fade),1.2+1.8*fade,true)
			var ray2 := Vector2(-0.35, sign_y*0.88)
			draw_line(ray2*(2+reach*0.4),ray2*(6+reach*0.75),Color(1,0.82,0.48,fade*0.85),1.0+1.2*fade,true)
	draw_set_transform(Vector2.ZERO)

func _draw_dodge_step(point: Vector2, dir: Vector2, r: float, p: float, col: Color, reduced: bool) -> void:
	var n := dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	var perp := Vector2(-n.y, n.x)
	var fade := 1.0 - p
	for i in range(-1, 2):
		var start := point - n * (r * (0.3 + 0.9 * (1.0 - p))) + perp * (float(i) * 9.0)
		var end := point + n * (r * 0.35) + perp * (float(i) * 6.0)
		draw_line(start, end, Color(col.r, col.g, col.b, (0.45 if reduced else 0.78) * fade), 2.8 * fade + 0.6, true)
	draw_set_transform(point, 0.0, Vector2(1.0, 0.45))
	draw_arc(Vector2.ZERO, r * (0.45 + 0.45 * p), 0.0, TAU, 24, Color(col.r, col.g, col.b, 0.68 * fade), 2.0, true)
	draw_set_transform(Vector2.ZERO)

func _draw_enemy_telegraph(item: Dictionary, p: float, reduced: bool) -> void:
	var telegraph_tag := str(item.options.get("telegraph", ""))
	var is_rift := telegraph_tag == "rift_collapse"
	var is_arcane := telegraph_tag in ["arcane_slam", "rift_collapse"]
	var is_toxic := telegraph_tag == "toxic_bomb"
	var is_boss_slam := telegraph_tag in ["boss_slam", "bear_slam"]
	var rad := maxf(6.0, float(item.radius))

	# Theme colors: grounded nocturnal violet-cyan for Ruins telegraphs, toxic green for Skunk bombs, crimson-amber for Beast slams.
	var wash_col := Color(0.14, 0.07, 0.28) if is_arcane else (Color(0.12, 0.24, 0.12) if is_toxic else (Color(0.30, 0.09, 0.08) if is_boss_slam else Color(0.24, 0.12, 0.10)))
	var rim_col := (Color(0.84, 0.48, 1.0) if is_rift else Color(0.72, 0.54, 1.0)) if is_arcane else (Color(0.46, 0.92, 0.42) if is_toxic else (Color(0.98, 0.38, 0.28) if is_boss_slam else Color(0.95, 0.60, 0.32)))
	var pulse_col := Color(0.56, 0.92, 1.0) if is_arcane else (Color(0.76, 1.0, 0.56) if is_toxic else Color(1.0, 0.82, 0.48))
	var hot_col := Color(1.0, 0.90, 0.62) if is_arcane else Color(1.0, 0.93, 0.72)

	var urgent := clampf((p - 0.62) / 0.38, 0.0, 1.0)
	var breath := 1.0 if reduced else (0.86 + 0.14 * sin(_clock * 8.5 + p * 6.0))
	var eased_p := 1.0 - pow(1.0 - p, 1.8)

	draw_set_transform(item.point, 0.0, Vector2(1.0, 0.58))

	# 1. Soft ground-hugging radial shadow/tint gradient (no flat solid circle cut).
	if _glow_tex != null:
		draw_texture_rect(_glow_tex, Rect2(-Vector2.ONE * rad * 1.12, Vector2.ONE * rad * 2.24), false, Color(wash_col.r, wash_col.g, wash_col.b, (0.36 + 0.24 * p)))
		var inner_r := maxf(8.0, rad * (0.28 + 0.72 * eased_p))
		draw_texture_rect(_glow_tex, Rect2(-Vector2.ONE * inner_r, Vector2.ONE * inner_r * 2.0), false, Color(rim_col.r, rim_col.g, rim_col.b, (0.16 + 0.24 * p) * breath))
	else:
		draw_circle(Vector2.ZERO, rad, Color(wash_col, 0.22 + 0.14 * p))

	# 2. Outer soft halo ring + segmented rotating rune boundary (12 dashed arcs).
	draw_arc(Vector2.ZERO, rad * 1.02, 0, TAU, 48, Color(wash_col, 0.42), 4.5, true)
	var rot_offset := 0.0 if reduced else _clock * (0.65 if is_rift else 0.42)
	var seg_count := 12
	for seg in range(seg_count):
		var a0 := rot_offset + float(seg) * (TAU / float(seg_count))
		var span := (TAU / float(seg_count)) * (0.58 + 0.16 * urgent)
		var seg_alpha := (0.45 + 0.35 * p) * breath
		draw_arc(Vector2.ZERO, rad, a0, a0 + span, 5, Color(rim_col, seg_alpha), 2.2 + 0.8 * urgent, true)

	# 3. Four rotating diamond ticks marking the hazard perimeter on ground.
	for k in range(4):
		var ka := -rot_offset * 0.7 + float(k) * (TAU * 0.25)
		var pt := Vector2.RIGHT.rotated(ka) * rad
		var tang := Vector2(-sin(ka), cos(ka))
		var norm := Vector2(cos(ka), sin(ka))
		var tick_sz := 4.5 + 2.0 * urgent
		draw_colored_polygon(
			PackedVector2Array([pt + norm * tick_sz, pt + tang * tick_sz * 0.65, pt - norm * tick_sz, pt - tang * tick_sz * 0.65]),
			Color(pulse_col, 0.6 + 0.35 * p)
		)

	# 4. Dual concentric ripple waves: converging fill front + echoing pulse wave.
	var wave_r := maxf(6.0, rad * eased_p)
	draw_arc(Vector2.ZERO, wave_r, 0, TAU, 36, Color(pulse_col, 0.55 + 0.35 * p), 2.0 + 0.6 * urgent, true)
	if not reduced:
		var echo := fmod(p * 2.2, 1.0)
		var echo_r := maxf(5.0, rad * echo)
		draw_arc(Vector2.ZERO, echo_r, 0, TAU, 32, Color(rim_col, (1.0 - echo) * 0.48), 1.6, true)

	# 5. Center focal cross-diamond sigil that sharpens right before detonation.
	var core_sz := 6.0 + 5.0 * (1.0 - urgent)
	var core_col := pulse_col.lerp(hot_col, urgent)
	draw_arc(Vector2.ZERO, core_sz, 0, TAU, 16, Color(core_col, 0.5 + 0.45 * p), 1.6, true)
	if urgent > 0.05:
		var s := 8.0 * urgent
		draw_line(Vector2(-s, 0), Vector2(s, 0), Color(hot_col, urgent * 0.9), 1.6, true)
		draw_line(Vector2(0, -s), Vector2(0, s), Color(hot_col, urgent * 0.9), 1.6, true)

	draw_set_transform(Vector2.ZERO)


func _draw_friendly_telegraph(item: Dictionary, p: float, colour: Color) -> void:
	var rad := maxf(6.0, float(item.radius))
	if item.options.has("core_radius"):
		draw_arc(item.point,rad,0.0,TAU,46,Color(0.21,0.13,0.09,0.48),3.5,true)
		draw_arc(item.point,float(item.options.core_radius),0.0,TAU,36,Color(0.21,0.13,0.09,0.65),4.6,true)
		draw_arc(item.point,rad,0.0,TAU,46,Color(colour,0.52),1.5,true)
		draw_arc(item.point,float(item.options.core_radius),0.0,TAU,36,Color(colour,0.45+0.35*p),2.5,true)
		return
	draw_set_transform(item.point)
	if _glow_tex != null:
		draw_texture_rect(_glow_tex, Rect2(-Vector2.ONE * rad, Vector2.ONE * rad * 2.0), false, Color(colour.r, colour.g, colour.b, 0.14 + 0.10 * p))
	draw_arc(Vector2.ZERO, rad, 0, TAU, 48, Color(colour, 0.48), 2.0, true)
	draw_arc(Vector2.ZERO, maxf(4.0, rad * (1.0 - p)), 0, TAU, 40, Color(colour, 0.38), 1.5, true)
	draw_set_transform(Vector2.ZERO)


func _draw_floating_numbers() -> void:
	for item in game.numbers:
		var font_size := 24 if (game.feel != null and game.feel.enabled) else 13
		if bool(item.get("critical",false)): font_size+=6
		var size := ThemeDB.fallback_font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var origin: Vector2 = item.point - Vector2(size.x * 0.5, 0)
		var alpha := minf(1.0, float(item.life) * 4.0)
		draw_string_outline(ThemeDB.fallback_font, origin, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0.12, 0.08, 0.05, alpha))
		draw_string(ThemeDB.fallback_font, origin, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(item.colour, alpha))
		var icon_position:=origin+Vector2(size.x+3,-font_size*0.70)
		for id in item.get("icons",[]):
			var card_icon:=ArenaConditions.icon(id)
			if card_icon!=null:
				draw_texture_rect(card_icon,Rect2(icon_position,Vector2(15,15)),false,Color(1,1,1,alpha))
				icon_position.x+=16.0
		if bool(item.get("capped",false)):
			draw_string_outline(ThemeDB.fallback_font,origin+Vector2(0,15),"+80%（上限）",HORIZONTAL_ALIGNMENT_LEFT,-1,13,3,Color(0.12,0.08,0.05,alpha))
			draw_string(ThemeDB.fallback_font,origin+Vector2(0,15),"+80%（上限）",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color(1,0.92,0.65,alpha))
