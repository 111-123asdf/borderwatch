extends SceneTree

# Focused presentation checks. Enemies are deliberately placed for the fixture;
# this is not a playthrough or a balance test.
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error("VISUAL FAIL: " + message)

func frame_has_pixels(visual: ActorVisual) -> bool:
	var sprite := visual.sprite
	var image := sprite.texture.get_image()
	var width := image.get_width() / sprite.hframes
	var height := image.get_height() / sprite.vframes
	var rect := Rect2i((sprite.frame % sprite.hframes) * width, (sprite.frame / sprite.hframes) * height, width, height)
	return image.get_region(rect).get_used_rect().has_area()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	var barrel := ActorVisual.new()
	game.add_child(barrel)
	barrel.setup("barrel", "Red")
	for index in range(20):
		barrel.advance(0.08, Vector2.ZERO, Vector2.RIGHT)
		check(frame_has_pixels(barrel), "barrel idle frame %d is visible" % index)
	var brute := ActorVisual.new()
	game.add_child(brute)
	brute.setup("barrel", "Blue", 1.08)
	brute.use_enemy_preview("brute")
	var brute_frames := {}
	for index in range(48):
		brute.advance(0.04, Vector2(100, 0), Vector2.RIGHT)
		brute_frames[brute.sprite.frame] = true
		check(frame_has_pixels(brute), "bark brute walk frame contains pixels")
	check(brute_frames.size() == 6, "bark brute walk visits all six frames")
	brute.attack(Vector2.RIGHT, 0.6)
	var brute_attack_frames := {}
	for index in range(3):
		brute.advance(0.15, Vector2.ZERO, Vector2.RIGHT)
		brute_attack_frames[brute.sprite.frame] = true
		check(frame_has_pixels(brute), "bark brute attack frame contains pixels")
	check(brute.sprite.texture.resource_path.ends_with("enemy_bark_brute_attack_3.png") and brute_attack_frames.size() == 3, "bark brute uses all three attack poses")
	brute.queue_free()
	var fox := ActorVisual.new()
	game.add_child(fox)
	fox.setup("torch", "Red", 0.7)
	fox.use_enemy_preview("hound")
	var fox_walk_frames := {}
	for index in range(48):
		fox.advance(0.04, Vector2(100, 0), Vector2.RIGHT)
		fox_walk_frames[fox.sprite.frame] = true
		check(frame_has_pixels(fox), "cinder fox walk frame contains pixels")
	check(fox_walk_frames.size() == 4, "cinder fox walk visits all four frames")
	fox.attack(Vector2.LEFT, 0.6)
	fox.advance(0.1, Vector2.ZERO, Vector2.LEFT)
	check(fox.sprite.texture.resource_path.ends_with("enemy_cinder_fox_attack.png") and fox.sprite.frame == 2 and fox.sprite.flip_h, "fox uses first clean attack pose and faces left")
	fox.advance(0.3, Vector2.ZERO, Vector2.LEFT)
	check(fox.sprite.frame == 3 and frame_has_pixels(fox), "fox uses second clean attack pose")
	fox.advance(0.3, Vector2.ZERO, Vector2.LEFT)
	fox.advance(0.01, Vector2.ZERO, Vector2.LEFT)
	check(fox.sprite.texture.resource_path.ends_with("enemy_cinder_fox_walk.png"), "fox returns to its walk sheet after attacking")
	fox.queue_free()
	var wisp := ActorVisual.new()
	game.add_child(wisp)
	wisp.setup("archer", "Purple", 0.84)
	wisp.use_enemy_preview("shaman")
	var wisp_frames := {}
	for index in range(24):
		wisp.advance(0.08, Vector2.ZERO, Vector2.RIGHT)
		wisp_frames[wisp.sprite.frame] = true
		check(frame_has_pixels(wisp), "forest wisp float frame contains pixels")
	check(wisp_frames.size() == 4, "forest wisp idles through all four float frames")
	wisp.attack(Vector2.LEFT, 0.5)
	wisp.advance(0.1, Vector2.ZERO, Vector2.LEFT)
	check(wisp.sprite.texture.resource_path.ends_with("enemy_forest_wisp_walk.png") and wisp.sprite.flip_h, "forest wisp safely retains its float sheet during action")
	wisp.queue_free()
	var moth := ActorVisual.new()
	game.add_child(moth)
	moth.setup("barrel", "Red", 1.25)
	moth.use_enemy_preview("boss")
	var moth_frames := {}
	for index in range(24):
		moth.advance(0.08, Vector2.ZERO, Vector2.RIGHT)
		moth_frames[moth.sprite.frame] = true
		check(frame_has_pixels(moth), "boss idle flight frame contains pixels")
	check(moth_frames.size() == 4, "boss flaps all four frames while stationary")
	moth.hit_flash = 0.1
	moth.advance(0.01, Vector2.RIGHT * 36, Vector2.RIGHT)
	check(moth.hit_flash > 0.0 and moth.sprite.modulate.r > 1.0, "boss sprite flashes on hit")
	moth.queue_free()
	var visual: ActorVisual = game.hero.visual
	var frames := {}
	for index in range(48):
		visual.advance(0.04, Vector2(250, 0), Vector2.RIGHT)
		frames[visual.sprite.frame] = true
		check(frame_has_pixels(visual), "hero walking frame contains pixels")
	check(frames.size() == 6, "hero walk uses all six existing poses")
	check(visual.sprite.texture.resource_path.ends_with("knight_walk_side.png") and not visual.sprite.flip_h, "knight walks right in side view")
	visual.advance(0.04, Vector2.LEFT * 250, Vector2.RIGHT)
	check(visual.sprite.texture.resource_path.ends_with("knight_walk_side.png") and visual.sprite.flip_h, "knight walks left in mirrored side view")
	visual.advance(0.04, Vector2.DOWN * 250, Vector2.RIGHT)
	check(visual.sprite.texture.resource_path.ends_with("knight_walk_preview.png") and not visual.sprite.flip_h, "knight walks down in front view")
	visual.advance(0.04, Vector2.UP * 250, Vector2.RIGHT)
	check(visual.sprite.texture.resource_path.ends_with("knight_walk_back_v2.png") and not visual.sprite.flip_h, "knight walks up in back view")
	var knight_back_frames := {}
	for index in range(48):
		visual.advance(0.04, Vector2.UP * 250, Vector2.UP)
		knight_back_frames[visual.sprite.frame] = true
		check(frame_has_pixels(visual), "knight back frame contains pixels")
	check(knight_back_frames.size() == 6, "knight back view visits all six walk frames")
	var ranger := ActorVisual.new()
	game.add_child(ranger)
	ranger.setup("player", "Yellow")
	ranger.use_ranger_preview()
	var ranger_frames := {}
	for index in range(48):
		ranger.advance(0.04, Vector2(250, 0), Vector2.RIGHT)
		ranger_frames[ranger.sprite.frame] = true
		check(frame_has_pixels(ranger), "new ranger walk frame contains pixels")
	check(ranger_frames.size() == 6, "new ranger walk visits all six frames")
	ranger.advance(0.04, Vector2.UP * 250, Vector2.RIGHT)
	check(ranger.sprite.texture.resource_path.ends_with("ranger_walk_back.png"), "ranger uses back view when walking up")
	ranger.advance(0.04, Vector2.DOWN * 250, Vector2.RIGHT)
	check(ranger.sprite.texture.resource_path.ends_with("ranger_walk_preview.png"), "ranger uses front view when walking down")
	ranger.advance(0.04, Vector2.LEFT * 250, Vector2.RIGHT)
	check(ranger.sprite.texture.resource_path.ends_with("ranger_walk_side.png") and ranger.sprite.flip_h, "ranger mirrors side view when walking left")
	ranger.advance(0.04, Vector2.RIGHT * 250, Vector2.LEFT)
	check(ranger.sprite.texture.resource_path.ends_with("ranger_walk_side.png") and not ranger.sprite.flip_h, "ranger uses side view when walking right")
	ranger.queue_free()
	var mage := ActorVisual.new()
	game.add_child(mage)
	mage.setup("player", "Purple")
	mage.use_hero_preview("mage")
	var mage_frames := {}
	for index in range(48):
		mage.advance(0.04, Vector2(250, 0), Vector2.RIGHT)
		mage_frames[mage.sprite.frame] = true
		check(frame_has_pixels(mage), "new mage walk frame contains pixels")
	check(mage_frames.size() == 6, "new mage walk visits all six frames")
	check(mage.sprite.texture.resource_path.ends_with("mage_walk_side.png") and not mage.sprite.flip_h, "mage walks right in side view")
	mage.advance(0.04, Vector2.LEFT * 250, Vector2.RIGHT)
	check(mage.sprite.texture.resource_path.ends_with("mage_walk_side.png") and mage.sprite.flip_h, "mage walks left in mirrored side view")
	mage.advance(0.04, Vector2.DOWN * 250, Vector2.RIGHT)
	check(mage.sprite.texture.resource_path.ends_with("mage_walk_preview.png") and not mage.sprite.flip_h, "mage walks down in front view")
	mage.advance(0.04, Vector2.UP * 250, Vector2.RIGHT)
	check(mage.sprite.texture.resource_path.ends_with("mage_walk_back_v2.png") and not mage.sprite.flip_h, "mage walks up in back view")
	var mage_back_frames := {}
	for index in range(48):
		mage.advance(0.04, Vector2.UP * 250, Vector2.UP)
		mage_back_frames[mage.sprite.frame] = true
		check(frame_has_pixels(mage), "mage back frame contains pixels")
	check(mage_back_frames.size() == 6, "mage back view visits all six walk frames")
	mage.queue_free()
	game.hero.take_damage(1.0)
	check(visual.hit_flash > 0.0, "hero receives a visible hit flash")
	var shooter: ArenaEnemy = game.spawn_enemy("shooter", game.hero.position + Vector2(250, 0), 1000.0)
	shooter.speed = 0.0
	await create_timer(0.12).timeout
	check(shooter.visual.action_phase > 0.0, "shooter begins its existing attack animation")
	# Torch's Aseprite source labels six Run frames and three six-frame
	# directional Attack sequences. Exercise the live collision trigger as well.
	game.hitstop = 0.0
	game.hero.position = game.CORE + Vector2(420, 180)
	var torch: ArenaEnemy = game.spawn_enemy("torch", game.hero.position + Vector2(26, 0), 1000.0)
	torch.speed = 0.0
	await create_timer(0.10).timeout
	check(torch.visual.action_phase > 0.0, "torch contact triggers its attack sequence")
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.UP]:
		var attack_frames := {}
		torch.visual.attack(direction, 0.6)
		for index in range(6):
			torch.visual.advance(0.09, Vector2.ZERO, direction)
			attack_frames[torch.visual.sprite.frame] = true
			check(frame_has_pixels(torch.visual), "torch attack frame %d contains pixels" % index)
		check(attack_frames.size() == 6, "torch directional attack traverses six source frames")
	barrel.queue_free()
	game.queue_free()
	await process_frame
	await create_timer(1.0, true, false, true).timeout
	print("ARENA VISUAL CHECKS: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
