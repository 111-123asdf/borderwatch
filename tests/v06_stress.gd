extends SceneTree
# Dense active-combat stress fixture: injected resources/HP are intentional.
var game: ArenaGame
var elapsed:=0.0
var samples: Array[float]=[]
var physics: Array[float]=[]
func _initialize() -> void:call_deferred("run")
func run() -> void:
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game;await process_frame
	game.start_run("knight","creek")
	game.cycle=8;game.gold=20000;game.core_max=100000;game.core_health=100000
	game.hero.max_health=100000;game.hero.health=100000
	for i in range(10):
		game.build_tower(i,["archer","mage","cannon","barracks"][i%4]);var tower: ArenaTower=game.site_tower(i);tower.upgrade();tower.upgrade()
	for i in range(120):game.spawn_enemy(["fox","brute","wisp","spearman","spore"][i%5],i%2,150+i*12)
	game.begin_wave();Input.action_press("shoot")
func _process(delta: float) -> bool:
	if has_meta("finished") or game==null or not game.started:return false
	elapsed+=delta
	if game.choice_open:game.choose_perk(game.choices[0]);game.suppress_primary=false
	if elapsed>3:
		samples.append(delta*1000)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
	if game.enemies.size()<105:
		game.spawn_enemy(["fox","brute","wisp","spearman","spore"][int(elapsed*100)%5],int(elapsed*100)%2,100+fmod(elapsed*70,1200))
	if elapsed>18:
		var mean:=0.0
		for value in samples:mean+=value
		mean/=samples.size();samples.sort();physics.sort()
		print("DENSE STRESS active_enemies=",game.enemies.size()," towers=",game.towers.size()," soldiers=",game.soldiers.size()," frames=",samples.size()," mean_ms=",snappedf(mean,0.01)," p95_ms=",snappedf(samples[int(samples.size()*0.95)],0.01)," physics_p95_ms=",snappedf(physics[int(physics.size()*0.95)],0.01))
		RenderingServer.frame_post_draw.connect(capture,CONNECT_ONE_SHOT);set_meta("finished",true)
	return false
func capture() -> void:
	if not has_meta("finished"):return
	var folder:=ProjectSettings.globalize_path("user://v06-review");DirAccess.make_dir_recursive_absolute(folder);root.get_texture().get_image().save_png(folder+"/dense.png")
	Input.action_release("shoot");game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame;quit()
