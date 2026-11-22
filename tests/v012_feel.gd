extends SceneTree
# Explicit presentation fixtures for ranged v022 pixel-art heroes (Gunner Syrus & Healer Aphrodite).
var game: ArenaGame
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V012 FEEL FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func target(at: Vector2) -> ArenaEnemy:
	var enemy:=game.spawn_enemy("brute",0,500);enemy.position=at;enemy.set_physics_process(false);return enemy
func projectiles() -> Array:
	return game.actors.get_children().filter(func(node):return node is ArenaProjectile and not node.is_queued_for_deletion())
func run() -> void:
	create_timer(50).timeout.connect(func():push_error("V012 FEEL TIMEOUT");quit(1))
	for identity in ["gunner","healer"]:
		game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);game.campaign.data.levels[identity]=5
		root.add_child(game);await process_frame;game.start_run(identity,"forest");game.set_physics_process(false);game.hero.set_physics_process(false)
		var hero:=game.hero;var visual:=hero.visual
		check(visual.has_complete_set(),identity+" complete directions/states")
		check(ArenaHeroArt.portrait(identity).get_width()>0,identity+" v022 portrait exists")
		check(hero.data.type==(0 if identity=="gunner" else 1),identity+" damage category preserved")
		for child in hero.get_children():
			if child is CollisionShape2D:check(child.shape.radius==12,identity+" unchanged collision")
		for view in ["side","down","up"]:
			for state in ArenaActor.STATES:
				var animation: String=state+"_"+view
				check(visual.sprite_frames.get_frame_count(animation)==ArenaActor.POSE_COUNT,identity+" eight poses "+animation)
		visual.show_state("attack",Vector2.RIGHT);var right:=visual.emission_origin("attack")-hero.position
		visual.show_state("attack",Vector2.LEFT);var left:=visual.emission_origin("attack")-hero.position
		check(is_equal_approx(right.x,-left.x) and is_equal_approx(right.y,left.y),identity+" mirrored emission socket")
		check(right.length()>15 and right.length()<140,identity+" socket stays on visible character")
		hero.position=Vector2(700,500);var enemy:=target(Vector2(820,500))
		for index in range(3):
			hero.attack_cooldown=0;hero.cancel_action();check(hero.begin_attack(enemy),identity+" starts attack")
			hero.release_action();var shots:=projectiles();check(shots.size()==1,identity+" release emits exactly one shot")
			if not shots.is_empty():
				var shot: ArenaProjectile=shots[0];shot.set_physics_process(false)
				check(shot.presentation==identity and shot.damage_type==hero.data.type,identity+" projectile stores presentation and actual damage")
				check(shot.pierce==0,identity+" baseline attack does not inherit penetration")
				var tag:=shot.feedback_tag;hero.cancel_action();check(shot.feedback_tag==tag,identity+" projectile retains origin after action changes")
				hero.release_action();check(projectiles().size()==1,identity+" marker/clock cannot double emit")
				shot.queue_free()
			await process_frame
		var tower:=game.fire_projectile(Vector2.ZERO,Vector2.RIGHT,10,1,"tower")
		var hostile:=game.fire_projectile(Vector2.ZERO,Vector2.RIGHT,10,1,"enemy")
		check(tower.presentation=="" and hostile.presentation=="","unrelated projectiles keep existing visual path")
		tower.queue_free();hostile.queue_free()
		hero.cancel_action();hero.cooldowns=[0.0,0.0];hero.position=enemy.position-Vector2(60,0)
		check(hero.cast(0,enemy.position),identity+" real small skill")
		if identity=="gunner":
			check(hero.rolling>0 and hero.protection>0 and hero.empower_shot>0,"gunner dash grants invulnerability and empowers next shot immediately")
		hero.release_action()
		if identity=="healer":
			check(hero.healer_blessing_clock>0.0,"healer Q activates blessing aura")
		hero.cancel_action();check(hero.cast(1,enemy.position),identity+" real ultimate");hero.release_action()
		if identity=="gunner":
			check(hero.gunner_overdrive_clock>0.0 and hero.cooldowns[0]==0.0,"gunner E activates overdrive and resets dash cooldown")
		else:
			check(hero.healer_sanctuary_clock>0.0,"healer E opens sanctuary healing field")
		game.campaign.data.reduced_motion=true;game.feel.tick(game,.01)
		check(game.camera.offset==Vector2.ZERO,"reduced motion retains fixed full-map camera")
		for cue in ArenaAudio.HERO_CUES:
			check(game.audio.banks.has(cue),"sample loaded "+cue)
			for stream in game.audio.banks.get(cue,[]):check(stream.get_length()>0,"audible sample length "+cue)
		game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	print("V012 FEEL CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
