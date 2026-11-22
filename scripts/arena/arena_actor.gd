class_name ArenaActor
extends AnimatedSprite2D

const STATES := ["idle","walk","attack","small","ultimate","hurt","down"]
const POSE_COUNT := 8
const CONTACT_FRAME := 4
const CONTACT_FRACTION := float(CONTACT_FRAME)/POSE_COUNT
const VIEWS := ["side","down","up"]
const CELL_SIZE := 224.0
const FOOT_OFFSET_Y := -84.0

var identity := "lord"
var active_form := "lord"
var view := "side"
var direction := Vector2.RIGHT
var visual_size := 84.0
var feedback := ArenaVisualFeedback.new()
static var frames_cache: Dictionary = {}

func configure(key: String, height := 84.0, improved := true) -> void:
	identity = key if ArenaHeroArt.HEIGHTS.has(key) else ArenaDefinitions.resolve_hero_id(key)
	active_form = identity
	visual_size = height
	feedback.enabled = improved
	feedback.disable_squash = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_form_frames(active_form)
	feedback.base_scale = Vector2.ONE * visual_size / 132.0
	offset = Vector2(0.0, FOOT_OFFSET_Y)
	show_state("idle", Vector2.RIGHT)

func set_form(form_key: String) -> void:
	if active_form == form_key:
		return
	active_form = form_key
	var prev_state := str(animation).trim_suffix("_" + view)
	if prev_state.is_empty() or prev_state not in STATES:
		prev_state = "idle"
	_apply_form_frames(active_form)
	feedback.base_scale = Vector2.ONE * ArenaHeroArt.height(active_form, feedback.enabled) / 132.0
	scale = feedback.base_scale
	show_state(prev_state, direction)

func _apply_form_frames(form_key: String) -> void:
	if not frames_cache.has(form_key):
		frames_cache[form_key] = _load_frames(form_key)
	sprite_frames = frames_cache[form_key]

static func _load_frames(key: String) -> SpriteFrames:
	var bank := SpriteFrames.new()
	bank.remove_animation("default")
	for current_view in VIEWS:
		var sheet := load(ArenaHeroArt.pose_atlas(key, current_view)) as Texture2D
		if sheet == null:
			continue
		var cell := Vector2(float(sheet.get_width()) / POSE_COUNT, float(sheet.get_height()) / STATES.size())
		for row in range(STATES.size()):
			var animation_id: String = STATES[row] + "_" + current_view
			bank.add_animation(animation_id)
			bank.set_animation_speed(animation_id, float(POSE_COUNT) / 0.6)
			bank.set_animation_loop(animation_id, row < 2)
			for column in range(POSE_COUNT):
				var pose := AtlasTexture.new()
				pose.atlas = sheet
				pose.region = Rect2(Vector2(column, row) * cell, cell)
				pose.filter_clip = true
				bank.add_frame(animation_id, pose)
	return bank

func show_state(state: String, facing: Vector2, duration := 0.6) -> void:
	if facing.length_squared() > 0.01:
		direction = facing.normalized()
	view = "side" if absf(direction.x) > absf(direction.y) * 0.8 else ("up" if direction.y < 0 else "down")
	var desired := state + "_" + view
	if sprite_frames == null or not sprite_frames.has_animation(desired):
		return
	flip_h = view == "side" and direction.x < 0
	scale = feedback.base_scale
	feedback.base_speed = 1.0 if state in ["idle", "walk"] else 0.6 / maxf(0.1, duration)
	speed_scale = feedback.base_speed
	if animation != desired:
		feedback.stop_left = 0.0
	if animation != desired or not is_playing():
		play(desired)

func _process(delta: float) -> void:
	feedback.tick(self, delta)
	var recoil := feedback.incoming * maxf(0.0, 1.0 - feedback.age / 0.13) * (2.0 if feedback.reduced else 6.0)
	position = recoil
	rotation = 0.0

func stride(speed: float) -> void:
	feedback.base_speed = ArenaMotion.stride_scale(speed, visual_size)
	speed_scale = feedback.base_speed

func emission_origin(_state: String = "") -> Vector2:
	var forward := direction * (24.0 if view == "side" else 14.0)
	return to_global(forward + Vector2(0.0, -visual_size * 0.50))

func has_complete_set() -> bool:
	if sprite_frames == null:
		return false
	for current_view in VIEWS:
		for state in STATES:
			if not sprite_frames.has_animation(state + "_" + current_view):
				return false
	return true
