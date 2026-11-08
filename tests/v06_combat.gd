extends SceneTree
# Explicit rule fixtures. Tests type consistency, casts, failure boundaries and inputs.
var game: ArenaGame
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("COMBAT FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func cleanup() -> void:
	paused=false;game.choice_queue=0;game.choice_open=false;game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
func run() -> void:
	for identity in ArenaDefinitions.HERO_IDS:
		game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);await process_frame
		game.start_run(identity,"creek")
		var h: ArenaHero=game.hero
		check(h.max_health==ArenaDefinitions.HEROES[identity].health,"class health "+identity)
		check(h.cooldowns==[0.0,0.0],"skills start ready")
		game.request_skill(1)
		if identity!="knight":
			check(game.targeting_slot==1 and h.cooldowns[1]==0,"aim mode doesn't spend cooldown")
			var cancel:=InputEventMouseButton.new();cancel.button_index=MOUSE_BUTTON_RIGHT;cancel.pressed=true;game._unhandled_input(cancel)
			check(game.targeting_slot==-1 and h.cooldowns[1]==0,"cancel does not spend skill")
		else:check(h.cooldowns[1]>0,"warcry icon immediately casts")
		h.cancel_action();h.cooldowns=[0.0,0.0]
		check(h.cast(0,h.position+Vector2.LEFT*100),"small skill casts "+identity);var cd:=h.cooldowns[0]
		check(not h.cast(0,h.position) and h.cooldowns[0]==cd,"cooldown can't be bypassed")
		h.release_action();h.cancel_action()
		check(h.cast(1,h.position+Vector2.LEFT*150),"ultimate casts "+identity);h.release_action();h.cancel_action()
		if identity=="knight":check(game.war_cry_clock>0,"warcry enhances nearby combat")
		else:check(not game.delayed.is_empty(),"ranged ult schedules actual damage")
		for key in ArenaDefinitions.PERKS:
			for rank in range(3):check(h.apply_perk(key),"valid perk "+identity+" "+key)
			check(not h.apply_perk(key),"perk cap "+key)
		h.meta_cooldown=0.1
		check(is_equal_approx(h.cooldown_scale(),0.7),"CD reduction hard cap thirty percent")
		check(h.visual.has_complete_set(),"seven states and three directions "+identity)
		h.path=PackedVector2Array([h.position+Vector2(60,0)])
		Input.action_press("move_up");h._physics_process(0.016);Input.action_release("move_up")
		check(h.path.is_empty(),"manual movement cancels mouse order")
		# No input means no automatic attack.
		var enemy:=game.spawn_enemy("fox",0,400);h.position=enemy.position+Vector2(20,0);h.attack_cooldown=0;h.cancel_action();h.rolling=0;Input.action_release("shoot");h._physics_process(0.016)
		check(h.action=="","no click means no primary attack")
		check(h.begin_attack(enemy),"primary starts from a valid target")
		var shot_count:=h.shots;h.visual.frame=2
		check(not h.action_released and h.shots==shot_count,"anticipation cannot deal early damage")
		h.visual.frame=3
		check(h.action_released and h.shots==shot_count+1,"fourth frame releases exactly once")
		h.visual.frame=4
		check(h.shots==shot_count+1,"recovery cannot repeat the attack")
		# Enemy projectile can pass a tower and a soldier without hitting either.
		game.gold=1000;game.build_tower(0,"barracks");var s: ArenaSoldier=game.soldiers[0]
		var hp:=s.health;var shot:=game.fire_projectile(s.center() if s.has_method("center") else s.position,s.position+Vector2(50,0),40,1,"enemy")
		shot._physics_process(0.05);check(s.health==hp,"hostile bullets don't damage soldiers")
		var boss:=game.spawn_enemy("moth",0,game.routes[0].get_baked_length()-1)
		boss._physics_process(0.1);check(game.game_over and not game.victory,"boss reaching base ends run")
		await cleanup()
	print("V06 COMBAT CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
