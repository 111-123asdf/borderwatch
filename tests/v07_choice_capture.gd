extends SceneTree
# 临时截图脚本：验证三选一卡面与选卡流程。
var game: ArenaGame

func _initialize() -> void:
	call_deferred("run")

func frames() -> void:
	await process_frame
	await process_frame

func click(point: Vector2) -> void:
	root.warp_mouse(point)
	await frames()
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	await frames()
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await frames()

func snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://choice-%s.png" % name)

func run() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	game.progression = ArenaProgression.new("", false)
	game.start_run("knight", "forest")
	await frames()
	var keys: Array[String] = ["power", "rapid", "tough"]
	game.choices = keys
	game.choice_queue = 1
	game.choice_open = true
	game.hud.show_choices(keys)
	await frames()
	await snap("modal")
	var button := game.hud.root.find_child("Perk_power", true, false) as Button
	if button == null:
		push_error("perk card button missing")
		quit(1)
		return
	await click(button.get_global_rect().get_center())
	if game.hero.perk("power") != 1:
		push_error("perk was not applied")
		quit(1)
		return
	await snap("chosen")
	game.running = false
	game.audio.shutdown()
	await frames()
	OS.delay_msec(120)
	game.queue_free()
	await frames()
	quit(0)
