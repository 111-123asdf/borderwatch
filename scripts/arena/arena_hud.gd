class_name ArenaHUD
extends CanvasLayer

const INK := Color("142c31")
const CREAM := Color("f2ebd3")
const MUTED := Color("a8bdb1")
const GOLD := Color("e7c47b")

var game: Node2D
var root: Control
var status: Label
var resources: Label
var xp_label: Label
var skill_label: Label
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
	status = _label(Rect2(18, 16, 420, 28), 20, CREAM)
	resources = _label(Rect2(18, 48, 420, 24), 16, GOLD)
	xp_label = _label(Rect2(18, 74, 420, 24), 15, MUTED)
	skill_label = _label(Rect2(18, 100, 460, 24), 15, Color("cfe3d4"))
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
	subtitle.text = "三名英雄各有主动；宝匣会带来旧模式武器"
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

func _process(delta: float) -> void:
	if game == null: return
	var show_hud := not hero_selecting and not relic_selecting
	for node in [status, resources, xp_label, skill_label, phase_label, hint_label, core_label, build_label]:
		node.visible = show_hud
	core_bar.visible = show_hud
	focus_bar.visible = show_hud and game.build_mode
	boss_label.visible = show_hud and game.boss != null and is_instance_valid(game.boss) and not game.boss.dead
	boss_bar.visible = boss_label.visible
	if hero_selecting or relic_selecting:
		return
	status.text = "生命 %d/%d    护盾 %d/%d" % [game.hero.health, game.hero.max_health, game.hero.shield, game.hero.max_shield]
	resources.text = "金币 %d    Lv.%d    击杀 %d" % [game.gold, game.hero.level, game.stats.kills]
	xp_label.text = "经验 %d/%d    场上 %d    预算 %d" % [game.hero.xp, game.hero.xp_target, game.enemies.size(), game.spawn_budget]
	skill_label.text = "武器 %s Lv.%d    技能 %s    %s" % [Rules.weapon(game.hero.weapon_key).name, game.hero.weapon_level, game.hero.skill_name, "冷却 %ds" % ceili(game.hero.skill_cooldown) if game.hero.skill_cooldown > 0.0 else "可用"]
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
		var stats: Dictionary = ArenaTower.STATS[game.build_kind]
		build_label.text = "建造 %s · %d 金 · 左键放置 / 点已有塔升级 · 松开 B 退出" % [stats.name, stats.cost]
	else:
		build_label.text = "B 慢速建造 · 1 弩 / 2 炮 / 3 霜 · 点已有塔升级 · E 修理 · Space 技能 · R 重开"
	if game.boss != null and is_instance_valid(game.boss) and not game.boss.dead:
		boss_label.visible = true
		boss_bar.visible = true
		boss_label.text = "焚林统领  %d / %d" % [game.boss.health, game.boss.max_health]
		boss_bar.max_value = game.boss.max_health
		boss_bar.value = game.boss.health
	else:
		boss_label.visible = false
		boss_bar.visible = false
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
