class_name ArenaMenuArt
extends RefCounted
# Cartoon shell materials; battle art and combat definitions are independent.
const PAPER:=Color("382c29")
const PAPER_MUTED:=Color("6c5850")
const INK:=Color("121e2c")
const GOLD:=Color("f3cc65")
const CONTROL_NAMES:=["back","settings","exit","check","lock","flag","heart","sword","speed","range","diamond","coin","star","star_empty","camp","shield"]
static var cache: Dictionary={}
static var regions: Dictionary={}
static func texture(key: String) -> Texture2D:return load("res://assets/v013/"+key+".png")
static func part(sheet: String,key: Variant) -> Texture2D:
	var id:=sheet+str(key)
	if not cache.has(id):
		if regions.is_empty():regions=JSON.parse_string(FileAccess.get_file_as_string("res://assets/v013/regions.json"))
		var box: Array=regions[sheet][key]
		var result:=AtlasTexture.new();result.atlas=texture(sheet);result.region=Rect2(box[0],box[1],box[2],box[3]);result.filter_clip=true;cache[id]=result
	return cache[id]
static func skin(index: int) -> Texture2D:
	return part("ui_skin","card") if index==5 else texture("widget_"+["paper","dark","amber","blue","green"][index])
static func style(index: int,colour:=Color.WHITE) -> StyleBoxTexture:
	var box:=StyleBoxTexture.new();box.texture=skin(index);box.modulate_color=colour
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:box.set_texture_margin(side,26 if index<2 else 18);box.set_content_margin(side,14)
	return box
static func panel(node: Control,paper:=false) -> void:node.add_theme_stylebox_override("panel",style(0 if paper else 1))
static func small_style(selected:=false,tint:=GOLD) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new();box.bg_color=Color("304455") if selected else Color("243343")
	box.border_color=tint if selected else Color("0f1c29");box.set_border_width_all(4 if selected else 3);box.border_width_bottom=5
	box.set_corner_radius_all(12);box.shadow_color=Color(0,0,0,.25);box.shadow_size=3;box.shadow_offset=Vector2(0,3)
	return box
static func button(node: Button,primary:=false,plain:=false) -> void:
	node.focus_mode=Control.FOCUS_ALL;node.add_theme_font_size_override("font_size",26)
	for state in ["normal","hover","pressed","disabled","focus"]:
		if plain:node.add_theme_stylebox_override(state,StyleBoxEmpty.new())
		elif primary:
			var tint: Color={"normal":Color.WHITE,"hover":Color(1.10,1.08,1.04),"pressed":Color(.88,.9,.94),"disabled":Color(.45,.51,.57),"focus":Color(1.14,1.12,1.02)}[state]
			node.add_theme_stylebox_override(state,style(2,tint))
		else:
			var box:=small_style(state in ["hover","focus"])
			if state=="pressed":box.bg_color=Color("192633")
			if state=="disabled":box.bg_color=Color("26313b");box.border_color=Color("18232e")
			node.add_theme_stylebox_override(state,box)
	node.add_theme_color_override("font_color",Color("fff3cf"));node.add_theme_color_override("font_disabled_color",Color("bac2c7"))
	node.add_theme_color_override("font_outline_color",Color("17202a"));node.add_theme_constant_override("outline_size",3)
static func selected(node: Button,on: bool,tint:=GOLD) -> void:
	for state in ["normal","hover","pressed","focus"]:node.add_theme_stylebox_override(state,small_style(on or state in ["hover","focus"],tint))
static func accent(node: Button,colour: String) -> void:
	var index: int={"amber":2,"blue":3,"green":4}[colour]
	for state in ["normal","hover","pressed","disabled","focus"]:
		var tint:=Color(.48,.53,.56) if state=="disabled" else (Color(1.12,1.1,1.05) if state in ["hover","focus"] else (Color(.86,.9,.94) if state=="pressed" else Color.WHITE))
		node.add_theme_stylebox_override(state,style(index,tint))
static func interact(node: Button,reduced:=false) -> void:
	if node.has_meta("micro_bound"):return
	node.set_meta("micro_bound",true)
	node.resized.connect(func():node.pivot_offset=node.size*.5);node.pivot_offset=node.size*.5
	node.mouse_entered.connect(func():_scale_to(node,1.0 if reduced or node.disabled else 1.04))
	node.mouse_exited.connect(func():_scale_to(node,1.0))
	node.button_down.connect(func():_scale_to(node,1.0 if reduced or node.disabled else .96))
	node.button_up.connect(func():_scale_to(node,1.0 if reduced or not node.is_hovered() else 1.04))
static func _scale_to(node: Control,value: float) -> void:
	if not node.is_inside_tree():return
	if node.has_meta("micro_tween"):
		var old: Tween=node.get_meta("micro_tween")
		if is_instance_valid(old):old.kill()
	var tween:=node.create_tween();node.set_meta("micro_tween",tween);tween.tween_property(node,"scale",Vector2.ONE*value,.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
static func icon(index: int) -> Texture2D:return part("ui_icons",str(index))
static func utility(key: String) -> Texture2D:return part("ui_controls",str(CONTROL_NAMES.find(key)))
static func skill(identity: String,slot: int) -> Texture2D:return icon(4+ArenaDefinitions.HERO_IDS.find(identity)*4+slot)
static func perk(id: String) -> Texture2D:
	for index in range(ArenaPerks.CARDS.size()):
		if str(ArenaPerks.CARDS[index].id)==id:return part("perk_icons",str(index))
	return null
static func creature(key: String) -> Texture2D:
	var sheet: Texture2D=load("res://assets/v06/creature_"+key+".png");var image:=AtlasTexture.new();image.atlas=sheet;image.region=Rect2(Vector2.ZERO,sheet.get_size()/Vector2(6,3));return image
