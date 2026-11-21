extends SceneTree

var checks := 0
var failures := 0
var game: ArenaGame
var rng := RandomNumberGenerator.new()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V020 CONDITIONS FAIL: " + message)

func _initialize() -> void:
	run.call_deferred()

func bonus(state: ArenaConditions, enemy: ArenaEnemy, hp := 320.0, kind := ArenaCombat.Type.PHYSICAL) -> float:
	return float(state.resolve_hit(enemy,kind,hp,320.0,state.attack_context(),rng).bonus)

func check_bonus(state: ArenaConditions, enemy: ArenaEnemy, expected: float, message: String, hp := 320.0, kind := ArenaCombat.Type.PHYSICAL) -> void:
	check(is_equal_approx(bonus(state,enemy,hp,kind),expected),message)

func run() -> void:
	rng.seed = 2020
	check(ArenaConditions.CARDS.size()==20,"first release has 20 cards")
	var draws := {"common":0,"rare":0,"epic":0}
	for iteration in range(3000):
		var ids := ArenaConditions.draw(rng,{"glass":1},1)
		draws[ArenaConditions.CARDS[ids[0]].rarity] += 1
	check(absi(draws.common-1800)<120 and absi(draws.rare-900)<120 and absi(draws.epic-300)<85,"rarity weights apply before selecting an individual card")
	check("glass" not in ArenaConditions.draw(rng,{"glass":2},20),"max-rank cards are excluded")

	var enemy := ArenaEnemy.new()
	enemy.max_health = 100.0
	enemy.data = ArenaDefinitions.enemy("fox")
	var ranks := {"hunter":1}
	var state := ArenaConditions.new(ranks)
	enemy.health = 99.0
	check_bonus(state,enemy,0.20,"hunter activates at 99%")
	enemy.health = 98.9
	check_bonus(state,enemy,0.0,"hunter inactive below 99%")
	ranks.clear()
	ranks.execute = 1
	enemy.health = 30.0
	check_bonus(state,enemy,0.35,"execute rank one includes 30%")
	enemy.health = 30.1
	check_bonus(state,enemy,0.0,"execute rank one excludes 30.1%")
	ranks.execute = 2
	enemy.health = 40.0
	check_bonus(state,enemy,0.40,"execute rank two includes 40% and uses the first-round 40% damage bonus")
	enemy.health = 40.1
	check_bonus(state,enemy,0.0,"execute rank two excludes 40.1%")
	ranks.clear()
	ranks.desperate = 1
	check_bonus(state,enemy,0.0,"desperate excludes exactly 40%",128.0)
	check_bonus(state,enemy,0.30,"desperate activates below 40%",127.9)
	ranks.desperate = 2
	check_bonus(state,enemy,0.0,"desperate rank two excludes exactly 50%",160.0)
	check_bonus(state,enemy,0.40,"desperate rank two activates below 50%",159.9)
	ranks.clear()
	ranks.bloodprice = 1
	check_bonus(state,enemy,0.0,"bloodprice at full health",320.0)
	check_bonus(state,enemy,0.03,"bloodprice at exactly one lost step",288.0)
	check_bonus(state,enemy,0.0,"bloodprice below one lost step",289.0)
	check_bonus(state,enemy,0.27,"bloodprice at nine lost steps",32.0)

	ranks.clear()
	ranks.stillwater = 1
	state.update_movement(1.49,0.0,false)
	check(not state.resolve_hit(enemy,0,320.0,320.0,state.attack_context(),rng).icons.has("stillwater"),"stillwater before 1.5s")
	state.update_movement(0.01,0.0,false)
	check(state.resolve_hit(enemy,0,320.0,320.0,state.attack_context(),rng).icons.has("stillwater"),"stillwater at 1.5s")
	state.update_movement(0.2,520.0,true)
	check(state.still_time==0.0 and state.move_time==0.0,"roll clears stillness and contributes no movement time")
	ranks.clear()
	ranks.snapstop = 1
	state.update_movement(0.3,120.0,false)
	state.update_movement(0.01,0.0,false)
	state.update_movement(0.19,0.0,false)
	check(state.snapstop_ready(),"snapstop available after 0.19s")
	var started_in_window := state.attack_context()
	state.update_movement(0.02,0.0,false)
	check(not state.snapstop_ready(),"snapstop unavailable after 0.21s")
	check(is_equal_approx(state.resolve_hit(enemy,0,320.0,320.0,started_in_window,rng).bonus,0.35),"an action begun in the window retains its priming until impact")
	check(is_zero_approx(state.resolve_hit(enemy,0,320.0,320.0,started_in_window,rng).bonus),"a multi-hit action only consumes the charge once")
	state.update_movement(0.3,120.0,false,true)
	state.update_movement(0.1,0.0,false,true,true)
	check(not state.snapstop_ready(),"a rooted skill while movement is held does not trigger snapstop")
	state.update_movement(0.1,0.0,false,true)
	check(not state.snapstop_ready(),"a wall while movement is held does not trigger snapstop")
	state.update_movement(0.3,120.0,false,true)
	state.update_movement(0.01,0.0,false)
	check(state.snapstop_ready(),"voluntarily releasing movement still triggers snapstop")
	ranks.clear()
	ranks.rapids = 1
	state.update_movement(2.0,120.0,false)
	state.update_movement(4.0,0.0,false)
	check(state.rapids_ready(),"rapids persists after stopping")
	check_bonus(state,enemy,0.30,"rapids applies to the next connected hit")
	check(not state.rapids_ready(),"rapids readiness clears after a hit")
	check_bonus(state,enemy,0.0,"rapids is consumed")

	ranks.clear()
	ranks.lonewolf = 1
	ranks.phalanx = 1
	var soldier_a := ArenaSoldier.new()
	var soldier_b := ArenaSoldier.new()
	soldier_a.position.x = 119.0
	soldier_b.position.x = 119.0
	state.scan_soldiers(Vector2.ZERO,[soldier_a,soldier_b],0.1)
	check_bonus(state,enemy,0.0,"living soldiers at 119 suppress lonewolf")
	check(is_equal_approx(state.reduction(),0.12),"two nearby soldiers grant the full phalanx reduction")
	soldier_a.position.x = 121.0
	soldier_b.dead = true
	state.scan_soldiers(Vector2.ZERO,[soldier_a,soldier_b],0.1)
	check_bonus(state,enemy,0.15,"distant and fallen soldiers do not suppress lonewolf")
	check(is_equal_approx(state.reduction(),0.05),"phalanx still grants its fallback")
	soldier_a.free()
	soldier_b.free()
	ranks.clear()
	ranks.breaker = 1
	enemy.data = ArenaDefinitions.enemy("brute")
	check_bonus(state,enemy,0.0,"mage does not gain breaker versus armour",320.0,ArenaCombat.Type.MAGIC)
	check_bonus(state,enemy,0.20,"knight gains breaker versus armour")
	enemy.data = ArenaDefinitions.enemy("wisp")
	check_bonus(state,enemy,0.20,"mage gains breaker versus resistance",320.0,ArenaCombat.Type.MAGIC)
	check_bonus(state,enemy,0.0,"knight does not gain breaker versus resistance")
	ranks.clear()
	ranks.slayer = 1
	enemy.kind = "colossus"
	check_bonus(state,enemy,0.20,"colossus counts as a boss")
	enemy.kind = "fox"
	check_bonus(state,enemy,-0.08,"slayer trades away damage against ordinary enemies")
	ranks.clear()
	ranks.merge({"desperate":2,"bloodprice":2,"glass":2,"lonewolf":2})
	var capped := state.resolve_hit(enemy,0,32.0,320.0,state.attack_context(),rng)
	check(is_equal_approx(capped.multiplier,1.8) and capped.capped,"138% additive bonus caps at 80% and requests feedback")
	ranks.clear()
	ranks.merge({"gamble":2,"stillwater":2,"opener":2})
	enemy.health = 100.0
	var reference := RandomNumberGenerator.new()
	reference.seed = 691
	rng.seed = 691
	for index in range(64):
		var critical := reference.randf()<0.40
		var result := state.resolve_hit(enemy,0,320.0,320.0,state.attack_context(),rng)
		check(result.crit==critical and is_equal_approx(result.multiplier,2.0 if critical else 0.8),"critical cap and gamble damage branches")
	enemy.free()

	game=load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	check(game.condition_lab and game.action_controls,"CLI enables the experimental card pool and move-and-attack controls")
	check(game.campaign.path==ArenaCampaign.CONDITION_PATH,"condition lab uses an isolated profile")
	game.campaign.data.levels.ranger=5
	game.start_run("ranger","forest")
	await process_frame
	var hero := game.hero
	var victim := game.spawn_enemy("fox",0)
	victim.set_physics_process(false)
	victim.position = hero.position+Vector2(140,-30)
	victim.max_health = 1000.0
	victim.health = 1000.0
	game.passive_ranks.hunter=1
	check(hero.begin_attack(victim),"ranged attack starts on the normal release path")
	hero.release_action()
	victim.health = 985.0
	var start_hp := victim.health
	var shot_base := hero.attack_damage()
	for frame in range(35):
		await physics_frame
		if victim.health<start_hp: break
	check(is_equal_approx(start_hp-victim.health,shot_base),"projectile evaluates target health at impact")
	var direct := victim.take_hit(100.0,0,"tower")
	check(is_equal_approx(direct,100.0),"tower damage bypasses hero card bonuses")
	victim.health = victim.max_health
	hero.cancel_action()
	check(hero.cast(1,victim.position),"ranger ultimate starts on the normal skill path")
	hero.release_action()
	var initial_hp := victim.health
	for frame in range(45):
		await physics_frame
		if victim.health<initial_hp: break
	check(is_equal_approx(initial_hp-victim.health,36.0),"delayed ultimate also uses condition damage")
	check(game.numbers.any(func(item): return "hunter" in item.get("icons",[])),"condition damage adds a matching card icon to the hit number")
	for attack in game.delayed: attack.life=100.0

	hero.health=hero.max_health*0.55
	var before_glass := hero.max_health
	game.passive_ranks.glass=1
	hero.recompute()
	check(is_equal_approx(hero.max_health,before_glass*0.75) and is_equal_approx(hero.health/hero.max_health,0.55),"glass preserves current health percentage")
	hero.add_xp(1120)
	await process_frame
	check(game.choice_queue==10 and game.choice_open and paused,"levels 2 through 11 queue ten paused choices")
	var original := game.choices.duplicate()
	check(game.reroll_passives() and not game.reroll_passives(),"reroll works once per run")
	check(game.choices.size()==3 and not game.choices.any(func(id): return id in original),"reroll presents three new cards")
	var first := game.choices[0]
	var rank_before := game.passive_rank(first)
	var key := InputEventKey.new()
	key.pressed=true
	key.keycode=KEY_1
	root.push_input(key)
	check(game.passive_rank(first)==rank_before+1 and game.choice_queue==9,"number key selects and advances the queue")
	check(not game.suppress_primary,"choosing by keyboard leaves the first new attack available")
	await process_frame
	Input.action_press("shoot")
	check(game.choose_passive(game.choices[0]) and game.suppress_primary,"a held attack stays suppressed when the choice closes")
	Input.action_release("shoot")
	var mouse_release:=InputEventMouseButton.new()
	mouse_release.button_index=MOUSE_BUTTON_LEFT
	game._input(mouse_release)
	check(not game.suppress_primary,"releasing the consumed press restores attacks")
	while game.choice_queue>0:
		await process_frame
		check(game.choice_open,"queued choices stay available until selected")
		if not game.choice_open: break
		game.choose_passive(game.choices[0])
	game.hud.show_pause()
	var pause_labels:=game.hud.modal.find_children("*","Label",true,false)
	check(pause_labels.any(func(item): return item.text.contains("局内 2–11 级")),"pause shows the condition growth rules")
	check(pause_labels.any(func(item): return item.text.contains(ArenaConditions.CARDS[first].name) and item.text.contains("阶")),"pause shows an owned card and its rank")
	game.hud.resume()

	hero.lunge_left=0.1
	hero.cancel_action()
	check(hero.lunge_left==0.0,"cancelling an attack also cancels its lunge")
	hero.position=Vector2(16,450)
	hero.roll_direction=Vector2.LEFT
	hero.rolling=0.02
	hero._physics_process(0.03)
	check(hero.position.x>=15.0 and hero.velocity==Vector2.ZERO,"rolling stays in bounds and clears leftover movement")
	var boss:=game.spawn_enemy("moth",0)
	boss.position=hero.position+Vector2(30,0)
	hero._trigger_level_burst()
	check(boss.stun==0.0,"level-up burst does not stun a boss")
	hero.protection=0.0
	hero.take_hit(9999.0,ArenaCombat.Type.PHYSICAL)
	hero.add_xp(hero.xp_target)
	check(hero.knocked_out and is_zero_approx(hero.health),"experience gained while down does not restore health before respawn")
	game.remove_enemy(victim)
	game.remove_enemy(boss)
	game.phase="spawn"
	game.cycle=8
	game.delayed.clear()
	game.delayed_attack(hero.position,120.0,100.0,0,"enemy",0.05)
	game._physics_process(0.1)
	check(game.game_over and game.victory and is_equal_approx(game.delayed[0].life,0.05),"victory ends battle processing immediately")
	check(bool(game.settlement.ok) and FileAccess.file_exists(ArenaCampaign.CONDITION_PATH),"real settlement persists to the experimental save")
	var result_modal:=game.hud.modal
	key.keycode=KEY_H
	root.push_input(key)
	check(game.hud.modal==result_modal,"H cannot dismiss the result and leave the game stuck")
	game.audio.shutdown()
	await process_frame
	OS.delay_msec(150)
	game.queue_free()
	await process_frame
	paused=false
	print("V020 CONDITIONS CHECKS: %d, FAILURES: %d" % [checks,failures])
	quit(0 if failures==0 else 1)
