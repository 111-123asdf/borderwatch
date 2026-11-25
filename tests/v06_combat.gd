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
	paused=false;game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
func run() -> void:
	for identity in ArenaDefinitions.HERO_IDS:
		game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);root.add_child(game);await process_frame
		game.start_run(identity,"creek")
		var h: ArenaHero=game.hero
		# Isolate combat skill tests at base stats; campaign bonuses are tested in v09_campaign.
		h.meta_level=5
		check(h.max_health==ArenaDefinitions.HEROES[identity].health,"class health "+identity)
		check(h.cooldowns==[0.0,0.0],"skills start ready")
		game.request_skill(1)
		if game.skill_needs_target(1):
			check(game.targeting_slot==1 and h.cooldowns[1]==0,"aim mode doesn't spend cooldown")
			var cancel:=InputEventMouseButton.new();cancel.button_index=MOUSE_BUTTON_RIGHT;cancel.pressed=true;game._unhandled_input(cancel)
			check(game.targeting_slot==-1 and h.cooldowns[1]==0 and h.path.is_empty(),"cancel does not spend skill or move")
			var key_e:=InputEventKey.new();key_e.keycode=KEY_E;key_e.pressed=true;game._unhandled_input(key_e)
			check(game.targeting_slot==1 and h.cooldowns[1]==0,"keyboard E enters targeting mode for "+identity)
			var fire_lmb:=InputEventMouseButton.new();fire_lmb.button_index=MOUSE_BUTTON_LEFT;fire_lmb.pressed=true;fire_lmb.position=Vector2(600,450);game._unhandled_input(fire_lmb)
			check(game.targeting_slot==-1 and h.cooldowns[1]>0,"left click fires targeted ultimate for "+identity)
		else:
			check(h.cooldowns[1]>0,"self ultimate casts immediately")
		if identity=="lord":
			var key_q:=InputEventKey.new();key_q.keycode=KEY_Q;key_q.pressed=true;game._unhandled_input(key_q)
			check(game.targeting_slot==0 and h.cooldowns[0]==0,"lord Q enters directional cone targeting")
			var cancel_q:=InputEventMouseButton.new();cancel_q.button_index=MOUSE_BUTTON_RIGHT;cancel_q.pressed=true;game._unhandled_input(cancel_q)
			check(game.targeting_slot==-1 and h.cooldowns[0]==0,"right click cancels lord Q targeting")
		h.cancel_action();h.cooldowns=[0.0,0.0]
		check(h.cast(0,h.position+Vector2.LEFT*100),"small skill casts "+identity);var cd:=h.cooldowns[0]
		check(not h.cast(0,h.position) and h.cooldowns[0]==cd,"cooldown can't be bypassed")
		h.release_action();h.cancel_action()
		check(h.cast(1,h.position+Vector2.LEFT*150),"ultimate casts "+identity);h.release_action();h.cancel_action()
		if identity=="lord":check(h.lord_shield_clock>0 and h.overheal_shield>0,"lord ult grants blood-thorn shield")
		elif identity=="druid":check(h.companions.size()==2 and h.companions.all(func(b):return b.boost>=6.5),"druid ult awakens and empowers both wolves")
		elif identity=="healer":check(h.healer_sanctuary_clock>0,"healer ult opens blooming sanctuary")
		elif identity=="werewolf":check(h.werewolf_beast_clock>0 and h.visual.active_form=="werewolf_beast","werewolf ult transforms into giant white werewolf")
		elif identity=="gunner":check(h.gunner_overdrive_clock>0,"gunner ult activates overdrive")
		h.meta_cooldown=0.4
		check(is_equal_approx(h.cooldown_scale(),0.7),"CD reduction hard cap thirty percent")
		check(h.visual.has_complete_set(),"seven states and three directions "+identity)
		h.path=PackedVector2Array([h.position+Vector2(60,0)])
		Input.action_press("move_up");h._physics_process(0.016);Input.action_release("move_up")
		check(h.path.is_empty(),"manual movement cancels mouse order")
		# Out-of-range enemy does not trigger auto-attack.
		var enemy:=game.spawn_enemy("fox",0,400);h.position=enemy.position+Vector2(580,0);h.attack_cooldown=0;h.cancel_action();h.rolling=0;h.queued_attack_point=Vector2.INF;Input.action_release("shoot");h._physics_process(0.016)
		check(h.action=="","out of range means no primary attack")
		h.position=enemy.position+Vector2(20,0);h.attack_cooldown=0
		check(h.begin_attack(enemy),"primary starts from a valid target")
		var release:=ArenaActor.CONTACT_FRAME
		var shot_count:=h.shots;h.visual.frame=release-1
		check(not h.action_released and h.shots==shot_count,"anticipation cannot deal early damage")
		h.visual.frame=release
		check(h.action_released and h.shots==shot_count+1,"authored contact frame releases exactly once")
		h.visual.frame=release+1
		check(h.shots==shot_count+1,"recovery cannot repeat the attack")
		# Moving never aborts normal attack windup, and empty attack (whiff) works without a target.
		h.cancel_action();h.attack_cooldown=0.0
		var whiff_before:=h.shots
		check(h.begin_attack(null,h.position+Vector2.RIGHT*180.0),"empty attack starts without enemy "+identity)
		Input.action_press("move_left");h._physics_process(0.05);Input.action_release("move_left")
		check(h.action=="attack" and not h.action_released and h.velocity.length()>0.0,"moving during windup keeps attack alive and moves hero "+identity)
		h.release_action()
		check(h.shots==whiff_before+1,"moving empty attack completes release "+identity)
		h.cancel_action()
		# Enemy projectile can pass a tower and a soldier without hitting either.
		game.gold=1000;game.build_tower(0,"barracks");game.site_tower(0).finish_project();var s: ArenaSoldier=game.soldiers[0]
		var hp:=s.health;var shot:=game.fire_projectile(s.center() if s.has_method("center") else s.position,s.position+Vector2(50,0),40,1,"enemy")
		shot._physics_process(0.05);check(s.health==hp,"hostile bullets don't damage soldiers")
		var boss:=game.spawn_enemy("moth",0,game.routes[0].get_baked_length()-1)
		boss._physics_process(0.1);check(game.game_over and not game.victory,"boss reaching base ends run")
		await cleanup()
	print("V06 COMBAT CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
