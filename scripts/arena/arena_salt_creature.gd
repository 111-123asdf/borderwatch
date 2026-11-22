class_name ArenaSaltCreature
extends Node2D

const TYPES := {"fiddler":68.0,"mudshrimp":66.0,"salt_hermit":78.0,"anchor_crab":144.0}
static var meshes: Dictionary = {}
var identity := "fiddler"
var gait := 0.0
var previous := Vector2.ZERO
var lean := 0.0
var lift := 0.0
var strike := 0.0
var fall := 0.0
var flash := 0.0
var hit_direction := Vector2.ZERO
var side := 1.0
var last_step := 0
var painted: MeshInstance2D
var pose_material: ShaderMaterial
var painted_width := 0.0

func _ready() -> void:
	previous=global_position
	gait=fposmod(float(get_instance_id())*0.382,TAU)
	_make_painted_rig()

func _process(delta: float) -> void:
	var actor := get_parent() as ArenaCreature
	if actor==null:
		return
	var enemy := actor.get_parent() as ArenaEnemy
	var distance := global_position.distance_to(previous)
	previous=global_position
	if enemy!=null and (not enemy.game.running or enemy.game.game_over):
		return
	if actor.animation=="down":
		fall=minf(1.0,fall+delta*2.6)
		_pose_paint(0.0,0.0,0.3 if actor.feedback.reduced else 1.0)
		return
	var reduced := bool(enemy.game.campaign.data.reduced_motion) if enemy!=null else actor.feedback.reduced
	var motion := 0.28 if reduced else 1.0
	if absf(actor.direction.x)>0.1:
		side=signf(actor.direction.x)
	if actor.feedback.stop_left<=0.0 and distance<24.0:
		gait+=distance*(0.16 if identity=="anchor_crab" else 0.28)
	var moving := distance>0.02 and distance<24.0
	var sprinting := enemy!=null and identity=="mudshrimp" and enemy.salt_move_clock>=1.65
	var crouched := enemy!=null and identity=="mudshrimp" and enemy.salt_move_clock>=1.18 and not sprinting and enemy.blocker==null
	lift=lerpf(lift,(-4.5 if sprinting else (3.0 if crouched else (-1.8*absf(sin(gait)) if moving else 0.0)))*motion,minf(1.0,delta*22))
	lean=lerpf(lean,(0.18 if sprinting else (-0.14 if crouched else sin(gait)*0.05))*motion,minf(1.0,delta*18))
	var charging := enemy!=null and (enemy.melee_windup>0.0 or enemy.salt_slam_left>0.0)
	strike=move_toward(strike,(0.5 if reduced else 1.0) if charging else 0.0,delta*(4.0 if charging else 6.0))
	flash=pow(maxf(0.0,1.0-actor.feedback.age/0.19),2.0)*(0.35 if reduced else 1.0)
	hit_direction=actor.feedback.incoming
	var step := int(gait/PI)
	if not reduced and enemy!=null and global_position.y>535 and moving and step!=last_step and step%2==0:
		ArenaBattleArt.emit_world_dust(global_position+Vector2(0,3),Vector2(-side*24,-14),13,Color("ceeadd"))
	last_step=step
	_pose_paint(1.0 if moving else 0.0,strike,motion)

func _draw() -> void:
	if painted==null:return
	ArenaGrounding.ensure_textures()
	var w := painted_width*0.85
	draw_texture_rect(ArenaGrounding.shadow,Rect2(-w*0.43,-w*0.13,w,w*0.24),false)

func _make_painted_rig() -> void:
	var path := "res://assets/saltport/body_"+identity+".png"
	if not ResourceLoader.exists(path):
		return
	var art: Texture2D=load(path)
	painted_width=TYPES[identity]
	var size := art.get_size()*painted_width/art.get_width()
	painted=MeshInstance2D.new()
	painted.texture=art
	painted.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not meshes.has(identity):meshes[identity]=_pose_grid(size)
	painted.mesh=meshes[identity]
	pose_material=ShaderMaterial.new()
	pose_material.shader=preload("res://scripts/shaders/salt_creature_pose.gdshader")
	pose_material.set_shader_parameter("abdomen",1.0 if identity=="mudshrimp" else 0.24)
	painted.material=pose_material
	add_child(painted)

func _pose_paint(stride: float,claw: float,motion: float) -> void:
	if painted==null:return
	painted.transform=Transform2D(side*(lean+fall*0.84),Vector2(side,1.0-fall*0.45),0.0,Vector2(0,lift+fall*8)+hit_direction*flash*5.0)
	painted.self_modulate.a=1.0-fall*0.6
	pose_material.set_shader_parameter("gait",fposmod(gait,TAU))
	pose_material.set_shader_parameter("stride",stride)
	pose_material.set_shader_parameter("gather",claw)
	pose_material.set_shader_parameter("flash",flash*(1.0-fall))
	pose_material.set_shader_parameter("motion",motion)

static func _pose_grid(size: Vector2) -> ArrayMesh:
	const COLUMNS := 16
	const ROWS := 10
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for y in range(ROWS+1):
		for x in range(COLUMNS+1):
			var uv := Vector2(float(x)/COLUMNS,float(y)/ROWS)
			uvs.append(uv)
			vertices.append((uv-Vector2(0.50,0.96))*size)
			if y<ROWS and x<COLUMNS:
				var top := y*(COLUMNS+1)+x
				var bottom := top+COLUMNS+1
				indices.append_array(PackedInt32Array([top,top+1,bottom,top+1,bottom+1,bottom]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
