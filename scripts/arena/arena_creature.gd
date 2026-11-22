class_name ArenaCreature
extends AnimatedSprite2D
const CONSTRUCT_SHADER_PATH := "res://scripts/shaders/construct_emissive.gdshader"
var identity: String="fox"
var direction:=Vector2.RIGHT
var base_height:=50.0
var source_path: String=""
var is_pixel_v016:=false
var is_pixel_v023:=false
var v023_has_skill:=false
var painted_poses:=false
var construct_rig: ArenaConstructRig
var salt_rig: ArenaSaltCreature
static var salt_clock_frames: SpriteFrames
var emissive_material: ShaderMaterial
var hover_clock:=0.0
var phase_seed:=0.0
var dissolve_clock:=0.0
var prev_step_band:=-1
var _last_hit_flash:=-1.0
var _last_chill:=-1.0
var _last_boss_phase:=-1
var _last_low_hp:=false
var feedback:=ArenaVisualFeedback.new()
static var frame_cache: Dictionary={}
static func sheet_path(key: String) -> String:
	var lookup := "soldier_base" if key == "soldier" else key
	var v024 := "res://assets/towers_v024/creature_" + lookup + ".png"
	if ResourceLoader.exists(v024): return v024
	var v023:="res://assets/monsters_v023/creature_"+key+".png"
	if ResourceLoader.exists(v023):return v023
	var painted:="res://assets/hero_poses/creature_"+key+".png"
	if ResourceLoader.exists(painted):return painted
	var modern:="res://assets/v017/creature_"+key+".png"
	if ResourceLoader.exists(modern):return modern
	var v016: String="res://assets/v016/creature_"+key+".png"
	if ResourceLoader.exists(v016):return v016
	var v015: String="res://assets/v015/creature_"+key+".png"
	return v015 if ResourceLoader.exists(v015) else "res://assets/v06/creature_"+key+".png"
static func emit_path_for(sheet: String) -> String:
	if not sheet.ends_with(".png"):return ""
	var candidate: String=sheet.trim_suffix(".png")+"_emit.png"
	return candidate if ResourceLoader.exists(candidate) else ""
func _pulse_defaults(key: String) -> Dictionary:
	match key:
		"construct_hound":
			return {"color":Color(0.86,0.68,1.0,1.0),"speed":3.0,"strength":1.20}
		"rune_warden":
			return {"color":Color(0.58,0.92,1.0,1.0),"speed":2.0,"strength":1.25}
		"astral_prism":
			return {"color":Color(0.84,0.96,1.0,1.0),"speed":2.6,"strength":1.35}
		"rift_bomber":
			return {"color":Color(1.0,0.68,0.42,1.0),"speed":4.8,"strength":1.40}
		"void_harvester":
			return {"color":Color(0.92,0.64,1.0,1.0),"speed":2.8,"strength":1.30}
		"colossus":
			return {"color":Color(0.94,0.96,1.0,1.0),"speed":2.2,"strength":1.35}
		_:
			return {"color":Color.WHITE,"speed":2.6,"strength":1.25}
func _setup_emissive_material() -> void:
	emissive_material=null;material=null;feedback.material=null
	if not ResourceLoader.exists(CONSTRUCT_SHADER_PATH):return
	var shader:=load(CONSTRUCT_SHADER_PATH) as Shader
	if shader==null:return
	var mat:=ShaderMaterial.new()
	mat.shader=shader
	var emit_path:=emit_path_for(source_path)
	if emit_path!="" and ResourceLoader.exists(emit_path):
		var emit_tex:=load(emit_path) as Texture2D
		if emit_tex!=null:mat.set_shader_parameter("emit_tex",emit_tex)
	var preset:=_pulse_defaults(identity)
	mat.set_shader_parameter("pulse_color",preset.color)
	mat.set_shader_parameter("pulse_speed",float(preset.speed))
	mat.set_shader_parameter("emit_strength",float(preset.strength))
	mat.set_shader_parameter("phase_offset",phase_seed)
	mat.set_shader_parameter("chill_amount",0.0)
	mat.set_shader_parameter("hit_flash",0.0)
	mat.set_shader_parameter("flash_strength",0.0)
	mat.set_shader_parameter("dissolve_progress",0.0)
	emissive_material=mat;material=mat;feedback.material=mat
func configure(key: String, height := 50.0) -> void:
	identity=key;base_height=height
	phase_seed=fmod(float(abs(get_instance_id())%97)*0.37,TAU)
	hover_clock=0.0;dissolve_clock=0.0;position=Vector2.ZERO;rotation=0.0
	if ArenaSaltCreature.TYPES.has(key):
		_configure_salt(key)
		return
	source_path=sheet_path(key)
	is_pixel_v016=source_path.begins_with("res://assets/v016/")
	is_pixel_v023=source_path.begins_with("res://assets/monsters_v023/") or source_path.begins_with("res://assets/towers_v024/")
	painted_poses=source_path.begins_with("res://assets/hero_poses/")
	feedback.disable_squash=painted_poses or (key in ["bear_vanguard","bear_woodsman","darksteel_guard","two_headed_troll"])
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if (is_pixel_v016 or is_pixel_v023) else (CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if source_path.begins_with("res://assets/v017/") else CanvasItem.TEXTURE_FILTER_LINEAR)
	if not frame_cache.has(source_path):
		var bank:=SpriteFrames.new();bank.remove_animation("default")
		if ResourceLoader.exists(source_path):
			var sheet:=load(source_path) as Texture2D
			if sheet!=null and sheet.get_width()>=6 and sheet.get_height()>=3:
				var rows:=4 if painted_poses else 3
				if is_pixel_v023:
					var cell_w := maxf(1.0, float(sheet.get_width()) / 6.0)
					rows = maxi(3, int(round(float(sheet.get_height()) / cell_w)))
				var row_labels: Array = (["walk","attack","skill","down"] if (is_pixel_v023 and rows>=4) else (["walk","attack","down","hurt"] if painted_poses else ["walk","attack","down"]))
				for row in range(mini(rows, row_labels.size())):
					var label: String=str(row_labels[row])
					bank.add_animation(label);bank.set_animation_speed(label,8.0 if is_pixel_v023 else 9.0);bank.set_animation_loop(label,label=="walk")
					if is_pixel_v023 and label=="attack":bank.set_animation_speed(label,10.0)
					for col in range(6):
						var image:=AtlasTexture.new();image.atlas=sheet
						image.region=Rect2(col*sheet.get_width()/6.0,row*sheet.get_height()/float(rows),sheet.get_width()/6.0,sheet.get_height()/float(rows))
						image.filter_clip=is_pixel_v023
						bank.add_frame(label,image)
		frame_cache[source_path]=bank
	if is_pixel_v016:_setup_emissive_material()
	else:emissive_material=null;material=null;feedback.material=null
	sprite_frames=frame_cache[source_path]
	v023_has_skill=is_pixel_v023 and sprite_frames!=null and sprite_frames.has_animation("skill")
	show_pose("walk",Vector2.RIGHT)
	if source_path.begins_with("res://assets/v017/"):
		self_modulate=Color(1,1,1,0)
		construct_rig=ArenaConstructRig.new();add_child(construct_rig);construct_rig.configure(key)
func _configure_salt(key: String) -> void:
	if salt_clock_frames==null:
		salt_clock_frames=SpriteFrames.new()
		var image:=ImageTexture.create_from_image(Image.create_empty(2,2,false,Image.FORMAT_RGBA8))
		for state in ["walk","attack","down"]:
			salt_clock_frames.add_animation(state)
			salt_clock_frames.set_animation_loop(state,state=="walk")
			salt_clock_frames.set_animation_speed(state,9.0)
			for frame_index in range(6):
				salt_clock_frames.add_frame(state,image)
	sprite_frames=salt_clock_frames
	self_modulate.a=0.0
	feedback.disable_squash=true
	salt_rig=ArenaSaltCreature.new()
	salt_rig.identity=key
	add_child(salt_rig)
	show_pose("walk",Vector2.RIGHT)

func show_pose(state: String, facing: Vector2) -> void:
	if painted_poses and state!="down" and feedback.age<0.11 and animation=="hurt":return
	if facing.length()>0.01:direction=facing
	if salt_rig!=null:
		if animation!=state or (state=="walk" and not is_playing()):play(state)
		return
	flip_h=direction.x<0
	var resolved_state := state
	if resolved_state=="skill" and (sprite_frames==null or not sprite_frames.has_animation("skill")):
		resolved_state="attack"
	if sprite_frames==null or not sprite_frames.has_animation(resolved_state):return
	var image: Texture2D=sprite_frames.get_frame_texture(resolved_state,0)
	if image==null or image.get_height()<=0:return
	if is_pixel_v023:
		var fill_ratio := 0.70 if image.get_height() >= 240 else 0.62
		feedback.base_scale=Vector2.ONE*base_height/(image.get_height()*fill_ratio);scale=feedback.base_scale
		offset=Vector2(0,-image.get_height()*0.375)
	else:
		feedback.base_scale=Vector2.ONE*base_height/(image.get_height()*0.78);scale=feedback.base_scale
		offset=Vector2(0,-44) if painted_poses else Vector2(0,-image.get_height()*ArenaArtAnchors.offset_for("creature_"+identity,source_path))
	feedback.base_speed=1.0;speed_scale=feedback.base_speed
	if resolved_state!="down":
		dissolve_clock=0.0
		if emissive_material!=null:emissive_material.set_shader_parameter("dissolve_progress",0.0)
	if animation!=resolved_state:feedback.stop_left=0.0
	if animation!=resolved_state or (resolved_state=="walk" and not is_playing()):play(resolved_state)
func hit_pose(incoming: Vector2) -> void:
	if not painted_poses or animation=="down":return
	if is_instance_valid(get_parent()) and get_parent() is ArenaEnemy:
		if get_parent().melee_windup>0 or get_parent().windup>0:return
	if not incoming.is_zero_approx():flip_h=incoming.x>0
	play("hurt")
	frame=0

func match_stride(speed: float) -> void:
	if identity in ["wisp","moth","astral_prism","rift_bomber","colossus","scout_vulture"]:return
	feedback.base_speed=clampf(speed*6.0/(base_height*0.85*9.0),0.45,1.8);speed_scale=feedback.base_speed
func _process(delta: float) -> void:
	var owner_node:=get_parent()
	var enemy_owner:=owner_node as ArenaEnemy
	var is_enemy: bool=enemy_owner!=null
	var stunned: bool=is_enemy and enemy_owner.stun>0.0
	if stunned:feedback.base_speed=0.0
	feedback.tick(self,delta)
	var reduced: bool=feedback.reduced
	if is_enemy and enemy_owner.game!=null:
		var camp: Variant=enemy_owner.game.get("campaign")
		if camp!=null and typeof(camp.get("data"))==TYPE_DICTIONARY:
			reduced=reduced or bool(camp.data.get("reduced_motion",false))
	hover_clock+=delta
	var is_down: bool=(animation=="down") or (is_enemy and enemy_owner.dead)
	var hover_y: float=0.0
	var hover_rot: float=0.0
	if is_enemy and not is_down:
		if identity=="brute":
			feedback.disable_squash=true
		var is_flying_vulture := identity == "scout_vulture"
		var is_floater:=identity in ["wisp","spore","moth","astral_prism","rift_bomber","void_harvester","colossus"]
		if is_flying_vulture:
			var fly_amp := 1.5 if reduced else 5.0
			hover_y = -28.0 + sin(hover_clock * 4.6 + phase_seed) * fly_amp
			if not reduced:
				hover_rot = sin(hover_clock * 2.3 + phase_seed) * 0.04
		elif is_floater and construct_rig==null and not painted_poses:
			var f_amp: float=(0.8 if reduced else 3.4) if identity!="colossus" else 2.6
			var f_spd: float=2.6 if identity in ["wisp","astral_prism"] else 2.0
			hover_y=-3.5+sin(hover_clock*f_spd+phase_seed)*f_amp
			if not reduced:
				hover_rot=sin(hover_clock*(f_spd*0.65)+phase_seed)*0.025
		elif not is_floater and construct_rig==null and animation=="walk" and is_playing() and not stunned and not reduced:
			var step_freq: float=9.2 if identity in ["fox","spearman","rottooth_hyena","throat_cutter"] else 5.2
			var band:=int(floor((hover_clock*step_freq+phase_seed)/PI))
			if band!=prev_step_band:
				prev_step_band=band
				var back_dir:=Vector2(-signf(direction.x) if absf(direction.x)>0.1 else -1.0,-0.32)
				var d_sz:=24.0 if identity in ["brute","bear_vanguard","darksteel_guard","two_headed_troll"] else 14.0
				ArenaBattleArt.emit_world_dust(global_position+Vector2(randf_range(-4.0,4.0),3.0),back_dir*22.0,d_sz,Color("a6a089"))
	var hurt_pct: float=clampf(enemy_owner.hurt_time/0.12,0.0,1.0) if is_enemy else 0.0
	var fb_pct: float=clampf(1.0-feedback.age/0.14,0.0,1.0) if feedback.age<0.14 else 0.0
	var hit_intensity: float=maxf(hurt_pct,fb_pct)
	var shake_x: float=0.0
	var shake_y: float=0.0
	var hit_rot: float=0.0
	if is_pixel_v016 and not is_down and hit_intensity>0.001 and not reduced:
		var w: float=hover_clock*72.0+phase_seed
		var mag: float=2.6 if identity!="colossus" else 1.8
		shake_x=sin(w)*mag*hit_intensity
		shake_y=cos(w*1.37)*(mag*0.42)*hit_intensity
		hit_rot=sin(w*0.71)*(0.065 if identity!="colossus" else 0.030)*hit_intensity
	if is_enemy and construct_rig==null:
		var recoil := feedback.incoming * fb_pct * fb_pct * (1.0 if reduced else 6.0)
		position=Vector2(shake_x,hover_y+shake_y) + recoil
		rotation=hover_rot+hit_rot + recoil.x*0.018
		if painted_poses:
			position=(owner_node.global_position+position).snapped(Vector2.ONE)-owner_node.global_position
			rotation=0.0
	if emissive_material!=null:
		if is_enemy:
			var hf_val:=hit_intensity*(0.22 if reduced else 0.78)
			if absf(hf_val-_last_hit_flash)>0.01:
				emissive_material.set_shader_parameter("hit_flash",hf_val);_last_hit_flash=hf_val
			var chill: float=1.0 if stunned else clampf((0.55 if enemy_owner.slow>0.0 else 0.0)+float(enemy_owner.frost_stacks)*0.22,0.0,1.0)
			if absf(chill-_last_chill)>0.01:
				emissive_material.set_shader_parameter("chill_amount",chill);_last_chill=chill
			if identity=="colossus" and enemy_owner.boss_phase!=_last_boss_phase:
				_last_boss_phase=enemy_owner.boss_phase
				if enemy_owner.boss_phase>=2:
					emissive_material.set_shader_parameter("pulse_color",Color(0.95,0.52,1.0,1.0))
					emissive_material.set_shader_parameter("pulse_speed",6.0)
					emissive_material.set_shader_parameter("emit_strength",1.95)
				elif enemy_owner.boss_phase==1:
					emissive_material.set_shader_parameter("pulse_color",Color(0.45,0.96,1.0,1.0))
					emissive_material.set_shader_parameter("pulse_speed",3.8)
					emissive_material.set_shader_parameter("emit_strength",1.65)
			elif identity=="rift_bomber":
				var low_hp: bool=enemy_owner.max_health>0.0 and enemy_owner.health<enemy_owner.max_health*0.4
				if low_hp and not _last_low_hp:
					_last_low_hp=true
					emissive_material.set_shader_parameter("pulse_speed",8.4)
					emissive_material.set_shader_parameter("emit_strength",1.80)
		elif animation=="down":
			dissolve_clock+=delta
			emissive_material.set_shader_parameter("dissolve_progress",clampf(dissolve_clock/0.62,0.0,1.0))
			emissive_material.set_shader_parameter("hit_flash",0.0)
			emissive_material.set_shader_parameter("flash_strength",0.0)
			rotation=0.0
