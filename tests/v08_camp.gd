extends SceneTree
# Explicit fixtures for the elite camp state machine and its economy.
var checks:=0
var failures:=0
var game: ArenaGame
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("V08 CAMP FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func guards(camp_id: int) -> Array:
	var result: Array=[]
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.is_guard and enemy.camp_id==camp_id:result.append(enemy)
	return result
func clear_camp(camp_id: int) -> void:
	for enemy in guards(camp_id):enemy.take_hit(99999,0,"hero")
func run() -> void:
	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);await process_frame
	game.progression=ArenaProgression.new("user://fixture-camp.cfg",false)
	game.start_run("knight","forest")
	check_dormant()
	activate()
	check_aura()
	check_deadline()
	check_raid()
	await check_reward()
	await check_token()
	game.choice_queue=0;game.choice_open=false
	game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame
	paused=false
	print("V08 CAMP CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
func check_dormant() -> void:
	check(game.camps.size()==2,"both authored camps exist")
	check(game.camps[0].state=="dormant" and game.camps[1].state=="dormant","camps sleep before wave two")
	check(guards(0).is_empty() and guards(1).is_empty(),"dormant camps spawn no guards")
	check(game.camp_aura(game.camps[0].point).is_empty(),"dormant camps project no aura")
	check(game.camps_cleared==0 and game.doctrine_tokens==0,"run starts with no camps or tokens")
func activate() -> void:
	game.cycle=2;game.phase="rest";game.phase_clock=10;game.begin_wave()
	check(game.camps[0].state=="active" and game.camps[1].state=="active","wave two activates camps")
	check(guards(0).size()==3 and guards(1).size()==3,"each camp fields a captain and two elites")
	var captain: ArenaEnemy=null
	for enemy in guards(0):
		if enemy.kind=="captain":captain=enemy
	check(captain!=null and is_equal_approx(captain.max_health,420.0),"captain keeps its authored health")
	check(captain.kind=="captain" and captain.is_guard and not captain.elite,"captain is the camp leader, not an elite")
func check_aura() -> void:
	var camp: ArenaCamp=game.camps[0]
	var near:=camp.point+Vector2(60,0)
	check(not game.camp_aura(near).is_empty(),"local aura covers nearby ground")
	check(is_equal_approx(float(game.camp_aura(near).speed),0.12),"aura grants enemies twelve percent speed")
	check(game.camp_aura(Vector2(200,100)).is_empty(),"local aura does not reach across the map")
	var enemy:=game.spawn_enemy("fox",0,200)
	enemy.position=near
	check(is_equal_approx(enemy.speed_scale(),1.12),"marked enemies actually move faster")
	enemy.position=Vector2(200,100)
	check(is_equal_approx(enemy.speed_scale(),1.0),"enemies outside the aura move normally")
func check_deadline() -> void:
	game.cycle=4;game.phase="rest";game.phase_clock=10;game.begin_wave()
	check(game.camps[0].overdue and game.camps[1].overdue,"wave four makes uncleared auras global")
	check(not game.camp_aura(Vector2(200,100)).is_empty(),"global aura reaches the whole map")
	check(game.overdue_camps()==2,"both camps are flagged in the HUD")
func check_raid() -> void:
	var before:=game.enemies.size()
	game.cycle=5;game.phase="rest";game.phase_clock=10;game.begin_wave()
	check(game.camps[0].raid_sent and game.camps[1].raid_sent,"wave five sends the raid")
	check(game.enemies.size()==before+6,"each camp sends three foxes")
func check_reward() -> void:
	var gold:=game.gold
	clear_camp(0)
	check(game.camps[0].cleared() and game.camps_cleared==1,"clearing removes the camp")
	check(game.gold-gold<=100,"camp no longer pays an automatic sixty gold")
	check(game.choice_queue==0,"camp no longer opens a free hero pick")
	await process_frame
	check(game.camp_reward_open,"clearing opens the reward choice")
	check(game.hud.modal.find_child("CampReward_token",true,false)!=null,"reward lists the doctrine token")
	check(game.hud.modal.find_child("CampReward_gold",true,false)!=null and game.hud.modal.find_child("CampReward_hero",true,false)!=null,"reward lists hero and gold")
	var before_gold:=game.gold
	check(game.choose_camp_reward(0,"gold") and game.gold==before_gold+100,"gold option pays one hundred")
	check(not game.camp_reward_open and not paused,"choosing closes the modal and resumes the run")
	check(not game.camps[0].covers(game.camps[0].point),"cleared camp stops projecting aura")
func check_token() -> void:
	clear_camp(1)
	await process_frame
	check(game.camp_reward_open,"the second camp also asks for a reward")
	check(game.l2_count()==0,"token card is honest about missing level two towers")
	check(game.choose_camp_reward(1,"token") and game.doctrine_tokens==1,"token option banks a free L3")
	await process_frame
	if game.choice_open:game.choose_perk(game.choices[0])
	game.gold=1000;game.cycle=5
	check(game.build_tower(2,"archer"),"a tower can be built for the token")
	var tower: ArenaTower=game.site_tower(2)
	check(tower.upgrade() and tower.level==2,"tower reaches level two with gold")
	var gold:=game.gold
	check(tower.upgrade("",true) and tower.level==3 and tower.awaiting_doctrine,"token pays for the level three step")
	check(game.gold==gold and game.doctrine_tokens==0,"token is spent instead of gold")
	check(game.choose_doctrine(tower.site_id,"sentinel") and tower.doctrine_id=="sentinel","the free upgrade still picks a doctrine")
