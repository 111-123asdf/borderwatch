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

func _process(delta: float) -> void:
	if game == null: return
	status.text = "生命 %d/%d    护盾 %d/%d" % [game.hero.health, game.hero.max_health, game.hero.shield, game.hero.max_shield]
	resources.text = "金币 %d    Lv.%d    击杀 %d" % [game.gold, game.hero.level, game.stats.kills]
	xp_label.text = "经验 %d/%d    场上 %d    预算 %d" % [game.hero.xp, game.hero.xp_target, game.enemies.size(), game.spawn_budget]
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
		build_label.text = "B 慢速建造 · 1 弩 / 2 炮 / 3 霜 · 点已有塔升级 · E 修理 · Space 冲刺 · R 重开"
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
