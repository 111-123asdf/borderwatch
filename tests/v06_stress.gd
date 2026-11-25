extends SceneTree
# Dense active-combat stress fixture: injected resources/HP are intentional.
var game: ArenaGame
var elapsed:=0.0
var samples: Array[float]=[]
var physics: Array[float]=[]
var population:=105
var identity:="knight"
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--enemies="):population=clampi(int(argument.trim_prefix("--enemies=")),16,180)
		if argument.begins_with("--hero="):identity=argument.trim_prefix("--hero=")
	if identity not in ArenaDefinitions.HERO_IDS:identity="knight"
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);game.campaign.data.levels[identity]=5;root.add_child(game);current_scene=game;await process_frame
	game.start_run(identity,"creek");game.choose_defense_rule("");game.hero.position=game.routes[0].sample_baked(1100)
	game.cycle=8;game.gold=20000;game.core_max=100000;game.core_health=100000
	game.hero.max_health=100000;game.hero.health=100000
	for i in range(10):
		if game.site_locked(i):game.unlock_site(i)
		game.build_tower(i,["archer","mage","cannon","barracks"][i%4]);var tower: ArenaTower=game.site_tower(i)
		if tower==null:push_error("Stress fixture could not build tower");quit(1);return
		tower.finish_project()
		tower.upgrade();tower.finish_project();tower.upgrade();tower.finish_project();tower.choose_doctrine(str(ArenaDoctrines.for_tower(tower.kind)[0].id))
	for i in range(population+15):game.spawn_enemy(["fox","brute","wisp","spearman","spore"][i%5],i%2,150+i*12)
	game.begin_wave();Input.action_press("shoot")
func _process(delta: float) -> bool:
	if has_meta("finished") or game==null or not game.started:return false
	elapsed+=delta
	if not game.rule_offers.is_empty():game.choose_defense_rule("");game.suppress_primary=false
	var target:=game.nearest_enemy(game.hero.position,350)
	if target!=null:
		game.hero.cast(0,target.position);game.hero.cast(1,target.position)
	if elapsed>3:
		samples.append(delta*1000)
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
	if game.enemies.size()<population:
		game.spawn_enemy(["fox","brute","wisp","spearman","spore"][int(elapsed*100)%5],int(elapsed*100)%2,100+fmod(elapsed*70,1200))
	if elapsed>18:
		var mean:=0.0
		var over_budget:=0
		for value in samples:
			mean+=value
			if value>1000.0/60.0:over_budget+=1
		mean/=samples.size();samples.sort();physics.sort()
		# Godot publishes the largest physics step per second, not individual step timings.
		print("DENSE STRESS hero=",identity," shots=",game.hero.shots," active_enemies=",game.enemies.size()," towers=",game.towers.size()," soldiers=",game.soldiers.size()," frames=",samples.size()," mean_ms=",snappedf(mean,0.01)," p95_ms=",snappedf(samples[int(samples.size()*0.95)],0.01)," p99_ms=",snappedf(samples[int(samples.size()*0.99)],0.01)," max_ms=",snappedf(samples.back(),0.01)," frames_over_16ms=",over_budget," physics_peak_monitor_p95_ms=",snappedf(physics[int(physics.size()*0.95)],0.01))
		RenderingServer.frame_post_draw.connect(capture,CONNECT_ONE_SHOT);set_meta("finished",true)
	return false
func capture() -> void:
	if not has_meta("finished"):return
	var folder:=ProjectSettings.globalize_path("user://v06-review");DirAccess.make_dir_recursive_absolute(folder);root.get_texture().get_image().save_png(folder+"/dense.png")
	Input.action_release("shoot");game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame;quit()
