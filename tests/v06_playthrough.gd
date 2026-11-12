extends SceneTree
# Legal action driver: normal starting resources, actual enemies/rewards/timers.
# No mutation of HP/gold/damage/cooldowns/wave timing/enemy deaths.
var game: ArenaGame
var decision:=0.0
var passed:=false
var hero_id:="knight"
var stage:="forest"
var last_wave:=0
var camp_cursor:=0
var casts:=0
var knockouts:=0
var was_down:=false
var timer:=0.0
var stopping:=false
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hero="):hero_id=arg.trim_prefix("--hero=")
		if arg.begins_with("--level="):stage=arg.trim_prefix("--level=")
	if hero_id not in ArenaDefinitions.HERO_IDS or stage not in ArenaLevelCatalog.IDS:push_error("Invalid playthrough arguments");quit(1);return
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game;await process_frame
	game.progression=ArenaProgression.new("user://normal-"+hero_id+"-"+stage+".cfg",false)
	game.rng.seed=60406;game.start_run(hero_id,stage);Input.action_press("shoot")
func release_and_hold() -> void:
	Input.action_release("shoot")
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false;game._input(event)
	Input.action_press("shoot")
func _process(delta: float) -> bool:
	if stopping or game==null or not game.started:return false
	timer+=delta
	if game.choice_open:
		var priorities: Array=[]
		for card in ArenaPerks.CARDS:
			var only:=str(card.get("hero",""))
			if only=="" or only==hero_id: priorities.append(str(card.id))
		for key in priorities:
			if key in game.choices:game.choose_perk(key);release_and_hold();break
		return false
	if game.camp_reward_open:
		var reward: String="hero"
		if game.doctrine_tokens==0 and game.l2_count()>0:reward="token"
		elif game.gold<120:reward="gold"
		game.choose_camp_reward(game.open_camp_id,reward)
		return false
	if game.game_over:
		print("TELEMETRY ",JSON.stringify(game.telemetry()))
		print("NORMAL ",hero_id," ",stage," won=",game.victory," wave=",game.cycle," kills=",game.kills," core=",game.core_health," camps=",game.camps_cleared," l3=",l3_count()," doctrines=",doctrine_count()," casts=",casts," KO=",knockouts," simulated seconds=",snappedf(game.elapsed,0.1)," damage=",game.damage_stats)
		passed=game.victory and game.cycle==8 and game.built>=4 and casts>0
		stopping=true;finish.call_deferred();return false
	if timer>1100:push_error("NORMAL TIMEOUT "+hero_id+" "+stage);stopping=true;finish.call_deferred();return false
	decision-=delta
	if decision>0:return false
	decision=0.25
	if game.hero.knocked_out and not was_down:knockouts+=1
	was_down=game.hero.knocked_out
	if last_wave!=game.cycle:print("WAVE ",game.cycle," core=",game.core_health," gold=",game.gold," elapsed=",int(game.elapsed));last_wave=game.cycle
	manage_towers()
	if game.hero.knocked_out:return false
	var target: ArenaEnemy
	var greatest:=-INF
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_guard:continue
		var score: float=enemy.progress/game.routes[enemy.route_id].get_baked_length()
		if enemy.kind=="moth":score+=0.12
		if score>greatest:greatest=score;target=enemy
	if target==null:
		for enemy in game.enemies:
			if not is_instance_valid(enemy) or enemy.dead or not enemy.is_guard:continue
			if target==null or game.hero.position.distance_to(enemy.position)<game.hero.position.distance_to(target.position):target=enemy
	if target!=null:
		var spacing: float=28 if hero_id=="knight" else 150
		var offset: Vector2=(game.hero.position-target.position).normalized()
		if offset.length()<0.1:offset=Vector2.RIGHT
		var destination: Vector2=target.position+offset*spacing
		if game.hero.health<game.hero.max_health*0.27:
			destination=game.level_definition.hero_spawn+Vector2(-50,75)
		if game.hero.position.distance_to(destination)>35:game.hero.command_move(destination)
		if game.hero.position.distance_to(target.position)<(150 if hero_id=="knight" else 310):
			if game.hero.cooldowns[0]<=0 and game.hero.cast(0,target.position):casts+=1
			if game.hero.cooldowns[1]<=0 and game.hero.cast(1,target.position):casts+=1
	elif game.hero.position.distance_to(game.level_definition.hero_spawn)>80:game.hero.command_move(game.level_definition.hero_spawn)
	if game.phase=="rest" and game.camps_cleared==2 and game.hero.health>game.hero.max_health*0.85:
		game.request_wave()
	return false
func l3_count() -> int:
	var total:=0
	for tower in game.towers:
		if is_instance_valid(tower) and tower.level>=3:total+=1
	return total
func doctrine_count() -> int:
	var total:=0
	for tower in game.towers:
		if is_instance_valid(tower) and tower.doctrine_id!="":total+=1
	return total
func manage_towers() -> void:
	var order: Array=[0,1,3,2,4,5,6,7] if stage=="forest" else [0,5,1,6,3,7,4,8,2,9]
	var plan: Array=["archer","barracks","mage","archer","cannon","mage","archer","cannon"] if stage=="forest" else ["archer","mage","mage","barracks","archer","archer","cannon","mage","cannon","archer"]
	if game.cycle>=6:
		for index in order:
			if game.site_locked(index) and game.gold>=game.unlock_price(index)+120:game.unlock_site(index);return
	for index in order:
		var kind: String=plan[index]
		if game.site_tower(index)==null and kind in game.available_towers() and game.gold>=ArenaDefinitions.TOWERS[kind].cost:game.build_tower(index,kind);return
	for tower in game.towers:
		if tower.awaiting_doctrine:
			var options: Array=ArenaDoctrines.for_tower(tower.kind)
			if not options.is_empty():tower.choose_doctrine(str(options[(tower.site_id+game.cycle)%options.size()].id))
			return
	for tower in game.towers:
		if tower.level==2 and game.doctrine_tokens>0:tower.upgrade("",true);return
	for tower in game.towers:
		if tower.level<3 and game.gold>=tower.upgrade_price():tower.upgrade();return
func finish() -> void:
	Input.action_release("shoot");paused=false;game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame;quit(0 if passed else 1)
