extends SceneTree
# Same real runtime for both takes. Explicit level-5/enemy-layout fixture; not a playthrough.
var game: ArenaGame
var lab: ArenaFeelLab
var caption: Label
func _initialize() -> void:call_deferred("run")
func wait(seconds: float) -> void:await create_timer(seconds).timeout
func run() -> void:
	create_timer(70).timeout.connect(func():push_error("FEEL MOVIE TIMEOUT");quit(1))
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);game.campaign.data.levels.knight=5
	root.add_child(game);current_scene=game;await process_frame;game.start_run("knight","forest");game.feel_lab=true;game.phase="lab"
	lab=ArenaFeelLab.new();game.add_child(lab);lab.open(game);lab.panel.hide()
	caption=Label.new();caption.position=Vector2(35,790);caption.size=Vector2(1500,70);caption.add_theme_font_size_override("font_size",28);caption.add_theme_color_override("font_shadow_color",Color.BLACK);caption.add_theme_constant_override("shadow_offset_x",2);caption.add_theme_constant_override("shadow_offset_y",2);game.hud.root.add_child(caption)
	await take(true);await take(false)
	Input.action_release("shoot");game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame;quit()
func take(old: bool) -> void:
	Input.action_release("shoot");seed(11011);game.rng.seed=11011
	lab.baseline.set_pressed_no_signal(old);lab.apply();lab.reset_targets()
	caption.text=("原版动作/音效预设 · 原尺寸" if old else "青年骑士小样 · 视觉 ×1.3 · 新动作与音效")+"\n固定敌人布局／永久5级测试夹具 · 非正常通关"
	await wait(0.6)
	Input.action_press("move_down");await wait(0.65);Input.action_release("move_down")
	Input.action_press("move_up");await wait(0.65);Input.action_release("move_up")
	Input.action_press("shoot");await wait(2.2)
	game.hero.cast(0,game.hero.position+game.hero.facing*110);await wait(1.1)
	game.hero.cast(1,game.hero.position+game.hero.facing*110);await wait(2.8)
	Input.action_release("shoot");await wait(0.5)
