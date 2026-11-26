class_name ArenaHUD
extends CanvasLayer

class _AlarmVignette:
	extends Control
	var intensity := 0.0
	var critical := false
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		if intensity <= 0.01:
			return
		var sz := size
		var col := Color(0.95, 0.14, 0.18, intensity * (0.48 if critical else 0.30))
		var edge := 46.0 if critical else 28.0
		for i in range(4):
			var frac := 1.0 - float(i) * 0.25
			var c := Color(col.r, col.g, col.b, col.a * frac * 0.45)
			var w := edge * (1.0 - float(i) * 0.22)
			draw_rect(Rect2(0, 0, sz.x, w), c)
			draw_rect(Rect2(0, sz.y - w, sz.x, w), c)
			draw_rect(Rect2(0, w, w, sz.y - w * 2.0), c)
			draw_rect(Rect2(sz.x - w, w, w, sz.y - w * 2.0), c)

class _RiftMinimap:
	extends Panel
	var game: ArenaGame
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		if game == null or game.rift_domain == null or game.active_domain != "rift":
			return
		var rd := game.rift_domain
		var gb: Rect2i = rd.grid_bounds
		var span_c := maxi(2, gb.size.x)
		var span_r := maxi(2, gb.size.y)
		var pad_rect := Rect2(14.0, 32.0, 190.0, 140.0)
		var gap := Vector2(10.0, 8.0)
		var cw := clampf((pad_rect.size.x - gap.x * float(span_c - 1)) / float(span_c), 24.0, 44.0)
		var ch := clampf((pad_rect.size.y - gap.y * float(span_r - 1)) / float(span_r), 18.0, 30.0)
		var cell := Vector2(cw, ch)
		var used_w := cw * float(span_c) + gap.x * float(span_c - 1)
		var used_h := ch * float(span_r) + gap.y * float(span_r - 1)
		var orig := Vector2(pad_rect.position.x + (pad_rect.size.x - used_w) * 0.5, pad_rect.position.y + (pad_rect.size.y - used_h) * 0.5)

		# Draw connecting corridors
		for c: Dictionary in rd.corridors:
			var ra: Dictionary = rd.rooms[c.a]
			var rb: Dictionary = rd.rooms[c.b]
			if str(ra.state) == "hidden" or str(rb.state) == "hidden":
				continue
			var pa := orig + Vector2(float(int(ra.col) - gb.position.x) * (cw + gap.x), float(int(ra.row) - gb.position.y) * (ch + gap.y)) + cell * 0.5
			var pb := orig + Vector2(float(int(rb.col) - gb.position.x) * (cw + gap.x), float(int(rb.row) - gb.position.y) * (ch + gap.y)) + cell * 0.5
			draw_line(pa, pb, Color("3c6478"), 3.5)

		# Draw procedural room nodes
		for rid: String in rd.room_order:
			var rm: Dictionary = rd.rooms[rid]
			var st := str(rm.state)
			if st == "hidden":
				continue
			var lx := float(int(rm.col) - gb.position.x)
			var ly := float(int(rm.row) - gb.position.y)
			var pos := orig + Vector2(lx * (cw + gap.x), ly * (ch + gap.y))
			var rk := str(rm.kind)
			var fill_c := Color("193a32") if st == "cleared" else (Color("4e1c28") if st == "locked_combat" else Color("172838"))
			var border_c := Color("ffe678") if (rk == "boss" and rd.descent_gate_active) else (Color("d478ff") if rk == "event" else (Color("6ef0a4") if st == "cleared" else (Color("ff5c6e") if st == "locked_combat" else Color("68c8e8"))))
			draw_rect(Rect2(pos, cell), fill_c)
			draw_rect(Rect2(pos, cell), border_c, false, 1.5)
			var sym := "⌂" if rk == "hub" else ("▼" if (rk == "boss" and rd.descent_gate_active) else ("♛" if rk == "boss" else ("☠" if rk == "miniboss" else ("★" if rk == "chest" else ("?" if rk == "event" else ("✓" if st == "cleared" else "⚔"))))))
			var tc := Color("ffe878") if rk in ["chest", "boss", "miniboss"] else (Color("e096ff") if rk == "event" else border_c)
			draw_string(ThemeDB.fallback_font, pos + Vector2(cw * 0.5 - 5.5, ch * 0.5 + 4.5), sym, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tc)
			var mut_id := str(rm.get("mutator", "none"))
			if mut_id != "none":
				var mc: Color = Color(ArenaRiftPCG.MUTATORS.get(mut_id, {}).get("color", Color.WHITE))
				draw_circle(pos + Vector2(cw - 4.0, 4.0), 2.5, mc)

		# Draw hero live dot mapped cleanly inside dynamic grid
		if is_instance_valid(game.hero):
			var local_h := game.hero.position - ArenaRiftDomain.RIFT_ORIGIN - ArenaRiftPCG.GRID_MARGIN
			var gx := clampf(local_h.x / ArenaRiftPCG.CELL_STEP.x - float(gb.position.x), -0.35, float(span_c) - 0.65)
			var gy := clampf(local_h.y / ArenaRiftPCG.CELL_STEP.y - float(gb.position.y), -0.35, float(span_r) - 0.65)
			var h_pt := orig + Vector2(gx * (cw + gap.x), gy * (ch + gap.y)) + cell * 0.5
			var pulse := 0.88 if bool(game.campaign.data.reduced_motion) else 0.75 + 0.25 * sin(float(Time.get_ticks_msec()) * 0.012)
			draw_circle(h_pt, 5.0, Color(0.08, 0.12, 0.16, 0.92))
			draw_circle(h_pt, 3.5 * pulse, Color("ffe97a"))

var game: ArenaGame
var root: Control
var menu: Control
var modal: Control
var _modal_return_focus: Control
var _leave_confirmation: Panel
var context: Panel
var order_hint: Panel
var order_label: Label
var order_notice := ""
var order_notice_left := 0.0
var preview_tower := ""
var wave_button: Button
var wave_glyph: ArenaGlyph
var preview: Panel
var hero_badge: TextureRect
var hero_health: ArenaMeter
var xp_bar: ArenaMeter
var core_health: ArenaMeter
var core_shield_bar: ArenaMeter
var tower_purchase: Button
var coins: Label
var wave_label: Label
var hero_level: Label
var run_lv_label: Label
var revival: Label
var unlock_hint: Panel
var unlock_clock := 0.0
var objective: Panel
var objective_step: Label
var objective_title: Label
var objective_body: Label
var phase_label: Label
var build_label: Label
var last_objective := ""
var tutorial_finished := false
var skills: Array[Button] = []
var skill_glyphs: Array[ArenaGlyph] = []
var dodge_button: Button
var dodge_glyph: ArenaGlyph
var dodge_cap_label: Label
var portal_button: Button
var portal_glyph: ArenaGlyph
var portal_cap_label: Label
var hero_debuff_box: HBoxContainer
var _last_debuff_sig := ""
var boss_bar_panel: Panel
var boss_portrait: TextureRect
var boss_title: Label
var boss_hp_text: Label
var boss_meter: ArenaMeter
var boss_ticks: Array[ColorRect] = []
var _last_boss_kind := ""
var radar_panel: Panel
var radar_status: Label
var radar_meter: ArenaMeter
var domain_switch_btn: Button
var alarm_vignette: _AlarmVignette
var transition_veil: ColorRect
var rift_minimap: _RiftMinimap
var rift_map_title: Label
var rift_map_footer: Label
var next_wave_btn: Button
var descent_badge: Button
var passive_ready_badge: Button
var _passive_badge_pulse := 0.0
var _passive_unlock_msec := 0
var _passive_require_release := false
var _passive_lock_bar: ArenaMeter
var _passive_lock_lbl: Label
var _passive_card_buttons: Array[Button] = []
var _event_unlock_msec := 0
var _event_lock_bar: ArenaMeter
var _event_lock_lbl: Label
var owned_passives_box: GridContainer
var owned_relics_box: HBoxContainer
var owned_passive_popover: Panel
var _last_owned_sig := ""
var _last_relic_sig := ""
var _open_owned_id := ""
var _open_passive_detail := ""
var bridge_button: Button
var bridge_meter: ArenaMeter
var bridge_label: Label
var breach_notice: Button
var battle_nodes: Array = []
var update_clock := 0.0
var selected_hero: String = "lord"
var frontend: ArenaFrontEnd

const CREAM := Color("f2e4c5")
const GOLD := Color("f3cc65")
const MUTED := Color("b6c0cb")
const COPPER := Color("b88943")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	context = Panel.new()
	context.hide()
	context.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(context)
	panel_style(context)
	frontend = ArenaFrontEnd.new(self)

func panel_style(node: Control, light := false) -> void:
	ArenaMenuArt.panel(node, light)

func pod_style(node: Control) -> void:
	node.add_theme_stylebox_override("panel", ArenaMenuArt.small_style(false))

func sub_card(parent: Node, rect: Rect2, paper := true) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.panel(node, paper)
	parent.add_child(node)
	return node

func enhancement_card(parent: Node, rect: Rect2, entry: Dictionary, status: String, tint: Color, index: int) -> Panel:
	var tile := sub_card(parent, rect, false)
	ArenaMenuArt.obsidian_panel(tile, true)
	tile.name = "Enhancement_%d" % index
	image(tile,ArenaMenuArt.perk(str(entry.icon)),Rect2(11,11,34,34)).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label(tile,str(entry.name),Rect2(53,7,rect.size.x-62,24),17,CREAM).name = "Title"
	label(tile,status,Rect2(53,30,rect.size.x-62,20),13,tint).name = "Status"
	var effect := label(tile,str(entry.summary),Rect2(11,54,rect.size.x-22,minf(54,rect.size.y-60)),14,MUTED)
	effect.name = "Effect"
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	return tile

func keycap(parent: Node, message: String, rect: Rect2, tint := GOLD) -> Panel:
	var node := Panel.new()
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_stylebox_override("panel", ArenaMenuArt.small_style(false, tint))
	parent.add_child(node)
	var txt := label(node, message, Rect2(Vector2(0, -1), rect.size), 12 if rect.size.y <= 24 else 14, tint)
	txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return node

func label(parent: Node, message: String, rect: Rect2, size := 18, colour := CREAM) -> Label:
	var node := Label.new()
	node.position = rect.position
	node.size = rect.size
	node.text = message
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", colour)
	parent.add_child(node)
	return node

func button(parent: Node, message: String, rect: Rect2, callback: Callable, primary := false) -> Button:
	var node := Button.new()
	node.position = rect.position
	node.size = rect.size
	node.text = message
	ArenaMenuArt.button(node, primary)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", 18 if rect.size.y < 56 else 20)
	var reduced := bool(game.campaign.data.get("reduced_motion", false)) if game != null and game.campaign != null else false
	ArenaMenuArt.interact(node, reduced)
	node.pressed.connect(func():
		game.suppress_primary = Input.is_action_pressed("shoot")
		callback.call()
	)
	parent.add_child(node)
	return node

func icon(parent: Node, key: String, rect: Rect2, tint := GOLD) -> ArenaGlyph:
	var node := ArenaGlyph.new()
	node.kind = key
	node.position = rect.position
	node.size = rect.size
	node.tint = tint
	parent.add_child(node)
	return node

func image(parent: Node, texture: Texture2D, rect: Rect2, cover := false) -> TextureRect:
	var node := TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture = texture
	node.position = rect.position
	node.size = rect.size
	node.stretch_mode = TextureRect.STRETCH_SCALE if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func colour_block(parent: Node, rect: Rect2, colour: Color) -> ColorRect:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = colour
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func meter(parent: Node, rect: Rect2, colour: Color) -> ArenaMeter:
	var node := ArenaMeter.new()
	node.position = rect.position
	node.size = rect.size
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("14202b")
	bg.border_color = Color("0b131c")
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = colour
	fg.set_corner_radius_all(4)
	node.add_theme_stylebox_override("background", bg)
	node.add_theme_stylebox_override("fill", fg)
	parent.add_child(node)
	return node

func steel_btn(parent: Node, message: String, rect: Rect2, callback: Callable, tone := "steel", font_size := 17) -> Button:
	var node := Button.new()
	node.position = rect.position
	node.size = rect.size
	node.text = message
	ArenaMenuArt.steel_button(node, tone)
	node.focus_mode = Control.FOCUS_NONE
	node.add_theme_font_size_override("font_size", font_size)
	var reduced := bool(game.campaign.data.get("reduced_motion", false)) if game != null and game.campaign != null else false
	ArenaMenuArt.interact(node, reduced)
	node.pressed.connect(func():
		game.suppress_primary = Input.is_action_pressed("shoot")
		callback.call()
	)
	parent.add_child(node)
	return node

func hero_portrait(key: String) -> Texture2D:
	return ArenaHeroArt.portrait(key)

func hero_badge_image(key: String) -> Texture2D:
	return ArenaHeroArt.small_portrait(key)

func tower_portrait(kind: String) -> Texture2D:
	return ArenaBattleArt.tower_portrait(kind)

func tower_image(kind: String, tier := 1, doctrine_id := "") -> Texture2D:
	return ArenaBattleArt.tower_texture(kind, tier, doctrine_id)

func reset_menu() -> void:
	if is_instance_valid(menu):
		root.remove_child(menu)
		menu.queue_free()
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(menu)

func fade_in(control: Control,start_alpha := 0.65) -> void:
	if bool(game.campaign.data.reduced_motion):
		return
	control.modulate.a = start_alpha
	control.create_tween().tween_property(control,"modulate:a",1.0,0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func refresh_motion() -> void:
	var reduced := bool(game.campaign.data.reduced_motion)
	for control in root.find_children("*","Button",true,false):
		ArenaMenuArt.interact(control,reduced)

func show_entry() -> void:
	frontend.entry()

func show_battle() -> void:
	if is_instance_valid(menu):
		menu.hide()
		menu.queue_free()
	for node in battle_nodes:
		if is_instance_valid(node):
			node.queue_free()
	battle_nodes.clear()
	skills.clear()
	skill_glyphs.clear()
	order_notice_left = 0.0
	order_hint = sub_card(root,Rect2(460,816,680,36),false)
	order_hint.name = "OrderHint"
	pod_style(order_hint)
	order_hint.hide()
	order_label = label(order_hint,"",Rect2(8,6,664,27),16,CREAM)
	order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	battle_nodes.append(order_hint)

	alarm_vignette = _AlarmVignette.new()
	alarm_vignette.name = "AlarmVignette"
	root.add_child(alarm_vignette)
	battle_nodes.append(alarm_vignette)

	transition_veil = ColorRect.new()
	transition_veil.name = "PortalIrisRect"
	transition_veil.color = Color(0.0, 0.0, 0.0, 0.0)
	transition_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if ResourceLoader.exists("res://scripts/shaders/portal_iris.gdshader"):
		var iris_mat := ShaderMaterial.new()
		iris_mat.shader = load("res://scripts/shaders/portal_iris.gdshader") as Shader
		iris_mat.set_shader_parameter("progress", 0.0)
		transition_veil.material = iris_mat
	root.add_child(transition_veil)
	battle_nodes.append(transition_veil)

	rift_minimap = _RiftMinimap.new()
	rift_minimap.name = "RiftMinimap"
	rift_minimap.game = game
	rift_minimap.position = Vector2(1370, 72)
	rift_minimap.size = Vector2(218, 204)
	ArenaMenuArt.obsidian_panel(rift_minimap, true)
	rift_map_title = label(rift_minimap, "F1 秘境 · 1/5轮", Rect2(10, 6, 198, 20), 12, ArenaMenuArt.STEEL_CYAN)
	rift_map_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rift_map_footer = label(rift_minimap, "", Rect2(10, 178, 198, 20), 12, GOLD)
	rift_map_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rift_minimap.hide()
	root.add_child(rift_minimap)
	battle_nodes.append(rift_minimap)

	descent_badge = steel_btn(root, "▼ 深层跃迁门已开 · 按 [F] 下潜", Rect2(570, 768, 460, 48), func():
		if game.rift_domain != null and game.rift_domain.can_descend_now():
			game.rift_domain.descend_next_floor()
	, "cyan", 16)
	descent_badge.name = "DescentReadyBadge"
	descent_badge.hide()
	battle_nodes.append(descent_badge)

	passive_ready_badge = steel_btn(root, "★ 进化就绪 · [Tab]", Rect2(610, 828, 380, 52), func():
		game.open_pending_passive_choice()
	, "gold", 17)
	passive_ready_badge.name = "PassiveReadyBadge"
	passive_ready_badge.tooltip_text = "已攒够升级经验！点击或按 [Tab] 从容挑选被动进化（战斗中可随时按需开启）"
	passive_ready_badge.hide()
	battle_nodes.append(passive_ready_badge)

	var hero_pod := Panel.new()
	hero_pod.name = "HeroPod"
	hero_pod.position = Vector2(12, 10)
	hero_pod.size = Vector2(294, 64)
	hero_pod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pod_style(hero_pod)
	root.add_child(hero_pod)
	battle_nodes.append(hero_pod)
	hero_badge = image(hero_pod, hero_badge_image(game.hero.class_id), Rect2(4, 5, 48, 52))
	hero_badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	revival = label(hero_pod, "", Rect2(8, 15, 40, 30), 20, GOLD)
	hero_health = meter(hero_pod, Rect2(58, 11, 124, 12), Color("d87d73"))
	xp_bar = meter(hero_pod, Rect2(58, 27, 124, 8), Color("4be3ff"))
	xp_bar.name = "XpMeter"
	run_lv_label = label(hero_pod, "Lv.1", Rect2(58, 39, 68, 18), 12, Color("7eeaff"))
	run_lv_label.name = "RunLevelLabel"
	hero_level = label(hero_pod, "养成1", Rect2(126, 40, 56, 16), 10, MUTED)
	hero_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	icon(hero_pod, "coin", Rect2(193, 15, 23, 23))
	coins = label(hero_pod, str(game.gold), Rect2(219, 13, 66, 28), 19, GOLD)

	var core_pod := Panel.new()
	core_pod.name = "CorePod"
	core_pod.position = Vector2(1378, 10)
	core_pod.size = Vector2(210, 54)
	core_pod.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pod_style(core_pod)
	root.add_child(core_pod)
	battle_nodes.append(core_pod)
	icon(core_pod, "core", Rect2(8, 11, 23, 28), Color("a0d9cd"))
	core_shield_bar = meter(core_pod, Rect2(40, 12, 110, 7), Color("7fe8ff"))
	core_shield_bar.name = "CoreShieldMeter"
	core_health = meter(core_pod, Rect2(40, 23, 110, 11), Color("79c69d"))
	var pause_button := button(core_pod, "Ⅱ", Rect2(158, 5, 48, 44), show_pause)
	pause_button.name = "Pause"
	pause_button.tooltip_text = "暂停 · Esc"

	next_wave_btn = steel_btn(root, "▶ 立刻开轮 [F]", Rect2(1378, 108, 210, 34), func():
		game.request_next_wave_anytime()
	, "cyan", 12)
	next_wave_btn.name = "CallNextWave"
	next_wave_btn.tooltip_text = "主防线常驻召潮：整备期立刻开轮 / 游击窗一键快进攻城 / 攻城完毕直接叠开下一轮拿高额赏金 [F]"
	battle_nodes.append(next_wave_btn)

	if game.world_size().x > 1600:
		var overview := button(root, "", Rect2(1324, 12, 44, 44), game.camera.toggle_overview)
		overview.name = "Overview"
		overview.tooltip_text = "M 全图 / 近景；中键拖动或边缘移动镜头；C 定位英雄"
		icon(overview, "overview", Rect2(8, 8, 28, 28))
		battle_nodes.append(overview)
		var focus := button(root, "", Rect2(314, 12, 44, 44), func():
			game.camera.focus(game.hero.position)
		)
		focus.name = "FocusHero"
		focus.tooltip_text = "定位英雄 · C"
		icon(focus, "target", Rect2(8, 8, 28, 28))
		battle_nodes.append(focus)
		breach_notice = button(root, "", Rect2(1324, 64, 44, 44), func():
			game.camera.focus(game.siege.point())
		)
		breach_notice.name = "BreachAlert"
		breach_notice.tooltip_text = "东北破障：击败蓄力中的破障者可延缓至下一轮。点击定位。"
		icon(breach_notice, "wave", Rect2(8, 8, 28, 28), GOLD)
		breach_notice.hide()
		battle_nodes.append(breach_notice)

	radar_panel = Panel.new()
	radar_panel.name = "DefenseRadar"
	radar_panel.position = Vector2(490, 10)
	radar_panel.size = Vector2(620, 44)
	radar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pod_style(radar_panel)
	root.add_child(radar_panel)
	battle_nodes.append(radar_panel)
	radar_status = label(radar_panel, "主域防线 · 安稳", Rect2(14, 4, 434, 18), 12, CREAM)
	radar_meter = meter(radar_panel, Rect2(14, 24, 434, 10), Color("6bd39c"))
	radar_meter.max_value = 100.0
	domain_switch_btn = steel_btn(radar_panel, "[T] 进裂隙", Rect2(458, 5, 152, 34), game.toggle_domain, "cyan", 13)
	domain_switch_btn.name = "DomainSwitch"

	wave_label = label(root, "1 / " + str(game.total_waves()), Rect2(1514, 74, 72, 22), 14, CREAM)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_nodes.append(wave_label)
	phase_label = label(root, "", Rect2(0, 0, 1, 1), 10)
	phase_label.hide()
	battle_nodes.append(phase_label)
	wave_button = button(root, "", Rect2(0, 0, 48, 48), game.request_wave)
	wave_button.name = "CallWave"
	wave_button.tooltip_text = "预览本轮兵力；再点提前开启本轮"
	battle_nodes.append(wave_button)
	wave_glyph = icon(wave_button, "wave", Rect2(7, 7, 34, 34))

	hero_debuff_box = HBoxContainer.new()
	hero_debuff_box.name = "HeroDebuffs"
	hero_debuff_box.position = Vector2(12, 78)
	hero_debuff_box.size = Vector2(310, 22)
	hero_debuff_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_debuff_box.add_theme_constant_override("separation", 6)
	root.add_child(hero_debuff_box)
	battle_nodes.append(hero_debuff_box)
	_last_debuff_sig = ""

	boss_bar_panel = Panel.new()
	boss_bar_panel.name = "BossBar"
	boss_bar_panel.position = Vector2(530, 60)
	boss_bar_panel.size = Vector2(540, 54)
	boss_bar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pod_style(boss_bar_panel)
	boss_bar_panel.hide()
	root.add_child(boss_bar_panel)
	battle_nodes.append(boss_bar_panel)
	boss_portrait = image(boss_bar_panel, null, Rect2(6, 4, 46, 46))
	boss_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	boss_title = label(boss_bar_panel, "", Rect2(60, 4, 336, 22), 15, GOLD)
	boss_hp_text = label(boss_bar_panel, "", Rect2(396, 5, 134, 20), 13, CREAM)
	boss_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_meter = meter(boss_bar_panel, Rect2(60, 29, 470, 15), Color("df5252"))
	boss_ticks.clear()
	_last_boss_kind = ""
	for frac in [0.33, 0.66]:
		var tick := colour_block(boss_bar_panel, Rect2(60.0 + 470.0 * frac, 29.0, 2.0, 15.0), Color(0.98, 0.92, 0.75, 0.65))
		boss_ticks.append(tick)

	var skill_dock := Control.new()
	skill_dock.position = Vector2(12, 818)
	skill_dock.size = Vector2(276, 70)
	skill_dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(skill_dock)
	battle_nodes.append(skill_dock)
	for slot in range(2):
		var b := button(skill_dock, "", Rect2(slot * 64, 4, 58, 62), game.request_skill.bind(slot))
		b.name = "Skill_" + str(slot)
		skills.append(b)
		var kind: String = {"lord": ["physical", "flag"], "druid": ["flag", "frost"], "healer": ["magic", "heart"], "werewolf": ["physical", "frost"], "gunner": ["move", "physical"]}.get(game.hero.class_id, ["physical", "flag"])[slot]
		var glyph := icon(b, kind, Rect2(4, 3, 48, 48), ArenaCombat.colour(game.hero.data.type))
		skill_glyphs.append(glyph)
		image(glyph, ArenaMenuArt.skill(game.hero.class_id, slot), Rect2(4, 3, 42, 42))
		keycap(b, "Q" if slot == 0 else "E", Rect2(35, 40, 20, 18))
		b.tooltip_text = ArenaDefinitions.skill_text(game.hero.class_id, slot, game.hero.passive_rank)

	dodge_button = button(skill_dock, "", Rect2(128, 4, 58, 62), func():
		if is_instance_valid(game.hero):
			game.hero.try_dodge()
	)
	dodge_button.name = "DodgeSkill"
	dodge_glyph = icon(dodge_button, "move", Rect2(8, 5, 42, 42), Color("9ae8ff"))
	var d_cap := keycap(dodge_button, game.campaign.keybind_label("dodge"), Rect2(14, 41, 40, 17), Color("9ae8ff"))
	for c in d_cap.get_children():
		if c is Label:
			dodge_cap_label = c
			c.add_theme_font_size_override("font_size", 10)

	portal_button = button(skill_dock, "", Rect2(192, 4, 58, 62), game.toggle_domain)
	portal_button.name = "PortalSkill"
	portal_glyph = icon(portal_button, "overview", Rect2(8, 5, 42, 42), Color("7fe8ff"))
	var p_cap := keycap(portal_button, game.campaign.keybind_label("portal"), Rect2(14, 41, 40, 17), GOLD)
	for c in p_cap.get_children():
		if c is Label:
			portal_cap_label = c
			c.add_theme_font_size_override("font_size", 10)
	refresh_keybind_labels()

	bridge_button = null
	bridge_meter = null
	bridge_label = null
	if not game.bridge_gate_config.is_empty():
		bridge_button = button(root, "", Rect2(game.bridge_gate_point() + Vector2(-22, 36), Vector2(44, 44)), game.trigger_bridge_gate)
		bridge_button.name = "BridgeGate"
		bridge_button.tooltip_text = "吊桥 [G] · 迫使敌人绕行 %d 秒，冷却 %d 秒。" % [ArenaGame.BRIDGE_SEAL_DURATION,ArenaGame.BRIDGE_COOLDOWN_DURATION]
		battle_nodes.append(bridge_button)
		icon(bridge_button, "flag", Rect2(8, 6, 26, 26), GOLD)
		keycap(bridge_button, "G", Rect2(25, 24, 17, 17))
		bridge_meter = meter(bridge_button, Rect2(4, 39, 36, 3), GOLD)
		bridge_label = label(bridge_button, "", Rect2(0, 0, 1, 1), 10)
		bridge_label.hide()

	preview = Panel.new()
	preview.size = Vector2(300, 102)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArenaMenuArt.obsidian_panel(preview, true)
	preview.hide()
	root.add_child(preview)
	battle_nodes.append(preview)

	create_owned_passives_strip()
	create_owned_relics_strip()

	objective = Panel.new()
	objective.position = Vector2(660, 835)
	objective.size = Vector2(280, 46)
	objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(objective)
	pod_style(objective)
	battle_nodes.append(objective)
	objective_step = label(objective, "", Rect2(0, 0, 1, 1), 10)
	objective_step.hide()
	objective_title = label(objective, "", Rect2(12, 9, 258, 26), 14, CREAM)
	objective_body = label(objective, "", Rect2(0, 0, 1, 1), 10)
	objective_body.hide()
	var build := Control.new()
	build.hide()
	root.add_child(build)
	battle_nodes.append(build)
	build_label = label(build, "", Rect2(0, 0, 1, 1), 10)
	root.move_child(context, root.get_child_count() - 1)

func refresh_keybind_labels() -> void:
	var dodge_k := game.campaign.keybind_label("dodge") if game != null and game.campaign != null else "V"
	var portal_k := game.campaign.keybind_label("portal") if game != null and game.campaign != null else "T"
	var recall_k := game.campaign.keybind_label("recall") if game != null and game.campaign != null else "R"
	if is_instance_valid(dodge_cap_label):
		dodge_cap_label.text = dodge_k
	if is_instance_valid(dodge_button):
		dodge_button.tooltip_text = "短距闪避 [%s]\n沿移动方向闪避，静止时朝面向闪避。短暂无敌，完美闪避强化下次普攻。" % dodge_k
	if is_instance_valid(portal_cap_label) and game != null:
		portal_cap_label.text = portal_k if game.active_domain == "defense" else recall_k

func create_owned_passives_strip() -> void:
	_last_owned_sig = "__init__"
	_open_owned_id = ""
	owned_passives_box = GridContainer.new()
	owned_passives_box.name = "OwnedPassivesStrip"
	owned_passives_box.position = Vector2(1010, 834)
	owned_passives_box.size = Vector2(574, 52)
	owned_passives_box.columns = 10
	owned_passives_box.add_theme_constant_override("h_separation", 6)
	owned_passives_box.add_theme_constant_override("v_separation", 6)
	owned_passives_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(owned_passives_box)
	battle_nodes.append(owned_passives_box)
	owned_passive_popover = Panel.new()
	owned_passive_popover.name = "OwnedPassivePopover"
	owned_passive_popover.position = Vector2(1224, 694)
	owned_passive_popover.size = Vector2(360, 132)
	owned_passive_popover.mouse_filter = Control.MOUSE_FILTER_STOP
	ArenaMenuArt.obsidian_panel(owned_passive_popover)
	owned_passive_popover.hide()
	root.add_child(owned_passive_popover)
	battle_nodes.append(owned_passive_popover)

func _show_owned_popover(item: Dictionary) -> void:
	if not is_instance_valid(owned_passive_popover):
		return
	var pid := str(item.id)
	if _open_owned_id == pid and owned_passive_popover.visible:
		_open_owned_id = ""
		owned_passive_popover.hide()
		return
	_open_owned_id = pid
	clear_children(owned_passive_popover)
	var mtex := ArenaMenuArt.passive_medal(pid)
	if mtex != null:
		var mi := image(owned_passive_popover, mtex, Rect2(14, 14, 42, 42))
		mi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var title_col := Color("ffe97a") if bool(item.evo) else ArenaMenuArt.STEEL_GOLD
	label(owned_passive_popover, "%s  ·  Lv.%d/3" % [str(item.name), int(item.rank)], Rect2(66, 12, 210, 24), 16, title_col)
	var cat := label(owned_passive_popover, "★超武" if bool(item.evo) else str(item.category), Rect2(276, 14, 70, 20), 12, ArenaMenuArt.STEEL_CYAN)
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var s_lbl := label(owned_passive_popover, str(item.summary), Rect2(14, 64, 332, 56), 13, CREAM)
	s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owned_passive_popover.show()

func refresh_owned_passives() -> void:
	if not is_instance_valid(owned_passives_box) or game.passive_engine == null:
		return
	var items := game.passive_engine.owned_list()
	var can_show := game.started and not has_modal()
	owned_passives_box.visible = can_show and not items.is_empty()
	if not owned_passives_box.visible and is_instance_valid(owned_passive_popover):
		owned_passive_popover.hide()
		_open_owned_id = ""
	var sig := ""
	for it in items:
		sig += str(it.id) + ":" + str(it.rank) + ";"
	if sig == _last_owned_sig:
		return
	_last_owned_sig = sig
	clear_children(owned_passives_box)
	var width := mini(items.size(),10)*54-6
	var top := 780.0 if items.size() > 10 else 834.0
	owned_passives_box.position = Vector2(1584-maxi(0,width),top)
	owned_passives_box.size = Vector2(maxi(0,width),900-top-12)
	owned_passive_popover.position.y = top-140.0
	var reduced := bool(game.campaign.data.get("reduced_motion", false)) if game != null and game.campaign != null else false
	for it in items:
		var pid := str(it.id)
		var slot := Button.new()
		slot.name = "OwnedPassive_" + pid
		slot.custom_minimum_size = Vector2(48, 48)
		slot.size = Vector2(48, 48)
		slot.focus_mode = Control.FOCUS_NONE
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var base_tint := Color(1.18, 1.05, 0.72) if bool(it.evo) else Color.WHITE
		for st_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			var tint := Color(1.22, 1.18, 1.08) if st_name in ["hover", "focus"] else base_tint
			slot.add_theme_stylebox_override(st_name, ArenaMenuArt.nine_patch_v028("badge_slot_mini", 6, 4, tint))
		var mtex := ArenaMenuArt.passive_medal(pid)
		if mtex != null:
			var mi := image(slot, mtex, Rect2(4, 3, 40, 40))
			mi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var pip := label(slot, "★" if bool(it.evo) else str(it.rank), Rect2(26, 30, 20, 16), 11, GOLD if bool(it.evo) else ArenaMenuArt.STEEL_CYAN)
		pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		slot.tooltip_text = "%s (Lv.%d/3)\n%s" % [str(it.name), int(it.rank), str(it.summary)]
		ArenaMenuArt.interact(slot, reduced)
		slot.pressed.connect(func():
			game.suppress_primary = Input.is_action_pressed("shoot")
			_show_owned_popover(it)
		)
		owned_passives_box.add_child(slot)

func create_owned_relics_strip() -> void:
	_last_relic_sig = "__init__"
	owned_relics_box = HBoxContainer.new()
	owned_relics_box.name = "OwnedRelicsStrip"
	owned_relics_box.position = Vector2(1010, 782)
	owned_relics_box.size = Vector2(574, 44)
	owned_relics_box.alignment = BoxContainer.ALIGNMENT_END
	owned_relics_box.add_theme_constant_override("separation", 6)
	owned_relics_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(owned_relics_box)
	battle_nodes.append(owned_relics_box)

func _show_owned_relic_popover(item: Dictionary) -> void:
	if not is_instance_valid(owned_passive_popover):
		return
	var pid := "relic:" + str(item.id)
	if _open_owned_id == pid and owned_passive_popover.visible:
		_open_owned_id = ""
		owned_passive_popover.hide()
		return
	_open_owned_id = pid
	clear_children(owned_passive_popover)
	var mtex := ArenaMenuArt.relic_medal(str(item.id))
	if mtex != null:
		var mi := image(owned_passive_popover, mtex, Rect2(14, 14, 42, 42))
		mi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label(owned_passive_popover, "遗物 · %s" % str(item.name), Rect2(66, 12, 210, 24), 16, Color("ffe97a"))
	var cat := label(owned_passive_popover, str(item.tag), Rect2(276, 14, 70, 20), 12, ArenaMenuArt.STEEL_CYAN)
	cat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var s_lbl := label(owned_passive_popover, str(item.desc), Rect2(14, 64, 332, 56), 13, CREAM)
	s_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	owned_passive_popover.show()

func refresh_owned_relics() -> void:
	if not is_instance_valid(owned_relics_box) or game.relic_engine == null:
		return
	var items := game.relic_engine.owned_list()
	var can_show := game.started and not has_modal()
	owned_relics_box.visible = can_show and not items.is_empty()
	var sig := ""
	for it in items:
		sig += str(it.id) + ";"
	if sig == _last_relic_sig:
		return
	_last_relic_sig = sig
	clear_children(owned_relics_box)
	var reduced := bool(game.campaign.data.get("reduced_motion", false)) if game != null and game.campaign != null else false
	for it in items:
		var rid := str(it.id)
		var slot := Button.new()
		slot.name = "OwnedRelic_" + rid
		slot.custom_minimum_size = Vector2(42, 42)
		slot.size = Vector2(42, 42)
		slot.focus_mode = Control.FOCUS_NONE
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		for st_name in ["normal", "hover", "pressed", "disabled", "focus"]:
			var tint := Color(1.22, 1.15, 0.95) if st_name in ["hover", "focus"] else Color(1.10, 1.02, 0.80)
			slot.add_theme_stylebox_override(st_name, ArenaMenuArt.nine_patch_v028("badge_slot_mini", 6, 4, tint))
		var rtex := ArenaMenuArt.relic_medal(rid)
		if rtex != null:
			var mi := image(slot, rtex, Rect2(3, 3, 36, 36))
			mi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.tooltip_text = "★ 裂隙遗物 · %s [%s]\n%s" % [str(it.name), str(it.tag), str(it.desc)]
		ArenaMenuArt.interact(slot, reduced)
		slot.pressed.connect(func():
			game.suppress_primary = Input.is_action_pressed("shoot")
			_show_owned_relic_popover(it)
		)
		owned_relics_box.add_child(slot)

func refresh_radar() -> void:
	if not is_instance_valid(radar_panel) or game.rift_domain == null:
		return
	var rd := game.rift_domain
	var pct := clampf(rd.max_road_ratio * 100.0, 0.0, 100.0)
	radar_meter.value = pct
	var fill_box := radar_meter.get_theme_stylebox("fill") as StyleBoxFlat
	var tier := rd.alarm_level
	if rd.core_hit_alert > 0.0:
		tier = 2
	if fill_box != null:
		fill_box.bg_color = Color("f04652") if tier >= 2 else (Color("f5a642") if tier == 1 else Color("6bd39c"))
	var dom_label := "主域防线"
	if game.active_domain == "rift":
		var rid := rd.current_room_id(game.hero.position) if is_instance_valid(game.hero) else "hub"
		var rtitle := str(rd.rooms.get(rid, {}).get("title", rd.layout.get("title", "秘境")))
		var m_lbl := rd.current_mutator_label(game.hero.position) if is_instance_valid(game.hero) else ""
		dom_label = "F%d %s · %s%s" % [rd.floor_index, str(rd.layout.get("short", "秘境")), rtitle, (" [" + m_lbl + "]" if m_lbl != "" else "")]
	var alert_txt := "⚠ 核心受击！" if rd.core_hit_alert > 0.0 else ("⚠ 攻城敌军接近" if tier >= 2 else ("敌人推进中" if tier == 1 else "防线稳固"))
	radar_status.text = "%s  |  %s (%d只 · %.0f%%)" % [dom_label, alert_txt, rd.live_road_enemies, pct]
	radar_status.add_theme_color_override("font_color", Color("ff8a8a") if tier >= 2 else (Color("ffd082") if tier == 1 else CREAM))
	var portal_k := game.campaign.keybind_label("portal") if game.campaign != null else "T"
	var recall_k := game.campaign.keybind_label("recall") if game.campaign != null else "R"
	var in_defense := game.active_domain == "defense"
	domain_switch_btn.disabled = game.game_over or has_modal() or game.portal_transition_active() or (in_defense and not rd.can_enter_rift())
	if game.portal_transition_active():
		domain_switch_btn.text = "切换中…"
	elif in_defense:
		if rd.portal_cooldown > 0.0:
			domain_switch_btn.text = "充能 %ds" % ceili(rd.portal_cooldown)
		else:
			domain_switch_btn.text = ("[%s] 继续战斗房" if not rd.active_combat_room.is_empty() else "[%s] 进裂隙") % portal_k
	else:
		domain_switch_btn.text = "[%s] 回防线" % recall_k
	domain_switch_btn.tooltip_text = "从离开的位置继续探索。回防后充能 %d 秒。" % ArenaRiftDomain.PORTAL_COOLDOWN if in_defense else "回防时震击核心附近的敌人，裂隙房间暂停。"
	if is_instance_valid(portal_button):
		portal_button.tooltip_text = domain_switch_btn.tooltip_text

func show_context(index: int) -> void:
	if not game.can_manage_defense():
		return
	game.selected_site = index
	refresh_context()

func clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _trait_badge(parent: Control, site_trait: String, trait_name: String, trait_desc: String, trait_tint: Color, rect: Rect2) -> void:
	if site_trait == "":
		return
	var badge := Panel.new()
	badge.position = rect.position
	badge.size = rect.size
	badge.mouse_filter = Control.MOUSE_FILTER_PASS
	pod_style(badge)
	badge.tooltip_text = trait_name + "：" + trait_desc
	var glyph: String = str({"highground": "physical", "choke": "shield", "conduit": "magic"}.get(site_trait, "magic"))
	var stat: String = str({"highground": "+18%", "choke": ("+18%" if game.tower_lab else "+25%"), "conduit": "+14%"}.get(site_trait, "+"))
	icon(badge, glyph, Rect2(6, 5, 16, 16), trait_tint)
	var lbl := label(badge, stat, Rect2(24, 3, rect.size.x - 28, 20), 13, trait_tint)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(badge)

func refresh_context() -> void:
	if game.selected_site < 0 or not game.can_manage_defense():
		return
	clear_children(context)
	tower_purchase = null
	context.show()
	_set_range_preview("")
	var tower: ArenaTower = game.site_tower(game.selected_site)
	var locked := tower == null and game.site_locked(game.selected_site)
	var sealed := tower != null and tower.has_method("is_sealed") and tower.is_sealed()
	var work_allowed := game.can_change_towers() and not sealed
	var sell_allowed := game.can_sell_towers() and not sealed
	var has_doctrine := tower != null and not tower.doctrine_id.is_empty() and not game.tower_lab
	if has_doctrine:
		ArenaMenuArt.obsidian_panel(context,false)
	else:
		panel_style(context)
	var cannon_order := tower != null and game.tower_lab and tower.can_set_bombard()
	var fixed_order := cannon_order and tower.bombard_point.is_finite()
	if not game.tower_lab:
		context.size = Vector2(328, 154) if locked else (Vector2(372, 172) if tower == null else (Vector2(658, 356) if has_doctrine else Vector2(316, 206)))
	else:
		context.size = Vector2(328, 154) if locked else (Vector2(372, 172) if tower == null else Vector2(316, 260 if fixed_order else 228))

	var point: Vector2 = game.world_to_hud(game.level_definition.sites[game.selected_site])
	_position_tower_context(point)
	var traits: Array = game.level_definition.get("site_traits", [])
	var site_trait: String = str(traits[game.selected_site]) if game.selected_site < traits.size() else ""
	var trait_name: String = ArenaTower.trait_label(site_trait)
	var trait_desc: String = ArenaTower.trait_summary(site_trait)
	if game.tower_lab and site_trait == "choke":
		trait_desc = "兵营生命 +18%"
	var trait_tint: Color = {"highground": Color("f6c862"), "choke": Color("ee7b56"), "conduit": Color("6ce8ff")}.get(site_trait, GOLD)
	var roles: Array = game.level_definition.get("site_roles", [])
	var role_name: String = str(roles[game.selected_site]) if game.selected_site < roles.size() else ""

	if not work_allowed and tower == null:
		label(context, "塔位暂不可用", Rect2(18, 12, 200, 28), 19, GOLD)
		label(context, "在防御域可建塔或解锁塔位", Rect2(18, 55, 284, 30), 17, MUTED)
		button(context, "关闭", Rect2(18, 100, 118, 38), close_context)
		return
	if locked:
		var price := game.unlock_price(game.selected_site)
		label(context, "解锁塔位", Rect2(18, 12, 180, 30), 20, GOLD)
		_trait_badge(context, site_trait, trait_name, trait_desc, trait_tint, Rect2(228, 12, 82, 26))
		var unlock := button(context, "解锁    %d  ◉" % price, Rect2(18, 52, 292, 48), game.unlock_site.bind(game.selected_site), true)
		unlock.name = "UnlockSite"
		unlock.set_meta("required_gold",price)
		unlock.disabled = game.gold < price
		unlock.tooltip_text = (role_name + "\n" if role_name != "" else "") + "解锁后可建造或出售防御塔"
		unlock.set_meta("base_tip",unlock.tooltip_text)
		label(context, "+1 火力位", Rect2(18, 108, 290, 22), 13, MUTED)
	elif tower == null:
		label(context, "建造防御塔", Rect2(18, 10, 220, 28), 18, GOLD)
		_trait_badge(context, site_trait, trait_name, trait_desc, trait_tint, Rect2(272, 10, 84, 26))
		for column in range(game.run_towers.size()):
			var key: String = game.run_towers[column]
			var data := game.tower_display_data(key)
			var b := button(context, "", Rect2(14 + column * 86, 44, 80, 108), _build.bind(key))
			b.name = "Build_" + key
			b.set_meta("required_gold",int(data.cost))
			b.set_meta("tower_kind",key)
			b.disabled = key not in game.available_towers() or game.gold < int(data.cost)
			var b_img := image(b, tower_portrait(key), Rect2(6, 4, 68, 68))
			b_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon(b, "coin", Rect2(12, 79, 18, 18))
			label(b, str(data.cost), Rect2(34, 78, 42, 22), 16, GOLD)
			b.mouse_entered.connect(_set_range_preview.bind(key))
			b.mouse_exited.connect(_set_range_preview.bind(""))
			if game.level_id in [ArenaSaltport.ID,"lighthouse","ruins","sanctum"]:
				b.focus_mode = Control.FOCUS_ALL
				b.focus_entered.connect(_set_range_preview.bind(key))
				b.focus_exited.connect(_set_range_preview.bind(""))
			var upgrade_hint := " · 点击塔位升级" if game.tower_lab else " · 金币足够时自动升级"
			b.tooltip_text = data.name + upgrade_hint + "\n" + (trait_name + " · " + trait_desc if trait_name != "" else str(data.description))
			b.set_meta("base_tip",b.tooltip_text)
	elif has_doctrine:
		_show_tower_specialization(tower, sealed, sell_allowed, trait_name)
	else:
		label(context, str(tower.data.name) + "  " + str(tower.level) + "/3", Rect2(18, 12, 160, 30), 21, GOLD)
		if sealed:
			label(context, "触手封锁 %.1f秒" % tower.seal_clock, Rect2(178, 14, 126, 26), 14, Color("ff809a")).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		else:
			_trait_badge(context, site_trait, trait_name, trait_desc, trait_tint, Rect2(216, 12, 84, 26))
		icon(context, "physical" if tower.data.type == 0 else "magic", Rect2(18, 48, 22, 22), ArenaCombat.colour(tower.data.type))
		var description := label(context, ArenaCombat.label(tower.data.type) + " · " + str(tower.data.description), Rect2(48, 44, 250, 40), 14, MUTED)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if tower.project_level == 1 or (tower.project_level != 0 and game.tower_lab):
			var caption := "建造中 · 取消" if tower.project_level == 1 else "升级中 · 取消"
			var cancel := button(context, caption, Rect2(16, 88, 284, 46), tower.cancel_project)
			cancel.name = "CancelTowerWork"
			cancel.disabled = sealed
		elif not game.tower_lab:
			var stage_name := "二级" if tower.level == 1 else "三级"
			var state := "自动升%s · %d 金币" % [stage_name,tower.upgrade_price()]
			if tower.project_level != 0:
				state = "正在升%s · 已付 %d 金币" % [stage_name,tower.project_gold]
			elif sealed:
				state = "解除封锁后自动升级"
			label(context, state, Rect2(16, 94, 284, 34), 16, GOLD)
		elif tower.level < 3:
			var price := tower.upgrade_price()
			var caption := "触手封锁 · 停摆中" if sealed else "升到%s级    %d 金币" % ["二" if tower.level == 1 else "三",price]
			var up := button(context, caption, Rect2(16, 88, 284, 46), tower.upgrade, true)
			up.name = "Upgrade"
			tower_purchase = up
			up.set_meta("required_gold", price)
			_sync_tower_purchase(work_allowed)
		else:
			var up := button(context, "已达三级", Rect2(16, 88, 284, 46), tower.upgrade, true)
			up.name = "Upgrade"
			up.disabled = true
		var can_order := (tower.kind == "barracks" or cannon_order) if game.tower_lab else tower.kind not in ["mage","snare"]
		if can_order:
			var ground_order := tower.kind == "barracks" or cannon_order
			var title := "⚑ 集结" if tower.kind == "barracks" else _tower_priority_label(tower)
			if cannon_order:
				title = "改落点" if fixed_order else "设落点"
			var target := button(context, title, Rect2(16, 150, 88, 44), _rally if ground_order else _target)
			target.name = "TowerGroundOrder" if ground_order else "TowerPriority"
			target.add_theme_font_size_override("font_size", 14)
			target.disabled = sealed or tower.project_level == 1
			if not game.tower_lab:
				target.tooltip_text = "选择士兵集结点" if ground_order else "点击切换优先目标"
		if fixed_order:
			var automatic := button(context, "恢复自动瞄准", Rect2(16, 201, 284, 36), tower.clear_bombard)
			automatic.name = "ResetBombard"
			automatic.disabled = sealed
		_sale_button(tower, Rect2(110, 150, 120, 44) if can_order else Rect2(16, 150, 214, 44), sell_allowed)
		button(context, "×", Rect2(240, 150, 60, 44), close_context)

func _show_tower_specialization(tower: ArenaTower, sealed: bool, sell_allowed: bool, trait_name: String) -> void:
	var entry := tower.doctrine_data
	label(context, "%s  /  三级" % str(tower.data.name), Rect2(20,9,400,31),21,GOLD)
	var site_label := label(context,"触手封锁中" if sealed else trait_name,Rect2(485,12,151,25),14,Color("ff809a") if sealed else MUTED)
	site_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var spec := sub_card(context,Rect2(18,47,622,83),false)
	ArenaMenuArt.obsidian_panel(spec,true)
	spec.name = "TowerSpecialization"
	image(spec,tower_image(tower.kind,3,tower.doctrine_id),Rect2(9,4,75,75)).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label(spec,"生效专精",Rect2(91,8,82,24),14,ArenaMenuArt.STEEL_CYAN)
	label(spec,str(entry.name),Rect2(174,6,151,26),19,GOLD).name = "Title"
	label(spec,str(entry.role),Rect2(333,8,270,24),14,MUTED)
	var description := label(spec,ArenaDoctrines.field_summary(tower.doctrine_id),Rect2(91,38,512,38),14,CREAM)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	var growth := Control.new()
	growth.name = "TowerEnhancements"
	growth.position = Vector2(18,139)
	growth.size = Vector2(622,162)
	growth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	context.add_child(growth)
	var stages := tower.enhancements()
	label(growth,"专精强化",Rect2(0,0,168,27),18,GOLD)
	var heading := "全部强化已生效" if tower.unlocked_enhancements == stages.size() else "金币足够时自动施工"
	label(growth,heading,Rect2(180,3,442,22),14,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var width := (622.0-8.0*(stages.size()-1))/stages.size()
	for index in range(stages.size()):
		var price: int = ArenaDoctrines.ENHANCEMENT_PRICES[index]
		var status := "待解锁 · %d 金币" % price
		var tint := MUTED
		if index < tower.unlocked_enhancements:
			status = "已生效"
			tint = Color("a6dfac")
		elif index == tower.unlocked_enhancements:
			status = "施工中 · 已付 %d 金币" % price if tower.project_level != 0 else "下一项 · %d 金币" % price
			tint = ArenaMenuArt.STEEL_CYAN
		enhancement_card(growth,Rect2(index*(width+8),36,width,126),stages[index],status,tint,index)

	var can_order := tower.kind not in ["mage", "snare"] and tower.forced_target().is_empty()
	if can_order:
		var is_barracks := tower.kind == "barracks"
		var order_label := "⚑ 集结" if is_barracks else _tower_priority_label(tower)
		var target := button(context,order_label,Rect2(18,308,126,35),_rally if is_barracks else _target)
		target.name = "TowerGroundOrder" if is_barracks else "TowerPriority"
		target.disabled = sealed
	_sale_button(tower,Rect2(152 if can_order else 18,308,148,35),sell_allowed)
	button(context,"×",Rect2(566,308,74,35),close_context)

func _sync_tower_purchase(allowed: bool) -> void:
	var shortfall := int(tower_purchase.get_meta("required_gold")) - game.gold
	tower_purchase.disabled = not allowed or shortfall > 0
	tower_purchase.tooltip_text = "还需 %d 金币" % shortfall if allowed and shortfall > 0 else ""

func _sale_button(tower: ArenaTower, rect: Rect2, sell_allowed: bool) -> void:
	var sealed := tower != null and tower.has_method("is_sealed") and tower.is_sealed()
	var caption := "出售 %d ◉" % tower.sale_value()
	if sealed:
		caption = "触手封锁"
	elif not sell_allowed:
		caption = "回防后出售" if game.active_domain == "rift" else "暂不可出售"
	elif tower.project_level != 0:
		caption = "完工出售"
	var sale := button(context, caption, rect, tower.sell)
	sale.name = "SellTower"
	sale.disabled = not sell_allowed or tower.project_level != 0
	sale.tooltip_text = "深渊触手封锁期间无法拆除" if sealed else "出售可回收实付金币的 %d%%，本塔回收 %d 金币。" % [roundi(ArenaTower.SALE_REFUND_RATIO*100.0),tower.sale_value()]

func _build(key: String) -> void:
	if game.build_tower(game.selected_site, key):
		refresh_context()

func _rally() -> void:
	if not game.can_manage_defense():
		return
	game.rally_site = game.selected_site
	game.targeting_slot = -1
	order_notice_left = 0.0
	close_context()

func _tower_priority_label(tower: ArenaTower) -> String:
	return "优先强敌" if tower.target_mode == "strongest" else "优先先锋"

func _target() -> void:
	if not game.can_manage_defense():
		return
	var tower := game.site_tower(game.selected_site)
	if tower != null and tower.forced_target() == "":
		tower.target_mode = "strongest" if tower.target_mode == "first" else "first"
		refresh_context()

func _position_tower_context(anchor: Vector2) -> void:
	var y := anchor.y + 38.0
	if y + context.size.y > 885.0:y = anchor.y - context.size.y - 38.0
	context.position = Vector2(clampf(anchor.x-context.size.x*0.5,12,1588-context.size.x),clampf(y,86,885-context.size.y))

func show_order_notice(message: String) -> void:
	order_notice = message
	order_notice_left = 1.15

func _refresh_order_hint(delta: float) -> void:
	if not is_instance_valid(order_hint):
		return
	order_notice_left = maxf(0.0,order_notice_left-delta)
	var hint := ""
	if order_notice_left > 0.0:
		hint = order_notice
	elif game.targeting_slot >= 0:
		hint = "左键施放技能   ·   右键 / Esc 取消"
	elif game.rally_site >= 0:
		var tower := game.site_tower(game.rally_site)
		if tower != null:
			var order := "炮击落点" if tower.can_set_bombard() else ("绊索位置" if tower.kind == "snare" else "集结点")
			hint = "左键确定%s   ·   右键 / Esc 取消" % order
	order_hint.visible = not hint.is_empty() and not has_modal() and not game.game_over
	if order_hint.visible:order_label.text = hint

func close_context() -> void:
	context.hide()
	game.selected_site = -1
	_set_range_preview("")

func _set_range_preview(key: String) -> void:
	preview_tower = key
	game.queue_redraw()

func announce_unlock() -> void:
	if not game.started:
		return
	var unlocked: Array = []
	for key in game.available_towers():
		if int(game.level_definition.towers[key]) == game.cycle:
			unlocked.append(key)
	if unlocked.is_empty():
		return
	if not is_instance_valid(unlock_hint):
		unlock_hint = Panel.new()
		unlock_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(unlock_hint)
		ArenaMenuArt.obsidian_panel(unlock_hint, true)
		battle_nodes.append(unlock_hint)
	clear_children(unlock_hint)
	unlock_hint.position = Vector2(636, 118)
	unlock_hint.size = Vector2(48 + unlocked.size() * 66, 75)
	unlock_hint.show()
	unlock_clock = 3.5
	icon(unlock_hint, "upgrade", Rect2(10, 22, 27, 32))
	for i in range(unlocked.size()):
		var u_img := image(unlock_hint, tower_portrait(unlocked[i]), Rect2(45 + i * 66, 4, 64, 64))
		u_img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func modal_panel(size: Vector2) -> Panel:
	close_modal()
	_modal_return_focus = get_viewport().gui_get_focus_owner()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.05, 0.09, 0.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(veil)
	var panel := Panel.new()
	panel.size = size
	panel.position = (Vector2(1600, 900) - size) * 0.5
	modal.add_child(panel)
	ArenaMenuArt.obsidian_panel(panel)
	fade_in(panel)
	return panel

func close_modal() -> void:
	if is_instance_valid(modal):
		root.remove_child(modal)
		modal.queue_free()
	modal = null
	if is_instance_valid(_modal_return_focus) and _modal_return_focus.is_visible_in_tree():
		_modal_return_focus.grab_focus()
	_modal_return_focus = null

func has_modal() -> bool:
	return is_instance_valid(modal)

func focus_dialog(preferred: Control) -> void:
	var controls: Array[Control] = []
	for control: Control in modal.find_children("*","Control",true,false):
		if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree() and (not control is BaseButton or not control.disabled):
			controls.append(control)
	for index in controls.size():
		var control := controls[index]
		control.focus_next = control.get_path_to(controls[(index+1)%controls.size()])
		control.focus_previous = control.get_path_to(controls[posmod(index-1,controls.size())])
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_bottom = control.focus_next
		control.focus_neighbor_left = control.focus_previous
		control.focus_neighbor_right = control.focus_next
	if preferred in controls:preferred.grab_focus()

func _toggle_passive_detail(popover: Panel, offer: Dictionary) -> void:
	if not is_instance_valid(popover):
		return
	var pid := str(offer.id)
	if popover.visible and _open_passive_detail == pid:
		_open_passive_detail = ""
		popover.hide()
		return
	_open_passive_detail = pid
	clear_children(popover)
	var mtex := ArenaMenuArt.passive_medal(pid)
	if mtex != null:
		var mi := image(popover, mtex, Rect2(18, 22, 54, 54))
		mi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var next_r := int(offer.get("next_rank", 1))
	label(popover, "%s · %s (Lv.%d/3)" % [str(offer.name), str(offer.get("category", "")), next_r], Rect2(84, 16, 560, 28), 19, ArenaMenuArt.STEEL_GOLD)
	var det := str(offer.get("detail", offer.get("tagline", "")))
	var d_lbl := label(popover, det, Rect2(84, 50, 598, 48), 15, CREAM)
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var all_d: Array = offer.get("all_details", [])
	if all_d.size() >= 3:
		var evo_lbl := label(popover, "满星超武 · " + str(all_d[2]), Rect2(84, 102, 598, 36), 13, Color("ffe878"))
		evo_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var close_btn := steel_btn(popover, "✕", Rect2(674, 14, 32, 30), func():
		popover.hide()
		_open_passive_detail = ""
	, "steel", 14)
	close_btn.name = "ClosePassiveDetail"
	popover.show()

func pulse_passive_badge() -> void:
	_passive_badge_pulse = 1.6


func is_passive_input_locked() -> bool:
	if Engine.time_scale > 2.0:
		return false
	return _passive_require_release or Time.get_ticks_msec() < _passive_unlock_msec


func is_event_input_locked() -> bool:
	return Time.get_ticks_msec() < _event_unlock_msec or _passive_require_release

func show_rift_event_modal(offer: Dictionary) -> void:
	close_context()
	game.rally_site = -1
	game.targeting_slot = -1
	close_modal()
	_event_unlock_msec = Time.get_ticks_msec() + 450
	_passive_require_release = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.05, 0.09, 0.72)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(veil)

	var head := label(modal, "◆  %s  ◆" % str(offer.get("title", "裂隙奇遇")), Rect2(200, 96, 1200, 44), 32, ArenaMenuArt.STEEL_GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := label(modal, str(offer.get("subtitle", "")), Rect2(200, 146, 1200, 26), 15, ArenaMenuArt.STEEL_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var opts: Array = offer.get("options", [])
	var card_w := 310.0
	var card_h := 290.0
	var gap := 32.0
	var total_w := card_w * opts.size() + gap * maxf(0.0, float(opts.size() - 1))
	var start_x := (1600.0 - total_w) * 0.5
	var reduced := bool(game.campaign.data.get("reduced_motion", false)) if game != null and game.campaign != null else false
	for i in range(opts.size()):
		var opt: Dictionary = opts[i]
		var cost_g := int(opt.get("cost_gold", 0))
		var cant_afford := game.gold < cost_g
		var b := Button.new()
		b.name = "EventOption_" + str(opt.id)
		b.position = Vector2(start_x + i * (card_w + gap), 240.0)
		b.size = Vector2(card_w, card_h)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = cant_afford
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.add_theme_stylebox_override("normal", ArenaMenuArt.nine_patch_v028("rule_card_bg", 20, 12))
		b.add_theme_stylebox_override("hover", ArenaMenuArt.nine_patch_v028("rule_card_hover", 20, 12))
		b.add_theme_stylebox_override("focus", ArenaMenuArt.nine_patch_v028("rule_card_hover", 20, 12))
		b.add_theme_stylebox_override("pressed", ArenaMenuArt.nine_patch_v028("rule_card_bg", 20, 12, Color(0.86, 0.90, 0.96)))
		ArenaMenuArt.interact(b, reduced)
		b.pressed.connect(func():
			if is_event_input_locked():
				return
			game.choose_rift_event(i)
		)
		modal.add_child(b)
		keycap(b, str(i + 1), Rect2(14, 14, 24, 22), GOLD)
		var tag_l := label(b, str(opt.get("tag", "")), Rect2(160, 16, 134, 22), 13, Color("ff7890") if cant_afford else ArenaMenuArt.STEEL_CYAN)
		tag_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var t_lbl := label(b, str(opt.get("title", "")), Rect2(18, 62, 274, 52), 20, ArenaMenuArt.STEEL_GOLD)
		t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		colour_block(b, Rect2(44, 126, 222, 1), Color(0.35, 0.65, 0.85, 0.35))
		var d_lbl := label(b, str(opt.get("desc", "")), Rect2(20, 146, 270, 118), 15, CREAM)
		d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_event_lock_lbl = label(modal, "防误触解锁中…请先确认事件抉择", Rect2(560, 560, 480, 22), 14, GOLD)
	_event_lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_lock_bar = meter(modal, Rect2(560, 586, 480, 8), GOLD)
	_event_lock_bar.max_value = 450.0
	_event_lock_bar.value = 0.0
	var skip_btn := steel_btn(modal, "暂不使用 (Esc)", Rect2(700, 622, 200, 44), func():
		game.close_rift_event_without_use()
	, "steel", 15)
	skip_btn.name = "CloseEventModal"

func show_passive_choice(offers: Array[Dictionary]) -> void:
	close_context()
	game.rally_site = -1
	game.targeting_slot = -1
	close_modal()
	_open_passive_detail = ""
	_passive_card_buttons.clear()
	_passive_unlock_msec = Time.get_ticks_msec() + 550
	_passive_require_release = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	var veil := ColorRect.new()
	veil.color = Color(0.03, 0.05, 0.09, 0.68)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(veil)
	var lv := game.passive_engine.run_level if game.passive_engine != null else 1
	var picks := game.passive_engine.picks_taken if game.passive_engine != null else 0
	var head_txt := "◆  挑选被动进化 · %d / %d (Lv.%d)  ◆" % [picks + 1, ArenaPassiveEngine.MAX_TOTAL_PICKS, lv]
	var head := label(modal, head_txt, Rect2(200, 74, 1200, 44), 30, ArenaMenuArt.STEEL_GOLD)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override("font_outline_color", Color("071018"))
	head.add_theme_constant_override("outline_size", 4)
	var sub := label(modal, "按 1 / 2 / 3 或点击卡牌获取（全自动触发 · 满3星觉醒超武 · 含0.55秒防误触保护）", Rect2(200, 124, 1200, 26), 15, ArenaMenuArt.STEEL_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", Color("071018"))
	sub.add_theme_constant_override("outline_size", 2)

	var detail_popover := Panel.new()
	detail_popover.name = "PassiveDetailPopover"
	detail_popover.position = Vector2(440, 646)
	detail_popover.size = Vector2(720, 152)
	detail_popover.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_popover.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	detail_popover.add_theme_stylebox_override("panel", ArenaMenuArt.nine_patch_v028("detail_popover_bg", 16, 12))
	detail_popover.hide()

	var count := offers.size()
	var card_w := 296.0
	var card_h := 356.0
	var gap := 34.0
	var total_w := card_w * count + gap * maxf(0.0, float(count - 1))
	var start_x := (1600.0 - total_w) * 0.5
	var card_y := 228.0
	var reduced := bool(game.campaign.data.get("reduced_motion", false)) if game != null and game.campaign != null else false

	for i in range(count):
		var offer := offers[i]
		var pid := str(offer.id)
		var will_evo := bool(offer.get("will_evo", false))
		var next_r := int(offer.get("next_rank", 1))
		var wrap := Control.new()
		wrap.position = Vector2(start_x + i * (card_w + gap), card_y)
		wrap.size = Vector2(card_w, card_h)
		wrap.clip_contents = false
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		modal.add_child(wrap)

		var b := Button.new()
		b.name = "PassiveOffer_" + pid
		b.position = Vector2.ZERO
		b.size = Vector2(card_w, card_h)
		b.focus_mode = Control.FOCUS_NONE
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if will_evo and ArenaMenuArt.v030("card_evo_gold") != null:
			b.add_theme_stylebox_override("normal", ArenaMenuArt.nine_patch_v030("card_evo_gold", 22, 12))
			b.add_theme_stylebox_override("hover", ArenaMenuArt.nine_patch_v030("card_evo_gold", 22, 12, Color(1.12, 1.12, 1.08)))
			b.add_theme_stylebox_override("focus", ArenaMenuArt.nine_patch_v030("card_evo_gold", 22, 12, Color(1.12, 1.12, 1.08)))
			b.add_theme_stylebox_override("pressed", ArenaMenuArt.nine_patch_v030("card_evo_gold", 22, 12, Color(0.88, 0.90, 0.94)))
		else:
			b.add_theme_stylebox_override("normal", ArenaMenuArt.nine_patch_v028("rule_card_bg", 20, 12))
			b.add_theme_stylebox_override("hover", ArenaMenuArt.nine_patch_v028("rule_card_hover", 20, 12))
			b.add_theme_stylebox_override("focus", ArenaMenuArt.nine_patch_v028("rule_card_hover", 20, 12))
			b.add_theme_stylebox_override("pressed", ArenaMenuArt.nine_patch_v028("rule_card_bg", 20, 12, Color(0.86, 0.90, 0.96)))
		ArenaMenuArt.interact(b, reduced)
		b.pressed.connect(func():
			if is_passive_input_locked():
				return
			game.suppress_primary = Input.is_action_pressed("shoot")
			game.choose_passive(pid)
		)
		wrap.add_child(b)
		_passive_card_buttons.append(b)

		keycap(b, str(i + 1), Rect2(14, 14, 24, 22), GOLD if will_evo else ArenaMenuArt.STEEL_GOLD)
		var tag_pill := Panel.new()
		tag_pill.position = Vector2(198, 14)
		tag_pill.size = Vector2(84, 24)
		tag_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag_pill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tag_pill.add_theme_stylebox_override("panel", ArenaMenuArt.nine_patch_v028("tag_pill_bg", 6, 4))
		b.add_child(tag_pill)
		var tag_lbl := label(tag_pill, str(offer.get("category_tag", "被动")), Rect2(0, 1, 84, 22), 12, Color("ffe878") if will_evo else ArenaMenuArt.STEEL_CYAN)
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

		var title_lbl := label(b, str(offer.get("short_name", offer.name)), Rect2(16, 62, 264, 34), 24, Color("ffe97a") if will_evo else ArenaMenuArt.STEEL_GOLD)
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_color_override("font_outline_color", Color("071018"))
		title_lbl.add_theme_constant_override("outline_size", 3)

		var stars := ""
		for s_i in range(3):
			stars += "★" if s_i < next_r else "☆"
		var star_lbl := label(b, "%s  Lv.%d" % [stars, next_r], Rect2(16, 100, 264, 24), 16, Color("ffe478") if will_evo else ArenaMenuArt.STEEL_CYAN)
		star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		colour_block(b, Rect2(44, 130, 208, 1), Color(0.35, 0.65, 0.85, 0.35))

		var rtl := RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.scroll_active = false
		rtl.fit_content = false
		rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rtl.position = Vector2(18, 152)
		rtl.size = Vector2(260, 72)
		rtl.add_theme_font_size_override("normal_font_size", 18)
		rtl.add_theme_color_override("default_color", ArenaMenuArt.STEEL_TEXT)
		rtl.add_theme_color_override("font_outline_color", Color("071018"))
		rtl.add_theme_constant_override("outline_size", 1)
		rtl.text = "[center]" + str(offer.get("tagline", "")) + "[/center]"
		b.add_child(rtl)

		var mtex := ArenaMenuArt.passive_medal(pid)
		if mtex != null:
			var medal := image(wrap, mtex, Rect2(100, -48, 96, 96))
			medal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var detail_btn := steel_btn(wrap, "详情", Rect2(96, 294, 104, 34), func():
			_toggle_passive_detail(detail_popover, offer)
		, "steel", 14)
		detail_btn.name = "PassiveDetail_" + pid
		detail_btn.z_index = 2

	_passive_lock_lbl = label(modal, "防误触解锁中…请先确认卡牌效果", Rect2(560, 602, 480, 22), 14, GOLD)
	_passive_lock_lbl.name = "PassiveLockLabel"
	_passive_lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_passive_lock_bar = meter(modal, Rect2(560, 626, 480, 8), GOLD)
	_passive_lock_bar.name = "PassiveLockBar"
	_passive_lock_bar.max_value = 550.0
	_passive_lock_bar.value = 0.0
	modal.add_child(detail_popover)

func show_pause() -> void:
	if not game.passive_offers.is_empty() or game.game_over:
		return
	if has_modal():
		resume()
		return
	get_tree().paused = true
	close_context()
	game.targeting_slot = -1
	game.rally_site = -1
	var panel := modal_panel(Vector2(880, 560))
	label(panel, "战 术 手 册", Rect2(30, 22, 820, 40), 28, ArenaMenuArt.STEEL_GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tower_hint := "选中塔位可建造或升级" if game.tower_lab else "金币足够时，已建成的塔会自动升阶并解锁专精强化"
	label(panel, "按 H 或 Esc 继续 · " + tower_hint, Rect2(30, 62, 820, 24), 13, ArenaMenuArt.STEEL_MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var left := sub_card(panel, Rect2(28, 94, 404, 370), false)
	ArenaMenuArt.obsidian_panel(left, true)
	label(left, "双域操控与快捷键", Rect2(24, 16, 230, 28), 18, ArenaMenuArt.STEEL_GOLD)
	var kb_btn := steel_btn(left, "设置", Rect2(280, 14, 100, 30), func():
		frontend.settings(true)
	, "steel", 13)
	kb_btn.name = "OpenSettingsFromPause"
	var d_lbl := game.campaign.keybind_label("dodge")
	var p_lbl := game.campaign.keybind_label("portal")
	var r_lbl := game.campaign.keybind_label("recall")
	keycap(left, "WASD / 右键", Rect2(24, 52, 112, 26), ArenaMenuArt.STEEL_GOLD)
	label(left, "走位 · " + ("左键攻击" if game.feel_lab or game.tower_lab else "自动攻击附近敌人"), Rect2(146, 54, 232, 24), 14, ArenaMenuArt.STEEL_TEXT)
	keycap(left, d_lbl, Rect2(24, 84, 112, 26), ArenaMenuArt.STEEL_CYAN)
	label(left, "短距闪避并短暂无敌", Rect2(146, 86, 232, 24), 14, ArenaMenuArt.STEEL_TEXT)
	if game.rift_domain != null:
		keycap(left, p_lbl + " / " + r_lbl, Rect2(24, 116, 112, 26), GOLD)
		label(left, "进裂隙 / 回防 · [F] 召波或下潜", Rect2(146, 118, 240, 24), 13, ArenaMenuArt.STEEL_TEXT)
	colour_block(left, Rect2(24, 152, 356, 1), Color(ArenaMenuArt.STEEL_MUTED, 0.28))
	for slot in range(2):
		var y_off := 166 + slot * 98
		var sk_name := str(game.hero.data.small if slot == 0 else game.hero.data.ultimate)
		var unlocked := game.hero.skill_unlocked(slot)
		var badge_box := Panel.new()
		badge_box.position = Vector2(24, y_off)
		badge_box.size = Vector2(56, 56)
		badge_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ArenaMenuArt.obsidian_panel(badge_box, true)
		left.add_child(badge_box)
		image(badge_box, ArenaMenuArt.skill(game.hero.class_id, slot), Rect2(5, 5, 46, 46))
		keycap(left, "Q" if slot == 0 else "E", Rect2(90, y_off, 26, 24), ArenaMenuArt.STEEL_GOLD)
		label(left, sk_name + (" (已解锁)" if unlocked else " (%d级解锁)" % ArenaDefinitions.SKILL_UNLOCK_LEVELS[slot]), Rect2(122, y_off, 258, 26), 16, ArenaMenuArt.STEEL_TEXT if unlocked else ArenaMenuArt.STEEL_MUTED)
		var sk_desc := label(left, ArenaDefinitions.skill_text(game.hero.class_id, slot, game.hero.passive_rank), Rect2(90, y_off + 28, 290, 62), 12, ArenaMenuArt.STEEL_MUTED)
		sk_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var right := sub_card(panel, Rect2(448, 94, 404, 370), false)
	ArenaMenuArt.obsidian_panel(right, true)
	var owned := game.passive_engine.owned_list() if game.passive_engine != null else []
	var has_rift := game.rift_domain != null
	label(right, "已选被动 · %d/%d" % [game.passive_engine.picks_taken,ArenaPassiveEngine.MAX_TOTAL_PICKS] if has_rift else "练习模式", Rect2(24, 16, 352, 28), 18, ArenaMenuArt.STEEL_GOLD)
	label(right, "升级后按 [Tab] 三选一。探索裂隙可收集遗物。" if has_rift else "在战役中可获得局内被动与裂隙遗物。", Rect2(24, 46, 356, 42), 13, ArenaMenuArt.STEEL_MUTED).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	colour_block(right, Rect2(24, 96, 356, 1), Color(ArenaMenuArt.STEEL_MUTED, 0.28))
	if owned.is_empty():
		if has_rift:
			label(right, "尚未选择被动 · 进入裂隙拾取经验晶石", Rect2(24, 114, 356, 28), 14, ArenaMenuArt.STEEL_MUTED)
	else:
		var scroll := ScrollContainer.new()
		scroll.position = Vector2(18, 106)
		scroll.size = Vector2(368, 250)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		right.add_child(scroll)
		var list_box := VBoxContainer.new()
		list_box.add_theme_constant_override("separation", 6)
		scroll.add_child(list_box)
		for it in owned:
			var row := Panel.new()
			row.custom_minimum_size = Vector2(352, 64)
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ArenaMenuArt.obsidian_panel(row, false)
			var mtex := ArenaMenuArt.passive_medal(str(it.id))
			if mtex != null:
				var mi := image(row, mtex, Rect2(10, 14, 36, 36))
				mi.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			label(row, "%s  Lv.%d" % [str(it.name), int(it.rank)], Rect2(54, 6, 220, 22), 14, GOLD if bool(it.evo) else ArenaMenuArt.STEEL_GOLD)
			label(row, "★超武" if bool(it.evo) else str(it.category), Rect2(276, 8, 66, 18), 11, ArenaMenuArt.STEEL_CYAN).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			var sum_lbl := label(row, str(it.summary), Rect2(54, 30, 288, 28), 11, CREAM)
			sum_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			list_box.add_child(row)

	var resume_button := steel_btn(panel, "继续守望", Rect2(156, 486, 264, 50), resume, "cyan", 18)
	var exit_button := steel_btn(panel, "返回地图", Rect2(460, 486, 264, 50), _confirm_leave, "steel", 18)
	exit_button.name = "LeaveBattle"
	for b in [kb_btn,resume_button,exit_button]:b.focus_mode = Control.FOCUS_ALL
	focus_dialog(resume_button)

func _confirm_leave() -> void:
	var panel := modal_panel(Vector2(560,238))
	_leave_confirmation = panel
	label(panel,"结束本局并返回地图？",Rect2(24,22,512,44),26,GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(panel,"本局进度和奖励将不会保存。",Rect2(24,78,512,32),18,MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var keep := steel_btn(panel,"继续本局",Rect2(28,150,232,56),_back_to_pause,"cyan",18)
	keep.name = "CancelLeaveBattle"
	var leave := steel_btn(panel,"结束本局",Rect2(300,150,232,56),game.return_to_menu,"steel",18)
	leave.name = "ConfirmLeaveBattle"
	for b in [keep,leave]:b.focus_mode = Control.FOCUS_ALL
	focus_dialog(keep)

func _back_to_pause() -> void:
	_leave_confirmation = null
	close_modal()
	show_pause()

func resume() -> void:
	if not game.passive_offers.is_empty():
		return
	if not game.active_event_offer.is_empty():
		game.close_rift_event_without_use()
		return
	get_tree().paused = false
	close_modal()
	game.suppress_primary = Input.is_action_pressed("shoot")
	game.pump_modals()

func show_result() -> void:
	close_context()
	var panel := modal_panel(Vector2(760, 492))
	label(panel, "防线守住了" if game.victory else "信标失守", Rect2(30, 24, 700, 50), 34, ArenaMenuArt.STEEL_GOLD if game.victory else Color("f28b82")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var card := sub_card(panel, Rect2(34, 86, 692, 292), false)
	ArenaMenuArt.obsidian_panel(card, true)
	label(card, "本局战报", Rect2(28, 16, 200, 28), 18, ArenaMenuArt.STEEL_GOLD)
	colour_block(card, Rect2(28, 50, 636, 1), Color(ArenaMenuArt.STEEL_MUTED, 0.28))
	label(card, "抵达轮次", Rect2(28, 70, 150, 24), 14, ArenaMenuArt.STEEL_MUTED)
	label(card, str(game.cycle) + " / " + str(game.total_waves()), Rect2(28, 96, 150, 32), 24, ArenaMenuArt.STEEL_TEXT)
	label(card, "击败敌人", Rect2(256, 70, 150, 24), 14, ArenaMenuArt.STEEL_MUTED)
	label(card, str(game.kills), Rect2(256, 96, 150, 32), 24, ArenaMenuArt.STEEL_TEXT)
	var run_lv := game.passive_engine.run_level if game.passive_engine != null else 1
	label(card, "局内等级", Rect2(484, 70, 150, 24), 14, ArenaMenuArt.STEEL_MUTED)
	label(card, "Lv." + str(run_lv), Rect2(484, 96, 150, 32), 24, ArenaMenuArt.STEEL_GOLD)
	label(card, "建造 %d 座防御塔   ·   核心耐久 %d" % [game.built, ceili(game.core_health)], Rect2(28, 154, 636, 28), 17, ArenaMenuArt.STEEL_MUTED)
	colour_block(card, Rect2(28, 198, 636, 1), Color(ArenaMenuArt.STEEL_MUTED, 0.25))
	image(card, ArenaMenuArt.utility("diamond"), Rect2(28, 218, 32, 32))
	var saved := bool(game.settlement.get("ok", false))
	var save_button: Button
	label(card, ("+" + str(game.settlement.get("amount", 0)) + " 钻石    总计 " + str(game.campaign.gems())) if saved else "奖励尚未保存", Rect2(72, 218, 400, 32), 20, ArenaMenuArt.STEEL_GOLD if saved else Color("f28b82"))
	if not saved:
		save_button = steel_btn(card, "重试保存", Rect2(504, 214, 160, 40), game.retry_settlement, "gold", 16)
		save_button.name = "RetrySave"
		save_button.focus_mode = Control.FOCUS_ALL
	var hall := steel_btn(panel, "英雄养成", Rect2(34, 404, 204, 56), game.open_hero_hall, "steel", 18)
	hall.name = "ResultHeroHall"
	var retry := steel_btn(panel, "再次出战", Rect2(278, 404, 204, 56), game.restart_run, "cyan", 18)
	retry.name = "RetryRun"
	var exit_button := steel_btn(panel, "返回地图", Rect2(522, 404, 204, 56), game.return_to_menu, "steel", 18)
	for b in [hall,retry,exit_button]:b.focus_mode = Control.FOCUS_ALL
	focus_dialog(retry if saved else save_button)

func objective_state() -> Dictionary:
	if game.built == 0:
		return {"step": "守望指引 · 1 / 3", "title": "部署第一座自动控场塔", "body": "点击道路旁的金色塔位建造。金币足够时，已建成的塔会自动升级。"}
	if game.phase == "rest" and game.cycle == 1:
		return {"step": "守望指引 · 2 / 3", "title": "侦察或进入裂隙发育", "body": "点击怪物图标开轮，或按 T 进裂隙割草拿被动。"}
	if game.cycle == 1:
		return {"step": "守望指引 · 3 / 3", "title": "双域联动防守", "body": "裂隙清剿升级后按 R 瞬回防线震击敌群！"}
	if game.phase == "rest":
		return {"step": "整备阶段", "title": "补强防线，准备第 " + str(game.cycle) + " 轮", "body": "可建新塔或提前开轮获取额外金币。"}
	return {"step": "双域交锋", "title": "守住第 " + str(game.cycle) + " 轮", "body": "注意顶部防御雷达，红框警报时随时按 R 回防。"}

func refresh_objective() -> void:
	if not is_instance_valid(objective):
		return
	if not tutorial_finished and game.built > 0 and game.hero.shots > 0 and game.phase != "rest":
		tutorial_finished = true
		game.campaign.complete_tutorial()
	objective.visible = game.can_manage_defense() and not has_modal() and game.passive_offers.is_empty() and not tutorial_finished and not bool(game.campaign.data.get("tutorial_done", false)) and game.cycle == 1 and game.built == 0
	var state := objective_state()
	var signature: String = str(state.step) + str(state.title)
	if signature != last_objective:
		last_objective = signature
		objective_step.text = state.step
		objective_title.text = state.title
		objective_body.text = state.body

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_passive_require_release = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not game.started and not has_modal() and is_instance_valid(frontend.stage_panel):
			if not frontend.stage_panel.get_global_rect().has_point(event.position):
				frontend.close_stage()
		if is_instance_valid(owned_passive_popover) and owned_passive_popover.visible:
			var inside_pop := owned_passive_popover.get_global_rect().has_point(event.position)
			var inside_bar := is_instance_valid(owned_passives_box) and owned_passives_box.get_global_rect().has_point(event.position)
			var inside_rel := is_instance_valid(owned_relics_box) and owned_relics_box.get_global_rect().has_point(event.position)
			if not inside_pop and not inside_bar and not inside_rel:
				owned_passive_popover.hide()
				_open_owned_id = ""
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if game.game_over:
		return
	if not game.active_event_offer.is_empty():
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			if is_event_input_locked():
				get_viewport().set_input_as_handled()
				return
			game.choose_rift_event(event.keycode - KEY_1)
		elif event.keycode == KEY_ESCAPE:
			game.close_rift_event_without_use()
		get_viewport().set_input_as_handled()
		return
	if not game.passive_offers.is_empty():
		if event.keycode in [KEY_1, KEY_2, KEY_3]:
			if is_passive_input_locked():
				get_viewport().set_input_as_handled()
				return
			var index: int = event.keycode - KEY_1
			if index < game.passive_offers.size():
				game.choose_passive(str(game.passive_offers[index].id))
		elif event.keycode == KEY_ESCAPE and is_instance_valid(modal):
			var pop := modal.get_node_or_null("PassiveDetailPopover") as Control
			if pop != null and pop.visible:
				pop.hide()
				_open_passive_detail = ""
		get_viewport().set_input_as_handled()
		return
	if not game.started:
		if event.keycode == KEY_ESCAPE:
			frontend.escape()
			get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_TAB and not has_modal() and not game.portal_transition_active() and game.open_pending_passive_choice():
		get_viewport().set_input_as_handled()
		return
	if event.keycode in [KEY_H,KEY_ESCAPE] and frontend.settings_open():
		frontend.close_settings()
		get_viewport().set_input_as_handled()
		return
	if event.keycode in [KEY_H,KEY_ESCAPE] and is_instance_valid(_leave_confirmation) and _leave_confirmation.get_parent() == modal:
		_back_to_pause()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_H or (event.keycode == KEY_ESCAPE and has_modal() and not game.game_over):
		if has_modal():
			resume()
		else:
			show_pause()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_refresh_order_hint(delta)
	var reduced := bool(game.campaign.data.reduced_motion)
	if unlock_clock > 0:
		unlock_clock -= delta
	if is_instance_valid(unlock_hint):
		var warping := game.rift_domain != null and game.rift_domain.warp_phase != ""
		unlock_hint.visible = unlock_clock > 0 and game.active_domain == "defense" and not warping and not game.wave_preview and not has_modal() and game.passive_offers.is_empty()

	if game.started and game.rift_domain != null:
		if is_instance_valid(alarm_vignette):
			var rd := game.rift_domain
			var show_vig := game.active_domain == "rift" and (rd.alarm_level >= 1 or rd.core_hit_alert > 0.0)
			if show_vig:
				var pulse := 0.70 if reduced else 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.008)
				alarm_vignette.critical = rd.alarm_level >= 2 or rd.core_hit_alert > 0.0
				alarm_vignette.intensity = (0.45 + 0.55 * pulse) if alarm_vignette.critical else (0.35 + 0.30 * pulse)
			else:
				alarm_vignette.intensity = 0.0
			alarm_vignette.queue_redraw()
		if is_instance_valid(transition_veil):
			var p_iris := game.rift_domain.iris_progress if game.rift_domain != null else 0.0
			if transition_veil.material is ShaderMaterial:
				var sm := transition_veil.material as ShaderMaterial
				sm.set_shader_parameter("progress", p_iris)
				sm.set_shader_parameter("reduced_motion", reduced)
				var f_uv := Vector2(0.5, 0.5)
				if p_iris > 0.005 and game.rift_domain != null:
					var wpt: Vector2 = game.hero.position if is_instance_valid(game.hero) else game.rift_domain.defense_portal_pos
					var spt: Vector2 = game.get_viewport().get_canvas_transform() * wpt
					var vsz := Vector2(get_viewport().get_visible_rect().size)
					if vsz.x > 1.0 and vsz.y > 1.0:
						f_uv = (spt / vsz).clamp(Vector2(0.08, 0.08), Vector2(0.92, 0.92))
				sm.set_shader_parameter("focal_uv", f_uv)
			else:
				transition_veil.color = Color(0.05, 0.08, 0.16, p_iris * 0.85)
		if is_instance_valid(rift_minimap):
			var show_mm := game.active_domain == "rift" and not has_modal()
			rift_minimap.visible = show_mm
			if show_mm:
				rift_minimap.queue_redraw()
				if is_instance_valid(rift_map_title):
					var rd := game.rift_domain
					rift_map_title.text = "F%d %s · %d/%d轮" % [rd.floor_index, str(rd.layout.get("short", "秘境")), game.cycle, game.total_waves()]
				if is_instance_valid(rift_map_footer) and game.passive_engine != null:
					rift_map_footer.text = "探索 %d/%d · 被动 %d/%d" % [game.rift_domain.cleared_count(), game.rift_domain.total_explore_rooms(), game.passive_engine.picks_taken, ArenaPassiveEngine.MAX_TOTAL_PICKS]
		if is_instance_valid(descent_badge):
			var show_desc := game.active_domain == "rift" and game.rift_domain.can_descend_now() and not has_modal() and game.passive_offers.is_empty() and game.active_event_offer.is_empty()
			descent_badge.visible = show_desc
			if show_desc:
				descent_badge.text = "▼ 深层跃迁门已开 · 按 [F] 下潜第%d层" % (game.rift_domain.floor_index + 1)
		var in_def_clean := game.active_domain == "defense" and game.can_manage_defense() and not has_modal()
		if is_instance_valid(next_wave_btn):
			next_wave_btn.visible = in_def_clean
		if is_instance_valid(wave_label):
			wave_label.visible = game.active_domain == "defense" and not has_modal()

	if not game.active_event_offer.is_empty() and is_instance_valid(_event_lock_bar):
		var elocked := is_event_input_locked()
		var erem := maxf(0.0, float(_event_unlock_msec - Time.get_ticks_msec()))
		_event_lock_bar.visible = elocked
		_event_lock_bar.value = clampf(450.0 - erem, 0.0, 450.0)
		if is_instance_valid(_event_lock_lbl):
			_event_lock_lbl.visible = elocked
			_event_lock_lbl.text = "防误触保护 · 请松开鼠标后再选" if _passive_require_release and erem <= 0.0 else "防误触解锁中…请先确认事件抉择"

	if not game.passive_offers.is_empty() and is_instance_valid(_passive_lock_bar):
		var locked_now := is_passive_input_locked()
		var rem_ms := maxf(0.0, float(_passive_unlock_msec - Time.get_ticks_msec()))
		_passive_lock_bar.visible = locked_now
		_passive_lock_bar.value = clampf(550.0 - rem_ms, 0.0, 550.0)
		if is_instance_valid(_passive_lock_lbl):
			_passive_lock_lbl.visible = locked_now
			_passive_lock_lbl.text = "防误触保护 · 请松开鼠标后再选" if _passive_require_release and rem_ms <= 0.0 else "防误触解锁中…请先确认卡牌效果"

	if is_instance_valid(passive_ready_badge) and game.passive_engine != null:
		var pend := game.passive_engine.pending_ups
		var show_badge := game.started and pend > 0 and not has_modal() and not game.game_over
		passive_ready_badge.visible = show_badge
		if show_badge:
			_passive_badge_pulse = maxf(0.0, _passive_badge_pulse - delta)
			var bounce := 1.0 if reduced else 1.0 + 0.045 * sin(float(Time.get_ticks_msec()) * 0.008) + (_passive_badge_pulse * 0.06)
			passive_ready_badge.pivot_offset = passive_ready_badge.size * 0.5
			passive_ready_badge.scale = Vector2.ONE * bounce
			passive_ready_badge.text = "★ 进化就绪 (×%d) · 按 [Tab] 开启" % pend

	update_clock -= delta
	if update_clock > 0 or not game.started or hero_health == null:
		return
	update_clock = 0.08
	refresh_owned_passives()
	refresh_owned_relics()
	refresh_radar()
	refresh_keybind_labels()

	var h: ArenaHero = game.hero
	if not is_instance_valid(h):
		return
	hero_badge.tooltip_text = "英雄养成 Lv." + str(h.meta_level)
	hero_health.max_value = h.max_health
	hero_health.value = h.health
	hero_health.tooltip_text = str(int(h.health)) + " / " + str(int(h.max_health))
	hero_level.text = "养成" + str(h.meta_level)
	if is_instance_valid(xp_bar) and game.passive_engine != null:
		var pe := game.passive_engine
		if pe.is_maxed_out():
			xp_bar.max_value = ArenaPassiveEngine.OVERFLOW_XP_STEP
			xp_bar.value = pe.overflow_xp
			xp_bar.tooltip_text = "满级溢流 · 每 %d XP 兑换 %d 金币和至多 %d 基地圣盾" % [ArenaPassiveEngine.OVERFLOW_XP_STEP,ArenaPassiveEngine.OVERFLOW_GOLD,ArenaPassiveEngine.OVERFLOW_SHIELD]
			if pe.pending_ups > 0:
				xp_bar.tooltip_text += "\n还有 %d 次升级待选择 [Tab]" % pe.pending_ups
		else:
			xp_bar.max_value = maxf(1.0, pe.xp_needed())
			xp_bar.value = pe.run_xp
			xp_bar.tooltip_text = "局内升级经验：%d / %d（已选 %d/%d）" % [int(pe.run_xp), int(pe.xp_needed()), pe.picks_taken, ArenaPassiveEngine.MAX_TOTAL_PICKS]
	if is_instance_valid(run_lv_label) and game.passive_engine != null:
		run_lv_label.text = "满级溢流" if game.passive_engine.is_maxed_out() else ("Lv." + str(game.passive_engine.run_level))
	core_health.max_value = game.core_max
	core_health.value = game.core_health
	core_health.tooltip_text = "%d / %d  (护盾 %d)" % [int(game.core_health), int(game.core_max), int(game.core_shield)]
	if is_instance_valid(core_shield_bar):
		core_shield_bar.max_value = ArenaGame.CORE_SHIELD_MAX
		core_shield_bar.value = game.core_shield
	if context.visible:
		var tower := game.site_tower(game.selected_site)
		var allowed := game.can_change_towers()
		if tower == null:
			var available := game.available_towers()
			for child in context.get_children():
				if child is Button and child.has_meta("required_gold"):
					var shortfall := int(child.get_meta("required_gold"))-game.gold
					var key := str(child.get_meta("tower_kind",""))
					var unavailable := not key.is_empty() and key not in available
					child.disabled = not allowed or shortfall > 0 or unavailable
					var reason := "\n第 %d 波可建" % int(game.level_definition.towers.get(key,1)) if unavailable else ("\n还需 %d 金币" % shortfall if shortfall > 0 else "")
					child.tooltip_text = str(child.get_meta("base_tip",""))+reason
		elif is_instance_valid(tower_purchase):
			_sync_tower_purchase(allowed and not tower.is_sealed() and tower.project_level == 0)
	if is_instance_valid(next_wave_btn):
		var show_nw := game.active_domain == "defense" and game.can_manage_defense() and not has_modal()
		next_wave_btn.visible = show_nw
		if show_nw:
			var nw := game.next_wave_button_state()
			next_wave_btn.disabled = not bool(nw.enabled)
			next_wave_btn.text = str(nw.label)
			next_wave_btn.tooltip_text = str(nw.tip)
			var mode_s := str(nw.mode)
			var tone_s := "gold" if mode_s in ["rest", "stack_next"] else ("cyan" if mode_s == "fast_siege" else "steel")
			if next_wave_btn.get_meta("nw_tone", "") != tone_s:
				next_wave_btn.set_meta("nw_tone", tone_s)
				ArenaMenuArt.steel_button(next_wave_btn, tone_s)
				next_wave_btn.add_theme_font_size_override("font_size", 12)
	coins.text = str(game.gold)
	revival.text = str(int(ceil(h.revive_clock))) if h.knocked_out else ""
	hero_badge.modulate = Color(0.6, 0.6, 0.6) if h.knocked_out else Color.WHITE

	for slot in range(2):
		var unlocked := h.skill_unlocked(slot)
		skills[slot].disabled = not h.can_cast(slot) or has_modal() or game.portal_transition_active()
		var unlock_level: int = ArenaDefinitions.SKILL_UNLOCK_LEVELS[slot]
		skills[slot].text = (str(ceili(h.cooldowns[slot])) if h.cooldowns[slot] > 0 else "") if unlocked else "%d级" % unlock_level
		skills[slot].tooltip_text = (str(h.data.small if slot == 0 else h.data.ultimate) + "\n" + ArenaDefinitions.skill_text(h.class_id, slot, h.passive_rank)) if unlocked else "英雄养成至 %d 级解锁" % unlock_level
		skill_glyphs[slot].progress = 1.0 - clampf(h.cooldowns[slot] / maxf(0.01,h.cooldown_totals[slot]),0.0,1.0) if unlocked else 0.0
		skill_glyphs[slot].modulate.a = 0.18 if not unlocked else (0.45 if h.cooldowns[slot] > 0 else 1.0)
		skill_glyphs[slot].queue_redraw()
	if is_instance_valid(dodge_button):
		dodge_button.disabled = not h.can_dodge() or has_modal() or game.portal_transition_active()
		dodge_button.text = str(int(ceil(h.dodge_cooldown))) if h.dodge_cooldown > 0.0 else ""
		dodge_glyph.progress = 1.0 - clampf(h.dodge_cooldown / maxf(0.01,h.dodge_cooldown_total), 0.0, 1.0)
		dodge_glyph.modulate.a = 0.42 if h.dodge_cooldown > 0.0 else 1.0
		dodge_glyph.queue_redraw()
	if is_instance_valid(portal_button) and game.rift_domain != null:
		var in_def := game.active_domain == "defense"
		var pcd := game.rift_domain.portal_cooldown if in_def else 0.0
		portal_button.disabled = domain_switch_btn.disabled
		portal_button.text = str(ceili(pcd)) if pcd > 0.0 else ""
		portal_glyph.progress = 1.0 - clampf(pcd / ArenaRiftDomain.PORTAL_COOLDOWN, 0.0, 1.0) if in_def else 1.0
		portal_glyph.tint = Color("7fe8ff") if in_def else GOLD
		portal_glyph.modulate.a = 0.45 if pcd > 0.0 else 1.0
		portal_glyph.queue_redraw()

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
			elif active_b.kind == "leviathan" and active_b.boss_phase >= 1:
				phase_lbl = " · 触手封塔" if active_b.boss_phase >= 2 else " · 深渊狂怒"
			elif active_b.kind == "baj_nimen" and active_b.boss_phase >= 1:
				phase_lbl = " · 裂隙跃迁" if active_b.boss_phase >= 2 else " · 星落护盾"
			boss_title.text = "%s · %s%s" % [str(active_b.data.name), tier_lbl, phase_lbl]
			boss_meter.max_value = active_b.max_health
			boss_meter.value = active_b.health
			boss_hp_text.text = "%d / %d" % [int(ceil(active_b.health)), int(ceil(active_b.max_health))]
			var show_ticks := active_b.kind in ["two_headed_troll", "leviathan", "baj_nimen", "moth"]
			for t_node in boss_ticks:
				t_node.visible = show_ticks
		else:
			boss_bar_panel.hide()

	if is_instance_valid(bridge_button) and not game.bridge_gate_config.is_empty():
		var b_ready := not game.bridge_sealed and game.bridge_cooldown <= 0.0 and not game.game_over
		bridge_button.position = game.world_to_hud(game.bridge_gate_point()) + Vector2(-22, 36)
		bridge_button.visible = game.active_domain == "defense" and Rect2(0, 80, 1556, 760).has_point(bridge_button.position)
		bridge_button.disabled = not b_ready
		bridge_meter.max_value = game.BRIDGE_SEAL_DURATION if game.bridge_sealed else game.BRIDGE_COOLDOWN_DURATION
		bridge_meter.value = game.bridge_active_clock if game.bridge_sealed else (game.BRIDGE_COOLDOWN_DURATION - game.bridge_cooldown)
		bridge_label.text = ("封锁 %ds" % int(ceil(game.bridge_active_clock))) if game.bridge_sealed else (("CD %ds" % int(ceil(game.bridge_cooldown))) if game.bridge_cooldown > 0.0 else "★ 就绪")
		bridge_label.modulate = Color("7fe8ff") if game.bridge_sealed else (GOLD if b_ready else MUTED)

	if context.visible and game.selected_site >= 0:
		var anchor := game.world_to_hud(game.level_definition.sites[game.selected_site])
		_position_tower_context(anchor)

	var total_w := game.total_waves()
	wave_label.visible = game.active_domain == "defense" and not has_modal()
	wave_label.text = str(game.cycle) + " / " + str(total_w)
	wave_button.disabled = not game.can_preview_wave()
	if is_instance_valid(breach_notice) and game.siege != null:
		breach_notice.visible = game.active_domain == "defense" and game.siege.warned and (not game.siege.opened or game.siege.warning_clock > 0.0)
	phase_label.text = ("整备 · " + str(int(ceil(game.phase_clock))) + " 秒" if game.phase == "rest" else "敌军来袭")
	var wave_data := game.wave_pattern()
	var lead := int(wave_data.get("lead", 0))
	lead = maxi(0, lead)
	var entry: Vector2 = game.world_to_hud(game.level_definition.routes[lead][0])
	var button_pos := Vector2(clampf(entry.x, 20, 1530), clampf(entry.y, 94, 770))
	var defense_visible := game.can_preview_wave() and not has_modal()
	wave_button.position = button_pos
	wave_button.visible = game.phase == "rest" and not game.game_over and defense_visible
	wave_button.tooltip_text = "%d / %d · %ds\n%s" % [game.cycle,total_w,ceili(game.phase_clock),("提前开轮 · +%d 金币" % game.preview_wave_bonus()) if game.wave_preview else "预览本轮兵力"]
	wave_glyph.progress = game.phase_clock / game.rest_duration if game.phase == "rest" else 1.0
	wave_glyph.tint = GOLD if game.wave_preview else CREAM
	wave_glyph.queue_redraw()
	refresh_objective()
	var show_preview: bool = game.wave_preview and defense_visible
	if preview.visible != show_preview:
		preview.visible = show_preview
		if preview.visible:
			clear_children(preview)
			var profile := ArenaLevelCatalog.preview_profile(game.wave_packets(wave_data),game.cycle)
			var pool: Array = profile.kinds
			var has_fly := bool(profile.get("has_flying", false))
			var pw := maxi(374, 16 + mini(6, pool.size()) * 61)
			preview.size = Vector2(pw, 124)
			for index in range(mini(6, pool.size())):
				var eid := str(pool[index])
				var artwork := ArenaMenuArt.creature(eid)
				if artwork != null:
					var img := image(preview, artwork, Rect2(8 + index * 61, 6, 56, 56))
					img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					img.mouse_filter = Control.MOUSE_FILTER_PASS
					var edata := ArenaDefinitions.enemy(eid)
					var etrait := str(edata.get("trait", ""))
					img.tooltip_text = str(edata.name) + ("\n" + etrait if etrait != "" else "")
			label(preview, "计划 %d 敌 · %d 种 · %d 精英%s" % [profile.count,pool.size(),profile.elites," · 含飞行单位" if has_fly else ""], Rect2(10, 68, pw - 20, 24), 14, MUTED)
			label(preview, "按生命计 · 重甲 %d%% · 高法抗 %d%%" % [roundi(profile.heavy*100.0),roundi(profile.high_res*100.0)], Rect2(10, 94, pw - 20, 22), 13, CREAM)
	preview.position = Vector2(clampf(button_pos.x + 54, 12, 1588 - preview.size.x), clampf(button_pos.y, 86, 888 - preview.size.y))
