extends SceneTree
# Explicit collision fixtures for snapshot invalidation, fast hits and stable foundations.
var game: ArenaGame
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("PROJECTILE FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func target(point: Vector2) -> ArenaEnemy:
	var enemy:=game.spawn_enemy("fox",0,0);enemy.position=point+Vector2(0,enemy.radius);return enemy
func run() -> void:
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false);root.add_child(game);await process_frame;game.start_run("knight","creek")
	var a:=target(Vector2(600,400));var hp:=a.health
	var shot:=game.fire_projectile(Vector2(400,400),Vector2(800,400),30,0,"tower")
	shot._physics_process(0.5)
	check(is_equal_approx(a.health,hp-30),"fast projectile hits a crossed target")
	var miss:=target(Vector2(580,455));hp=miss.health
	shot=game.fire_projectile(Vector2(400,400),Vector2(800,400),10,0,"tower");shot._physics_process(0.5)
	check(is_equal_approx(miss.health,hp),"broad phase does not hit an off-path target")
	game.remove_enemy(a)
	var fresh:=target(Vector2(510,400));hp=fresh.health
	shot=game.fire_projectile(Vector2(400,400),Vector2(800,400),20,0,"tower");shot._physics_process(0.3)
	check(is_equal_approx(fresh.health,hp-20),"same-tick replacement invalidates cached targets")
	var second:=target(Vector2(630,400));var first_hp:=fresh.health;var second_hp:=second.health
	shot=game.fire_projectile(Vector2(400,400),Vector2(800,400),15,0,"hero",{"pierce":2});shot.speed=1000;shot._physics_process(0.3)
	check(is_equal_approx(fresh.health,first_hp-15) and is_equal_approx(second.health,second_hp-15),"piercing preserves both hits and target order")
	game.gold=10000;game.cycle=5
	for kind in ArenaDefinitions.DEFAULT_TOWERS:
		var index: int=ArenaDefinitions.DEFAULT_TOWERS.find(kind)
		check(game.build_tower(index,kind),"foundation fixture builds "+kind)
		var tower:=game.site_tower(index)
		for tier in range(1,4):
			if tier>1:tower.upgrade()
			var contact:=ArenaBattleArt.contact(kind,tier,tower.body.texture.get_size())
			var local: Vector2=(Vector2(contact.uv)-Vector2(0.5,0.5))*tower.body.texture.get_size()+tower.body.offset
			check(tower.body.to_global(local).distance_to(tower.position)<0.01,"contact stays at authored site "+kind+str(tier))
			tower.fire_clock=0.12;tower._physics_process(0.016)
			check(is_zero_approx(tower.body.rotation),"firing never rotates the foundation "+kind+str(tier))
	var archer:=game.site_tower(0)
	archer.visual_target=Vector2.LEFT
	archer._pose_mechanism()
	check(archer.muzzle().is_equal_approx(archer.ballista.to_global(archer.Ballista.RELEASE_CENTER)),"release follows rotated bolt rail")
	var cannon:=game.site_tower(ArenaDefinitions.TOWER_IDS.find("cannon"))
	cannon.visual_target=Vector2(-0.85,0.45).normalized()
	cannon._pose_mechanism()
	check(cannon.moving_part.scale.x<0.0 and absf(cannon.moving_part.rotation)<=0.46,"cannon flips upright instead of inverting upside-down when aiming left")
	check(cannon.muzzle().x<cannon.to_global(cannon.swivel).x,"cannon muzzle follows horizontally mirrored barrel")
	for lv in range(1,4):
		var c_base: Image=(load("res://assets/v017/tower_cannon_%d_base.png"%lv) as Texture2D).get_image()
		var c_sock: Vector2=ArenaTower.SOCKETS["cannon"][lv-1]
		check(c_base.get_pixel(int(c_sock.x),int(c_sock.y)+12).a>0.9,"cannon base has solid cradle interior without oval hole lv"+str(lv))
		var m_base: Image=(load("res://assets/v017/tower_mage_%d_base.png"%lv) as Texture2D).get_image()
		check(m_base.get_pixel(258,280).a>0.7 and m_base.get_pixel(258,310).a>0.9,"mage base preserves caster hands and pedestal lv"+str(lv))
	var hound:=game.spawn_enemy("construct_hound",0,0)
	hound.position=Vector2(820,330)
	var arrow:=game.fire_projectile(hound.center()+Vector2(80,0),hound.center(),23,0,"tower",{"target":hound,"feedback":"tower_arrow"})
	arrow._physics_process(0.16)
	check(is_equal_approx(hound.max_health-hound.health,21.85),"unbuffed arrow resolves once against hound armour")
	check(hound.visual.feedback.age==0.0 and hound.visual.feedback.incoming.x < -0.99,"light hit reacts from actual flight direction")
	game.feel.trauma=0.0
	cannon.fire_cannon(hound,48.0)
	check(not game.delayed.is_empty() and bool(game.delayed.back().options.get("cannon",false)),"cannon queues parabolic mortar shell")
	game. _physics_process(0.42)
	var has_cannon_blast:=false
	for fx in game.effects:
		if str(fx.get("kind",""))=="cannon_blast":has_cannon_blast=true;break
	check(has_cannon_blast and game.feel.trauma>0.1,"cannon shell impact spawns cannon_blast and adds camera trauma")
	var protected_hound:=game.spawn_enemy("construct_hound",0,0)
	protected_hound.barrier_shield=40
	protected_hound.take_hit(12,0,"tower",0,0,0,"tower_arrow",Vector2.RIGHT)
	check(protected_hound.health==protected_hound.max_health and game.effects.back().kind=="ward_contact","shield absorbs hit and owns contact cue")
	game.running=false;game.audio.shutdown();paused=false;await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	print("V09 PROJECTILE CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
