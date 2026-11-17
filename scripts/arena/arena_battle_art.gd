class_name ArenaBattleArt
extends Node2D
const FOOTPRINT:=Vector2(96,48)
const HEIGHTS:={"archer":[110.0,137.0,163.0],"mage":[115.0,142.0,168.0],"cannon":[65.0,85.0,110.0],"barracks":[87.0,109.0,132.0]}
const WIDTHS:={"archer":[0.72,0.74,0.87],"mage":[0.74,0.76,0.90],"cannon":[0.74,0.74,0.88],"barracks":[0.76,0.76,0.90]}
const CONTACT:=[0.79,0.80,0.87]
var game: ArenaGame
var pad: Texture2D
static var active_ground_fx: ArenaBattleArt = null
static var _dust_tex: Texture2D
var _world_dust: Array[Dictionary] = []
var _redraw_tick: int = 0
var _last_hover_site: int = -2

static func emit_world_dust(world_pos: Vector2, drift: Vector2, sz: float, col: Color) -> void:
	if active_ground_fx == null or not is_instance_valid(active_ground_fx):
		return
	active_ground_fx._push_dust(world_pos, drift, sz, col)

func _push_dust(world_pos: Vector2, drift: Vector2, sz: float, col: Color) -> void:
	if _world_dust.size() >= 48:
		_world_dust.pop_front()
	_world_dust.append({"pos": world_pos, "vel": drift, "life": 0.34, "max_life": 0.34, "size": sz, "col": col})
static func map_path(key: String) -> String:
	return "res://assets/v09/map_"+key+".png"
static func towers_path() -> String:
	return "res://assets/v017/towers.png"
static var tower_metadata: Dictionary={}
static func contact(kind: String,tier: int,cell: Vector2) -> Dictionary:
	if tower_metadata.is_empty():
		var file:=FileAccess.open("res://assets/v017/towers.json",FileAccess.READ)
		if file!=null:tower_metadata=JSON.parse_string(file.get_as_text())
	var entry: Dictionary=tower_metadata.get(kind+str(tier),{})
	var bounds: Array=entry.get("bounds",[16,16,496,496])
	var widths: Dictionary={"archer":[77.0,90.0,102.0],"mage":[86.0,99.0,112.0],"cannon":[96.0,112.0,126.0],"barracks":[99.0,116.0,136.0]}
	var factor: float=minf(float(widths[kind][tier-1])/(float(bounds[2])-float(bounds[0])),float(HEIGHTS[kind][tier-1])/(480.0-float(bounds[1])))
	return {"uv":Vector2(0.5,480.0/512.0),"scale":Vector2.ONE*factor}
func _ready() -> void:
	z_index=-10
	if ResourceLoader.exists("res://assets/v09/site_pad.png"):
		var atlas:=AtlasTexture.new();atlas.atlas=load("res://assets/v09/site_pad.png");atlas.region=Rect2(164,314,1276,443);pad=atlas
func _enter_tree() -> void:
	active_ground_fx = self

func _exit_tree() -> void:
	if active_ground_fx == self:
		active_ground_fx = null

func _process(delta: float) -> void:
	var dirty: bool = not _world_dust.is_empty()
	if dirty:
		var write := 0
		for i in range(_world_dust.size()):
			var d: Dictionary = _world_dust[i]
			var life := float(d.life) - delta
			if life > 0.0:
				d.life = life
				d.pos = Vector2(d.pos) + Vector2(d.vel) * delta
				d.vel = Vector2(d.vel) * maxf(0.0, 1.0 - delta * 4.5)
				_world_dust[write] = d
				write += 1
		_world_dust.resize(write)
	_redraw_tick += 1
	var hover_site: int = game.selected_site if game != null else -1
	if game != null and game.started and hover_site < 0:
		var cursor := game.mouse_world()
		for i in range(game.level_definition.sites.size()):
			if cursor.distance_squared_to(game.level_definition.sites[i]) < 3025.0:
				hover_site = i
				break
	if dirty or hover_site != _last_hover_site or (_redraw_tick % 4) == 0:
		_last_hover_site = hover_site
		queue_redraw()
func _site_trait(index: int) -> String:
	if game==null or game.level_definition.is_empty():return ""
	var traits: Array=game.level_definition.get("site_traits",[])
	return str(traits[index]) if index>=0 and index<traits.size() else ""
func _trait_color(trait_id: String) -> Color:
	return {"highground":Color("f6c862"),"choke":Color("ee7b56"),"conduit":Color("6ce8ff")}.get(trait_id,Color("d8caa8"))
func _draw_trait_frame(point: Vector2,trait_id: String,locked: bool,selected: bool,occupied: bool) -> void:
	var tint:=_trait_color(trait_id)
	var alpha: float=(0.45 if locked else (0.95 if selected else 0.85)) if not occupied else (0.85 if selected else 0.42)
	var col:=Color(tint,alpha)
	var dark:=Color(0.08,0.07,0.14,alpha*0.95)
	var pulse:=0.72+0.28*sin(Time.get_ticks_msec()*0.005)
	var box:=Rect2(Vector2(roundf(point.x-48.0),roundf(point.y-24.0)),Vector2(96.0,48.0))
	var x0:=box.position.x;var y0:=box.position.y;var x1:=box.end.x;var y1:=box.end.y
	# Stepped pixel-art corner rune brackets (crisp 2px grid blocks, no soft arcs).
	for sign_x in [-1.0,1.0]:
		for sign_y in [-1.0,1.0]:
			var cx: float=x0 if sign_x<0 else x1
			var cy: float=y0 if sign_y<0 else y1
			var hx:=Rect2(cx+(0.0 if sign_x<0 else -12.0),cy+(0.0 if sign_y<0 else -2.0),12.0,2.0)
			var vx:=Rect2(cx+(0.0 if sign_x<0 else -2.0),cy+(0.0 if sign_y<0 else -8.0),2.0,8.0)
			draw_rect(hx.grow(1.0),dark)
			draw_rect(vx.grow(1.0),dark)
			draw_rect(hx,col)
			draw_rect(vx,col)
	if occupied:
		return
	# Trait-specific pixel motif on the frame edges.
	if trait_id=="highground":
		# Stepped battlement chevrons at top and bottom centers.
		for dx in [-6.0,-4.0,-2.0,0.0,2.0,4.0]:
			var dy: float=-absf(dx+1.0)*0.5
			draw_rect(Rect2(point.x+dx-1.0,y0-3.0+dy,4.0,4.0),dark)
			draw_rect(Rect2(point.x+dx,y0-2.0+dy,2.0,2.0),col)
	elif trait_id=="choke":
		# Fortified iron bastion ticks flanking left and right edges.
		for side in [-1.0,1.0]:
			var bx: float=x0-2.0 if side<0 else x1
			draw_rect(Rect2(bx-1.0,point.y-7.0,4.0,14.0),dark)
			draw_rect(Rect2(bx,point.y-6.0,2.0,4.0),col)
			draw_rect(Rect2(bx,point.y+2.0,2.0,4.0),col)
	elif trait_id=="conduit":
		# Arcane leyline pulsing pixel nodes on the four cardinal sides.
		var glow:=Color(Color("c692ff").lerp(tint,pulse),alpha)
		for offset in [Vector2(-box.size.x*0.5,0),Vector2(box.size.x*0.5,0),Vector2(0,-box.size.y*0.5),Vector2(0,box.size.y*0.5)]:
			var p: Vector2=point+Vector2(offset)
			draw_rect(Rect2(roundf(p.x-3.0),roundf(p.y-3.0),6.0,6.0),dark)
			draw_rect(Rect2(roundf(p.x-2.0),roundf(p.y-2.0),4.0,4.0),glow)
	# Zero text on map plinths; ground-embedded stone geometry communicates traits.
func _draw() -> void:
	if not game.started:return
	var is_ruins: bool=game.level_id=="ruins"
	var cursor: Vector2=game.mouse_world()
	for index in range(game.level_definition.sites.size()):
		var point: Vector2=game.level_definition.sites[index]
		var occupied:=game.site_tower(index)!=null
		var trait_id:=_site_trait(index)
		var locked:=game.site_locked(index)
		var selected: bool=(game.selected_site==index)
		var hovered: bool=(selected or cursor.distance_to(point)<55.0)
		ArenaGrounding.draw_contact(self,point,occupied,is_ruins,index,trait_id,locked,hovered,selected)
	if not _world_dust.is_empty():
		if _dust_tex == null and ResourceLoader.exists("res://assets/v018/particles/smoke_07.png"):
			_dust_tex = load("res://assets/v018/particles/smoke_07.png")
		if _dust_tex != null:
			for d in _world_dust:
				var a := clampf(float(d.life) / float(d.max_life), 0.0, 1.0)
				var sz := float(d.size) * (1.28 - 0.32 * a)
				var p: Vector2 = d.pos
				var c: Color = d.col
				draw_texture_rect(_dust_tex, Rect2(p - Vector2(sz * 0.5, sz * 0.55), Vector2(sz, sz * 0.72)), false, Color(c.r, c.g, c.b, a * 0.36))
