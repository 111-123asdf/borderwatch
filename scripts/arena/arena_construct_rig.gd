class_name ArenaConstructRig
extends Node2D
## Painted rigid pieces with weight-class gaits (light/heavy/floating), hit-stop pause, and world-space dust.
static var definitions: Dictionary={}
static var dust_tex: Texture2D
static var shared_default_skin: ShaderMaterial
const DEFAULT_RUINS_TINT := Color(0.94,0.98,1.03)
var pieces: Array[Dictionary]=[]
var phase:=0.0
var prev_step_index:=-1
var previous:=Vector2.ZERO
var art_height:=476.0
var gait_kind:="heavy"
var configured:=false
var skin: ShaderMaterial
var _using_shared_skin:=true
var torso: Texture2D
var last_flash:=-1.0
var last_tint:=Color(-1,-1,-1,-1)
var torso_lift:=0.0
var forward_lean:=0.0
var hit_recoil:=0.0

func _ensure_local_skin() -> void:
	if _using_shared_skin or skin==null:
		skin=ArenaGrounding.material("ruins")
		_using_shared_skin=false
		material=skin

func configure(key: String) -> void:
	if definitions.is_empty():
		var file:=FileAccess.open("res://assets/v017/rigs.json",FileAccess.READ)
		if file!=null:definitions=JSON.parse_string(file.get_as_text())
	if dust_tex==null and ResourceLoader.exists("res://assets/v018/particles/smoke_07.png"):
		dust_tex=load("res://assets/v018/particles/smoke_07.png")
	if not definitions.has(key):return
	var data: Dictionary=definitions[key];art_height=float(data.height)
	if key in ["astral_prism","rift_bomber","void_harvester"]:
		gait_kind="floating"
	elif key=="construct_hound":
		gait_kind="light"
	else:
		gait_kind="heavy"
	# Desync phase per rig instance so enemy waves never march in unison.
	phase=fmod(float(abs(get_instance_id()))*0.6180339,1.0)*TAU
	if shared_default_skin==null:
		shared_default_skin=ArenaGrounding.material("ruins")
	material=shared_default_skin
	_using_shared_skin=true
	torso=load("res://assets/v017/actor_"+key+"_body.png")
	for entry in data.parts:
		var pivot:=Vector2(float(entry.pivot[0]),float(entry.pivot[1]))
		var origin_data: Array=entry.get("origin",[0,0]);var origin:=Vector2(float(origin_data[0]),float(origin_data[1]))
		pieces.append({"texture":load("res://assets/v017/"+str(entry.file)),"pivot":pivot,"origin":origin,"phase":float(entry.phase)*PI,"role":str(entry.get("role","leg")),"angle":0.0,"lift":0.0})
	var owner_art:=get_parent() as ArenaCreature
	if owner_art!=null:
		owner_art.feedback.disable_squash=true
	previous=global_position;configured=true

func _process(delta: float) -> void:
	if not configured:return
	var owner_art:=get_parent() as ArenaCreature
	if owner_art==null:return
	owner_art.feedback.disable_squash=true
	var enemy_node:=owner_art.get_parent() as ArenaEnemy
	var move_delta:=global_position-previous
	var distance:=move_delta.length();previous=global_position
	var down:=owner_art.animation=="down"
	var hit_stopped:=not down and owner_art.feedback.stop_left>0.0
	var walking:=owner_art.animation=="walk" and distance>0.01 and distance<24.0
	var reduced:=owner_art.feedback.reduced
	var flash:=maxf(0.0,1.0-owner_art.feedback.age/0.08)*(0.18 if reduced else 0.58)
	var chill_tint:=DEFAULT_RUINS_TINT
	if enemy_node!=null:
		chill_tint=Color(0.72,0.92,1.18) if enemy_node.slow>0.0 or enemy_node.stun>0.0 else (Color(1.12,0.86,0.74) if enemy_node.burn_clock>0.0 else DEFAULT_RUINS_TINT)
	var need_local: bool=(flash>0.01 or chill_tint!=DEFAULT_RUINS_TINT)
	if need_local:
		_ensure_local_skin()
		if absf(flash-last_flash)>0.01:
			skin.set_shader_parameter("flash_strength",flash);last_flash=flash
		if chill_tint!=last_tint:
			skin.set_shader_parameter("environment_tint",chill_tint);last_tint=chill_tint
	elif not _using_shared_skin:
		material=shared_default_skin;_using_shared_skin=true;last_flash=0.0;last_tint=DEFAULT_RUINS_TINT
	var factor:=owner_art.base_height/art_height/maxf(0.001,absf(owner_art.scale.y))
	var floating:=gait_kind=="floating"
	if not hit_stopped:
		if floating:
			phase+=delta*(2.4 if gait_kind=="floating" else 2.0)
		elif walking:
			var rate:=10.2 if gait_kind=="light" else 5.2
			phase+=distance/owner_art.base_height*rate
	if not reduced and (walking or floating) and not down:
		if gait_kind=="floating":
			torso_lift=-16.0-sin(phase)*9.0-cos(phase*0.65)*3.0
			forward_lean=0.06 if walking else 0.015
		elif gait_kind=="light":
			var hop:=absf(sin(phase))
			torso_lift=-hop*13.0
			forward_lean=0.075+hop*0.03
			if walking and not hit_stopped:
				var step_idx:=int(floor(phase/PI))
				if step_idx!=prev_step_index:
					prev_step_index=step_idx
					var back_dir:=Vector2(-signf(owner_art.direction.x) if absf(owner_art.direction.x)>0.1 else -1.0,-0.35)
					ArenaBattleArt.emit_world_dust(global_position+Vector2(randf_range(-5.0,5.0),4.0),back_dir*28.0,randf_range(16.0,22.0),Color(0.78,0.75,0.82))
		else:
			# Heavy construct: slow lift followed by sudden weighty plant
			var wave_abs:=absf(sin(phase))
			var lift_curve:=pow(wave_abs,1.55)
			torso_lift=-lift_curve*10.5+(3.2 if wave_abs<0.22 else 0.0)
			forward_lean=0.035*sin(phase)
			if walking and not hit_stopped:
				var step_idx:=int(floor(phase/PI))
				if step_idx!=prev_step_index:
					prev_step_index=step_idx
					var back_dir:=Vector2(-signf(owner_art.direction.x) if absf(owner_art.direction.x)>0.1 else -1.0,-0.25)
					ArenaBattleArt.emit_world_dust(global_position+Vector2(randf_range(-8.0,8.0),5.0),back_dir*22.0,randf_range(24.0,32.0),Color(0.72,0.70,0.78))
	else:
		torso_lift=move_toward(torso_lift,0.0,delta*75.0)
		forward_lean=move_toward(forward_lean,0.0,delta*6.0)
	hit_recoil=flash*(0.10 if not reduced else 0.02)
	var stop_jitter:=Vector2(sin(owner_art.feedback.stop_left*240.0)*1.3,0.0) if hit_stopped and not reduced else Vector2.ZERO
	if position!=stop_jitter:position=stop_jitter
	var next_scale:=Vector2(-factor if owner_art.direction.x<0 else factor,factor)
	if scale!=next_scale:scale=next_scale
	var amplitude:=0.04 if reduced else (0.28 if gait_kind=="light" else (0.16 if gait_kind=="heavy" else 0.14))
	for piece in pieces:
		var role:=str(piece.role)
		if owner_art.animation=="attack":
			var fp:=clampf(float(owner_art.frame)/5.0,0.0,1.0)
			# Windup (0..0.35) -> Snap strike (0.35..0.6) -> Recover (0.6..1.0)
			var atk_pose:=-sin(fp/0.35*PI*0.5)*0.48 if fp<0.35 else (lerpf(-0.48,0.58,(fp-0.35)/0.25) if fp<0.6 else lerpf(0.58,0.0,(fp-0.6)/0.4))
			if role=="arm":
				piece.angle=atk_pose*(0.2 if reduced else 1.0)
			elif floating:
				piece.angle=sin(phase+float(piece.phase))*amplitude*0.6
		elif hit_stopped:
			pass
		else:
			var wave:=sin(phase+float(piece.phase))
			if floating:
				piece.angle=wave*amplitude+cos(phase*1.45+float(piece.phase))*0.06
				piece.lift=sin(phase*1.3+float(piece.phase))*7.5
			elif walking:
				var leg_curve:=signf(wave)*pow(absf(wave),0.85 if gait_kind=="light" else 1.25)
				piece.angle=leg_curve*amplitude
				piece.lift=-maxf(0.0,wave)*(15.0 if gait_kind=="light" else 9.0)
			else:
				piece.angle=lerp_angle(float(piece.angle),0.0,minf(1.0,delta*16.0))
				piece.lift=move_toward(float(piece.lift),0.0,delta*55.0)
	var next_rot:=lerp_angle(rotation,(0.65 if down else forward_lean-hit_recoil),minf(1.0,delta*16.0))
	if absf(next_rot-rotation)>0.001:rotation=next_rot
	var next_a:=0.45 if down else 1.0
	if absf(modulate.a-next_a)>0.005:modulate.a=next_a
	if walking or floating or down or hit_stopped or owner_art.animation=="attack" or flash>0.01 or absf(torso_lift)>0.05:
		queue_redraw()

func _draw() -> void:
	if torso==null:return
	var lift_vec:=Vector2(0.0,torso_lift)
	draw_texture(torso,Vector2(-256,-494)+lift_vec)
	for piece in pieces:
		var pivot: Vector2=piece.pivot
		draw_set_transform(pivot-Vector2(256,494)+Vector2(0,float(piece.lift)+torso_lift*0.65),float(piece.angle))
		draw_texture(piece.texture,Vector2(piece.origin)-pivot)
	draw_set_transform(Vector2.ZERO)
