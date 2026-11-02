extends SceneTree

# Headless playtest probe for the arena prototype. It drives the hero through
# the real input actions and places towers through the real placement API.
# Usage:
#   godot --headless --path . --fixed-fps 60 --script res://tests/arena_probe.gd -- --policy=hero

var game: Node2D
var policy := "hero"
var hero_key := "knight"
var elapsed := 0.0
var frames := 0
var rejected := 0

func _initialize() -> void:
	call_deferred("_run")

func _parse_policy() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--policy="):
			return argument.split("=", true, 1)[1]
	return "hero"

func _parse_hero() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hero="):
			return argument.split("=", true, 1)[1]
	return "knight"

func _run() -> void:
	policy = _parse_policy()
	hero_key = _parse_hero()
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero(hero_key)
	game.sim_speed = 4.0
	_setup_towers()
	var dt := 1.0 / 60.0
	while not game.game_over and elapsed < 360.0:
		_drive()
		await process_frame
		elapsed += dt
		frames += 1
		if frames % 600 == 0:
			print("STATE " + JSON.stringify({
				"t": snappedf(elapsed, 1), "cycle": game.cycle, "phase": game.phase,
				"core": snappedf(game.core_health, 1), "enemies": game.enemies.size(),
				"budget": game.spawn_budget, "kills": game.stats.kills,
				"hero": game.hero.position.round(), "towers": game.towers.size(),
			}))
	_print_result()
	game.queue_free()
	await process_frame
	quit(0)

func _setup_towers() -> void:
	if policy == "idle" or policy == "hero" or policy == "natural":
		return
	game.gold = 9999
	var cells: Array[Vector2i] = []
	if policy == "tower1":
		cells = [Vector2i(23, 20)]
	elif policy == "tower2":
		cells = [Vector2i(23, 20), Vector2i(17, 20)]
	elif policy == "tower4" or policy == "tower_only":
		cells = [Vector2i(23, 20), Vector2i(17, 20), Vector2i(20, 23), Vector2i(20, 17)]
	elif policy == "tower5":
		cells = [Vector2i(23, 20), Vector2i(17, 20), Vector2i(20, 23), Vector2i(20, 17), Vector2i(24, 23)]
	elif policy == "tower6":
		cells = [
			Vector2i(23, 20), Vector2i(17, 20), Vector2i(20, 23),
			Vector2i(20, 17), Vector2i(24, 23), Vector2i(16, 17),
		]
	elif policy == "tower8":
		cells = [
			Vector2i(24, 20), Vector2i(23, 23), Vector2i(20, 24), Vector2i(17, 23),
			Vector2i(16, 20), Vector2i(17, 17), Vector2i(20, 16), Vector2i(23, 17),
		]
	elif policy == "tower10":
		cells = [
			Vector2i(24, 20), Vector2i(23, 23), Vector2i(20, 24), Vector2i(17, 23),
			Vector2i(16, 20), Vector2i(17, 17), Vector2i(20, 16), Vector2i(23, 17),
			Vector2i(26, 20), Vector2i(14, 20),
		]
	elif policy == "wall":
		cells = [
			Vector2i(24, 20), Vector2i(23, 22), Vector2i(22, 23), Vector2i(20, 24),
			Vector2i(18, 23), Vector2i(17, 22), Vector2i(16, 20), Vector2i(17, 18),
			Vector2i(18, 17), Vector2i(20, 16), Vector2i(22, 17), Vector2i(23, 18),
		]
	var kinds := ["bolt", "cannon", "frost", "bolt", "cannon", "frost", "bolt", "cannon"]
	for index in range(cells.size()):
		game.build_kind = kinds[index % kinds.size()]
		if not game.place_tower(cells[index]): rejected += 1
	if policy == "tower10":
		for tower in game.towers:
			tower.upgrade()
			tower.upgrade()

func _release_movement() -> void:
	for action in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(action)

func _press_direction(direction: Vector2) -> void:
	_release_movement()
	if direction.x > 0.15: Input.action_press("move_right", minf(1.0, direction.x))
	if direction.x < -0.15: Input.action_press("move_left", minf(1.0, -direction.x))
	if direction.y > 0.15: Input.action_press("move_down", minf(1.0, direction.y))
	if direction.y < -0.15: Input.action_press("move_up", minf(1.0, -direction.y))

func _drive() -> void:
	if game.passive_selecting:
		game.choose_passive(game.passive_choices[0])
	if game.relic_choice_pending:
		var choices := {"defense": "lone", "lead": "vanguard", "tempo": "hold"}
		game.choose_relic(choices.get(game.pending_relic_group, "lone"))
	if policy == "natural":
		_try_natural_build()
	if policy == "idle" or policy == "tower_only":
		Input.action_release("shoot")
		_release_movement()
		return
	var hero = game.hero
	if hero == null or game.game_over: return
	var target: ArenaEnemy = game.nearest_enemy(hero.position, 800.0)
	if target != null:
		var distance: float = hero.position.distance_to(target.position)
		var direction := Vector2.ZERO
		if distance > 260.0:
			direction = (target.position - hero.position).normalized()
		elif distance < 150.0:
			direction = (hero.position - target.position).normalized()
		_press_direction(direction)
		Input.action_press("shoot")
		if distance < 135.0 and hero.skill_cooldown <= 0.0:
			hero.use_skill(direction)
	else:
		Input.action_release("shoot")
		var drop := _nearest_drop()
		if drop != null:
			_press_direction((drop.position - hero.position).normalized())
		elif hero.position.distance_to(game.CORE) > 240.0:
			_press_direction((game.CORE - hero.position).normalized())
		else:
			_release_movement()

func _try_natural_build() -> void:
	if game.phase != "rest": return
	if game.gold >= 30 and game.nearest_damaged_tower(game.hero.position, 150.0) != null:
		game.repair_nearest()
	var sequence: Array[Vector2i] = [
		Vector2i(23, 20), Vector2i(17, 20), Vector2i(20, 23), Vector2i(20, 17),
		Vector2i(24, 23), Vector2i(16, 17), Vector2i(23, 24), Vector2i(17, 16),
	]
	if game.towers.size() >= sequence.size(): return
	game.build_kind = "bolt" if game.towers.size() % 2 == 0 else "cannon"
	game.place_tower(sequence[game.towers.size()])

func _nearest_drop() -> ArenaDrop:
	var best: ArenaDrop
	var best_distance := 100000.0
	for drop in game.drops:
		if not is_instance_valid(drop): continue
		var distance: float = game.hero.position.distance_to(drop.position)
		if distance < best_distance:
			best_distance = distance
			best = drop
	return best

func _print_result() -> void:
	var result := {
		"policy": policy,
		"hero": hero_key,
		"weapon": game.hero.weapon_key,
		"camps": game.camps_cleared,
		"relics": game.relics,
		"result": "victory" if game.victory else ("defeat" if game.game_over else "timeout"),
		"cycle": game.cycle,
		"phase": game.phase,
		"core": snappedf(game.core_health, 0.1),
		"elapsed": snappedf(elapsed, 0.1),
		"kills": game.stats.kills,
		"level": game.hero.level,
		"towers": game.towers.size(),
		"spawns": game.debug.spawns,
		"damage_hero": snappedf(float(game.damage_stats.hero), 1.0),
		"damage_tower": snappedf(float(game.damage_stats.tower), 1.0),
		"hero_kills": game.stats.hero_kills,
		"tower_kills": game.stats.tower_kills,
		"leaks": game.debug.leaks,
		"leak_damage": snappedf(game.debug.leak_damage, 0.1),
		"drops_spawned": game.debug.drops_spawned,
		"drops_collected": game.debug.drops_collected,
		"drops_expired": game.debug.drops_expired,
		"towers_lost": game.debug.towers_lost,
		"build_rejected": game.debug.build_rejected + rejected,
		"regions": game.debug.regions,
		"spawn_patterns": game.debug.spawn_patterns,
		"hero_health": snappedf(game.hero.health, 0.1),
	}
	print("PROBE " + JSON.stringify(result))
