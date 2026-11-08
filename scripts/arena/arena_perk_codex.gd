class_name ArenaPerkCodex
extends Control
# 被动星图：v0.7 设计预览（只读图鉴，不参与战斗结算）。

signal closed

const GRAPH_SCALE := 0.74
const GRAPH_ORIGIN := Vector2(14, 52)
const AXIS_LABEL := {"blade":"锋刃","star":"星火","bulwark":"壁垒","command":"号令","bridge":"桥接",
	"knight":"骑士","ranger":"游侠","mage":"法师","evo":"进化"}
const RARITY_LABEL := {"common":"普通","rare":"稀有","epic":"史诗","evo":"进化"}
const EDGE_COLOR := {"amplify":Color("e9c588"),"trigger":Color("7fd4c1"),"convert":Color("b9a7ff"),"require":Color("f2d27a")}
const EDGE_NAME := {"amplify":"强化","trigger":"触发","convert":"转化","require":"门槛"}

var hover_id := ""
var selected_id := ""
var title_label: Label
var meta_label: Label
var body_text: RichTextLabel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var head := Label.new()
	head.text = "被动星图 · v0.7 设计预览"
	head.position = Vector2(24, 12)
	head.add_theme_font_size_override("font_size", 24)
	head.add_theme_color_override("font_color", Color("e9c588"))
	add_child(head)
	var sub := Label.new()
	sub.text = "40 张卡 · 37 条连接（全部实装） · 12 条进化门槛 · 6 星座 · 8 套装"
	sub.position = Vector2(26, 44)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Color("a9b3a4"))
	add_child(sub)
	_build_panel()
	_show_overview()
	queue_redraw()

func _build_panel() -> void:
	var panel := Panel.new()
	panel.position = Vector2(1212, 16)
	panel.size = Vector2(372, 868)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("16241f")
	style.border_color = Color("2c4038")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var box := VBoxContainer.new()
	box.position = Vector2(14, 12)
	box.size = Vector2(344, 844)
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	title_label = Label.new()
	title_label.text = "被动星图"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color("e9c588"))
	box.add_child(title_label)
	meta_label = Label.new()
	meta_label.text = "点节点查看每级效果与连接"
	meta_label.add_theme_font_size_override("font_size", 12)
	meta_label.add_theme_color_override("font_color", Color("a9b3a4"))
	box.add_child(meta_label)
	body_text = RichTextLabel.new()
	body_text.bbcode_enabled = true
	body_text.fit_content = false
	body_text.scroll_active = true
	body_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_text.add_theme_font_size_override("normal_font_size", 14)
	box.add_child(body_text)
	var close := Button.new()
	close.name = "关闭图鉴"
	close.text = "关闭图鉴"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(_close)
	box.add_child(close)

func _show_overview() -> void:
	title_label.text = "被动星图"
	meta_label.text = "点节点查看每级效果与连接"
	body_text.text = "[b]这是什么[/b]\n\n" \
		+ "v0.7 的被动网络设计：34 张池内卡、6 张进化，用 37 条显式连接串成 6 个星座。\n\n" \
		+ "· 金线 = 强化，青虚 = 触发，紫点 = 转化，淡金 = 进化门槛\n" \
		+ "· 点任意节点看 R1/R2/R3 与它的全部连接\n" \
		+ "· 37 条联动已全部按行为或条件实现\n\n" \
		+ "[color=#a9b3a4]完整设计见 docs/DESIGN_PASSIVES_V3_LINKS.md；交互版见 docs/passives-network.html。[/color]"

func _show_card(id: String) -> void:
	var card := ArenaPerkNetwork.card(id)
	if card.is_empty():
		return
	title_label.text = str(card.name)
	meta_label.text = "%s · %s · 上限 %d" % [AXIS_LABEL.get(card.axis, card.axis), RARITY_LABEL.get(card.rarity, card.rarity), int(card.max)]
	var text := ""
	for index in range(card.ranks.size()):
		text += "[color=#e9c588]R%d[/color]  %s\n" % [index + 1, str(card.ranks[index])]
	text += "\n[color=#a9b3a4]连接[/color]\n"
	var links := ArenaPerkNetwork.links_to(id)
	if links.is_empty():
		text += "无\n"
	for edge in links:
		var other_id: String = edge.to if edge.from == id else edge.from
		var other := ArenaPerkNetwork.card(other_id)
		var arrow: String = "→" if edge.from == id else "←"
		var tag: String = "已实现"
		text += "[color=#e9c588]%s[/color] %s %s [%s]：%s\n" % [EDGE_NAME.get(edge.type, edge.type), arrow, str(other.get("name", other_id)), tag, str(edge.text)]
	var set_names: Array[String] = []
	for item in ArenaPerkNetwork.SETS:
		if item.has("members") and id in item.get("members", []):
			set_names.append(str(item.name))
		elif item.has("axis") and str(item.axis) == str(card.axis):
			set_names.append(str(item.name))
	if not set_names.is_empty():
		text += "\n[color=#a9b3a4]套装[/color]\n" + "、".join(set_names) + "\n"
	body_text.text = text

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color("0b1512"))
	# 星座光晕与标题
	for cluster in ArenaPerkNetwork.CLUSTERS:
		var center := _screen(Vector2(float(cluster.x), float(cluster.y)))
		var radius: float = float(cluster.r) * GRAPH_SCALE
		var fill := Color(str(cluster.color))
		fill.a = 0.05
		draw_circle(center, radius, fill)
		var ring := Color(str(cluster.color))
		ring.a = 0.18
		draw_arc(center, radius, 0, TAU, 64, ring, 1.0, true)
		var label_y: float = center.y + radius + 22 if cluster.key == "expose" else center.y - radius - 10
		draw_string(font, Vector2(center.x - 110, label_y), str(cluster.label),
			HORIZONTAL_ALIGNMENT_CENTER, 220, 13, Color("7f9b88"))
	# 连线
	for edge in ArenaPerkNetwork.EDGES:
		var a := _screen(_card_pos(edge.from))
		var b := _screen(_card_pos(edge.to))
		var color: Color = EDGE_COLOR.get(edge.type, Color.WHITE)
		var hovered: bool = edge.from == hover_id or edge.to == hover_id or edge.from == selected_id or edge.to == selected_id
		if not hovered:
			color.a = 0.22 if edge.type == "require" else 0.5
		if edge.type == "require":
			draw_dashed_line(a, b, color, 1.4, 6.0)
		elif edge.type == "trigger":
			draw_dashed_line(a, b, color, 1.3, 4.0)
		elif edge.type == "convert":
			draw_dashed_line(a, b, color, 1.3, 2.0)
		else:
			draw_line(a, b, color, 1.3, true)
		if hovered:
			_arrow(a, b, color)
	# 节点
	for card in ArenaPerkNetwork.CARDS:
		var p := _screen(Vector2(float(card.x), float(card.y)))
		var radius: float = float(card.r) * GRAPH_SCALE
		var color := Color(str(card.color))
		draw_circle(p, radius, color)
		draw_arc(p, radius, 0, TAU, 32, Color("0d1714"), 1.6, true)
		var font_size := 10 if str(card.name).length() >= 3 else 11
		draw_string(font, Vector2(p.x - 40, p.y + 4), str(card.name),
			HORIZONTAL_ALIGNMENT_CENTER, 80, font_size, Color("10201a"))
		# 层数点
		var count: int = int(card.max)
		for index in range(count):
			var x := p.x + (index - (count - 1) * 0.5) * 7.0
			draw_circle(Vector2(x, p.y + radius + 6), 2.0, Color("6f866f"))
		if card.id == hover_id or card.id == selected_id:
			draw_arc(p, radius + 4, 0, TAU, 40, Color("fff4bf"), 2.0, true)

func _arrow(a: Vector2, b: Vector2, color: Color) -> void:
	var dir := (b - a).normalized()
	var perp := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([b, b - dir * 7 + perp * 3, b - dir * 7 - perp * 3]), color)

func _card_pos(id: String) -> Vector2:
	var card := ArenaPerkNetwork.card(id)
	if card.is_empty():
		return Vector2.ZERO
	return Vector2(float(card.x), float(card.y))

func _screen(point: Vector2) -> Vector2:
	return GRAPH_ORIGIN + point * GRAPH_SCALE

func _pick(position: Vector2) -> String:
	var world := (position - GRAPH_ORIGIN) / GRAPH_SCALE
	for card in ArenaPerkNetwork.CARDS:
		if world.distance_to(Vector2(float(card.x), float(card.y))) <= float(card.r) + 9:
			return str(card.id)
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var id := _pick(event.position)
		if id != hover_id:
			hover_id = id
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var id := _pick(event.position)
		if id != "":
			selected_id = id
			_show_card(id)
			queue_redraw()
			accept_event()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()

func _close() -> void:
	closed.emit()
	queue_free()
