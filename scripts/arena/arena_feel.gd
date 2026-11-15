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

func hit(game: Node2D, point: Vector2, damage: float, kind: int, killed: bool, source: String, target: Node2D, attack: String) -> void:
	hit_serial+=1
	if not enabled:
		game.effect(point,21 if killed else 12,ArenaCombat.colour(kind),"hit",0.27 if killed else 0.16)
		if game.numbers.size()<24:game.numbers.append({"point":point,"text":str(int(ceil(damage))),"colour":ArenaCombat.colour(kind),"life":0.55})
		if damage>90:game.shake=1.4
		game.audio.play("kill" if killed else "hit",-12 if killed else -16);return
	if damage<=0:return
	var knight: bool=source=="hero" and game.hero.class_id=="knight"
	var hero_hit: bool=source=="hero"
	var heavy: bool=(knight and attack=="small" and kind==0) or (hero_hit and attack=="meteor" and kind==1)
	if is_instance_valid(target) and hero_hit:
		target.visual.feedback.reduced=bool(game.campaign.data.reduced_motion)
		target.visual.feedback.impact(target.visual,heavy)
	if hero_hit and kind==1:
		game.effect(point,25 if killed else 17,ArenaCombat.colour(kind),"magic_impact_painted",0.25)
	elif hero_hit and game.hero.class_id=="ranger":
		game.effect(point,22 if killed else 16,ArenaCombat.colour(kind),"arrow_impact_painted",0.20)
	elif knight:
		game.effect(point,23 if killed else (20 if heavy else 14),ArenaCombat.colour(kind),"impact_painted",0.22 if killed else 0.16)
	else:game.effect(point,12,ArenaCombat.colour(kind),"hit",0.16)
	if heavy:
		if knight and attack=="small" and game.hero.action=="small" and game.hero.action_released:game.hero.visual.feedback.freeze_after_release()
		var now:=Time.get_ticks_msec()
		if now-last_heavy>=400:trauma=minf(1.0,trauma+0.55);last_heavy=now
	if source=="hero":_number(game,point,damage,kind,target)
	var sound: String="kill" if killed else ("heavy_hit" if heavy else "hit")
	if hero_hit and kind==1:sound="mage_hit"
	elif hero_hit and game.hero.class_id=="ranger":sound="ranger_hit"
	game.audio.play(sound,-15 if source!="hero" else -9)
	if hero_hit and killed and sound!="kill":game.audio.play("kill",-15)

func _number(game: Node2D, point: Vector2, damage: float, kind: int, target: Node2D) -> void:
	var id: int=target.get_instance_id() if is_instance_valid(target) else 0
	# Use simulation presentation time: opening a menu cannot silently consume a merge window.
	for item in game.numbers:
		if int(item.get("target",-1))==id and int(item.get("kind",-1))==kind and float(item.get("merge",0.0))>0:
			item.amount+=damage;item.text=str(int(ceil(item.amount)));item.life=0.65;return
	if game.numbers.size()>=24:game.numbers.pop_front()
	var origin:=point+Vector2(-8,-18)
	for item in game.numbers:
		if float(item.life)>0.35 and origin.distance_to(item.point)<28:origin.y-=25
	game.numbers.append({"point":origin,"text":str(int(ceil(damage))),"amount":damage,"target":id,"kind":kind,"merge":0.15,"colour":ArenaCombat.colour(kind),"life":0.65,"duration":0.65})

func tick(game: Node2D, delta: float) -> void:
	shake_clock+=delta;trauma=maxf(0.0,trauma-delta*3.0)
	if bool(game.campaign.data.reduced_motion):game.camera.offset=Vector2.ZERO;return
	if not enabled:
		game.shake=maxf(0,game.shake-delta*12);game.camera.offset=Vector2(sin(game.elapsed*71),cos(game.elapsed*49))*game.shake;return
	var power:=trauma*trauma
	game.camera.offset=Vector2(sin(shake_clock*35.0),sin(shake_clock*27.0+1.2))*6.0*power
