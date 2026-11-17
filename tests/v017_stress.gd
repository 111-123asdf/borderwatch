extends SceneTree
# Explicit active-combat pressure fixture. Injected HP/resources are not a normal clear.
var game: ArenaGame
var elapsed:=0.0
var samples: Array[float]=[]
var base:=""
var finished:=false
func _initialize() -> void:call_deferred("run")
func run() -> void:
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);game.campaign.data.levels.knight=5;root.add_child(game);current_scene=game;await process_frame
	game.start_run("knight","ruins");game.cycle=8;game.gold=20000;game.core_max=100000;game.core_health=100000;game.hero.max_health=100000;game.hero.health=100000
	for i in range(mini(12,game.level_definition.sites.size())):
		if game.site_locked(i):game.unlock_site(i)
		if game.build_tower(i,["archer","mage","cannon","barracks"][i%4]):
			var tower: ArenaTower=game.site_tower(i);tower.upgrade();tower.upgrade();tower.choose_doctrine(str(ArenaDoctrines.for_tower(tower.kind)[0].id))
	game.begin_wave();game.spawn_queue.clear();Input.action_press("shoot")
	for i in range(120):game.spawn_enemy(["construct_hound","rune_warden","astral_prism","rift_bomber","void_harvester"][i%5],i%game.routes.size(),300+i*9)
func _process(delta: float) -> bool:
	if finished or game==null or not game.started:return false
	elapsed+=delta
	if game.choice_open:game.choose_perk(game.choices[0])
	if game.camp_reward_open:game.choose_camp_reward(game.open_camp_id,"gold")
	if game.enemies.size()<105:game.spawn_enemy(["construct_hound","rune_warden","astral_prism","rift_bomber","void_harvester"][int(elapsed*100)%5],int(elapsed*100)%game.routes.size(),200+fmod(elapsed*70,1200))
	if elapsed>3:samples.append(delta*1000.0)
	if elapsed>18:
		finished=true;samples.sort();var total:=0.0
		for value in samples:total+=value
		print("V017 STRESS active=",game.enemies.size()," towers=",game.towers.size()," mean_ms=",snappedf(total/samples.size(),0.01)," p95_ms=",snappedf(samples[int(samples.size()*0.95)],0.01)," p99_ms=",snappedf(samples[int(samples.size()*0.99)],0.01))
		finish.call_deferred()
	return false
func finish() -> void:
	Input.action_release("shoot");game.running=false;game.audio.shutdown();await create_timer(0.25).timeout;game.queue_free();await process_frame;await process_frame;quit()
