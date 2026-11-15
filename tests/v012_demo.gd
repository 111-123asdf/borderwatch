extends SceneTree
# Same runtime, A/B presets, explicit rank-5/enemy-layout fixture. Not playthrough.
var game: ArenaGame
var lab: ArenaFeelLab
var caption: Label
var identity:="knight"
func _initialize() -> void:call_deferred("run")
func wait(seconds: float) -> void:await create_timer(seconds).timeout
func run() -> void:
	create_timer(70).timeout.connect(func():push_error("HERO MOVIE TIMEOUT");quit(1))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-hero="):identity=arg.trim_prefix("--demo-hero=")
	if identity not in ArenaDefinitions.HERO_IDS:identity="knight"
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);game.campaign.data.levels[identity]=5
	root.add_child(game);current_scene=game;await process_frame;game.start_run(identity,"forest");game.feel_lab=true;game.phase="lab"
	lab=ArenaFeelLab.new();game.add_child(lab);lab.open(game);lab.panel.hide()
	caption=Label.new();caption.position=Vector2(35,790);caption.size=Vector2(1500,70);caption.add_theme_font_size_override("font_size",28);caption.add_theme_color_override("font_shadow_color",Color.BLACK);caption.add_theme_constant_override("shadow_offset_x",2);caption.add_theme_constant_override("shadow_offset_y",2);game.hud.root.add_child(caption)
	await take(true);await take(false)
	Input.action_release("shoot");game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame;quit()
func take(old: bool) -> void:
	Input.action_release("shoot");seed(12012);game.rng.seed=12012
	lab.baseline.set_pressed_no_signal(old);lab.apply();lab.reset_targets()
	caption.text=("原版动作/音效预设 · 原尺寸" if old else game.hero.data.name+" · 视觉 ×1.3 · 新动作与音效")+"\n固定敌人布局／永久5级测试夹具 · 非正常通关"
	await wait(.6)
	Input.action_press("move_down");await wait(.5);Input.action_release("move_down")
	Input.action_press("move_up");await wait(.5);Input.action_release("move_up")
	Input.action_press("move_right");await wait(.3);Input.action_release("move_right")
	Input.action_press("move_left");await wait(.3);Input.action_release("move_left")
	Input.action_press("shoot");await wait(2.2)
	game.hero.cast(0,game.hero.position+game.hero.facing*100);await wait(.9)
	game.hero.cast(1,game.hero.position+game.hero.facing*100);await wait(2.8)
	Input.action_release("shoot");await wait(.5)
