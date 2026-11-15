class_name ArenaPerkCodex
extends Control
# Run-only cards. Colors are categories, never additional purchases or currencies.
signal closed
var selected_id:=""
var filter_id:="all"
var title_label: Label
var meta_label: Label
var body_text: RichTextLabel
var grid: Control
var nodes: Dictionary={}
var filter_buttons: Dictionary={}
const AXES:={"blade":"锋刃","star":"星火","bulwark":"壁垒","command":"号令","bridge":"联动","knight":"骑士","ranger":"游侠","mage":"法师","evo":"进化"}
const COLOURS:={"blade":Color("eeb45b"),"star":Color("64d7ef"),"bulwark":Color("78d796"),"command":Color("ee8176"),"bridge":Color("c39cf3"),"knight":Color("eeb45b"),"ranger":Color("78d796"),"mage":Color("b994ef"),"evo":Color("e4c06c")}
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);mouse_filter=Control.MOUSE_FILTER_STOP
	var backdrop:=TextureRect.new();backdrop.name="CodexScenery";backdrop.texture=ArenaMenuArt.texture("hall_bg");backdrop.size=Vector2(1600,900);backdrop.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;backdrop.stretch_mode=TextureRect.STRETCH_SCALE;backdrop.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(backdrop)
	_label(self,"成长图鉴",Rect2(42,25,650,58),34)
	_button(self,"返回",Rect2(1434,20,120,78),_close,"关闭图鉴")
	for pair in [["all","全部"],["blade","锋刃"],["star","星火"],["bulwark","壁垒"],["command","号令"],["class","职业"],["evo","进化"]]:
		var button:=_button(self,pair[1],Rect2(40+filter_buttons.size()*142,112,130,74),_filter.bind(pair[0]),"CodexFilter_"+pair[0]);filter_buttons[pair[0]]=button
	grid=Control.new();grid.name="CodexGrid";grid.position=Vector2(40,208);grid.size=Vector2(1000,610);add_child(grid)
	var panel:=Panel.new();panel.name="CodexDetails";panel.position=Vector2(1050,112);panel.size=Vector2(515,730);ArenaMenuArt.panel(panel);add_child(panel)
	title_label=_label(panel,"局内成长",Rect2(30,28,455,52),30)
	meta_label=_label(panel,"",Rect2(32,88,451,60),23);meta_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var inset:=Panel.new();inset.position=Vector2(22,162);inset.size=Vector2(471,542);ArenaMenuArt.panel(inset,true);panel.add_child(inset)
	body_text=RichTextLabel.new();body_text.name="CodexDescription";body_text.position=Vector2(22,20);body_text.size=Vector2(427,502);body_text.bbcode_enabled=true;body_text.scroll_active=true;body_text.add_theme_font_size_override("normal_font_size",23);body_text.add_theme_font_size_override("bold_font_size",24);body_text.add_theme_color_override("default_color",ArenaMenuArt.PAPER);inset.add_child(body_text)
	_build_grid();_update_filters();_show_card("power")
func _label(parent: Node,value: String,rect: Rect2,size: int) -> Label:
	var label:=Label.new();label.text=value;label.position=rect.position;label.size=rect.size;label.mouse_filter=Control.MOUSE_FILTER_IGNORE;label.add_theme_font_size_override("font_size",size);label.add_theme_color_override("font_color",ArenaHUD.CREAM);parent.add_child(label);return label
func _button(parent: Node,value: String,rect: Rect2,callback: Callable,key: String) -> Button:
	var button:=Button.new();button.text=value;button.position=rect.position;button.size=rect.size;button.name=key;ArenaMenuArt.button(button);parent.add_child(button)
	var game: ArenaGame=get_parent().get_parent().game if get_parent().get_parent() is ArenaHUD else null
	ArenaMenuArt.interact(button,bool(game.campaign.data.reduced_motion) if game!=null else false)
	button.pressed.connect(callback)
	if game!=null:button.pressed.connect(func():game.audio.play("ui_click",-26,1.4))
	return button
func _filter(key: String) -> void:
	filter_id=key;_build_grid();_update_filters()
	if not nodes.has(selected_id) and not nodes.is_empty():_show_card(str(nodes.keys()[0]))
func _update_filters() -> void:
	for key in filter_buttons:ArenaMenuArt.selected(filter_buttons[key],key==filter_id,COLOURS.get(key,ArenaMenuArt.GOLD))
func _build_grid() -> void:
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	nodes.clear();var index:=0
	for card in ArenaPerks.CARDS:
		if filter_id=="class":
			if str(card.get("hero",""))=="":continue
		elif filter_id!="all" and str(card.axis)!=filter_id:continue
		var id:=str(card.id)
		var button:=_button(grid,"",Rect2(index%8*124,index/8*122,114,112),_show_card.bind(id),"CodexCard_"+id)
		var image:=TextureRect.new();image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.texture=ArenaMenuArt.perk(id);image.position=Vector2(20,7);image.size=Vector2(74,66);image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.mouse_filter=Control.MOUSE_FILTER_IGNORE;button.add_child(image)
		var label:=_label(button,str(card.name),Rect2(3,77,108,29),22);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		button.tooltip_text=str(card.name);button.set_meta("axis",str(card.axis));button.set_meta("rarity",str(card.rarity));nodes[id]=button;index+=1
	_update_cards()
func _update_cards() -> void:
	for id in nodes:
		var button: Button=nodes[id];var tint: Color=COLOURS.get(str(button.get_meta("axis")),ArenaMenuArt.GOLD);var rare:=str(button.get_meta("rarity"))!="common"
		for state in ["normal","hover","pressed","focus"]:
			var style:=ArenaMenuArt.small_style(id==selected_id or state in ["hover","focus"],tint)
			style.border_color=tint if id==selected_id else tint.darkened(.35);style.set_border_width_all(4 if rare or id==selected_id else 2);style.border_width_bottom=5
			if rare:style.bg_color=Color("34314c")
			button.add_theme_stylebox_override(state,style)
func _show_overview() -> void:
	title_label.text="局内成长";meta_label.text="每局重新构筑";body_text.text="点选图标，查看各级效果与联动。"
func _show_card(id: String) -> void:
	var card:=ArenaPerks.card(id)
	if card.is_empty():return
	selected_id=id;title_label.text=str(card.name);meta_label.text=str(AXES.get(card.axis,card.axis))+" · 上限 "+str(card.max)
	var lines: Array[String]=[]
	for index in range(card.ranks.size()):lines.append(str(index+1)+"级  "+str(card.ranks[index]))
	var links:=ArenaPerkNetwork.links_to(id)
	if not links.is_empty():
		lines.append("联动条件")
		for edge in links:
			var other: String=str(edge.to if edge.from==id else edge.from);lines.append(str(ArenaPerks.card(other).get("name",other))+" · "+str(edge.text))
	var sets: Array[String]=[]
	for item in ArenaPerks.SETS:
		if (item.has("members") and id in item.members) or (item.has("axis") and str(item.axis)==str(card.axis)):sets.append(str(item.name))
	if not sets.is_empty():lines.append("套装\n"+"、".join(sets))
	body_text.text="\n\n".join(lines);body_text.scroll_to_line(0);_update_cards()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_ESCAPE:
		get_viewport().set_input_as_handled();_close()
func _close() -> void:closed.emit();queue_free()
