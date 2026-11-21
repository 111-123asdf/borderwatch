class_name ArenaActor
extends AnimatedSprite2D
const STATES := ["idle","walk","attack","small","ultimate","hurt","down"]
var identity: String="knight"
var view: String="side"
var direction:=Vector2.RIGHT
var visual_size:=80.0
var polished:=true
var feedback:=ArenaVisualFeedback.new()
var pose_data: Dictionary={}
var base_offset:=Vector2(0,-224)
var breathe_phase:=0.0
static var frames_cache: Dictionary={}
static var authored: Dictionary={}
func configure(key: String, height := 80.0, improved:=true) -> void:
	identity=key;visual_size=height;polished=improved;feedback.enabled=improved
	pose_data=ArenaHeroArt.metadata(key) if improved else {}
	if authored.is_empty():authored=ArenaHeroArt.metadata("knight")
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var cache_key:=key+("_"+str(ArenaHeroArt.MODERN[key].folder) if improved else "_legacy")
	if not frames_cache.has(cache_key):
		var bank:=SpriteFrames.new();bank.remove_animation("default")
		for facing in ["side","down","up"]:
			var path:=ArenaHeroArt.atlas(key,facing,improved)
			if not ResourceLoader.exists(path): continue
			var sheet: Texture2D=load(path)
			var sheet_image: Image=sheet.get_image()
			for row in range(STATES.size()):
				var animation_id: String=STATES[row]+"_"+facing
				var count:=ArenaMotion.frame_count(STATES[row]);var weights:=ArenaMotion.holds(key,STATES[row],improved)
				var loop_seconds:=1.6 if row==0 else (0.9 if row==1 else 0.6)
				bank.add_animation(animation_id);bank.set_animation_speed(animation_id,float(count)/loop_seconds);bank.set_animation_loop(animation_id,row<2)
				for index in range(count):
					if row==0 and index>0:
						bank.add_frame(animation_id,bank.get_frame_texture(animation_id,0),weights[index])
						continue
					var columns:=8 if improved else 12
					var column:=0 if row==0 else roundi(float(index)*(columns-1)/maxi(1,count-1))
					var frame_texture:=AtlasTexture.new();frame_texture.atlas=sheet
					frame_texture.region=Rect2(column*sheet.get_width()/float(columns),row*sheet.get_height()/7.0,sheet.get_width()/float(columns),sheet.get_height()/7.0)
					if columns==8 and pose_data.has("views"):
						var region: Dictionary=pose_data.views[facing].states[STATES[row]][column]
						var rect: Array=region.rect;var anchor: Array=region.anchor
						var anchor_x:=float(anchor[0]);var anchor_y:=float(anchor[1])
						if row==1:
							var used:=sheet_image.get_region(Rect2i(int(rect[0]),int(rect[1]),int(rect[2]),int(rect[3]))).get_used_rect()
							anchor_x=float(used.position.x)+float(used.size.x)*0.5
							anchor_y=float(used.position.y)+float(pose_data.views[facing].height)
						frame_texture.region=Rect2(rect[0],rect[1],rect[2],rect[3])
						frame_texture.margin=Rect2(256.0-anchor_x,480.0-anchor_y,512.0-float(rect[2]),512.0-float(rect[3]))
						frame_texture.filter_clip=true
					bank.add_frame(animation_id,frame_texture,weights[index])
		frames_cache[cache_key]=bank
	sprite_frames=frames_cache[cache_key]
	show_state("idle",Vector2.RIGHT)
func show_state(state: String, facing: Vector2, duration := 0.6) -> void:
	var locomotion:=state in ["idle","walk"]
	if facing.length_squared()>0.01:
		var requested:=facing.normalized()
		direction=direction.slerp(requested,0.55).normalized() if locomotion else requested
	var wanted_view: String="side" if direction.y<0 or absf(direction.x)>absf(direction.y)*0.8 else "down"
	if locomotion and wanted_view!=view:
		if wanted_view=="side" and absf(direction.x)<absf(direction.y)*1.12: wanted_view=view
		elif wanted_view!="side" and absf(direction.y)<absf(direction.x)*1.08: wanted_view=view
	view=wanted_view
	var desired: String=state+"_"+view
	if not sprite_frames.has_animation(desired): desired=state+"_side"
	if not sprite_frames.has_animation(desired): return
	flip_h=view=="side" and direction.x<0
	var image: Texture2D=sprite_frames.get_frame_texture(desired,0)
	feedback.base_scale=Vector2.ONE*visual_size/(image.get_height()*0.86);scale=feedback.base_scale;offset=Vector2(0,-image.get_height()*0.47)
	if polished and pose_data.has("views"):
		feedback.base_scale=Vector2.ONE*visual_size/float(pose_data.views[view].height);scale=feedback.base_scale;base_offset=Vector2(0,-224);offset=base_offset
	feedback.base_speed=1.0 if state in ["idle","walk"] else 0.6/maxf(0.1,duration)
	speed_scale=feedback.base_speed
	if animation!=desired:feedback.stop_left=0.0
	if animation!=desired or not is_playing(): play(desired)
func _process(delta: float) -> void:
	feedback.tick(self,delta)
	if not polished:return
	if animation.begins_with("walk"):
		breathe_phase+=delta*9.0;offset=base_offset+Vector2(0,sin(breathe_phase)*2.0)
	elif animation.begins_with("idle"):
		breathe_phase+=delta*1.6;offset=base_offset+Vector2(0,sin(breathe_phase)*1.1)
	else:offset=base_offset
func stride(speed: float) -> void:
	var target:=ArenaMotion.stride_scale(speed,visual_size)
	feedback.base_speed=lerpf(feedback.base_speed,target,0.25);speed_scale=feedback.base_speed
func emission_origin(state: String="") -> Vector2:
	if not polished or pose_data.is_empty():return get_parent().position+Vector2(0,-30)
	if state=="":state=str(animation).trim_suffix("_"+view)
	var count:=ArenaMotion.frame_count(state)
	var column:=roundi(float(ArenaMotion.release_frame(state,identity))*7.0/maxi(1,count-1))
	var spec: Dictionary=pose_data.views[view].states[state][column]
	if not spec.has("socket"):return get_parent().position+Vector2(0,-30)
	var anchor: Array=spec.anchor;var socket: Array=spec.socket
	return to_global(Vector2((float(socket[0])-float(anchor[0]))*(-1.0 if flip_h else 1.0),float(socket[1])-float(anchor[1])))
func has_complete_set() -> bool:
	for facing in ["side","down","up"]:
		for state in STATES:
			if not sprite_frames.has_animation(state+"_"+facing): return false
	return true
