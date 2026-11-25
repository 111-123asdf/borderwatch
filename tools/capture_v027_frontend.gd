extends SceneTree

var out_dir := ""


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.trim_prefix("--out=")
	if out_dir.is_empty():
		out_dir = ProjectSettings.globalize_path("res://test-results/v027_media")
	DirAccess.make_dir_recursive_absolute(out_dir)
	call_deferred("run")


func _pump(frames: int) -> void:
	for _i in range(frames):
		await process_frame


func _save_shot(filename: String) -> void:
	await _pump(3)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png(out_dir.path_join(filename))
	print("SAVED ", filename)


func run() -> void:
	var game := load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	game.campaign.data.gems = 42
	game.campaign.data.cleared["forest"] = true
	game.campaign.data.levels["werewolf"] = 4
	game.campaign.data.levels["lord"] = 2
	game.campaign.select_hero("werewolf")
	root.add_child(game)
	current_scene = game
	await _pump(6)

	# 1. Title screen
	await _save_shot("01_title.png")

	# 2. World map (with forest cleared & rest open)
	game.hud.frontend.levels()
	await _save_shot("02_world_map.png")

	# 3. Stage preview modal (creek)
	game.hud.frontend.prepare("creek")
	await _save_shot("03_stage_preview.png")

	# 4. Hero hall (Wolf King LV.4 showcase + Lord LV.2 showing E skill lock badge)
	game.hud.frontend.close_stage()
	game.hud.frontend.hall()
	game.hud.frontend.select_hall("werewolf")
	await _save_shot("04_hero_hall.png")
	game.hud.frontend.select_hall("lord")
	await _save_shot("04b_hero_lord_lock.png")

	# 5. Tower workshop (Lens Tier 3 Focus with 4-slot equipped ring)
	game.hud.frontend.towers()
	game.hud.frontend.select_tower("lens")
	game.hud.frontend.select_tier(3)
	await _pump(8)
	await _save_shot("05_tower_workshop.png")

	# 6. Settings modal over frontend
	game.hud.frontend.settings()
	await _save_shot("06_settings_modal.png")

	game.running = false
	game.audio.shutdown()
	await _pump(2)
	OS.delay_msec(120)
	game.queue_free()
	await _pump(2)
	print("ALL V027 FRONTEND SHOTS COMPLETE")
	quit(0)
