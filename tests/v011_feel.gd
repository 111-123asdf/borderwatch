extends SceneTree
# Explicit presentation/combat fixtures for v022 pixel-art tank hero (Lord Dolorion).
var game: ArenaGame
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FEEL FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func target(progress:=500.0) -> ArenaEnemy:
	var enemy:=game.spawn_enemy("brute",0,progress);enemy.set_physics_process(false);return enemy
func run() -> void:
	create_timer(30).timeout.connect(func():push_error("FEEL TEST TIMEOUT");quit(1))
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);game.campaign.data.levels["lord"]=5
	root.add_child(game);await process_frame;game.start_run("lord","forest")
	game.set_physics_process(false);game.hero.set_physics_process(false)
	check(is_equal_approx(game.hero.visual.visual_size,ArenaHeroArt.height("lord",true)),"lord uses configured live sprite height")
	check(game.hero.block_capacity()==3,"visual scale preserves block capacity")
	var collision: CollisionShape2D
	for child in game.hero.get_children():
		if child is CollisionShape2D:collision=child
	check(collision!=null and collision.shape.radius==12,"visual scale preserves collision")
	check(not game.campaign.persistent,"fixture does not persist")
	check(game.hero.visual.has_complete_set(),"lord has complete 3-view x 7-state sprites")
	for view in ["side","down","up"]:
		for state in ArenaActor.STATES:
			var anim: String = state + "_" + view
			check(game.hero.visual.sprite_frames.get_frame_count(anim)==ArenaActor.POSE_COUNT,"eight pixel poses "+anim)
	for key in ArenaAudio.FILES:
		check(game.audio.banks.has(key),"sample bank loaded "+key)
		for stream in game.audio.banks.get(key,[]):check(stream.get_length()>0,"sample has duration "+key)
	var enemy:=target();var original_position:=enemy.position;var original_radius:=enemy.radius
	game.numbers.clear();enemy.take_hit(5,0,"tower")
	check(game.numbers.is_empty(),"tower damage has no floating number")
	var hp:=enemy.health
	enemy.take_hit(10,0,"hero");enemy.take_hit(10,0,"hero")
	check(game.numbers.size()==1,"same target and type merge within 150ms")
	check(is_equal_approx(game.numbers[0].amount,hp-enemy.health),"merged number sums resolved damage")
	game.numbers[0].merge=0.0;enemy.take_hit(2,0,"hero")
	check(game.numbers.size()==2,"next merge window gets separate number")
	enemy.take_hit(2,1,"hero")
	check(game.numbers.size()==3,"physical and magic remain distinct")
	var another:=target(550);another.take_hit(2,0,"hero")
	check(game.numbers.size()==4,"different targets never merge")
	check(enemy.position==original_position and enemy.radius==original_radius,"impact leaves route position and radius unchanged")
	var base:=enemy.visual.feedback.base_scale
	enemy.visual.feedback.tick(enemy.visual,0.01)
	check(enemy.visual.feedback.age<0.12 and enemy.visual.animation=="hurt","impact selects the target recoil pose")
	enemy.visual.feedback.tick(enemy.visual,0.2)
	check(enemy.visual.scale.is_equal_approx(base),"impact recovers to rest")
	game.hero.action="small";game.hero.action_released=true;enemy.take_hit(2,0,"hero",0.0,0.0,0.0,"small")
	check(enemy.visual.feedback.stop_left>0 and game.hero.visual.feedback.stop_left>0,"heavy cleave locally holds victim and released hero")
	check(is_equal_approx(Engine.time_scale,1.0),"local stop never changes global time")
	var trauma:=game.feel.trauma;enemy.take_hit(2,0,"hero",0.0,0.0,0.0,"small")
	check(is_equal_approx(trauma,game.feel.trauma),"multi-target cleave cannot stack camera trauma in same interval")
	game.hero.cooldowns[0]=3.0;game.hero.visual.feedback.freeze_after_release();game.hero._physics_process(0.016)
	check(game.hero.cooldowns[0]<3.0,"cooldowns continue during visual stop")
	game.hero.cancel_action();check(game.hero.visual.feedback.stop_left==0,"movement/action cancellation clears visual stop")
	game.campaign.data.reduced_motion=true;enemy.take_hit(1,0,"hero",0.0,0.0,0.0,"small");enemy.visual.feedback.tick(enemy.visual,0.08);game.feel.tick(game,0.01)
	check(game.camera.offset==Vector2.ZERO,"reduced motion disables camera feedback")
	check(enemy.visual.feedback.stop_left==0,"reduced motion disables local stop")
	game.campaign.data.reduced_motion=false;game.hero.action="";game.hero.attack_cooldown=0
	game.hero.position=another.position+Vector2(35,0);var before:=another.health
	check(game.hero.begin_attack(another),"real attack can start")
	game.hero.release_action();var after:=another.health;game.hero.release_action()
	check(after<before and is_equal_approx(after,another.health),"release marker and clock cannot double hit")
	var cd:=game.hero.attack_cooldown;game.hero.cancel_action()
	check(game.hero.attack_cooldown==cd,"cancel does not reset attack cooldown")
	var doomed:=target(800);var gold:=game.gold;var kills:=game.kills
	doomed.take_hit(10000,0,"hero");var reward:=game.gold-gold
	check(doomed.dead and doomed not in game.enemies and game.kills==kills+1,"death immediately leaves combat and awards kill")
	doomed.take_hit(10000,0,"hero")
	check(game.gold-gold==reward and game.kills==kills+1,"death cannot duplicate rewards")
	game.feel.clear(game)
	check(game.camera.offset==Vector2.ZERO and game.hero.visual.feedback.stop_left==0,"clear removes feedback state")
	game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	print("V011 FEEL CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
