extends SceneTree

var game: Node2D
var phase := "explore"
var camp_index := 0
var last_construction := -10.0
var navigation_clock := 0.0
var report := {"visited_camps": [], "first_two_waves_core": [], "weapon_changes": [], "passives": [], "gold_curve": []}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var test_seed := 20261019
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--test-seed="): test_seed = int(argument.trim_prefix("--test-seed="))
	seed(test_seed)
	report["seed"] = test_seed
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.sound.enabled = false
	report["hero"] = game.hero.class_id
	_build_affordable()
	var iterations := 0
	var recorded_waves := 0
	while game.elapsed < 1000 and iterations < 90000:
		iterations += 1
		if game.hud.modal_kind == "result": break
		if game.hud.modal_kind == "reward":
			var priorities := ["swarm", "command", "hold", "lone", "vanguard", "raid"]
			var chosen := 0
			for key in priorities:
				if game.offered.has(key):
					chosen = game.offered.find(key)
					break
			report.passives.append(game.offered[chosen])
			game.hud.reward_buttons[chosen].pressed.emit()
		if game.hud.modal_kind == "confirm":
			game.hud.close_modal()
			game.start_wave()
		await physics_frame
		if not game.running: continue
		if game.completed_waves > recorded_waves:
			recorded_waves = game.completed_waves
			if recorded_waves <= 2: report.first_two_waves_core.append(game.core_health)
			report.gold_curve.append([recorded_waves, game.gold, game.towers.size()])
		var target := _movement_target()
		navigation_clock -= 1.0 / 60
		if navigation_clock <= 0:
			game.hero.command_move(target)
			navigation_clock = 0.3
		var enemy: Enemy = game.hero.auto_target()
		if enemy != null and game.hero.respawn_time <= 0:
			var distance: float = game.hero.position.distance_to(enemy.position)
			game.hero.fire()
			if game.hero.class_id == "knight" or (game.hero.class_id == "mage" and distance < 400) or (game.hero.class_id == "ranger" and distance < 150): game.hero.use_skill()
		if game.can_manage() and game.elapsed - last_construction > 2:
			_build_affordable()
			last_construction = game.elapsed
	_set_motion(Vector2.ZERO)
	paused = false
	report.merge({"elapsed": game.elapsed, "wave": game.wave, "core": game.core_health, "health": game.hero.health, "shield": game.hero.shield, "energy": game.hero.energy, "nodes": game.camps.map(func(camp): return camp.progress), "level": game.level, "gold": game.gold, "towers": game.towers.size(), "relics": game.relic_ranks, "camps": game.camps.map(func(camp): return camp.chest_claimed), "weapon": game.hero.weapon_id, "weapon_level": game.hero.weapon_level, "skill_level": game.hero.skill_level, "stats": game.stats, "boss_defeated": game.boss_defeated, "terminal": game.hud.modal_kind == "result", "phase": phase})
	var path := "user://exported_playthrough-%s.json" % game.hero.class_id if "--export-check" in OS.get_cmdline_user_args() else "res://test-results/playthrough-0.3-%s-%d.json" % [game.hero.class_id, test_seed]
	var output := FileAccess.open(path, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	print(JSON.stringify(report))
	var success: bool = game.boss_defeated and game.core_health > 0 and game.hud.modal_kind == "result" and game.claimed_count() == 3 and game.stats.tower_kills > 0 and game.stats.hero_kills > 0 and game.level >= 5
	game.queue_free()
	await process_frame
	quit(0 if success else 1)

func _movement_target() -> Vector2:
	if game.hero.respawn_time > 0: return game.hero.position
	var home := Rules.CORE + Vector2(160, 150)
	if phase == "explore":
		var center: Vector2 = game.exploration_target(camp_index)
		if game.camps[camp_index].cleared:
			if game.hero.position.distance_to(center) < 95:
				game.interact()
				if game.camps[camp_index].chest_claimed:
					report.visited_camps.append(game.elapsed)
					game.interact()
					phase = "return"
			return center
		var guard: Enemy = game.nearest_enemy(game.hero.position, 480)
		if guard != null and game.hero.position.distance_to(center) < 410:
			if game.hero.weapon_id in ["sword", "halberd"]: return guard.position + Vector2.RIGHT.rotated(game.elapsed) * 65
			return center + Vector2.RIGHT.rotated(game.elapsed * 0.8) * 245
		return center + Vector2(-150, 50)
	if phase == "return":
		if game.hero.position.distance_to(home) < 65:
			_build_affordable()
			phase = "defend"
		return home
	if not game.wave_active:
		if camp_index < 2 and game.camps[camp_index].chest_claimed and game.completed_waves >= Rules.CAMP_UNLOCK[camp_index + 1]:
			camp_index += 1
			phase = "explore"
			return home
		game.early_wave()
	for hazard in game.hazards:
		if game.hero.center().distance_to(hazard.point) < hazard.radius + 35:
			var direction: Vector2 = (game.hero.center() - hazard.point + Vector2(1, 1)).normalized()
			return game.hero.position + direction * 180
	var enemy: Enemy = game.nearest_enemy(Rules.CORE, 1150)
	if enemy != null:
		if game.hero.weapon_id in ["sword", "halberd"]: return enemy.position + Vector2(65, 20)
		var position := enemy.position + Vector2(230, 80)
		position.x = maxf(1420, position.x)
		position.y = clampf(position.y, Rules.CORE.y - 250, Rules.CORE.y + 250)
		return position
	return home

func _build_affordable() -> void:
	if not game.can_manage(): return
	var kinds: Array = game.unlocked_tower_kinds()
	for index in range(Rules.BUILD_SITES.size()):
		if game.towers.size() >= game.tower_limit(): break
		var point: Vector2 = Rules.BUILD_SITES[index]
		if game.nearest_tower(point, 15) != null: continue
		var kind := "bolt"
		if index >= 2 and "cannon" in kinds: kind = "cannon"
		if kind not in kinds: kind = "bolt"
		if game.gold < Rules.TOWERS[kind].cost: continue
		game.choose_build(kind)
		game.try_build(point)
	for tower in game.towers:
		if tower.level < Tower.MAX_LEVEL and game.gold >= tower.upgrade_price() + 40:
			game.selected = tower
			game.upgrade_selected()
	game.selected = null

func _set_motion(direction: Vector2) -> void:
	for action in ["left", "right", "up", "down"]: Input.action_release(action)
	if direction.length() < 15: return
	if absf(direction.x) > 8: Input.action_press("right" if direction.x > 0 else "left")
	if absf(direction.y) > 8: Input.action_press("down" if direction.y > 0 else "up")
