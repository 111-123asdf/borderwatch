extends SceneTree

# Design contract: towers alone must lose, hero alone must lose.
# --mode=tower : no exploration, hero never attacks, only build/upgrade available towers
# --mode=hero  : no towers, hero defends the core

var game: Node2D
var mode := "tower"
var build_clock := 0.0
var report := {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="): mode = argument.trim_prefix("--mode=")
	seed(20261019)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.sound.enabled = false
	game.hero.position = Rules.CORE + (Vector2(600, 0) if mode == "tower" else Vector2(120, 112))
	if mode == "minimal": _setup_minimal()
	var iterations := 0
	while iterations < 60000 and game.elapsed < 600:
		iterations += 1
		if game.hud.modal_kind == "result": break
		if game.hud.modal_kind == "reward": _choose_relic()
		if game.hud.modal_kind == "confirm":
			game.hud.close_modal()
			game.start_wave()
		await physics_frame
		if not game.running: continue
		if not game.wave_active and game.wave < Rules.WAVES: game.early_wave()
		if mode == "tower": _tower_play()
		elif mode == "no_explore": _mixed_play()
		elif mode == "minimal": _minimal_play()
		else: _hero_play()
	report.merge({
		"mode": mode, "elapsed": game.elapsed, "wave": game.wave, "core": game.core_health,
		"boss": game.boss_defeated, "result": game.hud.modal_kind, "towers": game.towers.size(),
		"gold": game.gold, "hero_kills": game.stats.hero_kills, "tower_kills": game.stats.tower_kills,
		"level": game.level, "camps": game.claimed_count(),
	})
	print(JSON.stringify(report))
	var held: bool = game.hud.modal_kind == "result" and not game.boss_defeated
	game.queue_free()
	await process_frame
	quit(0 if held else 1)

func _setup_minimal() -> void:
	game.camps[0].cleared = true
	game.camps[0].chest_claimed = true
	game.camps[0].progress = 1
	game.gold = 600
	game.choose_build("bolt")
	game.try_build(Rules.BUILD_SITES[0])
	game.choose_build("cannon")
	game.try_build(Rules.BUILD_SITES[1])

func _minimal_play() -> void:
	if game.hero.respawn_time > 0: return
	var enemy: Enemy = game.nearest_enemy(Rules.CORE, 760)
	if enemy != null:
		var desired: Vector2 = enemy.position + Vector2(110, 70)
		desired = desired.clamp(Rules.CORE - Vector2(520, 380), Rules.CORE + Vector2(520, 380))
		if game.hero.position.distance_to(desired) > 40: game.hero.command_move(desired)
		game.hero.fire()
		if game.hero.class_id == "knight" and game.hero.position.distance_to(enemy.position) < 360:
			game.hero.use_skill()
	for hazard in game.hazards:
		if game.hero.center().distance_to(hazard.point) < hazard.radius + 40:
			var away: Vector2 = (game.hero.center() - hazard.point).normalized()
			game.hero.command_move(game.hero.position + away * 170)
			break

func _choose_relic() -> void:
	for key in ["swarm", "command", "hold"]:
		var index: int = game.offered.find(key)
		if index >= 0:
			game.hud.reward_buttons[index].pressed.emit()
			return
	game.hud.reward_buttons[0].pressed.emit()

func _tower_play() -> void:
	if game.hero.respawn_time > 0: return
	var point := Rules.CORE + Vector2(600, 0)
	for hazard in game.hazards:
		if game.hero.position.distance_to(hazard.point) < hazard.radius + 35:
			point = game.hero.position + (game.hero.position - hazard.point).normalized() * 150
	if game.hero.position.distance_to(point) > 30: game.hero.command_move(point)
	build_clock -= 1.0 / 60.0
	if build_clock <= 0 and game.can_manage():
		_build_all()
		build_clock = 1.0

func _hero_play() -> void:
	if game.hero.respawn_time > 0: return
	var enemy: Enemy = game.nearest_enemy(Rules.CORE, 520)
	if enemy != null:
		var desired: Vector2 = enemy.position + Vector2(90, 0)
		desired.x = maxf(desired.x, Rules.CORE.x + 40)
		game.hero.command_move(desired)
		game.hero.fire()
	for hazard in game.hazards:
		if game.hero.center().distance_to(hazard.point) < hazard.radius + 40:
			var away: Vector2 = (game.hero.center() - Rules.CORE).normalized()
			game.hero.command_move(game.hero.position + away * 160)
			break

func _mixed_play() -> void:
	if game.hero.respawn_time > 0: return
	var enemy: Enemy = game.nearest_enemy(Rules.CORE, 760)
	if enemy != null:
		var desired: Vector2 = enemy.position + Vector2(110, 70)
		desired = desired.clamp(Rules.CORE - Vector2(520, 380), Rules.CORE + Vector2(520, 380))
		if game.hero.position.distance_to(desired) > 40: game.hero.command_move(desired)
		game.hero.fire()
		if game.hero.class_id == "knight" and game.hero.position.distance_to(enemy.position) < 360:
			game.hero.use_skill()
	for hazard in game.hazards:
		if game.hero.center().distance_to(hazard.point) < hazard.radius + 40:
			var away: Vector2 = (game.hero.center() - hazard.point).normalized()
			game.hero.command_move(game.hero.position + away * 170)
			break
	build_clock -= 1.0 / 60.0
	if build_clock <= 0:
		_build_all()
		build_clock = 1.0

func _build_all() -> void:
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