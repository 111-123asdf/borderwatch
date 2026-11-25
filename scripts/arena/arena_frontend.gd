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
var roster_pips: Dictionary={}
var deployed_hero_img: TextureRect
var card: Control
var card_frame_overlay: NinePatchRect
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
var skill_lock_badges: Array[TextureRect]=[]
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
var loadout_slots: Array[Button]=[]
var loadout_icons: Array[TextureRect]=[]
var loadout_count: Label
var tower_ticker: Node
var tower_glow: TextureRect
const ROLES:={"lord":"重装 · 宽弧横扫","druid":"召唤 · 双狼协同","healer":"圣光 · 溢疗化伤","werewolf":"狂战 · 爪击溅射","gunner":"游射 · 穿透连射"}

class _SettingsKeyCatcher:
	extends Node
	var owner_frontend: ArenaFrontEnd
	var buttons := {}
	var active_action := ""
	var err_label: Label
	func _input(event: InputEvent) -> void:
		if active_action.is_empty(): return
		if not (event is InputEventKey and event.pressed and not event.echo): return
		var kc := (event as InputEventKey).keycode
		if kc == KEY_ESCAPE:
			active_action = ""
			_refresh()
			get_viewport().set_input_as_handled()
			return
		var ok: bool = owner_frontend.game.campaign.set_keybind(active_action, kc)
		if is_instance_valid(err_label):
			err_label.text = "" if ok else owner_frontend.game.campaign.last_error
		active_action = ""
		_refresh()
		get_viewport().set_input_as_handled()
	func _refresh() -> void:
		for act in buttons:
			var b: Button = buttons[act]
			if not is_instance_valid(b): continue
			if active_action == act:
				b.text = "按下新按键…"
			else:
				b.text = owner_frontend.game.campaign.keybind_label(act)

class _MapTrailLayer:
	extends Control
	var cleared_map: Dictionary={}
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var cleared_count: int=0
		for id in ArenaLevelCatalog.IDS:
			if bool(cleared_map.get(id,false)):
				cleared_count+=1
		for trail_idx in range(ArenaLevelCatalog.MAP_TRAILS.size()):
			var pts: Array=ArenaLevelCatalog.MAP_TRAILS[trail_idx]
			var lit: bool=trail_idx < maxi(1, cleared_count)
			var col: Color=Color("f3cc6599") if lit else Color("b4cad866")
			var rim: Color=Color("071018aa")
			for i in range(pts.size()-1):
				var p0: Vector2=pts[i]
				var p1: Vector2=pts[i+1]
				var dist: float=p0.distance_to(p1)
				var steps: int=maxi(2, int(floorf(dist / 22.0)))
				for s in range(1, steps):
					var pos: Vector2=p0.lerp(p1, float(s) / float(steps))
					draw_circle(pos, 3.4, rim)
					draw_circle(pos, 2.1, col)

class _LoadoutRingDecor:
	extends Control
	const CENTER:=Vector2(146,226)
	const SOCKETS:=[Vector2(146,126),Vector2(46,226),Vector2(246,226),Vector2(146,326)]
	func _ready() -> void:
		mouse_filter=Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_arc(CENTER, 100.0, 0.0, TAU, 48, Color("2e485c99"), 3.0)
		draw_arc(CENTER, 100.0, 0.0, TAU, 48, Color("6c8da3aa"), 1.2)
		for i in range(SOCKETS.size()):
			var a: Vector2=SOCKETS[i]
			var b: Vector2=SOCKETS[(i + 1) % SOCKETS.size()]
			draw_line(a, b, Color("10202ccc"), 5.0)
			draw_line(a, b, Color("517087cc"), 2.0)

class _TowerShowcaseTicker:
	extends Node
	var target: TextureRect
	var tower_kind:=""
	var tier_num:=1
	var doctrine_id:=""
	var reduced_motion:=false
	var pulse_clock:=1.6
	var anim_clock:=0.0
	var anim_step:=0
	var playing:=false
	func setup(art: TextureRect,kind: String,tier: int,doc: String,is_reduced: bool,burst: bool) -> void:
		target=art
		var changed: bool=(tower_kind != kind or tier_num != tier or doctrine_id != doc)
		tower_kind=kind
		tier_num=tier
		doctrine_id=doc
		reduced_motion=is_reduced
		if reduced_motion:
			playing=false
			anim_step=0
			_apply_frame()
			return
		if burst or changed:
			trigger_burst()
		else:
			_apply_frame()
	func trigger_burst() -> void:
		if reduced_motion:
			anim_step=0
			_apply_frame()
			return
		playing=true
		anim_step=1
		anim_clock=0.11
		pulse_clock=2.6
		_apply_frame()
	func _process(delta: float) -> void:
		if not is_instance_valid(target) or tower_kind.is_empty():
			return
		if reduced_motion:
			return
		if playing:
			anim_clock-=delta
			if anim_clock<=0.0:
				anim_step+=1
				if anim_step>3:
					anim_step=0
					playing=false
				else:
					anim_clock=0.11
				_apply_frame()
		else:
			pulse_clock-=delta
			if pulse_clock<=0.0:
				trigger_burst()
	func _apply_frame() -> void:
		if not is_instance_valid(target):
			return
		var tex: Texture2D=ArenaBattleArt.tower_frame_texture(tower_kind, tier_num, doctrine_id, anim_step)
		if tex == null:
			tex=ArenaBattleArt.tower_texture(tower_kind, tier_num, doctrine_id)
		target.texture=tex
		target.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func _init(owner: ArenaHUD) -> void:
	hud=owner;game=owner.game;hero_id=game.campaign.selected_hero()

func reduced() -> bool:
	return bool(game.campaign.data.reduced_motion)

func base(background: String,page_name: String) -> void:
	page_id=page_name;stage_panel=null;roster.clear();roster_pips.clear();deployed_hero_img=null
	stat_bars.clear();stat_values.clear();stat_icons.clear()
	skill_buttons.clear();skill_images.clear();skill_lock_badges.clear()
	rank_stars.clear();tier_buttons.clear();route_buttons.clear();route_titles.clear();route_icons.clear()
	loadout_slots.clear();loadout_icons.clear();loadout_count=null;tower_ticker=null;tower_glow=null;card_frame_overlay=null
	hud.reset_menu();hud.menu.modulate=Color.WHITE
	var tex: Texture2D=ArenaMenuArt.v027(background)
	if tex==null: tex=ArenaMenuArt.texture(background)
	var image: TextureRect=hud.image(hud.menu,tex,Rect2(0,0,1600,900),true);image.name="Scenery"
	notice=text(hud.menu,"",Rect2(420,852,760,34),21);notice.name="FrontMessage";notice.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_color",ArenaMenuArt.STEEL_GOLD)

func frame(parent: Node,rect: Rect2,inset:=false) -> Panel:
	var panel:=Panel.new();panel.position=rect.position;panel.size=rect.size;panel.mouse_filter=Control.MOUSE_FILTER_STOP
	parent.add_child(panel);ArenaMenuArt.obsidian_panel(panel,inset);return panel

func text(parent: Node,value: String,rect: Rect2,size:=24,colour:=ArenaMenuArt.STEEL_TEXT) -> Label:
	var lbl: Label=hud.label(parent,value,rect,size,colour)
	lbl.add_theme_color_override("font_outline_color",Color("060d14"))
	lbl.add_theme_constant_override("outline_size",2)
	return lbl

func body(parent: Node,rect: Rect2,size:=21) -> RichTextLabel:
	var label:=RichTextLabel.new();label.position=rect.position;label.size=rect.size;label.bbcode_enabled=true;label.scroll_active=true
	label.add_theme_font_size_override("normal_font_size",size);label.add_theme_font_size_override("bold_font_size",size+1)
	label.add_theme_color_override("default_color",ArenaMenuArt.STEEL_TEXT);parent.add_child(label);return label

func action(parent: Node,caption: String,rect: Rect2,callback: Callable,key: String,tone:="steel",plain:=false) -> Button:
	var button:=hud.button(parent,caption,rect,callback);button.name=key
	ArenaMenuArt.steel_button(button,tone,plain);ArenaMenuArt.interact(button,reduced())
	button.pressed.connect(func():game.audio.play("ui_click",-26,1.4));return button

func utility(parent: Node,kind: String,rect: Rect2,callback: Callable,key: String,tone:="steel") -> Button:
	var button:=action(parent,"",rect,callback,key,tone)
	var pad: float=14.0 if rect.size.x >= 72.0 else 12.0
	var ic: TextureRect=hud.image(button,ArenaMenuArt.utility(kind),Rect2(Vector2(pad,pad),rect.size-Vector2.ONE*(pad*2.0)))
	ic.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	return button

func wallet() -> void:
	var is_playtest: bool=game.campaign.path==ArenaCampaign.PLAYTEST_PATH
	var pill:=Panel.new();pill.name="Wallet";pill.position=Vector2(106 if page_id=="world" else 1244,22);pill.size=Vector2(246 if is_playtest else 196,64)
	pill.mouse_filter=Control.MOUSE_FILTER_IGNORE;ArenaMenuArt.steel_rail(pill);hud.menu.add_child(pill)
	hud.image(pill,ArenaMenuArt.utility("diamond"),Rect2(14,12,40,40))
	wallet_value=text(pill,str(game.campaign.gems()),Rect2(62,14,120,38),28,ArenaMenuArt.STEEL_TEXT)
	if is_playtest:
		var badge:=Panel.new();badge.position=Vector2(174,17);badge.size=Vector2(56,28);badge.mouse_filter=Control.MOUSE_FILTER_IGNORE
		ArenaMenuArt.obsidian_panel(badge,true);pill.add_child(badge)
		var pt:=text(badge,"试玩",Rect2(0,1,56,26),15,ArenaMenuArt.STEEL_CYAN);pt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func header(title: String,back: Callable) -> void:
	utility(hud.menu,"back",Rect2(24,20,68,68),back,"Back")
	var label:=text(hud.menu,title,Rect2(108,31,220,46),30,ArenaMenuArt.STEEL_TEXT)
	label.add_theme_color_override("font_outline_color",Color("071018"));label.add_theme_constant_override("outline_size",4)
	wallet();utility(hud.menu,"settings",Rect2(1506,20,68,68),settings,"Settings")

func feedback() -> void:
	if is_instance_valid(notice):notice.text=message

func entry() -> void:
	message="";base("title_bg","title")
	# Pure KR5 centerpiece logo in the dark twilight upper-center sky
	var logo: TextureRect=hud.image(hud.menu,ArenaMenuArt.v027("title_logo"),Rect2(470,22,660,280))
	logo.name="TitleLogo";logo.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	if not reduced():
		var logo_tween: Tween=logo.create_tween().set_loops()
		logo_tween.tween_property(logo,"position:y",logo.position.y+4.0,1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		logo_tween.tween_property(logo,"position:y",logo.position.y,1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var start:=action(hud.menu,"进入守望",Rect2(620,742,360,80),levels,"StartCampaign","gold")
	start.add_theme_font_size_override("font_size",31)
	start.tooltip_text="前往战役地图，选择关卡与出战阵容"
	var settings_button:=utility(hud.menu,"settings",Rect2(1418,22,68,68),settings,"Settings")
	settings_button.tooltip_text="设置"
	var exit_button:=utility(hud.menu,"exit",Rect2(1506,22,68,68),game.quit_game,"ExitGame")
	exit_button.tooltip_text="退出游戏"
	start.focus_next=start.get_path_to(settings_button);start.focus_previous=start.get_path_to(exit_button)
	settings_button.focus_next=settings_button.get_path_to(exit_button);settings_button.focus_previous=settings_button.get_path_to(start)
	exit_button.focus_next=exit_button.get_path_to(start);exit_button.focus_previous=exit_button.get_path_to(settings_button)
	start.grab_focus()
	_title_status()

func _title_status() -> void:
	var cleared:=0
	for key in ArenaLevelCatalog.IDS:
		if bool(game.campaign.data.cleared.get(key,false)):cleared+=1
	var left_pill:=hud.colour_block(hud.menu,Rect2(26,846,162,32),Color(0.03,0.07,0.11,0.52))
	left_pill.name="TitleProgressBg"
	var progress:=text(hud.menu,"战役  %d / %d"%[cleared,ArenaLevelCatalog.IDS.size()],Rect2(34,849,148,28),17,Color("a4bccf"))
	progress.name="TitleProgress"
	var identity: String=game.campaign.selected_hero()
	var hero_txt: String="%s · LV.%d"%[ArenaDefinitions.HEROES[identity].name,game.campaign.level(identity)]
	var right_pill:=hud.colour_block(hud.menu,Rect2(1310,846,264,32),Color(0.03,0.07,0.11,0.52))
	right_pill.name="TitleStatusBg"
	var hero_lbl:=text(hud.menu,hero_txt,Rect2(1318,849,182,28),17,Color("b7ccdc"))
	hero_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	var ver:=text(hud.menu,"v"+str(ProjectSettings.get_setting("application/config/version")),Rect2(1504,849,64,28),15,Color("738b9e"))
	ver.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT

func levels() -> void:
	message="";base("world_map","world");wallet()
	var trails:=_MapTrailLayer.new();trails.cleared_map=game.campaign.data.cleared.duplicate();trails.size=Vector2(1600,900);hud.menu.add_child(trails)
	utility(hud.menu,"back",Rect2(24,20,68,68),entry,"Back")
	utility(hud.menu,"settings",Rect2(1506,20,68,68),settings,"Settings")
	for index in range(ArenaLevelCatalog.IDS.size()):
		var key: String=ArenaLevelCatalog.IDS[index];var point: Vector2=ArenaLevelCatalog.WORLD_NODES[key].position
		var cleared: bool=bool(game.campaign.data.cleared.get(key,false))
		var node:=action(hud.menu,"",Rect2(point-Vector2(42,84),Vector2(84,96)),prepare.bind(key),"Level_"+key,"steel",true)
		var shield:=hud.image(node,ArenaMenuArt.v027("stage_shield_cleared" if cleared else "stage_shield_open"),Rect2(0,0,84,96))
		shield.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var number:=text(node,str(index+1),Rect2(18,22,48,40),27,ArenaMenuArt.STEEL_GOLD if cleared else Color("fff2cc"))
		number.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		number.add_theme_color_override("font_outline_color",Color("060d14"));number.add_theme_constant_override("outline_size",4)
		node.tooltip_text=ArenaLevelCatalog.definition(key).name
		if not reduced():
			var float_tween:=node.create_tween().set_loops()
			float_tween.tween_property(node,"position:y",node.position.y-3.5,1.4).set_trans(Tween.TRANS_SINE)
			float_tween.tween_property(node,"position:y",node.position.y,1.4).set_trans(Tween.TRANS_SINE)
	for entry_lock in ArenaLevelCatalog.FUTURE_LOCKS:
		var lpos: Vector2=entry_lock.pos
		var lock:=hud.image(hud.menu,ArenaMenuArt.v027("stage_lock_seal"),Rect2(lpos-Vector2(21,21),Vector2(42,42)))
		lock.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		lock.modulate=Color(1.0,1.0,1.0,0.82)
		lock.tooltip_text=str(entry_lock.tip)
		lock.mouse_filter=Control.MOUSE_FILTER_PASS
	dock()

func dock() -> void:
	var tray:=Control.new();tray.name="WorldLoadout";tray.position=Vector2(24,778);tray.size=Vector2(474,94);tray.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.menu.add_child(tray)
	var tray_bg:=Panel.new();tray_bg.position=Vector2.ZERO;tray_bg.size=tray.size;tray_bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;ArenaMenuArt.steel_rail(tray_bg);tray.add_child(tray_bg)
	var hero_button:=action(tray,"",Rect2(14,7,80,80),hall,"WorldHero")
	ArenaMenuArt.steel_slot(hero_button,false,ArenaMenuArt.STEEL_GOLD)
	hero_button.tooltip_text=ArenaDefinitions.HEROES[game.campaign.selected_hero()].name
	var hero_img:=hud.image(hero_button,hud.hero_badge_image(game.campaign.selected_hero()),Rect2(6,5,68,70));hero_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	hud.colour_block(tray,Rect2(104,14,2,66),Color("3b586e99"))
	var equipped:=game.campaign.tower_loadout()
	for index in range(4):
		var button:=action(tray,"",Rect2(116+index*86,9,76,76),towers,"WorldTower_"+str(index))
		ArenaMenuArt.steel_slot(button,false,ArenaMenuArt.STEEL_CYAN)
		if index<equipped.size():
			var w_img:=hud.image(button,hud.tower_portrait(equipped[index]),Rect2(4,3,68,70));w_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			button.tooltip_text=game.tower_display_data(equipped[index]).name
		else:
			hud.image(button,ArenaMenuArt.v027("equipped_pip"),Rect2(26,26,24,24)).modulate.a=0.25
	var nav_items: Array=[["dock_hero",hall,"HeroHall","英雄"],["dock_tower",towers,"TowerHall","防御塔"]]
	var count: int=nav_items.size()
	var start_x: float=1572.0 - float(count) * 140.0
	for i in range(count):
		var item: Array=nav_items[i]
		var button:=action(hud.menu,"",Rect2(start_x+float(i)*140.0,734,124,142),item[1],item[2],"steel",true)
		var med:=hud.image(button,ArenaMenuArt.v027(str(item[0])),Rect2(8,2,108,108));med.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var plate:=Panel.new();plate.position=Vector2(14,104);plate.size=Vector2(96,30);plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
		ArenaMenuArt.obsidian_panel(plate,true);button.add_child(plate)
		var caption:=text(plate,str(item[3]),Rect2(0,1,96,28),18,ArenaMenuArt.STEEL_TEXT);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func prepare(key: String) -> void:
	if key not in ArenaLevelCatalog.IDS:return
	stage=key;close_stage()
	stage_panel=frame(hud.menu,Rect2(836,148,668,592));stage_panel.name="StagePanel"
	var definition:=ArenaLevelCatalog.definition(stage)
	var preview_bg:=Panel.new();preview_bg.position=Vector2(22,20);preview_bg.size=Vector2(624,178);preview_bg.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.obsidian_panel(preview_bg,true);stage_panel.add_child(preview_bg)
	var prev_img := hud.image(preview_bg,load(definition.get("preview_art",definition.get("map_art",ArenaBattleArt.map_path(stage)))),Rect2(6,6,612,166),true)
	if stage in ["saltport","lighthouse","ruins","sanctum"]:
		prev_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var close:=action(stage_panel,"×",Rect2(582,12,68,62),close_stage,"CloseStage","steel");close.add_theme_font_size_override("font_size",32)
	text(stage_panel,definition.name,Rect2(28,214,470,46),32,ArenaMenuArt.STEEL_TEXT)
	var wave_pill:=Panel.new();wave_pill.position=Vector2(28,266);wave_pill.size=Vector2(142,34);wave_pill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.obsidian_panel(wave_pill,true);stage_panel.add_child(wave_pill)
	var w_lbl:=text(wave_pill,str(int(definition.get("waves",5)))+" 轮 · 双域",Rect2(0,3,142,28),18,ArenaMenuArt.STEEL_CYAN);w_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var rew_pill:=Panel.new();rew_pill.position=Vector2(516,264);rew_pill.size=Vector2(124,36);rew_pill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.obsidian_panel(rew_pill,true);stage_panel.add_child(rew_pill)
	hud.image(rew_pill,ArenaMenuArt.utility("diamond"),Rect2(12,4,28,28))
	text(rew_pill,"+"+str(6 if bool(game.campaign.data.cleared.get(stage,false)) else 8),Rect2(48,4,66,28),21,ArenaMenuArt.STEEL_GOLD)
	var briefing:=frame(stage_panel,Rect2(24,316,620,148),true)
	var preview_list: Array=definition.get("preview_enemies",["pigsoldier","tusk_fighter","dreadeye_viper","bear_vanguard"])
	for index in range(min(4,preview_list.size())):
		var enemy: String=str(preview_list[index])
		var slot_box:=Panel.new();slot_box.position=Vector2(18+index*72,40);slot_box.size=Vector2(66,66);slot_box.mouse_filter=Control.MOUSE_FILTER_IGNORE
		ArenaMenuArt.obsidian_panel(slot_box,false);briefing.add_child(slot_box)
		var image:=hud.image(slot_box,ArenaMenuArt.creature(enemy),Rect2(4,4,58,58))
		image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var edata := ArenaDefinitions.enemy(enemy)
		var etrait := str(edata.get("trait",""))
		image.tooltip_text=str(edata.name)+("\n"+etrait if etrait!="" else "")
		image.mouse_filter=Control.MOUSE_FILTER_PASS
	var tagline: String="\n"+str(definition.get("tagline",""))
	if str(definition.get("tagline","")).is_empty():tagline=""
	var brief:=text(briefing,str(definition.story)+tagline,Rect2(318,34,282,92),21,ArenaMenuArt.STEEL_TEXT);brief.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var ready:=game.campaign.can_deploy(stage,game.defense_rules)
	var deploy:=action(stage_panel,"战斗！",Rect2(164,486,340,76),deploy_stage,"Deploy","cyan");deploy.disabled=not ready
	deploy.add_theme_font_size_override("font_size",28)
	if not ready:
		var warn:=text(stage_panel,"需先装备首波可建防御塔",Rect2(24,458,620,26),18,ArenaMenuArt.STEEL_GOLD);warn.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var cfg:=action(stage_panel,"配置防御塔",Rect2(164,486,340,76),towers,"ConfigureTowers","gold")
		cfg.add_theme_font_size_override("font_size",26);deploy.hide()

func close_stage() -> void:
	if is_instance_valid(stage_panel):hud.menu.remove_child(stage_panel);stage_panel.queue_free()
	stage_panel=null

func deploy_stage() -> void:
	if game.campaign.can_deploy(stage,game.defense_rules):game.start_run(game.campaign.selected_hero(),stage)

func _make_card(pos: Vector2,card_size: Vector2,inset_size: Vector2) -> void:
	card=Control.new();card.name="PortraitCard";card.position=pos;card.size=card_size;card.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.menu.add_child(card)
	var offset: Vector2=(card_size-inset_size)*0.5
	var clip:=Control.new();clip.name="CardClip";clip.position=offset;clip.size=inset_size;clip.clip_contents=true;clip.mouse_filter=Control.MOUSE_FILTER_IGNORE;card.add_child(clip)
	hud.colour_block(clip,Rect2(Vector2.ZERO,clip.size),Color("0a1520"))
	card_art=hud.image(clip,null,Rect2(Vector2.ZERO,clip.size));card_art.name="CardPortrait";card_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_frame_overlay=NinePatchRect.new();card_frame_overlay.name="CardFrameOverlay";card_frame_overlay.texture=ArenaMenuArt.v027("card_frame_steel")
	card_frame_overlay.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	card_frame_overlay.size=card_size;card_frame_overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	card_frame_overlay.patch_margin_left=18;card_frame_overlay.patch_margin_right=18;card_frame_overlay.patch_margin_top=18;card_frame_overlay.patch_margin_bottom=18
	card.add_child(card_frame_overlay)

func _make_vertical_stat(parent: Node,kind: String,y: float) -> void:
	stat_icons.append(hud.image(parent,ArenaMenuArt.v027(kind),Rect2(24,y,28,28)))
	var v_lbl:=text(parent,"",Rect2(60,y+1,172,28),22,ArenaMenuArt.STEEL_TEXT);v_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	stat_values.append(v_lbl)
	var bar:=ProgressBar.new();bar.position=Vector2(24,y+36);bar.size=Vector2(208,11);bar.show_percentage=false;bar.max_value=1.0
	ArenaMenuArt.stat_bar_theme(bar);parent.add_child(bar);stat_bars.append(bar)

func _make_inline_stat(parent: Node,kind: String,x: float,y: float) -> void:
	var ic:=hud.image(parent,ArenaMenuArt.v027(kind),Rect2(x,y,28,28));ic.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	stat_icons.append(ic)
	var v_lbl:=text(parent,"",Rect2(x+34,y+1,170,28),21,ArenaMenuArt.STEEL_TEXT);v_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	stat_values.append(v_lbl)
	var bar:=ProgressBar.new();bar.position=Vector2(x,y+35);bar.size=Vector2(204,11);bar.show_percentage=false;bar.max_value=1.0
	ArenaMenuArt.stat_bar_theme(bar);parent.add_child(bar);stat_bars.append(bar)

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
	var rail:=Panel.new();rail.name="RosterRail";rail.position=Vector2(382,12);rail.size=Vector2(700,92);rail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.steel_rail(rail);hud.menu.add_child(rail)
	var eq_tag:=text(rail,"出战",Rect2(14,7,76,18),13,ArenaMenuArt.STEEL_GOLD);eq_tag.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var eq_box:=Panel.new();eq_box.position=Vector2(22,26);eq_box.size=Vector2(60,56);eq_box.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.obsidian_panel(eq_box,true);rail.add_child(eq_box)
	deployed_hero_img=hud.image(eq_box,hud.hero_badge_image(game.campaign.selected_hero()),Rect2(4,3,52,50));deployed_hero_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	hud.colour_block(rail,Rect2(100,14,2,64),Color("3a566b99"))
	for index in range(ArenaDefinitions.HERO_IDS.size()):
		var id: String=ArenaDefinitions.HERO_IDS[index]
		var button:=action(rail,"",Rect2(124+index*112,8,80,76),select_hall.bind(id),"Hall_"+id)
		var r_img:=hud.image(button,hud.hero_badge_image(id),Rect2(6,4,68,68));r_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var pip:=hud.image(button,ArenaMenuArt.v027("equipped_pip"),Rect2(56,52,20,20));pip.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		roster[id]=button;roster_pips[id]=pip;button.tooltip_text=ArenaDefinitions.HEROES[id].name
	var pillar:=frame(hud.menu,Rect2(88,152,256,560));pillar.name="StatPillar"
	var lv_pill:=Panel.new();lv_pill.position=Vector2(58,20);lv_pill.size=Vector2(140,42);lv_pill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.obsidian_panel(lv_pill,true);pillar.add_child(lv_pill)
	rank_label=text(lv_pill,"",Rect2(0,5,140,34),24,ArenaMenuArt.STEEL_GOLD);rank_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for index in range(5):
		var star:=hud.image(pillar,ArenaMenuArt.v027("star_off"),Rect2(32+index*39,80,32,32));star.name="HeroRank_"+str(index+1)
		star.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;rank_stars.append(star)
	hud.colour_block(pillar,Rect2(24,132,208,1),Color("294254cc"))
	_make_vertical_stat(pillar,"stat_hp",166)
	_make_vertical_stat(pillar,"stat_atk",278)
	_make_vertical_stat(pillar,"stat_spd",390)
	_make_card(Vector2(372,136),Vector2(384,564),Vector2(360,540))
	card_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	card_art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	equip_button=action(hud.menu,"",Rect2(414,682,300,62),equip_hero,"EquipHero","cyan")
	detail_panel=frame(hud.menu,Rect2(780,152,732,560));detail_panel.name="HeroDetails"
	name_label=text(detail_panel,"",Rect2(34,24,660,46),34,ArenaMenuArt.STEEL_TEXT)
	role_label=text(detail_panel,"",Rect2(36,74,660,30),20,ArenaMenuArt.STEEL_CYAN)
	for index in range(3):
		var sx: float=36.0+float(index)*112.0
		var button:=action(detail_panel,"",Rect2(sx,118,84,84),select_skill.bind(index),"HeroSkill_"+str(index) if index<2 else "HeroPassive")
		skill_buttons.append(button)
		var simg:=hud.image(button,null,Rect2(8,8,68,68));simg.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;skill_images.append(simg)
		var lock_b:=hud.image(button,ArenaMenuArt.v027("lock_badge"),Rect2(56,56,24,24));lock_b.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		lock_b.visible=false;skill_lock_badges.append(lock_b)
		var cap:=text(detail_panel,["Q","E","被动"][index],Rect2(sx,206,84,26),18,ArenaMenuArt.STEEL_MUTED);cap.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var info:=frame(detail_panel,Rect2(30,248,672,198),true)
	skill_title=text(info,"",Rect2(24,16,620,34),24,ArenaMenuArt.STEEL_GOLD);skill_title.name="HeroSkillTitle"
	skill_body=body(info,Rect2(24,58,620,124),21);skill_body.name="HeroSkillDescription"
	text(detail_panel,"LV.2 / LV.4 解锁技能 · LV.3 / LV.5 强化天赋",Rect2(34,488,360,26),16,Color("6e889c"))
	upgrade_button=action(detail_panel,"",Rect2(410,468,292,66),upgrade_hero,"UpgradeHero","gold")
	_refresh_hero()

func _refresh_hero(animated:=false) -> void:
	hero_id=ArenaDefinitions.resolve_hero_id(hero_id)
	var data: Dictionary=ArenaDefinitions.HEROES[hero_id];var rank: int=game.campaign.level(hero_id);var bonus:=game.campaign.bonuses(hero_id)
	var equipped_hero: String=game.campaign.selected_hero()
	if is_instance_valid(deployed_hero_img):
		deployed_hero_img.texture=hud.hero_badge_image(equipped_hero)
	for id in roster:
		ArenaMenuArt.steel_slot(roster[id],id==hero_id,ArenaMenuArt.STEEL_CYAN)
		roster[id].position.y=6 if id==hero_id else 8
		roster_pips[id].visible=(id==equipped_hero)
	var card_tex: Texture2D=ArenaMenuArt.v027("hero_card_"+hero_id)
	card_art.texture=card_tex if card_tex!=null else hud.hero_portrait(hero_id)
	card_art.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR if card_tex!=null else CanvasItem.TEXTURE_FILTER_NEAREST
	if is_instance_valid(card_frame_overlay):
		card_frame_overlay.texture=ArenaMenuArt.v027("card_frame_gold" if hero_id==equipped_hero else "card_frame_steel")
	rank_label.text="LV. "+str(rank)
	name_label.text=data.name;role_label.text=ROLES[hero_id]+" · "+ArenaCombat.label(int(data.type))
	var health:=float(data.health)*(1.0+float(bonus.health));var damage:=float(data.damage)*(1.0+float(bonus.attack))
	stat_icons[1].texture=ArenaMenuArt.icon(15) if int(data.type)==1 else ArenaMenuArt.v027("stat_atk")
	_stat_value(0,health,480,str(roundi(health)),animated);_stat_value(1,damage,45,str(snappedf(damage,.1)),animated);_stat_value(2,1.0/float(data.interval),2.0,str(snappedf(1.0/float(data.interval),.01))+" /秒",animated)
	for slot in range(3):
		skill_images[slot].texture=ArenaMenuArt.skill(hero_id,slot)
		var is_open: bool=(slot==2 or game.campaign.skill_unlocked(hero_id,slot))
		skill_images[slot].modulate=Color.WHITE if is_open else Color(0.45,0.52,0.60)
		skill_lock_badges[slot].visible=not is_open
	for index in range(5):
		rank_stars[index].texture=ArenaMenuArt.v027("star_on" if rank>index else "star_off")
	var active:=equipped_hero==hero_id
	equip_button.text="✓ 已出战" if active else "设为出战";equip_button.disabled=active or game.campaign.locked
	ArenaMenuArt.steel_button(equip_button,"steel" if active else "cyan")
	if active:
		equip_button.add_theme_stylebox_override("disabled",ArenaMenuArt.nine_patch("btn_steel",14,8,Color(0.95,0.98,1.0)))
		equip_button.add_theme_color_override("font_disabled_color",ArenaMenuArt.STEEL_TEXT)
	var price:=game.campaign.price(hero_id);upgrade_button.text="已满级" if rank==5 else "升级    "+str(price)
	upgrade_button.icon=null if rank==5 else ArenaMenuArt.utility("diamond");upgrade_button.expand_icon=true;upgrade_button.icon_alignment=HORIZONTAL_ALIGNMENT_RIGHT;upgrade_button.add_theme_constant_override("icon_max_width",26)
	upgrade_button.disabled=rank==5 or game.campaign.gems()<price or game.campaign.locked
	ArenaMenuArt.steel_button(upgrade_button,"muted" if rank==5 else "gold")
	wallet_value.text=str(game.campaign.gems());select_skill(selected_skill);feedback()

func select_skill(slot: int) -> void:
	selected_skill=clampi(slot,0,2)
	for index in range(skill_buttons.size()):
		ArenaMenuArt.steel_slot(skill_buttons[index],index==selected_skill,ArenaMenuArt.STEEL_GOLD)
	var data: Dictionary=ArenaDefinitions.HEROES[hero_id]
	if selected_skill==2:
		skill_title.text="职业天赋";skill_body.text=passive_text(hero_id,int(game.campaign.bonuses(hero_id).passive));return
	var unlocked:=game.campaign.skill_unlocked(hero_id,selected_skill)
	skill_title.text=str(data.small if selected_skill==0 else data.ultimate)+"  ·  "+str(data.small_cd if selected_skill==0 else data.ultimate_cd)+"秒"
	var details: Dictionary={
		"lord":["向前方挥出大范围血剑横斩（+20%横扫幅度），重创群怪并震慑打断攻势。","展开血棘圣盾，获得50%最大生命护盾、6秒35%减伤与+1拦截上限，并周期反伤周围敌人。"],
		"druid":["指定位置或敌人，驱使寒霜狼与赤焰狼冲锋集火并溅射周围敌人，同时为双狼回复30%生命。","唤醒双狼野性：随同穿越裂隙作战，体型平滑变大至1.35倍，7秒内移速+25%、攻速+40%、攻击+45%。"],
		"healer":["绽放花灵圣光造成范围法伤并治疗自身，触发「圣光溢疗化伤」对周围敌人迸发圣光爆裂，5秒内友军与塔攻速+20%。","召唤5秒圣泉领域，持续为自身（溢出转护盾并每次触发圣光震爆）与附近士兵回血，并令范围内防御塔攻速+25%。"],
		"werewolf":["激发寒冰嗜血，5秒内攻速+35%、普攻附带15%吸血且全段爪击带范围霜雪溅射。","彻底狂化为巨型白狼人8秒：攻速+55%、宽幅冰爪顺劈伤害+30%、22%吸血与+20%移速。"],
		"gunner":["短冷却高速战术滑步并短暂无敌，滑步后下一发平A强化为2.0倍暴击重穿弹（基础穿透1→进阶穿透3）。","进入6秒超载律动：立即重置滑步冷却且冷却减半，智能锁定范围敌群连发双倍暴击穿甲弹。"]
	}
	skill_body.text=str(details[hero_id][selected_skill])+("" if unlocked else "\n[color=#e8b84b]LV."+str(2 if selected_skill==0 else 4)+" 解锁[/color]")

func passive_text(id: String,rank: int) -> String:
	var key := ArenaDefinitions.resolve_hero_id(id)
	return {
		"lord":["普攻附带大范围横扫，拦截时近战减伤20%","拦截时近战减伤24%，横扫顺劈清怪","拦截时近战减伤28%，横扫顺劈清怪"],
		"druid":["普攻溅射藤蔓震荡，双狼随行入裂隙","双狼生命提高12%，荆棘溅射协同","双狼生命提高24%，荆棘溅射协同"],
		"healer":["普攻溢疗与技能触发「圣光溢疗化伤」范围震爆","普攻易伤11%，溢疗转化高额圣光 AoE","普攻易伤12%，溢疗转化高额圣光 AoE"],
		"werewolf":["爪击自带范围溅射与15%寒霜减速","狂化吸血进一步增强，群体爪击清怪","狂化吸血与冰爪范围伤害增强"],
		"gunner":["普攻自带穿透1名敌人，智能锁定并强化暴击弹","滑步后强化射击提升至2.15倍暴击穿透","滑步后强化射击提升至2.3倍暴击穿透"]
	}[key][rank]

func select_hall(key: String) -> void:
	key = ArenaDefinitions.resolve_hero_id(key)
	if key not in ArenaDefinitions.HERO_IDS:return
	hero_id=key;selected_skill=0;message="";_refresh_hero()

func equip_hero() -> void:
	message="" if game.campaign.select_hero(hero_id) else game.campaign.last_error;_refresh_hero()

func upgrade_hero() -> void:
	var ok:=game.campaign.upgrade(hero_id);message="" if ok else game.campaign.last_error;_refresh_hero(ok)
	if ok and not reduced():
		var tween:=card.create_tween();card.modulate=Color(1.22,1.15,.92);tween.tween_property(card,"modulate",Color.WHITE,.30)
		var star: TextureRect=rank_stars[game.campaign.level(hero_id)-1];star.pivot_offset=star.size*.5;star.scale=Vector2.ONE*1.25;star.create_tween().tween_property(star,"scale",Vector2.ONE,.28)

func _on_loadout_slot(index: int) -> void:
	var equipped:=game.campaign.tower_loadout()
	if index >= 0 and index < equipped.size():
		select_tower(equipped[index])

func towers() -> void:
	if page_id=="towers" and is_instance_valid(card):_refresh_tower();return
	message="";base("hall_bg","towers");header("防御塔工坊",levels)
	var rail:=Panel.new();rail.name="TowerRail";rail.position=Vector2(354,12);rail.size=Vector2(760,92);rail.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.steel_rail(rail);hud.menu.add_child(rail)
	for index in ArenaDefinitions.TOWER_IDS.size():
		var id: String=ArenaDefinitions.TOWER_IDS[index]
		var button:=action(rail,"",Rect2(20+index*104,8,80,76),select_tower.bind(id),"Tower_"+id)
		var t_img:=hud.image(button,hud.tower_portrait(id),Rect2(4,3,72,70));t_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var eq_mark:=hud.image(button,ArenaMenuArt.v027("equipped_pip"),Rect2(56,52,20,20));eq_mark.name="Equipped";eq_mark.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		roster[id]=button;button.tooltip_text=game.tower_display_data(id).name
	# Left column: KR5-style 4-slot equipped loadout ring
	var left_col:=Control.new();left_col.name="EquippedRing";left_col.position=Vector2(66,152);left_col.size=Vector2(292,560);left_col.mouse_filter=Control.MOUSE_FILTER_IGNORE;hud.menu.add_child(left_col)
	var hdr:=Panel.new();hdr.position=Vector2(42,14);hdr.size=Vector2(208,38);hdr.mouse_filter=Control.MOUSE_FILTER_IGNORE;ArenaMenuArt.obsidian_panel(hdr,true);left_col.add_child(hdr)
	var hdr_lbl:=text(hdr,"已装备防线",Rect2(0,4,208,30),19,ArenaMenuArt.STEEL_TEXT);hdr_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var ring_decor:=_LoadoutRingDecor.new();ring_decor.position=Vector2(0,44);ring_decor.size=Vector2(292,450);left_col.add_child(ring_decor)
	for s_idx in range(4):
		var cpos: Vector2=_LoadoutRingDecor.SOCKETS[s_idx]+Vector2(0,44)
		var slot_btn:=action(left_col,"",Rect2(cpos-Vector2(42,42),Vector2(84,84)),_on_loadout_slot.bind(s_idx),"LoadoutSlot_"+str(s_idx))
		var s_img:=hud.image(slot_btn,null,Rect2(6,5,72,74));s_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		loadout_slots.append(slot_btn);loadout_icons.append(s_img)
	var cnt_pill:=Panel.new();cnt_pill.position=Vector2(98,468);cnt_pill.size=Vector2(96,32);cnt_pill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.obsidian_panel(cnt_pill,true);left_col.add_child(cnt_pill)
	loadout_count=text(cnt_pill,"4 / 4",Rect2(0,3,96,26),17,ArenaMenuArt.STEEL_MUTED);loadout_count.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	# Center showcase card with stone plinth + live animated pixel tower
	_make_card(Vector2(382,136),Vector2(384,564),Vector2(360,540))
	var clip: Control=card.find_child("CardClip",true,false)
	var ped:=hud.image(clip,ArenaMenuArt.v027("tower_pedestal_bg"),Rect2(0,0,360,540),true);ped.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var ggrad:=Gradient.new();ggrad.colors=PackedColorArray([Color(1,1,1,0.28),Color(1,1,1,0)])
	var gtex:=GradientTexture2D.new();gtex.gradient=ggrad;gtex.width=64;gtex.height=64;gtex.fill=GradientTexture2D.FILL_RADIAL;gtex.fill_from=Vector2(0.5,0.5);gtex.fill_to=Vector2(1.0,0.5)
	tower_glow=hud.image(clip,gtex,Rect2(30,90,300,300));tower_glow.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	clip.move_child(card_art,clip.get_child_count()-1)
	card_art.position=Vector2(24,104);card_art.size=Vector2(312,312);card_art.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;card_art.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	tower_ticker=_TowerShowcaseTicker.new();tower_ticker.name="TowerShowcaseTicker";clip.add_child(tower_ticker)
	var rbadge:=Panel.new();rbadge.position=Vector2(138,14);rbadge.size=Vector2(108,34);rbadge.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.obsidian_panel(rbadge,true);card.add_child(rbadge)
	rank_label=text(rbadge,"",Rect2(0,3,108,28),20,ArenaMenuArt.STEEL_GOLD);rank_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for index in range(3):
		var tb:=action(card,["I","II","III"][index],Rect2(32+index*108,472,102,42),select_tier.bind(index+1),"TowerTier_"+str(index+1))
		tb.add_theme_font_size_override("font_size",20);tier_buttons.append(tb)
	equip_button=action(hud.menu,"",Rect2(424,682,300,62),toggle_tower,"EquipTower","cyan")
	# Right column: Obsidian panel with compact single-row mini stats + Tier 3 doctrines
	detail_panel=frame(hud.menu,Rect2(792,152,720,560));detail_panel.name="TowerDetails"
	name_label=text(detail_panel,"",Rect2(32,24,650,46),34,ArenaMenuArt.STEEL_TEXT)
	role_label=text(detail_panel,"",Rect2(34,74,650,30),20,ArenaMenuArt.STEEL_CYAN)
	_make_inline_stat(detail_panel,"stat_rng",32,124)
	_make_inline_stat(detail_panel,"stat_atk",256,124)
	_make_inline_stat(detail_panel,"stat_spd",480,124)
	hud.colour_block(detail_panel,Rect2(32,190,656,1),Color("294254cc"))
	text(detail_panel,"III 阶改造",Rect2(32,202,220,30),19,ArenaMenuArt.STEEL_GOLD)
	for index in range(3):
		var button:=action(detail_panel,"",Rect2(30+index*224,242,212,84),select_route.bind(index),"TowerRoute_"+str(index))
		route_buttons.append(button);route_icons.append(hud.image(button,null,Rect2(12,18,48,48)));route_titles.append(text(button,"",Rect2(68,25,136,36),21,ArenaMenuArt.STEEL_TEXT))
	var info:=frame(detail_panel,Rect2(30,346,660,188),true);route_name=text(info,"",Rect2(24,18,612,34),24,ArenaMenuArt.STEEL_GOLD)
	route_body=body(info,Rect2(24,60,612,114),21)
	_refresh_tower()

func _refresh_tower() -> void:
	var data:=game.tower_display_data(tower_id);var equipped:=game.campaign.tower_loadout()
	for id in roster:
		ArenaMenuArt.steel_slot(roster[id],id==tower_id,ArenaMenuArt.STEEL_CYAN)
		roster[id].position.y=6 if id==tower_id else 8
		roster[id].get_node("Equipped").visible=id in equipped
	for s_idx in range(4):
		var slot_btn: Button=loadout_slots[s_idx]
		var slot_icon: TextureRect=loadout_icons[s_idx]
		if s_idx<equipped.size():
			var eq_id: String=equipped[s_idx]
			slot_icon.texture=hud.tower_portrait(eq_id);slot_icon.modulate=Color.WHITE
			slot_btn.disabled=false;slot_btn.tooltip_text=game.tower_display_data(eq_id).name
			ArenaMenuArt.steel_slot(slot_btn,eq_id==tower_id,ArenaMenuArt.STEEL_GOLD)
		else:
			slot_icon.texture=null;slot_btn.disabled=true;slot_btn.tooltip_text="空余塔位"
			ArenaMenuArt.steel_slot(slot_btn,false,ArenaMenuArt.STEEL_CYAN)
	if is_instance_valid(loadout_count):
		loadout_count.text="%d / %d"%[equipped.size(),ArenaDefinitions.LOADOUT_LIMIT]
	var doc_id: String = str(ArenaDoctrines.for_tower(tower_id)[selected_route].id) if preview_tier == 3 else ""
	if is_instance_valid(tower_glow):
		tower_glow.modulate=data.colour
	if is_instance_valid(tower_ticker):
		(tower_ticker as _TowerShowcaseTicker).setup(card_art,tower_id,preview_tier,doc_id,reduced(),true)
	else:
		card_art.texture = hud.tower_image(tower_id, preview_tier, doc_id)
		card_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var equipped_now:=tower_id in equipped
	if is_instance_valid(card_frame_overlay):
		card_frame_overlay.texture=ArenaMenuArt.v027("card_frame_gold" if equipped_now else "card_frame_steel")
	rank_label.text=["I","II","III"][preview_tier-1]+" 阶"
	name_label.text=data.name;role_label.text=ArenaCombat.label(int(data.type))+" · "+str(data.description)
	stat_icons[1].texture=ArenaMenuArt.v027("stat_shield") if tower_id=="barracks" else (ArenaMenuArt.icon(15) if int(data.type)==1 else ArenaMenuArt.v027("stat_atk"))
	_stat_value(0,float(data.reach)+(preview_tier-1)*16,320,str(roundi(float(data.reach)+(preview_tier-1)*16)))
	_stat_value(1,3 if tower_id=="barracks" else float(data.damage)*(1+.6*(preview_tier-1)),3 if tower_id=="barracks" else 130,"3 人" if tower_id=="barracks" else str(snappedf(float(data.damage)*(1+.6*(preview_tier-1)),.1)))
	_stat_value(2,1.0 if tower_id=="barracks" else (1+.14*(preview_tier-1))/float(data.interval),2,"1 /秒" if tower_id=="barracks" else str(snappedf((1+.14*(preview_tier-1))/float(data.interval),.01))+" /秒")
	for index in range(3):
		ArenaMenuArt.steel_slot(tier_buttons[index],index+1==preview_tier,ArenaMenuArt.STEEL_GOLD)
	if equipped_now:
		equip_button.text="✓ 已装备 · 卸下"
		ArenaMenuArt.steel_button(equip_button,"steel")
	elif equipped.size()==ArenaDefinitions.LOADOUT_LIMIT:
		equip_button.text="替换出战塔"
		ArenaMenuArt.steel_button(equip_button,"gold")
	else:
		equip_button.text="装备防御塔"
		ArenaMenuArt.steel_button(equip_button,"cyan")
	equip_button.disabled=game.campaign.locked or (equipped_now and equipped.size()==1)
	equip_button.tooltip_text="至少保留一类防御塔" if equipped_now and equipped.size()==1 else ""
	var symbols: Array={"archer":["farsight","rapid","pierce"],"mage":["frostheart","burn","starcore"],"cannon":["executioner","burn","warmachine"],"barracks":["ironwall","piercearrow","rapid"],"storm":["starlight","farsight","executioner"],"lens":["starcore","rapid","farsight"],"snare":["ironwall","pierce","warmachine"]}[tower_id]
	for index in range(3):route_titles[index].text=str(ArenaDoctrines.for_tower(tower_id)[index].name);route_icons[index].texture=ArenaMenuArt.perk(symbols[index])
	select_route(selected_route);feedback()

func select_tower(id: String) -> void:
	if id not in ArenaDefinitions.TOWER_IDS:return
	tower_id=id;preview_tier=1;selected_route=0;message="";_refresh_tower()

func select_tier(tier: int) -> void:
	preview_tier=clampi(tier,1,3);_refresh_tower()

func select_route(index: int) -> void:
	selected_route=clampi(index,0,2)
	var doctrine: Dictionary=ArenaDoctrines.for_tower(tower_id)[selected_route]
	if is_instance_valid(card_art) and preview_tier == 3:
		if is_instance_valid(tower_ticker):
			(tower_ticker as _TowerShowcaseTicker).setup(card_art,tower_id,3,str(doctrine.id),reduced(),true)
		else:
			card_art.texture = hud.tower_image(tower_id, 3, str(doctrine.id))
	for i in range(route_buttons.size()):
		ArenaMenuArt.steel_slot(route_buttons[i],i==selected_route,ArenaMenuArt.STEEL_GOLD)
	route_name.text=str(doctrine.name)+" · "+str(doctrine.role);route_body.text=str(doctrine.summary);route_body.scroll_to_line(0)

func toggle_tower() -> void:
	var equipped:=game.campaign.tower_loadout()
	if tower_id in equipped:equipped.erase(tower_id)
	elif equipped.size()==ArenaDefinitions.LOADOUT_LIMIT:
		var panel:=hud.modal_panel(Vector2(700,288))
		ArenaMenuArt.obsidian_panel(panel,false)
		text(panel,"选择要换下的塔",Rect2(28,22,520,44),28,ArenaMenuArt.STEEL_GOLD)
		action(panel,"×",Rect2(604,14,72,56),hud.close_modal,"CancelReplacement","steel")
		for slot in equipped.size():
			var old:=equipped[slot]
			var button:=action(panel,"",Rect2(28+slot*164,92,152,148),replace_tower.bind(slot),"Replace_"+old,"steel")
			ArenaMenuArt.steel_slot(button,false,ArenaMenuArt.STEEL_CYAN)
			var r_img:=hud.image(button,hud.tower_portrait(old),Rect2(34,8,84,84));r_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			var caption:=text(button,str(game.tower_display_data(old).name),Rect2(4,102,144,36),19,ArenaMenuArt.STEEL_TEXT);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
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

func settings() -> void:
	var panel:=hud.modal_panel(Vector2(680,576));ArenaMenuArt.obsidian_panel(panel,false)
	text(panel,"设置",Rect2(40,22,400,42),30,ArenaMenuArt.STEEL_GOLD)
	var card_box:=frame(panel,Rect2(36,78,608,368),true)
	text(card_box,"音量",Rect2(28,22,140,34),22,ArenaMenuArt.STEEL_TEXT)
	var volume:=HSlider.new();volume.name="Volume";volume.min_value=0;volume.max_value=1;volume.step=.05;volume.value=float(game.campaign.data.volume);volume.position=Vector2(180,24);volume.size=Vector2(390,40);card_box.add_child(volume)
	var motion:=CheckButton.new();motion.name="ReduceMotion";motion.text="减少动态与闪烁";motion.add_theme_font_size_override("font_size",21);motion.add_theme_color_override("font_color",ArenaMenuArt.STEEL_TEXT);motion.position=Vector2(24,78);motion.size=Vector2(540,48);motion.button_pressed=reduced();card_box.add_child(motion)
	hud.colour_block(card_box,Rect2(24,140,560,1),Color(ArenaMenuArt.STEEL_MUTED,0.28))
	text(card_box,"快捷按键设置（点击后按下任意键绑定）",Rect2(28,154,540,26),16,ArenaMenuArt.STEEL_GOLD)
	var error_label:=text(panel,"",Rect2(36,454,608,26),18,Color("ff8b80"))
	var catcher := _SettingsKeyCatcher.new()
	catcher.owner_frontend = self
	catcher.err_label = error_label
	panel.add_child(catcher)
	var bind_rows := [["dodge","短距闪避"],["portal","基地进裂隙"],["recall","随时瞬回防线"]]
	for i in range(bind_rows.size()):
		var act := str(bind_rows[i][0])
		var cap := str(bind_rows[i][1])
		var y_row := 192 + i * 50
		text(card_box, cap, Rect2(32, y_row + 6, 200, 32), 18, ArenaMenuArt.STEEL_TEXT)
		var kb_btn := action(card_box, game.campaign.keybind_label(act), Rect2(260, y_row, 180, 40), func():
			catcher.active_action = act
			catcher._refresh()
		, "Rebind_" + act, "steel")
		kb_btn.add_theme_font_size_override("font_size", 17)
		catcher.buttons[act] = kb_btn
	var reset_kb := action(card_box, "恢复默认", Rect2(458, 192, 124, 40), func():
		for act_k in ["dodge","portal","recall"]:
			game.campaign.set_keybind(act_k, ArenaCampaign.DEFAULT_KEYBINDS[act_k])
		error_label.text = ""
		catcher.active_action = ""
		catcher._refresh()
	, "ResetKeybinds", "muted")
	reset_kb.add_theme_font_size_override("font_size", 15)
	action(panel,"保存",Rect2(48,490,266,64),func():
		if game.campaign.settings(volume.value,motion.button_pressed):
			AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.0001,volume.value)));hud.close_modal()
			if is_instance_valid(tower_ticker):
				(tower_ticker as _TowerShowcaseTicker).setup(card_art,tower_id,preview_tier,str(ArenaDoctrines.for_tower(tower_id)[selected_route].id) if preview_tier==3 else "",motion.button_pressed,false)
		else:error_label.text=game.campaign.last_error,"SaveSettings","cyan")
	action(panel,"返回",Rect2(366,490,266,64),hud.close_modal,"CloseSettings","steel")

func escape() -> void:
	if hud.has_modal():hud.close_modal()
	elif is_instance_valid(stage_panel):close_stage()
	elif page_id=="title":game.quit_game()
	elif page_id=="world":settings()
	else:levels()
