extends Node2D

var running := false
var started := false
var gold := 180
var core_health := 240.0
var core_max_health := 240.0
var wave := 0
var completed_waves := 0
var wave_active := false
var wave_clock := 0.0
var elapsed := 0.0
var shortcut_cooldown := 0.0
const WAVE_COUNTS := [0, 12, 18, 24, 30, 36, 36]
const ARMORED_COUNTS := [0, 0, 0, 4, 5, 5, 5]
var spawn_queue: Array[Dictionary] = []
var spawn_clock := 0.0
var enemies: Array[Enemy] = []
var towers: Array[Tower] = []
var hazards: Array[Dictionary] = []
var relics: Array[String] = []
var relic_ranks := {}
var pending_rewards := 0
var offered: Array = []
var camps: Array[Camp] = []
var camp_labels: Array[Label] = []
var threat := Threat.new()
var pickups: Array[Dictionary] = []
var experience := 0
var level := 1
var experience_target := 12
var build_kind := ""
var selected: Tower
var tower_boost := 0.0
var hero: Hero
var actors: Node2D
var projectiles: Node2D
var world: ForestWorld
var effects: BattlefieldEffects
var camera: Camera2D
var hud: CanvasLayer
var sound: GameSound
var trauma := 0.0
var reduced_shake := false
var boss_seen := false
var boss_defeated := false
var block_pointer := false
var hero_selected := false
var drag_start := Vector2.ZERO
var dragging := false
var navigation := AStarGrid2D.new()
var stats := {"kills": 0, "hero_kills": 0, "tower_kills": 0, "built": 0, "skills": 0, "levels": 0}

func _ready() -> void:
	get_window().title = "边境守望 · 核心切片预览"
	_configure_input()
	world = ForestWorld.new()
	world.game = self
	add_child(world)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	world.populate(actors)
	projectiles = Node2D.new()
	projectiles.z_index = 15
	add_child(projectiles)
	hero = Hero.new()
	hero.game = self
	hero.position = Rules.CORE + Vector2(128, 112)
	actors.add_child(hero)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hero="): hero.configure(argument.trim_prefix("--hero="))
	effects = BattlefieldEffects.new()
	effects.game = self
	effects.z_index = 20
	add_child(effects)
	camera = Camera2D.new()
	camera.position = hero.position
	add_child(camera)
	camera.make_current()
	sound = GameSound.new()
	add_child(sound)
	for index in range(3):
		camps.append(Camp.new(index))
		_create_camp(index)
	_rebuild_navigation()
	hud = load("res://scripts/hud.gd").new()
	hud.game = self
	add_child(hud)
	if "--qa-state" in OS.get_cmdline_user_args():
		var probe := Timer.new()
		probe.process_mode = Node.PROCESS_MODE_ALWAYS
		probe.wait_time = 0.1
		probe.timeout.connect(_write_qa_state)
		add_child(probe)
		probe.start()
		if "--qa-capture" in OS.get_cmdline_user_args():
			var capture := Timer.new()
			capture.process_mode = Node.PROCESS_MODE_ALWAYS
			capture.wait_time = 0.5
			capture.timeout.connect(_capture_qa)
			add_child(capture)
			capture.start()
	if "--smoke" in OS.get_cmdline_user_args():
		start_run()

func _configure_input() -> void:
	var actions := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "interact": [KEY_E], "recall": [KEY_R], "skill": [KEY_C, KEY_SPACE], "pause": [KEY_ESCAPE], "early": [KEY_F], "inventory": [KEY_TAB], "map": [KEY_M]}
	for action in actions:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in actions[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	if not InputMap.has_action("shoot"): InputMap.add_action("shoot")
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", mouse)

func start_run() -> void:
	started = true
	wave_clock = Rules.FIRST_WAVE
	hud.close_modal()
	if not hud.tutorial_seen and not _tutorial_suppressed():
		hud.show_tutorial(0)
	else:
		toast("点击路边空地建塔；第一波由你确认开始。", 5)

func _tutorial_suppressed() -> bool:
	return DisplayServer.get_name() == "headless" or "--smoke" in OS.get_cmdline_user_args() or "--qa-state" in OS.get_cmdline_user_args()

func rank(key: String) -> int:
	return int(relic_ranks.get(key, 0))

func _physics_process(delta: float) -> void:
	if not running: return
	elapsed += delta
	shortcut_cooldown = maxf(0, shortcut_cooldown - delta)
	tower_boost = maxf(0, tower_boost - delta)
	if not Input.is_action_pressed("shoot") and not dragging: block_pointer = false
	if wave < Rules.WAVES and not wave_active:
		wave_clock = maxf(0, wave_clock - delta)
		if wave_clock <= 0: start_wave()
	spawn_clock -= delta
	if not spawn_queue.is_empty() and spawn_clock <= 0:
		var entry: Dictionary = spawn_queue.pop_front()
		spawn_enemy(entry.kind, entry.lane, -1, Vector2.ZERO, entry.health)
		spawn_clock = 0.72 if wave < 4 else 0.55
	if wave_active and spawn_queue.is_empty() and not enemies.any(func(enemy): return is_instance_valid(enemy) and not enemy.dead and enemy.lane >= 0):
		wave_active = false
		completed_waves = wave
		var reward := 25 + wave * 4
		gold += reward
		wave_clock = prep_seconds()
		if wave == Rules.WAVES and boss_defeated:
			finish(true)
			return
		toast("防线守住了 · +%d金 · 现在可安心探索" % reward, 4)
	for hazard in hazards.duplicate():
		hazard.remaining -= delta
		if hazard.remaining <= 0:
			_resolve_hazard(hazard)
			hazards.erase(hazard)
	_update_camps(delta)
	for pickup in pickups.duplicate():
		pickup.age += delta
		var distance: float = pickup.point.distance_to(hero.center())
		if distance < 210 or pickup.age > 5:
			pickup.point = pickup.point.move_toward(hero.center(), delta * (350 + pickup.age * 160))
		if distance < 24:
			pickups.erase(pickup)
			hero.energy = minf(hero.max_energy, hero.energy + 3)
			gain_experience(pickup.amount)
	if pending_rewards > 0 and hud.modal_kind.is_empty(): open_reward()
	if hero.respawn_time <= 0 and hero.position.distance_to(Rules.CORE) < 170:
		hero.health = minf(hero.max_health, hero.health + delta * 5)
		hero.energy = minf(hero.max_energy, hero.energy + delta * 12)

func _process(delta: float) -> void:
	if hero == null: return
	var focus := hero.position
	var near_base := hero.position.distance_to(Rules.CORE) < 450
	if near_base:
		focus = Rules.CORE + Vector2(-100, 0) + (hero.position - Rules.CORE) * 0.32
	var target_zoom := 0.88 if near_base else 1.0
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, 1 - exp(-5 * delta))
	var half := get_viewport_rect().size * 0.5 / camera.zoom
	focus = focus.clamp(half, Rules.WORLD_SIZE - half)
	camera.position = camera.position.lerp(focus, 1 - exp(-7 * delta))
	trauma = maxf(0, trauma - delta * 1.6)
	camera.offset = Vector2(sin(elapsed * 67), sin(elapsed * 91)) * (0.0 if reduced_shake else trauma * trauma * 10)

func _unhandled_input(event: InputEvent) -> void:
	if not running: return
	if event.is_action_pressed("interact"): interact()
	elif event.is_action_pressed("recall"): hero.recall()
	elif event.is_action_pressed("early"): early_wave()
	elif event is InputEventMouseButton:
		var point: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			block_pointer = true
			hud.close_context()
			hero.command_move(point)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				selected = nearest_tower(point, 44)
				var site := nearest_site(point, 40)
				if selected != null or site >= 0:
					block_pointer = true
					hud.show_context(site, selected)
				elif point.distance_to(hero.center()) < 40 or point.distance_to(hero.position) < 27:
					dragging = true
					drag_start = point
					block_pointer = true
				elif hero_selected:
					block_pointer = true
					hero.command_move(point)
					hero_selected = false
				else:
					hud.close_context()
			elif dragging:
				dragging = false
				if point.distance_to(drag_start) > 24:
					hero.command_move(point)
					hero_selected = false
				else: hero_selected = true

func nearest_site(point: Vector2, radius: float) -> int:
	var result := -1
	for index in range(Rules.BUILD_SITES.size()):
		if point.distance_to(Rules.BUILD_SITES[index]) < radius and nearest_tower(Rules.BUILD_SITES[index], 15) == null:
			radius = point.distance_to(Rules.BUILD_SITES[index])
			result = index
	return result

func choose_build(kind: String) -> void:
	build_kind = kind

func build_error(point: Vector2) -> String:
	if not Rules.TOWERS.has(build_kind): return "请选择防御塔"
	if not can_manage(): return "英雄回到基地后可建设"
	if build_kind not in unlocked_tower_kinds(): return tower_lock_reason(build_kind)
	if towers.size() >= tower_limit(): return "塔位已满 · 探索营地可增加塔位"
	if nearest_site(point, 12) < 0: return "请点击路边的建设空地"
	if gold < int(Rules.TOWERS[build_kind].cost): return "金币不足"
	if point.distance_to(hero.position) < 35: return "先让英雄离开这块空地"
	return ""

func cleared_count() -> int:
	return camps.filter(func(camp: Camp): return camp.cleared).size()

func claimed_count() -> int:
	return camps.filter(func(camp: Camp): return camp.chest_claimed).size()

func tower_limit() -> int:
	var slots := 4 + 2 * cleared_count()
	if rank("swarm") > 0: slots += 2
	if rank("lone") > 0: slots -= 2
	return clampi(slots, 2, Rules.TOWER_LIMIT)

func unlocked_tower_kinds() -> Array:
	var keys := ["bolt"]
	if camps[0].cleared: keys.append("cannon")
	return keys

func tower_lock_reason(kind: String) -> String:
	if kind == "cannon" and not camps[0].cleared: return "肃清苔石林地后解锁"
	return ""

func try_build(point: Vector2) -> Tower:
	var error := build_error(point)
	if not error.is_empty():
		toast(error)
		return null
	gold -= int(Rules.TOWERS[build_kind].cost)
	var tower := Tower.new()
	tower.game = self
	tower.kind = build_kind
	tower.position = point
	actors.add_child(tower)
	towers.append(tower)
	stats.built += 1
	build_kind = ""
	selected = null
	_rebuild_navigation()
	burst(point + Vector2(0, -30), Color("f6d598"), 20)
	sound.play("build")
	toast("塔已建成 · 英雄靠近时进入指挥光环，伤害与射程提升", 3)
	return tower

func can_manage() -> bool:
	return hero.respawn_time <= 0 and hero.position.distance_to(Rules.CORE) <= Rules.BASE_RADIUS

func upgrade_selected() -> void:
	if not is_instance_valid(selected): return
	if not can_manage(): toast("返回基地、离开炮塔后可升级")
	elif not selected.upgrade(): toast("金币不足，或已达最高级")

func sell_selected() -> void:
	if not is_instance_valid(selected) or not can_manage(): return
	gold += int(selected.invested * 0.7)
	towers.erase(selected)
	selected.queue_free()
	selected = null
	_rebuild_navigation()

func nearest_tower(point: Vector2, radius: float) -> Tower:
	var result: Tower
	for tower in towers:
		var distance := minf(point.distance_to(tower.position), point.distance_to(tower.center()))
		if distance < radius:
			radius = distance
			result = tower
	return result

func interact() -> void:
	if hero.respawn_time > 0: return
	for index in range(3):
		if hero.position.distance_to(Rules.CAMPS[index]) < 125 and not camps[index].chest_claimed:
			if not camps[index].cleared:
				toast("先击败遗迹守卫")
				return
			camps[index].claim_chest()
			gold += Rules.CAMP_GOLD[index]
			hero.health = minf(hero.max_health, hero.health + 45)
			hero.shield = hero.max_shield
			var weapon_key: String = ["scatter", "sniper", "boomerang"][index]
			hero.equip_weapon(weapon_key, index + 1)
			pending_rewards += 1
			toast("秘藏 · %s +%d 已装备 · 一条路线待选" % [Rules.weapon(weapon_key).name, index + 1], 5)
			sound.play("reward")
			return
	for index in range(3):
		if camps[index].chest_claimed and hero.position.distance_to(Rules.CAMPS[index]) < 125:
			if shortcut_cooldown > 0:
				toast("捷径冷却 %d秒" % ceili(shortcut_cooldown), 2)
				return
			for enemy in enemies:
				if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(Rules.CAMPS[index]) < 260:
					toast("附近有敌人，无法使用捷径", 2)
					return
			hero.position = Rules.CORE + Vector2(150, 135)
			hero.navigation.clear()
			shortcut_cooldown = 25
			burst(hero.center(), Color("96e1d8"), 20)
			toast("沿已开启的捷径回到营地", 2)
			return
	toast("靠近宝匣或营地伙伴，再按 E；点击炮塔可升级")

func early_wave() -> void:
	if wave_active or wave >= Rules.WAVES: return
	if wave == 0: hud.show_wave_confirmation()
	else: start_wave()

func start_wave() -> void:
	if wave_active or wave >= Rules.WAVES or not running: return
	wave += 1
	wave_active = true
	wave_clock = 0
	spawn_clock = 0.15
	for entry in wave_roster(wave):
		spawn_queue.append(entry)
	if wave == Rules.WAVES:
		toast("焚林统领来袭 · 塔与英雄一起压上去", 5)
	else:
		var extra := ""
		if ARMORED_COUNTS[wave] > 0: extra += " · 铁甲出现"
		toast("第 %d / 6 波 · %s%s" % [wave, ["", "林地试探", "双线来袭", "冲锋压境", "重装突围", "防线考验"][wave], extra], 3)
	sound.play("wave")

## 四种问题：群潮（torch）、远程压制（shooter）、冲锋自爆（barrel）、重甲（armored，交给塔）。
func wave_roster(number: int) -> Array:
	var entries: Array = []
	var count: int = WAVE_COUNTS[number]
	for index in range(count):
		var kind := "torch"
		if number >= 2 and index % 6 == 0: kind = "shooter"
		if number >= 3 and index % 5 == 1: kind = "barrel"
		var health := 30.0 + number * 12
		if kind == "barrel": health *= 1.6
		entries.append({"kind": kind, "lane": index % 2, "health": threat.enemy_health(number, health)})
	for index in range(ARMORED_COUNTS[number]):
		entries.append({"kind": "armored", "lane": (index + 1) % 2, "health": threat.enemy_health(number, 220.0 + number * 12)})
	if number == Rules.WAVES:
		entries.push_front({"kind": "boss", "lane": 0, "health": 3200.0})
	return entries

func wave_preview_text() -> String:
	if wave >= Rules.WAVES: return ""
	var counts := {}
	for entry in wave_roster(wave + 1):
		counts[entry.kind] = counts.get(entry.kind, 0) + 1
	var labels := {"torch": "群潮", "barrel": "冲锋", "shooter": "远程压制", "armored": "铁甲（交给塔）", "boss": "统领"}
	var parts: Array[String] = []
	for kind in ["torch", "barrel", "shooter", "armored", "boss"]:
		if counts.get(kind, 0) > 0: parts.append("%s×%d" % [labels[kind], counts[kind]])
	return "下一波：" + " · ".join(parts)

func spawn_enemy(kind: String, lane: int, camp := -1, point := Vector2.ZERO, health := 50.0) -> Enemy:
	var enemy := Enemy.new()
	enemy.game = self
	enemy.kind = kind
	enemy.lane = lane
	enemy.camp = camp
	enemy.max_health = health
	enemy.health = health
	enemy.speed = 68 + minf(wave, 5) * 2.5 if lane >= 0 else 82.0
	if kind == "barrel": enemy.speed *= 1.2
	if kind == "shielded": enemy.speed = 55 if lane >= 0 else 62
	if kind == "armored": enemy.speed = 58 if lane >= 0 else 66
	if kind in ["boss", "warden"]: enemy.speed = 28 if lane >= 0 else 52
	if kind == "boss":
		boss_seen = true
	if lane >= 0:
		enemy.position = Rules.PATHS[lane][0] if point == Vector2.ZERO else point
		if point != Vector2.ZERO:
			var best := INF
			for segment in range(Rules.PATHS[lane].size() - 1):
				var closest := Geometry2D.get_closest_point_to_segment(point, Rules.PATHS[lane][segment], Rules.PATHS[lane][segment + 1])
				if point.distance_to(closest) < best:
					best = point.distance_to(closest)
					enemy.waypoint = segment + 1
	else: enemy.position = point
	actors.add_child(enemy)
	enemies.append(enemy)
	return enemy

func _create_camp(index: int) -> void:
	var marker := Node2D.new()
	marker.position = Rules.CAMPS[index]
	var structure := Art.sprite("Resources/Gold Mine/GoldMine_Inactive.png")
	structure.scale = Vector2.ONE * 0.75
	structure.position.y = -55
	marker.add_child(structure)
	var label := Label.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("ffe1a3"))
	label.add_theme_color_override("font_outline_color", Color("283d3b"))
	label.add_theme_constant_override("outline_size", 5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-140, 68)
	label.size.x = 280
	marker.add_child(label)
	camp_labels.append(label)
	actors.add_child(marker)

func _update_camps(delta: float) -> void:
	for index in range(3):
		var camp: Camp = camps[index]
		camp.unlocked = completed_waves >= Rules.CAMP_UNLOCK[index]
		var center: Vector2 = Rules.CAMPS[index]
		if camp.encounter_active and not enemies.any(func(enemy): return is_instance_valid(enemy) and not enemy.dead and enemy.camp == index):
			var finished: bool = camp.end_encounter()
			hero.energy = minf(hero.max_energy, hero.energy + 18)
			if finished:
				threat.note_camp_cleared()
				var unlock_text := " · 重炮已解锁" if index == 0 else (" · 寒霜已解锁" if index == 1 else "")
				toast("区域肃清 · 宝匣与回营捷径已开放" + unlock_text, 4)
			else:
				gold += 20
				toast("前哨拿下 · +20金 · 沿标记继续探索", 3)
		if camp.can_start_encounter() and hero.position.distance_to(exploration_target(index)) < 390: _spawn_camp_stage(index)
		var suffix := ""
		if camp.chest_claimed: suffix = " · 已探索"
		elif not camp.unlocked: suffix = "\n守住第%d波后开放" % Rules.CAMP_UNLOCK[index]
		elif camp.cleared: suffix = "\nE 开启宝匣" if index < 2 else "\nE 开启秘藏"
		elif hero.position.distance_to(center) < 450: suffix = "\n探索据点"
		camp_labels[index].text = Rules.CAMP_NAMES[index] + suffix

func _spawn_camp_stage(index: int) -> void:
	var stage: int = camps[index].begin_encounter()
	var count: int = 4 + stage + index
	for guard in range(count):
		var point: Vector2 = exploration_target(index) + Vector2.RIGHT.rotated(TAU * guard / count + 0.2) * 235
		var kind := "shooter" if guard % 3 == 0 else "torch"
		spawn_enemy(kind, -1, index, point, 54.0 + index * 20 + stage * 10)

func exploration_target(index: int) -> Vector2:
	# 单节点营地：节点就是营地本身；多节点时按进度沿路线推进。
	if Rules.CAMP_NODES <= 1 or camps[index].progress >= Rules.CAMP_NODES:
		return Rules.CAMPS[index]
	return Rules.EXPLORATION_ROUTES[index][mini(2, camps[index].progress)]

func clipped_ray(start: Vector2, end: Vector2) -> Vector2:
	var result := end
	for rectangle in world.cover_rects:
		var points := [rectangle.position, rectangle.position + Vector2(rectangle.size.x, 0), rectangle.end, rectangle.position + Vector2(0, rectangle.size.y)]
		for index in range(4):
			var contact = Geometry2D.segment_intersects_segment(start, end, points[index], points[(index + 1) % 4])
			if contact != null and start.distance_to(contact) < start.distance_to(result): result = contact
	return result

func line_of_sight(start: Vector2, end: Vector2) -> bool:
	return clipped_ray(start, end).distance_to(end) < 2

func nearest_target(point: Vector2, radius: float) -> Enemy:
	var result: Enemy
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		if enemy.kind == "armored": continue
		var distance := point.distance_to(enemy.center())
		if distance <= radius and line_of_sight(point, enemy.center()):
			radius = distance
			result = enemy
	return result

func nearest_enemy(point: Vector2, radius: float, excluded: Enemy = null, excluded_enemies: Array = []) -> Enemy:
	var result: Enemy
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy == excluded or enemy in excluded_enemies: continue
		var distance := point.distance_to(enemy.center())
		if distance < radius:
			radius = distance
			result = enemy
	return result

func leading_enemy(point: Vector2, radius: float) -> Enemy:
	var result: Enemy
	var remaining := INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or point.distance_to(enemy.position) > radius: continue
		var candidate := enemy.remaining_route()
		if candidate < remaining:
			remaining = candidate
			result = enemy
	return result

func fire_projectile(origin: Vector2, direction: Vector2, damage: float, kind: String, empowered: bool) -> Projectile:
	var bullet := Projectile.new()
	bullet.game = self
	bullet.position = origin
	bullet.direction = direction.normalized()
	bullet.damage = damage
	bullet.kind = kind
	bullet.empowered = empowered
	if kind in Rules.weapon_keys(): bullet.upgrade_level = hero.weapon_level
	if Rules.TOWERS.has(kind):
		bullet.color = Rules.TOWERS[kind].color
		bullet.max_distance = 650 if empowered else float(Rules.TOWERS[kind].range) + 100
	elif kind in Rules.weapon_keys(): bullet.color = Rules.weapon(kind).color
	if kind == "cannon":
		bullet.splash = 90 * (1 + rank("blast") * 0.2)
		bullet.speed = 570
		bullet.lifetime = 1.8
	elif kind == "sniper":
		bullet.speed = 1250
		bullet.max_distance = 1000
	elif kind == "rocket":
		bullet.speed = 410
		bullet.splash = 105 * (1 + rank("blast") * 0.2)
		bullet.lifetime = 2.5
	elif kind == "boomerang":
		bullet.speed = 460
		bullet.pierce = 99
		bullet.lifetime = 3
	projectiles.add_child(bullet)
	return bullet

func enemy_bullet(origin: Vector2, direction: Vector2, damage: float, speed: float) -> Projectile:
	var bullet := Projectile.new()
	bullet.game = self
	bullet.position = origin
	bullet.direction = direction
	bullet.damage = damage
	bullet.speed = speed
	bullet.lifetime = 5
	bullet.max_distance = 1100
	bullet.hostile = true
	projectiles.add_child(bullet)
	return bullet

func radial_damage(point: Vector2, radius: float, damage: float, source: String, empowered := true) -> void:
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.center().distance_to(point) < radius:
			enemy.take_damage(damage, empowered, source)
			enemy.knockback += (enemy.center() - point).normalized() * 65

func sweep_bullets(point: Vector2, radius: float, direction := Vector2.ZERO) -> void:
	for bullet in projectiles.get_children():
		if bullet is Projectile and bullet.hostile and bullet.position.distance_to(point) < radius:
			if direction == Vector2.ZERO or absf(direction.angle_to(bullet.position - point)) < 1.35:
				burst(bullet.position, Color("99e9e2"), 4)
				bullet.queue_free()

func enemy_defeated(enemy: Enemy, source: String) -> void:
	enemies.erase(enemy)
	stats.kills += 1
	if source == "hero": stats.hero_kills += 1
	else: stats.tower_kills += 1
	var bounty := 2 if enemy.lane >= 0 else 4
	if enemy.kind == "shielded": bounty = 12
	if enemy.kind == "armored": bounty = 7
	gold += int(round(bounty * kill_gold_scale()))
	if enemy.kind == "boss":
		boss_defeated = true
		gold += 80
		shake(0.65)
		sound.play("boom")
	pickups.append({"point": enemy.center(), "age": 0.0, "amount": 8 if enemy.kind in ["boss", "warden", "barrel", "shielded"] else (5 if enemy.kind == "armored" else 3)})
	if source == "hero" and rank("leech") > 0:
		hero.shield = minf(hero.max_shield, hero.shield + 3 * rank("leech"))
		if hero.weapon_id == "sword": hero.health = minf(hero.max_health, hero.health + 2 * rank("leech"))

func enemy_escaped(enemy: Enemy) -> void:
	enemies.erase(enemy)

func gain_experience(amount: int) -> void:
	experience += amount
	while experience >= experience_target:
		experience -= experience_target
		experience_target += 7
		level += 1
		stats.levels += 1
		hero.max_health += 2.0
	if pending_rewards > 0 and hud.modal_kind.is_empty(): open_reward()

func open_reward(_title := "") -> void:
	if not running or pending_rewards <= 0: return
	var group := pending_group()
	if group.is_empty():
		pending_rewards = 0
		gold += 50
		return
	offered = Rules.ACTIVE_RELICS.filter(func(key): return String(Rules.RELICS[key].group) == group)
	hud.show_reward("营地秘藏 · 选择一条路线", offered)
	sound.play("reward")

## 还没选过的第一组；三组都选完就返回空。
func pending_group() -> String:
	for group in Rules.RELIC_GROUPS:
		if not _group_taken(group): return group
	return ""

func _group_taken(group: String) -> bool:
	for key in Rules.ACTIVE_RELICS:
		if String(Rules.RELICS[key].group) == group and rank(key) > 0: return true
	return false

func claim_relic(key: String) -> void:
	if not offered.has(key) or pending_rewards <= 0: return
	if not Rules.ACTIVE_RELICS.has(key): return
	relic_ranks[key] = 1
	if not relics.has(key): relics.append(key)
	pending_rewards -= 1
	offered.clear()
	hud.close_modal()
	if pending_rewards > 0: open_reward()
	else: toast("获得：%s" % Rules.RELICS[key].name, 2)

func tower_damage_scale() -> float:
	var scale := 1.0
	if rank("lone") > 0: scale *= 1.40
	if rank("swarm") > 0: scale *= 0.85
	if rank("vanguard") > 0: scale *= 0.90
	if rank("command") > 0: scale *= 1.25
	return scale

func hero_damage_scale() -> float:
	if rank("vanguard") > 0: return 1.35
	if rank("command") > 0: return 0.90
	return 1.0

func prep_seconds() -> float:
	var seconds := Rules.PREPARATION
	if rank("raid") > 0: seconds -= 15.0
	if rank("hold") > 0: seconds += 20.0
	return maxf(20.0, seconds)

func kill_gold_scale() -> float:
	return 1.4 if rank("raid") > 0 else 1.0

func damage_core(amount: float) -> void:
	if not running: return
	core_health = maxf(0, core_health - amount)
	shake(0.3)
	burst(Rules.CORE, Color("ee9674"), 12)
	if core_health <= 0: finish(false)

func add_hazard(point: Vector2, radius: float, duration: float, damage := 32.0) -> void:
	hazards.append({"point": point, "radius": radius, "remaining": duration, "total": duration, "damage": damage})

func _resolve_hazard(hazard: Dictionary) -> void:
	explosion(hazard.point, hazard.radius, Color("f7a97f"))
	if hero.center().distance_to(hazard.point) < hazard.radius: hero.take_damage(hazard.damage)
	shake(0.22)
	sound.play("boom", 3)

func _rebuild_navigation() -> void:
	navigation.region = Rect2i(Vector2i.ZERO, Vector2i(Rules.WORLD_SIZE / 64))
	navigation.cell_size = Vector2(64, 64)
	navigation.offset = Vector2(32, 32)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for tower in towers:
		navigation.set_point_solid(Vector2i(tower.position / 64))
	for rectangle in world.cover_rects:
		for column in range(int(rectangle.position.x / 64), ceili(rectangle.end.x / 64)):
			for row in range(int(rectangle.position.y / 64), ceili(rectangle.end.y / 64)):
				if navigation.is_in_boundsv(Vector2i(column, row)): navigation.set_point_solid(Vector2i(column, row))

func navigation_path(start: Vector2, end: Vector2) -> PackedVector2Array:
	var first := Vector2i(start.clamp(Vector2(32, 32), Rules.WORLD_SIZE - Vector2(33, 33)) / 64)
	var last := Vector2i(end.clamp(Vector2(32, 32), Rules.WORLD_SIZE - Vector2(33, 33)) / 64)
	if navigation.is_point_solid(first):
		for offset in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, -1)]:
			if navigation.is_in_boundsv(first + offset) and not navigation.is_point_solid(first + offset):
				first += offset
				break
	if navigation.is_point_solid(last):
		var found := false
		for distance in range(1, 4):
			for offset in [Vector2i(distance, 0), Vector2i(-distance, 0), Vector2i(0, distance), Vector2i(0, -distance)]:
				if navigation.is_in_boundsv(last + offset) and not navigation.is_point_solid(last + offset):
					last += offset
					found = true
					break
			if found: break
	var path := navigation.get_point_path(first, last, true)
	if not path.is_empty(): path.remove_at(0)
	return path

func finish(victory: bool) -> void:
	if not running: return
	running = false
	hud.show_result(victory)

func shake(amount: float) -> void:
	trauma = minf(trauma + amount, 1)

func toast(message: String, duration := 3.0) -> void:
	if hud != null: hud.toast(message, duration)

func spark(point: Vector2, velocity: Vector2, color: Color, duration: float, size: float) -> void:
	effects.particles.append({"point": point, "velocity": velocity, "color": color, "life": duration, "total": duration, "size": size})

func burst(point: Vector2, color: Color, count: int) -> void:
	for index in range(count): spark(point, Vector2.RIGHT.rotated(randf() * TAU) * randf_range(40, 160), color, randf_range(0.2, 0.5), randf_range(2, 5))

func explosion(point: Vector2, radius: float, color: Color, _heavy := false) -> void:
	effects.rings.append({"point": point, "radius": radius, "color": color, "life": 0.35, "total": 0.35})
	if _heavy: effects.animations.append({"point": point, "radius": radius, "time": 0.0})
	burst(point, color, 14)

func lightning(start: Vector2, end: Vector2) -> void:
	var points := PackedVector2Array([start])
	for index in range(1, 6): points.append(start.lerp(end, index / 6.0) + Vector2(randf_range(-9, 9), randf_range(-9, 9)))
	points.append(end)
	effects.bolts.append({"points": points, "life": 0.2})

func float_text(point: Vector2, message: String, color: Color, font_size := 18) -> void:
	var label := Label.new()
	label.text = message
	label.position = point - Vector2(25, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("293541"))
	label.add_theme_constant_override("outline_size", 4)
	effects.add_child(label)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", point.y - 45, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)

func _write_qa_state() -> void:
	var output := FileAccess.open("user://qa_state.json", FileAccess.WRITE)
	var target: Vector2 = hero.locked.center() if is_instance_valid(hero.locked) and not hero.locked.dead else Vector2.ZERO
	output.store_string(JSON.stringify({"pid": OS.get_process_id(), "started": started, "running": running, "hero": [hero.position.x, hero.position.y], "class": hero.class_id, "energy": hero.energy, "aim": [hero.aim.x, hero.aim.y], "target": [target.x, target.y], "skill_time": hero.skill_time, "dash_time": hero.dash_time, "camera": [camera.position.x, camera.position.y], "zoom": camera.zoom.x, "gold": gold, "wave": wave, "wave_active": wave_active, "towers": towers.size(), "weapon": hero.weapon_id, "shield": hero.shield, "level": level, "skill_cooldown": hero.skill_cooldown, "dash_cooldown": hero.dash_cooldown, "attacks": hero.shot_count, "projectiles": projectiles.get_child_count(), "modal": hud.modal_kind, "context": hud.context != null, "navigating": not hero.navigation.is_empty()}))

func _capture_qa() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://qa_window.png")
