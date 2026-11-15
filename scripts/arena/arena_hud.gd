class_name ArenaHUD
extends CanvasLayer
var game: ArenaGame
var root: Control
var menu: Control
var modal: Control
var context: Panel
var wave_button: Button
var wave_glyph: ArenaGlyph
var preview: Panel
var hero_badge: TextureRect
var hero_health: ArenaMeter
var core_health: ArenaMeter
var experience: ArenaMeter
var coins: Label
var wave_label: Label
var hero_level: Label
var revival: Label
var tokens: Label
var token_glyph: ArenaGlyph
var debuff: Label
var unlock_hint: Panel
var unlock_clock:=0.0
var objective: Panel
var objective_step: Label
var objective_title: Label
var objective_body: Label
var phase_label: Label
var xp_label: Label
var build_label: Label
var last_objective:=""
var tutorial_finished:=false
var skills: Array[Button]=[]
var skill_glyphs: Array[ArenaGlyph]=[]
var battle_nodes: Array=[]
var update_clock:=0.0
var selected_hero: String="knight"
var frontend: ArenaFrontEnd
const CREAM:=Color("f2e4c5")
const GOLD:=Color("e9c588")
const MUTED:=Color("bbbea1")
const INK:=Color("17241e")
const COPPER:=Color("b88943")
const PANEL:=Color("1c3027f2")
var codex: ArenaPerkCodex
var codex_was_paused:=false
const AXIS_NAME:={"blade":"锋刃","star":"星火","bulwark":"壁垒","command":"号令","evo":"进化","knight":"骑士","ranger":"游侠","mage":"法师","bridge":"桥接"}
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	context=Panel.new();context.hide();context.mouse_filter=Control.MOUSE_FILTER_STOP;root.add_child(context);panel_style(context)
	frontend=ArenaFrontEnd.new(self)
func panel_style(node: Control,light:=false) -> void:
	var style:=StyleBoxFlat.new();style.bg_color=Color("ead8b3") if light else PANEL;style.border_color=Color("ad9362")
	style.set_border_width_all(1);style.set_corner_radius_all(12);style.shadow_color=Color(0,0,0,0.32);style.shadow_size=8
	node.add_theme_stylebox_override("panel",style)
func label(parent: Node,message: String,rect: Rect2,size:=18,colour:=CREAM) -> Label:
	var node:=Label.new();node.position=rect.position;node.size=rect.size;node.text=message;node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",size);node.add_theme_color_override("font_color",colour);parent.add_child(node);return node
func button(parent: Node,message: String,rect: Rect2,callback: Callable) -> Button:
	var node:=Button.new();node.position=rect.position;node.size=rect.size;node.text=message;node.focus_mode=Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size",18);node.add_theme_color_override("font_color",CREAM)
	for state in ["normal","hover","pressed","disabled"]:
		var style:=StyleBoxFlat.new();style.bg_color={"normal":Color("3d4d35"),"hover":Color("59633d"),"pressed":Color("293b2a"),"disabled":Color("353c30")}[state]
		style.border_color=GOLD if state=="hover" else Color("7a7c51");style.set_border_width_all(1);style.set_corner_radius_all(8);node.add_theme_stylebox_override(state,style)
	node.pressed.connect(func():game.suppress_primary=true;callback.call());parent.add_child(node);return node
func icon(parent: Node,key: String,rect: Rect2,tint:=GOLD) -> ArenaGlyph:
	var node:=ArenaGlyph.new();node.kind=key;node.position=rect.position;node.size=rect.size;node.tint=tint;parent.add_child(node);return node
func image(parent: Node,texture: Texture2D,rect: Rect2,cover:=false) -> TextureRect:
	var node:=TextureRect.new();node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.texture=texture;node.position=rect.position;node.size=rect.size
	node.stretch_mode=TextureRect.STRETCH_SCALE if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(node);return node
func colour_block(parent: Node,rect: Rect2,colour: Color) -> ColorRect:
	var node:=ColorRect.new();node.position=rect.position;node.size=rect.size;node.color=colour;node.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(node);return node
func entry_button(message: String,rect: Rect2,callback: Callable,glyph: String,primary:=false) -> Button:
	var node:=button(menu,message,rect,callback);node.name=message;node.alignment=HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_constant_override("icon_max_width",34);node.add_theme_constant_override("h_separation",16);node.add_theme_font_size_override("font_size",22)
	for state in ["normal","hover","pressed","disabled"]:
		var style:=StyleBoxFlat.new()
		style.bg_color=({"normal":Color("b88943"),"hover":Color("d1a55d"),"pressed":Color("8d6835"),"disabled":Color("6d6a59")}[state] if primary else {"normal":Color("263a30e8"),"hover":Color("3c5543f2"),"pressed":Color("1c2d25f2"),"disabled":Color("26312be0")}[state])
		style.border_color=Color("f0d59c") if state=="hover" else Color("8e805f")
		style.set_border_width_all(1);style.set_corner_radius_all(6);style.content_margin_left=68;node.add_theme_stylebox_override(state,style)
	node.add_theme_color_override("font_color",INK if primary else CREAM);node.add_theme_color_override("font_hover_color",INK if primary else Color.WHITE)
	icon(node,glyph,Rect2(18,15,32,32),INK if primary else GOLD)
	return node
func meter(parent: Node,rect: Rect2,colour: Color) -> ArenaMeter:
	var node:=ArenaMeter.new();node.position=rect.position;node.size=rect.size
	var bg:=StyleBoxFlat.new();bg.bg_color=Color("23372d");bg.set_corner_radius_all(4)
	var fg:=StyleBoxFlat.new();fg.bg_color=colour;fg.set_corner_radius_all(4)
	node.add_theme_stylebox_override("background",bg);node.add_theme_stylebox_override("fill",fg);parent.add_child(node);return node
func hero_portrait(key: String) -> Texture2D:
	return ArenaHeroArt.portrait(key,game.feel.enabled)
func hero_badge_image(key: String) -> Texture2D:
	var portrait:=hero_portrait(key);var atlas:=AtlasTexture.new();atlas.atlas=portrait
	var ratio:=ArenaHeroArt.badge(key,game.feel.enabled);atlas.region=Rect2(ratio.position*portrait.get_size(),ratio.size*portrait.get_size());return atlas
func tower_image(kind: String,tier:=1) -> Texture2D:
	var sheet: Texture2D=load(ArenaBattleArt.towers_path());var atlas:=AtlasTexture.new();atlas.atlas=sheet
	atlas.region=Rect2(ArenaDefinitions.TOWER_IDS.find(kind)*sheet.get_width()/4.0,(tier-1)*sheet.get_height()/3.0,sheet.get_width()/4.0,sheet.get_height()/3.0);return atlas
func reset_menu() -> void:
	if is_instance_valid(menu):root.remove_child(menu);menu.queue_free()
	menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.mouse_filter=Control.MOUSE_FILTER_STOP;root.add_child(menu)
func backdrop() -> void:
	var path: String=ArenaBattleArt.map_path("forest")
	if ResourceLoader.exists(path):image(menu,load(path),Rect2(Vector2.ZERO,Vector2(1600,900)),true).modulate=Color(0.56,0.59,0.5)
	else:
		var bg:=ColorRect.new();bg.color=Color("607447");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(bg)
func show_codex() -> void:
	if is_instance_valid(codex) or game.choice_open or game.camp_reward_open:
		return
	codex_was_paused=get_tree().paused
	get_tree().paused=true
	codex = ArenaPerkCodex.new()
	root.add_child(codex)
	codex.closed.connect(_on_codex_closed)
func _on_codex_closed() -> void:
	codex = null
	get_tree().paused=codex_was_paused
	game.suppress_primary=true
	if not codex_was_paused:game.pump_modals()
func show_entry() -> void:frontend.entry()
func show_heroes() -> void:frontend.hall()
func show_levels(_key: String="") -> void:frontend.levels()
func show_battle() -> void:
	if is_instance_valid(menu):menu.queue_free()
	var bar:=Panel.new();bar.position=Vector2.ZERO;bar.size=Vector2(1600,86);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel_style(bar);root.add_child(bar);battle_nodes.append(bar)
	hero_badge=image(bar,hero_badge_image(game.hero.class_id),Rect2(8,3,68,78))
	hero_health=meter(bar,Rect2(84,22,180,13),Color("d87d73"));experience=meter(bar,Rect2(84,58,180,5),Color("c6d899"));hero_level=label(bar,"Lv.1",Rect2(271,18,58,32),18,GOLD)
	xp_label=label(bar,"0 / 80",Rect2(176,62,90,17),11,MUTED);xp_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	icon(bar,"heart",Rect2(84,38,15,15),Color("d87d73"));revival=label(bar,"",Rect2(27,25,55,35),24,GOLD)
	icon(bar,"coin",Rect2(315,23,36,36));coins=label(bar,str(game.gold),Rect2(356,25,96,32),24,GOLD)
	token_glyph=icon(bar,"upgrade",Rect2(622,25,30,34));tokens=label(bar,"",Rect2(658,27,110,32),20,GOLD)
	debuff=label(bar,"",Rect2(1030,28,155,30),16,Color("e7a28a"))
	for slot in range(2):
		var b:=button(bar,"",Rect2(465+slot*78,10,64,64),game.request_skill.bind(slot));b.name="Skill_"+str(slot);skills.append(b)
		var kind: String={"knight":["physical","flag"],"ranger":["move","rain"],"mage":["frost","meteor"]}[game.hero.class_id][slot]
		skill_glyphs.append(icon(b,kind,Rect2(15,6,34,37),ArenaCombat.colour(game.hero.data.type)))
		label(b,"Q" if slot==0 else "E",Rect2(9,45,55,17),12,MUTED)
		b.tooltip_text=str(game.hero.data.small if slot==0 else game.hero.data.ultimate)+"\n"+ArenaDefinitions.skill_text(game.hero.class_id,slot)
	wave_button=button(bar,"",Rect2(770,7,60,60),game.request_wave);wave_button.name="CallWave";wave_button.tooltip_text="预览下一波；再点提前开始"
	wave_glyph=icon(wave_button,"wave",Rect2(12,10,36,36));wave_label=label(bar,"第 1 / 8 波",Rect2(850,17,150,30),22)
	phase_label=label(bar,"整备阶段",Rect2(850,48,180,22),14,MUTED)
	icon(bar,"core",Rect2(1195,22,34,40),Color("9de0cf"));core_health=meter(bar,Rect2(1240,29,225,13),Color("96c8a0"))
	var pause:=button(bar,"Ⅱ",Rect2(1516,18,55,50),show_pause);pause.name="Pause"
	preview=Panel.new();preview.position=Vector2(665,98);preview.size=Vector2(390,104);preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel_style(preview);preview.hide();root.add_child(preview)
	objective=Panel.new();objective.position=Vector2(28,112);objective.size=Vector2(355,132);objective.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(objective);panel_style(objective)
	objective_step=label(objective,"守望指引",Rect2(20,13,115,22),14,GOLD)
	objective_title=label(objective,"部署第一座防御塔",Rect2(20,39,315,29),21,CREAM)
	objective_body=label(objective,"点击道路旁的金色塔位，然后选择建筑。",Rect2(20,75,315,45),15,MUTED);objective_body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var build:=Panel.new();build.position=Vector2(1260,106);build.size=Vector2(306,54);build.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(build);panel_style(build)
	icon(build,"upgrade",Rect2(12,12,28,28),GOLD);build_label=label(build,"本局成长 · 尚未获得",Rect2(50,14,240,25),15,MUTED)
	root.move_child(context,root.get_child_count()-1)
func show_context(index: int) -> void:
	game.selected_site=index;refresh_context()
func clear_children(node: Node) -> void:
	for child in node.get_children():node.remove_child(child);child.queue_free()
func refresh_context() -> void:
	if game.selected_site<0:return
	clear_children(context);context.show()
	var tower: ArenaTower=game.site_tower(game.selected_site)
	if tower!=null and tower.awaiting_doctrine:
		doctrine_context(tower);return
	var locked:=tower==null and game.site_locked(game.selected_site)
	context.size=Vector2(320,170) if locked else (Vector2(365,165) if tower==null else Vector2(300,225))
	var point: Vector2=game.level_definition.sites[game.selected_site]
	context.position=Vector2(clampf(point.x-context.size.x*0.5,12,1600-context.size.x-12),clampf(point.y+38,100,900-context.size.y-15))
	if locked:
		var price:=game.unlock_price(game.selected_site)
		label(context,"锁定塔位",Rect2(15,10,280,30),20,GOLD)
		var unlock:=button(context,"解锁    %d  ◉"%price,Rect2(15,48,290,48),game.unlock_site.bind(game.selected_site));unlock.name="UnlockSite";unlock.disabled=game.gold<price
		label(context,"本图仅 1 个额外火力点",Rect2(15,104,290,26),14,MUTED)
		label(context,"解锁后可正常建造或出售",Rect2(15,128,290,26),14,MUTED)
	elif tower==null:
		label(context,"建造",Rect2(15,8,250,28),19,GOLD)
		for column in range(game.run_towers.size()):
			var key: String=game.run_towers[column];var data: Dictionary=ArenaDefinitions.TOWERS[key]
			var b:=button(context,"",Rect2(14+column*86,44,78,105),_build.bind(key));b.name="Build_"+key;b.disabled=key not in game.available_towers() or game.gold<int(data.cost)
			image(b,tower_image(key),Rect2(4,1,70,70));icon(b,"coin",Rect2(11,78,18,18));label(b,str(data.cost),Rect2(33,77,40,22),16,GOLD)
			b.tooltip_text=data.name+" · "+ArenaCombat.label(data.type)+"\n"+data.description+("\n第"+str(game.level_definition.towers[key])+"波开放" if key not in game.available_towers() else "")
	else:
		var subtitle:=str(tower.data.description)
		if tower.doctrine_id!="":
			var entry: Dictionary=ArenaDoctrines.by_id(tower.doctrine_id)
			subtitle=str(entry.name)+" · "+str(entry.role)
		label(context,str(tower.data.name)+"  "+str(tower.level)+"/3",Rect2(17,10,260,32),21,GOLD)
		icon(context,"physical" if tower.data.type==0 else "magic",Rect2(18,49,23,23),ArenaCombat.colour(tower.data.type));label(context,ArenaCombat.label(tower.data.type)+" · "+subtitle,Rect2(50,47,245,28),15,MUTED)
		var price:=tower.upgrade_price();var token:=game.doctrine_tokens>0 and tower.level==2
		var caption: String="免费 L3 改造（剩 %d）"%game.doctrine_tokens if token else ("↑    %d  ◉"%price if tower.level<3 else "已满级")
		var up:=button(context,caption,Rect2(15,87,268,45),tower.upgrade.bind("",true) if token else tower.upgrade)
		up.name="Upgrade";up.disabled=tower.level>=3 or (not token and game.gold<price)
		var target:=button(context,"⚑" if tower.kind=="barracks" else "◎",Rect2(15,148,76,44),_rally if tower.kind=="barracks" else _target);target.tooltip_text="调整集结点" if tower.kind=="barracks" else "切换优先目标"
		button(context,"出售",Rect2(105,148,80,44),tower.sell)
		button(context,"×",Rect2(205,148,78,44),close_context)
func doctrine_context(tower: ArenaTower) -> void:
	var options: Array=ArenaDoctrines.for_tower(tower.kind)
	context.size=Vector2(500,304)
	var point: Vector2=game.level_definition.sites[tower.site_id]
	context.position=Vector2(clampf(point.x-context.size.x*0.5,12,1600-context.size.x-12),clampf(point.y+38,100,900-context.size.y-15))
	label(context,"L3 改造 · 三选一",Rect2(15,7,300,30),20,GOLD)
	label(context,"选择后永久生效，不随机、不重掷",Rect2(250,12,238,22),12,MUTED)
	for index in range(options.size()):
		var entry: Dictionary=options[index]
		var card:=button(context,"",Rect2(12+index*162,42,150,246),game.choose_doctrine.bind(tower.site_id,str(entry.id)))
		card.name="Doctrine_"+str(entry.id)
		label(card,str(entry.name),Rect2(10,8,130,30),19,GOLD)
		label(card,str(entry.role),Rect2(10,38,130,22),12,Color("9fc7b3"))
		var body:=label(card,str(entry.summary),Rect2(10,64,130,120),13,CREAM)
		body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label(card,"代价："+str(entry.drawback),Rect2(10,188,130,46),12,Color("e7a28a"))
func _build(key: String) -> void:
	if game.build_tower(game.selected_site,key):refresh_context()
func _rally() -> void:game.rally_site=game.selected_site;close_context()
func _target() -> void:
	var tower:=game.site_tower(game.selected_site)
	if tower!=null and tower.forced_target()=="":
		tower.target_mode="strongest" if tower.target_mode=="first" else "first";refresh_context()
func close_context() -> void:context.hide();game.selected_site=-1
func refresh_tokens() -> void:
	if not is_instance_valid(tokens):return
	tokens.text="改造 "+str(game.doctrine_tokens) if game.doctrine_tokens>0 else ""
	if is_instance_valid(token_glyph):token_glyph.modulate.a=1.0 if game.doctrine_tokens>0 else 0.25
func announce_unlock() -> void:
	if not game.started:return
	var unlocked: Array=[]
	for key in game.available_towers():
		if int(game.level_definition.towers[key])==game.cycle:unlocked.append(key)
	if unlocked.is_empty():return
	if not is_instance_valid(unlock_hint):
		unlock_hint=Panel.new();unlock_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(unlock_hint);panel_style(unlock_hint)
	clear_children(unlock_hint);unlock_hint.position=Vector2(665,105);unlock_hint.size=Vector2(48+unlocked.size()*66,75);unlock_hint.show();unlock_clock=3.5
	icon(unlock_hint,"upgrade",Rect2(10,22,27,32))
	for i in range(unlocked.size()):image(unlock_hint,tower_image(unlocked[i]),Rect2(45+i*66,4,64,64))
func modal_panel(size: Vector2) -> Panel:
	close_modal();modal=Control.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.mouse_filter=Control.MOUSE_FILTER_STOP;root.add_child(modal)
	var veil:=ColorRect.new();veil.color=Color(0.06,0.12,0.08,0.66);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_child(veil)
	var panel:=Panel.new();panel.size=size;panel.position=(Vector2(1600,900)-size)*0.5;modal.add_child(panel);panel_style(panel);return panel
func close_modal() -> void:
	if is_instance_valid(modal):root.remove_child(modal);modal.queue_free()
	modal=null
func has_modal() -> bool:return is_instance_valid(modal) or is_instance_valid(codex)
func show_choices(keys: Array[String]) -> void:
	close_context();game.targeting_slot=-1;game.rally_site=-1
	var panel:=modal_panel(Vector2(1040,470));label(panel,"选择一份成长",Rect2(360,22,500,45),29,GOLD)
	label(panel,"本局生效 · 升级或选择营地的英雄奖励时获得",Rect2(300,65,650,28),16,MUTED)
	for index in range(keys.size()):
		var key: String=keys[index];var data: Dictionary=ArenaPerks.card(key)
		var rank:=game.hero.perk(key);var next:=mini(rank+1,int(data.max))
		var colour: Color=data.get("color",GOLD)
		var b:=button(panel,"",Rect2(30+index*335,108,310,265),game.choose_perk.bind(key));b.name="Perk_"+key
		label(b,str(index+1),Rect2(16,12,28,28),16,MUTED)
		icon(b,str(data.icon),Rect2(125,20,60,60),colour)
		label(b,data.name,Rect2(24,84,262,34),24,colour)
		label(b,"%s · %d/%d" % [AXIS_NAME.get(str(data.axis),str(data.axis)),next,int(data.max)],Rect2(24,118,262,24),15,MUTED)
		var lines: Array=data.ranks
		var effect:=label(b,str(lines[mini(next-1,lines.size()-1)]),Rect2(24,148,262,54),16,CREAM)
		effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		if str(data.get("hint",""))!="":
			label(b,str(data.hint),Rect2(24,208,262,24),14,GOLD if bool(data.get("evolution",false)) else MUTED)
		if bool(data.get("evolution",false)):
			label(b,"进化",Rect2(238,16,58,24),14,GOLD)
		var peers: Array[String]=[]
		for edge in ArenaPerks.LINKS:
			if edge.from == key or edge.to == key:
				var other: String = str(edge.to) if edge.from == key else str(edge.from)
				var owned:=game.hero.perk(other)>0
				var tag: String=""
				peers.append(str(ArenaPerks.card(other).get("name",other))+("✓" if owned else "")+tag)
		if not peers.is_empty():
			var link_colour:=Color("9fc7b3") if game.hero.perk(key)>0 else MUTED
			var links:=label(b,"联动：%s" % "、".join(peers),Rect2(24,230,262,24),11,link_colour)
			links.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
			b.tooltip_text="联动："+"、".join(peers)
func show_camp_reward(id: int) -> void:
	close_context();get_tree().paused=true
	var panel:=modal_panel(Vector2(1080,470))
	label(panel,"营地已清 · 三选一",Rect2(380,24,420,50),30,GOLD)
	label(panel,"不自动给金币或英雄卡，选一项带走",Rect2(400,74,400,26),15,MUTED)
	var l2:=game.l2_count()
	var options: Array=[
		{"key":"hero","title":"英雄","body":"获得一次英雄成长三选一。\n强化本局英雄与防线联动。","foot":"英雄等级 "+str(game.hero.level)},
		{"key":"token","title":"防御","body":"获得 1 枚免费三级改造券，本局保留。\n任意二级塔升级时免费使用。","foot":"当前二级塔 "+str(l2)+" 座"+("" if l2>0 else " · 可留到之后使用")},
		{"key":"gold","title":"经济","body":"立即获得 100 金币。\n可建造、升级或留作 L3。","foot":"当前金币 "+str(game.gold)}]
	for index in range(options.size()):
		var option: Dictionary=options[index]
		var card:=button(panel,"",Rect2(40+index*340,108,320,310),game.choose_camp_reward.bind(id,str(option.key)))
		card.name="CampReward_"+str(option.key)
		label(card,str(option.title),Rect2(22,16,276,42),26,GOLD)
		var body:=label(card,str(option.body),Rect2(22,74,276,160),16,CREAM)
		body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label(card,str(option.foot),Rect2(22,250,276,40),14,Color("9fc7b3"))
func show_pause() -> void:
	if game.choice_open or game.camp_reward_open or game.game_over:return
	if has_modal():resume();return
	get_tree().paused=true;close_context();game.targeting_slot=-1;game.rally_site=-1
	var panel:=modal_panel(Vector2(760,510));label(panel,"守望手册",Rect2(280,27,450,50),32,GOLD)
	label(panel,"移动与战斗",Rect2(65,96,300,30),18,GOLD)
	label(panel,"WASD / 右键移动   ·   按住左键普攻\nQ 小技能（英雄2级） · E 大招（英雄4级）",Rect2(65,132,650,82),21)
	label(panel,"防线与成长",Rect2(65,232,300,30),18,GOLD)
	label(panel,"点塔位建造，点建筑升级与调度\n清理营地、积累经验，三选一强化本局英雄",Rect2(65,268,650,84),20)
	var codex_button:=button(panel,"被动图鉴",Rect2(260,350,240,40),show_codex);codex_button.name="被动图鉴"
	button(panel,"继续",Rect2(55,420,280,55),resume);button(panel,"返回地图",Rect2(420,420,280,55),game.return_to_menu)
func resume() -> void:
	get_tree().paused=false;close_modal();game.suppress_primary=true
	game.pump_modals()
func show_guide() -> void:
	var panel:=modal_panel(Vector2(800,540));label(panel,"新任守望者指南",Rect2(238,27,500,50),32,GOLD)
	label(panel,"1  部署",Rect2(65,102,150,30),18,GOLD);label(panel,"在固定塔位建设防线，金币用于建造与升级。",Rect2(210,102,520,30),19)
	label(panel,"2  出战",Rect2(65,158,150,30),18,GOLD);label(panel,"英雄拦截、躲避投射物；养成可解锁双技能。",Rect2(210,158,520,30),19)
	label(panel,"3  成长",Rect2(65,214,150,30),18,GOLD);label(panel,"升级选成长，清营选奖励；三级塔可选择改造。",Rect2(210,214,520,30),19)
	colour_block(panel,Rect2(65,269,670,1),Color("e9c58855"))
	label(panel,"物理",Rect2(65,295,90,28),18,ArenaCombat.colour(0));label(panel,"弓箭、火炮、骑士、游侠与士兵",Rect2(160,295,520,28),18)
	label(panel,"法术",Rect2(65,337,90,28),18,ArenaCombat.colour(1));label(panel,"法师与法师塔；适合对付重甲敌人",Rect2(160,337,520,28),18)
	label(panel,"英雄倒下会在 15 秒后复活；只有基地失守才会失败。",Rect2(65,390,670,30),17,MUTED)
	button(panel,"开始守望",Rect2(240,453,320,55),close_modal)
func show_result() -> void:
	close_context();var panel:=modal_panel(Vector2(700,455));label(panel,"防线守住了" if game.victory else "信标失守",Rect2(225,30,500,60),36,GOLD)
	label(panel,"本局战报",Rect2(70,110,160,30),17,GOLD);colour_block(panel,Rect2(70,145,560,1),Color("e9c58855"))
	label(panel,"抵达波次",Rect2(70,165,140,25),15,MUTED);label(panel,str(game.cycle)+" / 8",Rect2(70,191,140,32),23)
	label(panel,"击败敌人",Rect2(255,165,140,25),15,MUTED);label(panel,str(game.kills),Rect2(255,191,140,32),23)
	label(panel,"本局等级",Rect2(440,165,140,25),15,MUTED);label(panel,"Lv."+str(game.hero.level),Rect2(440,191,140,32),23)
	label(panel,"建造 "+str(game.built)+" 座防御塔   ·   清理营地 "+str(game.camps_cleared)+" / 2",Rect2(70,247,560,30),18,MUTED)
	icon(panel,"diamond",Rect2(70,290,30,30),Color("8bdadf"))
	var saved:=bool(game.settlement.get("ok",false))
	label(panel,("+"+str(game.settlement.get("amount",0))+"    合计 "+str(game.campaign.gems())) if saved else "奖励尚未保存",Rect2(112,288,490,32),20,GOLD)
	if not saved:
		var save_button:=button(panel,"重试保存",Rect2(470,282,160,38),game.retry_settlement);save_button.name="RetrySave"
	var hall:=button(panel,"英雄养成",Rect2(40,350,190,60),game.open_hero_hall);hall.name="ResultHeroHall"
	var retry:=button(panel,"再次出战",Rect2(255,350,190,60),game.restart_run);retry.name="RetryRun"
	button(panel,"返回地图",Rect2(470,350,190,60),game.return_to_menu)

func objective_state() -> Dictionary:
	if game.built==0:return {"step":"守望指引 · 1 / 3","title":"部署第一座防御塔","body":"点击道路旁的金色塔位，然后选择建筑。"}
	if game.phase=="rest" and game.cycle==1:return {"step":"守望指引 · 2 / 3","title":"侦察第一波敌人","body":"点击顶部怪物图标预览，再点一次提前开波。"}
	if game.cycle==1:return {"step":"守望指引 · 3 / 3","title":"英雄加入防守","body":"WASD / 右键移动，按住左键攻击；技能在英雄2级、4级解锁。"}
	if game.camps_cleared<game.camps.size():
		if game.cycle<2:return {"step":"当前目标","title":"准备迎接营地威胁","body":"第2波营地激活；调度英雄，兼顾主路。"}
		if game.overdue_camps()>0:return {"step":"营地警报","title":"解除全场图腾压制","body":"清除营地守卫后，选择成长、改造券或金币。"}
		return {"step":"当前目标","title":"清理精英营地","body":"第4波威胁扩散，第5波派出突袭队；清营后三选一。"}
	if game.phase=="rest":return {"step":"整备阶段","title":"升级防线，准备第 "+str(game.cycle)+" 波","body":"利用金币升级塔；提前开波基础奖励至多12金币，成长可提升。"}
	return {"step":"防守阶段","title":"守住第 "+str(game.cycle)+" 波","body":"观察敌人抗性，英雄随时回防；基地失守才会失败。"}

func refresh_objective() -> void:
	if not is_instance_valid(objective):return
	if not tutorial_finished and game.built>0 and game.hero.shots>0 and game.phase!="rest":
		tutorial_finished=true;game.campaign.complete_tutorial()
	objective.visible=not tutorial_finished and not bool(game.campaign.data.get("tutorial_done",false)) and game.cycle==1
	var state:=objective_state();var signature: String=str(state.step)+str(state.title)
	if signature!=last_objective:
		last_objective=signature;objective_step.text=state.step;objective_title.text=state.title;objective_body.text=state.body
	var summary: Array[String]=[]
	for key in game.hero.perks:
		var rank: int=game.hero.perk(key)
		if rank>0:summary.append(str(ArenaPerks.card(str(key)).name)+" "+str(rank))
	build_label.text="本局成长 · "+("尚未获得" if summary.is_empty() else "  ".join(summary.slice(0,3)))
	build_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	build_label.tooltip_text="\n".join(summary)
func _input(event: InputEvent) -> void:
	if is_instance_valid(codex):return
	if not game.started and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and is_instance_valid(frontend.stage_panel):
		if not frontend.stage_panel.get_global_rect().has_point(event.position):frontend.close_stage()
	if not (event is InputEventKey and event.pressed and not event.echo):return
	if game.choice_open:
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			var index: int=event.keycode-KEY_1
			if index<game.choices.size():game.choose_perk(game.choices[index])
			get_viewport().set_input_as_handled()
		return
	if not game.started:
		if event.keycode==KEY_ESCAPE:frontend.escape();get_viewport().set_input_as_handled()
		return
	if game.camp_reward_open:
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			var keys:=["hero","token","gold"]
			game.choose_camp_reward(game.open_camp_id,keys[event.keycode-KEY_1])
		get_viewport().set_input_as_handled()
		return
	if event.keycode==KEY_H or (event.keycode==KEY_ESCAPE and has_modal() and not game.game_over):
		if has_modal():resume()
		else:show_pause()
		get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if unlock_clock>0:
		unlock_clock-=delta
		if is_instance_valid(unlock_hint):unlock_hint.visible=unlock_clock>0 and not game.wave_preview
	update_clock-=delta
	if update_clock>0 or not game.started or hero_health==null:return
	update_clock=0.08
	var h: ArenaHero=game.hero
	hero_badge.tooltip_text="英雄养成 Lv."+str(h.meta_level)+" · 本局成长 Lv."+str(h.level)
	hero_health.max_value=h.max_health;hero_health.value=h.health;hero_health.tooltip_text=str(int(h.health))+" / "+str(int(h.max_health))
	experience.max_value=h.xp_target;experience.value=h.xp;hero_level.text="Lv."+str(h.level);xp_label.text=str(h.xp)+" / "+str(h.xp_target)
	core_health.max_value=game.core_max;core_health.value=game.core_health;core_health.tooltip_text=str(int(game.core_health))+" / "+str(int(game.core_max))
	coins.text=str(game.gold);revival.text=str(int(ceil(h.revive_clock))) if h.knocked_out else "";hero_badge.modulate=Color(0.6,0.6,0.6) if h.knocked_out else Color.WHITE
	refresh_tokens();var siege:=game.overdue_camps()
	debuff.text=("图腾压制 ×%d"%siege) if siege>0 else ""
	for slot in range(2):
		var unlocked:=h.skill_unlocked(slot)
		skills[slot].disabled=not unlocked or h.knocked_out or h.cooldowns[slot]>0 or game.game_over
		skills[slot].text=(str(int(ceil(h.cooldowns[slot]))) if h.cooldowns[slot]>0 else "") if unlocked else str(2 if slot==0 else 4)+"级"
		skills[slot].tooltip_text=(str(h.data.small if slot==0 else h.data.ultimate)+"\n"+ArenaDefinitions.skill_text(h.class_id,slot)) if unlocked else "英雄养成至"+str(2 if slot==0 else 4)+"级解锁"
		var maximum: float=float(h.data.small_cd if slot==0 else h.data.ultimate_cd)*h.cooldown_scale()
		skill_glyphs[slot].progress=1.0-h.cooldowns[slot]/maximum if unlocked else 0.0;skill_glyphs[slot].modulate.a=0.18 if not unlocked else (0.45 if h.cooldowns[slot]>0 else 1.0);skill_glyphs[slot].queue_redraw()
	wave_label.text="第 "+str(game.cycle)+" / 8 波";wave_button.disabled=game.phase!="rest" or game.game_over
	phase_label.text=("整备 · "+str(int(ceil(game.phase_clock)))+" 秒" if game.phase=="rest" else "敌军来袭")
	wave_glyph.progress=game.phase_clock/game.rest_duration if game.phase=="rest" else 1.0;wave_glyph.tint=GOLD if game.wave_preview else CREAM;wave_glyph.queue_redraw()
	refresh_objective()
	if preview.visible!=game.wave_preview:
		preview.visible=game.wave_preview
		if preview.visible:
			clear_children(preview)
			var pool: Array=[]
			for group in ArenaLevelCatalog.wave(game.level_id,game.cycle).units:pool.append(group[0])
			if game.cycle==8 and game.level_definition.boss:pool.append("moth")
			for index in range(pool.size()):
				var path: String="res://assets/v06/creature_"+pool[index]+".png"
				if ResourceLoader.exists(path):
					var sheet: Texture2D=load(path);var frame:=AtlasTexture.new();frame.atlas=sheet;frame.region=Rect2(0,0,sheet.get_width()/6.0,sheet.get_height()/3.0);image(preview,frame,Rect2(8+index*61,5,58,62))
			var profile:=ArenaLevelCatalog.wave_profile(game.level_id,game.cycle)
			label(preview,"重甲 %d%% · 高法抗 %d%% · 精英 %d" % [int(round(profile.heavy*100.0)),int(round(profile.high_res*100.0)),int(profile.elites)],Rect2(10,72,300,26),14,MUTED)
