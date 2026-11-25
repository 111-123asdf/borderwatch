class_name ArenaCreature
extends AnimatedSprite2D
var identity: String="fox"
var direction:=Vector2.RIGHT
var base_height:=50.0
var source_path: String=""
var is_pixel_v023:=false
var v023_has_skill:=false
var painted_poses:=false
var hover_clock:=0.0
var phase_seed:=0.0
var prev_step_band:=-1
var feedback:=ArenaVisualFeedback.new()
static var frame_cache: Dictionary={}

static func sheet_path(key: String) -> String:
	var lookup := "soldier_base" if key == "soldier" else key
	var v024 := "res://assets/towers_v024/creature_" + lookup + ".png"
	if ResourceLoader.exists(v024): return v024
	var v029_coast := "res://assets/monsters_v029_coast/creature_" + lookup + ".png"
	if ResourceLoader.exists(v029_coast): return v029_coast
	var v029_ruins := "res://assets/monsters_v029_ruins/creature_" + lookup + ".png"
	if ResourceLoader.exists(v029_ruins): return v029_ruins
	var v023 := "res://assets/monsters_v023/creature_" + lookup + ".png"
	if ResourceLoader.exists(v023): return v023
	var painted := "res://assets/hero_poses/creature_" + lookup + ".png"
	if ResourceLoader.exists(painted): return painted
	var v015 := "res://assets/v015/creature_" + lookup + ".png"
	return v015 if ResourceLoader.exists(v015) else "res://assets/v06/creature_" + lookup + ".png"

func configure(key: String, height := 50.0) -> void:
	identity=key;base_height=height
	phase_seed=fmod(float(abs(get_instance_id())%97)*0.37,TAU)
	hover_clock=0.0;position=Vector2.ZERO;rotation=0.0
	source_path=sheet_path(key)
	is_pixel_v023=source_path.begins_with("res://assets/monsters_v023/") or source_path.begins_with("res://assets/towers_v024/") or source_path.begins_with("res://assets/monsters_v029_coast/") or source_path.begins_with("res://assets/monsters_v029_ruins/")
	painted_poses=source_path.begins_with("res://assets/hero_poses/")
	feedback.disable_squash=painted_poses or (key in ["bear_vanguard","bear_woodsman","darksteel_guard","two_headed_troll","bloodshell_crab","bloodshell_boss","leviathan","bloodsoil_behemoth","bloodsoil_boss","baj_nimen"])
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST if is_pixel_v023 else CanvasItem.TEXTURE_FILTER_LINEAR
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
	material=null;feedback.material=null
	sprite_frames=frame_cache[source_path]
	v023_has_skill=is_pixel_v023 and sprite_frames!=null and sprite_frames.has_animation("skill")
	show_pose("walk",Vector2.RIGHT)

func show_pose(state: String, facing: Vector2) -> void:
	if painted_poses and state!="down" and feedback.age<0.11 and animation=="hurt":return
	if facing.length()>0.01:direction=facing
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
	if identity in ["wisp","moth","scout_vulture","storm_wyrm","void_gazer","water_sprite","tempest_elemental","void_eyeling","soul_reaver","vile_eyenest"]:return
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
		var is_flyer := identity in ["scout_vulture","storm_wyrm","void_gazer"]
		var is_floater := identity in ["wisp","spore","moth","water_sprite","tempest_elemental","void_eyeling","soul_reaver","twilight_golem","vile_eyenest"]
		if is_flyer:
			var fly_amp := 1.5 if reduced else 5.0
			hover_y = -28.0 + sin(hover_clock * 4.6 + phase_seed) * fly_amp
			if not reduced:
				hover_rot = sin(hover_clock * 2.3 + phase_seed) * 0.04
		elif is_floater and not painted_poses:
			var f_amp: float=(0.8 if reduced else 3.4) if identity!="vile_eyenest" else 2.8
			var f_spd: float=2.6 if identity in ["wisp","water_sprite","void_eyeling"] else 2.0
			hover_y=-3.5+sin(hover_clock*f_spd+phase_seed)*f_amp
			if not reduced:
				hover_rot=sin(hover_clock*(f_spd*0.65)+phase_seed)*0.025
		elif not is_floater and animation=="walk" and is_playing() and not stunned and not reduced:
			var step_freq: float=9.2 if identity in ["fox","spearman","rottooth_hyena","throat_cutter","tide_rider","wind_captain","twilight_harasser","spectral_cutter","avenger_rider"] else 5.2
			var band:=int(floor((hover_clock*step_freq+phase_seed)/PI))
			if band!=prev_step_band:
				prev_step_band=band
				var back_dir:=Vector2(-signf(direction.x) if absf(direction.x)>0.1 else -1.0,-0.32)
				var is_sub := enemy_owner.is_submerged() if enemy_owner.has_method("is_submerged") else false
				var d_sz:=24.0 if identity in ["brute","bear_vanguard","darksteel_guard","two_headed_troll","bloodshell_crab","bloodshell_boss","leviathan","bloodsoil_behemoth","bloodsoil_boss","baj_nimen"] else 14.0
				var dust_col := Color("94ecff") if (is_sub or identity == "leviathan") else Color("a6a089")
				ArenaBattleArt.emit_world_dust(global_position+Vector2(randf_range(-4.0,4.0),3.0),back_dir*22.0,d_sz,dust_col)
		if is_enemy and enemy_owner.has_method("is_submerged") and enemy_owner.is_submerged() and not is_flyer:
			hover_y += 5.0 + sin(hover_clock * 5.2 + phase_seed) * (0.8 if reduced else 2.2)
	var fb_pct: float=clampf(1.0-feedback.age/0.14,0.0,1.0) if feedback.age<0.14 else 0.0
	if is_enemy:
		var recoil := feedback.incoming * fb_pct * fb_pct * (1.0 if reduced else 6.0)
		position=Vector2(0.0, hover_y) + recoil
		rotation=hover_rot + recoil.x*0.018
		if painted_poses:
			position=(owner_node.global_position+position).snapped(Vector2.ONE)-owner_node.global_position
			rotation=0.0
