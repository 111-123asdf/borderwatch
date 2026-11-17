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
var resonance_button: Button
var resonance_meter: ArenaMeter
var resonance_label: Label
var bridge_button: Button
var bridge_meter: ArenaMeter
var bridge_label: Label
var breach_notice: Button
var battle_nodes: Array=[]
var update_clock:=0.0
var selected_hero: String="knight"
var frontend: ArenaFrontEnd
const CREAM:=Color("f2e4c5")
const GOLD:=Color("f3cc65")
const MUTED:=Color("b6c0cb")
const INK:=Color("121e2c")
const COPPER:=Color("b88943")
const PANEL:=Color("1d2a38f2")
var codex: ArenaPerkCodex
var codex_was_paused:=false
const AXIS_NAME:={"blade":"锋刃","star":"星火","bulwark":"壁垒","command":"号令","evo":"进化","knight":"骑士","ranger":"游侠","mage":"法师","bridge":"桥接"}
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
	var bg:=StyleBoxFlat.new();bg.bg_color=Color("14202b");bg.border_color=Color("0b131c");bg.set_border_width_all(1);bg.set_corner_radius_all(4)
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
	for node in battle_nodes:
		if is_instance_valid(node):node.queue_free()
	battle_nodes.clear();skills.clear();skill_glyphs.clear()
	var hero_pod:=Panel.new();hero_pod.name="HeroPod";hero_pod.position=Vector2(12,10);hero_pod.size=Vector2(294,58);hero_pod.mouse_filter=Control.MOUSE_FILTER_IGNORE;pod_style(hero_pod);root.add_child(hero_pod);battle_nodes.append(hero_pod)
	hero_badge=image(hero_pod,hero_badge_image(game.hero.class_id),Rect2(4,3,48,50))
	revival=label(hero_pod,"",Rect2(8,13,40,30),20,GOLD)
	hero_health=meter(hero_pod,Rect2(58,12,124,12),Color("d87d73"));experience=meter(hero_pod,Rect2(58,34,124,5),Color("c6d899"))
	hero_level=label(hero_pod,"1",Rect2(58,41,28,14),10,MUTED)
	xp_label=label(hero_pod,"",Rect2(88,41,92,14),10,MUTED);xp_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	icon(hero_pod,"coin",Rect2(193,12,23,23));coins=label(hero_pod,str(game.gold),Rect2(219,11,66,27),19,GOLD)
	token_glyph=icon(hero_pod,"upgrade",Rect2(213,40,12,12));tokens=label(hero_pod,"",Rect2(230,39,44,15),11,GOLD)
	var core_pod:=Panel.new();core_pod.name="CorePod";core_pod.position=Vector2(1378,10);core_pod.size=Vector2(210,48);core_pod.mouse_filter=Control.MOUSE_FILTER_IGNORE;pod_style(core_pod);root.add_child(core_pod);battle_nodes.append(core_pod)
	icon(core_pod,"core",Rect2(8,9,23,28),Color("a0d9cd"));core_health=meter(core_pod,Rect2(40,19,110,10),Color("79c69d"))
	var pause_button:=button(core_pod,"Ⅱ",Rect2(158,2,48,44),show_pause);pause_button.name="Pause";pause_button.tooltip_text="暂停 · Esc"
	if game.world_size().x>1600:
		var overview:=button(root,"",Rect2(1324,12,44,44),game.camera.toggle_overview);overview.name="Overview";overview.tooltip_text="M 全图 / 近景；中键拖动或边缘移动镜头；C 定位英雄";icon(overview,"overview",Rect2(8,8,28,28));battle_nodes.append(overview)
		var focus:=button(root,"",Rect2(314,12,44,44),func():game.camera.focus(game.hero.position));focus.name="FocusHero";focus.tooltip_text="定位英雄 · C";icon(focus,"target",Rect2(8,8,28,28));battle_nodes.append(focus)
		breach_notice=button(root,"",Rect2(1324,64,44,44),func():game.camera.focus(game.siege.point()));breach_notice.name="BreachAlert";breach_notice.tooltip_text="东北破障：击败蓄力中的破障者可延缓至下一波。点击定位。";icon(breach_notice,"wave",Rect2(8,8,28,28),GOLD);breach_notice.hide();battle_nodes.append(breach_notice)
	wave_label=label(root,"1 / 8",Rect2(1515,64,66,20),13,CREAM);wave_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;battle_nodes.append(wave_label)
	phase_label=label(root,"",Rect2(0,0,1,1),10);phase_label.hide();battle_nodes.append(phase_label)
	debuff=label(root,"",Rect2(1408,63,100,20),11,Color("f08c75"));battle_nodes.append(debuff)
	wave_button=button(root,"",Rect2(0,0,48,48),game.request_wave);wave_button.name="CallWave";wave_button.tooltip_text="预览下一波；再点提前开始";battle_nodes.append(wave_button)
	wave_glyph=icon(wave_button,"wave",Rect2(7,7,34,34))
	var skill_dock:=Control.new();skill_dock.position=Vector2(12,818);skill_dock.size=Vector2(220,70);skill_dock.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(skill_dock);battle_nodes.append(skill_dock)
	for slot in range(2):
		var b:=button(skill_dock,"",Rect2(slot*64,4,58,62),game.request_skill.bind(slot));b.name="Skill_"+str(slot);skills.append(b)
		var kind: String={"knight":["physical","flag"],"ranger":["move","rain"],"mage":["frost","meteor"]}[game.hero.class_id][slot]
		var glyph:=icon(b,kind,Rect2(4,3,48,48),ArenaCombat.colour(game.hero.data.type));skill_glyphs.append(glyph)
		image(glyph,ArenaMenuArt.skill(game.hero.class_id,slot),Rect2(4,3,42,42))
		keycap(b,"Q" if slot==0 else "E",Rect2(35,40,20,18));b.tooltip_text=ArenaDefinitions.skill_text(game.hero.class_id,slot)
	resonance_button=null;resonance_meter=null;resonance_label=null
	if game.keystone_mode:
		resonance_button=button(skill_dock,"",Rect2(128,4,58,62),game.request_skill.bind(2));resonance_button.name="Resonance";resonance_button.tooltip_text="共鸣斩 · R：充满后选点释放，破盾并引动附近塔齐射"
		icon(resonance_button,"meteor",Rect2(9,3,40,40),Color("9ccdd8"));resonance_meter=meter(resonance_button,Rect2(6,54,46,3),Color("9ccdd8"));resonance_label=label(resonance_button,"",Rect2(0,0,1,1),10);resonance_label.hide();keycap(resonance_button,"R",Rect2(35,40,20,18))
	bridge_button=null;bridge_meter=null;bridge_label=null
	if not game.bridge_gate_config.is_empty():
		bridge_button=button(root,"",Rect2(game.bridge_gate_point()+Vector2(-22,36),Vector2(44,44)),game.trigger_bridge_gate);bridge_button.name="BridgeGate";bridge_button.tooltip_text="吊桥 · G：封锁14秒。未到岔路的敌军绕行，已选路单位继续通过。冷却28秒。";battle_nodes.append(bridge_button)
		icon(bridge_button,"flag",Rect2(8,6,26,26),GOLD);keycap(bridge_button,"G",Rect2(25,24,17,17));bridge_meter=meter(bridge_button,Rect2(4,39,36,3),GOLD);bridge_label=label(bridge_button,"",Rect2(0,0,1,1),10);bridge_label.hide()
	preview=Panel.new();preview.size=Vector2(300,102);preview.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel_style(preview);preview.hide();root.add_child(preview);battle_nodes.append(preview)
	objective=Panel.new();objective.position=Vector2(660,835);objective.size=Vector2(280,46);objective.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(objective);pod_style(objective);battle_nodes.append(objective)
	objective_step=label(objective,"",Rect2(0,0,1,1),10);objective_step.hide();objective_title=label(objective,"",Rect2(12,9,258,26),14,CREAM);objective_body=label(objective,"",Rect2(0,0,1,1),10);objective_body.hide()
	var build:=Control.new();build.hide();root.add_child(build);battle_nodes.append(build);build_label=label(build,"",Rect2(0,0,1,1),10)
	root.move_child(context,root.get_child_count()-1)
func show_context(index: int) -> void:
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
	if game.selected_site<0:return
	clear_children(context);context.show()
	var tower: ArenaTower=game.site_tower(game.selected_site)
	if tower!=null and tower.awaiting_doctrine:
		doctrine_context(tower);return
	var locked:=tower==null and game.site_locked(game.selected_site)
	var has_doctrine:=tower!=null and tower.doctrine_id!=""
	context.size=Vector2(328,154) if locked else (Vector2(372,172) if tower==null else (Vector2(442,270) if has_doctrine else Vector2(316,228)))
	var point: Vector2=game.world_to_hud(game.level_definition.sites[game.selected_site])
	context.position=Vector2(clampf(point.x-context.size.x*0.5,12,1600-context.size.x-12),clampf(point.y+38,86,900-context.size.y-15))
	var traits: Array=game.level_definition.get("site_traits",[])
	var site_trait: String=str(traits[game.selected_site]) if game.selected_site<traits.size() else ""
	var trait_name: String=ArenaTower.trait_label(site_trait)
	var trait_desc: String=ArenaTower.trait_summary(site_trait)
	var trait_tint: Color={"highground":Color("f6c862"),"choke":Color("ee7b56"),"conduit":Color("6ce8ff")}.get(site_trait,GOLD)
	var roles: Array=game.level_definition.get("site_roles",[])
	var role_name: String=str(roles[game.selected_site]) if game.selected_site<roles.size() else ""
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
			var key: String=game.run_towers[column];var data: Dictionary=ArenaDefinitions.TOWERS[key]
			var b:=button(context,"",Rect2(14+column*86,44,80,108),_build.bind(key));b.name="Build_"+key;b.disabled=key not in game.available_towers() or game.gold<int(data.cost)
			image(b,tower_image(key),Rect2(5,2,70,70));icon(b,"coin",Rect2(12,79,18,18));label(b,str(data.cost),Rect2(34,78,42,22),16,GOLD)
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
			btn.disabled=maxed or game.gold<b_price
			var accent_tint:=Color("f5cd6a") if b==0 else Color("7fd8ff")
			label(btn,str(b_info.name),Rect2(12,8,136,24),16,accent_tint)
			label(btn,str(rank)+"/3",Rect2(150,9,40,22),15,accent_tint).horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
			var desc:=label(btn,str(b_info.summary),Rect2(12,36,178,52),12,CREAM);desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
			var price_text:="✓ 已满阶" if maxed else ("↑  %d ◉"%b_price)
			var price_tint:=Color("9ee4a8") if maxed else (GOLD if game.gold>=b_price else Color("e7a28a"))
			label(btn,price_text,Rect2(12,92,178,24),15,price_tint).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		var target:=button(context,"⚑ 集结" if tower.kind=="barracks" else "◎ 目标",Rect2(14,214,126,42),_rally if tower.kind=="barracks" else _target)
		target.tooltip_text="调整集结点" if tower.kind=="barracks" else "切换优先目标"
		button(context,"出售",Rect2(154,214,148,42),tower.sell)
		button(context,"×",Rect2(316,214,110,42),close_context)
	else:
		label(context,str(tower.data.name)+"  "+str(tower.level)+"/3",Rect2(18,12,160,30),21,GOLD)
		_trait_badge(context,site_trait,trait_name,trait_desc,trait_tint,Rect2(216,12,84,26))
		icon(context,"physical" if tower.data.type==0 else "magic",Rect2(18,48,22,22),ArenaCombat.colour(tower.data.type));label(context,ArenaCombat.label(tower.data.type)+" · "+str(tower.data.description),Rect2(48,46,252,26),14,MUTED)
		var price:=tower.upgrade_price();var token:=game.doctrine_tokens>0 and tower.level==2
		var caption: String="免费 L3 改造（剩 %d）"%game.doctrine_tokens if token else "↑    %d  ◉"%price
		var up:=button(context,caption,Rect2(16,88,284,46),tower.upgrade.bind("",true) if token else tower.upgrade,true)
		up.name="Upgrade";up.disabled=tower.level>=3 or (not token and game.gold<price)
		var target:=button(context,"⚑" if tower.kind=="barracks" else "◎",Rect2(16,150,84,44),_rally if tower.kind=="barracks" else _target);target.tooltip_text="调整集结点" if tower.kind=="barracks" else "切换优先目标"
		button(context,"出售",Rect2(114,150,90,44),tower.sell)
		button(context,"×",Rect2(218,150,82,44),close_context)
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
func _rally() -> void:game.rally_site=game.selected_site;close_context()
func _target() -> void:
	var tower:=game.site_tower(game.selected_site)
	if tower!=null and tower.forced_target()=="":
		tower.target_mode="strongest" if tower.target_mode=="first" else "first";refresh_context()
func close_context() -> void:context.hide();game.selected_site=-1
func refresh_tokens() -> void:
	if not is_instance_valid(tokens):return
	tokens.text=("×%d"%game.doctrine_tokens) if game.doctrine_tokens>0 else ""
	if is_instance_valid(token_glyph):token_glyph.modulate.a=1.0 if game.doctrine_tokens>0 else 0.25
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
	for i in range(unlocked.size()):image(unlock_hint,tower_image(unlocked[i]),Rect2(45+i*66,4,64,64))
func modal_panel(size: Vector2) -> Panel:
	close_modal();modal=Control.new();modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.mouse_filter=Control.MOUSE_FILTER_STOP;root.add_child(modal)
	var veil:=ColorRect.new();veil.color=Color(0.05,0.08,0.12,0.72);veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);modal.add_child(veil)
	var panel:=Panel.new();panel.size=size;panel.position=(Vector2(1600,900)-size)*0.5;modal.add_child(panel);panel_style(panel);return panel
func close_modal() -> void:
	if is_instance_valid(modal):root.remove_child(modal);modal.queue_free()
	modal=null
func has_modal() -> bool:return is_instance_valid(modal) or is_instance_valid(codex)
func show_choices(keys: Array[String]) -> void:
	close_context();game.targeting_slot=-1;game.rally_site=-1
	var panel:=modal_panel(Vector2(1060,510))
	var head:=label(panel,"★ 觉醒抉择 · 三选一",Rect2(40,22,980,44),28,GOLD);head.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var sub:=label(panel,"仅于关键节点（Lv.2 / Lv.5 / Lv.8）与营地触发 · 直赋满阶觉醒威力",Rect2(40,66,980,26),15,MUTED);sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
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
func show_camp_reward(id: int) -> void:
	close_context();get_tree().paused=true
	var panel:=modal_panel(Vector2(1060,478))
	var head:=label(panel,"营地已清 · 三选一",Rect2(40,22,980,44),28,GOLD);head.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var sub:=label(panel,"选择一项战利品带回防线",Rect2(40,66,980,26),15,MUTED);sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var l2:=game.l2_count()
	var hero_opt: Dictionary={"key":"hero","icon":"star","title":"星界祈愿","body":"立即为英雄提供 +160 经验与 40% 生命回复，并为守护祭坛与星界共鸣 +35% 充能。","foot":"当前共鸣 %d%%"%int(game.resonance)} if game.keystone_mode else {"key":"hero","icon":"star","title":"英雄觉醒","body":"立即开启一次英雄满阶觉醒三选一，强化本局战力与羁绊联动。","foot":"当前英雄 Lv.%d"%game.hero.level}
	var options: Array=[
		hero_opt,
		{"key":"token","icon":"shield","title":"防线秘券","body":"获得 1 枚免费三级改造券（本局保留），可免费将任意 2 级塔升至 3 阶流派。","foot":"当前二级塔 %d 座%s"%[l2,"" if l2>0 else " · 可留后用"]},
		{"key":"gold","icon":"coin","title":"军备金库","body":"立即获得 100 金币，用于快速建造新塔、升级流派或点满双分支。","foot":"当前金币 %d"%game.gold}]
	for index in range(options.size()):
		var option: Dictionary=options[index]
		var card:=button(panel,"",Rect2(34+index*340,104,312,338),game.choose_camp_reward.bind(id,str(option.key)))
		card.name="CampReward_"+str(option.key)
		keycap(card,str(index+1),Rect2(14,12,28,24))
		var plate:=sub_card(card,Rect2(14,44,284,234),true)
		image(plate,ArenaMenuArt.utility(str(option.icon)),Rect2(114,16,56,56))
		label(plate,str(option.title),Rect2(16,80,252,34),24,ArenaMenuArt.PAPER).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		colour_block(plate,Rect2(28,118,228,1),Color(ArenaMenuArt.PAPER_MUTED,0.35))
		var body:=label(plate,str(option.body),Rect2(20,130,244,92),15,ArenaMenuArt.PAPER);body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label(card,str(option.foot),Rect2(16,292,280,28),14,Color("9ee4a8")).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
func show_pause() -> void:
	if game.choice_open or game.camp_reward_open or game.game_over:return
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
	var right:=sub_card(panel,Rect2(438,90,394,364),true)
	label(right,"防线规则 · 本局构筑",Rect2(30,18,334,26),19,ArenaMenuArt.PAPER)
	var rule_text: String="• 三路合围 + 第4波东北破障；[G] 吊桥分流改道\n• 高台+射程 · 隘口强兵营 · 脉座+攻速穿透\n• 战斗零打断！第 2/4/6 波后整备三选一质变秘石" if game.keystone_mode else "• L3 转职后可同修双分支（最高 10 阶）\n• 物理克轻甲、法术破重甲；英雄 15 秒复活\n• Lv.2 / Lv.5 / Lv.8 触发满阶觉醒三选一"
	var rules:=label(right,rule_text,Rect2(26,48,342,68),13,ArenaMenuArt.PAPER_MUTED);rules.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	colour_block(right,Rect2(26,124,342,1),Color(ArenaMenuArt.PAPER_MUTED,0.3))
	if game.keystone_mode:
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
			var none:=label(right,"尚未觉醒被动\n升至 Lv.2 / Lv.5 / Lv.8 或清理营地可获得满阶成长卡",Rect2(22,188,350,80),14,ArenaMenuArt.PAPER_MUTED);none.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		else:
			for i in range(mini(owned.size(),6)):
				var pk:=owned[i];var pcard: Dictionary=ArenaPerks.card(pk)
				var cx:=22+(i%2)*178;var cy:=174+int(i/2)*56
				var ptex:=ArenaMenuArt.perk(pk)
				if ptex!=null:image(right,ptex,Rect2(cx,cy,44,44))
				label(right,str(pcard.get("name",pk)),Rect2(cx+50,cy+4,122,22),15,ArenaMenuArt.PAPER)
				label(right,"★ 已觉醒" if bool(game.hero.awakened_perks.get(pk,false)) else "Lv."+str(game.hero.perk(pk)),Rect2(cx+50,cy+26,122,18),12,Color("7a4c14"))
	var codex_button:=button(panel,"被动图鉴",Rect2(28,472,232,52),show_codex);codex_button.name="被动图鉴";ArenaMenuArt.accent(codex_button,"blue")
	var go_btn:=button(panel,"继续守望",Rect2(294,472,272,52),resume,true);ArenaMenuArt.accent(go_btn,"green")
	var back_btn:=button(panel,"返回地图",Rect2(600,472,232,52),game.return_to_menu);ArenaMenuArt.accent(back_btn,"amber")
func resume() -> void:
	get_tree().paused=false;close_modal();game.suppress_primary=true
	game.pump_modals()
func show_guide() -> void:
	var panel:=modal_panel(Vector2(820,544))
	label(panel,"新任守望者指南",Rect2(30,22,760,42),28,GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var card:=sub_card(panel,Rect2(34,76,752,374),true)
	label(card,"1  部署防线",Rect2(28,22,150,28),18,Color("7a4c14"));label(card,"在金色塔位建塔与升级；L3 转职后可双分支冲至 10 阶。",Rect2(178,22,544,28),17,ArenaMenuArt.PAPER)
	label(card,"2  英雄出战",Rect2(28,76,150,28),18,Color("7a4c14"));label(card,"WASD/右键移动，左键普攻；养成至 2/4 级解锁 Q/E 技能。",Rect2(178,76,544,28),17,ArenaMenuArt.PAPER)
	label(card,"3  觉醒成长",Rect2(28,130,150,28),18,Color("7a4c14"));label(card,"每级瞬发回血爆气，Lv.2/5/8 及清营选满阶觉醒被动。",Rect2(178,130,544,28),17,ArenaMenuArt.PAPER)
	colour_block(card,Rect2(28,184,696,1),Color(ArenaMenuArt.PAPER_MUTED,0.35))
	label(card,"物理",Rect2(28,210,90,28),18,Color("8d5418"));label(card,"弓箭、火炮、骑士、游侠与士兵 · 适合清理轻甲与兽群",Rect2(140,210,580,28),17,ArenaMenuArt.PAPER)
	label(card,"法术",Rect2(28,254,90,28),18,Color("2e5d8f"));label(card,"法师与法师塔 · 穿透高护甲并施加强力控制",Rect2(140,254,580,28),17,ArenaMenuArt.PAPER)
	label(card,"提示：英雄倒下 15 秒后在信标处复活，唯有信标失守才会战败。",Rect2(28,314,696,28),16,ArenaMenuArt.PAPER_MUTED)
	var go:=button(panel,"开始守望",Rect2(250,468,320,52),close_modal,true);ArenaMenuArt.accent(go,"green")
func show_result() -> void:
	close_context();var panel:=modal_panel(Vector2(740,478))
	label(panel,"防线守住了" if game.victory else "信标失守",Rect2(30,24,680,50),34,GOLD).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	var card:=sub_card(panel,Rect2(34,86,672,286),true)
	label(card,"本局战报",Rect2(28,16,200,28),18,Color("7a4c14"));colour_block(card,Rect2(28,50,616,1),Color(ArenaMenuArt.PAPER_MUTED,0.35))
	label(card,"抵达波次",Rect2(28,70,150,24),14,ArenaMenuArt.PAPER_MUTED);label(card,str(game.cycle)+" / 8",Rect2(28,96,150,32),24,ArenaMenuArt.PAPER)
	label(card,"击败敌人",Rect2(246,70,150,24),14,ArenaMenuArt.PAPER_MUTED);label(card,str(game.kills),Rect2(246,96,150,32),24,ArenaMenuArt.PAPER)
	label(card,"英雄等级",Rect2(464,70,150,24),14,ArenaMenuArt.PAPER_MUTED);label(card,"Lv."+str(game.hero.level),Rect2(464,96,150,32),24,ArenaMenuArt.PAPER)
	label(card,"建造 "+str(game.built)+" 座防御塔   ·   清理营地 "+str(game.camps_cleared)+" / 2",Rect2(28,154,616,28),17,ArenaMenuArt.PAPER_MUTED)
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
	if game.camps_cleared<game.camps.size():
		if game.cycle<2:return {"step":"当前目标","title":"准备迎接营地威胁","body":"第2波营地激活；调度英雄，兼顾主路。"}
		if game.overdue_camps()>0:return {"step":"营地警报","title":"解除全场图腾压制","body":"清除营地守卫后，选择成长、改造券或金币。"}
		return {"step":"当前目标","title":"清理精英营地","body":"第4波威胁扩散，第5波派出突袭队；清营后三选一。"}
	if game.phase=="rest":return {"step":"整备阶段","title":"升级防线，准备第 "+str(game.cycle)+" 波","body":"利用金币升级塔；提前开波奖励至多12金币。"}
	return {"step":"防守阶段","title":"守住第 "+str(game.cycle)+" 波","body":"观察敌人抗性，英雄随时回防；基地失守才会失败。"}

func refresh_objective() -> void:
	if not is_instance_valid(objective):return
	if not tutorial_finished and game.built>0 and game.hero.shots>0 and game.phase!="rest":
		tutorial_finished=true;game.campaign.complete_tutorial()
	objective.visible=not tutorial_finished and not bool(game.campaign.data.get("tutorial_done",false)) and game.cycle==1 and game.built==0
	var state:=objective_state();var signature: String=str(state.step)+str(state.title)
	if signature!=last_objective:
		last_objective=signature;objective_step.text=state.step;objective_title.text=state.title;objective_body.text=state.body
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
	if is_instance_valid(resonance_button) and game.keystone_mode:
		var r_ready:=game.resonance>=100.0 and not h.knocked_out and not game.game_over
		resonance_button.disabled=not r_ready
		resonance_meter.max_value=100.0;resonance_meter.value=game.resonance
		resonance_label.text="★ 就绪" if r_ready else "%d%%"%int(game.resonance)
		resonance_label.modulate=Color("9eeeff") if r_ready else CREAM
	if is_instance_valid(bridge_button) and not game.bridge_gate_config.is_empty():
		var b_ready:=not game.bridge_sealed and game.bridge_cooldown<=0.0 and not game.game_over
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
	wave_label.text=str(game.cycle)+" / 8";wave_button.disabled=game.phase!="rest" or game.game_over
	if is_instance_valid(breach_notice) and game.siege!=null:breach_notice.visible=game.siege.warned and (not game.siege.opened or game.siege.warning_clock>0.0)
	phase_label.text=("整备 · "+str(int(ceil(game.phase_clock)))+" 秒" if game.phase=="rest" else "敌军来袭")
	var wave_data:=ArenaLevelCatalog.wave(game.level_id,game.cycle)
	var lead:=int(wave_data.get("lead",0));lead=maxi(0,lead)
	var entry: Vector2=game.world_to_hud(game.level_definition.routes[lead][0])
	var button_pos:=Vector2(clampf(entry.x,20,1530),clampf(entry.y,94,770))
	wave_button.position=button_pos;wave_button.visible=game.phase=="rest" and not game.game_over
	preview.position=Vector2(clampf(button_pos.x+54,12,1288),clampf(button_pos.y,86,700))
	wave_button.tooltip_text="%d / 8 · %ds\n预览后再点提前开波"%[game.cycle,maxi(0,int(ceil(game.phase_clock)))]
	wave_glyph.progress=game.phase_clock/game.rest_duration if game.phase=="rest" else 1.0;wave_glyph.tint=GOLD if game.wave_preview else CREAM;wave_glyph.queue_redraw()
	refresh_objective()
	if preview.visible!=game.wave_preview:
		preview.visible=game.wave_preview
		if preview.visible:
			clear_children(preview)
			var pool: Array=[]
			for group in ArenaLevelCatalog.wave(game.level_id,game.cycle).units:pool.append(group[0])
			if game.cycle==8 and game.level_definition.boss:pool.append(str(game.level_definition.get("boss_kind","moth")))
			for index in range(pool.size()):
				var path: String=ArenaCreature.sheet_path(str(pool[index]))
				if ResourceLoader.exists(path):
					var sheet: Texture2D=load(path);var frame:=AtlasTexture.new();frame.atlas=sheet;frame.region=Rect2(0,0,sheet.get_width()/6.0,sheet.get_height()/3.0);image(preview,frame,Rect2(8+index*61,5,58,62))
			var profile:=ArenaLevelCatalog.wave_profile(game.level_id,game.cycle)
			label(preview,"重甲 %d%% · 高法抗 %d%% · 精英 %d" % [int(round(profile.heavy*100.0)),int(round(profile.high_res*100.0)),int(profile.elites)],Rect2(10,72,300,26),14,MUTED)
