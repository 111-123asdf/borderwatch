extends SceneTree
## Same starting gold and waves, with two different tower positions and one
## optional hero intervention. No spawned fixtures or replacement wave clocks.
const OPENINGS := {"dyke":[2,5],"shore":[6,9],"pump":[8,9],"relief":[2,5]}
var game: ArenaGame
var opening := "dyke"
var leaks := [0,0]
var shots := [0,0]
var first_shots := [Vector2.INF,Vector2.INF]
var switched := false
var engaged := false
var rally_started := -1.0
var rally_seconds := -1.0
var rally := Vector2.ZERO
var stopping := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--opening="):opening=arg.trim_prefix("--opening=")
	call_deferred("_start")

func _start() -> void:
	if not OPENINGS.has(opening):
		push_error("Unknown saltport opening")
		quit(1)
		return
	game=load("res://scenes/arena.tscn").instantiate()
	game.campaign=ArenaCampaign.new("",false)
	# The relief case and its counterpart have identical permanent skill access.
	game.campaign.data.levels.lord=5
	root.add_child(game)
	await process_frame
	game.rng.seed=40404
	game.start_run("lord","saltport")
	for site in OPENINGS[opening]:
		game.build_tower(site,"archer")
		game.site_tower(site).finish_project()
	if opening in ["dyke","relief"]:
		game.hero.command_move(Vector2(590,408))
	node_added.connect(_observe)
	game.request_wave()
	game.request_wave()

func _observe(node: Node) -> void:
	if node is ArenaEnemy:
		node.tree_exiting.connect(_enemy_exited.bind(node))
	elif node is ArenaProjectile and is_instance_valid(node.tower):
		var index: int=OPENINGS[opening].find(node.tower.site_id)
		if index>=0:
			if shots[index]==0:
				first_shots[index]=node.position
			shots[index]+=1

func _enemy_exited(enemy: ArenaEnemy) -> void:
	if enemy.health>0.0 and enemy.progress>=game.enemy_road(enemy).get_baked_length():
		leaks[enemy.route_id]+=1

func _physics_process(_delta: float) -> bool:
	if game==null or not game.started or stopping:
		return false
	if game.cycle==2 and game.phase=="rest":
		game.request_wave()
		game.request_wave()
	if opening=="relief" and game.cycle==2 and game.phase=="spawn":
		var target: ArenaEnemy
		for enemy in game.enemies:
			if enemy.route_id!=1:continue
			if target==null or enemy.progress>target.progress:target=enemy
		if not switched and game.wave_elapsed>=9.0:
			switched=true
			var road: Curve2D=game.routes[1]
			rally=road.sample_baked(road.get_closest_offset(Vector2(985,739)))
			rally_started=game.elapsed
			game.hero.command_move(rally)
		if switched and rally_seconds<0.0 and game.hero.position.distance_to(rally)<25:
			rally_seconds=game.elapsed-rally_started
		if switched and target!=null:
			var distance := game.hero.position.distance_to(target.position)
			if distance<115.0 and not engaged:
				engaged=game.hero.cast(0,target.position)
			if distance<85.0:
				game.hero.begin_attack(target)
			elif rally_seconds>=0.0 and Engine.get_physics_frames()%18==0:
				game.hero.command_move(target.position)
	if game.cycle>=3 or game.game_over or game.elapsed>=180.0:
		stopping=true
		print("SALTPORT OPENING ",opening, " shots=",shots, " first=",first_shots, " leaks west/south=",leaks, " health=",game.core_health, " q=",engaged, " cross_front_seconds=",snappedf(rally_seconds,0.01)," damage=",game.damage_stats)
		_finish.call_deferred()
	return false

func _finish() -> void:
	Input.action_release("shoot")
	game.running=false
	game.audio.shutdown()
	await process_frame
	OS.delay_msec(120)
	game.queue_free()
	await process_frame
	quit()
