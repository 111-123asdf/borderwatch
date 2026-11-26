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
var stage_config_return := ""
var settings_panel: Panel
var settings_from_pause := false
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
var route_states: Array[Label]=[]
var route_name: Label
var route_role: Label
var route_body: RichTextLabel
var equip_doctrine: Button
var enhancement_title: Label
var enhancement_list: Control
var selected_route:=0
var selected_passive := "chain_bolt"
var passive_detail: Panel
var loadout_slots: Array[Button]=[]
var loadout_icons: Array[TextureRect]=[]
var loadout_count: Label
var tower_ticker: Node
var tower_glow: TextureRect
const ROLES:={"lord":"重装 · 宽弧横扫","druid":"召唤 · 双狼协同","healer":"治疗 · 灼烧新星","werewolf":"狂战 · 爪击溅射","gunner":"游射 · 穿透连射"}

class _SettingsKeyCatcher:
	extends Node
	const RESERVED := [KEY_Q,KEY_E,KEY_F,KEY_G,KEY_H,KEY_M,KEY_C,KEY_TAB,KEY_ENTER,KEY_KP_ENTER]
	const MOVE_KEYS := [KEY_W,KEY_A,KEY_S,KEY_D,KEY_UP,KEY_DOWN,KEY_LEFT,KEY_RIGHT]
	var bindings := {}
	var buttons := {}
	var active_action := ""
	var err_label: Label
	func _input(event: InputEvent) -> void:
		if active_action.is_empty(): return
		if not (event is InputEventKey and event.pressed and not event.echo): return
		var kc := (event as InputEventKey).keycode
		get_viewport().set_input_as_handled()
		err_label.text = ""
		if kc == KEY_ESCAPE:
			active_action = ""
			_refresh()
			return
		if kc <= 0 or kc in RESERVED or kc in MOVE_KEYS or event.physical_keycode in MOVE_KEYS:
			err_label.text = "此键已用于走位或战斗指令，请换一个按键"
			return
		for action_id in bindings:
			if action_id != active_action and bindings[action_id] == kc:
				err_label.text = "此键已分配给另一项操作，请换一个按键"
				return
		bindings[active_action] = kc
		active_action = ""
		_refresh()
	func _refresh() -> void:
		for act in buttons:
			var b: Button = buttons[act]
			if not is_instance_valid(b): continue
			if active_action == act:
				b.text = "按下新按键…"
			else:
				b.text = ArenaCampaign.format_keybind(int(bindings[act]))

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
	rank_stars.clear();tier_buttons.clear();route_buttons.clear();route_titles.clear();route_icons.clear();route_states.clear()
	loadout_slots.clear();loadout_icons.clear();loadout_count=null;tower_ticker=null;tower_glow=null;card_frame_overlay=null
	hud.reset_menu()
	var tex: Texture2D=ArenaMenuArt.v027(background)
	if tex==null: tex=ArenaMenuArt.texture(background)
	var image: TextureRect=hud.image(hud.menu,tex,Rect2(0,0,1600,900),true);image.name="Scenery"
	hud.fade_in(image,0.82)
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
	for entry_lock in ArenaLevelCatalog.FUTURE_LOCKS:
		var lpos: Vector2=entry_lock.pos
		var lock:=hud.image(hud.menu,ArenaMenuArt.v027("stage_lock_seal"),Rect2(lpos-Vector2(21,21),Vector2(42,42)))
		lock.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		lock.modulate=Color(1.0,1.0,1.0,0.82)
		lock.tooltip_text=str(entry_lock.tip)
		lock.mouse_filter=Control.MOUSE_FILTER_PASS
	dock()
	_focus_stage_node()

func back_to_world() -> void:
	var resume_stage := stage_config_return
	stage_config_return = ""
	levels()
	if not resume_stage.is_empty():prepare(resume_stage)

func _configure_stage(edit_towers: bool) -> void:
	stage_config_return = stage
	if edit_towers:towers()
	else:
		hero_id = game.campaign.selected_hero()
		hall()

func _focus_stage_node() -> void:
	var node := hud.menu.get_node_or_null("Level_" + stage) as Button
	if node != null:node.grab_focus()

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
	var nav_items: Array=[
		[ArenaMenuArt.v027("dock_hero"),hall,"HeroHall","英雄"],
		[ArenaMenuArt.v027("dock_tower"),towers,"TowerHall","防御塔"],
		[ArenaMenuArt.v027("dock_codex"),passives,"PassiveHall","被动"]
	]
	var count: int=nav_items.size()
	var start_x: float=1572.0 - float(count) * 140.0
	for i in range(count):
		var item: Array=nav_items[i]
		var button:=action(hud.menu,"",Rect2(start_x+float(i)*140.0,734,124,142),item[1],item[2],"steel",true)
		var med:=hud.image(button,item[0],Rect2(8,2,108,108));med.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		var plate:=Panel.new();plate.position=Vector2(14,104);plate.size=Vector2(96,30);plate.mouse_filter=Control.MOUSE_FILTER_IGNORE
		ArenaMenuArt.obsidian_panel(plate,true);button.add_child(plate)
		var caption:=text(plate,str(item[3]),Rect2(0,1,96,28),18,ArenaMenuArt.STEEL_TEXT);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

func prepare(key: String) -> void:
	if key not in ArenaLevelCatalog.IDS:return
	close_stage(false)
	stage=key
	stage_panel=frame(hud.menu,Rect2(836,148,668,592));stage_panel.name="StagePanel"
	hud.fade_in(stage_panel)
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
	var tagline := str(definition.get("tagline","")).trim_prefix("5轮双域 · ")
	var feature := text(stage_panel,tagline,Rect2(184,267,320,30),17,ArenaMenuArt.STEEL_MUTED)
	feature.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var rew_pill:=Panel.new();rew_pill.position=Vector2(516,264);rew_pill.size=Vector2(124,36);rew_pill.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.obsidian_panel(rew_pill,true);stage_panel.add_child(rew_pill)
	hud.image(rew_pill,ArenaMenuArt.utility("diamond"),Rect2(12,4,28,28))
	text(rew_pill,"+"+str(game.campaign.victory_reward(stage)),Rect2(48,4,66,28),21,ArenaMenuArt.STEEL_GOLD)
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
	var story := str(definition.story).replace("[T]","[%s]" % game.campaign.keybind_label("portal")).replace("[R]","[%s]" % game.campaign.keybind_label("recall"))
	var brief:=text(briefing,story,Rect2(318,14,282,120),18,ArenaMenuArt.STEEL_TEXT)
	brief.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	brief.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	var ready:=game.campaign.can_deploy(stage,game.defense_rules)
	var hero_config:=action(stage_panel,"英雄",Rect2(24,486,144,76),_configure_stage.bind(false),"StageHero")
	hero_config.tooltip_text="当前出战 · " + str(ArenaDefinitions.HEROES[game.campaign.selected_hero()].name)
	var tower_config:=action(stage_panel,"防御塔",Rect2(500,486,144,76),_configure_stage.bind(true),"StageTowers" if ready else "ConfigureTowers","steel" if ready else "gold")
	tower_config.tooltip_text="当前装备 %d 类防御塔" % game.campaign.tower_loadout().size()
	var deploy:=action(stage_panel,"战斗！" if ready else "请先配置防御塔",Rect2(184,486,300,76),deploy_stage,"Deploy","cyan");deploy.disabled=not ready
	deploy.add_theme_font_size_override("font_size",28)
	if ready:deploy.grab_focus()
	else:tower_config.grab_focus()

func close_stage(restore_focus := true) -> void:
	if is_instance_valid(stage_panel):hud.menu.remove_child(stage_panel);stage_panel.queue_free()
	stage_panel=null
	if restore_focus:_focus_stage_node()

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
	message="";base("hall_bg","heroes");header("英雄大厅",back_to_world)
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
	var unlock_line := "LV.%d / LV.%d 解锁技能 · 详情随养成更新" % ArenaDefinitions.SKILL_UNLOCK_LEVELS
	text(detail_panel,unlock_line,Rect2(34,488,400,26),16,Color("6e889c"))
	upgrade_button=action(detail_panel,"",Rect2(410,468,292,66),upgrade_hero,"UpgradeHero","gold")
	_refresh_hero()
	roster[hero_id].grab_focus()

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
	upgrade_button.tooltip_text=game.campaign.last_error if game.campaign.locked else ("还需 %d 钻石" % (price-game.campaign.gems()) if rank<5 and game.campaign.gems()<price else "")
	wallet_value.text=str(game.campaign.gems());select_skill(selected_skill);feedback()

func select_skill(slot: int) -> void:
	selected_skill=clampi(slot,0,2)
	for index in range(skill_buttons.size()):
		ArenaMenuArt.steel_slot(skill_buttons[index],index==selected_skill,ArenaMenuArt.STEEL_GOLD)
	var data: Dictionary=ArenaDefinitions.HEROES[hero_id]
	var talent_rank := int(game.campaign.bonuses(hero_id).passive)
	if selected_skill==2:
		skill_title.text="职业天赋";skill_body.text=ArenaDefinitions.hero_talent_text(hero_id,talent_rank);return
	var unlocked:=game.campaign.skill_unlocked(hero_id,selected_skill)
	skill_title.text=str(data.small if selected_skill==0 else data.ultimate)+"  ·  "+str(data.small_cd if selected_skill==0 else data.ultimate_cd)+"秒"
	skill_body.text=ArenaDefinitions.skill_text(hero_id,selected_skill,talent_rank)+("" if unlocked else "\n[color=#e8b84b]LV."+str(ArenaDefinitions.SKILL_UNLOCK_LEVELS[selected_skill])+" 解锁[/color]")

func select_hall(key: String) -> void:
	key = ArenaDefinitions.resolve_hero_id(key)
	if key not in ArenaDefinitions.HERO_IDS:return
	hero_id=key;selected_skill=0;message="";_refresh_hero()

func equip_hero() -> void:
	var ok := game.campaign.select_hero(hero_id)
	message="已设 %s 为出战英雄" % ArenaDefinitions.HEROES[hero_id].name if ok else game.campaign.last_error
	_refresh_hero()
	if ok:roster[hero_id].grab_focus()

func upgrade_hero() -> void:
	var ok:=game.campaign.upgrade(hero_id)
	message="%s 升至 Lv.%d" % [ArenaDefinitions.HEROES[hero_id].name,game.campaign.level(hero_id)] if ok else game.campaign.last_error
	_refresh_hero(ok)
	if upgrade_button.disabled:roster[hero_id].grab_focus()
	if ok and not reduced():
		var tween:=card.create_tween();card.modulate=Color(1.22,1.15,.92);tween.tween_property(card,"modulate",Color.WHITE,.30)
		var star: TextureRect=rank_stars[game.campaign.level(hero_id)-1];star.pivot_offset=star.size*.5;star.scale=Vector2.ONE*1.25;star.create_tween().tween_property(star,"scale",Vector2.ONE,.28)

func _on_loadout_slot(index: int) -> void:
	var equipped:=game.campaign.tower_loadout()
	if index >= 0 and index < equipped.size():
		select_tower(equipped[index])

func passives() -> void:
	base("hall_bg","passives")
	header("被动图鉴",back_to_world)
	var library := frame(hud.menu,Rect2(62,140,802,626))
	text(library,"局内被动  ·  %d 种" % ArenaPassiveEngine.ORDER.size(),Rect2(20,14,360,32),21,ArenaMenuArt.STEEL_GOLD)
	for index in range(ArenaPassiveEngine.ORDER.size()):
		var id: String = ArenaPassiveEngine.ORDER[index]
		var spec: Dictionary = ArenaPassiveEngine.PASSIVES[id]
		var tile := action(library,"",Rect2(20+int(index%5)*154,56+floori(float(index)/5.0)*91,146,82),select_passive.bind(id),"Passive_"+id)
		hud.image(tile,ArenaMenuArt.passive_medal(id),Rect2(9,17,40,40)).texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
		text(tile,str(spec.name),Rect2(55,13,84,28),18)
		text(tile,str(spec.category),Rect2(55,43,84,24),14,ArenaMenuArt.STEEL_MUTED)
		roster[id]=tile
	passive_detail = frame(hud.menu,Rect2(890,140,648,626))
	passive_detail.name = "PassiveDetails"
	select_passive(selected_passive)
	roster[selected_passive].grab_focus()

func select_passive(id: String) -> void:
	selected_passive = id
	var spec: Dictionary = ArenaPassiveEngine.PASSIVES[id]
	for key in roster:
		ArenaMenuArt.steel_slot(roster[key],key==id,ArenaMenuArt.STEEL_GOLD)
	hud.clear_children(passive_detail)
	hud.image(passive_detail,ArenaMenuArt.passive_medal(id),Rect2(30,28,64,64)).texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	text(passive_detail,str(spec.name),Rect2(112,22,466,46),34,ArenaMenuArt.STEEL_GOLD).name="PassiveTitle"
	text(passive_detail,str(spec.category),Rect2(114,69,466,27),17,ArenaMenuArt.STEEL_CYAN)
	var overview := body(passive_detail,Rect2(32,111,582,63),19)
	overview.text = str(spec.tagline)
	for rank in range(ArenaPassiveEngine.MAX_RANK):
		var row := frame(passive_detail,Rect2(28,184+rank*128,592,113),true)
		row.name="PassiveRank_"+str(rank+1)
		var rank_title := "第 %d 阶" % (rank+1)
		if rank == ArenaPassiveEngine.MAX_RANK-1:
			rank_title += "  ·  " + str(spec.evo_name)
		text(row,rank_title,Rect2(18,10,552,29),21,ArenaMenuArt.STEEL_GOLD)
		var detail := text(row,str(spec.details[rank]),Rect2(18,43,552,62),19)
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func towers() -> void:
	if page_id=="towers" and is_instance_valid(card):_refresh_tower();return
	message="";base("hall_bg","towers");header("防御塔工坊",back_to_world)
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
	detail_panel=frame(hud.menu,Rect2(792,128,740,642));detail_panel.name="TowerDetails"
	name_label=text(detail_panel,"",Rect2(32,18,676,46),34,ArenaMenuArt.STEEL_TEXT)
	role_label=text(detail_panel,"",Rect2(34,65,676,30),20,ArenaMenuArt.STEEL_CYAN)
	_make_inline_stat(detail_panel,"stat_rng",32,104)
	_make_inline_stat(detail_panel,"stat_atk",263,104)
	_make_inline_stat(detail_panel,"stat_spd",494,104)
	hud.colour_block(detail_panel,Rect2(28,166,684,1),Color("294254cc"))
	text(detail_panel,"三级专精",Rect2(30,177,230,30),21,ArenaMenuArt.STEEL_GOLD)
	for index in range(3):
		var button:=action(detail_panel,"",Rect2(28+index*231,215,222,65),select_route.bind(index),"TowerRoute_"+str(index))
		route_buttons.append(button)
		var art := hud.image(button,null,Rect2(9,3,58,58))
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		route_icons.append(art)
		route_titles.append(text(button,"",Rect2(69,12,142,25),18))
		route_states.append(text(button,"",Rect2(69,37,142,20),13,ArenaMenuArt.STEEL_CYAN))
	var info:=frame(detail_panel,Rect2(28,294,684,128),true)
	info.name = "TowerDoctrineDetail"
	route_name=text(info,"",Rect2(17,12,266,34),25,ArenaMenuArt.STEEL_GOLD)
	route_role=text(info,"",Rect2(183,17,275,25),16,ArenaMenuArt.STEEL_CYAN)
	route_body=body(info,Rect2(17,54,650,63),17)
	route_body.scroll_active = false
	equip_doctrine=action(info,"",Rect2(474,10,192,38),_set_tower_doctrine,"EquipDoctrine","cyan")
	equip_doctrine.add_theme_font_size_override("font_size",16)
	var growth := frame(detail_panel,Rect2(28,436,684,180),true)
	growth.name = "TowerEnhancementPreview"
	enhancement_title=text(growth,"",Rect2(16,9,430,32),21,ArenaMenuArt.STEEL_GOLD)
	text(growth,"三级后依次自动扣金币",Rect2(451,14,215,24),14,ArenaMenuArt.STEEL_MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	enhancement_list=Control.new()
	enhancement_list.position=Vector2(14,48)
	enhancement_list.mouse_filter=Control.MOUSE_FILTER_IGNORE
	growth.add_child(enhancement_list)
	select_tower(tower_id)
	roster[tower_id].grab_focus()

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
	var doctrines := ArenaDoctrines.for_tower(tower_id)
	var doctrine: Dictionary = doctrines[selected_route]
	var doc_id: String = doctrine.id if preview_tier == 3 else ""
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
	var reach := ArenaTower.field_range(data,preview_tier)*ArenaDoctrines.value(doc_id,"range_mult",1.0)
	var damage := ArenaTower.field_power(data,preview_tier)*ArenaDoctrines.value(doc_id,"damage_mult",1.0)
	var speed := 1.0/(ArenaTower.field_cycle(data,preview_tier)*ArenaDoctrines.value(doc_id,"interval_mult",1.0))
	_stat_value(0,reach,360,str(roundi(reach)))
	var troop_count := int(ArenaDoctrines.value(doc_id,"soldier_count",3.0))
	_stat_value(1,troop_count if tower_id=="barracks" else damage,3 if tower_id=="barracks" else 28,"%d 人" % troop_count if tower_id=="barracks" else str(snappedf(damage,.1)))
	_stat_value(2,1.0 if tower_id=="barracks" else speed,2,"1 /秒" if tower_id=="barracks" else str(snappedf(speed,.01))+" /秒")
	stat_values[0].tooltip_text = "集结范围" if tower_id=="barracks" else "基础索敌射程"
	stat_values[1].tooltip_text = "基础驻军人数" if tower_id=="barracks" else "单次基础伤害，未计抗性、溅射衰减和强化"
	stat_values[2].tooltip_text = "单名士兵的基础攻速" if tower_id=="barracks" else "基础攻速，未计战场增益和强化"
	for stat in stat_values:
		stat.mouse_filter = Control.MOUSE_FILTER_PASS
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
	_refresh_tower_doctrine(doctrines, doctrine)
	feedback()

func select_tower(id: String) -> void:
	if id not in ArenaDefinitions.TOWER_IDS:return
	tower_id=id;preview_tier=1;selected_route=0;message=""
	var doctrines := ArenaDoctrines.for_tower(id)
	for index in range(doctrines.size()):
		if doctrines[index].id == game.campaign.tower_doctrine(id):
			selected_route = index
			break
	_refresh_tower()

func select_tier(tier: int) -> void:
	preview_tier=clampi(tier,1,3);_refresh_tower()

func select_route(index: int) -> void:
	selected_route=clampi(index,0,route_buttons.size()-1)
	preview_tier=3
	_refresh_tower()

func _refresh_tower_doctrine(doctrines: Array, doctrine: Dictionary) -> void:
	var active := game.campaign.tower_doctrine(tower_id)
	for index in range(doctrines.size()):
		var entry: Dictionary = doctrines[index]
		ArenaMenuArt.steel_slot(route_buttons[index],index==selected_route,ArenaMenuArt.STEEL_GOLD)
		route_titles[index].text = str(entry.name)
		route_icons[index].texture = hud.tower_image(tower_id,3,str(entry.id))
		route_states[index].text = "已设为自动" if entry.id == active else str(entry.role)
	route_name.text = str(doctrine.name)
	route_role.text = str(doctrine.role)
	route_body.text = ArenaDoctrines.field_summary(str(doctrine.id))
	equip_doctrine.text = "三级自动生效" if doctrine.id == active else "设为自动专精"
	equip_doctrine.disabled = doctrine.id == active or game.campaign.locked
	enhancement_title.text = "「%s」的专精强化" % str(doctrine.name)
	hud.clear_children(enhancement_list)
	var stages := ArenaDoctrines.enhancements(str(doctrine.id))
	var width := (656.0-10.0*(stages.size()-1))/stages.size()
	for index in range(stages.size()):
		var price := "%d 金币" % ArenaDoctrines.ENHANCEMENT_PRICES[index]
		hud.enhancement_card(enhancement_list,Rect2(index*(width+10),0,width,116),stages[index],price,ArenaMenuArt.STEEL_GOLD,index)

func _set_tower_doctrine() -> void:
	var doctrine: Dictionary = ArenaDoctrines.for_tower(tower_id)[selected_route]
	message = "" if game.campaign.select_tower_doctrine(tower_id,str(doctrine.id)) else game.campaign.last_error
	_refresh_tower()

func toggle_tower() -> void:
	var equipped:=game.campaign.tower_loadout()
	if tower_id in equipped:equipped.erase(tower_id)
	elif equipped.size()==ArenaDefinitions.LOADOUT_LIMIT:
		var panel:=hud.modal_panel(Vector2(700,288))
		ArenaMenuArt.obsidian_panel(panel,false)
		text(panel,"用%s替换哪座塔？" % game.tower_display_data(tower_id).name,Rect2(28,22,520,44),28,ArenaMenuArt.STEEL_GOLD)
		var cancel:=action(panel,"×",Rect2(604,14,72,56),hud.close_modal,"CancelReplacement","steel")
		for slot in equipped.size():
			var old:=equipped[slot]
			var button:=action(panel,"",Rect2(28+slot*164,92,152,148),replace_tower.bind(slot),"Replace_"+old,"steel")
			ArenaMenuArt.steel_slot(button,false,ArenaMenuArt.STEEL_CYAN)
			var r_img:=hud.image(button,hud.tower_portrait(old),Rect2(34,8,84,84));r_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			var caption:=text(button,str(game.tower_display_data(old).name),Rect2(4,102,144,36),19,ArenaMenuArt.STEEL_TEXT);caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		hud.focus_dialog(cancel)
		return
	else:equipped.append(tower_id)
	message="" if game.campaign.equip_towers(equipped) else (game.campaign.last_error if game.campaign.last_error!="" else "至少保留一类防御塔");_refresh_tower()

func replace_tower(slot: int) -> void:
	var equipped:=game.campaign.tower_loadout()
	if slot>=0 and slot<equipped.size() and tower_id not in equipped:
		equipped[slot]=tower_id
		message="已将%s编入出战阵容" % game.tower_display_data(tower_id).name if game.campaign.equip_towers(equipped) else game.campaign.last_error
	hud.close_modal()
	_refresh_tower()

func settings(from_pause := false) -> void:
	settings_from_pause = from_pause
	var panel:=hud.modal_panel(Vector2(680,576));ArenaMenuArt.obsidian_panel(panel,false)
	settings_panel = panel
	text(panel,"设置",Rect2(40,22,400,42),30,ArenaMenuArt.STEEL_GOLD)
	var card_box:=frame(panel,Rect2(36,78,608,368),true)
	text(card_box,"音量",Rect2(28,22,140,34),22,ArenaMenuArt.STEEL_TEXT)
	var volume:=HSlider.new();volume.name="Volume";volume.min_value=0;volume.max_value=1;volume.step=.05;volume.value=float(game.campaign.data.volume);volume.position=Vector2(180,24);volume.size=Vector2(390,40);card_box.add_child(volume)
	var motion:=CheckButton.new();motion.name="ReduceMotion";motion.text="减少动态与闪烁";motion.add_theme_font_size_override("font_size",21);motion.add_theme_color_override("font_color",ArenaMenuArt.STEEL_TEXT);motion.position=Vector2(24,78);motion.size=Vector2(540,48);motion.button_pressed=reduced();card_box.add_child(motion)
	hud.colour_block(card_box,Rect2(24,140,560,1),Color(ArenaMenuArt.STEEL_MUTED,0.28))
	text(card_box,"快捷按键设置（点击后按下任意键绑定）",Rect2(28,154,540,26),16,ArenaMenuArt.STEEL_GOLD)
	var error_label:=text(panel,"",Rect2(36,454,608,26),18,Color("ff8b80"))
	var catcher := _SettingsKeyCatcher.new()
	for act in ArenaCampaign.DEFAULT_KEYBINDS:
		catcher.bindings[act] = game.campaign.keybind(act)
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
			error_label.text = ""
			catcher._refresh()
		, "Rebind_" + act, "steel")
		kb_btn.add_theme_font_size_override("font_size", 17)
		catcher.buttons[act] = kb_btn
	var reset_kb := action(card_box, "恢复默认", Rect2(458, 192, 124, 40), func():
		catcher.bindings = ArenaCampaign.DEFAULT_KEYBINDS.duplicate()
		error_label.text = ""
		catcher.active_action = ""
		catcher._refresh()
	, "ResetKeybinds", "muted")
	reset_kb.add_theme_font_size_override("font_size", 15)
	action(panel,"保存",Rect2(48,490,266,64),func():
		if game.campaign.settings(volume.value,motion.button_pressed,catcher.bindings):
			AudioServer.set_bus_volume_db(0,linear_to_db(maxf(.0001,volume.value)))
			hud.refresh_motion()
			if is_instance_valid(tower_ticker):
				(tower_ticker as _TowerShowcaseTicker).setup(card_art,tower_id,preview_tier,str(ArenaDoctrines.for_tower(tower_id)[selected_route].id) if preview_tier==3 else "",motion.button_pressed,false)
			close_settings()
		else:error_label.text=game.campaign.last_error,"SaveSettings","cyan")
	action(panel,"返回",Rect2(366,490,266,64),close_settings,"CloseSettings","steel")
	hud.focus_dialog(volume)

func settings_open() -> bool:
	return is_instance_valid(settings_panel) and settings_panel.get_parent() == hud.modal

func close_settings() -> void:
	var return_to_pause := settings_from_pause
	settings_panel = null
	settings_from_pause = false
	hud.close_modal()
	if return_to_pause:hud.show_pause()

func escape() -> void:
	if settings_open():close_settings()
	elif hud.has_modal():hud.close_modal()
	elif is_instance_valid(stage_panel):close_stage()
	elif page_id=="world":entry()
	elif page_id in ["heroes","towers","passives"]:back_to_world()
