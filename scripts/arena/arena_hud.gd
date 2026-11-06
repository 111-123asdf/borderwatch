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
var unlock_hint: Panel
var unlock_clock:=0.0
var skills: Array[Button]=[]
var skill_glyphs: Array[ArenaGlyph]=[]
var battle_nodes: Array=[]
var update_clock:=0.0
var selected_hero: String="knight"
var selected_growth: String="knight"
const CREAM:=Color("f2e4c5")
const GOLD:=Color("e9c588")
const MUTED:=Color("bbbea1")
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	context=Panel.new();context.hide();context.mouse_filter=Control.MOUSE_FILTER_STOP;root.add_child(context);panel_style(context)
func panel_style(node: Control,light:=false) -> void:
	var style:=StyleBoxFlat.new();style.bg_color=Color("ead8b3") if light else Color("25392def");style.border_color=Color("957c50")
	style.set_border_width_all(2);style.set_corner_radius_all(10);style.shadow_color=Color(0,0,0,0.25);style.shadow_size=5
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
func meter(parent: Node,rect: Rect2,colour: Color) -> ArenaMeter:
	var node:=ArenaMeter.new();node.position=rect.position;node.size=rect.size
	var bg:=StyleBoxFlat.new();bg.bg_color=Color("23372d");bg.set_corner_radius_all(4)
	var fg:=StyleBoxFlat.new();fg.bg_color=colour;fg.set_corner_radius_all(4)
	node.add_theme_stylebox_override("background",bg);node.add_theme_stylebox_override("fill",fg);parent.add_child(node);return node
func hero_portrait(key: String) -> Texture2D:
	return load("res://assets/v06/portrait_"+key+".png")
func hero_badge_image(key: String) -> Texture2D:
	var portrait:=hero_portrait(key);var atlas:=AtlasTexture.new();atlas.atlas=portrait
	var region: Dictionary={"knight":Rect2(0.43,0.06,0.42,0.34),"ranger":Rect2(0.25,0.12,0.44,0.34),"mage":Rect2(0.23,0.04,0.51,0.4)}
	var ratio: Rect2=region[key];atlas.region=Rect2(ratio.position*portrait.get_size(),ratio.size*portrait.get_size());return atlas
func tower_image(kind: String,tier:=1) -> Texture2D:
	if not ResourceLoader.exists("res://assets/v06/towers.png"):return null
	var sheet: Texture2D=load("res://assets/v06/towers.png");var atlas:=AtlasTexture.new();atlas.atlas=sheet
	atlas.region=Rect2(ArenaDefinitions.TOWER_IDS.find(kind)*sheet.get_width()/4.0,(tier-1)*sheet.get_height()/3.0,sheet.get_width()/4.0,sheet.get_height()/3.0);return atlas
func reset_menu() -> void:
	if is_instance_valid(menu):menu.queue_free()
	menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.mouse_filter=Control.MOUSE_FILTER_STOP;root.add_child(menu)
func backdrop() -> void:
	var path: String="res://assets/v06/map_forest.png"
	if ResourceLoader.exists(path):image(menu,load(path),Rect2(Vector2.ZERO,Vector2(1600,900)),true).modulate=Color(0.56,0.59,0.5)
	else:
		var bg:=ColorRect.new();bg.color=Color("607447");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(bg)
func show_entry() -> void:
	reset_menu();backdrop()
	var title:=label(menu,"边境守望",Rect2(105,155,700,100),64,GOLD);title.add_theme_constant_override("outline_size",8);title.add_theme_color_override("font_outline_color",Color("243124"))
	label(menu,"守住微光，走向森林深处。",Rect2(110,265,600,42),24)
	var y:=355
	for spec in [["开始守望",show_heroes],["英雄训练",show_growth],["如何游玩",show_guide],["退出游戏",game.quit_game]]:
		var node:=button(menu,spec[0],Rect2(110,y,350,70),spec[1]);node.name=str(spec[0]);y+=90
		if ResourceLoader.exists("res://assets/original/frontier_menu_button.png"):
			var atlas:=AtlasTexture.new();atlas.atlas=load("res://assets/original/frontier_menu_button.png");atlas.region=Rect2(0,125,2172,470)
			for state in ["normal","hover","pressed"]:
				var style:=StyleBoxTexture.new();style.texture=atlas;style.modulate_color=Color(1.12,1.1,0.95) if state=="hover" else Color.WHITE;node.add_theme_stylebox_override(state,style)
	label(menu,"v0.6 · 林线守望",Rect2(110,820,400,30),17,MUTED)
	image(menu,hero_portrait("knight"),Rect2(820,200,350,520))
func show_heroes() -> void:
	reset_menu();backdrop();label(menu,"选择守望者",Rect2(605,75,500,70),40,GOLD)
	button(menu,"‹",Rect2(70,60,72,48),show_entry)
	for index in range(3):
		var key: String=ArenaDefinitions.HERO_IDS[index];var data: Dictionary=ArenaDefinitions.HEROES[key]
		var card:=button(menu,"",Rect2(180+index*425,180,390,590),show_levels.bind(key));card.name="Hero_"+key
		image(card,hero_portrait(key),Rect2(25,12,340,330))
		label(card,data.name,Rect2(30,355,330,38),28,GOLD)
		icon(card,"physical" if data.type==0 else "magic",Rect2(29,411,26,26),ArenaCombat.colour(data.type));label(card,ArenaCombat.label(data.type)+" · "+str(int(data.health))+" 生命",Rect2(65,410,290,28),18)
		label(card,data.small+"  /  "+data.ultimate,Rect2(30,463,330,34),19)
		label(card,data.trait,Rect2(30,514,330,28),17,MUTED)
func show_levels(key: String) -> void:
	selected_hero=key;reset_menu();backdrop();label(menu,"选择防线",Rect2(640,80,450,64),40,GOLD);button(menu,"‹",Rect2(70,60,72,48),show_heroes)
	for index in range(2):
		var stage: String=ArenaLevelCatalog.IDS[index];var data:=ArenaLevelCatalog.definition(stage)
		var card:=button(menu,"",Rect2(265+index*560,205,510,480),game.start_run.bind(selected_hero,stage));card.name="Level_"+stage
		var path: String="res://assets/v06/map_"+stage+".png"
		if ResourceLoader.exists(path):image(card,load(path),Rect2(15,15,480,270),true)
		label(card,data.name,Rect2(30,318,450,50),30,GOLD);label(card,data.story,Rect2(30,375,450,35),21);label(card,"8 波 · "+("单路防守" if stage=="forest" else "双桥回防"),Rect2(30,425,450,28),17,MUTED)
func show_battle() -> void:
	if is_instance_valid(menu):menu.queue_free()
	var bar:=Panel.new();bar.position=Vector2.ZERO;bar.size=Vector2(1600,86);bar.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel_style(bar);root.add_child(bar);battle_nodes.append(bar)
	hero_badge=image(bar,hero_badge_image(game.hero.class_id),Rect2(8,3,68,78))
	hero_health=meter(bar,Rect2(84,22,180,13),Color("d87d73"));experience=meter(bar,Rect2(84,58,180,5),Color("c6d899"));hero_level=label(bar,"1",Rect2(271,20,40,32),21,GOLD)
	icon(bar,"heart",Rect2(84,38,15,15),Color("d87d73"));revival=label(bar,"",Rect2(27,25,55,35),24,GOLD)
	icon(bar,"coin",Rect2(315,23,36,36));coins=label(bar,str(game.gold),Rect2(356,25,96,32),24,GOLD)
	for slot in range(2):
		var b:=button(bar,"",Rect2(465+slot*78,10,64,64),game.request_skill.bind(slot));b.name="Skill_"+str(slot);skills.append(b)
		var kind: String={"knight":["physical","flag"],"ranger":["move","rain"],"mage":["frost","meteor"]}[game.hero.class_id][slot]
		skill_glyphs.append(icon(b,kind,Rect2(15,6,34,37),ArenaCombat.colour(game.hero.data.type)))
		label(b,"Q" if slot==0 else "Space",Rect2(9,45,55,17),12,MUTED)
		b.tooltip_text=str(game.hero.data.small if slot==0 else game.hero.data.ultimate)+"\n"+ArenaDefinitions.skill_text(game.hero.class_id,slot)
	wave_button=button(bar,"",Rect2(770,7,60,60),game.request_wave);wave_button.name="CallWave";wave_button.tooltip_text="预览下一波；再点提前开始"
	wave_glyph=icon(wave_button,"wave",Rect2(12,10,36,36));wave_label=label(bar,"1 / 8",Rect2(850,24,130,36),23)
	icon(bar,"core",Rect2(1195,22,34,40),Color("9de0cf"));core_health=meter(bar,Rect2(1240,29,225,13),Color("96c8a0"))
	var pause:=button(bar,"Ⅱ",Rect2(1516,18,55,50),show_pause);pause.name="Pause"
	preview=Panel.new();preview.position=Vector2(665,98);preview.size=Vector2(320,75);panel_style(preview);preview.hide();root.add_child(preview)
	root.move_child(context,root.get_child_count()-1)
func show_context(index: int) -> void:
	game.selected_site=index;refresh_context()
func clear_children(node: Node) -> void:
	for child in node.get_children():node.remove_child(child);child.queue_free()
func refresh_context() -> void:
	if game.selected_site<0:return
	clear_children(context);context.show()
	var tower: ArenaTower=game.site_tower(game.selected_site)
	context.size=Vector2(365,165) if tower==null else Vector2(300,225)
	var point: Vector2=game.level_definition.sites[game.selected_site]
	context.position=Vector2(clampf(point.x-context.size.x*0.5,12,1600-context.size.x-12),clampf(point.y+38,100,900-context.size.y-15))
	if tower==null:
		label(context,"建造",Rect2(15,8,250,28),19,GOLD)
		for column in range(4):
			var key: String=ArenaDefinitions.TOWER_IDS[column];var data: Dictionary=ArenaDefinitions.TOWERS[key]
			var b:=button(context,"",Rect2(14+column*86,44,78,105),_build.bind(key));b.name="Build_"+key;b.disabled=key not in game.available_towers() or game.gold<int(data.cost)
			image(b,tower_image(key),Rect2(4,1,70,70));icon(b,"coin",Rect2(11,78,18,18));label(b,str(data.cost),Rect2(33,77,40,22),16,GOLD)
			b.tooltip_text=data.name+" · "+ArenaCombat.label(data.type)+"\n"+data.description+("\n第"+str(game.level_definition.towers[key])+"波开放" if key not in game.available_towers() else "")
	else:
		label(context,str(tower.data.name)+"  "+str(tower.level)+"/3",Rect2(17,10,260,32),21,GOLD)
		icon(context,"physical" if tower.data.type==0 else "magic",Rect2(18,49,23,23),ArenaCombat.colour(tower.data.type));label(context,ArenaCombat.label(tower.data.type)+" · "+tower.data.description,Rect2(50,47,245,28),15,MUTED)
		var up:=button(context,"↑    "+str(tower.upgrade_price())+"  ◉" if tower.level<3 else "已满级",Rect2(15,87,268,45),tower.upgrade)
		up.name="Upgrade";up.disabled=tower.level>=3 or game.gold<tower.upgrade_price()
		var target:=button(context,"⚑" if tower.kind=="barracks" else "◎",Rect2(15,148,76,44),_rally if tower.kind=="barracks" else _target);target.tooltip_text="调整集结点" if tower.kind=="barracks" else "切换优先目标"
		button(context,"出售",Rect2(105,148,80,44),tower.sell)
		button(context,"×",Rect2(205,148,78,44),close_context)
func _build(key: String) -> void:
	if game.build_tower(game.selected_site,key):refresh_context()
func _rally() -> void:game.rally_site=game.selected_site;close_context()
func _target() -> void:
	var tower:=game.site_tower(game.selected_site)
	if tower!=null:tower.target_mode="strongest" if tower.target_mode=="first" else "first";refresh_context()
func close_context() -> void:context.hide();game.selected_site=-1
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
func has_modal() -> bool:return is_instance_valid(modal)
func show_choices(keys: Array[String]) -> void:
	close_context();game.targeting_slot=-1;game.rally_site=-1
	var panel:=modal_panel(Vector2(1040,430));label(panel,"选择一份成长",Rect2(360,25,500,50),29,GOLD)
	for index in range(keys.size()):
		var key: String=keys[index];var data: Dictionary=ArenaDefinitions.PERKS[key]
		var b:=button(panel,"",Rect2(30+index*335,108,310,265),game.choose_perk.bind(key));b.name="Perk_"+key
		icon(b,data.icon,Rect2(115,28,80,80),GOLD);label(b,data.name+" "+str(game.hero.perk(key)+1),Rect2(30,137,250,40),27,GOLD)
		var text: String=data.text
		if key=="small":text={"knight":"震地伤害与眩晕增强","ranger":"翻滚后下一箭额外贯穿","mage":"霜环范围扩大"}[game.hero.class_id]
		if key=="ultimate":text={"knight":"战吼持续时间延长","ranger":"箭雨增加一轮","mage":"星陨伤害增强"}[game.hero.class_id]
		label(b,text,Rect2(25,198,285,35),18)
func show_pause() -> void:
	if game.choice_open or game.game_over:return
	if has_modal():resume();return
	get_tree().paused=true;close_context();game.targeting_slot=-1;game.rally_site=-1
	var panel:=modal_panel(Vector2(760,510));label(panel,"守望手册",Rect2(280,27,450,50),32,GOLD)
	label(panel,"WASD / 右键移动 · 按住左键普攻\nQ 小技能 · Space 大招\n点塔位建造 · 点建筑升级与调度\n英雄倒下15秒后复活 · 基地失守才失败",Rect2(65,112,650,230),23)
	button(panel,"继续",Rect2(55,400,280,55),resume);button(panel,"返回主菜单",Rect2(420,400,280,55),game.return_to_menu)
func resume() -> void:get_tree().paused=false;close_modal();game.suppress_primary=true
func show_guide() -> void:
	var panel:=modal_panel(Vector2(800,510));label(panel,"守住防线",Rect2(275,27,500,50),32,GOLD)
	label(panel,"弓箭与火炮：物理伤害\n法师塔：法术伤害，克制重甲\n兵营：派士兵在路上拦住敌人\n英雄可拦截、施法、躲弹；离开战斗后回血",Rect2(65,115,670,220),22)
	button(panel,"明白了",Rect2(240,410,320,55),close_modal)
func show_growth() -> void:
	var panel:=modal_panel(Vector2(850,580));label(panel,"英雄训练",Rect2(310,22,480,50),32,GOLD)
	for index in range(3):
		var key: String=ArenaDefinitions.HERO_IDS[index];button(panel,ArenaDefinitions.HEROES[key].name,Rect2(45+index*255,90,235,48),_growth_select.bind(key))
	var data: Dictionary=game.progression.entry(selected_growth)
	image(panel,hero_portrait(selected_growth),Rect2(45,160,220,290));label(panel,"可用训练点  "+str(game.progression.points(selected_growth)),Rect2(310,175,470,35),24,GOLD)
	label(panel,"生命训练  "+str(data.health)+"/5    每级 +3",Rect2(310,245,400,35),21)
	var hp:=button(panel,"+1",Rect2(690,240,90,45),_growth_upgrade.bind("health"));hp.disabled=game.progression.points(selected_growth)<=0 or int(data.health)>=5 or game.progression.locked
	label(panel,"技能训练  "+str(data.cooldown)+"/5    每级冷却 -2%",Rect2(310,330,420,35),21)
	var cd:=button(panel,"+1",Rect2(690,325,90,45),_growth_upgrade.bind("cooldown"));cd.disabled=game.progression.points(selected_growth)<=0 or int(data.cooldown)>=5 or game.progression.locked
	if game.progression.locked:label(panel,game.progression.last_error,Rect2(310,420,450,35),18,Color("e7a28a"))
	button(panel,"返回",Rect2(275,495,300,50),close_modal)
func _growth_select(key: String) -> void:selected_growth=key;show_growth()
func _growth_upgrade(stat: String) -> void:game.progression.upgrade(selected_growth,stat);show_growth()
func show_result() -> void:
	close_context();var panel:=modal_panel(Vector2(660,410));label(panel,"防线守住了" if game.victory else "信标失守",Rect2(205,35,500,60),36,GOLD)
	label(panel,"第 "+str(game.cycle)+" 波 · 击败 "+str(game.kills)+" · 建塔 "+str(game.built),Rect2(100,133,500,40),24)
	label(panel,"清理营地 "+str(game.camps_cleared)+" / 2 · 成长经验 +"+str(maxi(0,game.growth_reward)),Rect2(100,190,520,35),21,MUTED)
	var retry:=button(panel,"再守一次",Rect2(50,290,260,60),game.restart_run);retry.name="RetryRun"
	button(panel,"返回主菜单",Rect2(350,290,260,60),game.return_to_menu)
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):return
	if game.choice_open:
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			var index: int=event.keycode-KEY_1
			if index<game.choices.size():game.choose_perk(game.choices[index])
			get_viewport().set_input_as_handled()
		return
	if not game.started:return
	if event.keycode==KEY_H or (event.keycode==KEY_ESCAPE and has_modal() and not game.game_over):
		if has_modal():resume()
		else:show_pause()
		get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if unlock_clock>0:
		unlock_clock-=delta
		if unlock_clock<=0 and is_instance_valid(unlock_hint):unlock_hint.hide()
	update_clock-=delta
	if update_clock>0 or not game.started or hero_health==null:return
	update_clock=0.08
	var h: ArenaHero=game.hero
	hero_health.max_value=h.max_health;hero_health.value=h.health;hero_health.tooltip_text=str(int(h.health))+" / "+str(int(h.max_health))
	experience.max_value=h.xp_target;experience.value=h.xp;hero_level.text=str(h.level)
	core_health.max_value=game.core_max;core_health.value=game.core_health;core_health.tooltip_text=str(int(game.core_health))+" / "+str(int(game.core_max))
	coins.text=str(game.gold);revival.text=str(int(ceil(h.revive_clock))) if h.knocked_out else "";hero_badge.modulate=Color(0.6,0.6,0.6) if h.knocked_out else Color.WHITE
	for slot in range(2):
		skills[slot].disabled=h.knocked_out or h.cooldowns[slot]>0 or game.game_over
		skills[slot].text=str(int(ceil(h.cooldowns[slot]))) if h.cooldowns[slot]>0 else ""
		var maximum: float=float(h.data.small_cd if slot==0 else h.data.ultimate_cd)*h.cooldown_scale()
		skill_glyphs[slot].progress=1.0-h.cooldowns[slot]/maximum;skill_glyphs[slot].modulate.a=0.45 if h.cooldowns[slot]>0 else 1.0;skill_glyphs[slot].queue_redraw()
	wave_label.text=str(game.cycle)+" / 8";wave_button.disabled=game.phase!="rest" or game.game_over
	wave_glyph.progress=game.phase_clock/game.rest_duration if game.phase=="rest" else 1.0;wave_glyph.tint=GOLD if game.wave_preview else CREAM;wave_glyph.queue_redraw()
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
