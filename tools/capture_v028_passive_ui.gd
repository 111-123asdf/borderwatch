extends SceneTree

var game: ArenaGame
var out_dir := "C:/Users/黄子衿/.gemini/antigravity/brain/576a2758-9e88-4f27-8e7a-860481c4c0c1/v028_media"


func _initialize() -> void:
	call_deferred("run")


func frames(count := 3) -> void:
	for _i in range(count):
		await process_frame


func press(node_name: String) -> void:
	var btn := game.hud.root.find_child(node_name, true, false) as Button
	if btn == null:
		push_error("CAPTURE MISSING BUTTON: " + node_name)
		return
	var point := btn.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var ev := InputEventMouseButton.new()
	ev.position = point
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	root.push_input(ev, true)
	ev = ev.duplicate()
	ev.pressed = false
	root.push_input(ev, true)
	await frames(4)


func snap(filename: String) -> void:
	await create_timer(0.28).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(out_dir)
	var path := out_dir + "/" + filename
	var err := root.get_texture().get_image().save_png(path)
	print("CAPTURED ", path, " err=", err)


func cleanup() -> void:
	paused = false
	if is_instance_valid(game):
		game.running = false
		game.audio.shutdown()
		await frames(2)
		OS.delay_msec(120)
		game.queue_free()
		await frames(2)
	game = null


func run() -> void:
	create_timer(90.0).timeout.connect(func():
		push_error("V028 CAPTURE TIMEOUT")
		quit(1)
	)
	DirAccess.make_dir_recursive_absolute(out_dir)

	# 1 & 2. Forest Wave 1 unified 3-card selection + optional detail popover
	game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	game.campaign.data.levels["lord"] = 5
	game.campaign.equip_towers(["archer", "storm", "lens", "barracks"])
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.rng.seed = 3
	game.start_run("lord", "forest")
	await frames(4)
	await snap("01_rule_choice.png")

	var mid_id := str(game.rule_offers[1].id)
	await press("RuleDetail_" + mid_id)
	await snap("02_rule_detail_open.png")

	# 3. Battle view with 3 equipped rule medallions (bottom-right + popover) & Battle Orders open (bottom-left)
	await press("DefenseRule_relay")
	game.set_physics_process(false)
	game.gold = 1200
	game.build_tower(0, "archer")
	game.site_tower(0).finish_project()
	game.build_tower(2, "storm")
	game.site_tower(2).finish_project()
	game.rule_offers.assign([ArenaRuleDeck.card("wall", "open_gate")])
	game.choose_defense_rule("wall")
	game.rule_offers.assign([ArenaRuleDeck.card("bounty", "stake")])
	game.choose_defense_rule("bounty")
	game.hud.update_clock = 0.0
	game.hud._process(0.1)
	await frames(3)
	await press("BattleOrders")
	await press("OwnedRule_relay")
	await snap("03_battle_orders_and_badges.png")

	# 4. Obsidian Pause handbook
	if game.hud.orders_panel.visible:
		await press("BattleOrders")
	game.hud.show_pause()
	await frames(4)
	await snap("04_pause_obsidian.png")
	game.hud.resume()
	await frames(2)

	# 6. Obsidian Result screen
	game.cycle = 8
	game.kills = 64
	game.finish(true)
	await frames(4)
	await snap("06_result_obsidian.png")
	await cleanup()

	# 5. Ruins (Stage 3) Wave 1 unified tactical selection (no keystones/altars)
	game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	game.campaign.data.levels["werewolf"] = 5
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.rng.seed = 7
	game.start_run("werewolf", "ruins")
	await frames(4)
	await snap("05_ruins_unified.png")
	await cleanup()

	print("V028 CAPTURE COMPLETE")
	quit(0)
