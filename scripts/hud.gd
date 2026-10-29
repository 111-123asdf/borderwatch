extends CanvasLayer

const INK := Color("142c31")
const CREAM := Color("f2ebd3")
const MUTED := Color("a8bdb1")
const GOLD := Color("e7c47b")
var game: Node2D
var root: Control
var modal: Control
var modal_kind := ""
var context: Panel
var status: Label
var gold_label: Label
var health_bar: ProgressBar
var shield_bar: ProgressBar
var xp_bar: ProgressBar
var core_bar: ProgressBar
var early_button: Button
var skill_button: Button
var dash_label: Label
var hint: Label
var toast_label: Label
var toast_time := 0.0
var boss_bar: ProgressBar
var boss_panel: Panel
var boss_name: Label
var compass: Button
var preview: Label
var atlas: Texture2D
var reward_buttons: Array[Button] = []
var context_site := -1
var energy_bar: ProgressBar
var core_label: Label
var resource_label: Label
var skill_status: Label
var portraits: Texture2D
var hero_previews: Array[ActorVisual] = []
var tutorial_seen := false
var tutorial_page := 0
var tutorial_return := "main"
var pause_return := "main"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(func(): root.size = get_viewport().get_visible_rect().size)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	root.theme = theme
	if ResourceLoader.exists("res://assets/ui/passives.png"): atlas = load("res://assets/ui/passives.png")
	if ResourceLoader.exists("res://assets/ui/heroes-0.3.png"): portraits = load("res://assets/ui/heroes-0.3.png")
	_build_hud()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var settings := ConfigFile.new()
	if settings.load("user://settings.cfg") == OK:
		game.sound.enabled = settings.get_value("audio", "enabled", true)
		game.reduced_shake = settings.get_value("visual", "reduced_shake", false)
		AudioServer.set_bus_volume_linear(0, settings.get_value("audio", "volume", 0.6))
		tutorial_seen = settings.get_value("ui", "tutorial_seen", false)
	else: AudioServer.set_bus_volume_linear(0, 0.6)
	show_main_menu()

func _style(color := INK, border := Color("496761"), radius := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style

func _panel(parent: Node, rectangle: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rectangle.position
	panel.size = rectangle.size
	panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.15, 0.17, 0.94)))
	parent.add_child(panel)
	return panel

func _label(parent: Node, message: String, rectangle: Rect2, font_size := 17, color := CREAM) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = message
	label.position = rectangle.position
	label.size = rectangle.size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, message: String, rectangle: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = message
	button.position = rectangle.position
	button.size = rectangle.size
	button.add_theme_stylebox_override("normal", _style(Color("24443f")))
	button.add_theme_stylebox_override("hover", _style(Color("355a50"), GOLD))
	button.add_theme_stylebox_override("pressed", _style(Color("1c3533"), GOLD))
	button.add_theme_stylebox_override("disabled", _style(Color("203335"), Color("354d4b")))
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_disabled_color", Color("718c84"))
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _bar(parent: Node, rectangle: Rect2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = rectangle.position
	bar.set_deferred("size", rectangle.size)
	bar.show_percentage = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("28413e")
	background.set_corner_radius_all(4)
	var foreground := StyleBoxFlat.new()
	foreground.bg_color = color
	foreground.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", foreground)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	return bar

func _icon(parent: Node, key: String, rectangle: Rect2) -> Control:
	var view := TextureRect.new()
	view.position = rectangle.position
	view.size = rectangle.size
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if atlas != null:
		var index: int = Rules.RELICS.keys().find(key)
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		var cell := Vector2(atlas.get_width() / 4.0, atlas.get_height() / 3.0)
		texture.region = Rect2(Vector2(index % 4, index / 4) * cell + Vector2(12, 16), cell - Vector2(24, 32))
		view.texture = texture
	else:
		view.texture = Art.texture("UI/Icons/Regular_03.png")
		view.modulate = Rules.RELICS.get(key, {"color": GOLD}).color
	parent.add_child(view)
	return view

func _build_hud() -> void:
	var hero_panel := _panel(root, Rect2(16, 14, 300, 110))
	_icon(hero_panel, "shield", Rect2(9, 10, 48, 48))
	status = _label(hero_panel, "", Rect2(66, 7, 226, 23), 15)
	health_bar = _bar(hero_panel, Rect2(66, 36, 215, 8), Color("e39882"))
	shield_bar = _bar(hero_panel, Rect2(66, 51, 215, 7), Color("add5dc"))
	energy_bar = _bar(hero_panel, Rect2(66, 65, 215, 7), Color("78a9e4"))
	resource_label = _label(hero_panel, "", Rect2(16, 80, 272, 21), 13, MUTED)
	xp_bar = _bar(hero_panel, Rect2(16, 102, 266, 3), GOLD)
	var economy := _panel(root, Rect2(-278, 14, 262, 84))
	economy.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	gold_label = _label(economy, "", Rect2(15, 5, 167, 40), 29, GOLD)
	core_label = _label(economy, "", Rect2(16, 49, 162, 22), 14, MUTED)
	core_bar = _bar(economy, Rect2(16, 74, 148, 4), Color("88d9d0"))
	_button(economy, "☰", Rect2(187, 10, 59, 42), show_pause)
	early_button = _button(root, "", Rect2(-130, 17, 260, 43), func(): game.early_wave())
	early_button.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	compass = _button(root, "", Rect2(-130, 67, 260, 32), show_map)
	compass.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	compass.add_theme_font_size_override("font_size", 14)
	var skills := _panel(root, Rect2(16, -92, 210, 76))
	skills.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
	skill_button = _button(skills, "", Rect2(7, 7, 196, 62), func(): game.hero.use_skill())
	_icon(skill_button, Rules.HEROES[game.hero.class_id].icon, Rect2(4, 2, 52, 52))
	skill_status = _label(skill_button, "", Rect2(65, 7, 125, 48), 15)
	skill_button.tooltip_text = "Space / C：英雄专属技能。Q或1/2切换武器，Tab背包。"
	dash_label = _label(root, "", Rect2(-295, -70, 275, 48), 15)
	dash_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT, true)
	dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dash_label.add_theme_color_override("font_outline_color", INK)
	dash_label.add_theme_constant_override("outline_size", 5)
	hint = _label(root, "", Rect2(-190, -77, 380, 27), 17)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_outline_color", INK)
	hint.add_theme_constant_override("outline_size", 5)
	toast_label = _label(root, "", Rect2(-350, -43, 700, 28), 16)
	toast_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM, true)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_color_override("font_outline_color", INK)
	toast_label.add_theme_constant_override("outline_size", 5)
	boss_panel = _panel(root, Rect2(-180, 112, 360, 51))
	boss_panel.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	boss_name = _label(boss_panel, "焚林统领", Rect2(14, 3, 330, 25), 16, GOLD)
	boss_bar = _bar(boss_panel, Rect2(14, 31, 332, 6), Color("dc8b73"))
	boss_panel.hide()
	preview = _label(root, "", Rect2(-330, 102, 660, 24), 14, MUTED)
	preview.set_anchors_preset(Control.PRESET_CENTER_TOP, true)
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview.add_theme_color_override("font_outline_color", INK)
	preview.add_theme_constant_override("outline_size", 4)

func _process(delta: float) -> void:
	toast_time = maxf(0, toast_time - delta)
	toast_label.visible = toast_time > 0 and modal_kind.is_empty()
	var hero: Hero = game.hero
	for preview in hero_previews:
		if is_instance_valid(preview): preview.advance(delta, Vector2(100, 0), Vector2.RIGHT)
	status.text = "%s  局内Lv.%d" % [Rules.HEROES[hero.class_id].name, game.level]
	health_bar.value = hero.health / hero.max_health * 100
	shield_bar.value = hero.shield / hero.max_shield * 100
	energy_bar.value = hero.energy / hero.max_energy * 100
	resource_label.text = "生命 %d   护盾 %d   能量 %d / %d" % [hero.health, hero.shield, hero.energy, hero.max_energy]
	xp_bar.value = game.experience * 100.0 / game.experience_target
	gold_label.text = "%d 金" % game.gold
	core_label.text = "遗迹核心  %d / %d" % [game.core_health, game.core_max_health]
	core_bar.value = game.core_health / game.core_max_health * 100
	early_button.disabled = game.wave_active or game.wave >= Rules.WAVES
	if game.wave == 0: early_button.text = "开始第一波  ·  F"
	elif game.wave_active: early_button.text = "第 %d / 6 波" % game.wave
	else: early_button.text = "下一波 %d秒  ·  F提前" % ceili(game.wave_clock)
	skill_status.text = "%s\n%s · Space" % [Rules.HEROES[hero.class_id].skill, ("就绪" if hero.skill_cooldown <= 0 else "%.1fs" % hero.skill_cooldown)]
	skill_button.disabled = not game.running or hero.skill_cooldown > 0 or hero.respawn_time > 0
	var first: Dictionary = hero.weapon_slots[0]
	var second: Dictionary = hero.weapon_slots[1]
	dash_label.text = "1%s%s +%d  2%s%s +%d\nQ 切换 · Tab 武器栏" % ["▶" if hero.active_weapon_slot == 0 else " ", Rules.weapon(first.id).name, first.level, "▶" if hero.active_weapon_slot == 1 else " ", Rules.weapon(second.id).name, second.level]
	var next_camp := -1
	for index in range(3):
		if not game.camps[index].chest_claimed and game.completed_waves >= Rules.CAMP_UNLOCK[index]:
			next_camp = index
			break
	compass.visible = game.started and next_camp >= 0 and modal_kind.is_empty()
	if next_camp >= 0:
		var offset: Vector2 = game.exploration_target(next_camp) - hero.position
		var arrows := ["→", "↘", "↓", "↙", "←", "↖", "↑", "↗"]
		var arrow: String = arrows[posmod(roundi(offset.angle() / (PI / 4)), 8)]
		compass.text = "%s %s %d/3 · %dm" % [arrow, Rules.CAMP_NAMES[next_camp], mini(3, game.camps[next_camp].progress + 1), int(offset.length() / 32)]
	hint.text = ""
	if hero.respawn_time > 0: hint.text = "重新集结 %d秒" % ceili(hero.respawn_time)
	elif hero.recall_time > 0: hint.text = "回营中…"
	else:
		for index in range(3):
			if game.camps[index].cleared and not game.camps[index].chest_claimed and hero.position.distance_to(Rules.CAMPS[index]) < 125:
				hint.text = "E  开启宝匣" + (" / 解救伙伴" if index < 2 else "")
			elif game.camps[index].chest_claimed and hero.position.distance_to(Rules.CAMPS[index]) < 125: hint.text = "E  沿捷径回营"
		if game.core_health < game.core_max_health and hero.position.distance_to(Rules.CORE) < 200:
			hint.text = "核心受损 %d · 不会再自行恢复" % int(game.core_health)
	hint.visible = modal_kind.is_empty()
	var boss: Enemy
	for enemy in game.enemies:
		if is_instance_valid(enemy) and enemy.kind == "boss" and not enemy.dead: boss = enemy
	boss_panel.visible = boss != null and modal_kind.is_empty()
	if boss != null:
		boss_bar.value = boss.health / boss.max_health * 100
		boss_name.text = "焚林统领"
	var preview_text := ""
	if not game.wave_active and game.wave < Rules.WAVES and modal_kind.is_empty():
		preview_text = game.wave_preview_text()
		if game.wave > 0 and hero.position.distance_to(Rules.CORE) > 260:
			var walk := ceili(hero.position.distance_to(Rules.CORE) / Rules.HEROES[hero.class_id].speed)
			preview_text = "回防约 %d秒 · %s" % [walk, preview_text]
			preview.add_theme_color_override("font_color", Color("ffb08a") if walk > ceili(game.wave_clock) else MUTED)
		else:
			preview.add_theme_color_override("font_color", MUTED)
	preview.text = preview_text
	preview.visible = not preview_text.is_empty()

func pointer_over_ui() -> bool:
	if not modal_kind.is_empty(): return true
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered != root and root.is_ancestor_of(hovered)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if modal_kind == "tutorial":
			_finish_tutorial()
			get_viewport().set_input_as_handled()
			return
		if modal_kind == "reward" or modal_kind == "result" or modal_kind == "title": return
		if not modal_kind.is_empty(): close_modal()
		elif context != null: close_context()
		else: show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and game.started:
		if modal_kind == "reward" or modal_kind == "result": return
		if modal_kind == "inventory": close_modal()
		elif modal_kind.is_empty(): show_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("map") and game.started and modal_kind != "reward" and modal_kind != "result":
		if modal_kind == "map": close_modal()
		elif modal_kind.is_empty(): show_map()
		get_viewport().set_input_as_handled()

func _open(kind: String, dimensions: Vector2, title: String) -> Panel:
	close_context()
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	modal_kind = kind
	modal.show()
	game.running = false
	game.get_tree().paused = true
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.07, 0.08, 0.92 if kind in ["main", "title", "progression"] else 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(shade)
	var panel := _panel(modal, Rect2(-dimensions * 0.5, dimensions))
	panel.set_anchors_preset(Control.PRESET_CENTER, true)
	_label(panel, title, Rect2(30, 23, dimensions.x - 60, 47), 27, GOLD)
	return panel

func close_modal() -> void:
	modal_kind = ""
	modal.hide()
	game.get_tree().paused = false
	game.running = game.started
	game.block_pointer = true

func show_main_menu() -> void:
	var panel := _open("main", Vector2(720, 690), "边境守望")
	_label(panel, "英雄探索 × 自动塔防", Rect2(30, 78, 660, 35), 20, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(panel, "核心切片 · 全局英雄养成", Rect2(30, 113, 660, 27), 15, Color("b8dcae")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var start := _button(panel, "开始游戏", Rect2(150, 174, 420, 67), show_title)
	var growth := _button(panel, "英雄养成", Rect2(150, 257, 420, 67), show_progression)
	var guide := _button(panel, "玩法引导", Rect2(150, 340, 420, 67), func(): show_tutorial(0))
	var settings := _button(panel, "设置", Rect2(150, 423, 420, 67), func(): show_pause("main"))
	var exit_button := _button(panel, "退出游戏", Rect2(150, 506, 420, 57), func(): game.get_tree().quit())
	for button in [start, growth, guide, settings, exit_button]:
		button.add_theme_font_size_override("font_size", 21)
		button.add_theme_stylebox_override("normal", _style(Color("263f3c"), Color("78958a"), 2))
		button.add_theme_stylebox_override("hover", _style(Color("395a50"), GOLD, 2))
	_label(panel, "选择英雄、整备成长，然后进入边境林地", Rect2(90, 602, 540, 30), 16, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(panel, "v0.3.0", Rect2(30, 650, 660, 20), 13, Color("718c84")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func show_progression() -> void:
	var panel := _open("progression", Vector2(1100, 710), "英雄养成 / 全局档案")
	_button(panel, "返回主菜单", Rect2(890, 24, 180, 42), show_main_menu)
	_label(panel, "关卡结算获得英雄经验；升级获得1点，可永久强化一项属性。", Rect2(30, 70, 820, 30), 16, MUTED)
	for index in range(Rules.HEROES.size()):
		var key: String = Rules.HEROES.keys()[index]
		var current: Dictionary = game.progression.entry(key)
		var selected: bool = key == game.hero.class_id
		var text := "%s%s  全局Lv.%d\n经验 %d/%d  ·  可用点数 %d" % ["▶ " if selected else "", Rules.HEROES[key].name, current.level, current.xp, game.progression.experience_target(key), current.points]
		var card := _button(panel, text, Rect2(30, 112 + index * 102, 350, 86), func(): game.hero.configure(key); show_progression())
		card.add_theme_stylebox_override("normal", _style(Color("2d4b45") if selected else Color("1a3235"), GOLD if selected else Color("496761"), 4))
	var hero_id: String = game.hero.class_id
	var definition: Dictionary = Rules.HEROES[hero_id]
	var profile: Dictionary = game.progression.entry(hero_id)
	var bonus: Dictionary = game.progression.bonuses(hero_id)
	var preview := ActorVisual.new()
	preview.position = Vector2(995, 151)
	preview.setup("player", definition.color, 1.25, true)
	preview.hero_identity = hero_id
	preview.held_weapon = game.hero.weapon_id
	panel.add_child(preview)
	hero_previews.clear()
	hero_previews.append(preview)
	_label(panel, definition.name, Rect2(420, 116, 480, 40), 28, GOLD)
	_label(panel, "%s\n%s" % [definition.role, definition.passive], Rect2(420, 163, 520, 62), 16, MUTED)
	_label(panel, "基础：生命%d · 护盾%d · 能量%d\n永久加成：生命+%d · 护盾+%d · 能量+%d · 伤害+%d%%" % [definition.health, definition.shield, definition.energy, bonus.health, bonus.shield, bonus.energy, roundi(float(bonus.damage) * 100)], Rect2(420, 235, 620, 65), 17)
	_label(panel, "可用升级点  %d" % profile.points, Rect2(420, 315, 500, 34), 22, GOLD)
	var stat_labels := {"health": "生命训练", "shield": "护盾训练", "energy": "能量训练", "damage": "武器专精"}
	var stat_values := {"health": "+6生命", "shield": "+4护盾", "energy": "+6能量", "damage": "+4%伤害"}
	for index in range(HeroProgression.STAT_KEYS.size()):
		var stat: String = HeroProgression.STAT_KEYS[index]
		var rank: int = int(profile[stat])
		_label(panel, "%s  %d/%d\n每级%s" % [stat_labels[stat], rank, HeroProgression.STAT_CAP, stat_values[stat]], Rect2(420, 370 + index * 70, 350, 55), 17)
		var upgrade := _button(panel, "强化 · 1点", Rect2(805, 374 + index * 70, 210, 47), func(): _upgrade_global_stat(stat))
		upgrade.disabled = int(profile.points) <= 0 or rank >= HeroProgression.STAT_CAP
	_label(panel, "全局成长对所有关卡生效；局内升级会在本局结束后重置。", Rect2(420, 657, 620, 28), 15, Color("b8dcae"))

func _upgrade_global_stat(stat: String) -> void:
	if game.progression.upgrade(game.hero.class_id, stat):
		game.hero.configure(game.hero.class_id)
	show_progression()

func show_title() -> void:
	for child in skill_button.get_children():
		if child is TextureRect:
			skill_button.remove_child(child)
			child.queue_free()
	_icon(skill_button, Rules.HEROES[game.hero.class_id].icon, Rect2(4, 2, 52, 52))
	var panel := _open("title", Vector2(1120, 740), "关卡准备 / 边境林地")
	hero_previews.clear()
	_label(panel, "英雄与武器已解耦 · 所有英雄共享双武器栏：手枪 + 长剑，局内可替换与切换", Rect2(30, 72, 1060, 28), 17, MUTED)
	for index in range(Rules.HEROES.size()):
		var key: String = Rules.HEROES.keys()[index]
		var definition: Dictionary = Rules.HEROES[key]
		var profile: Dictionary = game.progression.entry(key)
		var bonus: Dictionary = game.progression.bonuses(key)
		var column := index % 3
		var row := index / 3
		var card := _button(panel, "", Rect2(25 + column * 360, 110 + row * 245, 350, 230), func(): game.hero.configure(key); show_title())
		card.add_theme_stylebox_override("normal", _style(Color("25423f") if game.hero.class_id == key else Color("1a3235"), GOLD if game.hero.class_id == key else Color("496761")))
		var preview := ActorVisual.new()
		preview.position = Vector2(302, 55)
		preview.setup("player", definition.color, 1.0, true)
		preview.hero_identity = key
		preview.held_weapon = game.hero.weapon_id
		card.add_child(preview)
		hero_previews.append(preview)
		_label(card, definition.name + ("  ✓" if game.hero.class_id == key else ""), Rect2(18, 13, 275, 31), 22, GOLD if game.hero.class_id == key else CREAM)
		_label(card, "%s · 全局Lv.%d" % [definition.role, profile.level], Rect2(18, 48, 270, 24), 14, MUTED)
		_label(card, "生命%d  护盾%d  能量%d  伤害+%d%%" % [definition.health + bonus.health, definition.shield + bonus.shield, definition.energy + bonus.energy, roundi(float(bonus.damage) * 100)], Rect2(18, 78, 314, 25), 14)
		_label(card, "%s · %.1f秒CD" % [definition.skill, definition.cooldown], Rect2(18, 109, 314, 26), 18, GOLD)
		_label(card, definition.text, Rect2(18, 140, 314, 39), 14, MUTED)
		_label(card, definition.passive, Rect2(18, 186, 314, 28), 13, Color("b8dcae"))
	_button(panel, "返回主菜单", Rect2(26, 659, 150, 45), show_main_menu)
	_button(panel, "新手引导", Rect2(186, 659, 150, 45), func(): show_tutorial(0))
	_button(panel, "以%s出发" % Rules.HEROES[game.hero.class_id].name, Rect2(740, 653, 350, 56), func(): game.start_run())
	_label(panel, "首波 90 秒后自动开始 · 可提前确认", Rect2(380, 666, 330, 29), 16, MUTED)

func show_tutorial(page := 0) -> void:
	if page == 0 and modal_kind != "tutorial": tutorial_return = modal_kind
	tutorial_page = clampi(page, 0, 3)
	var panels := [
		"【移动与战斗】\nWASD / 方向键移动；右键地面、点选或拖动英雄指定目的地。\n左键 / 按住左键：自动攻击射程内最近、可见的敌人，鼠标不用瞄准。\nSpace / C：英雄主动技能；Q切换双武器，数字1/2直接选槽位。\nE 交互 · R 回营 · Tab 武器与成长 · M 地图 · F 开波 · Esc 设置",
		"【防线】\n点击路边圆形空地建塔。开局只有 4 个塔位和弩塔。\n肃清苔石林地：+2 塔位并解锁重炮；肃清回响石庭：+2 塔位。\n英雄 340 范围内是指挥光环：塔 +30% 伤害、+10% 射程；英雄离开，塔会变弱。\n铁甲：英雄打不动、自动索敌会跳过，必须交给塔。\n塔位不够时先出门探索，不要只靠英雄。",
		"【探索与回防】\n每个营地有 3 个节点，走近触发遭遇；清完 3 个才能开宝箱、救伙伴。\n宝箱旁按 E 开箱；开过的宝箱旁再按 E 可回营（25 秒冷却，附近有敌人不可用）。\n首波 90 秒后自动开始，之后两波之间 55 秒，HUD 会显示回防时间。\n核心掉血不会自行恢复：漏一只怪就是一笔账。",
		"【Boss 与成长】\n第 6 波焚林统领血很厚，塔与英雄要一起压；它到核心就输。\n局内升级增加生命、护盾、能量和伤害，本局结束后重置。\n结算获得全局英雄经验；回到主菜单的英雄养成页可分配永久升级点。\n宝匣武器进入双武器栏，不再绑定英雄。",
	]
	var panel := _open("tutorial", Vector2(900, 560), "新手引导  %d / 4" % (tutorial_page + 1))
	_label(panel, panels[tutorial_page], Rect2(34, 82, 832, 380), 18, CREAM)
	_button(panel, "跳过", Rect2(34, 492, 120, 44), _finish_tutorial)
	if tutorial_page > 0:
		_button(panel, "上一步", Rect2(176, 492, 120, 44), func(): show_tutorial(tutorial_page - 1))
	var next_text := "开始" if tutorial_page >= 3 else "下一步"
	_button(panel, next_text, Rect2(730, 492, 136, 44), _tutorial_next)

func _tutorial_next() -> void:
	if tutorial_page >= 3: _finish_tutorial()
	else: show_tutorial(tutorial_page + 1)

func _finish_tutorial() -> void:
	tutorial_seen = true
	_save_settings()
	if game.started:
		close_modal()
		game.toast("WASD 移动 · 左键自动攻击 · 点击空地建塔 · 塔在英雄附近更强", 5)
	else:
		close_modal()
		if tutorial_return == "title": show_title()
		else: show_main_menu()

func show_wave_confirmation() -> void:
	var panel := _open("confirm", Vector2(490, 270), "准备迎战？")
	_label(panel, "建议先在两路各放一座塔。\n开波不额外奖励金币，探索多久都可以。", Rect2(30, 85, 430, 67), 18, MUTED)
	_button(panel, "再准备一下", Rect2(30, 186, 195, 49), close_modal)
	_button(panel, "开始第一波", Rect2(245, 186, 215, 49), func(): close_modal(); game.start_wave())

func show_pause(return_to := "") -> void:
	if not return_to.is_empty(): pause_return = return_to
	var panel := _open("pause", Vector2(700, 590), "营地手册 / 设置")
	_label(panel, "WASD 移动 · 左键 / 按住左键攻击，自动锁定最近敌人\n鼠标不用瞄准；自动索敌不会替你追怪\nSpace / C 使用英雄主动技能\nQ切换双武器；数字1/2直接选择；Tab查看武器与成长\n右键地面移动，或点击 / 拖动英雄指定目的地\n点击空地建塔；点击塔升级 / 出售\nE 宝匣 / 捷径 · R 引导回营 · M地图\nF 开波：首波90秒后自动开始，后续清场55秒准备\n\n宝匣武器替换副槽，当前武器会保留下来。\n升级增加生命、护盾、能量与英雄伤害。\n近战与月轮可消弹，结界可挡弹；红圈仍需走位。", Rect2(32, 81, 640, 310), 17, MUTED)
	var audio := CheckButton.new()
	audio.text = "音效"
	audio.position = Vector2(32, 411)
	audio.button_pressed = game.sound.enabled
	audio.toggled.connect(func(enabled: bool): game.sound.enabled = enabled; _save_settings())
	panel.add_child(audio)
	var shake := CheckButton.new()
	shake.text = "减少镜头震动"
	shake.position = Vector2(300, 411)
	shake.button_pressed = game.reduced_shake
	shake.toggled.connect(func(enabled: bool): game.reduced_shake = enabled; _save_settings())
	panel.add_child(shake)
	var volume := HSlider.new()
	volume.position = Vector2(135, 427)
	volume.size = Vector2(120, 20)
	volume.max_value = 1
	volume.step = 0.05
	volume.value = AudioServer.get_bus_volume_linear(0)
	volume.value_changed.connect(func(value: float): AudioServer.set_bus_volume_linear(0, value); _save_settings())
	panel.add_child(volume)
	_button(panel, "新手引导", Rect2(470, 507, 180, 50), func(): show_tutorial(0))
	_button(panel, "返回", Rect2(250, 507, 200, 50), func():
		if game.started: close_modal()
		elif pause_return == "title": show_title()
		else: show_main_menu())

func _save_settings() -> void:
	var settings := ConfigFile.new()
	settings.set_value("audio", "enabled", game.sound.enabled)
	settings.set_value("audio", "volume", AudioServer.get_bus_volume_linear(0))
	settings.set_value("visual", "reduced_shake", game.reduced_shake)
	settings.set_value("ui", "tutorial_seen", tutorial_seen)
	settings.save("user://settings.cfg")

func show_reward(title: String, choices: Array) -> void:
	var panel := _open("reward", Vector2(1030, 510), title)
	_label(panel, "时间已暂停 · 选定即锁定这条路线", Rect2(32, 73, 960, 29), 17, MUTED)
	reward_buttons.clear()
	for index in range(choices.size()):
		var key: String = choices[index]
		var definition: Dictionary = Rules.RELICS[key]
		var card := _button(panel, "", Rect2(30 + index * 330, 123, 310, 351), func(): game.claim_relic(key))
		card.add_theme_stylebox_override("normal", _style(Color("203c3a"), Color(definition.color, 0.7)))
		_icon(card, key, Rect2(84, 15, 142, 142))
		_label(card, definition.tag, Rect2(22, 166, 268, 26), 15, definition.color)
		_label(card, definition.name, Rect2(22, 199, 268, 38), 24)
		_label(card, definition.text, Rect2(22, 249, 268, 78), 18, MUTED)
		reward_buttons.append(card)

func show_inventory() -> void:
	var panel := _open("inventory", Vector2(990, 650), "双武器与英雄成长")
	_button(panel, "关闭 · Tab", Rect2(787, 24, 173, 42), close_modal)
	var hero: Hero = game.hero
	_label(panel, "%s  局内Lv.%d\n生命 %d/%d · 护盾 %d/%d\n能量 %d/%d · 局内经验 %d/%d" % [Rules.HEROES[hero.class_id].name, game.level, hero.health, hero.max_health, hero.shield, hero.max_shield, hero.energy, hero.max_energy, game.experience, game.experience_target], Rect2(30, 88, 430, 95), 18)
	_label(panel, "武器栏 · Q切换 / 1、2直接选择", Rect2(30, 190, 430, 28), 18, GOLD)
	for slot in range(hero.weapon_slots.size()):
		var item: Dictionary = hero.weapon_slots[slot]
		var weapon := Rules.weapon(item.id)
		var active := slot == hero.active_weapon_slot
		var button := _button(panel, "%s槽位 %d · %s +%d\n%s" % ["▶ " if active else "", slot + 1, weapon.name, item.level, weapon.tag], Rect2(30, 226 + slot * 92, 430, 78), func(): hero.switch_weapon(slot); show_inventory())
		button.add_theme_stylebox_override("normal", _style(Color("2c4d45") if active else Color("1b3435"), GOLD if active else Color("496761")))
	_label(panel, "%s · 主动 Lv.%d" % [Rules.HEROES[hero.class_id].skill, hero.skill_level], Rect2(30, 423, 430, 31), 20)
	_label(panel, Rules.HEROES[hero.class_id].text, Rect2(30, 458, 425, 48), 15, MUTED)
	_label(panel, Rules.HEROES[hero.class_id].passive, Rect2(30, 514, 425, 35), 15, Color("b8dcae"))
	_label(panel, "每级：生命+4 · 护盾+2 · 能量+3 · 伤害+3%", Rect2(30, 558, 440, 30), 15, GOLD)
	_label(panel, "已获得的被动", Rect2(500, 88, 440, 28), 20, GOLD)
	if game.relics.is_empty(): _label(panel, "击杀获取经验；营地秘藏提供路线二选一。", Rect2(500, 135, 430, 60), 18, MUTED)
	for index in range(game.relics.size()):
		var key: String = game.relics[index]
		var column: int = index % 6
		var row: int = index / 6
		var icon := _icon(panel, key, Rect2(500 + column * 72, 131 + row * 84, 64, 64))
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon.tooltip_text = "%s %d级\n%s" % [Rules.RELICS[key].name, game.rank(key), Rules.RELICS[key].text]
		_label(panel, str(game.rank(key)), Rect2(548 + column * 72, 176 + row * 84, 20, 24), 15, GOLD)
	_label(panel, "%d金 · 建塔与升级共用金币" % game.gold, Rect2(30, 607, 900, 25), 16, MUTED)

func show_context(site: int, tower: Tower) -> void:
	close_context()
	context_site = site
	game.selected = tower
	var point: Vector2 = tower.position if tower != null else Rules.BUILD_SITES[site]
	var screen := game.get_viewport().get_canvas_transform() * point
	var position := (screen + Vector2(40, -150)).clamp(Vector2(16, 115), root.size - Vector2(306, 325))
	context = _panel(root, Rect2(position, Vector2(290, 300)))
	root.move_child(context, root.get_child_count() - 2)
	_label(context, Rules.TOWERS[tower.kind].name + " Lv.%d" % tower.level if tower != null else "路边建设空地 · 塔位 %d/%d" % [game.towers.size(), game.tower_limit()], Rect2(17, 13, 230, 31), 21, GOLD)
	_button(context, "×", Rect2(242, 9, 36, 32), close_context)
	if tower == null:
		var full: bool = game.towers.size() >= game.tower_limit()
		for index in range(3):
			var key: String = Rules.TOWERS.keys()[index]
			var definition: Dictionary = Rules.TOWERS[key]
			var lock: String = game.tower_lock_reason(key)
			var text := "%s · %d金\n%s" % [definition.name, definition.cost, definition.description]
			if not lock.is_empty(): text = "%s\n%s" % [definition.name, lock]
			elif full: text = "%s · 塔位已满\n%s" % [definition.name, definition.description]
			var button := _button(context, text, Rect2(13, 55 + index * 71, 264, 62), func():
				game.choose_build(key)
				game.try_build(Rules.BUILD_SITES[site])
				close_context())
			button.add_theme_font_size_override("font_size", 16)
			button.disabled = not game.can_manage() or game.gold < definition.cost or not lock.is_empty() or full
	else:
		_label(context, Rules.TOWERS[tower.kind].description + "\n自动攻击 · 不受敌方弹幕伤害", Rect2(18, 58, 254, 64), 17, MUTED)
		var upgrade := _button(context, "升级 · %d金" % tower.upgrade_price() if tower.level < Tower.MAX_LEVEL else "已达最高级", Rect2(15, 143, 260, 49), func(): game.upgrade_selected(); close_context())
		upgrade.disabled = not game.can_manage() or tower.level >= Tower.MAX_LEVEL or game.gold < tower.upgrade_price()
		_button(context, "出售 · 返还 %d金" % int(tower.invested * 0.7), Rect2(15, 204, 260, 45), func(): game.sell_selected(); close_context()).disabled = not game.can_manage()
	_label(context, "" if game.can_manage() else "英雄回到营地后可建设 / 升级", Rect2(15, 266, 263, 26), 14, MUTED)

func close_context() -> void:
	if is_instance_valid(context):
		context.queue_free()
		context = null
	game.selected = null

func show_map() -> void:
	var panel := _open("map", Vector2(850, 590), "林地行军图")
	var map: Control = load("res://scripts/minimap.gd").new()
	map.game = game
	map.position = Vector2(28, 90)
	map.size = Vector2(794, 357)
	panel.add_child(map)
	_label(panel, "左侧两路来敌 → 核心  ·  东北救工匠 → 东南救导师 → 深处寻秘藏", Rect2(30, 466, 790, 53), 17, MUTED)
	_button(panel, "返回 · M", Rect2(325, 521, 200, 45), close_modal)

func show_result(victory: bool) -> void:
	var panel := _open("result", Vector2(650, 510), "林地守住了" if victory else "核心失守")
	var profile: Dictionary = game.progression.entry(game.hero.class_id)
	_label(panel, "第 %d / 6 波 · 局内Lv.%d\n击败 %d 敌人 · 防御塔击败 %d\n探索 %d / 3 处 · 最终武器 %s" % [game.wave, game.level, game.stats.kills, game.stats.tower_kills, game.claimed_count(), Rules.weapon(game.hero.weapon_id).name], Rect2(34, 91, 582, 132), 20)
	_label(panel, "全局经验  +%d%s\n%s  全局Lv.%d · 经验 %d/%d · 可用点数 %d" % [game.profile_reward, " · 升级！" if game.profile_levels_gained > 0 else "", Rules.HEROES[game.hero.class_id].name, profile.level, profile.xp, game.progression.experience_target(game.hero.class_id), profile.points], Rect2(34, 239, 582, 84), 19, GOLD)
	_label(panel, "回到英雄养成页分配升级点，永久强化下一次出战。", Rect2(34, 337, 582, 43), 17, MUTED)
	_button(panel, "返回主菜单", Rect2(190, 421, 270, 54), func(): game.get_tree().paused = false; game.get_tree().reload_current_scene())

func toast(message: String, duration: float) -> void:
	toast_label.text = message
	toast_time = duration
