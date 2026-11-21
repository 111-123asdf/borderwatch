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
	game.running=false;game.audio.shutdown();paused=false;await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	print("V09 PROJECTILE CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
