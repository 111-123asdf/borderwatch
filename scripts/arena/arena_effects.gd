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
	queue_redraw()
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
			size_px = maxf(r * 2.05, 80.0)
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
	_draw_war_cry_markers()
	_draw_legacy_and_painted_effects()
	_draw_delayed_indicators()
	_draw_floating_numbers()


func _draw_war_cry_markers() -> void:
	if game.feel != null and game.feel.enabled and game.war_cry_clock > 0:
		var supported: Array = game.towers + game.soldiers + [game.hero]
		for unit in supported:
			if not is_instance_valid(unit) or unit.position.distance_to(game.war_cry_position) >= game.hero.war_cry_radius():
				continue
			var marker: Vector2 = unit.position + Vector2(0, 8)
			draw_line(marker + Vector2(-6, 1), marker + Vector2(0, -5), Color("281808"), 3.5, true)
			draw_line(marker + Vector2(0, -5), marker + Vector2(6, 1), Color("281808"), 3.5, true)
			draw_line(marker + Vector2(-6, 1), marker + Vector2(0, -5), Color("f5ce7b"), 2.0, true)
			draw_line(marker + Vector2(0, -5), marker + Vector2(6, 1), Color("f5ce7b"), 2.0, true)


func _draw_legacy_and_painted_effects() -> void:
	var reduced := _is_reduced_motion()
	for item in game.effects:
		var dur := maxf(0.01, float(item.duration))
		var p: float = clampf(1.0 - float(item.life) / dur, 0.0, 1.0)
		var colour: Color = Color(item.colour, (1.0 - p) * 0.85)
		var point: Vector2 = item.point
		var r: float = item.radius
		match item.kind:
			"arrow_impact_painted", "magic_impact_painted":
				_paint("mage" if item.kind == "magic_impact_painted" else "ranger", 1, int(p * 4), point, Vector2.ONE * r * 2, 1.0 - p * p)
			"roll_painted":
				if not reduced:
					_paint("ranger", 2, int(p * 4), point, Vector2(r * 2, r), 1.0 - p, Vector2(item.direction).angle())
			"frost_painted":
				_paint("mage", 2, int(p * 4), point, Vector2.ONE * r * 2, 1.0 - p * p)
				draw_arc(point, r, 0, TAU, 48, Color(0.65, 0.88, 1.0, (1.0 - p) * 0.3), 1.5, true)
			"meteor_painted":
				var travel := Vector2(-r * 0.9 * (1.0 - p), -350.0 * (1.0 - p))
				_paint("mage", 3, 0 if p < 0.6 else 1, point + travel, Vector2.ONE * (55 + p * 25), 0.9)
			"meteor_impact":
				_paint("mage", 3, 2 if p < 0.45 else 3, point, Vector2.ONE * r * 2, 1.0 - p * p)
			"rain_impact":
				for index in range(5):
					var offset := Vector2.RIGHT.rotated(index * TAU / 5.0) * r * 0.55
					_paint("ranger", 1, int(p * 4), point + offset, Vector2.ONE * 32, 1.0 - p)
			"slash_painted", "impact_painted", "slam_painted", "banner_painted":
				if painted != null:
					var row: int = {"slash_painted": 0, "impact_painted": 1, "slam_painted": 2, "banner_painted": 3}[item.kind]
					var cell := painted.get_size() / 4.0
					var column := mini(3, int(p * 4.0))
					var angle: float = Vector2(item.direction).angle() if row == 0 else 0.0
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
			var add_alpha := (0.46 if kind in ["blast", "lightning", "shield_break", "upgrade"] else 0.36) * fade * glow_mul
			_draw_sheet_frame(_glow_layer, sheet_key, kind, item.point, float(item.radius), p, add_alpha, add_tint, angle, 1.06)
		if circle_tex != null and kind in ["blast", "slam", "frost", "shield_break", "upgrade"]:
			var cr := maxf(float(item.radius) * (0.45 + 0.72 * p), 28.0)
			_glow_layer.draw_set_transform(item.point, p * 1.4, Vector2(1.0, 0.65 if kind in ["slam", "upgrade"] else 1.0))
			_glow_layer.draw_texture_rect(circle_tex, Rect2(-Vector2.ONE * cr, Vector2.ONE * cr * 2.0), false, Color(col.r, col.g, col.b, 0.42 * fade * glow_mul))
			_glow_layer.draw_set_transform(Vector2.ZERO)
		if magic_tex != null and kind in ["upgrade", "frost", "summon", "shield_break"]:
			var mr := maxf(float(item.radius) * (0.6 + 0.5 * p), 32.0)
			_glow_layer.draw_set_transform(item.point, -p * 2.1)
			_glow_layer.draw_texture_rect(magic_tex, Rect2(-Vector2.ONE * mr, Vector2.ONE * mr * 2.0), false, Color(col.r, col.g, col.b, 0.38 * fade * glow_mul))
			_glow_layer.draw_set_transform(Vector2.ZERO)
		if spark_tex != null and kind in ["hit", "slash", "blast", "lightning"]:
			var sr := maxf(float(item.radius) * (0.55 + 0.45 * p), 24.0)
			_glow_layer.draw_set_transform(item.point, _sheet_angle(kind, item) + p * 0.8)
			_glow_layer.draw_texture_rect(spark_tex, Rect2(-Vector2.ONE * sr, Vector2.ONE * sr * 2.0), false, Color(1.0, 0.94, 0.76, 0.45 * fade * glow_mul))
			_glow_layer.draw_set_transform(Vector2.ZERO)
		if _glow_tex != null and not (kind in ["roll_painted", "arrow_impact_painted"]):
			var halo_r := maxf(float(item.radius) * (0.95 + 0.25 * p), 26.0)
			var halo_alpha := (0.30 if kind in ["blast", "upgrade", "shield_break", "frost", "lightning"] else 0.16) * fade * glow_mul
			var center_pt := Vector2(item.point) + (Vector2(0, -14) if kind == "upgrade" else Vector2.ZERO)
			_glow_layer.draw_texture_rect(_glow_tex, Rect2(center_pt - Vector2.ONE * halo_r, Vector2.ONE * halo_r * 2.0), false, Color(col.r, col.g, col.b, halo_alpha))

	# 3. Ground telegraph center convergence glow (additive, ground-squashed)
	for item in game.delayed:
		if item.source != "enemy":
			continue
		var dur := maxf(0.01, float(item.duration))
		var p := clampf(1.0 - float(item.life) / dur, 0.0, 1.0)
		var telegraph_tag := str(item.options.get("telegraph", ""))
		var ruin_telegraph := telegraph_tag in ["arcane_slam", "rift_collapse"]
		var glow_col := Color(0.55, 0.85, 1.0) if telegraph_tag == "rift_collapse" else (Color(0.78, 0.54, 1.0) if ruin_telegraph else Color(1.0, 0.68, 0.36))
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
		if game.feel != null and game.feel.enabled and item.source == "hero" and bool(item.options.get("arrow_rain", false)):
			if int(item.options.get("rain_index", 0)) == 0:
				draw_set_transform(item.point, 0.0, Vector2(1.0, 0.58))
				if _glow_tex != null:
					draw_texture_rect(_glow_tex, Rect2(-Vector2.ONE * item.radius, Vector2.ONE * item.radius * 2.0), false, Color(0.9, 0.82, 0.45, 0.14))
				draw_arc(Vector2.ZERO, item.radius, 0, TAU, 48, Color(0.9, 0.83, 0.5, 0.42), 1.5, true)
				draw_set_transform(Vector2.ZERO)
			if float(item.life) <= 0.25:
				var fall := clampf(1.0 - float(item.life) / 0.25, 0.0, 1.0)
				_paint("ranger", 3, int(fall * 4), Vector2(item.point) + Vector2(0, -140.0 * (1.0 - fall)), Vector2(item.radius * 1.5, 130), 0.85)
			continue

		if item.source == "enemy":
			_draw_enemy_telegraph(item, p, reduced)
		else:
			_draw_friendly_telegraph(item, p, colour)

		if item.options.has("origin"):
			var arc_pt: Vector2 = Vector2(item.options.origin).lerp(item.point, p) + Vector2(0, -sin(p * PI) * 100.0)
			draw_circle(arc_pt, 8.0, Color(0.12, 0.08, 0.18, 0.45))
			draw_circle(arc_pt, 6.5, colour)
			draw_circle(arc_pt - Vector2(1.8, 1.8), 2.2, Color("fff1b0"))
		elif bool(item.options.get("arrow_rain", false)):
			for index in range(5):
				var drop_pt: Vector2 = item.point + Vector2((index - 2) * 34, -180.0 * (1.0 - p))
				draw_line(drop_pt, drop_pt + Vector2(0, 15), colour, 2.0, true)


func _draw_enemy_telegraph(item: Dictionary, p: float, reduced: bool) -> void:
	var telegraph_tag := str(item.options.get("telegraph", ""))
	var is_rift := telegraph_tag == "rift_collapse"
	var is_arcane := telegraph_tag in ["arcane_slam", "rift_collapse"]
	var rad := maxf(6.0, float(item.radius))

	# Theme colors: grounded nocturnal violet-cyan for Ruins telegraphs, warm amber-ochre for Woodland spores.
	var wash_col := Color(0.14, 0.07, 0.28) if is_arcane else Color(0.24, 0.12, 0.10)
	var rim_col := (Color(0.84, 0.48, 1.0) if is_rift else Color(0.72, 0.54, 1.0)) if is_arcane else Color(0.95, 0.60, 0.32)
	var pulse_col := Color(0.56, 0.92, 1.0) if is_arcane else Color(1.0, 0.82, 0.48)
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
	draw_set_transform(item.point, 0.0, Vector2(1.0, 0.58))
	if _glow_tex != null:
		draw_texture_rect(_glow_tex, Rect2(-Vector2.ONE * rad, Vector2.ONE * rad * 2.0), false, Color(colour.r, colour.g, colour.b, 0.14 + 0.10 * p))
	draw_arc(Vector2.ZERO, rad, 0, TAU, 48, Color(colour, 0.48), 2.0, true)
	draw_arc(Vector2.ZERO, maxf(4.0, rad * (1.0 - p)), 0, TAU, 40, Color(colour, 0.38), 1.5, true)
	draw_set_transform(Vector2.ZERO)


func _draw_floating_numbers() -> void:
	for item in game.numbers:
		var font_size := 24 if (game.feel != null and game.feel.enabled) else 13
		var size := ThemeDB.fallback_font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var origin: Vector2 = item.point - Vector2(size.x * 0.5, 0)
		var alpha := minf(1.0, float(item.life) * 4.0)
		draw_string_outline(ThemeDB.fallback_font, origin, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0.12, 0.08, 0.05, alpha))
		draw_string(ThemeDB.fallback_font, origin, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(item.colour, alpha))
