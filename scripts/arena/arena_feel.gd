class_name ArenaFeel
extends RefCounted
# One place owns presentation presets; real combat remains in ArenaCombat/ArenaHero.
var enabled := true
var unit_scale := 1.3
var trauma := 0.0
var shake_clock := 0.0
var last_heavy := -1000
var hit_serial := 0

func clear(game: Node2D) -> void:
	trauma=0.0;shake_clock=0.0;last_heavy=-1000
	if is_instance_valid(game.camera):game.camera.offset=Vector2.ZERO
	if is_instance_valid(game.hero):game.hero.visual.feedback.clear(game.hero.visual)
	for enemy in game.enemies:
		if is_instance_valid(enemy):enemy.visual.feedback.clear(enemy.visual)

func hit(game: Node2D, point: Vector2, damage: float, kind: int, killed: bool, source: String, target: Node2D, attack: String, incoming := Vector2.ZERO, shielded := false, condition_result: Dictionary={}) -> void:
	hit_serial+=1
	if not enabled:
		game.effect(point,21 if killed else 12,ArenaCombat.colour(kind),"hit",0.27 if killed else 0.16)
		if damage>0 and not condition_result.is_empty(): _number(game,point,damage,kind,target,condition_result)
		elif game.numbers.size()<24:game.numbers.append({"point":point,"text":str(int(ceil(damage))),"colour":ArenaCombat.colour(kind),"life":0.55})
		if damage>90:game.shake=1.4
		game.audio.play("kill" if killed else "hit",-12 if killed else -16);return
	if damage<=0:return
	var lord: bool=source=="hero" and game.hero.class_id=="lord"
	var hero_hit: bool=source=="hero"
	var heavy: bool=(lord and attack=="small" and kind==0) or (hero_hit and attack=="werewolf_claw" and game.hero.werewolf_beast_clock>0.0) or (hero_hit and attack=="pierce_arrow") or (hero_hit and bool(condition_result.get("crit",false))) or (source=="tower" and attack=="shell")
	var dir_vec := incoming.normalized()
	if dir_vec.is_zero_approx() and hero_hit:
		dir_vec = game.hero.position.direction_to(point)
	if attack == "burn_tick" and not killed:
		return
	if shielded:
		game.effect(point,18,Color("a0d6ef"),"ward_contact",0.16,dir_vec)
		game.audio.play("mage_hit",-21)
		return
	if is_instance_valid(target):
		target.visual.feedback.reduced=bool(game.campaign.data.reduced_motion)
		target.visual.feedback.impact(target.visual,heavy,dir_vec)
		target.visual.hit_pose(dir_vec)
	if attack == "tower_arrow" or attack == "soldier_strike" or (source == "tower" and attack == "pierce_arrow"):
		var contact_kind := "edge_contact" if attack == "soldier_strike" else "shaft_contact"
		game.effect(point, 22 if attack == "pierce_arrow" else (20 if attack == "tower_arrow" else 18), ArenaCombat.colour(kind), contact_kind, 0.22 if attack != "soldier_strike" else 0.18, dir_vec)
	elif hero_hit and attack in ["quick_arrow","short_sword","beast_strike","small","werewolf_claw","lord_thorn","druid_orb","healer_orb","healer_blessing"]:
		var colour:=Color("8be4ff") if attack=="werewolf_claw" else (Color("f06478") if attack in ["small","lord_thorn"] else (Color("f8a6c8") if attack in ["healer_orb","healer_blessing"] else (Color("7be088") if attack in ["druid_orb","beast_strike"] else Color("e9c08b"))))
		game.effect(point,19.0 if heavy else 12.0,colour,"shield_contact" if attack=="small" else "pixel_contact",0.16,dir_vec)
	elif hero_hit and kind==1:
		game.effect(point,25 if killed else 17,ArenaCombat.colour(kind),"magic_impact_painted",0.25,dir_vec)
	elif hero_hit and game.hero.class_id=="gunner":
		game.effect(point,22 if killed else 16,Color("7ce2ff"),"arrow_impact_painted",0.20,dir_vec)
	elif lord:
		game.effect(point,23 if killed else (20 if heavy else 14),ArenaCombat.colour(kind),"impact_painted",0.22 if killed else 0.16,dir_vec)
	elif source=="tower":
		if attack == "shell":
			game.effect(point,14.0,Color("f4c58d"),"edge_contact",0.15,dir_vec)
		elif attack in ["arc","beam","tower_frost","snare"]:
			var px_col := Color("5ce2ff") if attack == "arc" else (Color("ffe068") if attack == "beam" else (Color("9ce8ff") if attack == "tower_frost" else Color("f0be74")))
			game.effect(point, 18.0 if killed else 13.0, px_col, "pixel_contact", 0.18, dir_vec if not dir_vec.is_zero_approx() else Vector2.UP)
		else:
			game.effect(point,24 if killed else (20 if heavy else 16),ArenaCombat.colour(kind),"impact_painted" if kind==0 else "magic_impact_painted",0.24 if killed else 0.19,dir_vec)
	else:game.effect(point,12,ArenaCombat.colour(kind),"hit",0.16)
	if heavy:
		if lord and attack=="small" and game.hero.action=="small" and game.hero.action_released:game.hero.visual.feedback.freeze_after_release()
		var now:=Time.get_ticks_msec()
		if source=="hero" and now-last_heavy>=260:
			trauma=minf(1.0,trauma+0.52);last_heavy=now
			if Engine.time_scale<=2.0 and not bool(game.campaign.data.reduced_motion) and is_instance_valid(game.hero):
				game.hero.visual.feedback.stop_left=maxf(game.hero.visual.feedback.stop_left,0.032)
	elif bool(condition_result.get("crit",false)) and source=="hero":
		var now_c:=Time.get_ticks_msec()
		if now_c-last_heavy>=260:
			trauma=minf(1.0,trauma+0.24);last_heavy=now_c
	if source=="hero" and not bool(game.get_meta("hide_damage_numbers",false)):
		var crowded: bool=attack in ["small","werewolf_claw","healer_blessing","lord_thorn"]
		if not crowded or game.numbers.all(func(n):return n.point.distance_squared_to(point)>42.0*42.0 or float(n.get("merge",0.0))<=0.0):
			_number(game,point,damage,kind,target,condition_result)
	# A cannon shell already has one explosion sound at its impact point.
	if source == "tower" and attack == "shell":return
	var sound: String="kill" if killed else ("heavy_hit" if heavy else "hit")
	if hero_hit and kind==1:sound="mage_hit"
	elif hero_hit and game.hero.class_id=="gunner":sound="ranger_hit"
	game.audio.play(sound,-15 if source!="hero" else -9)
	if hero_hit and killed and sound!="kill":game.audio.play("kill",-15)

func _number(game: Node2D, point: Vector2, damage: float, kind: int, target: Node2D, condition_result: Dictionary) -> void:
	var id: int=target.get_instance_id() if is_instance_valid(target) else 0
	var critical := bool(condition_result.get("crit",false))
	var decorated := critical
	# Use simulation presentation time: opening a menu cannot silently consume a merge window.
	for item in game.numbers:
		if not decorated and int(item.get("target",-1))==id and int(item.get("kind",-1))==kind and float(item.get("merge",0.0))>0:
			item.amount+=damage;item.text=str(int(ceil(item.amount)));item.life=0.65;return
	if game.numbers.size()>=24:game.numbers.pop_front()
	var origin:=point+Vector2(-8,-18)
	for item in game.numbers:
		if float(item.life)>0.35 and origin.distance_to(item.point)<28:origin.y-=25
	var colour := Color("fff098") if critical else ArenaCombat.colour(kind)
	game.numbers.append({"point":origin,"text":str(int(ceil(damage))),"amount":damage,"target":id,"kind":kind,"merge":0.0 if decorated else 0.15,"colour":colour,"life":0.65,"duration":0.65,"critical":critical})

func tick(game: Node2D, delta: float) -> void:
	shake_clock+=delta;trauma=maxf(0.0,trauma-delta*3.0)
	if bool(game.campaign.data.reduced_motion):game.camera.offset=Vector2.ZERO;return
	if not enabled:
		game.shake=maxf(0,game.shake-delta*12);game.camera.offset=Vector2(sin(game.elapsed*71),cos(game.elapsed*49))*game.shake;return
	var power:=trauma*trauma
	game.camera.offset=Vector2(sin(shake_clock*35.0),sin(shake_clock*27.0+1.2))*6.0*power
