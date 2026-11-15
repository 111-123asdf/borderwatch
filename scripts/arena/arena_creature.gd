class_name ArenaCreature
extends AnimatedSprite2D
var identity: String="fox"
var direction:=Vector2.RIGHT
var base_height:=50.0
var feedback:=ArenaVisualFeedback.new()
static var frame_cache: Dictionary={}
func configure(key: String, height := 50.0) -> void:
	identity=key;base_height=height;texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	if not frame_cache.has(key):
		var bank:=SpriteFrames.new();bank.remove_animation("default")
		var path: String="res://assets/v06/creature_"+key+".png"
		if ResourceLoader.exists(path):
			var sheet: Texture2D=load(path)
			for row in range(3):
				var label: String=["walk","attack","down"][row]
				bank.add_animation(label);bank.set_animation_speed(label,9.0);bank.set_animation_loop(label,label=="walk")
				for col in range(6):
					var image:=AtlasTexture.new();image.atlas=sheet;image.region=Rect2(col*sheet.get_width()/6.0,row*sheet.get_height()/3.0,sheet.get_width()/6.0,sheet.get_height()/3.0)
					bank.add_frame(label,image)
		frame_cache[key]=bank
	sprite_frames=frame_cache[key];show_pose("walk",Vector2.RIGHT)
func show_pose(state: String, facing: Vector2) -> void:
	if facing.length()>0.01:direction=facing
	flip_h=direction.x<0
	if not sprite_frames.has_animation(state):return
	var image: Texture2D=sprite_frames.get_frame_texture(state,0)
	feedback.base_scale=Vector2.ONE*base_height/(image.get_height()*0.78);scale=feedback.base_scale;offset=Vector2(0,-image.get_height()*ArenaArtAnchors.offset_for("creature_"+identity))
	feedback.base_speed=1.0;speed_scale=feedback.base_speed
	if animation!=state:feedback.stop_left=0.0
	if animation!=state or (state=="walk" and not is_playing()):play(state)
func match_stride(speed: float) -> void:
	if identity in ["wisp","moth"]:return
	feedback.base_speed=clampf(speed*6.0/(base_height*0.85*9.0),0.45,1.8);speed_scale=feedback.base_speed
func _process(delta: float) -> void:
	var owner_node:=get_parent()
	if owner_node is ArenaEnemy and owner_node.stun>0:feedback.base_speed=0.0
	feedback.tick(self,delta)
