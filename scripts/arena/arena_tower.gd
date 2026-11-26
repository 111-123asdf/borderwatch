class_name ArenaTower
extends Node2D
var game: Node2D
var kind: String="archer"
var site_id:=0
var level:=1
var data: Dictionary={}
var destroyed:=false
var doctrine_id: String=""
var doctrine_data: Dictionary={}
var unlocked_enhancements := 0
var enhancement_mods: Dictionary = {}
const AttackTiming := preload("res://scripts/arena/arena_attack_timing.gd")
var attack_clock:=0.0
var fire_clock:=0.0
var jam_clock:=0.0
var jam_slow:=0.0
var seal_telegraph:=0.0
var seal_clock:=0.0
var _pending_seal_dur:=0.0
var timing: AttackTiming = AttackTiming.new()
const SALE_REFUND_RATIO := 0.6
const MAX_LEVEL := 3
var barrier_clock := 3.0
var barrier_active_clock := 0.0

func is_sealed() -> bool:
	return seal_clock > 0.0

func is_seal_warning() -> bool:
	return seal_telegraph > 0.0

func apply_seal(duration := 7.5, telegraph := 3.0) -> void:
	if destroyed:
		return
	if telegraph <= 0.0:
		seal_telegraph = 0.0
		_pending_seal_dur = 0.0
		seal_clock = maxf(seal_clock, duration)
		timing.cancel()
		focus_target = null
		focus_layers = 0
		if tower_fx != null:
			tower_fx.queue_redraw()
		_sync_tower_draw()
		if game != null and game.hud != null and game.selected_site == site_id:
			game.hud.refresh_context()
		return
	seal_telegraph = maxf(seal_telegraph, telegraph)
	_pending_seal_dur = maxf(_pending_seal_dur, duration)
	if tower_fx != null:
		tower_fx.queue_redraw()
	_sync_tower_draw()
var _draw_sig: int = -1
var _part_base_scale: Vector2 = Vector2.ONE
var _last_pose_phase: int = -1
var _last_pose_aim: Vector2 = Vector2.ZERO
var _last_pose_prep: float = -1.0
var use_v024_art := false
var _v024_base_scale := Vector2.ONE
var _v024_frame := 0
var _v024_flip := false
var _v024_flash := 0.0
var _v024_recoil := 0.0
var _snare_snap_clock := 0.0
func _is_healer_buffed() -> bool:
	return game != null and game.hero != null and game.hero.has_method("healer_tower_speed_bonus") and game.hero.healer_tower_speed_bonus(position) > 0.0
func apply_jam(duration: float, slow_ratio := 0.35) -> void:
	jam_clock = maxf(jam_clock, duration)
	jam_slow = maxf(jam_slow, clampf(slow_ratio, 0.0, 0.55))
func can_hit_flying() -> bool:
	return kind in ["archer","mage","storm","lens"]
func _sync_tower_draw() -> void:
	var sel: int = 1 if game.selected_site==site_id else 0
	var sig: int = sel+(unlocked_enhancements<<1)+(1<<7 if doctrine_id!="" else 0)+(1<<8 if _is_healer_buffed() else 0)+(1<<9 if jam_clock>0.0 else 0)+(1<<10 if seal_clock>0.0 else 0)+(1<<11 if seal_telegraph>0.0 else 0)
	if sig!=_draw_sig:
		_draw_sig=sig;queue_redraw()
var rally_point:=Vector2.ZERO
var rally_across:=Vector2.DOWN
var bombard_point:=Vector2.INF
var target_mode: String="first"
var troops: Array=[]
var body: Sprite2D
var moving_part: Sprite2D
var visual_clock:=0.0
var visual_target:=Vector2.RIGHT
const Ballista := preload("res://scripts/arena/arena_ballista.gd")
# Points on the 512px paintings: watchtower booth deck, arcane orb center, mortar cradle trunnion, barracks door.
const SOCKETS := {
	"archer":[Vector2(272,178),Vector2(308,166),Vector2(260,172)],
	"mage":[Vector2(258,210),Vector2(261,165),Vector2(260,178)],
	"cannon":[Vector2(248,304),Vector2(288,282),Vector2(314,266)],
	"barracks":[Vector2(229,433),Vector2(167,427),Vector2(303,425)]
}
var swivel := Vector2.ZERO
var ballista: Ballista
var pivot_bed: Node2D
var tower_fx: Node2D
var focus_target: ArenaEnemy
var focus_layers:=0
const SNARE_ARM_TIME:=1.2
var project_level:=0
var project_clock:=0.0
var project_gold:=0
var project_doctrine:=""
var invested_gold:=0
static var art_cache: Dictionary={}
func _ready() -> void:
	data=game.tower_display_data(kind);body=Sprite2D.new();body.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(body);refresh_art()
	var skin:=ArenaGrounding.material(game.level_id);body.material=skin;moving_part.material=skin
	var obstacle:=StaticBody2D.new();obstacle.collision_layer=1;obstacle.collision_mask=2
	var collision:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=25;collision.shape=circle;obstacle.add_child(collision);add_child(obstacle)
	var near: Dictionary=game.nearest_road(position)
	var anchor: Vector2=near.point
	var road: Curve2D=game.routes[near.route]
	var road_offset:=float(near.progress)
	if game.tower_lab and kind=="barracks":
		road_offset=maxf(0.0,road_offset-40.0)
		anchor=road.sample_baked(road_offset,true)
	if kind=="barracks":
		if game.stage_gimmicks!=null and game.stage_gimmicks.has_method("is_shoal_point") and game.stage_gimmicks.is_shoal_point(anchor):
			var dry: Dictionary=game.stage_gimmicks.nearest_dry_road(position)
			if not dry.is_empty():
				anchor=dry.point
				road=game.routes[int(dry.route)]
				road_offset=float(dry.progress)
		orient_rally(road,road_offset)
	rally_point=anchor
	if kind=="snare": attack_clock=SNARE_ARM_TIME
	if project_level==1:
		if use_v024_art: body.visible=false
		else: modulate.a=0.52
	if kind=="barracks" and project_level!=1:
		sync_troops()
func refresh_art() -> void:
	if ArenaBattleArt.has_v024_tower(kind, level, doctrine_id):
		use_v024_art = true
		var f_idx := clampi(_v024_frame, 0, 3)
		var tex := ArenaBattleArt.tower_frame_texture(kind, level, doctrine_id, f_idx)
		if tex != null:
			body.texture = tex
			body.centered = true
			body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var cell_sz := tex.get_size()
			var placement := ArenaBattleArt.contact(kind, level, cell_sz, doctrine_id)
			_v024_base_scale = placement.scale
			_part_base_scale = placement.scale
			body.scale = _v024_base_scale
			body.flip_h = _v024_flip
			body.offset = (Vector2(0.5, 0.5) - Vector2(placement.uv)) * cell_sz
			body.position = Vector2.ZERO
			body.rotation = 0.0
			body.visible = (project_level != 1)
			if moving_part == null:
				moving_part = Sprite2D.new()
				add_child(moving_part)
			moving_part.texture = null
			moving_part.visible = false
			moving_part.centered = false
			moving_part.scale = _v024_base_scale
			_last_pose_phase = -1
			var muv := ArenaBattleArt.tower_muzzle_uv(kind, level, doctrine_id)
			var sock_uv := Vector2(0.5, 0.42) if kind == "cannon" else (muv if kind == "barracks" else Vector2(muv.x - 0.06, muv.y))
			swivel = (sock_uv - Vector2(placement.uv)) * cell_sz * _v024_base_scale
			moving_part.offset = Vector2.ZERO
			moving_part.position = swivel
			if pivot_bed != null:
				pivot_bed.visible = false
			if kind == "archer":
				if ballista == null:
					ballista = Ballista.new()
					add_child(ballista)
				ballista.visible = false
				ballista.position = swivel
				ballista.tier = level
			elif ballista != null:
				ballista.visible = false
			if tower_fx == null:
				tower_fx = Node2D.new()
				add_child(tower_fx)
				tower_fx.draw.connect(_draw_tower_fx)
			tower_fx.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tower_fx.queue_redraw()
			_pose_mechanism()
			queue_redraw()
			return
	use_v024_art = false
	body.flip_h = false
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if ArenaBattleArt.TOWER_REGIONS.has(kind):
		var key: String=kind+str(level)
		if not art_cache.has(key):
			art_cache[key]=ArenaBattleArt.tower_texture(kind,level)
		if art_cache.has(key):
			body.texture=art_cache[key]
			var placement:=ArenaBattleArt.contact(kind,level,body.texture.get_size())
			body.scale=placement.scale;body.offset=(Vector2(0.5,0.5)-Vector2(placement.uv))*body.texture.get_size();body.position=Vector2.ZERO
			# Only a masked upper component moves. The feet/contact remain immobile.
			if moving_part==null:moving_part=Sprite2D.new();moving_part.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(moving_part)
			if ArenaBattleArt.TOWER_REGIONS.has(kind):
				if not moving_part.draw.is_connected(draw_mechanism): moving_part.draw.connect(draw_mechanism)
				moving_part.position=muzzle()-firing_position()
				return
	var placement := ArenaBattleArt.contact(kind,level,Vector2(512,512))
	var path := "res://assets/v017/tower_%s_%d" % [kind,level]
	var static_upper := kind in ["archer","barracks"]
	body.texture=load(path+(".png" if kind=="barracks" else "_base.png"))
	body.centered=true
	body.scale=placement.scale
	body.offset=Vector2(0,-224)
	# Early cannon and barracks atlas cells contain a sliver of the next building.
	var trim := 512
	if kind=="cannon" and level<3:
		trim = 432 if level==1 else 443
	elif kind=="barracks" and level<3:
		trim = 386 if level==1 else 432
	if trim<512:
		var cropped := AtlasTexture.new()
		cropped.atlas = body.texture
		cropped.region = Rect2(0,0,trim,512)
		cropped.margin = Rect2(0,0,512-trim,0)
		body.texture = cropped
	if moving_part==null:
		moving_part=Sprite2D.new()
		moving_part.texture_filter=body.texture_filter
		add_child(moving_part)
	moving_part.texture=null if static_upper else load(path+"_part.png")
	moving_part.centered=false
	moving_part.scale=placement.scale
	_part_base_scale=placement.scale
	_last_pose_phase=-1
	var socket: Vector2=SOCKETS[kind][level-1]
	swivel=(socket-Vector2(256,480))*body.scale
	moving_part.offset=-socket
	moving_part.position=swivel
	if kind=="cannon" and pivot_bed==null:
		pivot_bed=Node2D.new()
		add_child(pivot_bed)
		move_child(pivot_bed, body.get_index() + 1)
		pivot_bed.draw.connect(_draw_trunnion)
	if pivot_bed!=null:
		pivot_bed.position=swivel
		pivot_bed.queue_redraw()
	if kind=="archer":
		if ballista==null:
			ballista=Ballista.new()
			add_child(ballista)
		ballista.position=swivel
		ballista.tier=level
		ballista.queue_redraw()
	if tower_fx==null:
		tower_fx=Node2D.new()
		add_child(tower_fx)
		tower_fx.draw.connect(_draw_tower_fx)
	tower_fx.queue_redraw()
	queue_redraw()

func _draw_trunnion() -> void:
	var reduced := bool(game.campaign.data.reduced_motion) if (game!=null and game.campaign!=null) else false
	var amp := 0.3 if reduced else 1.0
	var prep := timing.prep_progress() * amp
	var rel := (1.0-timing.release_progress() if timing.phase==AttackTiming.Phase.RELEASE else 0.0) * amp
	var aim := visual_target.normalized()
	var sign_x := -1.0 if aim.x < 0.0 else 1.0
	var radius := 6.0 + level * 1.1
	# Compact side trunnion axle bearing tucked behind the mortar barrel
	pivot_bed.draw_set_transform(Vector2(-2.0 * sign_x, 6.0), 0.0, Vector2(1.15, 0.82))
	pivot_bed.draw_circle(Vector2.ZERO, radius + 1.5, Color("241c1a"), true, -1, true)
	pivot_bed.draw_circle(Vector2.ZERO, radius, Color("5a483c"), true, -1, true)
	pivot_bed.draw_circle(Vector2.ZERO, radius - 1.8, Color("c8934c"), true, -1, true)
	var gear_rot := (aim.angle() * 1.6 - prep * 0.45 + rel * 0.35) * sign_x
	for i in range(6):
		var pin := Vector2.RIGHT.rotated(gear_rot + i*TAU/6.0)*(radius-1.2)
		pivot_bed.draw_circle(pin, 1.0, Color("f2ca82"), true, -1, true)
	pivot_bed.draw_set_transform(Vector2.ZERO)

func _draw_tower_fx() -> void:
	if game == null or not game.started or destroyed or project_level == 1:
		return
	var reduced := bool(game.campaign.data.reduced_motion) if game.campaign != null else false
	var amp := 0.35 if reduced else 1.0
	var prep := timing.prep_progress() * amp
	var rel := (1.0 - timing.release_progress() if timing.phase == AttackTiming.Phase.RELEASE else 0.0) * amp
	var aim := visual_target.normalized()
	if use_v024_art:
		match kind:
			"mage", "storm", "lens":
				var muv := ArenaBattleArt.tower_muzzle_uv(kind, level, doctrine_id)
				if _v024_flip: muv.x = 1.0 - muv.x
				var core := (muv - Vector2(0.5, ArenaBattleArt.V024_FOOT_FRAC)) * ArenaBattleArt.V024_CELL * _v024_base_scale
				var p_col := Color("6ef0ff") if kind == "mage" else (Color("8ce8ff") if kind == "storm" else Color("ffe875"))
				if kind == "mage":
					if doctrine_id == "arcfire": p_col = Color("ff9238")
					elif doctrine_id == "breaker": p_col = Color("c682ff")
				var motes := 2 if reduced else 4
				for m_i in range(motes):
					var ma := visual_clock * (2.2 + 2.8 * prep) + float(m_i) * (TAU / float(motes))
					var mr := 11.0 + 3.0 * level + sin(visual_clock * 3.0 + float(m_i)) * 2.5 - 4.0 * prep
					var mp := (core + Vector2(cos(ma) * mr, sin(ma) * mr * 0.65)).snapped(Vector2(2, 2))
					tower_fx.draw_rect(Rect2(mp - Vector2(2, 2), Vector2(4, 4)), Color("14111b", 0.72))
					tower_fx.draw_rect(Rect2(mp - Vector2(1, 1), Vector2(2, 2)), p_col)
			"cannon":
				if fire_clock > 0.0:
					var fp := clampf(fire_clock / 0.16, 0.0, 1.0)
					var muz_l := muzzle() - global_position
					var dir_c := aim
					var perp_c := Vector2(-dir_c.y, dir_c.x)
					var c_len := (22.0 + 5.0 * float(level)) * (1.2 - 0.25 * fp)
					var c_w := (9.0 + 2.0 * float(level)) * fp
					tower_fx.draw_colored_polygon(PackedVector2Array([muz_l, muz_l + dir_c * c_len * 0.65 + perp_c * c_w, muz_l + dir_c * c_len, muz_l + dir_c * c_len * 0.65 - perp_c * c_w]), Color(1.0, 0.62, 0.22, 0.88 * fp))
					tower_fx.draw_colored_polygon(PackedVector2Array([muz_l, muz_l + dir_c * c_len * 0.45 + perp_c * c_w * 0.5, muz_l + dir_c * c_len * 0.72, muz_l + dir_c * c_len * 0.45 - perp_c * c_w * 0.5]), Color(1.0, 0.96, 0.76, 0.95 * fp))
			"barracks":
				var f_local := rally_point - position
				var flag_name := "flag_elite" if level >= 3 else "flag_std"
				var f_idx := int(floor(visual_clock * 4.5)) % 2
				var flag_tex := ArenaBattleArt.prop_frame_texture(flag_name, f_idx, 2)
				if flag_tex != null:
					tower_fx.draw_set_transform(f_local + Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
					tower_fx.draw_circle(Vector2.ZERO, 8.0, Color(0.08, 0.10, 0.08, 0.42))
					tower_fx.draw_set_transform(Vector2.ZERO)
					var fw := 34.0 if level < 3 else 38.0
					var fh := 34.0 if level < 3 else 38.0
					tower_fx.draw_texture_rect(flag_tex, Rect2(f_local + Vector2(-9.0, -fh + 4.0), Vector2(fw, fh)), false)
				if barrier_active_clock > 0.0:
					var bp := clampf(barrier_active_clock / 4.5, 0.0, 1.0)
					tower_fx.draw_set_transform(f_local, 0.0, Vector2(1.0, 0.55))
					tower_fx.draw_arc(Vector2.ZERO, 66.0, 0.0, TAU, 32, Color(0.45, 0.92, 1.0, 0.68 * bp), 3.0)
					tower_fx.draw_circle(Vector2.ZERO, 62.0, Color(0.32, 0.84, 1.0, 0.14 * bp))
					tower_fx.draw_set_transform(Vector2.ZERO)
		if jam_clock > 0.0:
			var jp := clampf(jam_clock / 0.8, 0.35, 1.0)
			var top_y := -48.0
			for k in range(5):
				var p_age := fmod(visual_clock * 0.9 + float(k) * 0.23, 1.0)
				var px_j := sin(visual_clock * 2.4 + float(k) * 1.9) * 14.0
				var py_j := top_y + 4.0 - p_age * 24.0
				var jp_pt := Vector2(px_j, py_j).snapped(Vector2(2, 2))
				var jc := Color(0.46, 0.86, 0.44, (1.0 - p_age) * 0.72 * jp) if k % 2 == 0 else Color(0.64, 0.38, 0.82, (1.0 - p_age) * 0.65 * jp)
				tower_fx.draw_rect(Rect2(jp_pt - Vector2(5, 4), Vector2(10, 8)), Color(0.12, 0.16, 0.10, (1.0 - p_age) * 0.55 * jp))
				tower_fx.draw_rect(Rect2(jp_pt - Vector2(4, 3), Vector2(8, 6)), jc)
		_draw_seal_fx()
		return

	match kind:
		"archer":
			# Foreground wooden railing beam occluding the lower waist of the dynamic archers so they stand *inside* the booth
			var rail_w: float = float([22.0, 34.0, 42.0][level - 1])
			var rail_y: float = float([6.5, 6.0, 5.5][level - 1])
			var rail_x: float = float([0.0, -7.0, 0.0][level - 1])
			var rail_c: Vector2 = swiv_offset(Vector2(rail_x, rail_y))
			tower_fx.draw_line(rail_c + Vector2(-rail_w, 1.5), rail_c + Vector2(rail_w, -1.0 if level < 3 else 1.5), Color("281910"), 5.2, true)
			tower_fx.draw_line(rail_c + Vector2(-rail_w, 1.2), rail_c + Vector2(rail_w, -1.3 if level < 3 else 1.2), Color("9d6332"), 3.0, true)
			tower_fx.draw_line(rail_c + Vector2(-rail_w, 0.2), rail_c + Vector2(rail_w, -2.2 if level < 3 else 0.2), Color("d59b58"), 1.2, true)
		"cannon":
			var sign_x := -1.0 if aim.x < 0.0 else 1.0
			# Live burning fuse & jumping sparks at the mortar breech
			var breech_world := moving_part.to_global(Vector2(-26.0, 18.0)) - global_position
			var fuse_tip := breech_world + Vector2(-7.0 * sign_x, -5.0 + sin(visual_clock * 14.0) * 1.5)
			tower_fx.draw_line(breech_world, fuse_tip, Color("3a2b22"), 2.4, true)
			var spark_sz := 2.4 + 2.8 * prep + 1.2 * absf(sin(visual_clock * 23.0))
			tower_fx.draw_circle(fuse_tip, spark_sz * 1.4, Color(1.0, 0.52, 0.14, 0.55 + 0.35 * prep))
			tower_fx.draw_circle(fuse_tip, spark_sz * 0.75, Color("fff6b8"))
			for s_i in range(3):
				var sa := visual_clock * 15.0 + float(s_i) * 2.1
				var sp := fuse_tip + Vector2(cos(sa), sin(sa)) * (3.0 + 5.0 * prep)
				tower_fx.draw_circle(sp, 1.2, Color("ffcf6e"))
			# Heavy directional muzzle blast cone & black-powder smoke ring on fire!
			if fire_clock > 0.0:
				var fp := clampf(fire_clock / 0.16, 0.0, 1.0)
				var muz_local := muzzle() - global_position
				var dir := aim
				var perp := Vector2(-dir.y, dir.x)
				var cone_len := (26.0 + 8.0 * level) * (1.3 - 0.3 * fp)
				var cone_w := (12.0 + 3.0 * level) * (1.2 - 0.2 * fp)
				tower_fx.draw_colored_polygon(PackedVector2Array([
					muz_local - dir * 3.0,
					muz_local + dir * cone_len * 0.65 + perp * cone_w,
					muz_local + dir * cone_len * 1.15,
					muz_local + dir * cone_len * 0.65 - perp * cone_w
				]), Color(1.0, 0.56, 0.16, 0.85 * fp))
				tower_fx.draw_colored_polygon(PackedVector2Array([
					muz_local,
					muz_local + dir * cone_len * 0.45 + perp * cone_w * 0.52,
					muz_local + dir * cone_len * 0.82,
					muz_local + dir * cone_len * 0.45 - perp * cone_w * 0.52
				]), Color(1.0, 0.96, 0.78, 0.95 * fp))
				tower_fx.draw_set_transform(muz_local + dir * 6.0, dir.angle(), Vector2(0.55, 1.15))
				tower_fx.draw_arc(Vector2.ZERO, (14.0 + 4.0 * level) * (1.35 - 0.35 * fp), 0.0, TAU, 24, Color(1.0, 0.86, 0.52, 0.82 * fp), 2.6, true)
				tower_fx.draw_set_transform(Vector2.ZERO)
		"mage":
			var orb_c := moving_part.position
			var spin := visual_clock * (1.8 + 3.2 * prep)
			var is_frost := doc_mod("slow_amount") > 0.0 or doc_mod("frost_stacks") > 0.0
			var core_col := Color("6ce8ff") if is_frost else Color("6ea4ff")
			var hi_col := Color("e8ffff") if is_frost else Color("eef6ff")
			var gold_col := Color("f0c66c")
			var gold_dark := Color("593e1c")

			# 1. Pulsing Arcane Orb Core & Outer Halo
			var orb_r: float = float([10.5, 12.5, 14.5][level - 1]) * (1.0 + 0.14 * prep + 0.18 * rel)
			tower_fx.draw_circle(orb_c, orb_r * 1.55, Color(core_col.r, core_col.g, core_col.b, 0.24 + 0.28 * prep))
			tower_fx.draw_circle(orb_c, orb_r * 0.92, Color(core_col.r, core_col.g, core_col.b, 0.55 + 0.32 * prep))
			tower_fx.draw_circle(orb_c + Vector2(-2.5, -2.5), orb_r * 0.45, Color(hi_col.r, hi_col.g, hi_col.b, 0.82))

			# 2. Counter-Rotating 3D Tilted Golden Astrolabe Rings (1..3 rings by tower level)
			for r_idx in range(level):
				var ring_ang: float = spin * (1.0 if r_idx % 2 == 0 else -1.25) + float(r_idx) * 1.05
				var ring_rad: float = orb_r + 4.5 + float(r_idx) * 3.8
				var tilt: float = 0.38 + 0.14 * sin(visual_clock * 1.5 + float(r_idx))
				tower_fx.draw_set_transform(orb_c, ring_ang, Vector2(1.0, tilt))
				tower_fx.draw_arc(Vector2.ZERO, ring_rad, 0.0, TAU, 32, gold_dark, 3.2, true)
				tower_fx.draw_arc(Vector2.ZERO, ring_rad, 0.0, TAU, 32, gold_col.lerp(hi_col, prep * 0.5), 1.7, true)
				for node_i in range(2):
					var np: Vector2 = Vector2.RIGHT.rotated(spin * 1.4 + float(node_i) * PI) * ring_rad
					tower_fx.draw_circle(np, 2.4, hi_col)
				tower_fx.draw_set_transform(Vector2.ZERO)

			# 3. Crackling Arcane Lightning Arcs from the bottom Wizard's raised hands up to the Orb
			var hands_y: float = float([13.0, 22.0, 20.0][level - 1])
			var hands_base: Vector2 = swivel + Vector2(0.0, hands_y)
			for side: float in [-1.0, 1.0]:
				var h_pt := hands_base + Vector2(side * 5.5, 0.0)
				tower_fx.draw_circle(h_pt, 2.8 + 2.0 * prep, Color(core_col.r, core_col.g, core_col.b, 0.65 + 0.3 * prep))
				var arc_pts := PackedVector2Array([h_pt])
				for step in range(1, 4):
					var u := float(step) / 4.0
					var jitter := sin(visual_clock * 19.0 + float(step) * 2.3 + side) * (3.2 + 3.5 * prep)
					arc_pts.append(h_pt.lerp(orb_c, u) + Vector2(jitter, 0.0))
				arc_pts.append(orb_c)
				tower_fx.draw_polyline(arc_pts, Color(core_col.r, core_col.g, core_col.b, 0.55 + 0.38 * prep), 2.2, true)
				tower_fx.draw_polyline(arc_pts, Color(hi_col.r, hi_col.g, hi_col.b, 0.72 + 0.25 * prep), 1.0, true)

			# 4. Converging Mana Wisps during windup (Prep) & Cast Pulse Ring on Release
			if prep > 0.04:
				for w_i in range(6):
					var wa := visual_clock * 5.5 + float(w_i) * (TAU / 6.0)
					var wr := (1.0 - prep) * (24.0 + 4.0 * float(level)) + 4.0
					var wp := orb_c + Vector2(cos(wa), sin(wa) * 0.75) * wr
					tower_fx.draw_line(wp, wp.lerp(orb_c, 0.35), Color(hi_col, prep * 0.85), 1.8, true)
					tower_fx.draw_circle(wp, 2.0, Color(hi_col, prep * 0.95))
			if fire_clock > 0.0:
				var fp := clampf(fire_clock / 0.13, 0.0, 1.0)
				tower_fx.draw_arc(orb_c, orb_r + (1.0 - fp) * 22.0, 0.0, TAU, 28, Color(hi_col, fp * 0.88), 2.4, true)
		"barracks":
			# 1. Warm interior doorway light when soldiers deploy/respawn
			if fire_clock > 0.0:
				var dp := clampf(fire_clock / 0.32, 0.0, 1.0)
				tower_fx.draw_set_transform(swivel + Vector2(0, -4), 0.0, Vector2(1.0, 0.65))
				tower_fx.draw_circle(Vector2.ZERO, 16.0 * dp, Color(1.0, 0.82, 0.42, 0.42 * dp))
				tower_fx.draw_set_transform(Vector2.ZERO)
			# 2. Planted Rally Point Standard Flag on the road
			var r_local := rally_point - position
			var wave := sin(visual_clock * 5.2 + float(site_id)) * 2.2
			tower_fx.draw_set_transform(r_local + Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
			tower_fx.draw_circle(Vector2.ZERO, 7.5, Color(0.08, 0.10, 0.08, 0.38))
			tower_fx.draw_set_transform(Vector2.ZERO)
			tower_fx.draw_line(r_local + Vector2(0, 2), r_local + Vector2(0, -22), Color("2b1e16"), 3.2, true)
			tower_fx.draw_line(r_local + Vector2(0, 2), r_local + Vector2(0, -22), Color("c89d54"), 1.6, true)
			var banner := PackedVector2Array([
				r_local + Vector2(1, -21),
				r_local + Vector2(14 + wave * 0.5, -18 + wave * 0.4),
				r_local + Vector2(11 + wave, -13 + wave * 0.5),
				r_local + Vector2(15 + wave * 0.7, -9 + wave * 0.3),
				r_local + Vector2(1, -11)
			])
			tower_fx.draw_colored_polygon(banner, Color("b8382c") if level < 3 else Color("2f68a8"))
			tower_fx.draw_polyline(banner, Color("f2cf76"), 1.3, true)
			tower_fx.draw_circle(r_local + Vector2(0, -23), 2.2, Color("f5d77f"))
	if jam_clock > 0.0:
		var jp := clampf(jam_clock / 0.8, 0.35, 1.0)
		var top_y := -48.0 if kind == "archer" else (-44.0 if kind == "mage" else -36.0)
		for k in range(5):
			var p_age := fmod(visual_clock * 0.9 + float(k) * 0.23, 1.0)
			var px_j := sin(visual_clock * 2.4 + float(k) * 1.9) * 14.0
			var py_j := top_y + 4.0 - p_age * 24.0
			var jp_pt := Vector2(px_j, py_j).snapped(Vector2(2, 2))
			var jc := Color(0.46, 0.86, 0.44, (1.0 - p_age) * 0.72 * jp) if k % 2 == 0 else Color(0.64, 0.38, 0.82, (1.0 - p_age) * 0.65 * jp)
			tower_fx.draw_rect(Rect2(jp_pt - Vector2(5, 4), Vector2(10, 8)), Color(0.12, 0.16, 0.10, (1.0 - p_age) * 0.55 * jp))
			tower_fx.draw_rect(Rect2(jp_pt - Vector2(4, 3), Vector2(8, 6)), jc)
		for row in range(2):
			var cy := top_y - 4.0 + float(row) * 5.0
			tower_fx.draw_polyline(PackedVector2Array([Vector2(-5, cy), Vector2(0, cy + 4.0), Vector2(5, cy)]), Color(0.86, 1.0, 0.56, 0.85 * jp), 1.8, true)
	_draw_seal_fx()

func _draw_seal_fx() -> void:
	if tower_fx == null:
		return
	if seal_telegraph > 0.0:
		var pulse := 0.55 + 0.45 * sin(visual_clock * 11.0)
		for b_i in range(9):
			var ang := float(b_i) * (TAU / 9.0) + visual_clock * 1.9
			var rx := cos(ang) * (28.0 + sin(visual_clock * 4.0 + float(b_i)) * 4.0)
			var ry := sin(ang) * 13.0 + 4.0 - fmod(visual_clock * 1.5 + float(b_i) * 0.17, 1.0) * 22.0
			var b_pt := Vector2(rx, ry).snapped(Vector2(2, 2))
			tower_fx.draw_rect(Rect2(b_pt - Vector2(4, 4), Vector2(8, 8)), Color("0d1c28", 0.90 * pulse))
			tower_fx.draw_rect(Rect2(b_pt - Vector2(2, 2), Vector2(4, 4)), Color("64f4ff", 0.95 * pulse) if b_i % 2 == 0 else Color("2894a4", 0.92 * pulse))
		var tip_p := Vector2(0, -18.0 - 8.0 * sin(visual_clock * 9.0)).snapped(Vector2(2, 2))
		tower_fx.draw_rect(Rect2(tip_p - Vector2(6, 6), Vector2(12, 12)), Color("0f1824", 0.92))
		tower_fx.draw_rect(Rect2(tip_p - Vector2(4, 4), Vector2(8, 8)), Color("ff7a8a", 0.96 * pulse))
	if seal_clock > 0.0:
		var top_h := -84.0 if kind in ["archer", "mage"] else -68.0
		var sway := sin(visual_clock * 4.8) * 4.5
		# Bold pixel kraken tentacles spiralling all the way up the locked tower
		var arm_defs := [
			[Vector2(-28, 8), Vector2(-34 + sway * 0.7, -20), Vector2(22 + sway, -42), Vector2(-18 + sway * 0.6, top_h * 0.78), Vector2(8 + sway * 0.4, top_h)],
			[Vector2(28, 8), Vector2(32 - sway * 0.6, -16), Vector2(-24 - sway, -46), Vector2(18 - sway * 0.5, top_h * 0.85), Vector2(-12 - sway * 0.3, top_h * 0.96)],
			[Vector2(0, 12), Vector2(-20 + sway * 0.5, -10), Vector2(26 - sway * 0.5, -28), Vector2(-6 + sway * 0.4, top_h * 0.62)]
		]
		for a_idx in range(arm_defs.size()):
			var pts: Array = arm_defs[a_idx]
			for s_i in range(pts.size() - 1):
				var p0: Vector2 = pts[s_i]
				var p1: Vector2 = pts[s_i + 1]
				var seg_col := Color("123b47") if a_idx == 2 else Color("1b5c68")
				var mid_col := Color("4ae4d6") if s_i % 2 == 0 else Color("289aa6")
				tower_fx.draw_line(p0, p1, Color("071018"), 11.0)
				tower_fx.draw_line(p0, p1, seg_col, 7.2)
				tower_fx.draw_line(p0, p1, mid_col, 3.6)
				var mid_pt := p0.lerp(p1, 0.5).snapped(Vector2(2, 2))
				tower_fx.draw_rect(Rect2(mid_pt - Vector2(3, 3), Vector2(6, 6)), Color("071018"))
				tower_fx.draw_rect(Rect2(mid_pt - Vector2(2, 2), Vector2(4, 4)), Color("ff74ba") if s_i % 2 == 1 else Color("8cffea"))
			var tip_t: Vector2 = Vector2(pts[pts.size() - 1]).snapped(Vector2(2, 2))
			tower_fx.draw_rect(Rect2(tip_t - Vector2(4, 4), Vector2(8, 8)), Color("071018"))
			tower_fx.draw_rect(Rect2(tip_t - Vector2(2, 2), Vector2(4, 4)), Color("7cf8e8"))
		# Crown seal sigil clearly marking locked tower above roof
		var crest := Vector2(0, top_h - 12.0).snapped(Vector2(2, 2))
		tower_fx.draw_rect(Rect2(crest - Vector2(10, 7), Vector2(20, 14)), Color("08111a", 0.94))
		tower_fx.draw_rect(Rect2(crest - Vector2(8, 5), Vector2(16, 10)), Color("267e8c"))
		tower_fx.draw_rect(Rect2(crest - Vector2(3, 3), Vector2(6, 6)), Color("ff7ea8"))

func swiv_offset(delta_px: Vector2) -> Vector2:
	return swivel + delta_px

func site_trait() -> String:
	if game==null or game.level_definition.is_empty():return ""
	var traits: Array=game.level_definition.get("site_traits",[])
	if site_id>=0 and site_id<traits.size():return str(traits[site_id])
	return ""
static func trait_label(trait_id: String) -> String:
	return {"highground":"高台","choke":"隘口","conduit":"脉座"}.get(trait_id,"")
static func trait_summary(trait_id: String) -> String:
	return {"highground":"射程 +18%","choke":"士兵生命 +18% · 补员速度 +25%","conduit":"攻速 +14% · 穿透 +12 个百分点"}.get(trait_id,"")
func soldier_respawn_scale() -> float:
	return (1.25 if site_trait()=="choke" and not game.tower_lab else 1.0) + doc_mod("respawn_speed")
func upgrade_price() -> int:
	if level == MAX_LEVEL:
		if unlocked_enhancements < enhancements().size():
			return ArenaDoctrines.ENHANCEMENT_PRICES[unlocked_enhancements]
		return 0
	if game.tower_lab: return roundi(float(data.cost)*(1.6 if level==1 else 2.4))
	return int(data.cost)*(level+1)/2+35
static func field_range(data: Dictionary, tier: int) -> float:
	return float(data.reach)+(tier-1)*16.0
static func field_power(data: Dictionary, tier: int) -> float:
	return float(data.damage)*(1.0+0.18*(tier-1))*0.25
static func field_cycle(data: Dictionary, tier: int) -> float:
	return float(data.interval)/(1.0+0.14*(tier-1))
func attack_range() -> float:
	var trait_range:=1.18 if site_trait()=="highground" else 1.0
	if game.tower_lab: return trial_stat("reach")*trait_range
	return field_range(data,level)*doc_mod("range_mult",1.0)*trait_range
func reload_time() -> float:
	var trait_speed: float=0.14 if site_trait()=="conduit" else 0.0
	if game.tower_lab: return trial_stat("cycle")/(1.0+trait_speed)
	var healer_speed: float=game.hero.healer_tower_speed_bonus(position) if game.hero!=null and game.hero.has_method("healer_tower_speed_bonus") else 0.0
	var passive_speed: float=game.passive_engine.tower_speed_bonus() if (game!=null and game.passive_engine!=null) else 0.0
	var relic_speed: float=game.relic_engine.tower_speed_bonus() if (game!=null and game.relic_engine!=null) else 0.0
	var overdrive_speed: float=ArenaGame.FORGE_OVERDRIVE_SPEED if (game!=null and game.core_overdrive_clock>0.0) else 0.0
	var jam_factor: float = 1.0 / maxf(0.45, 1.0 - jam_slow) if jam_clock > 0.0 else 1.0
	return field_cycle(data,level)*doc_mod("interval_mult",1.0)/(1.0+trait_speed+healer_speed+passive_speed+relic_speed+overdrive_speed)*jam_factor
func trial_stat(key: String) -> float: return ArenaTowerTrial.stat(kind,key,level)
func trial_arrow_range() -> float: return maxf(ArenaTowerTrial.ARCHER_FLIGHT,attack_range())
func trial_frost_inner() -> float: return attack_range()*ArenaTowerTrial.FROST_INNER_RATIO
func trial_shell_core() -> float: return splash_radius()*ArenaTowerTrial.SHELL_CORE_RATIO
func shot_power() -> float: return base_power()
func base_power() -> float:
	if game.tower_lab: return trial_stat("power")
	var p_mult: float = game.passive_engine.tower_power_mult(position) if (game != null and game.passive_engine != null) else 1.0
	var r_mult: float = game.relic_engine.tower_power_mult() if (game != null and game.relic_engine != null) else 1.0
	return field_power(data,level)*p_mult*r_mult
func splash_radius() -> float:
	if game.tower_lab and kind=="cannon": return trial_stat("splash")
	var radius:=trial_stat("splash") if game.defense_rules and kind=="cannon" else float(64+(level-1)*12)
	var r_spl: float = game.relic_engine.tower_splash_mult() if (game != null and game.relic_engine != null) else 1.0
	return radius*doc_mod("splash_mult",1.0)*r_spl
func doc_mod(key: String,fallback := 0.0) -> float:
	var trait_bonus: float=0.18 if (key=="soldier_health" and kind=="barracks" and site_trait()=="choke") else 0.0
	if doctrine_data.is_empty():return fallback+trait_bonus
	var effects: Dictionary=doctrine_data.get("effects",{})
	var base := float(effects.get(key, fallback)) + float(enhancement_mods.get(key, 0.0))
	if key=="interval_mult":return maxf(0.25,base)
	if key=="frost_stacks":return maxf(1.0,base) if effects.has(key) or base>0.0 else base
	return base+trait_bonus
func enhancements() -> Array:
	return ArenaDoctrines.enhancements(doctrine_id)
func _complete_enhancement() -> void:
	var entry: Dictionary = enhancements()[unlocked_enhancements]
	var delta: Dictionary = entry.delta
	for key in delta:
		enhancement_mods[key] = float(enhancement_mods.get(key, 0.0)) + float(delta[key])
	unlocked_enhancements += 1
	if kind == "barracks":
		sync_troops()
	queue_redraw()
	game.effect(position,62.0,Color("7ef2ff"),"upgrade",0.55)
	game.numbers.append({"point":position + Vector2(0,-52),"text":str(entry.name),"colour":Color("ffe678"),"life":0.9,"duration":0.9})
	game.audio.play("tower",-12,1.18)
	if is_instance_valid(game.hud) and game.selected_site == site_id:
		game.hud.refresh_context()

func forced_target() -> String: return str(doctrine_data.get("effects",{}).get("target",""))
func penetration() -> float:
	var trait_pen: float=0.12 if site_trait()=="conduit" else 0.0
	return (doc_mod("armour_pen") if int(data.type)==0 else doc_mod("resist_pen"))+trait_pen
func doctrine_multiplier(enemy: Node2D) -> float:
	var result:=doc_mod("damage_mult",1.0)
	if doc_mod("bonus_armour")>0.0 and float(enemy.data.armour)>=ArenaDoctrines.HEAVY_ARMOUR:result*=1.0+doc_mod("bonus_armour")
	if doc_mod("bonus_resist")>0.0 and float(enemy.data.resistance)>=ArenaDoctrines.HIGH_RESIST:result*=1.0+doc_mod("bonus_resist")
	if doc_mod("bonus_elite")>0.0 and (enemy.elite or enemy.is_boss() or (enemy.has_method("is_mini_boss") and enemy.is_mini_boss())):result*=1.0+doc_mod("bonus_elite")
	return result
func upgrade(doctrine := "") -> bool:
	if destroyed or project_level != 0 or is_sealed() or not game.can_change_towers() or game.get_tree().paused:
		return false
	if level == MAX_LEVEL and not doctrine.is_empty():
		return false
	var price := upgrade_price()
	if price == 0 or game.gold < price:
		return false
	var next_stage := level+1 if level < MAX_LEVEL else MAX_LEVEL+unlocked_enhancements+1
	start_project(next_stage, price)
	project_doctrine = doctrine
	game.gold -= price
	queue_redraw()
	if not game.timed_tower_work():
		finish_project()
	elif is_instance_valid(game.hud) and game.selected_site == site_id:
		game.hud.refresh_context()
	return true

func _prepare_doctrine(doctrine: String) -> void:
	if level != 3 or not doctrine_id.is_empty() or game.tower_lab:
		return
	if not doctrine.is_empty() and _apply_doctrine(doctrine):
		return
	_apply_doctrine(game.run_tower_doctrines.get(kind, ArenaDoctrines.AUTO_DEFAULT[kind]))

func _complete_upgrade(doctrine: String) -> void:
	_prepare_doctrine(doctrine)
	for soldier in troops:
		if is_instance_valid(soldier):soldier.refresh_stats()
	game.effect(position,65,Color("f4d28b"),"upgrade",0.55);game.audio.play("tower")
	if is_instance_valid(game.hud) and game.selected_site == site_id:
		game.hud.refresh_context()

func start_construction(cost: int) -> void:
	start_project(1,cost)

func start_project(next_level: int,cost: int) -> void:
	project_level=next_level
	project_clock=ArenaTowerTrial.BUILD_TIME
	project_gold=cost

func cancel_project() -> bool:
	if destroyed or is_sealed() or project_level==0 or not game.can_manage_defense(): return false
	var was_building:=project_level==1
	if not was_building and not game.tower_lab:
		return false
	game.gold+=project_gold
	project_level=0
	project_clock=0.0
	project_gold=0
	project_doctrine=""
	if was_building: retire()
	else: game.hud.refresh_context()
	return true

func finish_project() -> void:
	if project_level==0: return
	var completed_stage := project_level
	var was_building := completed_stage == 1
	var doctrine := project_doctrine
	invested_gold+=project_gold
	project_level=0
	project_clock=0.0
	project_gold=0
	project_doctrine=""
	if completed_stage > MAX_LEVEL:
		_complete_enhancement()
		return
	level = completed_stage
	modulate.a=1.0
	if is_instance_valid(body): body.visible=true
	if not was_building or use_v024_art: refresh_art()
	if kind=="barracks": sync_troops()
	if not was_building and not game.tower_lab:
		_complete_upgrade(doctrine)
		return
	game.effect(position,46,Color("e1c68e"),"upgrade",0.42)
	game.audio.play("tower",-6)
	if game.selected_site==site_id: game.hud.refresh_context()
func _apply_doctrine(id: String) -> bool:
	var entry: Dictionary=ArenaDoctrines.by_id(id)
	if entry.is_empty() or str(entry.tower)!=kind or doctrine_id!="":return false
	doctrine_id=id;doctrine_data=entry
	var forced:=str(entry.effects.get("target",""))
	if forced!="":target_mode=forced
	if kind=="barracks":
		sync_troops()
		for soldier in troops:
			if is_instance_valid(soldier) and soldier.has_method("refresh_visual"):
				soldier.refresh_visual()
	refresh_art()
	return true
func sync_troops() -> void:
	if kind!="barracks":return
	troops=troops.filter(func(soldier):return is_instance_valid(soldier))
	var target:=maxi(1,int(doc_mod("soldier_count",3)))
	while troops.size()>target:
		var soldier: ArenaSoldier=troops.pop_back()
		game.blocking.release(soldier);game.soldiers.erase(soldier);soldier.queue_free()
	while troops.size()<target:
		var soldier:=ArenaSoldier.new();soldier.game=game;soldier.tower=self
		soldier.position=position if game.tower_lab else rally_point
		soldier.redeploying=game.tower_lab
		game.actors.add_child(soldier);game.soldiers.append(soldier);troops.append(soldier)
	for index in range(troops.size()):troops[index].slot=index
	for soldier in troops:soldier.refresh_stats()
func sell() -> bool:
	if destroyed or is_sealed() or not game.can_sell_towers() or project_level!=0:return false
	game.gold+=sale_value()
	retire()
	return true

func sale_value() -> int:
	return floori(float(invested_gold) * SALE_REFUND_RATIO)

func retire() -> void:
	destroyed=true
	for soldier in troops:
		if is_instance_valid(soldier):game.blocking.release(soldier);game.soldiers.erase(soldier);soldier.queue_free()
	game.towers.erase(self);game.rebuild_navigation();queue_free();game.hud.close_context()
func set_rally(point: Vector2) -> bool:
	if kind not in ["barracks","snare"] or destroyed or is_sealed() or project_level==1 or not game.can_manage_defense():return false
	var destination := order_preview(point)
	if not destination.is_finite(): return false
	if rally_point.distance_to(destination)<1.0: return true
	if kind=="snare":
		rally_point=destination
		attack_clock=maxf(attack_clock,SNARE_ARM_TIME)
		queue_redraw()
		return true
	var closest: Dictionary=game.nearest_road(destination)
	orient_rally(game.routes[closest.route],closest.progress)
	for soldier: ArenaSoldier in troops: soldier.redeploy()
	rally_point=destination
	if tower_fx!=null: tower_fx.queue_redraw()
	game.effect(rally_point,25,Color("e9c37e"),"flag",0.5);return true

func orient_rally(road: Curve2D,progress: float) -> void:
	var ahead:=road.sample_baked(minf(road.get_baked_length(),progress+8.0),true)
	var behind:=road.sample_baked(maxf(0.0,progress-8.0),true)
	rally_across=behind.direction_to(ahead).orthogonal()

func rally_slot(slot: int) -> Vector2:
	return rally_point+rally_across*(float(slot)-1.0)*22.0

func ground_order_range() -> float:
	return float(data.reach) if kind=="barracks" and not game.tower_lab and not game.defense_rules else attack_range()

func order_preview(point: Vector2) -> Vector2:
	if project_level==1 or not point.is_finite(): return Vector2.INF
	if kind=="cannon":
		return point if Rect2(Vector2.ZERO,game.world_size()).has_point(point) and position.distance_to(point)<=attack_range() else Vector2.INF
	if kind not in ["barracks","snare"]: return Vector2.INF
	var nearby: Dictionary=game.nearest_road(point)
	if (game.tower_lab or kind=="snare") and point.distance_to(nearby.point)>ArenaTowerTrial.RALLY_CLICK_DISTANCE: return Vector2.INF
	if game.stage_gimmicks!=null and game.stage_gimmicks.has_method("is_shoal_point") and game.stage_gimmicks.is_shoal_point(nearby.point): return Vector2.INF
	if position.distance_to(nearby.point)>ground_order_range(): return Vector2.INF
	return nearby.point

func can_set_bombard() -> bool:
	return kind=="cannon" and game.tower_lab

func set_bombard(point: Vector2) -> bool:
	if not can_set_bombard() or destroyed or is_sealed() or not game.can_manage_defense(): return false
	var preview:=order_preview(point)
	if not preview.is_finite(): return false
	if bombard_point.is_finite() and bombard_point.distance_squared_to(preview)<1.0: return true
	bombard_point=preview
	game.audio.play("tower",-18)
	queue_redraw()
	return true

func clear_bombard() -> void:
	if not can_set_bombard() or destroyed or is_sealed() or not game.can_manage_defense(): return
	bombard_point=Vector2.INF
	queue_redraw()
	game.hud.refresh_context()

func firing_position() -> Vector2:
	return position

func destination_flag() -> Vector2:
	return rally_point

func destination_across() -> Vector2:
	return rally_across

func windup_aim(enemy: ArenaEnemy,prep: float) -> Vector2:
	if not game.defense_rules or kind!="cannon": return enemy.center()
	if bombard_point.is_finite(): return bombard_point
	var origin:=muzzle()
	var point:=enemy.position
	var flight:=0.38
	var forecast:=point+enemy.travel_velocity()*(prep+flight)
	if not order_preview(forecast).is_finite(): return point
	return forecast

func _physics_process(delta: float) -> void:
	if not game.running or game.game_over or destroyed:return
	if project_level!=0:
		project_clock=maxf(0.0,project_clock-delta)
		queue_redraw()
		if project_clock<=0.0: finish_project()
		if project_level==1:
			return
	attack_clock=maxf(0,attack_clock-delta);fire_clock=maxf(0,fire_clock-delta)
	jam_clock=maxf(0.0,jam_clock-delta)
	if jam_clock<=0.0:jam_slow=0.0
	if seal_telegraph>0.0:
		seal_telegraph=maxf(0.0,seal_telegraph-delta)
		if seal_telegraph<=0.0:
			seal_clock=maxf(seal_clock,_pending_seal_dur if _pending_seal_dur>0.0 else 7.5)
			_pending_seal_dur=0.0
			timing.cancel()
			focus_target=null
			focus_layers=0
			game.effect(position,54,Color("48d4ce"),"abyss_burst",0.6)
			_sync_tower_draw()
			if game.hud!=null and game.selected_site==site_id:
				game.hud.refresh_context()
	if seal_clock>0.0:
		seal_clock=maxf(0.0,seal_clock-delta)
		timing.cancel()
		focus_target=null
		focus_layers=0
		_sync_tower_draw()
		if seal_clock<=0.0 and game.hud!=null and game.selected_site==site_id:
			game.hud.refresh_context()
		return
	if kind=="barracks":
		if not game.tower_lab:
			var barrier_radius := doc_mod("barrier_radius",68.0)
			barrier_active_clock=maxf(0.0,barrier_active_clock-delta)
			barrier_clock-=delta
			if barrier_clock<=0.0:
				barrier_clock=9.0
				barrier_active_clock=doc_mod("barrier_duration",4.5)
				game.effect(rally_point,barrier_radius,Color("6cf2ff"),"upgrade",0.45)
			if barrier_active_clock>0.0:
				for enemy in game.domain_enemies("defense"):
					if is_instance_valid(enemy) and not enemy.dead and not enemy.is_flying() and enemy.position.distance_squared_to(rally_point)<=barrier_radius*barrier_radius:
						enemy.chill(0.42,0.5)
		if game.tower_lab and game.selected_site==site_id: queue_redraw()
		else: _sync_tower_draw()
		return
	if kind=="snare":
		if attack_clock<=0.0:
			if not game.tower_lab:
				_auto_aim_snare()
			try_snare()
		queue_redraw()
		return
	if kind=="lens" and (not is_instance_valid(focus_target) or not game.trial_tower_can_hit(focus_target) or position.distance_to(focus_target.position)>attack_range()):
		focus_target=null
		focus_layers=0
	if game.tower_lab:
		trial_attack(delta)
		return
	if not game.tower_lab and kind=="mage":
		if attack_clock<=0.0 and fire_trial_pulse(shot_power()):
			attack_clock=reload_time()
		_sync_tower_draw()
		return
	if timing.is_preparing():
		var cand: Node2D=timing.target
		var locked_aim: bool=game.defense_rules and kind=="cannon"
		var valid: bool=is_instance_valid(cand) and not cand.dead and firing_position().is_finite() and (locked_aim or firing_position().distance_to(cand.position)<=attack_range()+18.0)
		if valid and bombard_point.is_finite() and not locked_aim: valid=cand.position.distance_to(bombard_point)<=splash_radius()
		if not valid:
			cand=game.tower_target(self)
			if cand!=null:
				timing.target=cand;timing.target_point=windup_aim(cand,0.0)
				visual_target=muzzle().direction_to(timing.target_point)
			else:
				timing.cancel();attack_clock=0.06
				body.rotation=0.0;_sync_tower_draw();return
		elif not locked_aim:
			visual_target=(cand.center()-position).normalized()
		if timing.step(delta):
			var shot_target: Node2D=timing.target
			if is_instance_valid(shot_target) and not shot_target.dead:
				attack_clock=timing.post_cooldown
				_fire_at(shot_target)
			else:
				timing.cancel();attack_clock=0.06
	else:
		timing.step(delta)
		if attack_clock<=0:
			var enemy: Node2D=game.tower_target(self)
			if enemy!=null:
				var cycle: float=reload_time()
				var prep_s: float=minf(0.30,cycle*0.24) if kind=="cannon" else (minf(0.22,cycle*0.22) if kind=="mage" else minf(0.14,cycle*0.20))
				var rel_s: float=0.09 if kind=="cannon" else 0.07
				var rec_s: float=0.30 if kind=="cannon" else 0.16
				var aim:=windup_aim(enemy,prep_s)
				visual_target=muzzle().direction_to(aim)
				timing.begin(cycle,prep_s,rel_s,rec_s,enemy,aim)
	# The foundation stays planted. Firing feedback belongs at the articulated upper mechanism, not the base.
	body.rotation=0.0
	if game.defense_rules and kind=="cannon": queue_redraw()
	else: _sync_tower_draw()
func _auto_aim_snare() -> void:
	var best: ArenaEnemy = game.tower_target(self)
	if is_instance_valid(best) and not best.is_flying():
		var nr: Dictionary = game.nearest_road(best.position)
		if position.distance_to(Vector2(nr.point)) <= attack_range():
			rally_point = Vector2(nr.point)
func _fire_at(enemy: Node2D, bonus:=false) -> void:
	if not game.defense_rules or bonus or kind!="cannon":
		visual_target=muzzle().direction_to(enemy.center())
	if not ArenaBattleArt.TOWER_REGIONS.has(kind): _pose_mechanism()
	_trigger_v024_punch()
	if game != null and game.event_bus != null:
		game.event_bus.emit_event("tower_fire", {"tower": self, "target": enemy})
	var aura: float=game.hero.command_aura(position) if game.hero!=null and game.hero.has_method("command_aura") and game.hero.domain=="defense" else 0.0
	var power: float=shot_power()
	power*=1.0+aura
	if not (game.tower_lab and kind == "mage" and doctrine_id != "breaker"):
		power *= doctrine_multiplier(enemy)
	var aim:=timing.target_point if game.defense_rules and kind=="cannon" and not bonus and timing.phase==AttackTiming.Phase.RELEASE else Vector2.INF
	match kind:
		"cannon": fire_cannon(enemy,power,aim)
		"storm": fire_chain(enemy,power)
		"lens": fire_lens(enemy,power)
		"snare":
			if not game.tower_lab:
				_auto_aim_snare()
			try_snare()
		"mage":
			if game.tower_lab and doctrine_id!="breaker":
				fire_trial_pulse(power)
			else: fire_shots(enemy,power)
		_: fire_shots(enemy,power,aim)
	fire_clock=0.16 if kind=="cannon" else 0.13
	if tower_fx!=null: tower_fx.queue_redraw()
	game.audio.play({"archer":"ranger_release","mage":"mage_cast","cannon":"explode"}.get(kind,"tower"),-17)
func trigger_bonus_salvo() -> bool:
	if destroyed or kind=="barracks" or project_level==1:return false
	if kind=="snare": return attack_clock<=0.0 and try_snare()
	if game.tower_lab:
		if kind=="mage": return fire_trial_pulse()
		var aim:=plan_trial_attack(0.0)
		if aim.is_empty(): return false
		fire_trial(aim.point)
		return true
	if kind=="mage":
		return fire_trial_pulse()
	var enemy: Node2D = game.tower_target(self)
	if enemy==null:
		return false
	_fire_at(enemy,true)
	return true

func trial_attack(delta: float) -> void:
	if kind=="mage":
		if attack_clock<=0.0 and fire_trial_pulse(): attack_clock=reload_time()
		_sync_tower_draw()
		return
	if timing.is_preparing():
		if timing.step(delta):
			attack_clock=timing.post_cooldown
			fire_trial(timing.target_point,true)
	else:
		timing.step(delta)
		if attack_clock<=0.0:
			var prep:=trial_stat("prep")*reload_time()/trial_stat("cycle")
			var aim:=plan_trial_attack(prep)
			if not aim.is_empty():
				var point: Vector2=aim.point
				visual_target=muzzle().direction_to(point)
				timing.begin(reload_time(),prep,0.06,trial_stat("recovery") if kind=="archer" else 0.30,aim.target,point)
	queue_redraw()

func plan_trial_attack(prep: float) -> Dictionary:
	var targets: Array[ArenaEnemy]=game.trial_tower_targets(self)
	var forecast: Array[Dictionary]=[]
	var origin:=muzzle()
	for enemy in targets:
		var point:=enemy.center() if kind=="archer" else enemy.position
		var flight:=origin.distance_to(point)/trial_stat("speed") if kind=="archer" else trial_stat("flight")
		forecast.append({"enemy":enemy,"point":point+enemy.travel_velocity()*(prep+flight)})
	if kind=="cannon" and bombard_point.is_finite():
		for row in forecast:
			if bombard_point.distance_squared_to(row.point)<=pow(trial_shell_core(),2.0):
				return {"point":bombard_point,"target":row.enemy}
		return {}
	var best: Dictionary={}
	var best_score:=-INF
	var best_priority:=-INF
	var best_remaining:=INF
	for candidate in forecast:
		var target: ArenaEnemy=candidate.enemy
		var point: Vector2=candidate.point
		if kind=="cannon" and not order_preview(point).is_finite(): continue
		var score:=line_coverage(origin,point,forecast) if kind=="archer" else blast_coverage(point,forecast)
		if score<=0.0: continue
		var priority:=target.health if kind=="archer" else 0.0
		var remaining: float=game.enemy_road(target).get_baked_length()-target.progress
		if score>best_score or (score==best_score and (priority>best_priority or (priority==best_priority and remaining<best_remaining))):
			best={"point":point,"target":target}
			best_score=score
			best_priority=priority
			best_remaining=remaining
	return best

func line_coverage(origin: Vector2,point: Vector2,forecast: Array[Dictionary]) -> float:
	var direction:=origin.direction_to(point)
	if direction.is_zero_approx(): return 0.0
	var count:=0
	var maximum:=5 if level==3 else 4
	var distance:=trial_arrow_range()
	for row in forecast:
		if is_inf(ArenaTowerTrial.arrow_contact(origin,direction,distance,row.point,row.enemy.radius+4.0)): continue
		count+=1
		if count==maximum: break
	return float(count)

func blast_coverage(point: Vector2,forecast: Array[Dictionary]) -> float:
	var score:=0.0
	var outer:=splash_radius()
	var center:=trial_shell_core()
	for row in forecast:
		var distance:=point.distance_to(row.point)
		if distance>outer: continue
		score+=lerpf(1.0,0.5,distance/outer)+(0.75 if distance<=center else 0.0)
	return score

func fire_trial(aim: Vector2,locked_ray:=false) -> void:
	var origin:=muzzle()
	var power:=shot_power()
	if kind=="archer":
		var direction:=visual_target if locked_ray else origin.direction_to(aim)
		game.fire_projectile(origin,origin+direction,power,ArenaCombat.Type.PHYSICAL,"tower",{
			"tower":self,"speed":trial_stat("speed"),"pen":penetration(),
			"tower_kind":kind,"tower_level":level,"doctrine_id":doctrine_id,"feedback":"tower_arrow",
			"trial_pierce_scales":ArenaTowerTrial.arrow_scales(level),"trial_flight_left":trial_arrow_range()})
		game.tower_trial_stats.arrows+=1
	else:
		var time:=trial_stat("flight")
		game.delayed_attack(aim,splash_radius(),power,ArenaCombat.Type.PHYSICAL,"tower",time,{
			"origin":origin,"cannon":true,"cannon_tier":level,"feedback":"shell","doctrine_id":doctrine_id,"pen":penetration(),"stun":trial_stat("stun"),
			"tower_trial_shell":trial_stat("push"),"core_radius":trial_shell_core()})
	game.effect(origin,12,Color("e8c690"),"hit",0.15)
	fire_clock=0.13
	_trigger_v024_punch()
	game.audio.play("tower",-16)

func focus_order_id() -> int:
	return 0

func fire_chain(first: ArenaEnemy,power: float) -> void:
	var current:=first
	var origin:=muzzle()
	var struck: Array[ArenaEnemy]=[]
	var reach:=doc_mod("chain_reach",120.0)
	var retention := doc_mod("chain_retention",0.72)
	var arc_kind := "tower_arc" if doctrine_id.is_empty() else "tower_arc_" + doctrine_id
	var hops := int(doc_mod("chain_count", 4)) if not game.tower_lab else int(doc_mod("chain_count", 3))
	for hop in hops:
		if current==null: break
		var end:=current.center()
		struck.append(current)
		game.effect(origin,origin.distance_to(end),data.colour,arc_kind,0.24,origin.direction_to(end),{"hop":hop,"doctrine":doctrine_id})
		game.effect(end,18.0 + (4.0 if doctrine_id=="surge" else 0.0),data.colour,"storm_hit",0.20,origin.direction_to(end),{"doctrine":doctrine_id})
		var stag := doc_mod("chain_stagger", 0.18) if not game.tower_lab else 0.0
		current.take_hit(power,ArenaCombat.Type.MAGIC,"tower",stag,0,penetration(),"arc",Vector2.ZERO,Vector2.INF,{"auto_tower":true})
		origin=end
		power*=retention
		current=null
		var nearest:=reach*reach
		for other: ArenaEnemy in game.domain_enemies("defense"):
			if not game.trial_tower_can_hit(other) or other in struck: continue
			var distance:=end.distance_squared_to(other.center())
			if distance<nearest:
				current=other
				nearest=distance

func fire_lens(enemy: ArenaEnemy,power: float) -> void:
	var new_target := enemy != focus_target
	focus_layers=0 if new_target else mini(focus_layers+1,int(doc_mod("focus_limit",4.0)))
	focus_target=enemy
	var origin:=muzzle()
	var end:=enemy.center()
	var beam_kind := "tower_beam" if doctrine_id.is_empty() else "tower_beam_" + doctrine_id
	game.effect(origin,origin.distance_to(end),data.colour,beam_kind,0.24,origin.direction_to(end),{"layers":focus_layers,"doctrine":doctrine_id})
	game.effect(end,14.0+float(focus_layers)*4.0,data.colour,"lens_hit",0.20,origin.direction_to(end),{"layers":focus_layers})
	var hit_mult := doc_mod("first_light", 1.0) if new_target else 1.0+focus_layers*doc_mod("focus_step",0.35)
	enemy.take_hit(power*hit_mult,ArenaCombat.Type.MAGIC,"tower",0,0,penetration(),"beam",Vector2.ZERO,Vector2.INF,{"auto_tower":true})
	if not game.tower_lab and is_instance_valid(enemy) and not enemy.dead:
		enemy.expose(2.5)
		enemy.apply_mark(doc_mod("lens_mark_time",2.5),doc_mod("lens_mark",0.25))
		enemy.chill(doc_mod("lens_slow", 0.25), doc_mod("lens_slow_time", 1.5))

func snare_radius() -> float:
	return (64.0+8.0*(level-1))*doc_mod("splash_mult",1.0)

func try_snare() -> bool:
	if position.distance_to(rally_point)>attack_range(): return false
	var nearby: Array[ArenaEnemy]=[]
	var radius:=snare_radius()
	var trigger:=false
	for enemy: ArenaEnemy in game.domain_enemies("defense"):
		if not game.trial_tower_can_hit(enemy) or enemy.is_flying(): continue
		var distance:=rally_point.distance_to(enemy.position)
		if distance<=radius:
			nearby.append(enemy)
			if distance<=radius*0.65: trigger=true
	if not trigger: return false
	attack_clock=reload_time()
	fire_clock=0.16
	_snare_snap_clock=0.38
	_trigger_v024_punch()
	if game != null and game.event_bus != null and not nearby.is_empty():
		game.event_bus.emit_event("tower_fire", {"tower": self, "target": nearby[0]})
	var power: float=shot_power()*(1.0+(game.hero.command_aura(position) if game.hero.domain=="defense" else 0.0))
	for enemy in nearby:
		if not game.trial_tower_can_hit(enemy) or enemy.is_flying(): continue
		enemy.take_hit(power*doctrine_multiplier(enemy),ArenaCombat.Type.PHYSICAL,"tower",0,0,penetration(),"snare")
		if not enemy.dead:
			if enemy.is_boss(): enemy.accept_tower_control(0.30)
			else: enemy.chill(doc_mod("net_slow",0.32 if enemy.elite else 0.50),doc_mod("net_duration",2.4))
	game.effect(rally_point,radius,data.colour,"snare_snap",0.42,position.direction_to(rally_point),{"origin":muzzle(),"doctrine":doctrine_id})
	game.audio.play("tower",-18)
	return true

func fire_trial_pulse(power: float=-1.0) -> bool:
	var targets: Array[ArenaEnemy]=game.trial_tower_targets(self)
	var focused := focus_order_id()
	if focused != 0:
		targets = targets.filter(func(enemy): return enemy.get_instance_id() == focused)
	if targets.is_empty(): return false
	if doctrine_id == "breaker":
		var target := targets[0]
		for enemy in targets:
			if float(enemy.data.resistance) > float(target.data.resistance):
				target = enemy
		targets.assign([target])
	if power<0.0: power=shot_power()
	if not game.tower_lab and game.event_bus != null:
		game.event_bus.emit_event("tower_fire", {"tower": self, "target": targets[0]})
	var origin:=firing_position()
	var inner:=trial_frost_inner()
	for enemy in targets:
		if not game.trial_tower_can_hit(enemy): continue
		var at_center := origin.distance_squared_to(enemy.position) <= inner * inner
		var falloff := 1.0 if at_center or doctrine_id == "breaker" else minf(1.0,doc_mod("outer_power",ArenaTowerTrial.FROST_OUTER_POWER))
		enemy.take_hit(power * falloff * doctrine_multiplier(enemy), ArenaCombat.Type.MAGIC, "tower",
			0.0, 0.0, penetration(), "tower_frost", Vector2.ZERO, Vector2.INF, {"auto_tower": true})
		if enemy.dead and doctrine_id == "arcfire":
			game.area_damage(enemy.position, doc_mod("explode_radius"), power * doc_mod("explode_mult", 1.0),
				ArenaCombat.Type.MAGIC, "tower", 0.0, 0.0, 0.0, 0.0, "attack", true, {"domain": "defense"})
		if not enemy.dead and doctrine_id not in ["arcfire", "breaker"]:
			if doctrine_id=="frost" and not enemy.is_boss(): enemy.chill(doc_mod("slow_amount"),doc_mod("slow_time"))
			enemy.tower_frost(doc_mod("freeze_time",trial_stat("freeze")),2 if at_center else 1,int(doc_mod("frost_stacks",ArenaTowerTrial.FROST_LIMIT)))
		game.tower_trial_stats.pulse_hits+=1
		if at_center: game.tower_trial_stats.inner_hits+=1
	game.tower_trial_stats.pulses+=1
	if doctrine_id=="arcfire":
		game.effect(origin,attack_range(),Color("ffa767"),"tower_arcfire",0.44,Vector2.RIGHT,{"inner":inner,"doctrine":doctrine_id})
	elif doctrine_id == "breaker":
		game.effect(targets[0].position, 25.0, Color("9a89ff"), "magic_impact_painted", 0.35)
	else:
		game.effect(origin,attack_range(),Color("b6e5ef"),"tower_frost",0.52,Vector2.RIGHT,{"inner":inner,"doctrine":doctrine_id})
		game.effect(origin,inner,Color("d4f4ff"),"tower_frost_inner",0.52,Vector2.RIGHT,{"doctrine":doctrine_id})
	fire_clock=0.14
	_trigger_v024_punch()
	game.audio.play("tower",-12,1.14)
	return true
func fire_shots(enemy: Node2D,power: float,locked_aim:=Vector2.INF) -> void:
	var origin:=muzzle()
	var dist_to_enemy:=origin.distance_to(enemy.center())
	var options: Dictionary={"target":enemy,"appearance":"magic" if kind=="mage" else "arrow","speed":760.0,"tower":self,"pen":penetration(),
		"tower_kind":kind,"tower_level":level,"doctrine_id":doctrine_id,
		"bounce":0,"feedback":"tower_arrow" if kind=="archer" else "tower_spell","condition_hit":{"auto_tower":true},
		"mark":doc_mod("mark_time"),"mark_bonus":doc_mod("mark_bonus"),
		"slow_amount":doc_mod("slow_amount"),"slow_time":doc_mod("slow_time"),
		"freeze_stacks":int(doc_mod("frost_stacks")),"freeze_time":doc_mod("freeze_time")}
	if kind=="archer" and not game.tower_lab:
		options.mark=doc_mod("mark_time",3.5)
		options.mark_bonus=doc_mod("mark_bonus",0.28)
		options.pierce=int(doc_mod("arrow_pierce",2.0 if doctrine_id=="piercer" else 1.0))
		if doctrine_id=="piercer":
			options.speed=920.0
			options.arc_height=clampf(dist_to_enemy*0.08,10.0,26.0)
		else:
			options.speed=720.0
			options.arc_height=clampf(dist_to_enemy*0.18,16.0,56.0)
	elif kind=="mage" and not game.tower_lab:
		options.speed=720.0
		options.arc_height=clampf(dist_to_enemy*0.07,8.0,22.0)
	var shots:=1
	if doc_mod("triple_chance")>0.0 and game.rng.randf()<doc_mod("triple_chance"):
		shots=3
	if kind=="mage":
		var muz_col := Color("ff9238") if doctrine_id=="arcfire" else (Color("d488ff") if doctrine_id=="breaker" else Color("9ce8ff"))
		game.effect(origin,16,muz_col,"magic_impact_painted",0.14,visual_target)
	for index in range(shots):
		var spread: float=(index-(shots-1)*0.5)*0.09
		var point: Vector2=enemy.center()
		if locked_aim.is_finite(): point=locked_aim
		var aim: Vector2=origin+(point-origin).rotated(spread)
		var shot_options: Dictionary=options.duplicate()
		if shots>1 and index!=int(shots/2):shot_options["target"]=null
		game.fire_projectile(origin,aim,power,int(data.type),"tower",shot_options)
func fire_cannon(enemy: Node2D,power: float,locked_aim:=Vector2.INF) -> void:
	var aim_pos: Vector2=enemy.position
	if bombard_point.is_finite():
		aim_pos=bombard_point
		visual_target=(aim_pos-muzzle()).normalized()
	elif locked_aim.is_finite(): aim_pos=locked_aim
	elif not enemy.is_guard and enemy.blocker==null and enemy.windup<=0 and enemy.melee_windup<=0 and enemy.stun<=0 and enemy.route_id>=0 and enemy.route_id<game.routes.size():
		var road: Curve2D=game.enemy_road(enemy)
		var slow_factor: float=(1.0-enemy.slow_amount) if enemy.slow>0 else 1.0
		var eff_speed: float=float(enemy.data.speed)*enemy.speed_scale()*slow_factor
		var predicted: float=clampf(enemy.progress+eff_speed*0.38,0.0,road.get_baked_length())
		aim_pos=road.sample_baked(predicted,true)
	var muz:=muzzle()
	game.effect(muz,22,Color("ffd484"),"hit",0.18,visual_target)
	ArenaBattleArt.emit_world_dust(muz,visual_target*42.0+Vector2(0,-16.0),28.0,Color("d8c8b4"))
	ArenaBattleArt.emit_world_dust(muz+Vector2(-8,4),Vector2(-visual_target.x*22.0,-20.0),22.0,Color("9e9286"))
	ArenaBattleArt.emit_world_dust(muz+Vector2(6,-4),visual_target*26.0+Vector2(0,-24.0),20.0,Color("6e645c"))
	var options: Dictionary={"origin":muz,"cannon":true,"cannon_tier":level,"doctrine_id":doctrine_id,"feedback":"shell",
		"pen":penetration(),"knockback":doc_mod("knockback"),"condition_hit":{"auto_tower":not bombard_point.is_finite()},
		"burn_dps":doc_mod("burn_dps"),"burn_time":doc_mod("burn_time",3.0),"burn_radius":doc_mod("burn_radius",64.0)}
	if game.defense_rules:
		options["shell_edge_power"] = doc_mod("shell_edge_power", 0.5)
		options.merge({"core_radius":trial_shell_core(),"tower_trial_shell":18.0 if not game.tower_lab else trial_stat("push"),"stun":doc_mod("shell_stun",0.55) if not game.tower_lab else trial_stat("stun"),"tower":self,"focus_id":0})
	game.delayed_attack(aim_pos,splash_radius(),power,0,"tower",0.38,options)
func muzzle() -> Vector2:
	if use_v024_art:
		if kind=="archer":
			var shift_a:=firing_position()-position
			return shift_a+ballista.to_global(Ballista.RELEASE_CENTER)
		if kind=="cannon":
			var shift_c:=firing_position()-position
			return shift_c+moving_part.to_global(Vector2([46,52,56][level-1],[-38,-44,-48][level-1]))
		var muv := ArenaBattleArt.tower_muzzle_uv(kind, level, doctrine_id)
		if _v024_flip:
			muv.x = 1.0 - muv.x
		return firing_position() + (muv - Vector2(0.5, ArenaBattleArt.V024_FOOT_FRAC)) * ArenaBattleArt.V024_CELL * _v024_base_scale
	if ArenaBattleArt.TOWER_REGIONS.has(kind):
		var size:=body.texture.get_size()*body.scale
		var height:=0.74 if kind=="storm" else (0.76 if kind=="lens" else 0.60)
		return firing_position()+Vector2(size.x*(0.12 if kind=="lens" else 0.0),-size.y*height)
	var shift:=firing_position()-position
	match kind:
		"archer":
			return shift+ballista.to_global(Ballista.RELEASE_CENTER)
		"mage":
			return shift+moving_part.global_position
		"cannon":
			return shift+moving_part.to_global(Vector2([62,78,92][level-1],[-44,-55,-65][level-1]))
	return shift+to_global(swivel)

func _draw() -> void:
	if project_level==1:
		if use_v024_art:
			var scaf_idx := int(floor(visual_clock * 6.0)) % 2
			var scaf_tex := ArenaBattleArt.prop_frame_texture("scaffold", scaf_idx, 2)
			if scaf_tex != null:
				texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				var jitter_x := sin(visual_clock * 24.0) * 1.0 if scaf_idx == 1 else 0.0
				draw_texture_rect(scaf_tex, Rect2(Vector2(-52.0 + jitter_x, -82.0), Vector2(104.0, 88.0)), false)
			var frac := 1.0 - project_clock / ArenaTowerTrial.BUILD_TIME
			draw_rect(Rect2(-24.0, 10.0, 48.0, 6.0), Color("14111b"))
			draw_rect(Rect2(-22.0, 12.0, 44.0 * clampf(frac, 0.0, 1.0), 2.0), Color("f2cb6e"))
			return
		draw_arc(Vector2(0,10),28.0,-PI*0.5,-PI*0.5+TAU*(1.0-project_clock/ArenaTowerTrial.BUILD_TIME),28,Color("e4c382"),2.0,true)
		return
	ArenaGrounding.ensure_textures()
	var width := (56.0 if kind=="archer" else 76.0) + (level-1)*8
	draw_texture_rect(ArenaGrounding.shadow,Rect2(-width*0.4,-7,width,16),false,Color("bdabad"))
	if kind=="archer" and not use_v024_art:
		for side in [-1,1]:
			var foot := Vector2(side*width*0.34,-1)
			draw_texture_rect(ArenaGrounding.shadow,Rect2(foot-Vector2(9,4),Vector2(18,8)),false)
	if use_v024_art:
		_draw_v024_base_accent()
	if project_level > 1:
		var up_frac := clampf(1.0 - project_clock / ArenaTowerTrial.BUILD_TIME, 0.0, 1.0)
		draw_rect(Rect2(-22.0, 12.0, 44.0, 5.0), Color("14111b"))
		draw_rect(Rect2(-20.0, 13.5, 40.0 * up_frac, 2.0), Color("7fd8ff"))
	if _is_healer_buffed():
		for p_i in range(3):
			var p_age := fmod(visual_clock * 0.75 + float(p_i) * 0.33, 1.0)
			var px := cos(visual_clock * 2.2 + float(p_i) * 2.1) * (width * 0.34)
			var py := 2.0 - p_age * 28.0
			var pp := Vector2(px, py).snapped(Vector2(2, 2))
			var pa := sin(p_age * PI) * 0.92
			draw_rect(Rect2(pp - Vector2(2, 1.5), Vector2(4, 3)), Color(0.98, 0.68, 0.82, pa))
			draw_rect(Rect2(pp - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.92, 0.70, pa))
	if game.tower_lab and kind=="archer" and timing.is_preparing():
		var origin:=muzzle()-position
		var end:=origin+visual_target*trial_arrow_range()
		draw_line(origin,end,Color(0.18,0.14,0.08,0.45),4.0,true)
		draw_line(origin,end,Color(0.95,0.84,0.59,0.24+timing.prep_progress()*0.40),1.5,true)
	if kind=="snare":
		var point:=rally_point-position
		var ink:=Color(data.colour,0.88 if attack_clock<=0.0 else 0.42)
		var trap_name := "snare_barb" if doctrine_id=="barb" else ("snare_ratchet" if doctrine_id=="ratchet" else "snare_net")
		var trap_cols := 4 if trap_name=="snare_net" else 2
		var trap_tex := ArenaBattleArt.prop_frame_texture(trap_name, 0, trap_cols) if use_v024_art else null
		if trap_tex != null:
			texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var t_dim := Vector2(46.0, 34.0) if trap_name=="snare_net" else Vector2(44.0, 32.0)
			var t_alpha := 0.96 if attack_clock<=0.0 else 0.46
			draw_texture_rect(trap_tex, Rect2(point - t_dim * 0.5, t_dim), false, Color(1, 1, 1, t_alpha))
		else:
			draw_arc(point,9,0.0,TAU,16,ink,1.6,true)
			draw_line(point+Vector2(-13,3),point+Vector2(12,-3),ink,2,true)
		if game.tower_lab and game.selected_site==site_id: draw_arc(point,snare_radius(),0.0,TAU,48,ink,1.4,true)
	if can_set_bombard():
		if game.tower_lab and timing.is_preparing(): draw_cannon_point(timing.target_point,0.32+0.37*timing.prep_progress())
		elif bombard_point.is_finite():
			if game.selected_site==site_id: draw_cannon_point(bombard_point,0.72)
			else:
				var bp := (bombard_point - position).snapped(Vector2(2, 2))
				draw_line(bp - Vector2(5, 0), bp + Vector2(5, 0), Color("f5cf91b8"), 2.0, false)
				draw_line(bp - Vector2(0, 5), bp + Vector2(0, 5), Color("f5cf91b8"), 2.0, false)
	if game.selected_site==site_id:
		draw_arc(Vector2.ZERO,ground_order_range(),0,TAU,72,Color(data.colour,0.18),1.5,true)
		if game.tower_lab and kind=="mage" and doctrine_id!="breaker": draw_arc(Vector2.ZERO,trial_frost_inner(),0,TAU,58,Color("91cfdb96"),2.5,true)
		if game.tower_lab and kind=="barracks":
			for soldier: ArenaSoldier in troops:
				var point:=rally_slot(soldier.slot)-position
				var ink:=Color("efd49a") if soldier.can_block() else Color("efd49a66")
				draw_arc(point,5.0,0.0,TAU,14,ink,1.5,true)
	if doctrine_id!="":
		var count := enhancements().size()
		for index in range(count):
			var dot := Vector2((float(index)-(float(count)-1.0)*0.5)*10.0,25.0)
			draw_circle(dot,3.2,Color("171923"))
			draw_circle(dot,2.1,Color("f5cd6a") if index<unlocked_enhancements else Color("5e6878"))

func _draw_v024_base_accent() -> void:
	draw_set_transform(Vector2(0.0,2.0),0.0,Vector2(1.0,0.54))
	match kind:
		"archer":
			for px: float in [-26.0,22.0]:
				draw_rect(Rect2(px,-4.0,6.0,4.0),Color("24381e"))
				draw_rect(Rect2(px+1.0,-3.0,4.0,2.0),Color("588c3c"))
			draw_rect(Rect2(-18.0,14.0,4.0,4.0),Color("5e3c20"))
			draw_rect(Rect2(14.0,14.0,4.0,4.0),Color("5e3c20"))
		"mage":
			var m_col:=Color("ff8a28") if doctrine_id=="arcfire" else (Color("b874ff") if doctrine_id=="breaker" else Color("68d8ff"))
			for i in range(4):
				var rp:=Vector2.from_angle(float(i)*PI*0.5+0.78)*34.0
				draw_rect(Rect2(rp-Vector2(2.0,2.0),Vector2(4.0,4.0)),Color("14111b"))
				draw_rect(Rect2(rp-Vector2(1.0,1.0),Vector2(2.0,2.0)),m_col)
		"cannon":
			for rx: float in [-24.0,-8.0,8.0,24.0]:
				draw_rect(Rect2(rx-1.5,16.0,3.0,3.0),Color("1a181e"))
				draw_rect(Rect2(rx-0.5,17.0,1.0,1.0),Color("8c8894"))
		"barracks":
			draw_rect(Rect2(-16.0,14.0,32.0,5.0),Color("261e18",0.7))
			draw_rect(Rect2(-14.0,15.0,28.0,3.0),Color("c4965a",0.85))
		"storm":
			for ang: float in [0.4,2.7,3.6,5.9]:
				var gp:=Vector2.from_angle(ang)*34.0
				draw_rect(Rect2(gp-Vector2(3.0,3.0),Vector2(6.0,6.0)),Color("141824"))
				draw_rect(Rect2(gp-Vector2(1.5,1.5),Vector2(3.0,3.0)),Color("58b4e8" if fire_clock<=0.0 else "9cf4ff"))
		"lens":
			for i in range(4):
				var sp:=Vector2.from_angle(float(i)*PI*0.5)*35.0
				draw_rect(Rect2(sp-Vector2(2.0,2.0),Vector2(4.0,4.0)),Color("e6b842"))
		"snare":
			for sx: float in [-28.0,24.0]:
				draw_rect(Rect2(sx,12.0,5.0,4.0),Color("281a10"))
				draw_rect(Rect2(sx+1.0,13.0,3.0,2.0),Color("9e7240"))
	draw_set_transform(Vector2.ZERO)

func draw_cannon_point(point: Vector2,alpha: float) -> void:
	var center:=point-position
	var ink:=Color("f4c181")
	if game.tower_lab:
		draw_set_transform(center,0.0,Vector2(1.0,0.58))
		draw_arc(Vector2.ZERO,splash_radius(),0.0,TAU,48,Color(0.21,0.13,0.09,alpha*0.7),3.3,true)
		draw_arc(Vector2.ZERO,trial_shell_core(),0.0,TAU,40,Color(0.21,0.13,0.09,alpha*0.82),4.6,true)
		draw_arc(Vector2.ZERO,splash_radius(),0.0,TAU,48,Color(ink,alpha*0.7),1.3,true)
		draw_arc(Vector2.ZERO,trial_shell_core(),0.0,TAU,40,Color(ink,alpha),2.4,true)
		draw_set_transform(Vector2.ZERO)
	var ret_tex := ArenaBattleArt.prop_frame_texture("reticle", 0, 1) if use_v024_art else null
	if ret_tex != null:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var pulse := 1.0 + 0.08 * sin(visual_clock * 7.0)
		var dim := Vector2(36.0, 27.0) * pulse
		draw_texture_rect(ret_tex, Rect2(center - dim * 0.5, dim), false, Color(1.0, 0.92, 0.78, clampf(alpha * 1.35, 0.45, 0.96)))
	else:
		draw_line(center-Vector2(5,0),center+Vector2(5,0),Color(ink,alpha),1.4,true)
		draw_line(center-Vector2(0,5),center+Vector2(0,5),Color(ink,alpha),1.4,true)

func draw_mechanism() -> void:
	var tint:=Color(data.colour)
	var cycle:=sin(visual_clock*3.0)
	var power:=clampf(fire_clock/0.13,0.0,1.0)
	match kind:
		"storm":
			moving_part.draw_arc(Vector2.ZERO,3.5+power*3.0,cycle,cycle+4.8,12,Color(tint,0.5+power*0.4),1.4,true)
		"lens":
			moving_part.draw_circle(Vector2.ZERO,2.0+float(focus_layers)*0.7,Color(tint,0.5+power*0.4))
		"snare":
			var axle:=Vector2.RIGHT.rotated(visual_clock*4.0 if attack_clock>0 else 0.0)
			moving_part.draw_line(-axle*3.5,axle*3.5,Color("e8bb7c"),1.5,true)

func _trigger_v024_punch() -> void:
	if not use_v024_art:
		return
	var reduced := bool(game.campaign.data.reduced_motion) if game != null and game.campaign != null else false
	_v024_flash = 0.04 if reduced else 0.06
	_v024_recoil = 0.35 if reduced else 1.0
	if not reduced and game != null and game.feel != null and game.feel.enabled and (kind == "cannon" or doctrine_id in ["piercer", "surge", "far_lens"]):
		game.feel.trauma = minf(1.0, game.feel.trauma + 0.09)

func _sync_v024_animation() -> void:
	if not use_v024_art or body == null:
		return
	var reduced := bool(game.campaign.data.reduced_motion) if game != null and game.campaign != null else false
	var next_frame := 0
	match kind:
		"barracks":
			if fire_clock > 0.21: next_frame = 1
			elif fire_clock > 0.08: next_frame = 2
			elif fire_clock > 0.0: next_frame = 3
		"snare":
			if _snare_snap_clock > 0.22 or fire_clock > 0.0: next_frame = 2
			elif _snare_snap_clock > 0.0: next_frame = 3
			elif attack_clock > 0.0 and attack_clock <= 0.45: next_frame = 1
			elif attack_clock > 0.45: next_frame = 3
		_:
			if timing.phase == AttackTiming.Phase.PREP: next_frame = 1
			elif timing.phase == AttackTiming.Phase.RELEASE or fire_clock > 0.075: next_frame = 2
			elif timing.phase == AttackTiming.Phase.RECOVER or fire_clock > 0.0: next_frame = 3
	if next_frame != _v024_frame:
		_v024_frame = next_frame
		var next_tex := ArenaBattleArt.tower_frame_texture(kind, level, doctrine_id, _v024_frame)
		if next_tex != null:
			body.texture = next_tex
	if kind in ["archer", "cannon", "lens"]:
		if visual_target.x < -0.06: _v024_flip = true
		elif visual_target.x > 0.06: _v024_flip = false
		body.flip_h = _v024_flip
	var prep := timing.prep_progress() * (0.35 if reduced else 1.0)
	var sx := 1.0 + 0.032 * prep
	var sy := 1.0 - 0.048 * prep
	if _v024_recoil > 0.001:
		var heavy_recoil := kind in ["cannon", "snare"] or doctrine_id in ["piercer", "surge"]
		if heavy_recoil:
			sx += 0.075 * _v024_recoil
			sy -= 0.095 * _v024_recoil
		else:
			sx -= 0.045 * _v024_recoil
			sy += 0.065 * _v024_recoil
	body.scale = Vector2(_v024_base_scale.x * sx, _v024_base_scale.y * sy)
	var flash_w := clampf(_v024_flash / 0.06, 0.0, 1.0)
	if is_sealed():
		body.modulate = Color(0.50, 0.62, 0.74, 1.0)
	else:
		body.modulate = Color(1.0 + 0.34 * flash_w, 1.0 + 0.28 * flash_w, 1.0 + 0.18 * flash_w, 1.0)
	body.visible = (project_level != 1)

func _process(delta: float) -> void:
	if not game.running or game.game_over:
		return
	visual_clock += delta
	_v024_flash = maxf(0.0, _v024_flash - delta)
	_v024_recoil = maxf(0.0, _v024_recoil - delta * 6.5)
	_snare_snap_clock = maxf(0.0, _snare_snap_clock - delta)
	if use_v024_art:
		_sync_v024_animation()
		if kind in ["archer", "cannon"]:
			_pose_mechanism()
		if tower_fx != null and (fire_clock > 0.0 or jam_clock > 0.0 or seal_telegraph > 0.0 or seal_clock > 0.0 or int(visual_clock * 12.0) != int((visual_clock - delta) * 12.0)):
			tower_fx.queue_redraw()
		if project_level > 0:
			queue_redraw()
		return
	if moving_part==null:
		return
	if ArenaBattleArt.TOWER_REGIONS.has(kind):
		if not game.campaign.data.reduced_motion or fire_clock>0.0 or seal_telegraph>0.0 or seal_clock>0.0: moving_part.queue_redraw()
		if (seal_telegraph>0.0 or seal_clock>0.0) and tower_fx!=null: tower_fx.queue_redraw()
		return
	if kind in ["mage","archer","cannon","barracks"] or jam_clock>0.0 or seal_telegraph>0.0 or seal_clock>0.0 or timing.phase!=AttackTiming.Phase.IDLE or _last_pose_phase!=timing.phase or visual_target.distance_squared_to(_last_pose_aim)>0.0001:
		_pose_mechanism()
		if (jam_clock>0.0 or seal_telegraph>0.0 or seal_clock>0.0) and tower_fx!=null and (kind in ["barracks","cannon"] or seal_telegraph>0.0 or seal_clock>0.0):
			tower_fx.queue_redraw()

func _pose_mechanism() -> void:
	var reduced := bool(game.campaign.data.reduced_motion)
	var amp := 0.3 if reduced else 1.0
	var prep := timing.prep_progress()
	var release := 1.0-timing.release_progress() if timing.phase==AttackTiming.Phase.RELEASE else 0.0
	var aim := visual_target.normalized()
	_last_pose_phase = timing.phase
	_last_pose_aim = visual_target
	_last_pose_prep = prep
	if use_v024_art:
		if kind == "archer" and ballista != null:
			ballista.pose(aim, smoothstep(0.0, 1.0, prep) * amp, timing.is_preparing(), release * amp, visual_clock)
		elif kind == "cannon" and moving_part != null:
			var sign_x := -1.0 if aim.x < 0.0 else 1.0
			moving_part.scale = Vector2(_part_base_scale.x * sign_x, _part_base_scale.y)
			moving_part.rotation = clampf(aim.y * 0.18 - prep * 0.08 + release * 0.06, -0.16, 0.16) * sign_x
			moving_part.position = swivel
		return
	match kind:
		"archer":
			ballista.pose(aim,smoothstep(0.0,1.0,prep)*amp,timing.is_preparing(),release*amp,visual_clock)
			if tower_fx!=null:tower_fx.queue_redraw()
		"mage":
			moving_part.position=swivel+Vector2(0,(sin(visual_clock*2.2)*1.6-7.0*prep+3.5*release)*amp)
			moving_part.modulate=Color(1.0+prep*0.42,1.0+prep*0.56,1.0+prep*0.72)
			if tower_fx!=null:tower_fx.queue_redraw()
		"cannon":
			var sign_x := -1.0 if aim.x < 0.0 else 1.0
			var recovery := 1.0-timing.recover_progress() if timing.phase==AttackTiming.Phase.RECOVER else 0.0
			# Game-feel squash on prep, stretch on release, spring settle on recovery
			var sx_mod := 1.0 - 0.08 * prep * amp + 0.12 * release * amp - 0.03 * sin(recovery * PI) * amp
			var sy_mod := 1.0 + 0.07 * prep * amp - 0.08 * release * amp + 0.03 * sin(recovery * PI) * amp
			moving_part.scale = Vector2(_part_base_scale.x * sign_x * sx_mod, _part_base_scale.y * sy_mod)
			# Mortar always points upward into the sky (30..50 deg), adjusting elevation gently for target vertical offset
			var elev_adjust := clampf(aim.y * 0.18 - prep * 0.08 + release * 0.06, -0.16, 0.16)
			moving_part.rotation = elev_adjust * sign_x
			var recoil_vec := Vector2(sign_x * 0.78, -0.62).normalized()
			moving_part.position = swivel - recoil_vec * (release * 9.5 + recovery * 2.5 - prep * 1.8) * amp
			if pivot_bed!=null:pivot_bed.queue_redraw()
			if tower_fx!=null:tower_fx.queue_redraw()
		"barracks":
			if tower_fx!=null and (fire_clock>0.0 or int(visual_clock*12.0)%2==0):
				tower_fx.queue_redraw()
