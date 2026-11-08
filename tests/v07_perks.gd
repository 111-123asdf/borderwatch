extends SceneTree
# v0.7 被动全量夹具：卡池完整性、修正器、联动、套装、进化门槛。
var checks:=0
var failures:=0
var game: ArenaGame
var hero: ArenaHero

func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error("PERK FAIL: "+message)

func _initialize() -> void:
	call_deferred("run")

func apply(key: String, count: int) -> void:
	for index in range(count):
		check(hero.apply_perk(key), "apply "+key)

func reset_perks() -> void:
	hero.perks.clear()
	hero.echo_clock=0.0;hero.enchant_clock=0.0;hero.overload_clock=0.0;hero.roll_boost_clock=0.0
	hero.war_cry=0.0;hero.combo_count=0;hero.death_saved=false
	hero.recompute()
	hero.health=hero.max_health

func run() -> void:
	# 数据完整性
	for card in ArenaPerks.CARDS:
		check(card.effects.size()==int(card.max), "effects count "+str(card.id))
		check(card.ranks.size()>=int(card.max), "rank text "+str(card.id))
	for link in ArenaPerks.LINKS:
		check(ArenaPerks.has_card(str(link.from)), "link from "+str(link.from))
		check(ArenaPerks.has_card(str(link.to)), "link to "+str(link.to))
	for item in ArenaPerks.SETS:
		if item.has("members"):
			for card_id in item.members: check(ArenaPerks.has_card(str(card_id)), "set member "+str(card_id))

	game=load("res://scenes/arena.tscn").instantiate();root.add_child(game);current_scene=game
	await process_frame
	game.progression=ArenaProgression.new("",false)
	game.start_run("knight","forest")
	hero=game.hero
	check(is_equal_approx(hero.damage_scale(),1.0),"base damage scale")
	check(not game._card_available("shadowstep"),"ranger card filtered for knight")
	check(game._card_available("shieldback"),"knight card available")

	# 锋芒 + 疾攻 + 联动
	apply("power",3)
	check(is_equal_approx(hero.mod("damage"),0.36),"power damage 36%")
	check(is_equal_approx(hero.attack_damage(),float(hero.data.damage)*1.36+1.0),"power flat damage")
	apply("rapid",3)
	check(is_equal_approx(hero.mod("attack_speed"),0.30),"rapid 30%")
	check(is_equal_approx(hero.damage_scale(),1.36),"power+rapid damage 36% (link is behavioral)")
	reset_perks()

	# 战意、坚韧、堡垒
	apply("battlewill",3)
	hero.health=hero.max_health*0.4
	check(hero.damage_scale()>1.29,"battlewill below half health")
	reset_perks()
	var base_hp:=hero.max_health
	apply("tough",3)
	check(hero.max_health>base_hp*1.3,"tough three ranks")
	check(hero.block_capacity()==3,"base block capacity")
	hero.apply_perk("fortress")
	check(hero.block_capacity()==4,"fortress adds block")
	reset_perks()

	# 专注、星辉、嗜血
	apply("focus",3)
	check(is_equal_approx(hero.cooldown_scale(),0.7),"focus three ranks")
	apply("starlight",3)
	check(is_equal_approx(hero.skill_scale(),1.69),"starlight 60% + focus conversion 9%")
	hero.health=100.0
	apply("lifesteal",2)
	hero.heal_on_kill()
	check(is_equal_approx(hero.health,108.0),"lifesteal rank 2")
	reset_perks()

	# 号令：工事、远见、共战
	apply("works",1)
	game.gold=1000
	check(game.build_tower(0,"archer"),"archer builds")
	check(is_equal_approx(float(game.gold),937.0),"works build discount")
	var tower: ArenaTower=game.site_tower(0)
	apply("works",1)
	check(tower.upgrade_price()==84,"works upgrade discount")
	apply("farsight",2)
	check(is_equal_approx(tower.attack_range(),240.0*1.16),"farsight range")
	apply("command",3)
	check(is_equal_approx(hero.mod("command_aura"),0.36),"command aura 36%")
	reset_perks()

	# 破防、灼烧
	apply("pierce",2)
	check(is_equal_approx(hero.armor_pen(),0.25),"pierce 25%")
	var brute:=game.spawn_enemy("brute",0,300)
	check(is_equal_approx(brute.take_hit(100.0,0,"hero"),70.0),"pierce vs armour")
	brute.queue_free()
	apply("burn",3)
	check(is_equal_approx(hero.mod("burn"),7.0),"burn rank 3")
	var fox:=game.spawn_enemy("fox",0,400)
	fox.ignite(10.0,3.0)
	fox._physics_process(1.0)
	check(fox.health<=fox.max_health-9.0,"burn ticks")
	reset_perks()

	# 三卡套装：锋刃
	apply("power",1);apply("rapid",1);apply("lifesteal",1)
	check(is_equal_approx(hero.mod("attack_speed"),0.16),"blade set adds 6% attack speed")
	reset_perks()

	# 37 条联动：两端各 1 级即生效
	for link in ArenaPerks.LINKS:
		if ArenaPerks.is_real_link(str(link.from),str(link.to)): continue
		hero.perks={str(link.from):1,str(link.to):1}
		hero.recompute()
		for stat in link.bonus:
			check(hero.mod(str(stat))>=float(link.bonus[stat])-0.0001,"link "+str(link.from)+"->"+str(link.to)+" "+str(stat))
	# 8 个套装
	for item in ArenaPerks.SETS:
		hero.perks={}
		if item.has("members"):
			for card_id in item.members: hero.perks[str(card_id)]=1
		elif item.has("cross"):
			var picked:=0
			for card in ArenaPerks.CARDS:
				if picked>=4: break
				if str(card.axis) in ["blade","star"]: hero.perks[str(card.id)]=1;picked+=1
		else:
			var count:=0
			for card in ArenaPerks.CARDS:
				if count>=int(item.get("need",3)): break
				if str(card.axis)==str(item.axis): hero.perks[str(card.id)]=1;count+=1
		hero.recompute()
		for stat in item.bonus:
			check(hero.mod(str(stat))>=float(item.bonus[stat])-0.0001,"set "+str(item.name)+" "+str(stat))

	# 行为联动：B1
	reset_perks()
	apply("rapid",1)
	check(hero.rapid_every()==5,"rapid baseline every 5")
	apply("power",1)
	check(hero.rapid_every()==4,"rapid+power link changes to every 4")
	reset_perks()
	apply("lifesteal",2);apply("tough",1)
	check(is_equal_approx(hero.mod("shield_cap"),45.0),"lifesteal+tough shield cap +50%")
	apply("combo",1)
	hero.overheal_shield=10.0
	check(hero.attack_damage()>float(hero.data.damage)*1.14,"lifesteal+combo shield damage")
	reset_perks()
	apply("starlight",1);apply("burn",1)
	var burn_fox:=game.spawn_enemy("fox",0,500)
	burn_fox.expose(3.0);burn_fox.ignite(10.0,3.0)
	burn_fox._physics_process(1.0)
	check(burn_fox.health<=burn_fox.max_health-11.0,"exposed burn +20%")
	reset_perks()
	apply("starlight",1);apply("pierce",2)
	var armoured:=game.spawn_enemy("brute",0,520)
	armoured.expose(3.0)
	var exposed_hit:=armoured.take_hit(100.0,0,"hero")
	check(is_equal_approx(exposed_hit,80.0),"exposed pierce extra 10%")
	reset_perks()
	apply("execute",1);apply("combo",1);apply("enchant",1)
	hero.combo_count=0;hero.note_kill(true)
	check(hero.combo_count==1,"execute kill feeds combo")
	check(is_equal_approx(hero.enchant_clock,3.0),"execute kill refreshes enchant")
	reset_perks()
	apply("chain",1)
	hero.action_target=Vector2(400,300)
	var chained:=game.spawn_enemy("fox",0,540)
	chained.position=hero.action_target+Vector2(20,0)
	var before_chain:=chained.health
	hero._chain_skill(100.0)
	check(chained.health<before_chain,"chain skill deals damage")
	apply("chain",1)
	var chain_two:=game.spawn_enemy("fox",0,600)
	chain_two.position=hero.action_target+Vector2(60,0)
	hero._chain_skill(100.0)
	check(chained.health<before_chain and chain_two.health<chain_two.max_health,"chain rank 2 bounces twice")
	reset_perks()
	apply("echo",1);apply("overload",1)
	hero.overload_clock=6.0;hero.echo_clock=3.0
	check(hero.attack_damage()>55.0,"echo doubled during overload")
	hero.overload_clock=0.0
	check(hero.attack_damage()<55.0,"echo normal without overload")
	reset_perks()
	apply("overload",1);apply("focus",1)
	hero.cancel_action()
	hero.cooldowns=[10.0,0.0]
	check(hero.cast(1,hero.position+Vector2(40,0)),"ultimate casts")
	check(is_equal_approx(hero.cooldowns[0],8.0),"overload+focus recovers 2s with focus")
	hero.cancel_action();reset_perks()

	# B2 塔侧行为
	reset_perks()
	apply("command",1)
	var b2_tower: ArenaTower=game.towers[0]
	hero.position=b2_tower.position+Vector2(10,0)
	check(is_equal_approx(hero.command_aura(b2_tower.position),0.12),"command aura near tower")
	hero.position=b2_tower.position+Vector2(400,0)
	check(hero.command_aura(b2_tower.position)==0.0,"command aura outside radius")
	apply("farsight",1)
	check(is_equal_approx(hero.command_radius(),280.0),"farsight link extends aura")
	apply("armament",1)
	check(b2_tower.armament_every()==4,"command+armament every 4")
	apply("warcredit",1)
	game.kills=30
	check(hero.warcredit_stacks()==3,"warcredit three stacks")
	hero.position=b2_tower.position+Vector2(10,0)
	check(is_equal_approx(hero.command_aura(b2_tower.position),0.18),"warcredit feeds command aura")
	apply("citywall",1)
	check(hero.citywall_reduction()>=0.03,"citywall per tower plus aura")
	apply("warmachine",1)
	b2_tower.streak_count=6
	check(is_equal_approx(b2_tower.warmachine_bonus(),0.4),"warmachine two stacks")
	reset_perks()
	apply("works",1);apply("spoils",1)
	game.gold=0;game.phase="rest";game.begin_wave()
	check(game.gold>=5,"works+spoils wave gold")

	# B3 英雄侧行为
	reset_perks()
	apply("power",3);apply("execute",1)
	check(is_equal_approx(hero.full_hp_threshold(),0.7),"execute link widens power full-hp window")
	var full_target:=game.spawn_enemy("fox",0,560)
	check(is_equal_approx(hero.attack_damage_against(full_target,100.0),115.0),"power full-hp bonus")
	full_target.health=full_target.max_health*0.6
	check(is_equal_approx(hero.attack_damage_against(full_target,100.0),100.0),"no full-hp bonus below threshold")
	reset_perks()
	apply("pierce",1);apply("execute",1)
	check(is_equal_approx(hero.execute_threshold(),0.30),"pierce link raises execute threshold")
	reset_perks()
	apply("unyield",1);apply("revive",1)
	hero.protection=0.0
	hero.take_hit(10000.0,0,true)
	check(hero.revive_halved,"unyield marks halved revive")
	hero.protection=0.0
	hero.take_hit(10000.0,0,true)
	check(hero.knocked_out and is_equal_approx(hero.revive_clock,5.5),"revive time halved after unyield")
	hero.knocked_out=false;hero.health=hero.max_health;hero.revive_clock=0
	reset_perks()
	apply("battlewill",1);apply("bloodrage",1)
	hero.health=hero.max_health*0.4
	check(hero.damage_scale()>1.39,"battlewill+bloodrage low-health synergy")
	reset_perks()
	apply("command",1);apply("oath",1)
	hero.war_cry=1.0
	hero.position=b2_tower.position+Vector2(10,0)
	check(is_equal_approx(hero.command_aura(b2_tower.position),0.24),"oath doubles command aura")
	hero.war_cry=0.0;reset_perks()
	apply("focus",1);apply("starlight",1)
	check(is_equal_approx(hero.skill_scale(),1.23),"focus converts to skill damage")
	apply("enchant",1);hero.enchant_clock=3.0
	var exposed_target:=game.spawn_enemy("fox",0,580)
	exposed_target.expose(3.0)
	check(is_equal_approx(hero.attack_damage_against(exposed_target,100.0),104.0),"enchant takes expose bonus")
	reset_perks()
	apply("piercearrow",1);apply("combo",1)
	hero.combo_count=0;hero.note_pierce_hit()
	check(hero.combo_count==1,"pierce hit feeds combo")

	# 进化门槛
	hero.perks={"power":3,"rapid":3};hero.recompute()
	check(game._card_available("sworddance"),"sworddance unlocked")
	check(not game._card_available("fortress"),"fortress still locked")
	hero.perks={"tough":3,"ironwall":3};hero.recompute()
	check(game._card_available("fortress"),"fortress unlocked")

	game.choice_queue=0;game.choice_open=false;game.running=false;game.audio.shutdown()
	await process_frame
	OS.delay_msec(120)
	game.queue_free()
	await process_frame
	print("V07 PERK CHECKS: %d, FAILURES: %d"%[checks,failures])
	quit(0 if failures==0 else 1)
