extends SceneTree

var game: Node2D
var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("ARENA FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	check(game.hero != null, "Arena creates a hero")
	check(game.core_health == game.core_max, "Arena creates a core")
	check(game.spawn_points.size() == 8, "Arena has eight spawn regions")
	var compass := {
		"东": Vector2.RIGHT, "东南": Vector2(1, 1), "南": Vector2.DOWN,
		"西南": Vector2(-1, 1), "西": Vector2.LEFT, "西北": Vector2(-1, -1),
		"北": Vector2.UP, "东北": Vector2(1, -1),
	}
	for region in range(game.spawn_points.size()):
		var name: String = game._region_name(region)
		var expected: Vector2 = compass.get(name, Vector2.ZERO)
		var actual: Vector2 = game.spawn_points[region] - game.CORE
		check(expected != Vector2.ZERO and actual.normalized().dot(expected.normalized()) > 0.999, "Region %d direction matches label %s" % [region, name])
	for viewport_size in [Vector2(1280, 800), Vector2(1920, 1080)]:
		var zoom := Vector2(0.78, 0.78)
		var half: Vector2 = viewport_size / (zoom * 2.0)
		for requested in [Vector2.ZERO, game.ARENA_SIZE]:
			var constrained: Vector2 = game._constrain_camera_center(requested, viewport_size, zoom)
			check(constrained.x >= half.x and constrained.y >= half.y and constrained.x <= game.ARENA_SIZE.x - half.x and constrained.y <= game.ARENA_SIZE.y - half.y, "Camera keeps map inside view at %s" % viewport_size)
	var oversized: Vector2 = game._constrain_camera_center(Vector2.ZERO, Vector2(3840, 2160), Vector2(0.78, 0.78))
	check(oversized.is_equal_approx(game.ARENA_SIZE * 0.5), "Camera centers the map when it is smaller than the viewport")
	check(game.flow_at(game.CORE + Vector2(300, 0)).length() > 0.0, "Flow field points toward the core")

	var camp_drop: ArenaDrop
	for drop in game.drops:
		if is_instance_valid(drop) and drop.cache:
			camp_drop = drop
	check(camp_drop != null, "The first rest spawns a camp chest")
	if camp_drop != null:
		var chest_offset: Vector2 = camp_drop.position - game.CORE
		var chest_region: int = posmod(roundi(chest_offset.angle() * game.REGION_COUNT / TAU), game.REGION_COUNT)
		check("宝匣" in game.hud.phase_hint and game._region_name(chest_region) in game.hud.phase_hint, "First rest shows the actual chest direction")
		game.hero.position = camp_drop.position
		await create_timer(0.25).timeout
		check(game.camps_cleared == 1, "Collecting a camp chest advances camp progression")
		check(not ("宝匣" in game.hud.phase_hint), "Collected chest no longer appears in the rest hint")
		check(game.passive_selecting, "Camp chest opens a powerful passive choice")
		var passive_key: String = game.passive_choices[0]
		game.choose_passive(passive_key)
		check(not game.passive_selecting, "Choosing a camp passive resumes the run")
		check(game.hero.passives.size() > 0 or "lone" in game.relics or "swarm" in game.relics or "vanguard" in game.relics or "command" in game.relics or "raid" in game.relics or "hold" in game.relics, "Camp passive applies")
	game.start_rest(20.0)
	check("宝匣" in game.hud.phase_hint, "A new rest announces its chest")
	game.expire_normal_drops()
	check(not ("宝匣" in game.hud.phase_hint), "Expired chest no longer appears in the rest hint")

	var level_before: int = game.hero.level
	var level_pool := ArenaUpgrades.build_pool(game.hero, "level")
	check("pistol_akimbo" in level_pool and not ("bow_hunter" in level_pool), "Weapon-specific upgrades filter by weapon")
	check("knight_bulwark" in level_pool and not ("ranger_tempo" in level_pool), "Class-specific upgrades filter by hero")
	check(not ("tower_link" in level_pool), "Tower-only cards are not offered before any tower is built")
	check(ArenaUpgrades.weight_for("power", game.hero, 1) > ArenaUpgrades.weight_for("storm", game.hero, 1), "Early pool favors common cards")
	check(ArenaUpgrades.weight_for("storm", game.hero, 6) > ArenaUpgrades.weight_for("power", game.hero, 6), "Late pool favors epic cards")
	check(game.level_cycles == 8, "First level is configured for eight cycles")
	game.hero.extra_weapon_keys.append("bow")
	var dual_weapon_pool := ArenaUpgrades.build_pool(game.hero, "level")
	check("bow_broadhead" in dual_weapon_pool, "Card pool supports multiple equipped weapon keys")
	game.hero.extra_weapon_keys.erase("bow")
	var pre_bulwark: float = game.hero.damage_reduction
	game.hero.apply_passive("knight_bulwark")
	check(game.hero.damage_reduction > pre_bulwark, "Knight class passive applies its effect")
	var pre_tier: int = game.hero.weapon_level
	game.hero.apply_passive("pistol_quickdraw")
	game.hero.apply_passive("pistol_ricochet")
	check(game.hero.weapon_level >= maxi(2, pre_tier), "Two weapon cards evolve the weapon")
	game.hero.apply_passive("pistol_storm")
	game.hero.apply_passive("pistol_caliber")
	check(game.hero.weapon_level == 3, "Four weapon cards unlock weapon tier 3")
	var tower_speed_before: float = game.tower_attack_speed_scale("bolt")
	game.hero.apply_passive("tower_bolt")
	check(game.tower_attack_speed_scale("bolt") > tower_speed_before, "Tower bolt passive speeds towers up")
	var tower_cost_before: int = game.tower_cost("bolt")
	game.hero.apply_passive("tower_engineer")
	check(game.tower_cost("bolt") < tower_cost_before, "Tower engineer passive discounts construction")
	game.hero.apply_passive("tower_command")
	check(game.tower_attack_speed_scale("cannon", game.hero.position) > 1.0, "Tower command speeds nearby towers")
	game.hero.passives["tower_link"] = 1
	game.hero.passives["tower_network"] = 1
	check("tower_fortress" in ArenaUpgrades.ready_synergies(game.hero), "Tower synergy is ready after prerequisites")
	game.hero.passives.erase("tower_link")
	game.hero.passives.erase("tower_network")
	var camp_pool := ArenaUpgrades.build_pool(game.hero, "camp")
	check(not ("power" in camp_pool), "Camp pool excludes common upgrades")
	game.hero.passives["burn"] = 1
	game.hero.passives["chain"] = 1
	var synergy_pool := ArenaUpgrades.build_pool(game.hero, "level")
	check("stormfire" in synergy_pool, "Synergy appears only after prerequisites")
	game.hero.passives.erase("burn")
	game.hero.passives.erase("chain")
	var rolled_choices := ArenaUpgrades.roll(game.hero, "level", 3, game.rng, true, true)
	var rolled_weapon := false
	var rolled_element := false
	for key in rolled_choices:
		if ArenaUpgrades.DEFS[key].has("weapon"): rolled_weapon = true
		if "元素" in ArenaUpgrades.DEFS[key].tags: rolled_element = true
	check(rolled_choices.size() == 3 and rolled_weapon and rolled_element, "Roll guarantees a weapon and element card")
	game.hero.add_xp(500)
	check(game.passive_selecting, "Level up opens a passive choice")
	var rerolls_before: int = game.passive_rerolls
	game.reroll_passive_choice()
	check(game.passive_rerolls == rerolls_before - 1 and game.passive_selecting, "Passive reroll refreshes the choice")
	while game.passive_selecting:
		game.choose_passive(game.passive_choices[0])
	check(game.hero.level > level_before, "Level up advances the hero")

	game.gold = 600
	game.build_kind = "bolt"
	var cell: Vector2i = game.world_to_cell(game.CORE + Vector2(260, 0))
	check(game.can_place(cell) == "", "A legal cell can host a tower")
	var tower = game.place_tower(cell)
	check(tower != null and game.towers.size() == 1, "Placing a tower consumes a slot")
	check(ArenaTower.STATS.size() == 7 and ArenaTower.TOWER_ORDER.size() == 7, "Seven tower types are available")
	game.build_kind = "banner"
	var banner_cell: Vector2i = cell + Vector2i(2, 0)
	game.place_tower(banner_cell)
	check(game.tower_support_bonus(game.towers[0]) > 0.0, "Banner aura buffs nearby towers")
	var basic_tower: ArenaTower = game.towers[0]
	var range_before: float = basic_tower.attack_range()
	var interval_before: float = basic_tower.attack_interval()
	basic_tower.level = 2
	check(basic_tower.attack_range() > range_before and basic_tower.attack_interval() < interval_before, "Tower level improves range and attack speed")
	basic_tower.level = 1
	game.select_tower(basic_tower)
	var target_before: String = basic_tower.target_mode
	game.cycle_tower_target()
	check(basic_tower.target_mode != target_before, "Tower targeting mode cycles")
	var all_target_before: String = game.default_target_mode
	game.cycle_all_targets()
	check(game.default_target_mode != all_target_before and game.towers[0].target_mode == game.default_target_mode, "Global targeting applies to every tower")
	game.select_tower(basic_tower)
	var dismiss_click := InputEventMouseButton.new()
	dismiss_click.button_index = MOUSE_BUTTON_LEFT
	dismiss_click.pressed = true
	dismiss_click.position = Vector2(2, 2)
	game._unhandled_input(dismiss_click)
	check(game.selected_tower == null, "Clicking outside closes the tower panel")
	var gold_before_sell: int = game.gold
	var count_before_sell: int = game.towers.size()
	game.select_tower(game.towers[1])
	game.sell_selected()
	check(game.towers.size() == count_before_sell - 1 and game.gold > gold_before_sell, "Tower can be sold for a refund")
	check(game.blocked[game.cell_index(cell)], "Tower blocks its grid cell")
	check(game.can_place(cell + Vector2i(1, 0)) == "不能挨着其他塔", "Towers cannot be adjacent")
	check(game.can_place(game.world_to_cell(game.CORE + Vector2(1200, 0))) == "超出建造范围", "Build radius is enforced")
	check(game.towers[0].upgrade() and game.towers[0].level == 2, "Towers can be upgraded with gold")
	var before_menu_build: int = game.towers.size()
	game.toggle_build_mode()
	game.build_cell = game._nearest_build_cell(Vector2i(25, 20))
	game.build_site_ok = true
	game.build_valid = true
	game.number_build("bolt")
	check(game.confirm_build() and game.towers.size() == before_menu_build + 1, "Selected tower places on confirm")
	var before_second_build: int = game.towers.size()
	game.toggle_build_mode()
	game.build_cell = game._nearest_build_cell(Vector2i(26, 20))
	game.build_site_ok = true
	game.build_valid = true
	game.number_build("bolt")
	check(game.confirm_build() and game.towers.size() == before_second_build + 1, "Build selection can be used again")
	var before_manual_click: int = game.towers.size()
	game.toggle_build_mode()
	game.build_cell = game._nearest_build_cell(Vector2i(24, 24))
	game.number_build("bolt")
	await create_timer(0.1).timeout
	game._set_build_cell(game._nearest_build_cell(Vector2i(24, 24)))
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	click_event.position = game.get_viewport().get_canvas_transform() * game.cell_center(game.build_cell)
	var gold_before_site: int = game.gold
	game._unhandled_input(click_event)
	check(game.build_site_selected and game.towers.size() == before_manual_click and game.gold == gold_before_site, "Clicking a legal site opens tower selection without spending gold")
	game.hud._update_build_menu()
	check(game.hud.build_palette.visible and game.hud.build_buttons.size() == 7, "Selected site shows seven tower choices")
	var menu_rect: Rect2 = game.hud.build_palette.get_global_rect()
	var screen_rect: Rect2 = game.get_viewport().get_visible_rect()
	check(screen_rect.encloses(menu_rect), "Tower selection stays inside the viewport")
	var selected_site: Vector2i = game.build_cell
	game.build_cell = Vector2i(0, 0)
	game.hud._update_build_menu()
	check(screen_rect.encloses(game.hud.build_palette.get_global_rect()), "Tower selection is clamped at the upper-left edge")
	game.build_cell = Vector2i(game.GRID_W - 1, game.GRID_H - 1)
	game.hud._update_build_menu()
	check(screen_rect.encloses(game.hud.build_palette.get_global_rect()), "Tower selection is clamped at the lower-right edge")
	game.build_cell = selected_site
	game.hud._update_build_menu()
	game.hud.build_buttons[0].pressed.emit()
	check(game.towers.size() == before_manual_click + 1 and not game.build_mode, "Selecting a tower builds at the chosen site")
	check(game.towers.back().cell == selected_site, "Selecting a tower preserves the exact chosen cell")
	var before_confirmed = game.towers.size()
	game.number_build("bolt")
	check(game.towers.size() == before_confirmed and game.build_mode, "Number key only selects a tower")
	var gold_before_rejected_click: int = game.gold
	var rejected_click := InputEventMouseButton.new()
	rejected_click.button_index = MOUSE_BUTTON_LEFT
	rejected_click.pressed = true
	rejected_click.position = game.get_viewport().get_canvas_transform() * game.CORE
	game._unhandled_input(rejected_click)
	check(game.build_cell == game.world_to_cell(game.CORE) and not game.build_valid and game.build_reason == "离核心太近", "Invalid click marks the actual cell and explains the rejection")
	check(game.towers.size() == before_confirmed and game.gold == gold_before_rejected_click and game.build_mode, "Invalid click does not place or charge for a tower elsewhere")
	var outside_world := Vector2(-game.CELL, game.CORE.y)
	rejected_click.position = game.get_viewport().get_canvas_transform() * outside_world
	game._unhandled_input(rejected_click)
	check(game.build_cell.x == -1 and game.build_reason == "超出地图" and not game.build_valid, "Outside-map click is not clamped to the edge")
	check(game.towers.size() == before_confirmed and game.gold == gold_before_rejected_click and game.build_mode, "Outside-map click neither builds nor spends gold")
	game._set_build_cell(game._nearest_build_cell(Vector2i(26, 24)))
	game.confirm_build()
	check(game.towers.size() == before_confirmed + 1, "Confirm places the selected tower")
	game.toggle_build_mode()
	var cancel_gold: int = game.gold
	var cancel_tower_count: int = game.towers.size()
	check(game.select_build_site(game._nearest_build_cell(Vector2i(26, 24))), "A free site can be selected before cancelling")
	var cancel_event := InputEventMouseButton.new()
	cancel_event.button_index = MOUSE_BUTTON_RIGHT
	cancel_event.pressed = true
	game._unhandled_input(cancel_event)
	check(not game.build_mode and not game.build_site_selected and game.gold == cancel_gold and game.towers.size() == cancel_tower_count, "Right click cancels without building or charging")
	game.toggle_build_mode()
	check(game.select_build_site(game._nearest_build_cell(Vector2i(26, 24))), "A site can be selected before Escape")
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	game._unhandled_input(escape_event)
	check(not game.build_mode and not game.build_site_selected and game.gold == cancel_gold, "Escape cancels the tower selection")
	game.toggle_build_mode()
	check(game.select_build_site(game._nearest_build_cell(Vector2i(26, 24))), "A site can be selected before focus expires")
	var saved_phase: String = game.phase
	var saved_focus: float = game.focus
	game.phase = "spawn"
	game.focus = 0.01
	game._update_build_mode(0.1)
	check(not game.build_mode and not game.build_site_selected and game.gold == cancel_gold, "Focus exhaustion closes the selection without charging")
	game.phase = saved_phase
	game.focus = saved_focus
	game.toggle_build_mode()
	var saved_gold: int = game.gold
	game.gold = 0
	check(game.select_build_site(game._nearest_build_cell(Vector2i(26, 24))), "A location can be selected before choosing an affordable tower")
	game.choose_build_kind("bolt")
	check(game.build_mode and game.build_site_selected and game.gold == 0 and game.towers.size() == cancel_tower_count, "Unaffordable tower does not spend or build")
	game.gold = saved_gold
	game.toggle_build_mode()
	game.toggle_build_mode()
	game.number_build("bolt")
	var wheel_change: String = game.build_kind
	var wheel_event := InputEventMouseButton.new()
	wheel_event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_event.pressed = true
	game._unhandled_input(wheel_event)
	check(game.build_kind != wheel_change, "Mouse wheel switches selected tower")
	var global_before: float = game.tower_global_damage_bonus()
	game.hero.apply_passive("tower_cannon")
	check(game.tower_global_damage_bonus() > global_before, "Specialist tower card also buffs all towers")
	game.build_cell = game._nearest_build_cell(Vector2i(26, 24))
	game.number_build("cannon")
	game.confirm_build()
	check(game.distinct_tower_kinds() >= 2, "Mixed tower composition is tracked")
	var mode_tower: ArenaTower = game.towers[0]
	var frost_target: ArenaEnemy = game.spawn_enemy("torch", mode_tower.position + Vector2(120, 0), 500.0)
	mode_tower.kind = "frost"
	mode_tower.fire(frost_target)
	check(mode_tower.last_attack_mode == "frost_nova" and frost_target.slow_time > 0.0, "Frost tower attacks with a slowing nova")
	game.enemy_escaped(frost_target)
	frost_target.queue_free()
	var venom_target: ArenaEnemy = game.spawn_enemy("torch", mode_tower.position + Vector2(120, 0), 500.0)
	mode_tower.kind = "venom"
	mode_tower.fire(venom_target)
	check(mode_tower.last_attack_mode == "venom_cloud" and venom_target.poison_time > 0.0, "Venom tower attacks with a poison cloud")
	game.enemy_escaped(venom_target)
	venom_target.queue_free()
	var laser_target: ArenaEnemy = game.spawn_enemy("torch", mode_tower.position + Vector2(120, 0), 500.0)
	mode_tower.kind = "laser"
	var laser_health: float = laser_target.health
	mode_tower.fire(laser_target)
	check(mode_tower.last_attack_mode == "laser_beam" and laser_target.health < laser_health, "Laser tower attacks with a beam")
	game.enemy_escaped(laser_target)
	laser_target.queue_free()
	var arc_a: ArenaEnemy = game.spawn_enemy("torch", mode_tower.position + Vector2(90, 0), 500.0)
	var arc_b: ArenaEnemy = game.spawn_enemy("torch", mode_tower.position + Vector2(130, 0), 500.0)
	mode_tower.kind = "arc"
	var arc_b_health: float = arc_b.health
	mode_tower.fire(arc_a)
	check(mode_tower.last_attack_mode == "arc_chain" and arc_b.health < arc_b_health, "Arc tower attacks with chain lightning")
	game.enemy_escaped(arc_a)
	game.enemy_escaped(arc_b)
	arc_a.queue_free()
	arc_b.queue_free()
	mode_tower.kind = "bolt"
	var bolt_target: ArenaEnemy = game.spawn_enemy("torch", mode_tower.position + Vector2(120, 0), 500.0)
	mode_tower.fire(bolt_target)
	check(mode_tower.last_attack_mode == "bolt_volley", "Bolt tower uses a volley")
	game.enemy_escaped(bolt_target)
	bolt_target.queue_free()
	var preview_info: Dictionary = game.passive_info("tower_bolt")
	check(preview_info.has("preview") and String(preview_info.preview) != "", "Tower card shows a numeric preview")
	var tower_disabled_before: float = mode_tower.disabled_time
	game.boss_phase_shift(mode_tower.position, 1)
	check(mode_tower.disabled_time > tower_disabled_before, "Boss phase shift silences nearby towers")
	var hitstop_before: float = game.hitstop
	game.hit_feedback(mode_tower.position + Vector2(40, 0), 25.0, true, Vector2.RIGHT)
	check(game.hitstop > hitstop_before and game.sparks.size() > 0, "Critical hits add hitstop and impact sparks")
	check(game.audio != null and game.audio.streams.size() >= 6, "Procedural combat audio is available")
	var damage_test: ArenaEnemy = game.spawn_enemy("torch", game.CORE + Vector2(740, 220), 100.0)
	var hero_damage_before: float = float(game.damage_stats.hero)
	damage_test.take_damage(12.0, "hero")
	check(float(game.damage_stats.hero) > hero_damage_before, "Damage attribution records hero damage")
	game.enemy_escaped(damage_test)
	damage_test.queue_free()
	var knockback_test: ArenaEnemy = game.spawn_enemy("torch", game.CORE + Vector2(760, 260), 100.0)
	knockback_test.apply_knockback(Vector2.LEFT, 40.0)
	check(knockback_test.knockback.length() > 0.0, "Enemies receive knockback")
	game.enemy_escaped(knockback_test)
	knockback_test.queue_free()

	game.hero.position = game.CORE + Vector2(160, 0)
	var gold_before: int = game.gold
	var drop = game.spawn_drop(game.hero.position, 10, 5, false)
	await create_timer(0.35).timeout
	check(is_instance_valid(drop) == false, "Drops are collected on contact")
	check(game.gold >= gold_before + 5, "Collected gold reaches the hero wallet")

	var core_before: float = game.core_health
	game.hero.set_physics_process(false)
	for placed in game.towers:
		placed.active = false
	var leaked = game.spawn_enemy("torch", game.CORE, 30.0)
	await create_timer(0.25).timeout
	check(game.enemies.is_empty(), "Leaked enemies are removed from the live array")
	check(game.core_health < core_before, "Leaked enemies damage the core")

	game.towers[0].active = true
	var tower_health_before: float = game.towers[0].health
	var sapper = game.spawn_enemy("sapper", game.towers[0].position + Vector2(30, 0), 1000.0)
	await create_timer(0.25).timeout
	check(game.towers[0].health < tower_health_before, "Sappers damage towers")
	game.enemy_escaped(sapper)
	sapper.queue_free()

	var shield_before: float = game.hero.shield
	var shooter = game.spawn_enemy("shooter", game.hero.position + Vector2(70, 0), 1000.0)
	await create_timer(0.6).timeout
	check(game.hero.shield < shield_before or game.hero.health < game.hero.max_health, "Shooters threaten the hero")
	game.enemy_escaped(shooter)
	shooter.queue_free()

	game.spawn_budget = 4
	game.start_spawn()
	game.spawn_cluster()
	check(game.spawn_warnings.size() > 0, "Spawns are telegraphed by a moving ring")
	await create_timer(1.2).timeout
	check(game.enemies.size() > 0, "Spawn director creates enemies after the warning")
	check(game.flow_at(game.spawn_points[0]).length() > 0.0, "Spawned enemies have a flow direction")
	var hound_test: ArenaEnemy = game.spawn_enemy("hound", game.CORE + Vector2(700, 140), 60.0)
	check(hound_test.weakness == "frost" and hound_test.speed > 120.0, "Hound is a fast frost-weak hunter")
	game.enemy_escaped(hound_test)
	hound_test.queue_free()
	var sniper_test: ArenaEnemy = game.spawn_enemy("sniper", game.CORE + Vector2(680, 160), 80.0)
	check(sniper_test.weakness == "lightning", "Sniper is a lightning-weak ranged threat")
	game.enemy_escaped(sniper_test)
	sniper_test.queue_free()
	var grenadier_test: ArenaEnemy = game.spawn_enemy("grenadier", game.CORE + Vector2(680, 200), 100.0)
	check(grenadier_test.weakness == "fire", "Grenadier is a fire-weak area threat")
	game.enemy_escaped(grenadier_test)
	grenadier_test.queue_free()
	game.enemy_grenade(game.CORE + Vector2(500, 0), 80.0, 12.0, 0.2)
	check(game.danger_zones.size() > 0, "Grenadier creates a telegraphed danger zone")
	await create_timer(0.35).timeout
	check(game.danger_zones.is_empty(), "Danger zone resolves after its delay")
	var elite_test: ArenaEnemy = game.spawn_enemy("torch", game.CORE + Vector2(600, 180), 60.0, true)
	check(elite_test.elite_mod != "", "Elite enemies receive an affix")
	game.enemy_escaped(elite_test)
	elite_test.queue_free()
	var shaman_test: ArenaEnemy = game.spawn_enemy("shaman", game.CORE + Vector2(620, 220), 120.0)
	var hurt_test: ArenaEnemy = game.spawn_enemy("torch", game.CORE + Vector2(660, 220), 120.0)
	hurt_test.health = 40.0
	game.shaman_support(shaman_test.position)
	check(hurt_test.health > 40.0, "Shaman heals nearby enemies")
	game.enemy_escaped(shaman_test)
	game.enemy_escaped(hurt_test)
	shaman_test.queue_free()
	hurt_test.queue_free()
	var splitter_test: ArenaEnemy = game.spawn_enemy("splitter", game.CORE + Vector2(720, 220), 120.0)
	var before_split: int = game.enemies.size()
	splitter_test.take_damage(999.0)
	check(game.enemies.size() >= before_split, "Splitter death spawns children")

	var armored_test: ArenaEnemy = game.spawn_enemy("armored", game.CORE + Vector2(700, 0), 100.0)
	check(armored_test.weakness == "lightning" and armored_test.element_multiplier("lightning") > 1.0, "Armored enemies are weak to lightning")
	game.enemy_escaped(armored_test)
	armored_test.queue_free()
	var brute_test: ArenaEnemy = game.spawn_enemy("brute", game.CORE + Vector2(700, 100), 100.0)
	brute_test.apply_burn(10.0, 3.0)
	check(brute_test.weakness == "fire" and brute_test.burn_dps > 10.0, "Fire weakness amplifies burn")
	game.enemy_escaped(brute_test)
	brute_test.queue_free()
	var freeze_test: ArenaEnemy = game.spawn_enemy("torch", game.CORE + Vector2(800, 200), 100.0)
	freeze_test.apply_frost(2.0)
	freeze_test.apply_frost(2.0)
	freeze_test.apply_frost(2.0)
	check(freeze_test.freeze_time > 0.0, "Three frost applications freeze an enemy")
	game.enemy_escaped(freeze_test)
	freeze_test.queue_free()
	game.hero.apply_passive("burn")
	game.hero.apply_passive("wildfire")
	var fire_source: ArenaEnemy = game.spawn_enemy("torch", game.CORE + Vector2(850, 0), 100.0)
	var fire_target: ArenaEnemy = game.spawn_enemy("torch", game.CORE + Vector2(880, 0), 100.0)
	fire_source.apply_burn(12.0, 3.0)
	fire_source.take_damage(9999.0)
	check(fire_target.burn_time > 0.0, "Wildfire spreads burn on death")
	game.enemy_escaped(fire_target)
	fire_target.queue_free()
	var build_check: Dictionary = game.build_report()
	check(build_check.has("grade") and build_check.has("boss_affinity") and build_check.has("warnings"), "Boss build report has grade, affinity and warnings")
	# The Boss counter should use the effects of the currently equipped weapon.
	var boss_test_passives: Dictionary = game.hero.passives.duplicate(true)
	var boss_test_weapon: String = game.hero.weapon_key
	game.hero.passives = {"scatter_frost": 1}
	game.hero.weapon_key = "pistol"
	check(game.build_report().elements == 0 and game.build_report().boss_affinity != "frost", "Inactive scatter frost does not affect Boss affinity")
	game.hero.weapon_key = "scatter"
	check(game.build_report().elements == 1 and game.build_report().boss_affinity == "frost", "Equipped scatter frost affects Boss affinity")
	game.hero.weapon_key = boss_test_weapon
	game.hero.passives = boss_test_passives
	check(ArenaUpgrades.DEFS.size() >= 96, "Expanded card pool is available")
	check(ArenaUpgrades.DEFS.has("bullet_hell") and ArenaUpgrades.DEFS.has("tower_legion") and ArenaUpgrades.DEFS.has("combustion"), "Ballistic, tower and fire capstones are registered")
	check(ArenaUpgrades.DEFS.has("knight_champion") and ArenaUpgrades.DEFS.has("ranger_phantom") and ArenaUpgrades.DEFS.has("mage_archon"), "Class capstones are registered")
	game.hero.passives["burn"] = 2
	check(ArenaUpgrades.archetype_stacks(game.hero, "fire") >= 2 and ArenaUpgrades.archetype_tier(game.hero, "fire") >= 1, "Fire archetype reaches branch tier")
	game.hero.passives.erase("burn")
	var greed_before: float = game.hero.gold_mult
	game.hero.apply_passive("greed")
	check(game.hero.gold_mult > greed_before, "Greed card increases gold gain")

	game.dry_weapon_choices = 2
	game.dry_element_choices = 2
	game.open_passive_choice("level")
	var icons_present: bool = game.hud.passive_buttons.size() == game.passive_choices.size()
	for card in game.hud.passive_buttons:
		var icon := card.get_node_or_null("PassiveIcon") as TextureRect
		icons_present = icons_present and icon != null and icon.texture != null and not card.tooltip_text.is_empty()
	check(icons_present, "Each passive choice displays a shared semantic icon and full tooltip")
	var all_icon_cells_valid := true
	for key in ArenaUpgrades.DEFS:
		var icon_index: int = game.hud._passive_icon_cell(key, ArenaUpgrades.info(key))
		all_icon_cells_valid = all_icon_cells_valid and icon_index >= 0 and icon_index < 12
	check(all_icon_cells_valid, "Every passive definition maps to an existing icon atlas cell")
	check(game.hud._passive_icon_cell("tower_bolt", ArenaUpgrades.info("tower_bolt")) != game.hud._passive_icon_cell("tower_cannon", ArenaUpgrades.info("tower_cannon")), "Bolt and cannon passives use distinguishable motifs")
	game.hud.passive_buttons[0].emit_signal("pressed")
	check(not game.hud.passive_confirm.disabled, "Selecting an illustrated card enables confirm")
	var soft_weapon := false
	var soft_element := false
	for key in game.passive_choices:
		if ArenaUpgrades.DEFS[key].has("weapon"): soft_weapon = true
		if "元素" in ArenaUpgrades.DEFS[key].tags: soft_element = true
	check(soft_weapon and soft_element, "Two dry levels trigger weapon and element pity")
	var banish_key: String = game.passive_choices[0]
	game.banish_passive_choice(banish_key)
	check(banish_key in game.banished_passives and not (banish_key in game.passive_choices), "Banish removes one card from the pool")
	game.choose_passive(game.passive_choices[0])
	game.hero.passives["burn"] = 1
	game.hero.passives["chain"] = 1
	game.hero.passives.erase("stormfire")
	var ready_synergies := ArenaUpgrades.ready_synergies(game.hero)
	check("stormfire" in ready_synergies, "Ready synergy enters the weighted pool")
	game.hero.passives.erase("burn")
	game.hero.passives.erase("chain")
	var gold_before_empty: int = game.gold
	var saved_passives: Dictionary = game.hero.passives.duplicate()
	for key in ArenaUpgrades.DEFS:
		game.hero.passives[key] = int(ArenaUpgrades.DEFS[key].max)
	game.open_passive_choice("level")
	check(not game.passive_selecting and game.gold > gold_before_empty, "Empty upgrade pool converts to gold instead of soft-locking")
	game.hero.passives = saved_passives

	game.focus = game.focus_max
	game.toggle_build_mode()
	check(game.select_build_site(game._nearest_build_cell(Vector2i(26, 24))), "A site is available before the relic modal")
	game.hud._update_build_menu()
	var modal_gold: int = game.gold
	var modal_towers: int = game.towers.size()
	game.open_relic_choice("defense")
	game.number_build("bolt")
	game.choose_build_kind("bolt")
	check(not game.build_mode and not game.build_site_selected and not game.hud.build_palette.visible and game.gold == modal_gold and game.towers.size() == modal_towers, "Relic selection cancels construction and blocks building")
	game.choose_relic("lone")
	game.toggle_build_mode()
	check(game.select_build_site(game._nearest_build_cell(Vector2i(26, 24))), "A site is available before the passive modal")
	game.hud._update_build_menu()
	game.open_passive_choice("level")
	game.number_build("bolt")
	game.choose_build_kind("bolt")
	check(not game.build_mode and not game.build_site_selected and not game.hud.build_palette.visible and game.gold == modal_gold and game.towers.size() == modal_towers, "Passive selection cancels construction and blocks building")
	game.choose_passive(game.passive_choices[0])
	game.toggle_build_mode()
	check(game.select_build_site(game._nearest_build_cell(Vector2i(26, 24))), "A site is available before opening the guide")
	game.hud._update_build_menu()
	game.hud._show_ingame_guide()
	game.number_build("bolt")
	game.choose_build_kind("bolt")
	check(paused and not game.build_mode and not game.hud.build_palette.visible and game.gold == modal_gold and game.towers.size() == modal_towers, "Guide cancels construction and blocks building while paused")
	game.hud._close_guide()
	game.toggle_build_mode()
	check(game.select_build_site(game._nearest_build_cell(Vector2i(26, 24))), "A site is available before defeat")
	game.hud._update_build_menu()
	game.hero.invulnerability = 0.0
	game.hero.take_damage(9999.0)
	check(game.game_over and not game.running, "Hero death ends the run")
	check(game.hud.result_panel.visible, "Death shows the result panel")
	game.number_build("bolt")
	game.choose_build_kind("bolt")
	check(not game.build_mode and not game.build_site_selected and not game.hud.build_palette.visible and game.gold == modal_gold and game.towers.size() == modal_towers, "Defeat cancels construction and blocks building")

	print("ARENA CHECKS: %d, FAILURES: %d" % [checks, failures.size()])
	game.queue_free()
	await process_frame
	# Let the audio server release playback objects before the test process exits.
	await create_timer(1.0, true, false, true).timeout
	quit(0 if failures.is_empty() else 1)
