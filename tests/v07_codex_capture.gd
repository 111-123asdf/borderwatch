extends SceneTree
# 临时截图脚本：从主菜单打开被动星图、点卡看详情、关闭，验证菜单入口与渲染。
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
	root.get_texture().get_image().save_png("user://codex-%s.png" % name)

func run() -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await frames()
	var menu_button := game.hud.root.find_child("被动图鉴", true, false) as Button
	if menu_button == null:
		push_error("codex menu button missing")
		quit(1)
		return
	await click(menu_button.get_global_rect().get_center())
	if not is_instance_valid(game.hud.codex):
		push_error("codex did not open")
		quit(1)
		return
	await snap("overview")
	var card := ArenaPerkNetwork.card("power")
	var pos := Vector2(14, 52) + Vector2(float(card.x), float(card.y)) * 0.74
	await click(pos)
	await snap("card")
	var close_button := game.hud.root.find_child("关闭图鉴", true, false) as Button
	if close_button == null:
		push_error("codex close button missing")
		quit(1)
		return
	await click(close_button.get_global_rect().get_center())
	await frames()
	if game.hud.codex != null:
		push_error("codex did not close")
		quit(1)
		return
	await snap("closed")
	game.audio.shutdown()
	quit(0)
