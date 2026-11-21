extends SceneTree
# Legal action driver: normal starting resources, actual enemies/rewards/timers.
# No mutation of HP/gold/damage/cooldowns/wave timing/enemy deaths.
var game: ArenaGame
var decision:=0.0
var passed:=false
var hero_id:="knight"
var stage:="forest"
var last_wave:=0
var casts:=0
var knockouts:=0
var was_down:=false
var timer:=0.0
var stopping:=false
var hero_level:=1
var preview:=false
var defense_rule:=""
var roster:=PackedStringArray()
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--preview":preview=true
		if arg.begins_with("--towers="): roster=arg.trim_prefix("--towers=").split(",")
		if arg.begins_with("--hero="):hero_id=arg.trim_prefix("--hero=")
		if arg.begins_with("--level="):stage=arg.trim_prefix("--level=")
		if arg.begins_with("--hero-level="):hero_level=int(arg.trim_prefix("--hero-level="))
		if arg.begins_with("--rule="):defense_rule=arg.trim_prefix("--rule=")
	if hero_id not in ArenaDefinitions.HERO_IDS or stage not in ArenaLevelCatalog.IDS:push_error("Invalid playthrough arguments");quit(1);return
	game=load("res://scenes/arena.tscn").instantiate();game.campaign=ArenaCampaign.new("",false)
	if not roster.is_empty() and not game.campaign.equip_towers(Array(roster)):
		push_error("Invalid tower roster");quit(1);return
	# Optional pre-existing hero-level profile is a labelled meta fixture. Run resources stay normal.
	game.campaign.data.levels[hero_id]=clampi(hero_level,1,5)
	root.add_child(game);current_scene=game;await process_frame
	game.rng.seed=60406;game.start_run(hero_id,stage);Input.action_press("shoot")
	if preview:
		var caption:=Label.new();caption.position=Vector2(30,810);caption.size=Vector2(1500,70);caption.text=game.hero.data.name+"首关前三波 · 自动操作实战摘录\n正常局内资源 · 永久5级既有档夹具 · 非真人试玩";caption.add_theme_font_size_override("font_size",25);caption.add_theme_color_override("font_shadow_color",Color.BLACK);caption.add_theme_constant_override("shadow_offset_y",2);game.hud.root.add_child(caption)
func release_and_hold() -> void:
	Input.action_release("shoot")
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=false;game._input(event)
	Input.action_press("shoot")
func _process(delta: float) -> bool:
	if stopping or game==null or not game.started:return false
	timer+=delta
	if preview and game.cycle>=4:
		print("PREVIEW FIRST THREE WAVES PASSED: ",JSON.stringify(game.wave_log)," casts=",casts)
		passed=game.core_health>0 and casts>0;stopping=true;finish.call_deferred();return false
	if not game.rule_offers.is_empty():
		var pick:=defense_rule
		if pick=="draw" or (not pick.is_empty() and not game.rule_offers.any(func(c): return c.id==defense_rule)):
			if pick!="draw" and not ArenaRuleDeck.BLESSINGS.has(pick):
				push_error("Unknown defense rule: "+pick)
				stopping=true;finish.call_deferred();return false
			pick=game.rule_offers[0].id
		if not game.choose_defense_rule(pick):
			push_error("Invalid defense rule for automated run: "+pick)
			stopping=true;finish.call_deferred();return false
		if not pick.is_empty():
			print("RULE ",game.cycle," ",pick," + ",game.selected_defense_cards.back().curse_id)
			for order in ["lure","bounty","chest","gate","bridge"]:
				game.orders.command(order)
		release_and_hold()
		return false
	if game.choice_open:
		var priorities: Array=[]
		for card in (ArenaKeystones.LIST if game.keystone_mode else ArenaPerks.CARDS):
			var only:=str(card.get("hero",""))
			if only=="" or only==hero_id: priorities.append(str(card.id))
		for key in priorities:
			if key in game.choices:game.choose_perk(key);release_and_hold();break
		return false
	if game.game_over:
		print("TELEMETRY ",JSON.stringify(game.telemetry()))
		print("NORMAL ",hero_id," ",stage," won=",game.victory," wave=",game.cycle," kills=",game.kills," core=",game.core_health," l3=",l3_count()," doctrines=",doctrine_count()," casts=",casts," KO=",knockouts," simulated seconds=",snappedf(game.elapsed,0.1)," damage=",game.damage_stats)
		passed=game.victory and game.cycle==8 and game.built>=4 and (casts>0 if hero_level>=2 else casts==0)
		if not roster.is_empty():
			var built_kinds:=game.towers.map(func(t): return t.kind)
			print("DEPLOYED TOWERS ",built_kinds)
			passed=passed and Array(roster).all(func(kind): return kind in built_kinds)
		if defense_rule not in ["","draw"]: passed=passed and defense_rule in game.picked_rules
		stopping=true;finish.call_deferred();return false
	if timer>1100:push_error("NORMAL TIMEOUT "+hero_id+" "+stage);stopping=true;finish.call_deferred();return false
	decision-=delta
	if decision>0:return false
	decision=0.25
	if game.hero.knocked_out and not was_down:knockouts+=1
	was_down=game.hero.knocked_out
	if last_wave!=game.cycle:print("WAVE ",game.cycle," core=",game.core_health," gold=",game.gold," elapsed=",int(game.elapsed));last_wave=game.cycle
	manage_towers()
	if game.keystone_mode:
		if game.resonance>=100.0:
			var pack:=game.nearest_enemy(game.level_definition.core,650)
			if pack!=null:game.cast_resonance(pack.position)
		if not game.bridge_sealed and game.bridge_cooldown<=0.0:
			for unit in game.enemies:
				if is_instance_valid(unit) and not unit.dead and unit.route_id==1 and unit.bridge_branch=="":game.trigger_bridge_gate();break
	if game.hero.knocked_out:return false
	var target: ArenaEnemy
	var greatest:=-INF
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_guard:continue
		var score: float=enemy.progress/game.enemy_road(enemy).get_baked_length()
		if enemy.kind=="moth":score+=0.12
		if score>greatest:greatest=score;target=enemy
	if target==null:
		for enemy in game.enemies:
			if not is_instance_valid(enemy) or enemy.dead or not enemy.is_guard:continue
			if target==null or game.hero.position.distance_to(enemy.position)<game.hero.position.distance_to(target.position):target=enemy
	if target!=null:
		var spacing: float=28 if hero_id=="knight" else 150
		var offset: Vector2=(game.hero.position-target.position).normalized()
		if offset.length()<0.1:offset=Vector2.RIGHT
		var destination: Vector2=target.position+offset*spacing
		if game.hero.health<game.hero.max_health*0.27:
			destination=game.level_definition.hero_spawn+Vector2(-50,75)
		if game.hero.position.distance_to(destination)>35:game.hero.command_move(destination)
		if game.hero.position.distance_to(target.position)<(150 if hero_id=="knight" else 310):
			if game.hero.cooldowns[0]<=0 and game.hero.cast(0,target.position):casts+=1
			if game.hero.cooldowns[1]<=0 and game.hero.cast(1,target.position):casts+=1
	elif game.hero.position.distance_to(game.level_definition.hero_spawn)>80:game.hero.command_move(game.level_definition.hero_spawn)
	if game.phase=="rest" and game.hero.health>game.hero.max_health*0.85:
		game.request_wave()
	return false
func l3_count() -> int:
	var total:=0
	for tower in game.towers:
		if is_instance_valid(tower) and tower.level>=3:total+=1
	return total
func doctrine_count() -> int:
	var total:=0
	for tower in game.towers:
		if is_instance_valid(tower) and tower.doctrine_id!="":total+=1
	return total
func manage_towers() -> void:
	for tower in game.towers:
		if tower.awaiting_doctrine:
			var options: Array=ArenaDoctrines.for_tower(tower.kind)
			if not options.is_empty():tower.choose_doctrine(str(options[(tower.site_id+game.cycle)%options.size()].id))
			return
	if not game.can_change_towers(): return
	var order: Array=[0,1,3,2,4,5,6,7] if stage=="forest" else [0,5,1,6,3,7,4,8,2,9]
	var plan: Array=["archer","barracks","mage","archer","cannon","mage","archer","cannon"] if stage=="forest" else ["archer","mage","mage","barracks","archer","archer","cannon","mage","cannon","archer"]
	if stage=="ruins":
		order=[5,8,11,3,9,12,4,2,13,1,7,0,6,14,16,17,10,15]
		plan=["archer","archer","cannon","mage","archer","mage","archer","barracks","barracks","archer","mage","mage","cannon","archer","mage","mage","archer","archer"]
	if game.cycle>=6:
		for index in order:
			if game.site_locked(index) and game.gold>=game.unlock_price(index)+120:game.unlock_site(index);return
	for index in order:
		var kind: String=plan[index] if roster.is_empty() else str(roster[order.find(index)%roster.size()])
		if not game.site_locked(index) and game.site_tower(index)==null and kind in game.available_towers() and game.gold>=ArenaDefinitions.TOWERS[kind].cost:game.build_tower(index,kind);return
	for tower in game.towers:
		if tower.project_level==0 and tower.level<3 and game.gold>=tower.upgrade_price():tower.upgrade();return
	for tower in game.towers:
		if tower.doctrine_id!="" and not tower.awaiting_doctrine:
			for index in range(2):
				if tower.branch_rank(index)<3 and game.gold>=tower.branch_price(index):tower.upgrade_branch(index);return
func finish() -> void:
	Input.action_release("shoot");paused=false;game.running=false;game.audio.shutdown();await process_frame;OS.delay_msec(150);game.queue_free();await process_frame;quit(0 if passed else 1)
