class_name ArenaFrontEnd
extends RefCounted
var hud: ArenaHUD
var game: ArenaGame
var stage:="forest"
var hero_id:="knight"
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
const ROLES:={"knight":"近战 · 拦截守线","ranger":"远程 · 穿透点杀","mage":"法术 · 范围控制"}
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
	var title:=text(hud.menu,"边境守望",Rect2(420,24,760,160),102);title.name="GameTitle";title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_color_override("font_color",Color("ffe8ac"));title.add_theme_color_override("font_outline_color",Color("14283b"));title.add_theme_constant_override("outline_size",11)
	action(hud.menu,"进入守望",Rect2(610,748,380,94),levels,"StartCampaign",true)
	utility(hud.menu,"settings",Rect2(1382,26,78,78),settings,"Settings").tooltip_text="设置"
	utility(hud.menu,"exit",Rect2(1490,26,78,78),game.quit_game,"ExitGame").tooltip_text="退出"
	if game.campaign.path==ArenaCampaign.PLAYTEST_PATH:text(hud.menu,"自由试玩",Rect2(46,830,210,36),24)
func levels() -> void:
	message="";base("world_atlas","world");wallet()
	utility(hud.menu,"back",Rect2(28,20,84,84),entry,"Back");utility(hud.menu,"settings",Rect2(1474,20,84,84),settings,"Settings")
	for index in range(ArenaLevelCatalog.IDS.size()):
		var key: String=ArenaLevelCatalog.IDS[index];var point: Vector2=ArenaLevelCatalog.WORLD_NODES[key].position
		var node:=action(hud.menu,"",Rect2(point-Vector2(48,94),Vector2(96,104)),prepare.bind(key),"Level_"+key,false,true)
		hud.image(node,ArenaMenuArt.utility("flag"),Rect2(5,0,86,90))
		var number:=text(node,str(index+1),Rect2(24,12,48,45),30);number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;number.add_theme_color_override("font_outline_color",Color("241b18"));number.add_theme_constant_override("outline_size",3)
		node.tooltip_text=ArenaLevelCatalog.definition(key).name
		if bool(game.campaign.data.cleared[key]):hud.image(node,ArenaMenuArt.utility("check"),Rect2(56,66,40,40))
		if not reduced():
			var float_tween:=node.create_tween().set_loops();float_tween.tween_property(node,"position:y",node.position.y-5,1.3).set_trans(Tween.TRANS_SINE);float_tween.tween_property(node,"position:y",node.position.y,1.3).set_trans(Tween.TRANS_SINE)
	# No invented three-star scoring: existing clear flags are the only earned marks.
	for point in [Vector2(1125,210),Vector2(1400,390),Vector2(1240,620)]:
		var lock:=hud.image(hud.menu,ArenaMenuArt.utility("lock"),Rect2(point,Vector2(48,48)));lock.modulate=Color(1,1,1,.45);lock.tooltip_text="远景地区 · 尚未开放";lock.mouse_filter=Control.MOUSE_FILTER_PASS
	dock()
func dock() -> void:
	var tray:=Control.new();tray.name="WorldLoadout";tray.position=Vector2(32,755);tray.size=Vector2(474,104);tray.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.menu.add_child(tray)
	var hero_button:=action(tray,"",Rect2(0,0,90,90),hall,"WorldHero");hero_button.tooltip_text=ArenaDefinitions.HEROES[game.campaign.selected_hero()].name
	hud.image(hero_button,hud.hero_badge_image(game.campaign.selected_hero()),Rect2(8,5,74,78))
	var equipped:=game.campaign.tower_loadout()
	for index in range(4):
		var button:=action(tray,"",Rect2(106+index*88,4,80,82),towers,"WorldTower_"+str(index))
		if index<equipped.size():hud.image(button,hud.tower_image(equipped[index]),Rect2(3,1,74,76));button.tooltip_text=ArenaDefinitions.TOWERS[equipped[index]].name
		else:hud.image(button,ArenaMenuArt.utility("range"),Rect2(26,26,28,28)).modulate.a=.35
	for item in [[0,1124,hall,"HeroHall","英雄"],[1,1270,towers,"TowerHall","防御塔"],[2,1416,growth,"被动图鉴","成长"]]:
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
	text(stage_panel,"8 波",Rect2(34,260,150,36),25)
	hud.image(stage_panel,ArenaMenuArt.utility("diamond"),Rect2(480,257,34,34));text(stage_panel,"+"+str(6 if game.campaign.data.cleared[stage] else 8),Rect2(524,258,90,38),26)
	for index in range(4):
		var enemy: String=["fox","brute","wisp","moth" if stage=="forest" else "spearman"][index]
		var image:=hud.image(stage_panel,ArenaMenuArt.creature(enemy),Rect2(31+index*66,317,62,72));image.tooltip_text=ArenaDefinitions.ENEMIES[enemy].name;image.mouse_filter=Control.MOUSE_FILTER_PASS
	var brief:=text(stage_panel,str(definition.story)+("\n单路守线 · 飞蛾首领" if stage=="forest" else "\n双路回防 · 精英合流"),Rect2(330,312,286,88),25);brief.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var ready:=game.campaign.can_deploy(stage)
	var deploy:=action(stage_panel,"战斗！",Rect2(222,446,392,84),deploy_stage,"Deploy",true);deploy.disabled=not ready
	if not ready:
		text(stage_panel,"需装备首波可建的塔",Rect2(36,401,575,36),24)
		action(stage_panel,"配置塔",Rect2(222,446,392,84),towers,"ConfigureTowers",true);deploy.hide()
func close_stage() -> void:
	if is_instance_valid(stage_panel):hud.menu.remove_child(stage_panel);stage_panel.queue_free()
	stage_panel=null
func deploy_stage() -> void:
	if game.campaign.can_deploy(stage):game.start_run(game.campaign.selected_hero(),stage)
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
	for index in range(3):
		var id: String=ArenaDefinitions.HERO_IDS[index]
		var button:=action(hud.menu,"",Rect2(622+index*106,20,84,84),select_hall.bind(id),"Hall_"+id)
		hud.image(button,hud.hero_badge_image(id),Rect2(6,4,72,76));roster[id]=button;button.tooltip_text=ArenaDefinitions.HEROES[id].name
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
	var data: Dictionary=ArenaDefinitions.HEROES[hero_id];var rank:=game.campaign.level(hero_id);var bonus:=game.campaign.bonuses(hero_id)
	for id in roster:
		ArenaMenuArt.selected(roster[id],id==hero_id);roster[id].position.y=16 if id==hero_id else 20
	card_art.texture=hud.hero_portrait(hero_id);rank_label.text="LV. "+str(rank)
	name_label.text=data.name;role_label.text=ROLES[hero_id]+" · "+ArenaCombat.label(int(data.type))
	var health:=float(data.health)*(1.0+float(bonus.health));var damage:=float(data.damage)*(1.0+float(bonus.attack))
	stat_icons[1].texture=ArenaMenuArt.icon(15) if int(data.type)==1 else ArenaMenuArt.utility("sword")
	_stat_value(0,health,360,str(roundi(health)),animated);_stat_value(1,damage,45,str(snappedf(damage,.1)),animated);_stat_value(2,1.0/float(data.interval),1.8,str(snappedf(1.0/float(data.interval),.01))+" /秒",animated)
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
	var details: Dictionary={"knight":["扇形重斩造成物理伤害，短暂眩晕前方敌人。","战吼持续强化附近英雄、士兵与防御塔，适合守线集火。"],"ranger":["朝移动方向翻滚，立刻获得短暂保护；松开移动时朝面向翻滚。","向指定落点降下六段物理箭雨，覆盖半径135的区域。"],"mage":["对周围半径125内造成法术伤害，并减速3秒。","指定落点0.85秒后受到法术轰击，半径155，附带短暂眩晕。"]}
	skill_body.text=str(details[hero_id][selected_skill])+("" if unlocked else "\n[color=#8d592d]LV."+str(2 if selected_skill==0 else 4)+" 解锁 · 可先查看效果[/color]")
func passive_text(id: String,rank: int) -> String:
	return {"knight":["拦截时近战减伤15%","拦截时近战减伤16%","拦截时近战减伤18%"],"ranger":["每第三箭额外贯穿一人","第三箭贯穿并额外伤害5%","第三箭贯穿并额外伤害10%"],"mage":["普攻附加10%魔法易伤","普攻附加11%魔法易伤","普攻附加12%魔法易伤"]}[id][rank]+"\n英雄LV.3、LV.5进一步强化天赋。"
func select_hall(key: String) -> void:
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
	for index in range(4):
		var id: String=ArenaDefinitions.TOWER_IDS[index]
		var button:=action(hud.menu,"",Rect2(568+index*106,20,84,84),select_tower.bind(id),"Tower_"+id)
		hud.image(button,hud.tower_image(id),Rect2(5,4,74,76));roster[id]=button;button.tooltip_text=ArenaDefinitions.TOWERS[id].name
	_make_card(492);card_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
	var data: Dictionary=ArenaDefinitions.TOWERS[tower_id];var equipped:=game.campaign.tower_loadout()
	for id in roster:ArenaMenuArt.selected(roster[id],id==tower_id);roster[id].position.y=16 if id==tower_id else 20
	card_art.texture=hud.tower_image(tower_id,preview_tier);rank_label.text=["I","II","III"][preview_tier-1]+" 阶"
	name_label.text=data.name;role_label.text=ArenaCombat.label(int(data.type))+(" · 范围轰击" if tower_id=="cannon" else (" · 驻军拦截" if tower_id=="barracks" else " · 自动攻击"))
	stat_icons[1].texture=ArenaMenuArt.utility("shield") if tower_id=="barracks" else (ArenaMenuArt.icon(15) if int(data.type)==1 else ArenaMenuArt.utility("sword"))
	_stat_value(0,float(data.reach)+(preview_tier-1)*16,320,str(roundi(float(data.reach)+(preview_tier-1)*16)))
	_stat_value(1,3 if tower_id=="barracks" else float(data.damage)*(1+.6*(preview_tier-1)),3 if tower_id=="barracks" else 130,"3 人" if tower_id=="barracks" else str(snappedf(float(data.damage)*(1+.6*(preview_tier-1)),.1)))
	_stat_value(2,1.0 if tower_id=="barracks" else (1+.14*(preview_tier-1))/float(data.interval),2,"1 /秒" if tower_id=="barracks" else str(snappedf((1+.14*(preview_tier-1))/float(data.interval),.01))+" /秒")
	for index in range(3):ArenaMenuArt.selected(tier_buttons[index],index+1==preview_tier)
	var equipped_now:=tower_id in equipped
	equip_button.text="卸下防御塔" if equipped_now else "装备防御塔";equip_button.disabled=game.campaign.locked or (equipped_now and equipped.size()==1);ArenaMenuArt.accent(equip_button,"green" if equipped_now else "amber")
	equip_button.tooltip_text="至少保留一类防御塔" if equipped_now and equipped.size()==1 else ""
	var symbols: Array={"archer":["farsight","rapid","pierce"],"mage":["frostheart","burn","starcore"],"cannon":["executioner","burn","warmachine"],"barracks":["ironwall","piercearrow","rapid"]}[tower_id]
	for index in range(3):route_titles[index].text=str(ArenaDoctrines.for_tower(tower_id)[index].name);route_icons[index].texture=ArenaMenuArt.perk(symbols[index])
	select_route(selected_route);feedback()
func select_tower(id: String) -> void:
	if id not in ArenaDefinitions.TOWER_IDS:return
	tower_id=id;preview_tier=1;selected_route=0;message="";_refresh_tower()
func select_tier(tier: int) -> void:preview_tier=clampi(tier,1,3);_refresh_tower()
func select_route(index: int) -> void:
	selected_route=clampi(index,0,2)
	var doctrine: Dictionary=ArenaDoctrines.for_tower(tower_id)[selected_route]
	for i in range(route_buttons.size()):ArenaMenuArt.selected(route_buttons[i],i==selected_route)
	route_name.text=str(doctrine.name)+" · "+str(doctrine.role);route_body.text=str(doctrine.summary);route_body.scroll_to_line(0)
func toggle_tower() -> void:
	var equipped:=game.campaign.tower_loadout()
	if tower_id in equipped:equipped.erase(tower_id)
	else:equipped.append(tower_id)
	message="" if game.campaign.equip_towers(equipped) else (game.campaign.last_error if game.campaign.last_error!="" else "至少保留一类防御塔");_refresh_tower()
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
