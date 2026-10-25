class_name ArenaHUD
extends CanvasLayer

const INK := Color("142c31")
const CREAM := Color("f2ebd3")
const MUTED := Color("a8bdb1")
const GOLD := Color("e7c47b")

var game: Node2D
var root: Control
var status: Label
var shield_bar: ProgressBar
var resources: Label
var xp_label: Label
var skill_label: Label
var build_strip: Label
var phase_label: Label
var hint_label: Label
var build_label: Label
var core_label: Label
var core_bar: ProgressBar
var boss_label: Label
var boss_bar: ProgressBar
var focus_bar: ProgressBar
var result_panel: Panel
var result_label: Label
var hero_panel: Panel
var hero_selecting := false
var relic_panel: Panel
var relic_selecting := false
var passive_panel: Panel
var minimap: Control
var passive_buttons: Array[Button] = []
var passive_selected := ""
var passive_confirm: Button
var passive_reroll: Button
var build_palette: Panel
var palette_buttons := {}
var tower_panel: Panel
var tower_title: Label
var tower_upgrade: Button
var tower_repair: Button
var tower_close: Button
var toast_label: Label
var toast_time := 0.0
var phase_hint := ""

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	root.theme = theme
	minimap = ArenaMinimap.new()
	minimap.game = game
	minimap.anchor_left = 1.0
	minimap.anchor_right = 1.0
	minimap.anchor_top = 0.0
	minimap.anchor_bottom = 0.0
	minimap.offset_left = -232.0
	minimap.offset_right = -16.0
	minimap.offset_top = 86.0
	minimap.offset_bottom = 308.0
	root.add_child(minimap)
	status = _label(Rect2(18, 16, 420, 28), 20, CREAM)
	shield_bar = ProgressBar.new()
	shield_bar.position = Vector2(18, 44)
	shield_bar.size = Vector2(220, 8)
	shield_bar.show_percentage = false
	_style_bar(shield_bar, Color("76c9f0"), Color("1b2c2a"))
	root.add_child(shield_bar)
	resources = _label(Rect2(18, 54, 420, 24), 16, GOLD)
	xp_label = _label(Rect2(18, 78, 420, 24), 15, MUTED)
	skill_label = _label(Rect2(18, 102, 460, 24), 15, Color("cfe3d4"))
	build_strip = _label(Rect2(18, 128, 560, 44), 13, Color("9fb9aa"))
	build_strip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	phase_label = _label(Rect2(-320, 16, 640, 26), 20, GOLD)
	phase_label.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label = _label(Rect2(-420, 46, 840, 24), 15, MUTED)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	core_label = _label(Rect2(-280, 16, 250, 26), 18, CREAM)
	core_label.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	core_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	core_bar = ProgressBar.new()
	core_bar.position = Vector2(-280, 46)
	core_bar.size = Vector2(250, 12)
	core_bar.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	core_bar.show_percentage = false
	_style_bar(core_bar, Color("6fe0a8"), Color("1b2c2a"))
	root.add_child(core_bar)
	boss_label = _label(Rect2(-300, 82, 600, 24), 16, Color("ffb08a"))
	boss_label.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.visible = false
	boss_bar = ProgressBar.new()
	boss_bar.position = Vector2(-210, 108)
	boss_bar.size = Vector2(420, 10)
	boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	boss_bar.show_percentage = false
	boss_bar.visible = false
	_style_bar(boss_bar, Color("ff7868"), Color("2a1d1c"))
	root.add_child(boss_bar)
	build_label = _label(Rect2(-420, -72, 840, 26), 15, CREAM)
	build_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, true)
	build_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_bar = ProgressBar.new()
	focus_bar.position = Vector2(-180, -40)
	focus_bar.size = Vector2(360, 8)
	focus_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, true)
	focus_bar.max_value = 100
	focus_bar.show_percentage = false
	_style_bar(focus_bar, Color("e7c47b"), Color("2a2c24"))
	root.add_child(focus_bar)
	toast_label = _label(Rect2(-360, -112, 720, 28), 16, CREAM)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_panel = Panel.new()
	result_panel.position = Vector2(-260, -150)
	result_panel.size = Vector2(520, 300)
	result_panel.set_anchors_preset(Control.PRESET_CENTER, true)
	result_panel.visible = false
	root.add_child(result_panel)
	result_label = _label(Rect2(28, 28, 464, 220), 20, CREAM)
	root.remove_child(result_label)
	result_panel.add_child(result_label)
	_build_palette()
	_build_tower_panel()

func _label(rect: Rect2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", INK)
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)
	return label

func _style_bar(bar: ProgressBar, fill: Color, background: Color) -> void:
	var back := StyleBoxFlat.new()
	back.bg_color = background
	back.corner_radius_top_left = 4
	back.corner_radius_top_right = 4
	back.corner_radius_bottom_left = 4
	back.corner_radius_bottom_right = 4
	var front := StyleBoxFlat.new()
	front.bg_color = fill
	front.corner_radius_top_left = 4
	front.corner_radius_top_right = 4
	front.corner_radius_bottom_left = 4
	front.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", back)
	bar.add_theme_stylebox_override("fill", front)

func show_hero_select() -> void:
	if hero_panel != null: return
	hero_selecting = true
	hero_panel = Panel.new()
	hero_panel.position = Vector2(-330, -210)
	hero_panel.size = Vector2(660, 420)
	hero_panel.set_anchors_preset(Control.PRESET_CENTER, true)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("162b2b")
	panel_style.border_color = Color("6f8f7c")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	hero_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(hero_panel)
	var title := _label(Rect2(20, 20, 620, 36), 24, GOLD)
	root.remove_child(title)
	hero_panel.add_child(title)
	title.text = "选择英雄"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label(Rect2(20, 58, 620, 24), 14, MUTED)
	root.remove_child(subtitle)
	hero_panel.add_child(subtitle)
	subtitle.text = "三名英雄各有主动；营地宝匣会带来强力被动"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var keys := ["knight", "ranger", "mage"]
	for index in range(keys.size()):
		var key: String = keys[index]
		var data: Dictionary = Rules.HEROES[key]
		var button := Button.new()
		button.position = Vector2(60, 100 + index * 92)
		button.size = Vector2(540, 78)
		button.text = "%s  ·  %s\n%s" % [data.name, data.role, data.text]
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", CREAM)
		_style_button(button)
		button.pressed.connect(game.start_with_hero.bind(key))
		hero_panel.add_child(button)

func _style_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("1e3a36")
	normal.border_color = Color("58796d")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate()
	hover.bg_color = Color("2a5148")
	hover.border_color = Color("9ed6b8")
	var pressed := normal.duplicate()
	pressed.bg_color = Color("132b28")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)

func hide_hero_select() -> void:
	hero_selecting = false
	if hero_panel != null:
		hero_panel.visible = false
	_release_focus()

func _release_focus() -> void:
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()

func show_relic_choice(group: String) -> void:
	relic_selecting = true
	if relic_panel != null:
		relic_panel.queue_free()
	relic_panel = Panel.new()
	relic_panel.position = Vector2(-320, -180)
	relic_panel.size = Vector2(640, 360)
	relic_panel.set_anchors_preset(Control.PRESET_CENTER, true)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("162b2b")
	panel_style.border_color = Color("d6bd7a")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	relic_panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(relic_panel)
	var title := _label(Rect2(20, 22, 600, 32), 22, GOLD)
	root.remove_child(title)
	relic_panel.add_child(title)
	title.text = "营地路线"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label(Rect2(20, 60, 600, 24), 14, MUTED)
	root.remove_child(subtitle)
	relic_panel.add_child(subtitle)
	subtitle.text = "选择一组，锁定该组路线"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var choices := {"defense": ["lone", "swarm"], "lead": ["vanguard", "command"], "tempo": ["raid", "hold"]}
	var keys: Array = choices.get(group, [])
	for index in range(keys.size()):
		var key: String = keys[index]
		var data: Dictionary = Rules.RELICS[key]
		var button := Button.new()
		button.position = Vector2(40, 105 + index * 105)
		button.size = Vector2(560, 86)
		button.text = "%s · %s\n%s" % [data.name, data.tag, data.text]
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", CREAM)
		_style_button(button)
		button.pressed.connect(game.choose_relic.bind(key))
		relic_panel.add_child(button)

func hide_relic_choice() -> void:
	relic_selecting = false
	if relic_panel != null:
		relic_panel.visible = false
	_release_focus()

func show_passive_choice(choices: Array[String], source: String, rerolls: int) -> void:
	if passive_panel != null:
		passive_panel.queue_free()
	passive_buttons.clear()
	passive_selected = ""
	passive_panel = Panel.new()
	passive_panel.position = Vector2(-360, -250)
	passive_panel.size = Vector2(720, 500)
	passive_panel.set_anchors_preset(Control.PRESET_CENTER, true)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("162b2b")
	style.border_color = Color("d6bd7a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	passive_panel.add_theme_stylebox_override("panel", style)
	root.add_child(passive_panel)
	var title := _label(Rect2(20, 20, 680, 34), 24, GOLD)
	root.remove_child(title)
	passive_panel.add_child(title)
	title.text = "营地宝匣 · 强力被动" if source == "camp" else "升级 · 选择被动"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var subtitle := _label(Rect2(20, 60, 680, 24), 14, MUTED)
	root.remove_child(subtitle)
	passive_panel.add_child(subtitle)
	subtitle.text = "先点一张卡，再点确认；可刷新卡池"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for index in range(choices.size()):
		var key: String = choices[index]
		var data: Dictionary = game.passive_info(key)
		var button := Button.new()
		button.position = Vector2(40, 100 + index * 108)
		button.size = Vector2(640, 96)
		var rarity_text: String = String(data.get("rarity_name", "普通"))
		var tags_text: String = String(data.get("tags_text", "被动"))
		var stack_text: String = String(data.get("stack_text", ""))
		button.text = "%s · %s   [%s]   %s\n%s" % [data.name, tags_text, rarity_text, stack_text, data.desc]
		var requires_text: String = String(data.get("requires_text", ""))
		if requires_text != "":
			button.text += "\n前置：" + requires_text
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", data.get("rarity_color", CREAM))
		_style_button(button)
		button.toggle_mode = false
		button.pressed.connect(_select_passive.bind(key))
		passive_panel.add_child(button)
		passive_buttons.append(button)
	passive_reroll = Button.new()
	passive_reroll.position = Vector2(40, 432)
	passive_reroll.size = Vector2(190, 44)
	passive_reroll.text = "刷新 ×%d" % rerolls
	passive_reroll.disabled = rerolls <= 0
	passive_reroll.add_theme_font_size_override("font_size", 16)
	_style_button(passive_reroll)
	passive_reroll.pressed.connect(game.reroll_passive_choice)
	passive_panel.add_child(passive_reroll)
	passive_confirm = Button.new()
	passive_confirm.position = Vector2(250, 432)
	passive_confirm.size = Vector2(220, 44)
	passive_confirm.text = "先选择一张卡"
	passive_confirm.disabled = true
	passive_confirm.add_theme_font_size_override("font_size", 17)
	passive_confirm.add_theme_color_override("font_color", GOLD)
	_style_button(passive_confirm)
	passive_confirm.pressed.connect(_confirm_passive)
	passive_panel.add_child(passive_confirm)

func _select_passive(key: String) -> void:
	passive_selected = key
	for index in range(passive_buttons.size()):
		var selected: bool = index < 3 and game.passive_choices.size() > index and game.passive_choices[index] == key
		passive_buttons[index].modulate = Color(1.0, 0.9, 0.62) if selected else Color.WHITE
	if passive_confirm != null:
		passive_confirm.disabled = false
		passive_confirm.text = "确认选择"

func _confirm_passive() -> void:
	if passive_selected == "":
		return
	var key := passive_selected
	passive_selected = ""
	if game != null:
		game.choose_passive(key)

func hide_passive_choice() -> void:
	if passive_panel != null:
		passive_panel.visible = false
	passive_selected = ""
	_release_focus()

func _build_palette() -> void:
	build_palette = Panel.new()
	build_palette.size = Vector2(276, 92)
	build_palette.visible = false
	build_palette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142a28")
	style.border_color = Color("58796d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	build_palette.add_theme_stylebox_override("panel", style)
	root.add_child(build_palette)
	var index := 0
	for kind in ["bolt", "cannon", "frost"]:
		var data: Dictionary = ArenaTower.STATS[kind]
		var button := Button.new()
		button.position = Vector2(8 + index * 88, 8)
		button.size = Vector2(82, 76)
		button.text = "%s\n%d金" % [data.name, data.cost]
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", CREAM)
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_style_button(button)
		button.pressed.connect(game.number_build.bind(kind))
		build_palette.add_child(button)
		palette_buttons[kind] = button
		index += 1

func _update_build_strip() -> void:
	if game == null or game.hero == null:
		return
	var counts := {}
	for key in game.hero.passives:
		if not ArenaUpgrades.DEFS.has(key):
			continue
		for tag in ArenaUpgrades.DEFS[key].tags:
			counts[tag] = int(counts.get(tag, 0)) + 1
	var parts: Array[String] = []
	for tag in ["武器", "弹道", "元素", "生存", "经济", "塔防"]:
		if int(counts.get(tag, 0)) > 0:
			parts.append("%s%d" % [tag, int(counts[tag])])
	var synergies: Array[String] = []
	var near: Array[String] = []
	for key in ArenaUpgrades.DEFS:
		var data: Dictionary = ArenaUpgrades.DEFS[key]
		if String(data.rarity) != "synergy":
			continue
		if game.hero.passives.has(key):
			synergies.append(String(data.name))
			continue
		var requirements: Array = data.get("requires", [])
		var owned := 0
		for req in requirements:
			if game.hero.passives.has(String(req)):
				owned += 1
		if owned == requirements.size() - 1 and requirements.size() > 1:
			near.append("%s %d/%d" % [data.name, owned, requirements.size()])
	var line := "Build  " + (" · ".join(PackedStringArray(parts)) if parts.size() > 0 else "尚无")
	if synergies.size() > 0:
		line += "    协同：" + "、".join(PackedStringArray(synergies))
	if near.size() > 0:
		line += "\n接近协同：" + " · ".join(PackedStringArray(near.slice(0, 2)))
	build_strip.text = line

func _update_build_menu() -> void:
	if not game.build_mode or game.build_cell.x < 0:
		build_palette.visible = false
		return
	var screen: Vector2 = game.get_viewport().get_canvas_transform() * game.cell_center(game.build_cell)
	var viewport_size: Vector2 = game.get_viewport().get_visible_rect().size
	var position := screen + Vector2(34, -104)
	position.x = clampf(position.x, 12, viewport_size.x - build_palette.size.x - 12)
	position.y = clampf(position.y, 12, viewport_size.y - build_palette.size.y - 12)
	build_palette.position = position
	build_palette.visible = true

func _build_tower_panel() -> void:
	tower_panel = Panel.new()
	tower_panel.position = Vector2(-350, -250)
	tower_panel.size = Vector2(330, 220)
	tower_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
	tower_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142a28")
	style.border_color = Color("d6bd7a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	tower_panel.add_theme_stylebox_override("panel", style)
	root.add_child(tower_panel)
	tower_title = _label(Rect2(18, 14, 294, 28), 18, GOLD)
	root.remove_child(tower_title)
	tower_panel.add_child(tower_title)
	tower_upgrade = Button.new()
	tower_upgrade.position = Vector2(18, 60)
	tower_upgrade.size = Vector2(294, 46)
	tower_upgrade.add_theme_font_size_override("font_size", 15)
	_style_button(tower_upgrade)
	tower_upgrade.pressed.connect(game.upgrade_selected)
	tower_panel.add_child(tower_upgrade)
	tower_repair = Button.new()
	tower_repair.position = Vector2(18, 116)
	tower_repair.size = Vector2(140, 42)
	tower_repair.text = "修理 30 金"
	tower_repair.add_theme_font_size_override("font_size", 14)
	_style_button(tower_repair)
	tower_repair.pressed.connect(game.repair_selected)
	tower_panel.add_child(tower_repair)
	tower_close = Button.new()
	tower_close.position = Vector2(172, 116)
	tower_close.size = Vector2(140, 42)
	tower_close.text = "关闭"
	tower_close.add_theme_font_size_override("font_size", 14)
	_style_button(tower_close)
	tower_close.pressed.connect(game.close_tower_panel)
	tower_panel.add_child(tower_close)

func show_tower_panel(tower: ArenaTower) -> void:
	if tower == null:
		tower_panel.visible = false
		_release_focus()
		return
	tower_panel.visible = true
	_update_tower_panel()

func _update_tower_panel() -> void:
	if game.selected_tower == null or not is_instance_valid(game.selected_tower):
		tower_panel.visible = false
		return
	var tower: ArenaTower = game.selected_tower
	tower_panel.visible = not hero_selecting and not relic_selecting and not game.passive_selecting
	tower_title.text = "%s  Lv.%d" % [ArenaTower.STATS[tower.kind].name, tower.level]
	if tower.level >= ArenaTower.MAX_LEVEL:
		tower_upgrade.text = "已满级"
		tower_upgrade.disabled = true
	else:
		tower_upgrade.text = "升级 Lv.%d · %d 金" % [tower.level + 1, tower.upgrade_price()]
		tower_upgrade.disabled = game.gold < tower.upgrade_price()
	tower_repair.disabled = tower.health >= tower.max_health or game.gold < 30

func _update_tower_panel_old() -> void:
	pass

func _process(delta: float) -> void:
	if game == null: return
	var show_hud: bool = not hero_selecting and not relic_selecting and not game.passive_selecting
	for node in [status, resources, xp_label, skill_label, phase_label, hint_label, core_label, build_label, build_strip]:
		node.visible = show_hud
	core_bar.visible = show_hud
	shield_bar.visible = show_hud
	minimap.visible = show_hud
	focus_bar.visible = show_hud and game.build_mode
	build_palette.visible = false
	boss_label.visible = show_hud and game.boss != null and is_instance_valid(game.boss) and not game.boss.dead
	boss_bar.visible = boss_label.visible
	if hero_selecting or relic_selecting or game.passive_selecting:
		tower_panel.visible = false
		return
	status.text = "生命 %d/%d    护盾 %d/%d" % [game.hero.health, game.hero.max_health, game.hero.shield, game.hero.max_shield]
	shield_bar.max_value = game.hero.max_shield
	shield_bar.value = game.hero.shield
	resources.text = "金币 %d    Lv.%d    击杀 %d" % [game.gold, game.hero.level, game.stats.kills]
	xp_label.text = "经验 %d/%d    场上 %d    预算 %d" % [game.hero.xp, game.hero.xp_target, game.enemies.size(), game.spawn_budget]
	skill_label.text = "武器 %s Lv.%d    技能 %s · 空格    %s" % [Rules.weapon(game.hero.weapon_key).name, game.hero.weapon_level, game.hero.skill_name, "冷却 %ds" % ceili(game.hero.skill_cooldown) if game.hero.skill_cooldown > 0.0 else "可用"]
	_update_build_strip()
	core_label.text = "核心 %d / %d" % [game.core_health, game.core_max]
	core_label.add_theme_color_override("font_color", Color("ff8b7d") if game.core_health < game.core_max * 0.35 else CREAM)
	core_bar.max_value = game.core_max
	core_bar.value = game.core_health
	var phase_name := "休息" if game.phase == "rest" else ("出怪" if game.phase == "spawn" else "清场")
	phase_label.text = "第 %d / 6 轮 · %s %ds · 热点 %s" % [game.cycle, phase_name, ceili(game.phase_clock), game._region_name(game.hot_region)]
	hint_label.text = phase_hint
	if game.build_mode and game.build_reason != "":
		hint_label.text = "不能建造：" + game.build_reason
	if game.build_mode:
		build_label.text = "1/2/3 选塔：再按同键建造 · 换数字切塔 · 右键取消"
	else:
		build_label.text = "1/2/3 选塔并再按一次建造 · 左键点塔升级 · 空格技能 · R 重开"
	_update_build_menu()
	_update_tower_panel()
	if game.boss != null and is_instance_valid(game.boss) and not game.boss.dead:
		boss_label.text = "焚林统领  %d / %d" % [game.boss.health, game.boss.max_health]
		boss_bar.max_value = game.boss.max_health
		boss_bar.value = game.boss.health
	focus_bar.visible = game.build_mode
	focus_bar.value = game.focus / game.focus_max * 100.0
	toast_time = maxf(0.0, toast_time - delta)
	toast_label.visible = toast_time > 0.0
	result_panel.visible = game.game_over
	if game.game_over:
		result_label.text = ("守住了\n\n" if game.victory else "你倒下了\n\n") + "第 %d 轮 · 击杀 %d · 建塔 %d\n\n按 R 重开" % [game.cycle, game.stats.kills, game.stats.built]

func toast(message: String, duration := 2.0) -> void:
	toast_label.text = message
	toast_time = duration

func show_result(_win: bool) -> void:
	result_panel.visible = true
