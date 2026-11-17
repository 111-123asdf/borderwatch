extends SceneTree

# Deterministic Stage 3 Sample Slice capture for v019 before/after frame inspection.
# Captures Knight + Archer T1/T3 + Cannon T1/T3 + Light/Heavy/Floating enemies across sparse & dense waves.

var game: ArenaGame
var elapsed: float = 0.0
var phase_b_spawned: bool = false
var stopping: bool = false
var focus_center: Vector2 = Vector2(740.0, 540.0)

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	var campaign := ArenaCampaign.new("", false)
	campaign.data.levels["knight"] = 5
	game.campaign = campaign
	root.add_child(game)
	current_scene = game
	await process_frame
	game.rng.seed = 2026019
	game.start_run("knight", "ruins")
	await process_frame
	game.gold = 2600
	game.doctrine_tokens = 2
	game.phase = "wave"

	var unlocked: Array[int] = []
	for i in range(game.level_definition.sites.size()):
		if not game.site_locked(i):
			unlocked.append(i)
	unlocked.sort_custom(func(a: int, b: int) -> bool:
		var pa: Vector2 = game.level_definition.sites[a]
		var pb: Vector2 = game.level_definition.sites[b]
		return pa.distance_to(focus_center) < pb.distance_to(focus_center)
	)

	if unlocked.size() >= 4:
		var s0: int = unlocked[0]
		var s1: int = unlocked[1]
		var s2: int = unlocked[2]
		var s3: int = unlocked[3]
		game.build_tower(s0, "archer")
		game.build_tower(s1, "cannon")
		game.build_tower(s2, "archer")
		game.build_tower(s3, "cannon")
		for t in game.towers:
			if t.site_id == s2 or t.site_id == s3:
				t.upgrade("", true)
				t.upgrade("", true)
				if t.awaiting_doctrine:
					var opts: Array = ArenaDoctrines.for_tower(t.kind)
					if not opts.is_empty():
						t.choose_doctrine(str(opts[0].id))

	# Frame the central-west corridor (sites + roads 0/1) with room for visible open plinth.
	if game.camera != null:
		if game.camera.overview:
			game.camera.toggle_overview()
		game.camera.focus(focus_center)

	# Position Knight near road junction in central-west.
	game.hero.position = Vector2(780.0, 520.0)
	game.hero.command_move(Vector2(760.0, 500.0))

	# Phase A (Sparse): one Light, one Heavy, one Floating along route 0.
	var e1 := game.spawn_enemy("construct_hound", 0, 120.0, false)
	if e1 != null:
		e1.progress = 520.0
	var e2 := game.spawn_enemy("rune_warden", 0, 80.0, false)
	if e2 != null:
		e2.progress = 420.0
	var e3 := game.spawn_enemy("astral_prism", 0, 40.0, false)
	if e3 != null:
		e3.progress = 340.0

func _process(delta: float) -> bool:
	if stopping or game == null or not game.started:
		return false
	elapsed += delta

	# Keep camera locked cleanly on central-west corridor.
	if game.camera != null:
		game.camera.focus(focus_center)

	# Keep hero engaged on active enemy near central-west without stalling.
	var target: ArenaEnemy = game.nearest_enemy(focus_center, 460.0, false)
	if target != null:
		if game.hero.position.distance_to(target.position) > 54.0:
			game.hero.command_move(target.position + Vector2(-28.0, 6.0))
		else:
			game.hero.facing = (target.position - game.hero.position).normalized()
			Input.action_press("shoot")
		if elapsed > 8.5 and game.hero.cooldowns[0] <= 0.0:
			game.hero.cast(0, target.position)
		if elapsed > 10.5 and game.hero.cooldowns[1] <= 0.0:
			game.hero.cast(1, target.position)
	else:
		Input.action_release("shoot")

	# Phase B (Dense): mixed pack on routes 0 & 1 starting at t = 7.0s.
	if not phase_b_spawned and elapsed >= 7.0:
		phase_b_spawned = true
		for i in range(6):
			var h := game.spawn_enemy("construct_hound", 0, float(i) * 32.0, i == 5)
			if h != null:
				h.progress = 480.0 - float(i) * 24.0
		for i in range(3):
			var w := game.spawn_enemy("rune_warden", 0, float(i) * 44.0, i == 2)
			if w != null:
				w.progress = 380.0 - float(i) * 34.0
		for i in range(3):
			var p := game.spawn_enemy("astral_prism", 1, float(i) * 40.0, false)
			if p != null:
				p.progress = 520.0 - float(i) * 30.0
		for i in range(2):
			var b := game.spawn_enemy("rift_bomber", 1, float(i) * 55.0, false)
			if b != null:
				b.progress = 430.0 - float(i) * 42.0

	if elapsed >= 16.5:
		stopping = true
		Input.action_release("shoot")
		print("V019 SAMPLE CAPTURE DONE elapsed=", snappedf(elapsed, 0.01), " towers=", game.towers.size())
		call_deferred("_quit_clean")
	return false

func _quit_clean() -> void:
	game.running = false
	if game.audio != null:
		game.audio.shutdown()
	await process_frame
	game.queue_free()
	await process_frame
	quit(0)
