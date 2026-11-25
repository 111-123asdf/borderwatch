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
	"smoke7": "res://assets/v018/particles/smoke_07.png",
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
	"meteor_comet": {"path": "res://assets/vfx_v031/vfx_meteor_comet.png", "cols": 6, "pivot": Vector2(64, 96), "tint": 0.12, "exact_cols": true},
	"frost_spikes": {"path": "res://assets/vfx_v031/vfx_frost_spikes.png", "cols": 6, "pivot": Vector2(64, 108), "tint": 0.12, "exact_cols": true},
	"blackhole_void": {"path": "res://assets/vfx_v031/vfx_blackhole_void.png", "cols": 6, "pivot": Vector2(64, 64), "tint": 0.08, "exact_cols": true},
	"orbital_beam": {"path": "res://assets/vfx_v031/vfx_orbital_beam.png", "cols": 4, "pivot": Vector2(64, 174), "tint": 0.08, "exact_cols": true},
	"portal_warp": {"path": "res://assets/vfx_v031/vfx_portal_warp.png", "cols": 8, "pivot": Vector2(64, 64), "tint": 0.06, "exact_cols": true},
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
var _smoke_puff_tex: Texture2D
var _clock := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists("res://assets/v011/physical_fx.png"):
		painted = load("res://assets/v011/physical_fx.png")
	_load_v016_assets()
	_glow_tex = _build_radial_glow_texture()
	_smoke_puff_tex = _build_smoke_puff_texture()
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


func _build_smoke_puff_texture() -> Texture2D:
	var sz := 48
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var lobes := [
		[Vector2(24, 26), 13.0], [Vector2(16, 27), 9.5], [Vector2(32, 27), 9.5],
		[Vector2(20, 20), 9.0], [Vector2(29, 21), 8.5], [Vector2(24, 17), 7.5],
		[Vector2(24, 30), 8.5]
	]
	for y in range(sz):
		for x in range(sz):
			var p := Vector2(float(x), float(y))
			var density := 0.0
			for lb in lobes:
				var c: Vector2 = lb[0]
				var r: float = float(lb[1])
				var d := p.distance_to(c) / r
				if d < 1.0:
					var u := 1.0 - d
					density = maxf(density, u * u * (1.6 - 0.6 * u))
			density = clampf(density, 0.0, 1.0)
			if density > 0.04:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, density))
	return ImageTexture.create_from_image(img)


func _has_melee_telegraph() -> bool:
	if game == null:
		return false
	for e in game.domain_enemies(game.active_domain):
		if is_instance_valid(e) and not e.dead and e.melee_windup > 0.0 and e.melee_target == game.hero:
			return true
	return false

func _process(delta: float) -> void:
	_clock += delta
	var has_active: bool = game != null and (not game.effects.is_empty() or not game.delayed.is_empty() or not game.numbers.is_empty() or _has_melee_telegraph() or (game.passive_engine != null and (not game.passive_engine.active_wells.is_empty() or not game.passive_engine.active_beams.is_empty() or not game.passive_engine.active_phantoms.is_empty())))
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
		"frost_spikes":
			return "frost_spikes" if has_v016_fx("frost_spikes") else "frost"
		"starfall", "meteor", "meteor_comet":
			return "meteor_comet" if has_v016_fx("meteor_comet") else "arcane_blast"
		"blackhole_burst", "blackhole_void":
			return "blackhole_void" if has_v016_fx("blackhole_void") else "arcane_blast"
		"void_warp", "portal_warp":
			return "portal_warp" if has_v016_fx("portal_warp") else "arcane_blast"
		"orbital_beam":
			return "orbital_beam" if has_v016_fx("orbital_beam") else "lightning"
		"blast", "arcane_blast", "summon":
			return "arcane_blast"
		"frost", "frost_shatter", "abyss_burst":
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
	if bool(spec.get("exact_cols", false)):
		return maxi(1, int(spec.get("cols", 6)))
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
		"starfall", "meteor", "meteor_comet":
			size_px = maxf(r * 2.25, 118.0)
		"frost_spikes":
			size_px = maxf(r * 2.15, 112.0)
		"blackhole_burst", "blackhole_void":
			size_px = maxf(r * 2.35, 128.0)
		"orbital_beam":
			return Vector2(maxf(r * 1.9, 108.0), maxf(r * 2.85, 168.0))
		"void_warp", "portal_warp":
			size_px = maxf(r * 2.25, 96.0)
		"blast", "summon":
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
		Color(tint.r, tint.g, tint.b, alpha * 0.96)
	)
	target.draw_set_transform(Vector2.ZERO)


func _ambient_brazier_points() -> Array:
	if not ambient_braziers.is_empty():
		return ambient_braziers
	if game == null:
		return []
	if str(game.get("level_id")) in ["saltport", "lighthouse", "ruins", "sanctum"]:
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
	_draw_enemy_melee_glints()
	_draw_floating_numbers()

func _draw_enemy_melee_glints() -> void:
	if game == null or not is_instance_valid(game.hero):
		return
	for e in game.domain_enemies(game.active_domain):
		if not is_instance_valid(e) or e.dead or e.melee_windup <= 0.0 or e.melee_target != game.hero:
			continue
		var m_total: float = maxf(0.05, float(e.melee_windup_total))
		var mp: float = 1.0 - clampf(float(e.melee_windup) / m_total, 0.0, 1.0)
		var urgent: bool = float(e.melee_windup) <= 0.22
		var heavy: bool = e._is_heavy_melee()
		var dir: Vector2 = e.melee_dir
		var vis_h: float = float(e.visual.base_height) if is_instance_valid(e.visual) else 54.0
		var glint_m := (Vector2(e.position) + Vector2(dir.x * 24.0, dir.y * 8.0 - vis_h * 0.56)).snapped(Vector2(2, 2))
		if urgent:
			var g_len := 12.0 + 3.5 * sin(float(e.melee_windup) * 34.0)
			draw_line(glint_m - Vector2(g_len, 0.0), glint_m + Vector2(g_len, 0.0), Color("14111b"), 5.5, false)
			draw_line(glint_m - Vector2(0.0, g_len), glint_m + Vector2(0.0, g_len), Color("14111b"), 5.5, false)
			draw_line(glint_m - Vector2(g_len, 0.0), glint_m + Vector2(g_len, 0.0), Color("ff5c38"), 3.2, false)
			draw_line(glint_m - Vector2(0.0, g_len), glint_m + Vector2(0.0, g_len), Color("ff5c38"), 3.2, false)
			draw_line(glint_m - Vector2(g_len * 0.65, 0.0), glint_m + Vector2(g_len * 0.65, 0.0), Color("fff6a8"), 1.8, false)
			draw_line(glint_m - Vector2(0.0, g_len * 0.65), glint_m + Vector2(0.0, g_len * 0.65), Color("fff6a8"), 1.8, false)
			draw_rect(Rect2(glint_m - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color.WHITE)
		else:
			var s_len := 6.0 + 4.5 * mp
			var g_col := Color("ff5a38", 0.94) if heavy else Color("ffb048", 0.90)
			draw_line(glint_m - Vector2(s_len, 0.0), glint_m + Vector2(s_len, 0.0), Color("14111b", 0.90), 4.0, false)
			draw_line(glint_m - Vector2(0.0, s_len), glint_m + Vector2(0.0, s_len), Color("14111b", 0.90), 4.0, false)
			draw_line(glint_m - Vector2(s_len, 0.0), glint_m + Vector2(s_len, 0.0), g_col, 2.0, false)
			draw_line(glint_m - Vector2(0.0, s_len), glint_m + Vector2(0.0, s_len), g_col, 2.0, false)


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
		if item.kind=="perfect_dodge":
			_draw_perfect_dodge(point, Vector2(item.direction), r, p, item.colour, reduced)
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
	if game.passive_engine != null:
		for w: Dictionary in game.passive_engine.active_wells:
			if str(w.get("domain", game.active_domain)) != game.active_domain:
				continue
			var wp := Vector2(w.get("pos", Vector2.ZERO))
			var wr := float(w.get("radius", 120.0))
			var wt := fmod(maxf(0.0, _clock) * 1.4, 1.0)
			if has_v016_fx("blackhole_void"):
				_draw_sheet_frame(_pixel_layer, "blackhole_void", "blackhole_void", wp, wr * 0.85, wt * 0.82, 0.94, Color("d8a4ff"), _clock * 1.8)
		for b: Dictionary in game.passive_engine.active_beams:
			if str(b.get("domain", game.active_domain)) != game.active_domain:
				continue
			var bp := Vector2(b.get("pos", Vector2.ZERO))
			var br := float(b.get("radius", 65.0))
			var bt := 0.25 + fmod(maxf(0.0, _clock) * 2.2, 0.72)
			if has_v016_fx("orbital_beam"):
				_draw_sheet_frame(_pixel_layer, "orbital_beam", "orbital_beam", bp, br, bt, 0.96, Color.WHITE, 0.0)
		for ph: Dictionary in game.passive_engine.active_phantoms:
			if str(ph.get("domain", game.active_domain)) != game.active_domain:
				continue
			var php := Vector2(ph.get("pos", Vector2.ZERO))
			var phd := Vector2(ph.get("dir", Vector2.RIGHT)).normalized()
			var plife := clampf(float(ph.get("life", 0.0)) / maxf(0.05, float(ph.get("duration", 0.36))), 0.0, 1.0)
			var ph_r := float(ph.get("radius", 118.0))
			var evo_p: bool = game.passive_engine.is_evo("phantom_slash")
			var col_ph := Color("ffdf7a") if evo_p else Color("68e4ff")
			_pixel_layer.draw_set_transform(php, phd.angle())
			_pixel_layer.draw_arc(Vector2.ZERO, ph_r * 0.56, -0.95, 0.95, 18, Color(col_ph.r, col_ph.g, col_ph.b, plife * 0.92), 6.0 * plife + 1.5, false)
			_pixel_layer.draw_arc(Vector2(6, 0), ph_r * 0.44, -0.75, 0.75, 14, Color(1.0, 1.0, 1.0, plife * 0.85), 2.5 * plife + 0.5, false)
			_pixel_layer.draw_set_transform(Vector2.ZERO)


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
	if _glow_tex != null and game.passive_engine != null:
		for w: Dictionary in game.passive_engine.active_wells:
			if str(w.get("domain", game.active_domain)) != game.active_domain:
				continue
			var wp := Vector2(w.get("pos", Vector2.ZERO))
			var hr := float(w.get("radius", 120.0)) * 0.95
			_glow_layer.draw_texture_rect(_glow_tex, Rect2(wp - Vector2.ONE * hr, Vector2.ONE * hr * 2.0), false, Color(0.68, 0.34, 1.0, 0.36 * glow_mul))
		for b: Dictionary in game.passive_engine.active_beams:
			if str(b.get("domain", game.active_domain)) != game.active_domain:
				continue
			var bp := Vector2(b.get("pos", Vector2.ZERO))
			var br := float(b.get("radius", 65.0)) * 1.15
			_glow_layer.draw_texture_rect(_glow_tex, Rect2(bp - Vector2.ONE * br, Vector2.ONE * br * 2.0), false, Color(1.0, 0.86, 0.38, 0.46 * glow_mul))


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
	# 1. Ground Scorch Crater & Pixel Ember Fissures (zero flat rings)
	var crater_r := r * 0.56 * blast_scale
	for c_i in range(5):
		var ca := float(c_i) * (TAU / 5.0) + 0.28
		var off := Vector2(cos(ca) * crater_r * 0.32, sin(ca) * crater_r * 0.18).snapped(Vector2(2, 2))
		var cw := crater_r * (0.58 if c_i % 2 == 0 else 0.42)
		draw_rect(Rect2(point + off - Vector2(cw, cw * 0.52) * 0.5, Vector2(cw, cw * 0.52)), Color(0.11, 0.09, 0.08, 0.44 * fade))
		draw_rect(Rect2(point + off * 0.5 - Vector2(cw * 0.55, cw * 0.28) * 0.5, Vector2(cw * 0.55, cw * 0.28)), Color(0.06, 0.05, 0.05, 0.52 * fade))
	if p < 0.45:
		var ember_a := (1.0 - p / 0.45) * 0.90
		for e_i in range(6):
			var ea := float(e_i) * (TAU / 6.0) + 0.15
			var reach := crater_r * (0.45 + 0.65 * sqrt(p / 0.45))
			var p0 := point + Vector2(cos(ea) * 6.0, sin(ea) * 3.5)
			var p1 := point + Vector2(cos(ea) * reach, sin(ea) * reach * 0.56)
			draw_line(p0, p1, Color(1.0, 0.44 if is_burn else 0.64, 0.18, ember_a), 2.2, false)

	# 2. Brief 1-2 Frame Hot Core Flash + Expanding Fireball & Rolling Black Smoke
	if p < 0.12:
		var fl_a := (1.0 - p / 0.12)
		draw_circle(point + Vector2(0, -8), r * 0.38 * blast_scale * (0.7 + 0.4 * p / 0.12), Color(1.0, 0.92, 0.68, 0.84 * fl_a))
	if p < 0.72:
		var fp := p / 0.72
		var smoke_fade := clampf(1.0 - fp * fp, 0.0, 1.0)
		var smoke_spr: Texture2D = _smoke_puff_tex
		for k in range(6):
			var ka := float(k) * (TAU / 6.0) + 0.35
			var spread := r * blast_scale * (0.18 + 0.52 * sqrt(fp))
			var puff_pos := point + Vector2(cos(ka) * spread, sin(ka) * spread * 0.52 - fp * 22.0)
			var puff_sz := (32.0 + (k % 2) * 8.0) * (0.80 + 0.45 * fp)
			if smoke_spr != null:
				draw_set_transform(puff_pos, sin(float(k) * 1.1 + fp * 0.6) * 0.4)
				draw_texture_rect(smoke_spr, Rect2(-Vector2.ONE * puff_sz * 0.5, Vector2.ONE * puff_sz), false, Color(0.14, 0.11, 0.12, 0.68 * smoke_fade))
				draw_set_transform(Vector2.ZERO)
			if fp < 0.58:
				var fire_a := (1.0 - fp / 0.58)
				var f_pos := puff_pos.lerp(point + Vector2(0, -6), 0.42).snapped(Vector2(2, 2))
				var f_rad := puff_sz * 0.36
				draw_colored_polygon(PackedVector2Array([
					f_pos + Vector2(0, -f_rad * 1.25), f_pos + Vector2(f_rad * 0.78, 0), f_pos + Vector2(0, f_rad * 0.75), f_pos + Vector2(-f_rad * 0.78, 0)
				]), Color(1.0, (0.32 if is_burn else 0.48) + 0.22 * (k % 2), 0.12, 0.90 * fire_a))
				draw_rect(Rect2(f_pos - Vector2(f_rad * 0.3, f_rad * 0.3), Vector2(f_rad * 0.6, f_rad * 0.6)), Color(1.0, 0.94, 0.58, 0.96 * fire_a))

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
		var rad := float(item.radius)
		for k in range(5):
			var a := float(k) * (TAU / 5.0) + 0.35
			var reach := rad * (0.30 + 0.58 * sqrt(p))
			var dp := (pt + Vector2(cos(a) * reach, sin(a) * reach * 0.55 - p * 8.0)).snapped(Vector2(2, 2))
			var sz := 6.0 * (1.0 - 0.35 * p)
			draw_rect(Rect2(dp - Vector2(sz, sz * 0.6) * 0.5, Vector2(sz, sz * 0.6)), Color(0.84, 0.78, 0.64, 0.68 * fade))

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
	draw_set_transform(pt, 0.0, Vector2(1.0, 0.58))
	draw_arc(Vector2.ZERO, exp_r, 0.0, TAU, 40, Color(dark_c.r, dark_c.g, dark_c.b, 0.72 * fade), 5.0 if not is_inner else 4.0, false)
	draw_arc(Vector2.ZERO, exp_r, 0.0, TAU, 40, Color(mid_c.r, mid_c.g, mid_c.b, 0.90 * fade), 3.0 if not is_inner else 2.2, false)
	draw_arc(Vector2.ZERO, exp_r, 0.0, TAU, 40, Color(hi_c.r, hi_c.g, hi_c.b, 0.82 * fade), 1.2, false)
	var shards := 6 if reduced else (8 if is_inner else 10)
	for k in range(shards):
		var a := float(k) * (TAU / float(shards)) + (0.4 if is_fire else 0.0)
		var dist := exp_r * 0.86
		var sp := (Vector2.from_angle(a) * dist).snapped(Vector2(2, 2))
		var tang := Vector2.from_angle(a) * (6.5 * fade + 2.5)
		var perp := Vector2(-tang.y, tang.x) * 0.45
		draw_colored_polygon(PackedVector2Array([sp + tang, sp + perp, sp - tang * 0.6, sp - perp]), Color(dark_c.r, dark_c.g, dark_c.b, fade))
		draw_colored_polygon(PackedVector2Array([sp + tang * 0.8, sp + perp * 0.65, sp - tang * 0.4, sp - perp * 0.65]), Color(hi_c.r, hi_c.g, hi_c.b, fade))
	draw_set_transform(Vector2.ZERO)


func _draw_magic_impact_extra(point: Vector2, r: float, p: float, reduced: bool) -> void:
	var fade := clampf(1.0 - p * p, 0.0, 1.0)
	if fade <= 0.05:
		return
	var shard_len := maxf(2.4, (3.2 if reduced else 5.2) * fade)
	var count := 4 if reduced else 6
	for i in range(count):
		var a := float(i) * (TAU / float(count)) + p * 1.6
		var dist := r * (0.24 + 0.92 * sqrt(p))
		var sp := point + Vector2(cos(a) * dist, sin(a) * dist * 0.65 - p * 10.0)
		var tang := Vector2.from_angle(a) * shard_len
		var perp := Vector2(-tang.y, tang.x) * 0.58
		draw_colored_polygon(PackedVector2Array([sp + tang, sp + perp, sp - tang, sp - perp]), Color(0.86, 0.95, 1.0, 0.90 * fade))


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
		draw_line(start, end, Color(col.r, col.g, col.b, (0.45 if reduced else 0.78) * fade), 2.8 * fade + 0.6, false)
	if not reduced:
		for d_i in range(3):
			var dust := (point - n * (10.0 + float(d_i) * 8.0 * p) + perp * (float(d_i - 1) * 7.0)).snapped(Vector2(2, 2))
			draw_rect(Rect2(dust - Vector2(2, 2), Vector2(4, 3)), Color(col.r, col.g, col.b, 0.55 * fade))

func _draw_perfect_dodge(point: Vector2, dir: Vector2, r: float, p: float, col: Color, reduced: bool) -> void:
	var n := dir.normalized() if dir.length_squared() > 0.001 else Vector2.RIGHT
	var perp := Vector2(-n.y, n.x)
	var fade := clampf(1.0 - p, 0.0, 1.0)
	var gold := Color("ffe87a")
	for i in range(-2, 3):
		var spread := float(i) * 7.5
		var tail := point - n * (r * (0.4 + 0.95 * (1.0 - p))) + perp * spread
		var head := point + n * (r * 0.45) + perp * (spread * 0.55)
		var lc := gold if i == 0 else col
		draw_line(tail, head, Color(lc.r, lc.g, lc.b, (0.48 if reduced else 0.85) * fade), (3.4 if i == 0 else 2.2) * fade + 0.6, false)
	if not reduced and p < 0.55:
		var sp := (point - n * 12.0).snapped(Vector2(2, 2))
		var s_len := 18.0 * (1.0 - p / 0.55)
		draw_line(sp - Vector2(s_len, 0), sp + Vector2(s_len, 0), Color(gold, 0.95), 2.4, false)
		draw_line(sp - Vector2(0, s_len), sp + Vector2(0, s_len), Color(gold, 0.95), 2.4, false)
		draw_rect(Rect2(sp - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1, 0.95))

func _draw_enemy_telegraph(item: Dictionary, p: float, reduced: bool) -> void:
	var telegraph_tag := str(item.options.get("telegraph", ""))
	var pt_base := Vector2(item.point)
	var rad := maxf(12.0, float(item.radius))
	var urgent := clampf((p - 0.58) / 0.42, 0.0, 1.0)

	# 1. Thrown projectiles (skunk toxic flask, spore pod): parabolic shell + shrinking shadow already show trajectory cleanly.
	if item.options.has("origin"):
		var is_toxic := telegraph_tag == "toxic_bomb"
		var wisp_col := Color("5be86c") if is_toxic else Color("c876e8")
		var count := 3 if reduced else 5
		for k in range(count):
			var ka := float(k) * (TAU / float(count)) + (0.0 if reduced else _clock * 2.2)
			var wr := rad * (0.14 + 0.24 * (1.0 - p * 0.4))
			var wp := (pt_base + Vector2(cos(ka) * wr, sin(ka) * wr * 0.52 - p * 6.0 - float(k % 2) * 4.0)).snapped(Vector2(2, 2))
			draw_rect(Rect2(wp - Vector2(3, 2), Vector2(6, 4)), Color(wisp_col.r, wisp_col.g, wisp_col.b, 0.34 + 0.36 * p))
			draw_rect(Rect2(wp - Vector2(1.5, 1.5), Vector2(3, 3)), Color("d8ffbf" if is_toxic else "f4ccff", 0.55 * p))
		return

	# 2. Arcane / Void Rift ground telegraph: jagged converging pixel arcs + diamond core (no flat rings)
	if telegraph_tag in ["arcane_slam", "rift_collapse"]:
		var is_rift := telegraph_tag == "rift_collapse"
		var arc_c := Color(0.56, 0.92, 1.0) if is_rift else Color(0.76, 0.52, 1.0)
		var wisps := 5 if reduced else 8
		for k in range(wisps):
			var ang := float(k) * (TAU / float(wisps)) + 0.25
			var far_r := rad * lerpf(0.88, 0.22, p)
			var near_r := maxf(6.0, far_r - 22.0)
			var p0 := (pt_base + Vector2(cos(ang) * far_r, sin(ang) * far_r * 0.56)).snapped(Vector2(2, 2))
			var mid_a := ang + 0.14 * sin(float(k) * 2.3 + p * 6.0)
			var pm := (pt_base + Vector2(cos(mid_a) * (far_r + near_r) * 0.5, sin(mid_a) * (far_r + near_r) * 0.28)).snapped(Vector2(2, 2))
			var p1 := (pt_base + Vector2(cos(ang) * near_r, sin(ang) * near_r * 0.56)).snapped(Vector2(2, 2))
			draw_polyline(PackedVector2Array([p0, pm, p1]), Color(0.08, 0.05, 0.16, 0.65 + 0.25 * p), 3.2, false)
			draw_polyline(PackedVector2Array([p0, pm, p1]), Color(arc_c.r, arc_c.g, arc_c.b, 0.55 + 0.40 * p), 1.6, false)
		var core_s := (5.0 + 4.0 * urgent)
		draw_colored_polygon(PackedVector2Array([pt_base + Vector2(0, -core_s * 0.6), pt_base + Vector2(core_s, 0), pt_base + Vector2(0, core_s * 0.6), pt_base + Vector2(-core_s, 0)]), Color(1.0, 0.94, 0.72, 0.45 + 0.45 * p))
		return

	if telegraph_tag in ["storm_strike", "cyclone"]:
		var bolts := 4 if reduced else 6
		for k in range(bolts):
			var ang := float(k) * (TAU / float(bolts)) + _clock * 2.2
			var br := rad * (0.35 + 0.42 * p)
			var b0 := (pt_base + Vector2(cos(ang) * br, sin(ang) * br * 0.56)).snapped(Vector2(2, 2))
			var bm := (b0 + Vector2(sin(float(k) * 2.1 + _clock * 8.0) * 6.0, -14.0 - 12.0 * p)).snapped(Vector2(2, 2))
			var b1 := (pt_base + Vector2(cos(ang) * (br * 0.45), sin(ang) * (br * 0.25) - 24.0 * urgent)).snapped(Vector2(2, 2))
			draw_polyline(PackedVector2Array([b0, bm, b1]), Color("102436", 0.78), 3.6, false)
			draw_polyline(PackedVector2Array([b0, bm, b1]), Color("58ecff", 0.72 + 0.28 * urgent), 1.8, false)
			draw_rect(Rect2(b0 - Vector2(2, 2), Vector2(4, 4)), Color("e8ffff", 0.75 + 0.25 * p))
		return

	if telegraph_tag == "crystal_spikes":
		var shards := 4 if reduced else 6
		for k in range(shards):
			var ang := float(k) * (TAU / float(shards)) + 0.3
			var sr := rad * (0.25 + 0.38 * p)
			var base_p := (pt_base + Vector2(cos(ang) * sr, sin(ang) * sr * 0.54)).snapped(Vector2(2, 2))
			var h_sp := 6.0 + 18.0 * urgent
			var poly := PackedVector2Array([base_p + Vector2(-4, 0), base_p + Vector2(0, -h_sp), base_p + Vector2(4, 0), base_p + Vector2(0, 3)])
			draw_colored_polygon(poly, Color("201028", 0.85))
			draw_colored_polygon(PackedVector2Array([base_p + Vector2(-2, 0), base_p + Vector2(0, -h_sp * 0.78), base_p + Vector2(2, 0)]), Color("d65eff", 0.65 + 0.35 * urgent))
		return

	if telegraph_tag == "abyss_starfall":
		var pts_s := 5 if reduced else 7
		for k in range(pts_s):
			var ang := float(k) * (TAU / float(pts_s)) - _clock * 1.6
			var dist := rad * lerpf(0.75, 0.16, p)
			var sp := (pt_base + Vector2(cos(ang) * dist, sin(ang) * dist * 0.56)).snapped(Vector2(2, 2))
			draw_rect(Rect2(sp - Vector2(3, 3), Vector2(6, 6)), Color("1d0f2a", 0.82))
			draw_rect(Rect2(sp - Vector2(2, 2), Vector2(4, 4)), Color("cf74ff" if k % 2 == 0 else "ffe484", 0.72 + 0.28 * p))
		var drop_y := lerpf(-76.0, -4.0, p)
		var star_p := (pt_base + Vector2(0, drop_y)).snapped(Vector2(2, 2))
		draw_rect(Rect2(star_p - Vector2(5, 5), Vector2(10, 10)), Color("261238", 0.90))
		draw_rect(Rect2(star_p - Vector2(3, 3), Vector2(6, 6)), Color("f5b2ff", 0.95))
		draw_rect(Rect2(star_p - Vector2(1, 1), Vector2(2, 2)), Color("fffbe0", 0.98))
		return

	if telegraph_tag in ["seal_surge", "water_ambush", "chasm_ambush"]:
		var is_chasm := telegraph_tag == "chasm_ambush"
		var splash_c := Color("b668ff") if is_chasm else Color("5ee8ec")
		var rim_c := Color("201032") if is_chasm else Color("102a38")
		for k in range(5):
			var ka := float(k) * (TAU / 5.0) + _clock * 2.6
			var kr := rad * (0.28 + 0.28 * sin(p * PI))
			var kp := (pt_base + Vector2(cos(ka) * kr, sin(ka) * kr * 0.55 - 8.0 * urgent)).snapped(Vector2(2, 2))
			draw_rect(Rect2(kp - Vector2(3, 3), Vector2(6, 6)), Color(rim_c.r, rim_c.g, rim_c.b, 0.82))
			draw_rect(Rect2(kp - Vector2(2, 2), Vector2(4, 4)), Color(splash_c.r, splash_c.g, splash_c.b, 0.65 + 0.35 * p))
		return

	# 3. Heavy ground slams: tapered wedged earth fissures + dusty ground rumble + bouncing pebbles (zero circles)
	var fissure_count := 5 if reduced else 6
	var reach := rad * (0.28 + 0.40 * sqrt(p))
	var glow_c := Color("ff5c28") if telegraph_tag == "boss_slam" else Color("ff9234")
	var hot_c := Color("fff0a8")
	var smoke_spr: Texture2D = _smoke_puff_tex
	if smoke_spr != null:
		var d_sz := Vector2(rad * 0.85, rad * 0.46) * (0.6 + 0.35 * p)
		draw_texture_rect(smoke_spr, Rect2(pt_base - d_sz * 0.5, d_sz), false, Color(0.28, 0.20, 0.14, 0.36 + 0.22 * p))
	for k in range(fissure_count):
		var ba := float(k) * (TAU / float(fissure_count)) + 0.28 * float(k % 2)
		var seg_r := reach * (0.76 if k % 2 == 0 else 1.0)
		var dir_v := Vector2(cos(ba), sin(ba) * 0.56)
		var perp_v := Vector2(-dir_v.y, dir_v.x * 1.4).normalized()
		var p_mid := pt_base + Vector2(cos(ba + (0.20 if k % 2 == 0 else -0.22)) * seg_r * 0.48, sin(ba + (0.20 if k % 2 == 0 else -0.22)) * seg_r * 0.27)
		var p_tip := pt_base + dir_v * seg_r
		var wedge := PackedVector2Array([
			pt_base + perp_v * 3.8,
			p_mid + perp_v * 1.8,
			p_tip,
			p_mid - perp_v * 1.8,
			pt_base - perp_v * 3.8
		])
		draw_colored_polygon(wedge, Color(0.11, 0.07, 0.05, 0.88))
		if urgent > 0.05:
			var fc := glow_c.lerp(hot_c, urgent * 0.65)
			var inner_w := PackedVector2Array([
				pt_base + perp_v * 1.8,
				p_mid * 0.8 + pt_base * 0.2,
				pt_base - perp_v * 1.8
			])
			draw_colored_polygon(inner_w, Color(fc.r, fc.g, fc.b, 0.52 + 0.46 * urgent))
	if not reduced:
		for g_i in range(5):
			var ga := float(g_i) * 1.28 + 0.4
			var gd := reach * (0.45 + 0.25 * float(g_i % 2))
			var hop := absf(sin(p * PI * 3.0 + float(g_i))) * 7.0
			var gp := (pt_base + Vector2(cos(ga) * gd, sin(ga) * gd * 0.56 - hop)).snapped(Vector2(2, 2))
			draw_rect(Rect2(gp - Vector2(3, 2), Vector2(6, 4)), Color("261c16", 0.88))
			draw_rect(Rect2(gp - Vector2(2, 2), Vector2(4, 3)), Color("7a644e", 0.90))


func _draw_friendly_telegraph(item: Dictionary, p: float, colour: Color) -> void:
	var rad := maxf(6.0, float(item.radius))
	if game != null and game.tower_lab:
		if bool(item.options.get("cannon", false)) and item.options.has("core_radius"):
			draw_set_transform(item.point, 0.0, Vector2(1.0, 0.58))
			draw_arc(Vector2.ZERO, rad, 0.0, TAU, 46, Color(0.21, 0.13, 0.09, 0.48), 3.5, true)
			draw_arc(Vector2.ZERO, float(item.options.core_radius), 0.0, TAU, 36, Color(0.21, 0.13, 0.09, 0.65), 4.6, true)
			draw_arc(Vector2.ZERO, rad, 0.0, TAU, 46, Color(colour, 0.52), 1.5, true)
			draw_arc(Vector2.ZERO, float(item.options.core_radius), 0.0, TAU, 36, Color(colour, 0.45 + 0.35 * p), 2.5, true)
			draw_set_transform(Vector2.ZERO)
		elif not bool(item.options.get("cannon", false)):
			draw_set_transform(item.point, 0.0, Vector2(1.0, 0.58))
			draw_arc(Vector2.ZERO, rad, 0, TAU, 48, Color(colour, 0.48), 2.0, true)
			draw_arc(Vector2.ZERO, maxf(4.0, rad * (1.0 - p)), 0, TAU, 40, Color(colour, 0.38), 1.5, true)
			draw_set_transform(Vector2.ZERO)
		return
	if bool(item.options.get("cannon", false)):
		return
	var pt := Vector2(item.point)
	for k in range(4):
		var a := float(k) * (PI * 0.5) + _clock * 2.6
		var sr := maxf(6.0, rad * 0.45 * (1.0 - p * 0.72))
		var sp := (pt + Vector2(cos(a) * sr, sin(a) * sr * 0.58 - p * 12.0)).snapped(Vector2(2, 2))
		draw_rect(Rect2(sp - Vector2(2, 2), Vector2(4, 4)), Color("14111b", 0.7))
		draw_rect(Rect2(sp - Vector2(1, 1), Vector2(2, 2)), Color(colour.r, colour.g, colour.b, 0.88))


func _draw_floating_numbers() -> void:
	for item in game.numbers:
		var font_size := 24 if (game.feel != null and game.feel.enabled) else 13
		if bool(item.get("critical",false)): font_size+=6
		var size := ThemeDB.fallback_font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var origin: Vector2 = item.point - Vector2(size.x * 0.5, 0)
		var alpha := minf(1.0, float(item.life) * 4.0)
		draw_string_outline(ThemeDB.fallback_font, origin, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0.12, 0.08, 0.05, alpha))
		draw_string(ThemeDB.fallback_font, origin, item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(item.colour, alpha))
