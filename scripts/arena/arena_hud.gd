class_name ArenaHUD
extends CanvasLayer
var game: ArenaGame
var root: Control
var menu: Control
var modal: Control
var context: Panel
var preview_tower := ""
var wave_button: Button
var orders_button: Button
var orders_panel: Panel
var order_buttons := {}
var orders_status: Label
var order_hint: Label
var chest_button: Button
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
var objective: Panel
var objective_step: Label
var objective_title: Label
var objective_body: Label
var phase_label: Label
var xp_label: Label
var build_label: Label
var preview_stats: Label
var last_objective:=""
var tutorial_finished:=false
var skills: Array[Button]=[]
var skill_glyphs: Array[ArenaGlyph]=[]
var dodge_button: Button
var dodge_glyph: ArenaGlyph
var hero_debuff_box: HBoxContainer
var _last_debuff_sig := ""
var boss_bar_panel: Panel
var boss_portrait: TextureRect
var boss_title: Label
var boss_hp_text: Label
var boss_meter: ArenaMeter
var boss_ticks: Array[ColorRect]=[]
var _last_boss_kind := ""
var resonance_button: Button
var resonance_meter: ArenaMeter
var resonance_label: Label
var bridge_button: Button
var bridge_meter: ArenaMeter
var bridge_label: Label
var breach_notice: Button
var battle_nodes: Array=[]
var update_clock:=0.0
var selected_hero: String="lord"
var frontend: ArenaFrontEnd
const CREAM:=Color("f2e4c5")
const GOLD:=Color("f3cc65")
const MUTED:=Color("b6c0cb")
const INK:=Color("121e2c")
const COPPER:=Color("b88943")
const PANEL:=Color("1d2a38f2")
var codex: ArenaPerkCodex
var codex_was_paused:=false
const AXIS_NAME:={"blade":"锋刃","star":"星火","bulwark":"壁垒","command":"号令","evo":"进化","knight":"领主","ranger":"枪手","mage":"爱神","bridge":"桥接"}
func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	root=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root)
	context=Panel.new();context.hide();context.mouse_filter=Control.MOUSE_FILTER_STOP;root.add_child(context);panel_style(context)
	frontend=ArenaFrontEnd.new(self)
func panel_style(node: Control,light:=false) -> void:
	ArenaMenuArt.panel(node,light)
func pod_style(node: Control) -> void:
	node.add_theme_stylebox_override("panel",ArenaMenuArt.small_style(false))
func sub_card(parent: Node,rect: Rect2,paper:=true) -> Panel:
	var node:=Panel.new();node.position=rect.position;node.size=rect.size;node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.panel(node,paper);parent.add_child(node);return node
func keycap(parent: Node,message: String,rect: Rect2,tint:=GOLD) -> Panel:
	var node:=Panel.new();node.position=rect.position;node.size=rect.size;node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel",ArenaMenuArt.small_style(false,tint));parent.add_child(node)
	var txt:=label(node,message,Rect2(Vector2(0,-1),rect.size),12 if rect.size.y<=24 else 14,tint)
	txt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;txt.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	return node
func label(parent: Node,message: String,rect: Rect2,size:=18,colour:=CREAM) -> Label:
	var node:=Label.new();node.position=rect.position;node.size=rect.size;node.text=message;node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size",size);node.add_theme_color_override("font_color",colour);parent.add_child(node);return node
func button(parent: Node,message: String,rect: Rect2,callback: Callable,primary:=false) -> Button:
	var node:=Button.new();node.position=rect.position;node.size=rect.size;node.text=message
	ArenaMenuArt.button(node,primary);node.focus_mode=Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size",18 if rect.size.y<56 else 20)
	var reduced:=bool(game.campaign.data.get("reduced_motion",false)) if game!=null and game.campaign!=null else false
	ArenaMenuArt.interact(node,reduced)
	node.pressed.connect(func():game.suppress_primary=Input.is_action_pressed("shoot");callback.call());parent.add_child(node);return node
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
	var bg:=StyleBoxFlat.new();bg.bg_color=Color("14202b");bg.border_color=Color("0b131c");bg.set_border_width_all(1);bg.set_corner_radius_all(4)
	var fg:=StyleBoxFlat.new();fg.bg_color=colour;fg.set_corner_radius_all(4)
	node.add_theme_stylebox_override("background",bg);node.add_theme_stylebox_override("fill",fg);parent.add_child(node);return node
func hero_portrait(key: String) -> Texture2D:
	return ArenaHeroArt.portrait(key)
func hero_badge_image(key: String) -> Texture2D:
	return ArenaHeroArt.small_portrait(key)
func tower_portrait(kind: String) -> Texture2D:
	return ArenaBattleArt.tower_portrait(kind)
func tower_image(kind: String,tier:=1, doctrine_id:="") -> Texture2D:
	return ArenaBattleArt.tower_texture(kind,tier,doctrine_id)
func reset_menu() -> void:
	if is_instance_valid(menu):root.remove_child(menu);menu.queue_free()
	menu=Control.new();menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.mouse_filter=Control.MOUSE_FILTER_STOP;root.add_child(menu)
func backdrop() -> void:
	var path: String=ArenaBattleArt.map_path("forest")
	if ResourceLoader.exists(path):image(menu,load(path),Rect2(Vector2.ZERO,Vector2(1600,900)),true).modulate=Color(0.56,0.59,0.5)
	else:
		var bg:=ColorRect.new();bg.color=Color("607447");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);menu.add_child(bg)
func show_codex() -> void:
	if game.condition_lab or is_instance_valid(codex) or game.choice_open:
		return
	codex_was_paused=get_tree().paused
	get_tree().paused=true
	codex = ArenaPerkCodex.new()
	root.add_child(codex)
	codex.closed.connect(_on_codex_closed)
func _on_codex_closed() -> void:
	codex = null
	get_tree().paused=codex_was_paused
	game.suppress_primary=Input.is_action_pressed("shoot")
	if not codex_was_paused:game.pump_modals()
func show_entry() -> void:frontend.entry()
func show_heroes() -> void:frontend.hall()
func show_levels(_key: String="") -> void:frontend.levels()
func show_battle() -> void:
	if is_instance_valid(menu):menu.queue_free()
	for node in battle_nodes:
		if is_instance_valid(node):node.queue_free()
	battle_nodes.clear();skills.clear();skill_glyphs.clear()
	var hero_pod:=Panel.new();hero_pod.name="HeroPod";hero_pod.position=Vector2(12,10);hero_pod.size=Vector2(294,58);hero_pod.mouse_filter=Control.MOUSE_FILTER_IGNORE;pod_style(hero_pod);root.add_child(hero_pod);battle_nodes.append(hero_pod)
	hero_badge=image(hero_pod,hero_badge_image(game.hero.class_id),Rect2(4,3,48,50))
	hero_badge.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	revival=label(hero_pod,"",Rect2(8,13,40,30),20,GOLD)
	hero_health=meter(hero_pod,Rect2(58,12,124,12),Color("d87d73"))
	hero_level=label(hero_pod,"1",Rect2(58,41,28,14),10,MUTED)
	if not game.defense_rules:
		experience=meter(hero_pod,Rect2(58,34,124,5),Color("c6d899"))
		xp_label=label(hero_pod,"",Rect2(88,41,92,14),10,MUTED);xp_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	icon(hero_pod,"coin",Rect2(193,12,23,23));coins=label(hero_pod,str(game.gold),Rect2(219,11,66,27),19,GOLD)
	var core_pod:=Panel.new();core_pod.name="CorePod";core_pod.position=Vector2(1378,10);core_pod.size=Vector2(210,48);core_pod.mouse_filter=Control.MOUSE_FILTER_IGNORE;pod_style(core_pod);root.add_child(core_pod);battle_nodes.append(core_pod)
	icon(core_pod,"core",Rect2(8,9,23,28),Color("a0d9cd"));core_health=meter(core_pod,Rect2(40,19,110,10),Color("79c69d"))
	var pause_button:=button(core_pod,"Ⅱ",Rect2(158,2,48,44),show_pause);pause_button.name="Pause";pause_button.tooltip_text="暂停 · Esc"
	if game.world_size().x>1600:
		var overview:=button(root,"",Rect2(1324,12,44,44),game.camera.toggle_overview);overview.name="Overview";overview.tooltip_text="M 全图 / 近景；中键拖动或边缘移动镜头；C 定位英雄";icon(overview,"overview",Rect2(8,8,28,28));battle_nodes.append(overview)
		var focus:=button(root,"",Rect2(314,12,44,44),func():game.camera.focus(game.hero.position));focus.name="FocusHero";focus.tooltip_text="定位英雄 · C";icon(focus,"target",Rect2(8,8,28,28));battle_nodes.append(focus)
		breach_notice=button(root,"",Rect2(1324,64,44,44),func():game.camera.focus(game.siege.point()));breach_notice.name="BreachAlert";breach_notice.tooltip_text="东北破障：击败蓄力中的破障者可延缓至下一波。点击定位。";icon(breach_notice,"wave",Rect2(8,8,28,28),GOLD);breach_notice.hide();battle_nodes.append(breach_notice)
	wave_label=label(root,"1 / " + str(game.total_waves()),Rect2(1515,64,66,20),13,CREAM);wave_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;battle_nodes.append(wave_label)
	phase_label=label(root,"",Rect2(0,0,1,1),10);phase_label.hide();battle_nodes.append(phase_label)
	wave_button=button(root,"",Rect2(0,0,48,48),game.request_wave);wave_button.name="CallWave";wave_button.tooltip_text="预览下一波；再点提前开始";battle_nodes.append(wave_button)
	wave_glyph=icon(wave_button,"wave",Rect2(7,7,34,34))
	hero_debuff_box=HBoxContainer.new();hero_debuff_box.name="HeroDebuffs";hero_debuff_box.position=Vector2(12,72);hero_debuff_box.size=Vector2(310,22);hero_debuff_box.mouse_filter=Control.MOUSE_FILTER_IGNORE;hero_debuff_box.add_theme_constant_override("separation",6);root.add_child(hero_debuff_box);battle_nodes.append(hero_debuff_box)
	_last_debuff_sig=""
	boss_bar_panel=Panel.new();boss_bar_panel.name="BossBar";boss_bar_panel.position=Vector2(530,10);boss_bar_panel.size=Vector2(540,56);boss_bar_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE;pod_style(boss_bar_panel);boss_bar_panel.hide();root.add_child(boss_bar_panel);battle_nodes.append(boss_bar_panel)
	boss_portrait=image(boss_bar_panel,null,Rect2(6,5,46,46));boss_portrait.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	boss_title=label(boss_bar_panel,"",Rect2(60,4,336,22),15,GOLD)
	boss_hp_text=label(boss_bar_panel,"",Rect2(396,5,134,20),13,CREAM);boss_hp_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	boss_meter=meter(boss_bar_panel,Rect2(60,30,470,15),Color("df5252"))
	boss_ticks.clear();_last_boss_kind=""
	for frac in [0.33, 0.66]:
		var tick:=colour_block(boss_bar_panel,Rect2(60.0+470.0*frac,30.0,2.0,15.0),Color(0.98,0.92,0.75,0.65))
		boss_ticks.append(tick)
	var skill_dock:=Control.new();skill_dock.position=Vector2(12,818);skill_dock.size=Vector2(276,70);skill_dock.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(skill_dock);battle_nodes.append(skill_dock)
	for slot in range(2):
		var b:=button(skill_dock,"",Rect2(slot*64,4,58,62),game.request_skill.bind(slot));b.name="Skill_"+str(slot);skills.append(b)
		var kind: String={"lord":["physical","flag"],"druid":["flag","frost"],"healer":["magic","heart"],"werewolf":["physical","frost"],"gunner":["move","physical"]}.get(game.hero.class_id,["physical","flag"])[slot]
		var glyph:=icon(b,kind,Rect2(4,3,48,48),ArenaCombat.colour(game.hero.data.type));skill_glyphs.append(glyph)
		image(glyph,ArenaMenuArt.skill(game.hero.class_id,slot),Rect2(4,3,42,42))
		keycap(b,"Q" if slot==0 else "E",Rect2(35,40,20,18));b.tooltip_text=ArenaDefinitions.skill_text(game.hero.class_id,slot)
	dodge_button=button(skill_dock,"",Rect2(128,4,58,62),func():if is_instance_valid(game.hero):game.hero.try_dodge())
	dodge_button.name="DodgeSkill";dodge_button.tooltip_text="短距小闪避 · Space\n快速向移动方向小步闪避，获得短暂无敌帧并免疫负面效果（冷却 5 秒）"
	dodge_glyph=icon(dodge_button,"move",Rect2(8,5,42,42),Color("9ae8ff"))
	var dodge_cap:=keycap(dodge_button,"Space",Rect2(14,41,42,17),Color("9ae8ff"))
	for c in dodge_cap.get_children():
		if c is Label:c.add_theme_font_size_override("font_size",10)
	resonance_button=null;resonance_meter=null;resonance_label=null
	if game.keystone_mode:
		resonance_button=button(skill_dock,"",Rect2(192,4,58,62),game.request_skill.bind(2));resonance_button.name="Resonance";resonance_button.tooltip_text="共鸣斩 · R：充满后选点释放，破盾并引动附近塔齐射"
		icon(resonance_button,"meteor",Rect2(9,3,40,40),Color("9ccdd8"));resonance_meter=meter(resonance_button,Rect2(6,54,46,3),Color("9ccdd8"));resonance_label=label(resonance_button,"",Rect2(0,0,1,1),10);resonance_label.hide();keycap(resonance_button,"R",Rect2(35,40,20,18))
	bridge_button=null;bridge_meter=null;bridge_label=null
	if not game.bridge_gate_config.is_empty():
		bridge_button=button(root,"",Rect2(game.bridge_gate_point()+Vector2(-22,36),Vector2(44,44)),game.trigger_bridge_gate);bridge_button.name="BridgeGate";bridge_button.tooltip_text="吊桥 · G：封锁14秒。未到岔路的敌军绕行，已选路单位继续通过。冷却28秒。";battle_nodes.append(bridge_button)
		icon(bridge_button,"flag",Rect2(8,6,26,26),GOLD);keycap(bridge_button,"G",Rect2(25,24,17,17));bridge_meter=meter(bridge_button,Rect2(4,39,36,3),GOLD);bridge_label=label(bridge_button,"",Rect2(0,0,1,1),10);bridge_label.hide()
	preview=Panel.new();preview.size=Vector2(300,102);preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel_style(preview);preview.hide();root.add_child(preview);battle_nodes.append(preview)
	if game.defense_rules: create_orders_panel()
	objective=Panel.new();objective.position=Vector2(660,835);objective.size=Vector2(280,46);objective.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(objective);pod_style(objective);battle_nodes.append(objective)
	objective_step=label(objective,"",Rect2(0,0,1,1),10);objective_step.hide();objective_title=label(objective,"",Rect2(12,9,258,26),14,CREAM);objective_body=label(objective,"",Rect2(0,0,1,1),10);objective_body.hide()
	var build:=Control.new();build.hide();root.add_child(build);battle_nodes.append(build);build_label=label(build,"",Rect2(0,0,1,1),10)
	root.move_child(context,root.get_child_count()-1)
func create_orders_panel() -> void:
	chest_button=button(root,"",Rect2(14,72,169,34),use_order.bind("chest"))
	chest_button.name="CashChest"
	chest_button.hide()
	battle_nodes.append(chest_button)
	orders_button=button(root,"战场指令",Rect2(214,827,118,48),toggle_orders)
	orders_button.name="BattleOrders"
	orders_button.hide()
	battle_nodes.append(orders_button)
	orders_panel=Panel.new()
	orders_panel.position=Vector2(210,515)
	orders_panel.size=Vector2(424,302)
	orders_panel.mouse_filter=Control.MOUSE_FILTER_STOP
	pod_style(orders_panel)
	root.add_child(orders_panel)
	orders_panel.hide()
	battle_nodes.append(orders_panel)
	orders_status=label(orders_panel,"",Rect2(12,8,400,65),14,CREAM)
	orders_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	order_hint=label(root,"",Rect2(348,832,650,40),16,GOLD)
	battle_nodes.append(order_hint)
	for id in ["flag_a","flag_b","relay","riposte","wall","beacon","bounty","chest","gate","lure","bridge","battery","muster"]:
		var b:=button(orders_panel,"",Rect2(0,0,196,34),use_order.bind(id))
		b.name="Order_"+id
		b.add_theme_font_size_override("font_size",15)
		order_buttons[id]=b

func toggle_orders() -> void:
	if not game.running or game.game_over or has_modal(): return
	game.orders.cancel_target()
	orders_panel.visible=not orders_panel.visible
	refresh_orders()

func use_order(id: String) -> void:
	var ok := game.orders.command(id)
	if not ok and game.orders.hint.is_empty(): game.orders.hint="当前无法执行这个指令"
	if not game.orders.targeting.is_empty(): orders_panel.hide()
	refresh_orders()

func refresh_orders() -> void:
	if not is_instance_valid(orders_panel): return
	var o:=game.orders
	var prep:=game.phase=="rest"
	var visible_orders := {}
	if o.has("relay"):
		if prep:
			visible_orders.flag_a="设甲旗（出发）" if o.has("one_way") else "设甲旗"
			visible_orders.flag_b="设乙旗"
		else: visible_orders.relay="两旗接应"
	if not prep and o.has("riposte"): visible_orders.riposte="回马一击"
	if o.has("wall"):
		if not prep: visible_orders.wall="收墙反推" if o.wall_left>0 else "升起城墙"
		elif o.has("open_gate"): visible_orders.gate="敞开 · "+o.lane_name(o.gate_lane)
	if not prep and o.has("beacon"): visible_orders.beacon="烽火齐射"
	if prep and o.has("bounty"): visible_orders.bounty="接悬赏 · "+o.lane_name(o.bounty_lane)
	if o.has("chest"):
		if prep: visible_orders.chest="钱箱 · "+o.lane_name(o.chest_lane)
		elif o.chest_open: visible_orders.chest="收箱 · %d 金"%o.cash_amount()
	if prep and o.has("lure"): visible_orders.lure="诱敌 · "+o.lane_name(o.lure_lane)
	if prep and o.has("bridge"): visible_orders.bridge="吊桥 · "+("长路" if o.long_bridge else "短路")
	if prep and o.has("battery"): visible_orders.battery="配对借台"
	if o.has("muster"): visible_orders.muster="两营会师／召回"
	var usable:=game.can_manage_defense() and not has_modal()
	chest_button.visible=usable and not prep and o.chest_open
	if chest_button.visible:
		chest_button.text="收箱  %d 金 · %d/5"%[o.cash_amount(),o.chest_count]
		chest_button.tooltip_text="三笔起领 1.5 倍，五笔领双倍。同路主队触核会失去未领取的金币。"
	orders_button.visible=usable and not visible_orders.is_empty()
	if not orders_button.visible: orders_panel.hide()
	order_hint.visible=usable
	order_hint.text=o.hint
	if o.bounty_active: order_hint.text+="  悬赏 %d/3"%o.bounty_kills
	if o.wall_left>0: order_hint.text+="  城墙 %d／300 · %.1f 秒"%[ceili(o.wall_hp),o.wall_left]
	if not orders_panel.visible: return
	var top := 60 if (prep and o.bounty_lane>=0) or (not prep and o.chest_open) else 42
	var n:=0
	for id: String in order_buttons:
		var b: Button=order_buttons[id]
		b.visible=id in visible_orders
		if not b.visible: continue
		b.text=visible_orders[id]
		b.position=Vector2(12+202*(n%2),top+40*floori(n/2.0))
		b.disabled=(id=="relay" and (o.transfer_used or o.transfer_left>0)) or (id=="riposte" and o.push_ready>0) or (id=="wall" and o.wall_used and o.wall_left<=0) or (id=="beacon" and o.beacon_used)
		n+=1
	orders_panel.size.y=top+40*ceili(n/2.0)+8
	orders_panel.position.y=817-orders_panel.size.y
	if prep:
		var packets:=game.wave_packets(game.wave_pattern())
		var lanes:=o.counts(packets,false)
		var parts:=PackedStringArray()
		for lane in lanes:
			var group:=packets.filter(func(p): return p.route==lane)
			parts.append("%s %d只／精英%d／%.1f秒"%( [o.lane_name(lane),group.size(),group.filter(func(p):return p.elite).size(),group[0].at] ))
		orders_status.text="  ".join(parts)
		if o.bounty_lane>=0:
			var names:=PackedStringArray()
			for p in packets:
				if p.get("bounty",false): names.append(ArenaDefinitions.enemy(p.kind).name)
			orders_status.text+="\n悬赏  "+"、".join(names)
	else:
		orders_status.text="选择指令，点选地图目标。右键取消。"
		if o.chest_open: orders_status.text+="\n钱箱 %d/5 笔 · 当前可领 %d 金"%[o.chest_count,o.cash_amount()]

func show_context(index: int) -> void:
	if not game.can_manage_defense():return
	game.selected_site=index;refresh_context()
func clear_children(node: Node) -> void:
	for child in node.get_children():node.remove_child(child);child.queue_free()
func _trait_badge(parent: Control,site_trait: String,trait_name: String,trait_desc: String,trait_tint: Color,rect: Rect2) -> void:
	if site_trait=="":return
	var badge:=Panel.new();badge.position=rect.position;badge.size=rect.size;badge.mouse_filter=Control.MOUSE_FILTER_PASS;pod_style(badge)
	badge.tooltip_text=trait_name+"："+trait_desc
	var glyph: String=str({"highground":"physical","choke":"shield","conduit":"magic"}.get(site_trait,"magic"))
	var stat: String=str({"highground":"+18%","choke":"+20%","conduit":"+14%"}.get(site_trait,"+"))
	icon(badge,glyph,Rect2(6,5,16,16),trait_tint)
	var lbl:=label(badge,stat,Rect2(24,3,rect.size.x-28,20),13,trait_tint);lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;lbl.mouse_filter=Control.MOUSE_FILTER_IGNORE
	parent.add_child(badge)
func refresh_context() -> void:
	if game.selected_site<0 or not game.can_manage_defense():return
	clear_children(context);context.show();_set_range_preview("")
	var tower: ArenaTower=game.site_tower(game.selected_site)
	if tower!=null and tower.awaiting_doctrine:
		doctrine_context(tower);return
	var locked:=tower==null and game.site_locked(game.selected_site)
	var work_allowed := game.can_change_towers()
	var has_doctrine:=tower!=null and tower.doctrine_id!=""
	var cannon_order:=tower!=null and tower.can_set_bombard()
	var fixed_order:=cannon_order and tower.bombard_point.is_finite()
	context.size=Vector2(328,154) if locked else (Vector2(372,172) if tower==null else (Vector2(442,314 if fixed_order else 270) if has_doctrine else Vector2(316,260 if fixed_order else 228)))
	if tower!=null and tower.project_level==0:
		var order_id:=""
		if tower.kind=="barracks" and game.orders.has("muster"): order_id="muster"
		elif game.phase=="rest" and tower.kind in ["archer","mage"] and game.orders.has("battery"): order_id="battery"
		if not order_id.is_empty():
			var row_y:=context.size.y
			context.size.y+=42
			button(context,"从本营会师／召回" if order_id=="muster" else "从本塔借台射击",Rect2(16,row_y-4,context.size.x-32,36),start_tower_order.bind(order_id,tower))
	var point: Vector2=game.world_to_hud(game.level_definition.sites[game.selected_site])
	context.position=Vector2(clampf(point.x-context.size.x*0.5,12,1600-context.size.x-12),clampf(point.y+38,86,900-context.size.y-15))
	var traits: Array=game.level_definition.get("site_traits",[])
	var site_trait: String=str(traits[game.selected_site]) if game.selected_site<traits.size() else ""
	var trait_name: String=ArenaTower.trait_label(site_trait)
	var trait_desc: String=ArenaTower.trait_summary(site_trait)
	if game.tower_lab and site_trait=="choke": trait_desc="兵营生命 +18%"
	var trait_tint: Color={"highground":Color("f6c862"),"choke":Color("ee7b56"),"conduit":Color("6ce8ff")}.get(site_trait,GOLD)
	var roles: Array=game.level_definition.get("site_roles",[])
	var role_name: String=str(roles[game.selected_site]) if game.selected_site<roles.size() else ""
	if not work_allowed and tower==null:
		label(context,"战中封工",Rect2(18,12,200,28),19,GOLD)
		label(context,"下次整备可建塔或解锁塔位",Rect2(18,55,284,30),17,MUTED)
		button(context,"关闭",Rect2(18,100,118,38),close_context)
		return
	if locked:
		var price:=game.unlock_price(game.selected_site)
		label(context,"解锁塔位",Rect2(18,12,180,30),20,GOLD)
		_trait_badge(context,site_trait,trait_name,trait_desc,trait_tint,Rect2(228,12,82,26))
		var unlock:=button(context,"解锁    %d  ◉"%price,Rect2(18,52,292,48),game.unlock_site.bind(game.selected_site),true);unlock.name="UnlockSite";unlock.disabled=game.gold<price
		unlock.tooltip_text=(role_name+"\n" if role_name!="" else "")+"解锁后可建造或出售防御塔"
		var lock_count: int=game.level_definition.get("locked_sites",[]).size()
		label(context,"+%d 火力位"%lock_count if lock_count>1 else "+1 火力位",Rect2(18,108,290,22),13,MUTED)
	elif tower==null:
		label(context,"建造防御塔",Rect2(18,10,160,28),19,GOLD)
		_trait_badge(context,site_trait,trait_name,trait_desc,trait_tint,Rect2(272,10,84,26))
		for column in range(game.run_towers.size()):
			var key: String=game.run_towers[column];var data:=game.tower_display_data(key)
			var b:=button(context,"",Rect2(14+column*86,44,80,108),_build.bind(key));b.name="Build_"+key;b.disabled=key not in game.available_towers() or game.gold<int(data.cost)
			var b_img:=image(b,tower_portrait(key),Rect2(6,4,68,68));b_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			icon(b,"coin",Rect2(12,79,18,18));label(b,str(data.cost),Rect2(34,78,42,22),16,GOLD)
			if game.level_id==ArenaSaltport.ID:
				b.focus_mode=Control.FOCUS_ALL
				b.mouse_entered.connect(_set_range_preview.bind(key))
				b.mouse_exited.connect(_set_range_preview.bind(""))
				b.focus_entered.connect(_set_range_preview.bind(key))
				b.focus_exited.connect(_set_range_preview.bind(""))
			b.tooltip_text=data.name+" · "+ArenaCombat.label(data.type)+"\n"+(trait_name+"："+trait_desc if trait_name!="" else data.description)+("\n第"+str(game.level_definition.towers[key])+"波开放" if key not in game.available_towers() else "")
	elif has_doctrine:
		var entry: Dictionary=ArenaDoctrines.by_id(tower.doctrine_id)
		label(context,str(tower.data.name)+" · "+str(entry.name),Rect2(18,12,280,30),21,GOLD)
		label(context,"%d / 10 阶"%tower.total_steps(),Rect2(304,14,120,26),17,Color("7fd8ff")).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		icon(context,"physical" if tower.data.type==0 else "magic",Rect2(18,46,20,20),ArenaCombat.colour(tower.data.type))
		var doc_sub: String=ArenaCombat.label(tower.data.type)+" · "+str(entry.role)+(" · "+trait_name if trait_name!="" else "（双分支可同修）")
		label(context,doc_sub,Rect2(44,44,380,24),14,MUTED)
		var hidden_up:=Button.new();hidden_up.name="Upgrade";hidden_up.disabled=true;hidden_up.visible=false;context.add_child(hidden_up)
		var b_list: Array=ArenaDoctrines.branches(tower.doctrine_id)
		for b in range(b_list.size()):
			var b_info: Dictionary=b_list[b]
			var rank: int=tower.branch_rank(b);var b_price: int=tower.branch_price(b);var maxed: bool=rank>=3
			var btn:=button(context,"",Rect2(14+b*210,76,202,126),_upgrade_branch.bind(b));btn.name="Branch_"+str(b)
			btn.disabled=not work_allowed or maxed or game.gold<b_price
			var accent_tint:=Color("f5cd6a") if b==0 else Color("7fd8ff")
			label(btn,str(b_info.name),Rect2(12,8,136,24),16,accent_tint)
			label(btn,str(rank)+"/3",Rect2(150,9,40,22),15,accent_tint).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			var desc:=label(btn,str(b_info.summary),Rect2(12,36,178,52),12,CREAM);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			var price_text:="✓ 已满阶" if maxed else ("↑  %d ◉"%b_price)
			var price_tint:=Color("9ee4a8") if maxed else (GOLD if game.gold>=b_price else Color("e7a28a"))
			label(btn,price_text,Rect2(12,92,178,24),15,price_tint).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var ground_order:=tower.kind in ["barracks","snare"] or cannon_order
		var order_label:="设落点" if cannon_order else ("⚑ 集结" if tower.kind=="barracks" else "◎ 目标")
		var target:=button(context,order_label,Rect2(14,214,126,42),_rally if ground_order else _target)
		if tower.kind=="snare": target.text="设绊索"
		target.tooltip_text="点选射程内的道路，移索后需要重新布设" if tower.kind=="snare" else "选择射程内的炮击点" if cannon_order else ("调整集结点" if ground_order else "切换优先目标")
		_sale_button(tower,Rect2(154,214,148,42),work_allowed)
		button(context,"×",Rect2(316,214,110,42),close_context)
		if fixed_order: button(context,"恢复自动瞄准",Rect2(14,266,288,36),tower.clear_bombard)
	else:
		label(context,str(tower.data.name)+"  "+str(tower.level)+"/3",Rect2(18,12,160,30),21,GOLD)
		_trait_badge(context,site_trait,trait_name,trait_desc,trait_tint,Rect2(216,12,84,26))
		icon(context,"physical" if tower.data.type==0 else "magic",Rect2(18,48,22,22),ArenaCombat.colour(tower.data.type))
		var description:=label(context,ArenaCombat.label(tower.data.type)+" · "+str(tower.data.description),Rect2(48,44,250,40),14,MUTED)
		description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var price:=tower.upgrade_price()
		if tower.project_level!=0:
			var caption:="建造中 · 取消" if tower.project_level==1 else "升级中 · 取消"
			var cancel:=button(context,caption,Rect2(16,88,284,46),tower.cancel_project)
			cancel.name="CancelTowerWork"
			cancel.tooltip_text="返还本次投入"
		else:
			var caption:="↑    %d  ◉"%price if tower.level<3 else "已达三级"
			var up:=button(context,caption,Rect2(16,88,284,46),tower.upgrade,true)
			up.name="Upgrade";up.disabled=not work_allowed or tower.level>=3 or game.gold<price
		if not game.tower_lab or tower.kind=="barracks" or cannon_order:
			var title:="改落点" if fixed_order else ("设落点" if cannon_order else ("⚑" if tower.kind=="barracks" else "◎"))
			var ground_order:=tower.kind in ["barracks","snare"] or cannon_order
			var target:=button(context,title,Rect2(16,150,84,44),_rally if ground_order else _target)
			target.name="TowerGroundOrder" if ground_order else "TowerPriority"
			if tower.kind=="snare": target.text="设绊索"
			target.tooltip_text="点选射程内的道路，移索后需要重新布设" if tower.kind=="snare" else "选择射程内的炮击点。爆炸范围内有敌时开炮。" if cannon_order else ("调整集结点" if ground_order else "切换优先目标")
			target.disabled=tower.project_level==1
		if fixed_order:
			var automatic:=button(context,"恢复自动瞄准",Rect2(16,201,284,36),tower.clear_bombard)
			automatic.name="ResetBombard"
		_sale_button(tower,Rect2(110,150,120,44),work_allowed)
		button(context,"×",Rect2(240,150,60,44),close_context)
func start_tower_order(order_id: String,tower: ArenaTower) -> void:
	if is_instance_valid(tower) and game.orders.command(order_id):
		game.orders.choose_point(tower.position)

func _sale_button(tower: ArenaTower,rect: Rect2,work_allowed: bool) -> void:
	var caption := "出售 %d ◉" % tower.sale_value() if game.defense_rules else "出售"
	if not work_allowed: caption="整备时出售"
	elif game.defense_rules and tower.project_level!=0: caption="完工后出售"
	var sale:=button(context,caption,rect,tower.sell)
	sale.name="SellTower"
	sale.disabled=not work_allowed or tower.project_level!=0
	sale.tooltip_text="战中封工 · 建造、升级和出售在整备时开放" if not work_allowed else "售价 %d 金币" % tower.sale_value()
	if work_allowed and tower.project_level!=0: sale.tooltip_text="当前项目可从塔位菜单取消"
func doctrine_context(tower: ArenaTower) -> void:
	var options: Array=ArenaDoctrines.for_tower(tower.kind)
	context.size=Vector2(516,312)
	var point: Vector2=game.world_to_hud(game.level_definition.sites[tower.site_id])
	context.position=Vector2(clampf(point.x-context.size.x*0.5,12,1600-context.size.x-12),clampf(point.y+38,86,900-context.size.y-15))
	label(context,"L3 改造 · 选择专属流派",Rect2(18,10,300,30),20,GOLD)
	label(context,"选定后开放双分支 10 阶养成",Rect2(276,14,224,22),12,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	for index in range(options.size()):
		var entry: Dictionary=options[index]
		var card:=button(context,"",Rect2(14+index*166,46,154,250),game.choose_doctrine.bind(tower.site_id,str(entry.id)))
		card.name="Doctrine_"+str(entry.id)
		label(card,str(entry.name),Rect2(10,10,134,28),19,GOLD)
		label(card,str(entry.role),Rect2(10,38,134,22),12,Color("8bdadf"))
		var body:=label(card,str(entry.summary),Rect2(10,64,134,122),13,CREAM)
		body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label(card,"代价："+str(entry.drawback),Rect2(10,192,134,46),12,Color("e7a28a"))
func _upgrade_branch(index: int) -> void:
	var tower:=game.site_tower(game.selected_site)
	if tower!=null and tower.upgrade_branch(index):refresh_context()
func _build(key: String) -> void:
	if game.build_tower(game.selected_site,key):refresh_context()
func _rally() -> void:
	if not game.can_manage_defense():return
	game.rally_site=game.selected_site;close_context()
func _target() -> void:
	if not game.can_manage_defense():return
	var tower:=game.site_tower(game.selected_site)
	if tower!=null and tower.forced_target()=="":
		tower.target_mode="strongest" if tower.target_mode=="first" else "first";refresh_context()
func close_context() -> void:context.hide();game.selected_site=-1;_set_range_preview("")

func _set_range_preview(key: String) -> void:
	preview_tower=key
	game.queue_redraw()
func announce_unlock() -> void:
	if not game.started:return
	var unlocked: Array=[]
	for key in game.available_towers():
		if int(game.level_definition.towers[key])==game.cycle:unlocked.append(key)
	if unlocked.is_empty():return
	if not is_instance_valid(unlock_hint):
		unlock_hint=Panel.new();unlock_hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(unlock_hint);pod_style(unlock_hint);battle_nodes.append(unlock_hint)
	clear_children(unlock_hint);unlock_hint.position=Vector2(636,68);unlock_hint.size=Vector2(48+unlocked.size()*66,75);unlock_hint.show();unlock_clock=3.5
	icon(unlock_hint,"upgrade",Rect2(10,22,27,32))
	for i in range(unlocked.size()):
		var u_img:=image(unlock_hint,tower_portrait(unlocked[i]),Rect2(45+i*66,4,64,64))
		u_img.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
func modal_panel(size: Vector2) -> Panel:
	close_modal();modal=Control.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.mouse_filter=Control.MOUSE_FILTER_STOP;root.add_child(modal)
	var veil:=ColorRect.new();veil.color=Color(0.05,0.08,0.12,0.72);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_child(veil)
	var panel:=Panel.new();panel.size=size;panel.position=(Vector2(1600,900)-size)*0.5;modal.add_child(panel);panel_style(panel);return panel
func close_modal() -> void:
	if is_instance_valid(modal):root.remove_child(modal);modal.queue_free()
	modal=null
func has_modal() -> bool:return is_instance_valid(modal) or is_instance_valid(codex)
func show_rule_choice(offers: Array[Dictionary]) -> void:
	close_context()
	game.rally_site=-1
	game.targeting_slot=-1
	var width := maxf(580.0, 40.0 + 380.0 * offers.size())
	var panel:=modal_panel(Vector2(width,390))
	label(panel,"第一波 · 选本局打法" if game.cycle==1 else "第 %d 波 · 加选打法" % game.cycle,Rect2(24,30,width-48,38),28,GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label(panel,"选中的祝福和诅咒持续到本局结束",Rect2(24,76,width-48,25),17,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var left := (width-380.0*offers.size())*0.5
	for i in range(offers.size()):
		var rule := offers[i]
		var card := button(panel,"",Rect2(left+380*i+6,118,368,174),game.choose_defense_rule.bind(str(rule.id)))
		card.name="DefenseRule_"+str(rule.id)
		label(card,str(rule.name),Rect2(22,19,324,34),25,GOLD)
		var blessing:=label(card,"祝福  "+str(rule.blessing),Rect2(22,68,324,42),18,Color("a9e2bd"))
		var curse:=label(card,"诅咒  "+str(rule.curse),Rect2(22,117,324,42),18,Color("f1aa98"))
		blessing.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		curse.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if game.cycle==1:
		var control:=button(panel,"常规守线",Rect2((width-202.0)*0.5,323,202,44),game.choose_defense_rule.bind(""))
		control.name="StandardDefense"
func show_choices(keys: Array[String]) -> void:
	close_context();game.targeting_slot=-1;game.rally_site=-1
	var panel:=modal_panel(Vector2(1060,510))
	var head:=label(panel,"★ 觉醒抉择 · 三选一",Rect2(40,22,980,44),28,GOLD);head.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var sub:=label(panel,"仅于关键节点（Lv.2 / Lv.5 / Lv.8）触发 · 直赋满阶觉醒威力",Rect2(40,66,980,26),15,MUTED);sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for index in range(keys.size()):
		var key: String=keys[index];var data: Dictionary=ArenaPerks.card(key)
		var colour: Color=data.get("color",GOLD)
		var b:=button(panel,"",Rect2(34+index*340,104,312,374),game.choose_perk.bind(key));b.name="Perk_"+key
		keycap(b,str(index+1),Rect2(14,12,28,24))
		var badge_text:="★ 进化觉醒" if bool(data.get("evolution",false)) else "★ 觉醒满阶"
		label(b,badge_text,Rect2(146,12,152,24),14,GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var plate:=sub_card(b,Rect2(14,44,284,264),true)
		var tex:=ArenaMenuArt.perk(key)
		if tex!=null:image(plate,tex,Rect2(105,12,74,74))
		else:icon(plate,str(data.icon),Rect2(112,18,60,60),colour)
		var title:=label(plate,str(data.name),Rect2(16,92,252,32),22,ArenaMenuArt.PAPER);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var axis:=label(plate,"%s · 满阶 %d/%d"%[AXIS_NAME.get(str(data.axis),str(data.axis)),int(data.max),int(data.max)],Rect2(16,124,252,22),13,ArenaMenuArt.PAPER_MUTED);axis.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		colour_block(plate,Rect2(28,150,228,1),Color(ArenaMenuArt.PAPER_MUTED,0.35))
		var lines: Array=data.ranks
		var awakened_text: String=""
		if not lines.is_empty():
			var last_line:=str(lines[lines.size()-1])
			if last_line.begins_with("再"):awakened_text=str(lines[0])+"；且"+last_line+"\n（满阶觉醒 · 数值 ×1.25）"
			elif key=="burn":awakened_text="普攻附带持续火焰灼烧\n（满阶觉醒：每秒 +22 灼烧）"
			else:awakened_text=last_line+"\n（"+("满阶觉醒 · 数值 ×1.25" if lines.size()>1 else "觉醒强化")+"）"
		var effect:=label(plate,awakened_text,Rect2(18,156,248,74),14,ArenaMenuArt.PAPER)
		effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		if str(data.get("hint",""))!="":
			var hint_lbl:=label(plate,str(data.hint),Rect2(18,232,248,24),12,Color("7a4c14") if bool(data.get("evolution",false)) else ArenaMenuArt.PAPER_MUTED)
			hint_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var peers: Array[String]=[]
		for edge in ArenaPerks.LINKS:
			if edge.from==key or edge.to==key:
				var other: String=str(edge.to) if edge.from==key else str(edge.from)
				var peer_txt:=str(ArenaPerks.card(other).get("name",other))+("✓" if game.hero.perk(other)>0 else "")
				if not (peer_txt in peers):peers.append(peer_txt)
		if not peers.is_empty():
			var link_colour:=Color("9ee4a8") if game.hero.perk(key)>0 else MUTED
			var links:=label(b,"联动："+"、".join(peers),Rect2(16,320,280,24),12,link_colour)
			links.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;links.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			b.tooltip_text="联动："+"、".join(peers)
		else:
			label(b,"点击或按数字键选取",Rect2(16,320,280,24),12,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
func show_passive_choices(keys: Array[String]) -> void:
	close_context();game.targeting_slot=-1;game.rally_site=-1
	var panel:=modal_panel(Vector2(1060,486))
	var head:=label(panel,"被动抉择" if game.condition_lab else "被动抉择 · 三选一（原型）",Rect2(40,22,980,44),28,GOLD);head.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var sub:=label(panel,"选取一张，重复选取升至 2 阶" if game.condition_lab else "事件 / 动作卡 · 每张 2 阶 · 每局 1 次重抽",Rect2(40,66,980,26),15,MUTED);sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for index in range(keys.size()):
		var key: String=keys[index];var data: Dictionary=ArenaConditions.CARDS[key] if game.condition_lab else ArenaPassives.card(key)
		var colour: Color=data.get("color",{"common":CREAM,"rare":Color("99dfff"),"epic":Color("d8b7ff")}.get(data.rarity,GOLD))
		var b:=button(panel,"",Rect2(34+index*340,104,312,300),game.choose_passive.bind(key));b.name="Passive_"+key
		keycap(b,str(index+1),Rect2(14,12,28,24))
		var rank:=game.passive_rank(key)
		var title:=label(b,"%s · %d/2"%[str(data.get("name",key)),rank+1 if game.condition_lab else rank],Rect2(46,10,252,28),19,colour)
		title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
		var rarity_name: String=str({"common":"普通","rare":"稀有","epic":"史诗"}.get(str(data.get("rarity","common")),"普通"))
		var type_name: String=str(data.type) if game.condition_lab else ("事件" if str(data.get("type",""))=="event" else "动作")
		label(b,"%s · %s"%[type_name,rarity_name],Rect2(16,44,280,22),13,MUTED)
		var lines: Array=data.get("desc",[])
		var text: String=""
		if not lines.is_empty():text=str(lines[mini(rank,lines.size()-1)])
		if rank>=2:text+="\n（已满阶）"
		if game.condition_lab:
			var card_icon:=ArenaConditions.icon(key)
			if card_icon!=null: image(b,card_icon,Rect2(126,84,60,60))
			if key=="breaker": b.tooltip_text="物理英雄看护甲，法术英雄看抗性。达到 40% 即为高防。"
		var body_rect:=Rect2(20,164,272,104) if game.condition_lab else Rect2(20,80,272,150)
		var body:=label(b,text,body_rect,19 if game.condition_lab else 17,CREAM)
		body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		body.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	if game.passive_reroll_used:
		label(panel,"本局重抽已用",Rect2(430,424,200,36),15,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	else:
		button(panel,"重抽一次",Rect2(430,418,200,42),game.reroll_passives)

func show_keystone_choices(keys: Array[String]) -> void:
	close_context();game.targeting_slot=-1;game.rally_site=-1
	var panel:=modal_panel(Vector2(1060,486))
	var wave_done:=maxi(2,game.cycle-1)
	var head:=label(panel,"★ 秘石觉醒 · 质变大天赋（三选一）",Rect2(40,22,980,44),28,GOLD);head.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var sub:=label(panel,"第 %d 波清场奖励 · 仅在整备阶段触发 · 战斗零打断 · 永久改变本局协同流派"%wave_done,Rect2(40,66,980,26),15,MUTED);sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	for index in range(keys.size()):
		var key: String=keys[index];var data: Dictionary=ArenaKeystones.by_id(key)
		var colour: Color=data.get("color",GOLD)
		var b:=button(panel,"",Rect2(34+index*340,104,312,348),game.choose_perk.bind(key));b.name="Keystone_"+key
		keycap(b,str(index+1),Rect2(14,12,28,24))
		label(b,"★ 质变秘石",Rect2(146,12,152,24),14,colour).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		var plate:=sub_card(b,Rect2(14,44,284,254),true)
		icon(plate,"star",Rect2(114,8,56,56),colour)
		var title:=label(plate,str(data.get("name",key)),Rect2(16,66,252,32),22,ArenaMenuArt.PAPER);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var tag:=label(plate,str(data.get("tag","")),Rect2(16,97,252,22),13,ArenaMenuArt.PAPER_MUTED);tag.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		colour_block(plate,Rect2(28,123,228,1),Color(ArenaMenuArt.PAPER_MUTED,0.35))
		var effect:=label(plate,str(data.get("summary","")),Rect2(18,129,248,76),14,ArenaMenuArt.PAPER)
		effect.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;effect.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var hint_lbl:=label(plate,str(data.get("hint","")),Rect2(18,210,248,22),12,Color("7a4c14"));hint_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label(b,"点击或按 ["+str(index+1)+"] 刻印核心",Rect2(16,308,280,24),13,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
func show_pause() -> void:
	if game.choice_open or not game.rule_offers.is_empty() or game.game_over:return
	if has_modal():resume();return
	get_tree().paused=true;close_context();game.targeting_slot=-1;game.rally_site=-1
	var panel:=modal_panel(Vector2(860,546))
	label(panel,"守 望 手 册",Rect2(30,22,800,40),28,GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label(panel,"按 H 或 Esc 随时切换暂停 · 鼠标点击塔位建塔与双分支升级",Rect2(30,60,800,24),13,MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var left:=sub_card(panel,Rect2(28,90,394,364),true)
	label(left,"操作与英雄技能",Rect2(30,22,334,28),19,ArenaMenuArt.PAPER)
	keycap(left,"WASD / 右键",Rect2(26,56,110,28));label(left,"移动走位与集火路线",Rect2(146,58,224,26),15,ArenaMenuArt.PAPER)
	keycap(left,"按住左键",Rect2(26,92,110,28));label(left,"持续普攻附近敌军",Rect2(146,94,224,26),15,ArenaMenuArt.PAPER)
	colour_block(left,Rect2(26,130,342,1),Color(ArenaMenuArt.PAPER_MUTED,0.3))
	for slot in range(2):
		var y_off:=146+slot*102
		var sk_name:=str(game.hero.data.small if slot==0 else game.hero.data.ultimate)
		var unlocked:=game.hero.skill_unlocked(slot)
		var badge_box:=Panel.new();badge_box.position=Vector2(26,y_off);badge_box.size=Vector2(56,56);badge_box.mouse_filter=Control.MOUSE_FILTER_IGNORE;pod_style(badge_box);left.add_child(badge_box)
		image(badge_box,ArenaMenuArt.skill(game.hero.class_id,slot),Rect2(5,5,46,46))
		keycap(left,"Q" if slot==0 else "E",Rect2(92,y_off,26,24))
		label(left,sk_name+(" (已解锁)" if unlocked else " (%d级解锁)"%(2 if slot==0 else 4)),Rect2(124,y_off,246,26),16,ArenaMenuArt.PAPER if unlocked else ArenaMenuArt.PAPER_MUTED)
		var sk_desc:=label(left,ArenaDefinitions.skill_text(game.hero.class_id,slot),Rect2(92,y_off+28,278,64),13,ArenaMenuArt.PAPER_MUTED);sk_desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if game.condition_lab:
		label(left,"可边走边普攻",Rect2(26,322,342,26),14,ArenaMenuArt.PAPER)
	var right:=sub_card(panel,Rect2(438,90,394,364),true)
	label(right,"防线规则 · 本局构筑",Rect2(30,18,334,26),19,ArenaMenuArt.PAPER)
	var rule_text: String="• 三路合围 + 第4波东北破障；[G] 吊桥分流改道\n• 高台+射程 · 隘口强兵营 · 脉座+攻速穿透\n• 战斗零打断！第 2/4/6 波后整备三选一质变秘石" if game.keystone_mode else "• L3 转职后可同修双分支（最高 10 阶）\n• 物理克轻甲、法术破重甲；英雄 15 秒复活\n• Lv.2 / Lv.5 / Lv.8 触发满阶觉醒三选一"
	if game.condition_lab:
		var level_rule: String="• 第 4 波东北破障，按 G 切换吊桥" if game.keystone_mode else "• 塔升至三级后可选改造，再升双分支"
		rule_text=level_rule+"\n• 局内 2–11 级各三选一，重复选取升阶\n• 本局重抽"+("已用" if game.passive_reroll_used else "剩余 1 次")
	if game.defense_rules:
		rule_text="守住核心并清完所有波次。有首领的关卡还需击败首领。"
	var rules:=label(right,rule_text,Rect2(26,48,342,68),13,ArenaMenuArt.PAPER_MUTED);rules.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	colour_block(right,Rect2(26,124,342,1),Color(ArenaMenuArt.PAPER_MUTED,0.3))
	if game.defense_rules:
		if game.selected_defense_cards.is_empty(): label(right,"常规守线",Rect2(26,134,342,24),16,ArenaMenuArt.PAPER)
		var rule_list:=VBoxContainer.new()
		var scroll:=ScrollContainer.new()
		scroll.position=Vector2(24,134);scroll.size=Vector2(346,215)
		scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
		right.add_child(scroll);scroll.add_child(rule_list)
		for rule in game.selected_defense_cards:
			var entry:=Label.new()
			entry.custom_minimum_size.x=326
			entry.text="%s\n祝福  %s\n诅咒  %s" % [rule.name,rule.blessing,rule.curse]
			entry.add_theme_color_override("font_color",ArenaMenuArt.PAPER)
			entry.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			rule_list.add_child(entry)
	elif game.condition_lab:
		label(right,"本局被动",Rect2(26,134,342,24),16,ArenaMenuArt.PAPER)
		if game.passive_ranks.is_empty():
			label(right,"到达局内 2 级后选择第一张卡。",Rect2(26,169,342,26),14,ArenaMenuArt.PAPER_MUTED)
		var index:=0
		for key in game.passive_ranks:
			var card: Dictionary=ArenaConditions.CARDS[key]
			var rank: int=game.passive_rank(key)
			var x:=26+(index%2)*171
			var y:=168+int(index/2.0)*36
			var badge:=label(right,"%s · %d 阶" % [card.name,rank],Rect2(x+32,y,132,28),14,ArenaMenuArt.PAPER)
			badge.mouse_filter=Control.MOUSE_FILTER_PASS
			badge.tooltip_text=card.desc[rank-1]
			var texture:=ArenaConditions.icon(key)
			if texture!=null: image(right,texture,Rect2(x,y,26,26))
			index+=1
	elif game.keystone_mode:
		label(right,"已刻印质变秘石（%d / 3）"%game.keystones.size(),Rect2(26,134,342,24),16,ArenaMenuArt.PAPER)
		if game.keystones.is_empty():
			var none_k:=label(right,"尚未觉醒秘石核心\n撑过第 2、4、6 波后的整备阶段将自动三选一",Rect2(26,168,342,64),13,ArenaMenuArt.PAPER_MUTED);none_k.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		else:
			for i in range(mini(game.keystones.size(),3)):
				var kd:=ArenaKeystones.by_id(game.keystones[i]);var ky:=174+i*58
				icon(right,"star",Rect2(22,ky+4,32,32),kd.get("color",GOLD))
				label(right,str(kd.get("name",game.keystones[i])),Rect2(60,ky+2,160,22),15,ArenaMenuArt.PAPER)
				label(right,str(kd.get("tag","")),Rect2(224,ky+3,144,20),12,Color("7a4c14")).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
				var ks:=label(right,str(kd.get("hint","")),Rect2(60,ky+24,308,20),12,ArenaMenuArt.PAPER_MUTED)
				ks.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS
	else:
		label(right,"本局已觉醒被动",Rect2(26,142,342,24),16,ArenaMenuArt.PAPER)
		var owned: Array[String]=[]
		for k in game.hero.perks:
			if game.hero.perk(str(k))>0:owned.append(str(k))
		if owned.is_empty():
			var none:=label(right,"尚未觉醒被动\n升至 Lv.2 / Lv.5 / Lv.8 可获得满阶成长卡",Rect2(22,188,350,80),14,ArenaMenuArt.PAPER_MUTED);none.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		else:
			for i in range(mini(owned.size(),6)):
				var pk:=owned[i];var pcard: Dictionary=ArenaPerks.card(pk)
				var cx:=22+(i%2)*178;var cy:=174+int(i/2)*56
				var ptex:=ArenaMenuArt.perk(pk)
				if ptex!=null:image(right,ptex,Rect2(cx,cy,44,44))
				label(right,str(pcard.get("name",pk)),Rect2(cx+50,cy+4,122,22),15,ArenaMenuArt.PAPER)
				label(right,"★ 已觉醒" if bool(game.hero.awakened_perks.get(pk,false)) else "Lv."+str(game.hero.perk(pk)),Rect2(cx+50,cy+26,122,18),12,Color("7a4c14"))
	if not game.condition_lab and not game.defense_rules:
		var codex_button:=button(panel,"被动图鉴",Rect2(28,472,232,52),show_codex);codex_button.name="被动图鉴";ArenaMenuArt.accent(codex_button,"blue")
	var go_btn:=button(panel,"继续守望",Rect2(294,472,272,52),resume,true);ArenaMenuArt.accent(go_btn,"green")
	var back_btn:=button(panel,"返回地图",Rect2(600,472,232,52),game.return_to_menu);ArenaMenuArt.accent(back_btn,"amber")
func resume() -> void:
	if not game.rule_offers.is_empty(): return
	get_tree().paused=false;close_modal();game.suppress_primary=Input.is_action_pressed("shoot")
	game.pump_modals()
func show_guide() -> void:
	var panel:=modal_panel(Vector2(820,544))
	label(panel,"新任守望者指南",Rect2(30,22,760,42),28,GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var card:=sub_card(panel,Rect2(34,76,752,374),true)
	label(card,"1  部署防线",Rect2(28,22,150,28),18,Color("7a4c14"));label(card,"在金色塔位建塔与升级；L3 转职后可双分支冲至 10 阶。",Rect2(178,22,544,28),17,ArenaMenuArt.PAPER)
	label(card,"2  英雄出战",Rect2(28,76,150,28),18,Color("7a4c14"));label(card,"WASD/右键移动，左键普攻；养成至 2/4 级解锁 Q/E 技能。",Rect2(178,76,544,28),17,ArenaMenuArt.PAPER)
	var growth_title: String="3  被动成长" if game.condition_lab else "3  觉醒成长"
	var growth_text: String="局内 2–11 级各选一张被动，重复升阶，每局可重抽一次。" if game.condition_lab else "每级瞬发回血爆气，Lv.2/5/8 选满阶觉醒被动。"
	if game.defense_rules:
		growth_title="3  自选打法"
		growth_text="开局选打法，祝福和诅咒持续到本局结束。"
	label(card,growth_title,Rect2(28,130,150,28),18,Color("7a4c14"));label(card,growth_text,Rect2(178,130,544,28),17,ArenaMenuArt.PAPER)
	colour_block(card,Rect2(28,184,696,1),Color(ArenaMenuArt.PAPER_MUTED,0.35))
	label(card,"物理",Rect2(28,210,90,28),18,Color("8d5418"));label(card,"弓箭、火炮、领主、狼王、星衡与士兵 · 适合压制轻甲与兽群",Rect2(140,210,580,28),17,ArenaMenuArt.PAPER)
	label(card,"法术",Rect2(28,254,90,28),18,Color("2e5d8f"));label(card,"德鲁伊、爱神与法师塔 · 穿透重甲并强化全队防线",Rect2(140,254,580,28),17,ArenaMenuArt.PAPER)
	label(card,"提示：英雄倒下 15 秒后在信标处复活，唯有信标失守才会战败。",Rect2(28,314,696,28),16,ArenaMenuArt.PAPER_MUTED)
	var go:=button(panel,"开始守望",Rect2(250,468,320,52),close_modal,true);ArenaMenuArt.accent(go,"green")
func show_result() -> void:
	close_context();var panel:=modal_panel(Vector2(740,478))
	label(panel,"防线守住了" if game.victory else "信标失守",Rect2(30,24,680,50),34,GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var card:=sub_card(panel,Rect2(34,86,672,286),true)
	label(card,"本局战报",Rect2(28,16,200,28),18,Color("7a4c14"));colour_block(card,Rect2(28,50,616,1),Color(ArenaMenuArt.PAPER_MUTED,0.35))
	label(card,"抵达波次",Rect2(28,70,150,24),14,ArenaMenuArt.PAPER_MUTED);label(card,str(game.cycle)+" / "+str(game.total_waves()),Rect2(28,96,150,32),24,ArenaMenuArt.PAPER)
	label(card,"击败敌人",Rect2(246,70,150,24),14,ArenaMenuArt.PAPER_MUTED);label(card,str(game.kills),Rect2(246,96,150,32),24,ArenaMenuArt.PAPER)
	label(card,"英雄等级",Rect2(464,70,150,24),14,ArenaMenuArt.PAPER_MUTED);label(card,"Lv."+str(game.hero.meta_level if game.defense_rules else game.hero.level),Rect2(464,96,150,32),24,ArenaMenuArt.PAPER)
	label(card,"建造 %d 座防御塔   ·   核心耐久 %d"%[game.built,ceili(game.core_health)],Rect2(28,154,616,28),17,ArenaMenuArt.PAPER_MUTED)
	colour_block(card,Rect2(28,198,616,1),Color(ArenaMenuArt.PAPER_MUTED,0.25))
	image(card,ArenaMenuArt.utility("diamond"),Rect2(28,218,32,32))
	var saved:=bool(game.settlement.get("ok",false))
	label(card,("+"+str(game.settlement.get("amount",0))+" 钻石    总计 "+str(game.campaign.gems())) if saved else "奖励尚未保存",Rect2(72,218,390,32),20,Color("7a4c14") if saved else Color("9e342b"))
	if not saved:
		var save_button:=button(card,"重试保存",Rect2(484,214,160,40),game.retry_settlement);save_button.name="RetrySave";ArenaMenuArt.accent(save_button,"amber")
	var hall:=button(panel,"英雄养成",Rect2(34,394,200,56),game.open_hero_hall);hall.name="ResultHeroHall";ArenaMenuArt.accent(hall,"blue")
	var retry:=button(panel,"再次出战",Rect2(270,394,200,56),game.restart_run,true);retry.name="RetryRun";ArenaMenuArt.accent(retry,"green")
	var map_btn:=button(panel,"返回地图",Rect2(506,394,200,56),game.return_to_menu);ArenaMenuArt.accent(map_btn,"amber")

func objective_state() -> Dictionary:
	if game.built==0:return {"step":"守望指引 · 1 / 3","title":"部署第一座防御塔","body":"点击道路旁的金色塔位，然后选择建筑。"}
	if game.phase=="rest" and game.cycle==1:return {"step":"守望指引 · 2 / 3","title":"侦察第一波敌人","body":"点击入口旁怪物图标预览，再点一次提前开波。"}
	if game.cycle==1:return {"step":"守望指引 · 3 / 3","title":"英雄加入防守","body":"WASD / 右键移动，按住左键攻击；技能在英雄2级、4级解锁。"}
	if game.phase=="rest":return {"step":"整备阶段","title":"升级防线，准备第 "+str(game.cycle)+" 波","body":"利用金币升级塔；提前开波奖励至多12金币。"}
	return {"step":"防守阶段","title":"守住第 "+str(game.cycle)+" 波","body":"观察敌人抗性，英雄随时回防；基地失守才会失败。"}

func refresh_objective() -> void:
	if not is_instance_valid(objective):return
	if not tutorial_finished and game.built>0 and game.hero.shots>0 and game.phase!="rest":
		tutorial_finished=true;game.campaign.complete_tutorial()
	objective.visible=game.can_manage_defense() and not tutorial_finished and not bool(game.campaign.data.get("tutorial_done",false)) and game.cycle==1 and game.built==0
	var state:=objective_state();var signature: String=str(state.step)+str(state.title)
	if signature!=last_objective:
		last_objective=signature;objective_step.text=state.step;objective_title.text=state.title;objective_body.text=state.body
	if game.defense_rules: return
	var summary: Array[String]=[]
	if game.keystone_mode:
		for key in game.keystones:
			summary.append(str(ArenaKeystones.by_id(key).get("name",key)))
		build_label.text="秘石核心 · "+("第2/4/6波后整备觉醒" if summary.is_empty() else "  ".join(summary))
	else:
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
	if game.game_over:return
	if not game.rule_offers.is_empty():
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			var index: int=event.keycode-KEY_1
			if index<game.rule_offers.size(): game.choose_defense_rule(str(game.rule_offers[index].id))
		get_viewport().set_input_as_handled()
		return
	if game.choice_open:
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			var index: int=event.keycode-KEY_1
			if index<game.choices.size():
				if game.passive_lab or game.condition_lab:game.choose_passive(game.choices[index])
				else:game.choose_perk(game.choices[index])
			get_viewport().set_input_as_handled()
		return
	if not game.started:
		if event.keycode==KEY_ESCAPE:frontend.escape();get_viewport().set_input_as_handled()
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
	refresh_orders()
	var h: ArenaHero=game.hero
	if not is_instance_valid(h): return
	hero_badge.tooltip_text="英雄养成 Lv."+str(h.meta_level)
	if not game.defense_rules: hero_badge.tooltip_text+=" · 本局成长 Lv."+str(h.level)
	hero_health.max_value=h.max_health;hero_health.value=h.health;hero_health.tooltip_text=str(int(h.health))+" / "+str(int(h.max_health))
	if h.conditions!=null:
		hero_health.low_threshold=h.conditions.hero_hp_threshold()
		hero_health.full_threshold=h.conditions.rank("fresh")>0 or h.conditions.rank("composure")>0
		hero_health.step_thresholds=h.conditions.rank("bloodprice")>0
	hero_level.text="Lv."+str(h.meta_level if game.defense_rules else h.level)
	if not game.defense_rules:
		experience.max_value=h.xp_target;experience.value=h.xp;xp_label.text=str(h.xp)+" / "+str(h.xp_target)
	core_health.max_value=game.core_max;core_health.value=game.core_health;core_health.tooltip_text=str(int(game.core_health))+" / "+str(int(game.core_max))
	coins.text=str(game.gold);revival.text=str(int(ceil(h.revive_clock))) if h.knocked_out else "";hero_badge.modulate=Color(0.6,0.6,0.6) if h.knocked_out else Color.WHITE
	for slot in range(2):
		var unlocked:=h.skill_unlocked(slot)
		skills[slot].disabled=not unlocked or h.knocked_out or h.cooldowns[slot]>0 or game.game_over
		skills[slot].text=(str(int(ceil(h.cooldowns[slot]))) if h.cooldowns[slot]>0 else "") if unlocked else str(2 if slot==0 else 4)+"级"
		skills[slot].tooltip_text=(str(h.data.small if slot==0 else h.data.ultimate)+"\n"+ArenaDefinitions.skill_text(h.class_id,slot)) if unlocked else "英雄养成至"+str(2 if slot==0 else 4)+"级解锁"
		var maximum: float=float(h.data.small_cd if slot==0 else h.data.ultimate_cd)*h.cooldown_scale()
		skill_glyphs[slot].progress=1.0-h.cooldowns[slot]/maximum if unlocked else 0.0;skill_glyphs[slot].modulate.a=0.18 if not unlocked else (0.45 if h.cooldowns[slot]>0 else 1.0);skill_glyphs[slot].queue_redraw()
	if is_instance_valid(dodge_button):
		dodge_button.disabled=h.knocked_out or h.dodge_cooldown>0.0 or h.debuff_stun_clock>0.0 or game.game_over
		dodge_button.text=str(int(ceil(h.dodge_cooldown))) if h.dodge_cooldown>0.0 else ""
		dodge_glyph.progress=1.0-clampf(h.dodge_cooldown/h.DODGE_CD,0.0,1.0)
		dodge_glyph.modulate.a=0.42 if h.dodge_cooldown>0.0 else 1.0
		dodge_glyph.queue_redraw()
	if is_instance_valid(hero_debuff_box):
		var d_items: Array[Dictionary] = h.active_debuffs()
		var d_sig := ""
		for it in d_items:
			d_sig += str(it.id) + ":" + str(int(ceil(float(it.time)))) + ";"
		if d_sig != _last_debuff_sig:
			_last_debuff_sig = d_sig
			clear_children(hero_debuff_box)
			hero_debuff_box.visible = not d_items.is_empty()
			for it in d_items:
				var chip := Panel.new()
				chip.custom_minimum_size = Vector2(68, 22)
				chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var st := StyleBoxFlat.new()
				st.bg_color = Color(0.11, 0.16, 0.22, 0.90)
				st.border_color = Color(it.color)
				st.set_border_width_all(1)
				st.set_corner_radius_all(5)
				chip.add_theme_stylebox_override("panel", st)
				var txt := str(it.label) if str(it.id) == "stun" else "%s %ds" % [str(it.label), maxi(1, int(ceil(float(it.time))))]
				var lbl := label(chip, txt, Rect2(2, 1, 64, 20), 11, Color(it.color))
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				hero_debuff_box.add_child(chip)
	if is_instance_valid(boss_bar_panel):
		var active_b: ArenaEnemy = game.active_boss() if game.has_method("active_boss") else null
		if is_instance_valid(active_b) and not active_b.dead:
			boss_bar_panel.show()
			if _last_boss_kind != active_b.kind:
				_last_boss_kind = active_b.kind
				boss_portrait.texture = ArenaMenuArt.creature(active_b.kind)
			var tier_lbl := "关底首领" if active_b.is_boss() else "小首领"
			var phase_lbl := ""
			if active_b.kind == "two_headed_troll" and active_b.boss_phase >= 1:
				phase_lbl = " · 绝境狂化" if active_b.boss_phase >= 2 else " · 双头暴怒"
			elif active_b.kind == "colossus" and active_b.boss_phase >= 1:
				phase_lbl = " · 过载" if active_b.boss_phase >= 2 else " · 护盾"
			boss_title.text = "%s · %s%s" % [str(active_b.data.name), tier_lbl, phase_lbl]
			boss_meter.max_value = active_b.max_health
			boss_meter.value = active_b.health
			boss_hp_text.text = "%d / %d" % [int(ceil(active_b.health)), int(ceil(active_b.max_health))]
			var show_ticks := active_b.kind in ["two_headed_troll","colossus","moth"]
			for t_node in boss_ticks:
				t_node.visible = show_ticks
		else:
			boss_bar_panel.hide()
	if is_instance_valid(resonance_button) and game.keystone_mode:
		var r_ready:=game.resonance>=100.0 and not h.knocked_out and not game.game_over
		resonance_button.disabled=not r_ready
		resonance_meter.max_value=100.0;resonance_meter.value=game.resonance
		resonance_label.text="★ 就绪" if r_ready else "%d%%"%int(game.resonance)
		resonance_label.modulate=Color("9eeeff") if r_ready else CREAM
	if is_instance_valid(bridge_button) and not game.bridge_gate_config.is_empty():
		var b_ready:=not game.bridge_sealed and game.bridge_cooldown<=0.0 and not game.game_over and not (game.phase!="rest" and game.orders.has("fixed_bridge"))
		bridge_button.position=game.world_to_hud(game.bridge_gate_point())+Vector2(-22,36)
		bridge_button.visible=Rect2(0,80,1556,760).has_point(bridge_button.position)
		bridge_button.disabled=not b_ready
		bridge_meter.max_value=game.BRIDGE_SEAL_DURATION if game.bridge_sealed else game.BRIDGE_COOLDOWN_DURATION
		bridge_meter.value=game.bridge_active_clock if game.bridge_sealed else (game.BRIDGE_COOLDOWN_DURATION-game.bridge_cooldown)
		bridge_label.text=("封锁 %ds"%int(ceil(game.bridge_active_clock))) if game.bridge_sealed else (("CD %ds"%int(ceil(game.bridge_cooldown))) if game.bridge_cooldown>0.0 else "★ 就绪")
		bridge_label.modulate=Color("7fe8ff") if game.bridge_sealed else (GOLD if b_ready else MUTED)
	if context.visible and game.selected_site>=0:
		var anchor:=game.world_to_hud(game.level_definition.sites[game.selected_site])
		context.position=Vector2(clampf(anchor.x-context.size.x*0.5,12,1588-context.size.x),clampf(anchor.y+38,86,885-context.size.y))
	var total_w := game.total_waves()
	wave_label.text=str(game.cycle)+" / "+str(total_w);wave_button.disabled=game.phase!="rest" or game.game_over
	if is_instance_valid(breach_notice) and game.siege!=null:breach_notice.visible=game.siege.warned and (not game.siege.opened or game.siege.warning_clock>0.0)
	phase_label.text=("整备 · "+str(int(ceil(game.phase_clock)))+" 秒" if game.phase=="rest" else "敌军来袭")
	var wave_data:=game.wave_pattern()
	var lead:=int(wave_data.get("lead",0));lead=maxi(0,lead)
	var entry: Vector2=game.world_to_hud(game.level_definition.routes[lead][0])
	var button_pos:=Vector2(clampf(entry.x,20,1530),clampf(entry.y,94,770))
	var defense_visible:=game.can_manage_defense()
	wave_button.position=button_pos;wave_button.visible=game.phase=="rest" and not game.game_over and defense_visible
	wave_button.tooltip_text="%d / %d · %ds\n预览后再点提前开波"%[game.cycle,total_w,maxi(0,int(ceil(game.phase_clock)))]
	wave_glyph.progress=game.phase_clock/game.rest_duration if game.phase=="rest" else 1.0;wave_glyph.tint=GOLD if game.wave_preview else CREAM;wave_glyph.queue_redraw()
	refresh_objective()
	var show_preview: bool=game.wave_preview and defense_visible
	if preview.visible!=show_preview:
		preview.visible=show_preview
		if preview.visible:
			clear_children(preview)
			var pool: Array=[]
			for group in wave_data.units:
				if group[0] not in pool:pool.append(group[0])
			if game.cycle==total_w and game.level_definition.boss and not game.level_definition.get("boss_in_wave",false):pool.append(str(game.level_definition.get("boss_kind","moth")))
			var profile:=ArenaLevelCatalog.wave_profile(game.level_id,game.cycle,wave_data)
			var tag_txt := str(profile.get("tag",""))
			var has_fly := bool(profile.get("has_flying",false))
			var pw := maxi(308, 16 + mini(6, pool.size()) * 61)
			var ph := 124 if (tag_txt != "" or has_fly) else 104
			preview.size = Vector2(pw, ph)
			for index in range(mini(6, pool.size())):
				var eid := str(pool[index])
				var artwork := ArenaMenuArt.creature(eid)
				if artwork!=null:
					var img := image(preview,artwork,Rect2(8+index*61,6,56,56))
					img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					img.mouse_filter = Control.MOUSE_FILTER_PASS
					var edata := ArenaDefinitions.enemy(eid)
					var etrait := str(edata.get("trait",""))
					img.tooltip_text = str(edata.name) + ("\n" + etrait if etrait != "" else "")
			label(preview,"重甲 %d%% · 高法抗 %d%% · 精英 %d" % [int(round(profile.heavy*100.0)),int(round(profile.high_res*100.0)),int(profile.elites)],Rect2(10,68,pw-20,24),14,MUTED)
			if tag_txt != "" or has_fly:
				var note := (tag_txt + (" · " if tag_txt != "" and has_fly else "")) + ("⚠ 含飞行单位 · 需防空" if has_fly else "")
				var note_col := Color("f5cd6a") if (bool(profile.get("has_boss",false)) or bool(profile.get("has_mini_boss",false))) else (Color("7be0ff") if has_fly else Color("ffa868"))
				label(preview,note,Rect2(10,94,pw-20,22),13,note_col)
	preview.position=Vector2(clampf(button_pos.x+54,12,1588-preview.size.x),clampf(button_pos.y,86,888-preview.size.y))
