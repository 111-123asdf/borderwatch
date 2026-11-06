class_name ArenaActor
extends AnimatedSprite2D
const STATES := ["idle","walk","attack","small","ultimate","hurt","down"]
var identity: String="knight"
var view: String="side"
var direction:=Vector2.RIGHT
var visual_size:=80.0
static var frames_cache: Dictionary={}
func configure(key: String, height := 80.0) -> void:
	identity=key;visual_size=height
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	if not frames_cache.has(key):
		var bank:=SpriteFrames.new();bank.remove_animation("default")
		for facing in ["side","down","up"]:
			var path: String="res://assets/v06/"+key+"_"+facing+".png"
			if not ResourceLoader.exists(path): continue
			var sheet: Texture2D=load(path)
			for row in range(STATES.size()):
				var animation_id: String=STATES[row]+"_"+facing
				bank.add_animation(animation_id);bank.set_animation_speed(animation_id,10.0);bank.set_animation_loop(animation_id,row<2)
				for column in range(6):
					var frame_texture:=AtlasTexture.new();frame_texture.atlas=sheet
					frame_texture.region=Rect2(column*sheet.get_width()/6.0,row*sheet.get_height()/7.0,sheet.get_width()/6.0,sheet.get_height()/7.0)
					bank.add_frame(animation_id,frame_texture,ArenaMotion.holds(key,STATES[row])[column])
		frames_cache[key]=bank
	sprite_frames=frames_cache[key]
	show_state("idle",Vector2.RIGHT)
func show_state(state: String, facing: Vector2, duration := 0.6) -> void:
	if facing.length_squared()>0.01: direction=facing.normalized()
	view="side" if absf(direction.x)>absf(direction.y)*0.8 else ("up" if direction.y<0 else "down")
	var desired: String=state+"_"+view
	if not sprite_frames.has_animation(desired): desired=state+"_side"
	if not sprite_frames.has_animation(desired): return
	flip_h=view=="side" and direction.x<0
	var image: Texture2D=sprite_frames.get_frame_texture(desired,0)
	scale=Vector2.ONE*visual_size/(image.get_height()*0.78);offset=Vector2(0,-image.get_height()*ArenaArtAnchors.offset_for(identity+"_"+view))
	speed_scale=1.0 if state in ["idle","walk"] else 0.6/maxf(0.1,duration)
	if animation!=desired or not is_playing(): play(desired)
func has_complete_set() -> bool:
	for facing in ["side","down","up"]:
		for state in STATES:
			if not sprite_frames.has_animation(state+"_"+facing): return false
	return true
