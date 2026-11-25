class_name ArenaAtmosphere
extends Node2D

const SHADER_WATER := "res://scripts/shaders/ruins_abyss_water.gdshader"
const SHADER_RIBBON := "res://scripts/shaders/water_ribbon.gdshader"
const SHADER_TERRAIN := "res://scripts/shaders/terrain_frost_rim.gdshader"
const SHADER_FOLIAGE := "res://scripts/shaders/foliage_sway.gdshader"
const SHADER_POST := "res://scripts/shaders/battle_atmosphere.gdshader"
const EMIT_RUINS_PATH := "res://assets/v016/tiles_ruins_emit.png"

const MAP_SIZE := Vector2(1600.0, 900.0)
const RUINS_CORE_DEFAULT := Vector2(1120.0, 560.0)
const RUINS_BRIDGE_DEFAULT := Vector2(480.0, 800.0)
const RUINS_RIFT_DEFAULT := Vector2(1550.0, 330.0)
const RUINS_BRAZIERS := [
	Vector2(1028.0, 429.0),
	Vector2(1217.0, 430.0),
	Vector2(1030.0, 615.0),
	Vector2(1204.0, 616.0),
	Vector2(540.0, 20.0),
	Vector2(1688.0, 36.0),
	Vector2(373.0, 1002.0),
	Vector2(1634.0, 932.0)
]

var game: Node2D
var level_id: String = "forest"

var canvas_modulate: CanvasModulate
var post_layer: CanvasLayer
var post_rect: ColorRect
var post_material: ShaderMaterial

var water_material: ShaderMaterial
var cliff_material: ShaderMaterial
var ground_material: ShaderMaterial
var props_material: ShaderMaterial

var core_light: PointLight2D
var brazier_lights: Array[PointLight2D] = []
var ambient_lights: Array[PointLight2D] = []
var bridge_light: PointLight2D
var breach_light: PointLight2D

var particle_far: CPUParticles2D
var particle_near: CPUParticles2D

var _radial_tex: GradientTexture2D
var _particle_tex: ImageTexture
var _ember_tex: ImageTexture
var _emit_ruins_tex: Texture2D

var _tilemap_bound: bool = false
var _time: float = 0.0
var _last_sync_frame: int = -1
var _last_reduced: bool = false

var _rift_active: bool = false
var _rift_point: Vector2 = RUINS_RIFT_DEFAULT
var _bridge_sealed: bool = false
var _bridge_point: Vector2 = RUINS_BRIDGE_DEFAULT

var _storm_boost: float = 0.0
var _breach_boost: float = 0.0
var _gust_boost: float = 0.0
var _flash_amount: float = 0.0
var _focal_pulse: float = 0.0
var _breach_flare: float = 0.0


static func install(target_game: Node2D) -> ArenaAtmosphere:
	if target_game == null or not is_instance_valid(target_game):
		return null
	var existing: Variant = target_game.get_node_or_null("ArenaAtmosphere")
	if existing == null:
		for child in target_game.get_children():
			if child is Node2D and child.has_method("sync_battle") and child.has_method("trigger_rift_breach"):
				existing = child
				break
	if existing != null and is_instance_valid(existing) and existing.has_method("setup"):
		existing.setup(target_game)
		return existing
	var atmosphere: Variant = new()
	atmosphere.name = "ArenaAtmosphere"
	target_game.add_child(atmosphere)
	atmosphere.setup(target_game)
	return atmosphere


func setup(target_game: Node2D) -> void:
	game = target_game
	_reset_state()
	if game == null or not is_instance_valid(game):
		return

	level_id = str(game.get("level_id")) if game.get("level_id") != null else "forest"
	var reduced := _is_reduced_motion()
	_last_reduced = reduced

	_ensure_textures()
	_install_post_process(reduced)

	if level_id in ["ruins","sanctum"]:
		_setup_ruins(reduced)
	else:
		_setup_woodland(level_id, reduced)


func sync_battle(delta: float) -> void:
	_last_sync_frame = Engine.get_process_frames()
	if game == null or not is_instance_valid(game):
		return

	var reduced := _is_reduced_motion()
	if reduced != _last_reduced:
		_last_reduced = reduced
		_apply_reduced_motion(reduced)

	var dt := maxf(0.0, delta)
	_time += dt * (0.25 if reduced else 1.0)
	_storm_boost = maxf(0.0, _storm_boost - dt * 0.25)
	_breach_boost = maxf(0.0, _breach_boost - dt * 0.55)
	_gust_boost = maxf(0.0, _gust_boost - dt * 0.35)
	_flash_amount = maxf(0.0, _flash_amount - dt * 2.8)
	_focal_pulse = maxf(0.0, _focal_pulse - dt * 1.45)
	_breach_flare = maxf(0.0, _breach_flare - dt * 1.15)

	if level_id in ["ruins","sanctum"]:
		_sync_ruins(reduced)
	else:
		_sync_woodland(reduced)

	_sync_post_process(reduced)


func trigger_rift_breach(point: Vector2) -> void:
	_rift_active = true
	_rift_point = point
	_storm_boost = 1.0
	_breach_boost = 1.0
	_gust_boost = 1.0
	_breach_flare = 1.0

	var reduced := _is_reduced_motion()
	if not reduced:
		_flash_amount = 0.72
		_focal_pulse = 1.0
		if post_material != null:
			post_material.set_shader_parameter("focal_uv", _world_to_uv(point))
			post_material.set_shader_parameter("breach_uv", _world_to_uv(point))

	if is_instance_valid(breach_light):
		breach_light.position = point
		breach_light.enabled = true
		breach_light.energy = 0.75 if reduced else 1.35

	_sync_particle_intensity(reduced)


func set_bridge_sealed(point: Vector2, sealed: bool) -> void:
	_bridge_sealed = sealed
	_bridge_point = point
	var reduced := _is_reduced_motion()

	if sealed:
		_breach_boost = maxf(_breach_boost, 0.55)
		if not reduced:
			_focal_pulse = maxf(_focal_pulse, 0.75)
			if post_material != null:
				post_material.set_shader_parameter("focal_uv", _world_to_uv(point))

	if is_instance_valid(bridge_light):
		bridge_light.position = point
		bridge_light.enabled = true
		if sealed:
			bridge_light.color = Color(0.46, 0.88, 1.0)
			bridge_light.energy = 0.82
			bridge_light.texture_scale = 1.55
		else:
			bridge_light.color = Color(0.86, 0.70, 0.42)
			bridge_light.energy = 0.24
			bridge_light.texture_scale = 1.05


func _process(delta: float) -> void:
	if Engine.get_process_frames() != _last_sync_frame:
		sync_battle(delta)


func _reset_state() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	canvas_modulate = null
	post_layer = null
	post_rect = null
	post_material = null
	water_material = null
	cliff_material = null
	ground_material = null
	props_material = null
	core_light = null
	brazier_lights.clear()
	ambient_lights.clear()
	bridge_light = null
	breach_light = null
	particle_far = null
	particle_near = null
	_tilemap_bound = false
	_time = 0.0
	_rift_active = false
	_rift_point = RUINS_RIFT_DEFAULT
	_bridge_sealed = false
	_bridge_point = RUINS_BRIDGE_DEFAULT
	_storm_boost = 0.0
	_breach_boost = 0.0
	_gust_boost = 0.0
	_flash_amount = 0.0
	_focal_pulse = 0.0
	_breach_flare = 0.0


func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


func _is_reduced_motion() -> bool:
	if game == null or not is_instance_valid(game):
		return false
	var camp: Variant = game.get("campaign")
	if camp == null:
		return false
	var d: Variant = camp.get("data")
	if typeof(d) == TYPE_DICTIONARY:
		return bool(d.get("reduced_motion", false))
	return false


func _level_def() -> Dictionary:
	if game == null or not is_instance_valid(game):
		return {}
	var def: Variant = game.get("level_definition")
	return def if typeof(def) == TYPE_DICTIONARY else {}


func _world_to_uv(point: Vector2) -> Vector2:
	return Vector2(clampf(point.x / MAP_SIZE.x, 0.0, 1.0), clampf(point.y / MAP_SIZE.y, 0.0, 1.0))


func _ensure_textures() -> void:
	if _radial_tex == null:
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.35, 0.70, 1.0])
		grad.colors = PackedColorArray([
			Color(1.0, 1.0, 1.0, 1.0),
			Color(0.84, 0.84, 0.84, 0.62),
			Color(0.32, 0.32, 0.32, 0.20),
			Color(0.0, 0.0, 0.0, 0.0)
		])
		var radial := GradientTexture2D.new()
		radial.width = 256
		radial.height = 256
		radial.fill = GradientTexture2D.FILL_RADIAL
		radial.fill_from = Vector2(0.5, 0.5)
		radial.fill_to = Vector2(1.0, 0.5)
		radial.gradient = grad
		_radial_tex = radial

	if _particle_tex == null:
		var img := Image.create(6, 6, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.0, 0.0, 0.0, 0.0))
		for y in range(6):
			for x in range(6):
				var dx := absf(float(x) - 2.5)
				var dy := absf(float(y) - 2.5)
				var d := dx + dy
				if d <= 1.1:
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
				elif d <= 2.2:
					img.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.48))
		_particle_tex = ImageTexture.create_from_image(img)

	if _ember_tex == null:
		var img2 := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img2.fill(Color(0.0, 0.0, 0.0, 0.0))
		for y in range(1, 3):
			for x in range(1, 3):
				img2.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))
		img2.set_pixel(0, 1, Color(1.0, 1.0, 1.0, 0.35))
		img2.set_pixel(3, 2, Color(1.0, 1.0, 1.0, 0.35))
		_ember_tex = ImageTexture.create_from_image(img2)

	if _emit_ruins_tex == null and ResourceLoader.exists(EMIT_RUINS_PATH):
		_emit_ruins_tex = load(EMIT_RUINS_PATH) as Texture2D


func _make_shader_material(path: String) -> ShaderMaterial:
	if not ResourceLoader.exists(path):
		return null
	var shader := load(path) as Shader
	if shader == null:
		return null
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _make_point_light(pos: Vector2, tint: Color, energy_val: float, scale_val: float, label: String) -> PointLight2D:
	var light := PointLight2D.new()
	light.name = label
	light.position = pos
	light.color = tint
	light.energy = energy_val
	light.texture = _radial_tex
	light.texture_scale = scale_val
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.shadow_enabled = false
	light.range_layer_min = 0
	light.range_layer_max = 0
	light.range_z_min = -100
	light.range_z_max = 100
	add_child(light)
	return light


func _install_post_process(reduced: bool) -> void:
	post_layer = CanvasLayer.new()
	post_layer.name = "AtmosphereOverlayLayer"
	post_layer.layer = 0
	add_child(post_layer)

	post_rect = ColorRect.new()
	post_rect.name = "AtmospherePostRect"
	post_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_rect.color = Color.WHITE
	post_layer.add_child(post_rect)

	post_material = _make_shader_material(SHADER_POST)
	if post_material != null:
		post_rect.material = post_material
		_configure_post_defaults(reduced)
	else:
		# Fallback ultra-light flat tint if shader file is absent.
		post_rect.color = Color(0.04, 0.06, 0.14, 0.04 if level_id == "ruins" else 0.0)


func _configure_post_defaults(reduced: bool) -> void:
	if post_material == null:
		return
	if level_id in ["ruins","sanctum"]:
		post_material.set_shader_parameter("vignette_strength", 0.11)
		post_material.set_shader_parameter("vignette_color", Color(0.04, 0.06, 0.16, 1.0))
		post_material.set_shader_parameter("moon_glow_strength", 0.05)
		post_material.set_shader_parameter("moon_glow_color", Color(0.58, 0.78, 1.0, 1.0))
		post_material.set_shader_parameter("breach_intensity", 0.0)
	else:
		post_material.set_shader_parameter("vignette_strength", 0.085)
		post_material.set_shader_parameter("vignette_color", Color(0.06, 0.10, 0.05, 1.0))
		post_material.set_shader_parameter("moon_glow_strength", 0.038)
		post_material.set_shader_parameter("moon_glow_color", Color(1.0, 0.93, 0.74, 1.0))
		post_material.set_shader_parameter("breach_intensity", 0.0)
	post_material.set_shader_parameter("flash_amount", 0.0)
	post_material.set_shader_parameter("focal_pulse", 0.0 if reduced else 0.0)


func _setup_ruins(reduced: bool) -> void:
	var def := _level_def()
	var core_pos: Vector2 = Vector2(def.get("core", RUINS_CORE_DEFAULT))

	# Cool moonlit ambient tone keeping courtyard stonework distinct from abyss while projectiles/HP stay crisp.
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.name = "MoonCanvasModulate"
	canvas_modulate.color = Color(0.98, 0.98, 1.0, 1.0)
	add_child(canvas_modulate)

	# Central Starfall Sanctum core light.
	core_light = _make_point_light(core_pos, Color(0.56, 0.85, 1.0), 0.16, 2.25, "CorePointLight")

	# Subtle cool moonlit ambient fill on West/East walkable courtyards so wings don't crush to abyss black.
	ambient_lights.append(_make_point_light(Vector2(265.0, 480.0), Color(0.62, 0.76, 1.0), 0.18, 2.25, "MoonCourtyardWest"))
	ambient_lights.append(_make_point_light(Vector2(1320.0, 480.0), Color(0.62, 0.76, 1.0), 0.18, 2.25, "MoonCourtyardEast"))

	# Four corner fortress war braziers (read from level_definition.braziers if provided).
	var brazier_pts: Array = def.get("braziers", RUINS_BRAZIERS)
	for i in range(brazier_pts.size()):
		var b_light := _make_point_light(Vector2(brazier_pts[i]), Color(1.0, 0.58, 0.24), 0.52, 1.45, "BrazierPointLight_%d" % i)
		brazier_lights.append(b_light)

	# Bridge gate rune lantern & NE rift breach light.
	var bridge_cfg: Variant = def.get("bridge_gate", {})
	var bridge_pt: Vector2 = Vector2(bridge_cfg.get("point", RUINS_BRIDGE_DEFAULT)) if typeof(bridge_cfg) == TYPE_DICTIONARY else RUINS_BRIDGE_DEFAULT
	_bridge_point = bridge_pt
	bridge_light = _make_point_light(bridge_pt, Color(0.86, 0.70, 0.42), 0.24, 1.05, "BridgePointLight")

	breach_light = _make_point_light(RUINS_RIFT_DEFAULT, Color(0.68, 0.44, 1.0), 0.0, 1.85, "RiftBreachLight")
	breach_light.enabled = false

	_try_bind_ruins_tilemap()
	_spawn_water_ribbons([Rect2(442.0, 635.0, 76.0, 315.0)], Color(0.42, 0.82, 0.98, 0.30))
	_setup_ruins_particles(reduced)


func _setup_woodland(stage_id: String, reduced: bool) -> void:
	# Preserve original bright woodland/creek palette; add gentle canopy/water dappled glow.
	var is_creek := stage_id == "creek"
	var canopy_pts := [
		Vector2(340.0, 260.0),
		Vector2(860.0, 420.0),
		Vector2(1320.0, 560.0)
	]
	for i in range(canopy_pts.size()):
		var tint := Color(0.82, 0.95, 1.0) if (is_creek and i == 1) else Color(1.0, 0.94, 0.76)
		var l := _make_point_light(canopy_pts[i], tint, 0.16, 2.35, "WoodlandLight_%d" % i)
		ambient_lights.append(l)
	if is_creek:
		var def := _level_def()
		var wrects: Array = def.get("water_rects", [])
		_spawn_water_ribbons(wrects, Color(0.45, 0.86, 1.0, 0.34))

	_setup_woodland_particles(is_creek, reduced)


func _spawn_water_ribbons(rects: Array, tint: Color) -> void:
	var rmat := _make_shader_material(SHADER_RIBBON)
	if rmat == null:
		return
	rmat.set_shader_parameter("water_tint", tint)
	for i in range(rects.size()):
		var r: Rect2 = Rect2(rects[i])
		var ribbon := ColorRect.new()
		ribbon.name = "WaterRibbon_%d" % i
		ribbon.position = r.position - Vector2(8.0, 4.0)
		ribbon.size = r.size + Vector2(16.0, 8.0)
		ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ribbon.z_index = -18
		ribbon.material = rmat
		add_child(ribbon)


func _make_fade_ramp(base_color: Color, peak_alpha: float) -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.80, 1.0])
	ramp.colors = PackedColorArray([
		Color(base_color.r, base_color.g, base_color.b, 0.0),
		Color(base_color.r, base_color.g, base_color.b, peak_alpha),
		Color(base_color.r, base_color.g, base_color.b, peak_alpha * 0.85),
		Color(base_color.r, base_color.g, base_color.b, 0.0)
	])
	return ramp


func _setup_ruins_particles(reduced: bool) -> void:
	# Layer 1: Deep cold mist & star-ash drift behind towers/actors.
	particle_far = CPUParticles2D.new()
	particle_far.name = "BlizzardAshFar"
	particle_far.z_index = -12
	particle_far.position = MAP_SIZE * 0.5
	particle_far.texture = _particle_tex
	particle_far.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle_far.amount = 14 if reduced else 44
	particle_far.lifetime = 6.5
	particle_far.preprocess = 3.0
	particle_far.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particle_far.emission_rect_extents = Vector2(860.0, 480.0)
	particle_far.direction = Vector2(-0.85, 0.48).normalized()
	particle_far.spread = 18.0
	particle_far.gravity = Vector2(-10.0, 8.0)
	particle_far.initial_velocity_min = 18.0 if reduced else 48.0
	particle_far.initial_velocity_max = 32.0 if reduced else 82.0
	particle_far.scale_amount_min = 0.55
	particle_far.scale_amount_max = 1.05
	particle_far.color_ramp = _make_fade_ramp(Color(0.72, 0.82, 0.98), 0.36)
	add_child(particle_far)

	# Layer 2: Foreground crisp snow-ash & tiny astral embers above actors, below HUD.
	particle_near = CPUParticles2D.new()
	particle_near.name = "BlizzardAshNear"
	particle_near.z_index = 25
	particle_near.position = MAP_SIZE * 0.5
	particle_near.texture = _ember_tex
	particle_near.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle_near.amount = 10 if reduced else 34
	particle_near.lifetime = 4.8
	particle_near.preprocess = 2.5
	particle_near.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particle_near.emission_rect_extents = Vector2(860.0, 480.0)
	particle_near.direction = Vector2(-0.92, 0.40).normalized()
	particle_near.spread = 14.0
	particle_near.gravity = Vector2(-18.0, 12.0)
	particle_near.initial_velocity_min = 28.0 if reduced else 96.0
	particle_near.initial_velocity_max = 46.0 if reduced else 165.0
	particle_near.scale_amount_min = 0.65
	particle_near.scale_amount_max = 1.25
	particle_near.color_ramp = _make_fade_ramp(Color(0.88, 0.94, 1.0), 0.52)
	add_child(particle_near)


func _setup_woodland_particles(is_creek: bool, reduced: bool) -> void:
	# Layer 1: Gentle sun-dappled drifting woodland spores.
	particle_far = CPUParticles2D.new()
	particle_far.name = "WoodlandSpores"
	particle_far.z_index = -12
	particle_far.position = MAP_SIZE * 0.5
	particle_far.texture = _particle_tex
	particle_far.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle_far.amount = 10 if reduced else 28
	particle_far.lifetime = 8.0
	particle_far.preprocess = 3.5
	particle_far.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particle_far.emission_rect_extents = Vector2(820.0, 440.0)
	particle_far.direction = Vector2(0.80, -0.45).normalized()
	particle_far.spread = 45.0
	particle_far.gravity = Vector2(4.0, -3.0)
	particle_far.initial_velocity_min = 8.0 if reduced else 14.0
	particle_far.initial_velocity_max = 15.0 if reduced else 28.0
	particle_far.scale_amount_min = 0.50
	particle_far.scale_amount_max = 0.90
	particle_far.color_ramp = _make_fade_ramp(Color(0.86, 0.96, 0.68) if not is_creek else Color(0.76, 0.95, 0.92), 0.34)
	add_child(particle_far)

	# Layer 2: Soft breeze fireflies / mist motes.
	particle_near = CPUParticles2D.new()
	particle_near.name = "WoodlandFireflies"
	particle_near.z_index = 25
	particle_near.position = MAP_SIZE * 0.5
	particle_near.texture = _ember_tex
	particle_near.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle_near.amount = 8 if reduced else 20
	particle_near.lifetime = 6.0
	particle_near.preprocess = 2.5
	particle_near.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particle_near.emission_rect_extents = Vector2(780.0, 410.0)
	particle_near.direction = Vector2(0.5, -0.85).normalized()
	particle_near.spread = 65.0
	particle_near.gravity = Vector2(2.0, -4.0)
	particle_near.initial_velocity_min = 6.0 if reduced else 12.0
	particle_near.initial_velocity_max = 14.0 if reduced else 26.0
	particle_near.scale_amount_min = 0.65
	particle_near.scale_amount_max = 1.15
	particle_near.color_ramp = _make_fade_ramp(Color(1.0, 0.90, 0.50) if not is_creek else Color(0.74, 0.96, 0.88), 0.52)
	add_child(particle_near)


func _find_layer_recursive(root_node: Node, layer_name: String) -> CanvasItem:
	if root_node == null or not is_instance_valid(root_node):
		return null
	if root_node.name == layer_name and root_node is CanvasItem:
		return root_node as CanvasItem
	for child in root_node.get_children():
		var found := _find_layer_recursive(child, layer_name)
		if found != null:
			return found
	return null


func _try_bind_ruins_tilemap() -> void:
	if game == null or not is_instance_valid(game):
		return
	var search_root: Node = game.get("terrain") as Node
	if search_root == null or not is_instance_valid(search_root):
		search_root = game

	var water_layer := _find_layer_recursive(search_root, "AbyssWaterLayer")
	var cliff_layer := _find_layer_recursive(search_root, "CliffWallLayer")
	var ground_layer := _find_layer_recursive(search_root, "FortressGroundLayer")
	var props_layer := _find_layer_recursive(search_root, "PropsDetailLayer")

	if water_layer == null and cliff_layer == null and ground_layer == null and props_layer == null:
		return

	var def := _level_def()
	var core_pos: Vector2 = Vector2(def.get("core", RUINS_CORE_DEFAULT))
	var motion := 0.0 if _is_reduced_motion() else 1.0
	_ensure_textures()

	if water_layer != null:
		water_material = _make_shader_material(SHADER_WATER)
		if water_material != null:
			water_material.set_shader_parameter("motion_scale", motion)
			water_material.set_shader_parameter("tile_size_px", 32.0)
			water_layer.material = water_material

	if cliff_layer != null:
		cliff_material = _make_shader_material(SHADER_TERRAIN)
		if cliff_material != null:
			if _emit_ruins_tex != null:
				cliff_material.set_shader_parameter("emit_tex", _emit_ruins_tex)
			cliff_material.set_shader_parameter("emit_strength", 0.85)
			cliff_material.set_shader_parameter("frost_intensity", 0.14)
			cliff_material.set_shader_parameter("motion_scale", motion)
			cliff_material.set_shader_parameter("sanctum_pos", core_pos)
			cliff_material.set_shader_parameter("tile_size_px", 32.0)
			cliff_layer.material = cliff_material

	if ground_layer != null:
		ground_material = _make_shader_material(SHADER_TERRAIN)
		if ground_material != null:
			if _emit_ruins_tex != null:
				ground_material.set_shader_parameter("emit_tex", _emit_ruins_tex)
			ground_material.set_shader_parameter("emit_strength", 1.30)
			ground_material.set_shader_parameter("frost_intensity", 0.16)
			ground_material.set_shader_parameter("motion_scale", motion)
			ground_material.set_shader_parameter("sanctum_pos", core_pos)
			ground_material.set_shader_parameter("tile_size_px", 32.0)
			ground_layer.material = ground_material

	if props_layer != null:
		props_material = _make_shader_material(SHADER_FOLIAGE)
		if props_material != null:
			if _emit_ruins_tex != null:
				props_material.set_shader_parameter("emit_tex", _emit_ruins_tex)
			props_material.set_shader_parameter("tile_size_px", 32.0)
			props_material.set_shader_parameter("sway_strength", 1.8)
			props_material.set_shader_parameter("emit_strength", 1.25)
			props_material.set_shader_parameter("motion_scale", motion)
			props_layer.material = props_material

	_tilemap_bound = true


func _sync_ruins(reduced: bool) -> void:
	if not _tilemap_bound:
		_try_bind_ruins_tilemap()

	var cyc: int = int(game.get("cycle")) if game.get("cycle") != null else 1
	var phase_str: String = str(game.get("phase")) if game.get("phase") != null else "rest"
	if bool(game.get("breach_open")) and phase_str == "spawn" and not _rift_active:
		trigger_rift_breach(RUINS_RIFT_DEFAULT)

	var motion := 0.0 if reduced else 1.0
	if water_material != null:
		water_material.set_shader_parameter("motion_scale", motion)
		water_material.set_shader_parameter("storm_boost", _storm_boost)
	if cliff_material != null:
		cliff_material.set_shader_parameter("motion_scale", motion)
		cliff_material.set_shader_parameter("breach_boost", _breach_boost)
	if ground_material != null:
		ground_material.set_shader_parameter("motion_scale", motion)
		ground_material.set_shader_parameter("breach_boost", _breach_boost)
	if props_material != null:
		props_material.set_shader_parameter("motion_scale", motion)
		props_material.set_shader_parameter("gust_boost", _gust_boost)

	if is_instance_valid(core_light):
		var core_pulse := 1.0 if reduced else (1.0 + 0.08 * sin(_time * 2.4))
		core_light.energy = 0.10 * core_pulse

	# Flicker corner war braziers gently when motion is enabled.
	for i in range(brazier_lights.size()):
		var b_light := brazier_lights[i]
		if not is_instance_valid(b_light):
			continue
		if reduced:
			b_light.energy = 0.10
		else:
			var f1 := sin(_time * 7.3 + float(i) * 2.1)
			var f2 := sin(_time * 13.1 + float(i) * 4.7)
			b_light.energy = 0.09 + 0.02 * f1 + 0.01 * f2

	if is_instance_valid(bridge_light) and _bridge_sealed:
		bridge_light.energy = 0.12 if reduced else (0.11 + 0.02 * sin(_time * 4.5))

	if is_instance_valid(breach_light) and _rift_active:
		var base_e := 0.08 + _breach_flare * 0.12
		breach_light.energy = base_e if reduced else (base_e + 0.10 * sin(_time * 5.4))

	_sync_particle_intensity(reduced)


func _sync_woodland(reduced: bool) -> void:
	for i in range(ambient_lights.size()):
		var l := ambient_lights[i]
		if not is_instance_valid(l):
			continue
		l.energy = 0.16 if reduced else (0.15 + 0.03 * sin(_time * 1.1 + float(i) * 1.7))


func _sync_particle_intensity(reduced: bool) -> void:
	if level_id == "ruins":
		var boost := 1.0 if reduced else (1.0 + _storm_boost * 1.1)
		if is_instance_valid(particle_far):
			particle_far.speed_scale = boost
		if is_instance_valid(particle_near):
			particle_near.speed_scale = boost


func _apply_reduced_motion(reduced: bool) -> void:
	if level_id == "ruins":
		if is_instance_valid(particle_far):
			particle_far.amount = 14 if reduced else 44
			particle_far.initial_velocity_min = 18.0 if reduced else 48.0
			particle_far.initial_velocity_max = 32.0 if reduced else 82.0
		if is_instance_valid(particle_near):
			particle_near.amount = 10 if reduced else 34
			particle_near.initial_velocity_min = 28.0 if reduced else 96.0
			particle_near.initial_velocity_max = 46.0 if reduced else 165.0
	else:
		if is_instance_valid(particle_far):
			particle_far.amount = 10 if reduced else 28
		if is_instance_valid(particle_near):
			particle_near.amount = 8 if reduced else 20


func _sync_post_process(reduced: bool) -> void:
	if post_material == null:
		return
	var rift_edge := 0.35 if (_rift_active and level_id == "ruins") else 0.0
	post_material.set_shader_parameter("breach_intensity", clampf(rift_edge + _breach_boost * 0.45, 0.0, 1.0))
	post_material.set_shader_parameter("flash_amount", 0.0 if reduced else _flash_amount)
	post_material.set_shader_parameter("focal_pulse", 0.0 if reduced else _focal_pulse)
