class_name ArenaFrontEnd
extends RefCounted
var hud: ArenaHUD
var game: ArenaGame
var stage:="forest"
var hero_id:="lord"
var tower_id:="archer"
var preview_tier:=1
var page_id:=""
var stage_panel: Panel
var message:=""
var wallet_value: Label
var notice: Label
var roster: Dictionary={}
var card: Control
var card_art: TextureRect
var rank_label: Label
var detail_panel: Panel
var name_label: Label
var role_label: Label
var stat_bars: Array[ProgressBar]=[]
var stat_values: Array[Label]=[]
var stat_icons: Array[TextureRect]=[]
var skill_buttons: Array[Button]=[]
var skill_images: Array[TextureRect]=[]
var skill_locks: Array[Label]=[]
var skill_title: Label
var skill_body: RichTextLabel
var selected_skill:=0
var rank_stars: Array[TextureRect]=[]
var upgrade_button: Button
var equip_button: Button
var tier_buttons: Array[Button]=[]
var route_buttons: Array[Button]=[]
var route_titles: Array[Label]=[]
var route_icons: Array[TextureRect]=[]
var route_name: Label
var route_body: RichTextLabel
var selected_route:=0
const ROLES:={"lord":"重装 · 拦截护盾","druid":"召唤 · 双狼协同","healer":"辅助 · 治愈增益","werewolf":"狂战 · 冰狼变身","gunner":"游射 · 灵动暴击"}
func _init(owner: ArenaHUD) -> void:
	hud=owner;game=owner.game;hero_id=game.campaign.selected_hero()
func reduced() -> bool:return bool(game.campaign.data.reduced_motion)
func base(background: String,page_name: String) -> void:
	page_id=page_name;stage_panel=null;roster.clear();stat_bars.clear();stat_values.clear();stat_icons.clear();skill_buttons.clear();skill_images.clear();skill_locks.clear();rank_stars.clear();tier_buttons.clear();route_buttons.clear();route_titles.clear();route_icons.clear()
	hud.reset_menu();hud.menu.modulate=Color.WHITE
	var image:=hud.image(hud.menu,ArenaMenuArt.texture(background),Rect2(0,0,1600,900),true);image.name="Scenery"
	if page_name in ["title","world"] and not reduced():
		var gradient:=Gradient.new();gradient.colors=PackedColorArray([Color(1,.89,.58,.25),Color(1,.89,.58,0)])
		var dot:=GradientTexture2D.new();dot.gradient=gradient;dot.width=24;dot.height=24;dot.fill=GradientTexture2D.FILL_RADIAL;dot.fill_from=Vector2(.5,.5);dot.fill_to=Vector2(1,.5)
		var light:=CPUParticles2D.new();light.name="AmbientLights";light.texture=dot;light.position=Vector2(800,450);light.amount=8;light.lifetime=24;light.preprocess=18;light.emission_shape=CPUParticles2D.EMISSION_SHAPE_RECTANGLE;light.emission_rect_extents=Vector2(780,400);light.gravity=Vector2.ZERO;light.direction=Vector2.UP;light.initial_velocity_min=1;light.initial_velocity_max=3;light.scale_amount_min=.2;light.scale_amount_max=.4;hud.menu.add_child(light)
		if page_name=="world":
			var top_gate:=hud.colour_block(hud.menu,Rect2(0,0,1600,36),Color(0.08,0.11,0.16,0.78))
			var bot_gate:=hud.colour_block(hud.menu,Rect2(0,864,1600,36),Color(0.08,0.11,0.16,0.78))
			top_gate.z_index=30;bot_gate.z_index=30
			var tw:=hud.menu.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(top_gate,"position:y",-40.0,0.16)
			tw.tween_property(bot_gate,"position:y",904.0,0.16)
			tw.chain().tween_callback(func():
				if is_instance_valid(top_gate):top_gate.queue_free()
				if is_instance_valid(bot_gate):bot_gate.queue_free())
	notice=text(hud.menu,"",Rect2(420,846,760,38),23);notice.name="FrontMessage";notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
func frame(parent: Node,rect: Rect2,paper:=false) -> Panel:
	var panel:=Panel.new();panel.position=rect.position;panel.size=rect.size;panel.mouse_filter=Control.MOUSE_FILTER_STOP;parent.add_child(panel);ArenaMenuArt.panel(panel,paper);return panel
func text(parent: Node,value: String,rect: Rect2,size:=24,paper:=false) -> Label:
	return hud.label(parent,value,rect,size,ArenaMenuArt.PAPER if paper else ArenaHUD.CREAM)
func body(parent: Node,rect: Rect2,paper:=false) -> RichTextLabel:
	var label:=RichTextLabel.new();label.position=rect.position;label.size=rect.size;label.bbcode_enabled=true;label.scroll_active=true;label.add_theme_font_size_override("normal_font_size",23);label.add_theme_font_size_override("bold_font_size",24);label.add_theme_color_override("default_color",ArenaMenuArt.PAPER if paper else ArenaHUD.CREAM);parent.add_child(label);return label
func action(parent: Node,caption: String,rect: Rect2,callback: Callable,key: String,primary:=false,plain:=false) -> Button:
	var button:=hud.button(parent,caption,rect,callback);button.name=key;ArenaMenuArt.button(button,primary,plain);ArenaMenuArt.interact(button,reduced());button.pressed.connect(func():game.audio.play("ui_click",-26,1.4));return button
func utility(parent: Node,kind: String,rect: Rect2,callback: Callable,key: String) -> Button:
	var button:=action(parent,"",rect,callback,key);hud.image(button,ArenaMenuArt.utility(kind),Rect2(Vector2.ONE*15,rect.size-Vector2.ONE*30));return button
func wallet() -> void:
	var pill:=Panel.new();pill.name="Wallet";pill.position=Vector2(1228,26);pill.size=Vector2(210,68);pill.mouse_filter=Control.MOUSE_FILTER_IGNORE;pill.add_theme_stylebox_override("panel",ArenaMenuArt.small_style());hud.menu.add_child(pill)
	hud.image(pill,ArenaMenuArt.utility("diamond"),Rect2(14,10,48,48));wallet_value=text(pill,str(game.campaign.gems()),Rect2(72,13,126,42),30)
	if game.campaign.path==ArenaCampaign.PLAYTEST_PATH:
		var flag:=text(hud.menu,"自由试玩",Rect2(1250,99,180,30),22);flag.modulate=Color(.7,.85,.9)
func header(title: String,back: Callable) -> void:
	utility(hud.menu,"back",Rect2(28,20,84,84),back,"Back")
	var label:=text(hud.menu,title,Rect2(136,34,340,54),34);label.add_theme_color_override("font_outline_color",Color("121e2c"));label.add_theme_constant_override("outline_size",4)
	wallet();utility(hud.menu,"settings",Rect2(1474,20,84,84),settings,"Settings")
func feedback() -> void:
	if is_instance_valid(notice):notice.text=message
func entry() -> void:
	message="";base("title","title")
	# Local scrims keep the painted heroes clear while grounding the title and controls.
	_title_scrim(Rect2(0,0,1600,230),Color("14253499"),Color("14253400"))
	_title_scrim(Rect2(0,560,1600,340),Color("101e2b00"),Color("101e2bf5"))
	var eyebrow:=text(hud.menu,"B O R D E R W A T C H",Rect2(490,28,620,30),21)
	eyebrow.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	eyebrow.add_theme_color_override("font_color",Color("f4db9f"))
	var title:=text(hud.menu,"边境守望",Rect2(420,58,760,116),96)
	title.name="GameTitle";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color",Color("ffe8ac"))
	title.add_theme_color_override("font_outline_color",Color("172a38"))
	title.add_theme_constant_override("outline_size",7)
	title.add_theme_color_override("font_shadow_color",Color("0b1729a6"))
	title.add_theme_constant_override("shadow_offset_y",5)
	var subtitle:=text(hud.menu,"集结英雄 · 筑起防线 · 守住边境",Rect2(490,180,620,38),24)
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_outline_color",Color("172a38"))
	subtitle.add_theme_constant_override("outline_size",4)
	var start:=action(hud.menu,"进入守望",Rect2(600,728,400,88),levels,"StartCampaign",true)
	start.add_theme_font_size_override("font_size",32)
	start.tooltip_text="前往世界地图，选择关卡与出战阵容"
	var hint:=text(hud.menu,"选择关卡，开启下一场守望",Rect2(520,828,560,34),22)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color",Color("b9c9ce"))
	var settings_button:=utility(hud.menu,"settings",Rect2(1390,30,72,72),settings,"Settings")
	settings_button.tooltip_text="设置"
	var exit_button:=utility(hud.menu,"exit",Rect2(1488,30,72,72),game.quit_game,"ExitGame")
	exit_button.tooltip_text="退出游戏"
	# A predictable keyboard loop also makes Enter usable without moving the mouse.
	start.focus_next=start.get_path_to(settings_button);start.focus_previous=start.get_path_to(exit_button)
	settings_button.focus_next=settings_button.get_path_to(exit_button);settings_button.focus_previous=settings_button.get_path_to(start)
	exit_button.focus_next=exit_button.get_path_to(start);exit_button.focus_previous=exit_button.get_path_to(settings_button)
	start.grab_focus()
	_title_status()
func _title_scrim(rect: Rect2,top: Color,bottom: Color) -> void:
	var gradient:=Gradient.new();gradient.colors=PackedColorArray([top,bottom])
	var texture:=GradientTexture2D.new();texture.gradient=gradient
	texture.width=2;texture.height=256;texture.fill_from=Vector2(.5,0);texture.fill_to=Vector2(.5,1)
	var shade:=hud.image(hud.menu,texture,rect,true)
	shade.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
func _title_status() -> void:
	var cleared:=0
	for key in ArenaLevelCatalog.IDS:
		if bool(game.campaign.data.cleared.get(key,false)):cleared+=1
	var progress:=text(hud.menu,"战役进度  %d / %d"%[cleared,ArenaLevelCatalog.IDS.size()],Rect2(48,752,320,34),24)
	progress.name="TitleProgress"
	for index in range(ArenaLevelCatalog.IDS.size()):
		var key: String=ArenaLevelCatalog.IDS[index]
		var complete:=bool(game.campaign.data.cleared.get(key,false))
		hud.colour_block(hud.menu,Rect2(50+index*68,802,54,4),ArenaMenuArt.GOLD if complete else Color("647984"))
	var identity:=game.campaign.selected_hero()
	var badge:=hud.image(hud.menu,hud.hero_badge_image(identity),Rect2(1270,746,66,72))
	badge.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	text(hud.menu,"出战英雄",Rect2(1352,746,200,30),21).add_theme_color_override("font_color",Color("b9c9ce"))
	text(hud.menu,"%s · LV.%d"%[ArenaDefinitions.HEROES[identity].name,game.campaign.level(identity)],Rect2(1352,780,200,38),24)
	var profile_text: String="自由试玩 · 独立存档" if game.campaign.path==ArenaCampaign.PLAYTEST_PATH else "英雄塔防 · 战役模式"
	text(hud.menu,profile_text,Rect2(48,846,340,30),20).add_theme_color_override("font_color",Color("9aadb7"))
	var version:=text(hud.menu,"v"+str(ProjectSettings.get_setting("application/config/version")),Rect2(1390,846,162,30),20)
	version.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	version.add_theme_color_override("font_color",Color("9aadb7"))
func levels() -> void:
	message="";base("world_atlas","world");wallet()
	utility(hud.menu,"back",Rect2(28,20,84,84),entry,"Back");utility(hud.menu,"settings",Rect2(1474,20,84,84),settings,"Settings")
	for index in range(ArenaLevelCatalog.IDS.size()):
		var key: String=ArenaLevelCatalog.IDS[index];var point: Vector2=ArenaLevelCatalog.WORLD_NODES[key].position
		var node:=action(hud.menu,"",Rect2(point-Vector2(48,94),Vector2(96,104)),prepare.bind(key),"Level_"+key,false,true)
		hud.image(node,ArenaMenuArt.utility("flag"),Rect2(5,0,86,90))
		var number:=text(node,str(index+1),Rect2(24,12,48,45),30);number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;number.add_theme_color_override("font_outline_color",Color("241b18"));number.add_theme_constant_override("outline_size",3)
		node.tooltip_text=ArenaLevelCatalog.definition(key).name
		if bool(game.campaign.data.cleared.get(key,false)):hud.image(node,ArenaMenuArt.utility("check"),Rect2(56,66,40,40))
		if not reduced():
			var float_tween:=node.create_tween().set_loops();float_tween.tween_property(node,"position:y",node.position.y-5,1.3).set_trans(Tween.TRANS_SINE);float_tween.tween_property(node,"position:y",node.position.y,1.3).set_trans(Tween.TRANS_SINE)
	# No invented three-star scoring: existing clear flags are the only earned marks.
	for point in [Vector2(1125,210),Vector2(1400,390)]:
		var lock:=hud.image(hud.menu,ArenaMenuArt.utility("lock"),Rect2(point,Vector2(48,48)));lock.modulate=Color(1,1,1,.45);lock.tooltip_text="远景地区 · 尚未开放";lock.mouse_filter=Control.MOUSE_FILTER_PASS
	dock()
func dock() -> void:
	var tray:=Control.new();tray.name="WorldLoadout";tray.position=Vector2(32,755);tray.size=Vector2(474,104);tray.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.menu.add_child(tray)
	var hero_button:=action(tray,"",Rect2(0,0,90,90),hall,"WorldHero");hero_button.tooltip_text=ArenaDefinitions.HEROES[game.campaign.selected_hero()].name
	var hero_img:=hud.image(hero_button,hud.hero_badge_image(game.campaign.selected_hero()),Rect2(8,5,74,78));hero_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var equipped:=game.campaign.tower_loadout()
	for index in range(4):
		var button:=action(tray,"",Rect2(106+index*88,4,80,82),towers,"WorldTower_"+str(index))
		if index<equipped.size():
			var w_img:=hud.image(button,hud.tower_portrait(equipped[index]),Rect2(4,3,72,74));w_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			button.tooltip_text=game.tower_display_data(equipped[index]).name
		else:hud.image(button,ArenaMenuArt.utility("range"),Rect2(26,26,28,28)).modulate.a=.35
	for item in [[0,1124,hall,"HeroHall","英雄"],[1,1270,towers,"TowerHall","防御塔"],[2,1416,growth,"被动图鉴","成长"]]:
		if (game.condition_lab or game.defense_rules) and item[0]==2: continue
		var button:=action(hud.menu,"",Rect2(item[1],710,132,148),item[2],item[3],false,true)
		hud.image(button,ArenaMenuArt.icon(item[0]),Rect2(14,0,104,104))
		var caption:=text(button,item[4],Rect2(0,106,132,36),26);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.add_theme_color_override("font_outline_color",Color("152535"));caption.add_theme_constant_override("outline_size",4)
func prepare(key: String) -> void:
	if key not in ArenaLevelCatalog.IDS:return
	stage=key;close_stage()
	stage_panel=frame(hud.menu,Rect2(780,178,660,566));stage_panel.name="StagePanel"
	var definition:=ArenaLevelCatalog.definition(stage)
	hud.image(stage_panel,load(definition.get("preview_art",definition.get("map_art",ArenaBattleArt.map_path(stage)))),Rect2(24,24,612,166),true)
	var close:=action(stage_panel,"×",Rect2(562,18,72,72),close_stage,"CloseStage");close.add_theme_font_size_override("font_size",38)
	text(stage_panel,definition.name,Rect2(34,209,530,48),34)
	text(stage_panel,str(int(definition.get("waves",8)))+" 波",Rect2(34,260,150,36),25)
	hud.image(stage_panel,ArenaMenuArt.utility("diamond"),Rect2(480,257,34,34));text(stage_panel,"+"+str(6 if bool(game.campaign.data.cleared.get(stage,false)) else 8),Rect2(524,258,90,38),26)
	var preview_list: Array=definition.get("preview_enemies",["pigsoldier","tusk_fighter","dreadeye_viper","bear_vanguard"])
	for index in range(min(4,preview_list.size())):
		var enemy: String=str(preview_list[index])
		var image:=hud.image(stage_panel,ArenaMenuArt.creature(enemy),Rect2(31+index*66,317,62,62))
		image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var edata := ArenaDefinitions.enemy(enemy)
		var etrait := str(edata.get("trait",""))
		image.tooltip_text=str(edata.name)+("\n"+etrait if etrait!="" else "")
		image.mouse_filter=Control.MOUSE_FILTER_PASS
	var tagline: String="\n"+str(definition.get("tagline",""))
	if str(definition.get("tagline","")).is_empty():tagline=""
	var brief:=text(stage_panel,str(definition.story)+tagline,Rect2(330,312,286,88),25);brief.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var ready:=game.campaign.can_deploy(stage,game.defense_rules)
	var deploy:=action(stage_panel,"战斗！",Rect2(222,446,392,84),deploy_stage,"Deploy",true);deploy.disabled=not ready
	if not ready:
		text(stage_panel,"需装备首波可建的塔",Rect2(36,401,575,36),24)
		action(stage_panel,"配置塔",Rect2(222,446,392,84),towers,"ConfigureTowers",true);deploy.hide()
func close_stage() -> void:
	if is_instance_valid(stage_panel):hud.menu.remove_child(stage_panel);stage_panel.queue_free()
	stage_panel=null
func deploy_stage() -> void:
	if game.campaign.can_deploy(stage,game.defense_rules):game.start_run(game.campaign.selected_hero(),stage)
func _make_card(height: float) -> void:
	card=Control.new();card.name="PortraitCard";card.position=Vector2(132,154);card.size=Vector2(420,height);card.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.menu.add_child(card)
	var clip:=Control.new();clip.name="CardClip";clip.position=Vector2(48,92);clip.size=Vector2(324,height-144);clip.clip_contents=true;clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(clip)
	hud.colour_block(clip,Rect2(Vector2.ZERO,clip.size),Color("263c4b"))
	card_art=hud.image(clip,null,Rect2(Vector2(0,0),clip.size));card_art.name="CardPortrait";card_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hud.image(card,ArenaMenuArt.skin(5),Rect2(Vector2.ZERO,card.size))
	rank_label=text(card,"",Rect2(162,46,98,46),26);rank_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
func _make_stat(parent: Node,kind: String,y: float,tint: Color) -> void:
	stat_icons.append(hud.image(parent,ArenaMenuArt.utility(kind),Rect2(38,y,42,42)))
	var bar:=ProgressBar.new();bar.position=Vector2(100,y+11);bar.size=Vector2(480,22);bar.show_percentage=false;bar.max_value=1
	var bg:=StyleBoxFlat.new();bg.bg_color=Color("132330");bg.set_border_width_all(2);bg.border_color=Color("0a1520");bg.set_corner_radius_all(7)
	var fg:=StyleBoxFlat.new();fg.bg_color=tint;fg.set_corner_radius_all(6);fg.border_color=tint.lightened(.2);fg.border_width_top=2
	bar.add_theme_stylebox_override("background",bg);bar.add_theme_stylebox_override("fill",fg);parent.add_child(bar);stat_bars.append(bar)
	stat_values.append(text(parent,"",Rect2(608,y+1,178,42),27))
func _stat_value(index: int,value: float,maximum: float,caption: String,animated:=false) -> void:
	var bar: ProgressBar=stat_bars[index]
	if bar.has_meta("value_tween"):
		var old: Tween=bar.get_meta("value_tween")
		if is_instance_valid(old):old.kill()
	if animated and not reduced():
		var label: Label=stat_values[index];var previous: float=float(label.get_meta("display_number",value))
		var tween:=bar.create_tween().set_parallel(true);bar.set_meta("value_tween",tween);tween.tween_property(bar,"value",clampf(value/maximum,0,1),.28)
		tween.tween_method(func(number: float):
			label.set_meta("display_number",number)
			label.text=str(snappedf(number,.01))+" /秒" if caption.contains("/秒") else (str(snappedf(number,.1)) if caption.contains(".") else str(roundi(number))),previous,value,.28)
	else:
		bar.value=clampf(value/maximum,0,1);stat_values[index].text=caption;stat_values[index].set_meta("display_number",value)
func hall() -> void:
	if page_id=="heroes" and is_instance_valid(card):_refresh_hero();return
	message="";base("hall_bg","heroes");header("英雄大厅",levels)
	selected_skill=0
	for index in range(ArenaDefinitions.HERO_IDS.size()):
		var id: String=ArenaDefinitions.HERO_IDS[index]
		var button:=action(hud.menu,"",Rect2(622+index*106,20,84,84),select_hall.bind(id),"Hall_"+id)
		var r_img:=hud.image(button,hud.hero_badge_image(id),Rect2(6,4,72,76));r_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;roster[id]=button;button.tooltip_text=ArenaDefinitions.HEROES[id].name
	_make_card(526)
	equip_button=action(hud.menu,"",Rect2(152,724,380,84),equip_hero,"EquipHero",true)
	detail_panel=frame(hud.menu,Rect2(646,148,828,680));detail_panel.name="HeroDetails"
	name_label=text(detail_panel,"",Rect2(38,25,730,52),36);role_label=text(detail_panel,"",Rect2(40,77,730,34),23)
	_make_stat(detail_panel,"heart",120,Color("87cf62"));_make_stat(detail_panel,"sword",174,Color("ef9a50"));_make_stat(detail_panel,"speed",228,Color("68cfda"))
	for index in range(3):
		var button:=action(detail_panel,"",Rect2(44+index*146,294,84,84),select_skill.bind(index),"HeroSkill_"+str(index) if index<2 else "HeroPassive")
		skill_buttons.append(button);skill_images.append(hud.image(button,null,Rect2(8,6,68,68)))
		var key:=text(detail_panel,["Q","E","被动"][index],Rect2(44+index*146,380,84,30),22);key.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		skill_locks.append(text(detail_panel,"",Rect2(495,300+index*31,290,30),22))
	var info:=frame(detail_panel,Rect2(28,420,772,138),true)
	skill_title=text(info,"",Rect2(24,12,720,34),26,true);skill_title.name="HeroSkillTitle"
	skill_body=body(info,Rect2(24,50,720,76),true);skill_body.name="HeroSkillDescription"
	for index in range(5):
		var star:=hud.image(detail_panel,ArenaMenuArt.utility("star_empty"),Rect2(40+index*52,589,46,46));star.name="HeroRank_"+str(index+1);rank_stars.append(star)
	upgrade_button=action(detail_panel,"",Rect2(460,580,336,76),upgrade_hero,"UpgradeHero",true);ArenaMenuArt.accent(upgrade_button,"blue")
	_refresh_hero()
func _refresh_hero(animated:=false) -> void:
	hero_id=ArenaDefinitions.resolve_hero_id(hero_id)
	var data: Dictionary=ArenaDefinitions.HEROES[hero_id];var rank:=game.campaign.level(hero_id);var bonus:=game.campaign.bonuses(hero_id)
	for id in roster:
		ArenaMenuArt.selected(roster[id],id==hero_id);roster[id].position.y=16 if id==hero_id else 20
	card_art.texture=hud.hero_portrait(hero_id);card_art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;rank_label.text="LV. "+str(rank)
	name_label.text=data.name;role_label.text=ROLES[hero_id]+" · "+ArenaCombat.label(int(data.type))
	var health:=float(data.health)*(1.0+float(bonus.health));var damage:=float(data.damage)*(1.0+float(bonus.attack))
	stat_icons[1].texture=ArenaMenuArt.icon(15) if int(data.type)==1 else ArenaMenuArt.utility("sword")
	_stat_value(0,health,480,str(roundi(health)),animated);_stat_value(1,damage,45,str(snappedf(damage,.1)),animated);_stat_value(2,1.0/float(data.interval),2.0,str(snappedf(1.0/float(data.interval),.01))+" /秒",animated)
	for slot in range(3):
		skill_images[slot].texture=ArenaMenuArt.skill(hero_id,slot)
		skill_images[slot].modulate=Color.WHITE if slot==2 or game.campaign.skill_unlocked(hero_id,slot) else Color(.58,.64,.7)
	skill_locks[0].text="Q · "+("已解锁" if rank>=2 else "LV.2 解锁")
	skill_locks[1].text="E · "+("已解锁" if rank>=4 else "LV.4 解锁")
	skill_locks[2].text="天赋 · LV.3 / 5 强化"
	for index in range(5):rank_stars[index].texture=ArenaMenuArt.utility("star" if rank>index else "star_empty")
	var active:=game.campaign.selected_hero()==hero_id
	equip_button.text="✓ 已出战" if active else "设为出战";equip_button.disabled=active or game.campaign.locked;ArenaMenuArt.accent(equip_button,"green" if active else "amber")
	if active:equip_button.add_theme_stylebox_override("disabled",ArenaMenuArt.style(4));equip_button.add_theme_color_override("font_disabled_color",ArenaHUD.CREAM)
	var price:=game.campaign.price(hero_id);upgrade_button.text="已满级" if rank==5 else "升级    "+str(price)
	upgrade_button.icon=null if rank==5 else ArenaMenuArt.utility("diamond");upgrade_button.expand_icon=true;upgrade_button.icon_alignment=HORIZONTAL_ALIGNMENT_RIGHT;upgrade_button.add_theme_constant_override("icon_max_width",28)
	upgrade_button.disabled=rank==5 or game.campaign.gems()<price or game.campaign.locked;ArenaMenuArt.accent(upgrade_button,"amber" if rank==5 else "blue")
	wallet_value.text=str(game.campaign.gems());select_skill(selected_skill);feedback()
func select_skill(slot: int) -> void:
	selected_skill=clampi(slot,0,2)
	for index in range(skill_buttons.size()):ArenaMenuArt.selected(skill_buttons[index],index==selected_skill)
	var data: Dictionary=ArenaDefinitions.HEROES[hero_id]
	if selected_skill==2:
		skill_title.text="职业天赋";skill_body.text=passive_text(hero_id,int(game.campaign.bonuses(hero_id).passive));return
	var unlocked:=game.campaign.skill_unlocked(hero_id,selected_skill)
	skill_title.text=str(data.small if selected_skill==0 else data.ultimate)+"  ·  "+str(data.small_cd if selected_skill==0 else data.ultimate_cd)+"秒"
	var details: Dictionary={
		"lord":["向前方挥出血剑重斩，造成中等范围伤害并震慑打断敌军攻势。","展开血棘圣盾，获得45%最大生命护盾、6秒35%减伤与+1拦截上限，并周期反伤周围敌人。"],
		"druid":["指定位置或敌人，驱使寒霜狼与赤焰狼冲锋集火，同时为双狼回复30%生命。","唤醒双狼野性：立即复活并回满血，体型平滑变大至1.35倍，7秒内移速+25%、攻速+40%、攻击+45%。"],
		"healer":["绽放花灵星辉造成范围轻法伤，5秒内令周围友军与防御塔攻速+20%、伤害+15%。","召唤5秒圣泉领域，持续为自身（溢出转护盾）与附近士兵回血，并令范围内防御塔攻速+25%。"],
		"werewolf":["激发寒冰嗜血，5秒内攻速+35%、普攻附带15%吸血并溅射霜伤。","彻底狂化为巨型白狼人8秒：攻速+55%、宽幅冰爪顺劈伤害+30%、22%吸血与+20%移速。"],
		"gunner":["短冷却高速战术滑步并短暂无敌，滑步后下一发平A强化为2.0倍暴击穿甲弹（穿透2敌）。","进入6秒超载律动：立即重置滑步冷却且冷却减半至2秒，移速+20%、射程+25%，强化射击发射双发暴击穿透弹。"]
	}
	skill_body.text=str(details[hero_id][selected_skill])+("" if unlocked else "\n[color=#8d592d]LV."+str(2 if selected_skill==0 else 4)+" 解锁 · 可先查看效果[/color]")
func passive_text(id: String,rank: int) -> String:
	var key := ArenaDefinitions.resolve_hero_id(id)
	return {
		"lord":["拦截时近战减伤20%","拦截时近战减伤24%","拦截时近战减伤28%"],
		"druid":["常驻寒霜狼与赤焰狼随行","双狼生命提高12%","双狼生命提高24%"],
		"healer":["光环使附近士兵攻速+10%","普攻易伤11%，光环攻速+10%","普攻易伤12%，光环攻速+10%"],
		"werewolf":["普攻附带寒霜减速15%","狂化吸血进一步增强","狂化吸血与冰爪伤害增强"],
		"gunner":["滑步后强化射击为2.0倍暴击","滑步后强化射击提升至2.15倍暴击","滑步后强化射击提升至2.3倍暴击"]
	}[key][rank]+"\n英雄LV.3、LV.5进一步强化天赋。"
func select_hall(key: String) -> void:
	key = ArenaDefinitions.resolve_hero_id(key)
	if key not in ArenaDefinitions.HERO_IDS:return
	hero_id=key;selected_skill=0;message="";_refresh_hero()
func equip_hero() -> void:
	message="" if game.campaign.select_hero(hero_id) else game.campaign.last_error;_refresh_hero()
func upgrade_hero() -> void:
	var ok:=game.campaign.upgrade(hero_id);message="" if ok else game.campaign.last_error;_refresh_hero(ok)
	if ok and not reduced():
		var tween:=card.create_tween();card.modulate=Color(1.25,1.14,.86);tween.tween_property(card,"modulate",Color.WHITE,.32)
		var star: TextureRect=rank_stars[game.campaign.level(hero_id)-1];star.pivot_offset=star.size*.5;star.scale=Vector2.ONE*1.25;star.create_tween().tween_property(star,"scale",Vector2.ONE,.28)
func towers() -> void:
	if page_id=="towers" and is_instance_valid(card):_refresh_tower();return
	message="";base("hall_bg","towers");header("防御塔工坊",levels)
	for index in ArenaDefinitions.TOWER_IDS.size():
		var id: String=ArenaDefinitions.TOWER_IDS[index]
		var button:=action(hud.menu,"",Rect2(450+index*100,20,84,84),select_tower.bind(id),"Tower_"+id)
		var t_img:=hud.image(button,hud.tower_portrait(id),Rect2(5,4,74,76));t_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		roster[id]=button;button.tooltip_text=game.tower_display_data(id).name
		var equipped_mark:=hud.image(button,ArenaMenuArt.utility("check"),Rect2(55,54,26,26));equipped_mark.name="Equipped"
	_make_card(492);card_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;card_art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	for index in range(3):
		tier_buttons.append(action(hud.menu,["I","II","III"][index],Rect2(154+index*126,664,116,70),select_tier.bind(index+1),"TowerTier_"+str(index+1)))
	equip_button=action(hud.menu,"",Rect2(152,752,380,78),toggle_tower,"EquipTower",true)
	detail_panel=frame(hud.menu,Rect2(646,148,828,680));detail_panel.name="TowerDetails"
	name_label=text(detail_panel,"",Rect2(38,25,730,52),36);role_label=text(detail_panel,"",Rect2(40,77,730,34),23)
	_make_stat(detail_panel,"range",120,Color("79bb88"));_make_stat(detail_panel,"sword",174,Color("ef9a50"));_make_stat(detail_panel,"speed",228,Color("68cfda"))
	text(detail_panel,"III 阶改造 · 关卡内选择",Rect2(38,294,745,36),25)
	for index in range(3):
		var button:=action(detail_panel,"",Rect2(32+index*258,342,246,94),select_route.bind(index),"TowerRoute_"+str(index))
		route_buttons.append(button);route_icons.append(hud.image(button,null,Rect2(12,20,48,48)));route_titles.append(text(button,"",Rect2(68,27,170,42),24))
	var info:=frame(detail_panel,Rect2(28,460,772,150),true);route_name=text(info,"",Rect2(24,12,720,34),27,true);route_body=body(info,Rect2(24,52,720,82),true)
	text(detail_panel,"预览不花费金币；实际建造与改造在关卡内进行。",Rect2(38,626,745,36),23)
	_refresh_tower()
func _refresh_tower() -> void:
	var data:=game.tower_display_data(tower_id);var equipped:=game.campaign.tower_loadout()
	for id in roster:
		ArenaMenuArt.selected(roster[id],id==tower_id)
		roster[id].position.y=16 if id==tower_id else 20
		roster[id].get_node("Equipped").visible=id in equipped
	var doc_id: String = str(ArenaDoctrines.for_tower(tower_id)[selected_route].id) if preview_tier == 3 else ""
	card_art.texture = hud.tower_image(tower_id, preview_tier, doc_id)
	card_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rank_label.text=["I","II","III"][preview_tier-1]+" 阶"
	name_label.text=data.name;role_label.text=ArenaCombat.label(int(data.type))+" · "+str(data.description)
	stat_icons[1].texture=ArenaMenuArt.utility("shield") if tower_id=="barracks" else (ArenaMenuArt.icon(15) if int(data.type)==1 else ArenaMenuArt.utility("sword"))
	_stat_value(0,float(data.reach)+(preview_tier-1)*16,320,str(roundi(float(data.reach)+(preview_tier-1)*16)))
	_stat_value(1,3 if tower_id=="barracks" else float(data.damage)*(1+.6*(preview_tier-1)),3 if tower_id=="barracks" else 130,"3 人" if tower_id=="barracks" else str(snappedf(float(data.damage)*(1+.6*(preview_tier-1)),.1)))
	_stat_value(2,1.0 if tower_id=="barracks" else (1+.14*(preview_tier-1))/float(data.interval),2,"1 /秒" if tower_id=="barracks" else str(snappedf((1+.14*(preview_tier-1))/float(data.interval),.01))+" /秒")
	for index in range(3):ArenaMenuArt.selected(tier_buttons[index],index+1==preview_tier)
	var equipped_now:=tower_id in equipped
	equip_button.text=("%s   %d / %d"%[("卸下防御塔" if equipped_now else ("替换出战塔" if equipped.size()==ArenaDefinitions.LOADOUT_LIMIT else "装备防御塔")),equipped.size(),ArenaDefinitions.LOADOUT_LIMIT]);equip_button.disabled=game.campaign.locked or (equipped_now and equipped.size()==1);ArenaMenuArt.accent(equip_button,"green" if equipped_now else "amber")
	equip_button.tooltip_text="至少保留一类防御塔" if equipped_now and equipped.size()==1 else ""
	var symbols: Array={"archer":["farsight","rapid","pierce"],"mage":["frostheart","burn","starcore"],"cannon":["executioner","burn","warmachine"],"barracks":["ironwall","piercearrow","rapid"],"storm":["starlight","farsight","executioner"],"lens":["starcore","rapid","farsight"],"snare":["ironwall","pierce","warmachine"]}[tower_id]
	for index in range(3):route_titles[index].text=str(ArenaDoctrines.for_tower(tower_id)[index].name);route_icons[index].texture=ArenaMenuArt.perk(symbols[index])
	select_route(selected_route);feedback()
func select_tower(id: String) -> void:
	if id not in ArenaDefinitions.TOWER_IDS:return
	tower_id=id;preview_tier=1;selected_route=0;message="";_refresh_tower()
func select_tier(tier: int) -> void:preview_tier=clampi(tier,1,3);_refresh_tower()
func select_route(index: int) -> void:
	selected_route=clampi(index,0,2)
	var doctrine: Dictionary=ArenaDoctrines.for_tower(tower_id)[selected_route]
	if is_instance_valid(card_art) and preview_tier == 3:
		card_art.texture = hud.tower_image(tower_id, 3, str(doctrine.id))
	for i in range(route_buttons.size()):ArenaMenuArt.selected(route_buttons[i],i==selected_route)
	route_name.text=str(doctrine.name)+" · "+str(doctrine.role);route_body.text=str(doctrine.summary);route_body.scroll_to_line(0)
func toggle_tower() -> void:
	var equipped:=game.campaign.tower_loadout()
	if tower_id in equipped:equipped.erase(tower_id)
	elif equipped.size()==ArenaDefinitions.LOADOUT_LIMIT:
		var panel:=hud.modal_panel(Vector2(690,282))
		ArenaMenuArt.panel(panel,true)
		text(panel,"选择要换下的塔",Rect2(28,22,520,44),30,true)
		action(panel,"×",Rect2(590,12,72,60),hud.close_modal,"CancelReplacement")
		for slot in equipped.size():
			var old:=equipped[slot]
			var button:=action(panel,"",Rect2(24+slot*162,90,152,134),replace_tower.bind(slot),"Replace_"+old)
			var caption:=text(button,str(game.tower_display_data(old).name),Rect2(2,85,148,42),20);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			var r_img:=hud.image(button,hud.tower_portrait(old),Rect2(35,3,82,82))
			r_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		return
	else:equipped.append(tower_id)
	message="" if game.campaign.equip_towers(equipped) else (game.campaign.last_error if game.campaign.last_error!="" else "至少保留一类防御塔");_refresh_tower()
func replace_tower(slot: int) -> void:
	var equipped:=game.campaign.tower_loadout()
	if slot>=0 and slot<equipped.size() and tower_id not in equipped:
		equipped[slot]=tower_id
		message="" if game.campaign.equip_towers(equipped) else game.campaign.last_error
	hud.close_modal()
	_refresh_tower()
func growth() -> void:hud.show_codex()
func settings() -> void:
	var panel:=hud.modal_panel(Vector2(700,480));ArenaMenuArt.panel(panel,true)
	text(panel,"设置",Rect2(50,30,500,50),32,true);text(panel,"音量",Rect2(55,125,150,40),25,true)
	var volume:=HSlider.new();volume.name="Volume";volume.min_value=0;volume.max_value=1;volume.step=.05;volume.value=float(game.campaign.data.volume);volume.position=Vector2(210,130);volume.size=Vector2(420,60);panel.add_child(volume)
	var motion:=CheckButton.new();motion.name="ReduceMotion";motion.text="减少动态与闪烁";motion.add_theme_font_size_override("font_size",25);motion.add_theme_color_override("font_color",ArenaMenuArt.PAPER);motion.position=Vector2(55,220);motion.size=Vector2(560,70);motion.button_pressed=reduced();panel.add_child(motion)
	var error_label:=text(panel,"",Rect2(55,300,590,38),23,true)
	action(panel,"保存",Rect2(55,365,260,80),func():
		if game.campaign.settings(volume.value,motion.button_pressed):
			AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.0001,volume.value)));hud.close_modal()
			for child in hud.menu.get_children():
				if child is CPUParticles2D:child.emitting=not motion.button_pressed
		else:error_label.text=game.campaign.last_error,"SaveSettings",true)
	action(panel,"返回",Rect2(375,365,260,80),hud.close_modal,"CloseSettings")
func escape() -> void:
	if hud.has_modal():hud.close_modal()
	elif is_instance_valid(stage_panel):close_stage()
	elif page_id=="title":game.quit_game()
	elif page_id=="world":settings()
	else:levels()
