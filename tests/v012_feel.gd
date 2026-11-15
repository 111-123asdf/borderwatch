extends SceneTree
# Explicit presentation fixtures. No injected state is represented as a playthrough.
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
	for identity in ["ranger","mage"]:
		game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);game.campaign.data.levels[identity]=5
		root.add_child(game);await process_frame;game.start_run(identity,"forest");game.set_physics_process(false);game.hero.set_physics_process(false)
		var hero:=game.hero;var visual:=hero.visual
		check(visual.has_complete_set(),identity+" complete directions/states")
		check(ArenaHeroArt.folder(identity)=="res://assets/v012/",identity+" uses new art")
		check(ArenaHeroArt.portrait(identity).get_width()>0,identity+" new portrait exists")
		check(hero.data.type==(0 if identity=="ranger" else 1),identity+" damage category preserved")
		check(hero.data.damage==33 and hero.data.interval==(.65 if identity=="ranger" else .9),identity+" attack numbers preserved")
		for child in hero.get_children():
			if child is CollisionShape2D:check(child.shape.radius==12,identity+" unchanged collision")
		for view in ["side","down","up"]:
			var spec: Dictionary=visual.pose_data.views[view]
			check(float(spec.height)>100,identity+view+" actual art height")
			for state in ArenaActor.STATES:
				var frames: Array=spec.states[state];check(frames.size()==8,identity+view+state+" eight key poses")
				var total:=0.0
				for weight in ArenaMotion.holds(identity,state):total+=float(weight)
				check(is_equal_approx(total,ArenaMotion.frame_count(state)),identity+state+" holds retain duration")
				for frame in frames:
					var box: Array=frame.rect;var foot: Array=frame.anchor;var socket: Array=frame.socket
					check(box[2]>0 and box[3]>0 and foot[1]<=box[3],identity+view+state+" ground within region")
					check(socket[0]>=0 and socket[0]<=box[2] and socket[1]>=0 and socket[1]<=box[3],identity+view+state+" emission inside art")
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
				check(shot.pierce==(1 if identity=="ranger" and index==2 else 0),identity+" existing third-arrow penetration")
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
		if identity=="ranger":check(hero.rolling>0 and hero.protection>0,"roll protection begins immediately, not on late release")
		hero.release_action()
		if identity=="mage":
			check(enemy.slow==3.0 and enemy.stun==0,"frost remains slow, not new stun")
			check(game.effects.any(func(f):return f.kind=="frost_painted"),"frost has dedicated painted effect")
		hero.cancel_action();game.delayed.clear();check(hero.cast(1,enemy.position),identity+" real ultimate");hero.release_action()
		check(game.delayed.size()==(6 if identity=="ranger" else 1),identity+" unchanged pulse count")
		for index in range(game.delayed.size()):
			var packet: Dictionary=game.delayed[index]
			check(is_equal_approx(packet.duration,.4+index*.32 if identity=="ranger" else .85),identity+" unchanged delay")
			check(packet.radius==(135 if identity=="ranger" else 155) and packet.type==(0 if identity=="ranger" else 1),identity+" unchanged radius/type")
		# Lab must skip wave progression but still execute delayed skill hits.
		hero.cancel_action();hero.visual.feedback.clear(visual);game.feel_lab=true
		var before:=enemy.health;game._physics_process(.41 if identity=="ranger" else .86)
		check(enemy.health<before,identity+" lab actually resolves delayed damage")
		check(visual.feedback.stop_left==0,identity+" delayed impact never holds unrelated shooter animation")
		game.campaign.data.reduced_motion=true;game.feel.tick(game,.01)
		check(game.camera.offset==Vector2.ZERO,"reduced motion retains fixed full-map camera")
		for cue in ArenaAudio.HERO_CUES:
			check(game.audio.banks.has(cue),"sample loaded "+cue)
			for stream in game.audio.banks.get(cue,[]):check(stream.get_length()>0,"audible sample length "+cue)
		game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	check(ArenaHeroArt.folder("knight")=="res://assets/v011/","approved knight asset family preserved")
	print("V012 FEEL CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
