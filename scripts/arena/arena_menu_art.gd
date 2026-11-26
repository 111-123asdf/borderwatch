class_name ArenaMenuArt
extends RefCounted
# Cartoon shell materials; battle art and combat definitions are independent.
const GOLD:=Color("f3cc65")
const STEEL_TEXT:=Color("e8f0f6")
const STEEL_MUTED:=Color("8ca5b8")
const STEEL_GOLD:=Color("eab955")
const STEEL_CYAN:=Color("59c9f5")
const V027_ROOT:="res://assets/ui_v027/"
const V028_ROOT:="res://assets/ui_v028/"
const V030_ROOT:="res://assets/ui_v030/"
const V032_ROOT:="res://assets/ui_v032/"
const CONTROL_NAMES:=["back","settings","exit","check","lock","flag","heart","sword","speed","range","diamond","coin","star","star_empty","camp","shield"]
const ICON_ATLAS_INDEX:={
	"power":0,"rapid":1,"lifesteal":2,"pierce":3,"execute":4,"combo":5,
	"focus":6,"starlight":7,"burn":8,"echo":9,"chain":10,"overload":11,
	"tough":12,"ironwall":13,"battlewill":14,"reflect":15,"revive":16,"unyield":17,
	"command":18,"armament":19,"spoils":20,"farsight":21,"works":22,"horn":23,
	"warcredit":24,"citywall":25,"enchant":26,"bloodrage":27,"shieldback":28,"oath":29,
	"shadowstep":30,"piercearrow":31,"frostheart":32,"starcore":33,"sworddance":34,"executioner":35,
	"frostfire":36,"fortress":37,"warmachine":38,"goldenage":39,
}
static var cache: Dictionary={}
static var regions: Dictionary={}
static var v027_cache: Dictionary={}
static var v028_cache: Dictionary={}
static var v030_cache: Dictionary={}
static var v032_cache: Dictionary={}
static func texture(key: String) -> Texture2D:return load("res://assets/v013/"+key+".png")
static func v027(key: String) -> Texture2D:
	if not v027_cache.has(key):
		var path: String = V027_ROOT + key + ".png"
		if ResourceLoader.exists(path):
			v027_cache[key] = load(path) as Texture2D
		else:
			v027_cache[key] = null
	return v027_cache.get(key) as Texture2D
static func v028(key: String) -> Texture2D:
	if not v028_cache.has(key):
		var path: String = V028_ROOT + key + ".png"
		if ResourceLoader.exists(path):
			v028_cache[key] = load(path) as Texture2D
		else:
			v028_cache[key] = null
	return v028_cache.get(key) as Texture2D
static func v030(key: String) -> Texture2D:
	if not v030_cache.has(key):
		var path: String = V030_ROOT + key + ".png"
		if ResourceLoader.exists(path):
			v030_cache[key] = load(path) as Texture2D
		else:
			v030_cache[key] = null
	return v030_cache.get(key) as Texture2D
static func rule_medal(id: String) -> Texture2D:
	return v028("medal_" + id)
static func passive_medal(id: String) -> Texture2D:
	var tex := v030("passive_" + id)
	if tex != null:return tex
	var symbols := {
		"breach": "ricochet", "spellbreak": "frost_nova", "hunt": "chain_bolt", "shieldbreak": "orbit_blades",
		"riposte": "phantom_slash", "iron_guard": "tower_aegis", "scatter_step": "multishot", "focus_energy": "star_meteor",
		"blastcraft": "blazing_wake", "hazardcraft": "gravity_well", "pathfinder": "ricochet", "room_recovery": "blood_aegis",
		"handover": "tower_storm", "volley": "orbital_laser", "last_stand": "void_bloom"
	}
	if symbols.has(id):
		return v030("passive_" + str(symbols[id]))
	return rule_medal(id)
static func v032(key: String) -> Texture2D:
	if not v032_cache.has(key):
		var path: String = V032_ROOT + key + ".png"
		if ResourceLoader.exists(path):
			v032_cache[key] = load(path) as Texture2D
		else:
			v032_cache[key] = null
	return v032_cache.get(key) as Texture2D
static func relic_medal(id: String) -> Texture2D:
	return v032("relic_" + id)
static func nine_patch_v030(key: String, margin := 16, content_pad := 10, colour := Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = v030(key)
	box.modulate_color = colour
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, margin)
		box.set_content_margin(side, content_pad)
	return box
static func nine_patch_v028(key: String, margin := 14, content_pad := 10, colour := Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = v028(key)
	box.modulate_color = colour
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, margin)
		box.set_content_margin(side, content_pad)
	return box
static func nine_patch(key: String, margin := 14, content_pad := 10, colour := Color.WHITE) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = v027(key)
	box.modulate_color = colour
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, margin)
		box.set_content_margin(side, content_pad)
	return box
static func obsidian_panel(node: Control, inset := false) -> void:
	var box: StyleBoxTexture = nine_patch("panel_inset_dark" if inset else "panel_obsidian", 12 if inset else 18, 10 if inset else 12)
	node.add_theme_stylebox_override("panel", box)
static func steel_rail(node: Control) -> void:
	node.add_theme_stylebox_override("panel", nine_patch("rail_steel", 16, 8))
static func steel_button(node: Button, tone := "steel", plain := false) -> void:
	node.focus_mode = Control.FOCUS_ALL
	node.add_theme_font_size_override("font_size", 24)
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var asset_key: String = {"cyan": "btn_cyan", "gold": "btn_gold", "steel": "btn_steel", "muted": "btn_muted"}.get(tone, "btn_steel")
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		if state == "focus":
			node.add_theme_stylebox_override(state, focus_outline())
		elif plain:
			node.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		elif state == "disabled":
			node.add_theme_stylebox_override(state, nine_patch("btn_muted", 14, 8, Color(0.86, 0.89, 0.93)))
		else:
			var tint: Color = {"normal": Color.WHITE, "hover": Color(1.12, 1.12, 1.10), "pressed": Color(0.84, 0.88, 0.92), "focus": Color(1.14, 1.14, 1.06)}.get(state, Color.WHITE)
			node.add_theme_stylebox_override(state, nine_patch(asset_key, 14, 8, tint))
	node.add_theme_color_override("font_color", STEEL_TEXT)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_focus_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", Color("d2dfe8"))
	node.add_theme_color_override("font_disabled_color", Color("6f8496"))
	node.add_theme_color_override("font_outline_color", Color("071018"))
	node.add_theme_constant_override("outline_size", 3)
static func steel_slot(node: Button, active := false, accent_col := STEEL_CYAN) -> void:
	for state in ["normal", "hover", "pressed", "focus"]:
		if state == "focus":
			node.add_theme_stylebox_override(state, focus_outline())
			continue
		var is_lit: bool = active or state in ["hover", "focus"]
		var box := StyleBoxFlat.new()
		box.bg_color = Color("162c3d") if active else (Color("122433") if is_lit else Color("0c1924"))
		if state == "pressed":
			box.bg_color = Color("09131c")
		box.border_color = accent_col if active else (accent_col.darkened(0.2) if is_lit else Color("3a5366"))
		box.set_border_width_all(3 if active else 2)
		box.border_width_bottom = 4
		box.set_corner_radius_all(6)
		box.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
		box.shadow_size = 2
		box.shadow_offset = Vector2(0, 2)
		node.add_theme_stylebox_override(state, box)
static func focus_outline() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Color("fff0b0")
	box.set_border_width_all(2)
	box.set_corner_radius_all(7)
	return box
static func stat_bar_theme(bar: ProgressBar) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("07111a")
	bg.border_color = Color("22384a")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(3)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("e8b84b")
	fg.border_color = Color("ffe18c")
	fg.border_width_top = 1
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
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
	node.set_meta("micro_reduced",reduced)
	if node.has_meta("micro_bound"):
		if reduced:_scale_to(node,1.0)
		return
	node.set_meta("micro_bound",true)
	node.resized.connect(func():node.pivot_offset=node.size*.5);node.pivot_offset=node.size*.5
	node.mouse_entered.connect(func():_scale_to(node,1.0 if node.disabled else 1.03))
	node.mouse_exited.connect(func():_scale_to(node,1.0))
	node.button_down.connect(func():_scale_to(node,1.0 if node.disabled else .97))
	node.button_up.connect(func():_scale_to(node,1.03 if node.is_hovered() and not node.disabled else 1.0))
static func _scale_to(node: Control,value: float) -> void:
	if not node.is_inside_tree():return
	if node.has_meta("micro_tween"):
		var old: Tween=node.get_meta("micro_tween")
		if is_instance_valid(old):old.kill()
	if bool(node.get_meta("micro_reduced",false)):
		node.scale=Vector2.ONE
		return
	var tween:=node.create_tween();node.set_meta("micro_tween",tween);tween.tween_property(node,"scale",Vector2.ONE*value,.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
static func icon(index: int) -> Texture2D:return part("ui_icons",str(index))
static func utility(key: String) -> Texture2D:return part("ui_controls",str(CONTROL_NAMES.find(key)))
static func skill(identity: String,slot: int) -> Texture2D:
	var key := ArenaDefinitions.resolve_hero_id(identity)
	var s := clampi(slot, 0, 2)
	match key:
		"lord":
			if s == 2: return perk("ironwall")
			return icon(4 if s == 0 else 6)
		"druid":
			return perk(["command", "bloodrage", "fortress"][s])
		"healer":
			return icon(12 + s)
		"werewolf":
			return perk(["lifesteal", "sworddance", "rapid"][s])
		"gunner":
			return icon(8 + s)
	return icon(4 + s)
static func perk(id: String) -> Texture2D:
	var idx: int = int(ICON_ATLAS_INDEX.get(id, -1))
	return part("perk_icons", str(idx)) if idx >= 0 else null
static func creature(key: String) -> Texture2D:
	var lookup := str(ArenaDefinitions.ENEMIES.get(key, {}).get("visual_kind", key))
	for dir_path in ["res://assets/monsters_v029_coast/portrait_", "res://assets/monsters_v029_ruins/portrait_", "res://assets/monsters_v023/portrait_"]:
		var portrait_path: String = dir_path + lookup + ".png"
		if ResourceLoader.exists(portrait_path):
			return load(portrait_path) as Texture2D
	var sheet: Texture2D=load(ArenaCreature.sheet_path(lookup));var image:=AtlasTexture.new();image.atlas=sheet;image.region=Rect2(Vector2.ZERO,sheet.get_size()/Vector2(6,3));return image
