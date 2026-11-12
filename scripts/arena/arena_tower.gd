class_name ArenaTower
extends Node2D
const MAX_LEVEL:=3
var game: Node2D
var kind: String="archer"
var site_id:=0
var level:=1
var data: Dictionary={}
var destroyed:=false
var doctrine_id: String=""
var doctrine_data: Dictionary={}
var awaiting_doctrine:=false
var attack_clock:=0.0
var fire_clock:=0.0
var rally_point:=Vector2.ZERO
var target_mode: String="first"
var troops: Array=[]
var body: Sprite2D
var shot_count:=0
var streak_target: Node2D
var streak_count:=0
static var art_cache: Dictionary={}
func _ready() -> void:
	data=ArenaDefinitions.tower(kind);body=Sprite2D.new();body.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;add_child(body);refresh_art()
	var obstacle:=StaticBody2D.new();obstacle.collision_layer=1;obstacle.collision_mask=2
	var collision:=CollisionShape2D.new();var circle:=CircleShape2D.new();circle.radius=25;collision.shape=circle;obstacle.add_child(collision);add_child(obstacle)
	var anchor: Vector2=game.nearest_road(position).point
	rally_point=anchor
	if kind=="barracks":
		for index in range(3):
			var soldier:=ArenaSoldier.new();soldier.game=game;soldier.tower=self;soldier.slot=index;soldier.position=anchor+Vector2((index-1)*20,8+index%2*15)
			game.actors.add_child(soldier);game.soldiers.append(soldier);troops.append(soldier)
func refresh_art() -> void:
	var key: String=kind+str(level)
	if not art_cache.has(key):
		var path: String="res://assets/v06/towers.png"
		if ResourceLoader.exists(path):
			var atlas:=AtlasTexture.new();var sheet: Texture2D=load(path);atlas.atlas=sheet
			var column: int=ArenaDefinitions.TOWER_IDS.find(kind)
			atlas.region=Rect2(column*sheet.get_width()/4.0,(level-1)*sheet.get_height()/3.0,sheet.get_width()/4.0,sheet.get_height()/3.0)
			art_cache[key]=atlas
	if art_cache.has(key):
		body.texture=art_cache[key]
		var width: float=(111.0+level*7) if kind in ["archer","mage"] else (120.0+level*11)
		body.scale=Vector2.ONE*width/body.texture.get_width();body.position.y=-body.texture.get_height()*body.scale.y*ArenaArtAnchors.offset_for("tower_"+kind+"_"+str(level))
func upgrade_price() -> int:
	var base:=int(data.cost)*(level+1)/2+35
	return int(float(base)*(1.0-clampf(game.hero.mod("tower_upgrade"),0.0,0.5)))
func attack_range() -> float: return (float(data.reach)+(level-1)*16)*(1.0+game.hero.mod("tower_range"))*doc_mod("range_mult",1.0)
func reload_time() -> float:
	return float(data.interval)/(1.0+0.14*(level-1))/(1.0+game.hero.mod("tower_speed"))*doc_mod("interval_mult",1.0)
func shot_power() -> float: return float(data.damage)*(1.0+0.6*(level-1))*game.support_scale(position)
func base_power() -> float: return float(data.damage)*(1.0+0.6*(level-1))
func splash_radius() -> float: return (64+(level-1)*12)*doc_mod("splash_mult",1.0)
func doc_mod(key: String,fallback := 0.0) -> float:
	if doctrine_data.is_empty():return fallback
	var effects: Dictionary=doctrine_data.get("effects",{})
	return float(effects[key]) if effects.has(key) else fallback
func forced_target() -> String: return str(doctrine_data.get("effects",{}).get("target",""))
func penetration() -> float: return doc_mod("armour_pen") if int(data.type)==0 else doc_mod("resist_pen")
func doctrine_multiplier(enemy: Node2D) -> float:
	var result:=doc_mod("damage_mult",1.0)
	if doc_mod("bonus_armour")>0.0 and float(enemy.data.armour)>=ArenaDoctrines.HEAVY_ARMOUR:result*=1.0+doc_mod("bonus_armour")
	if doc_mod("bonus_resist")>0.0 and float(enemy.data.resistance)>=ArenaDoctrines.HIGH_RESIST:result*=1.0+doc_mod("bonus_resist")
	if doc_mod("bonus_elite")>0.0 and (enemy.elite or str(enemy.kind)=="moth"):result*=1.0+doc_mod("bonus_elite")
	return result
func upgrade(doctrine := "",use_token := false) -> bool:
	if level>=3 or destroyed:return false
	var token: bool=use_token and level==2 and int(game.doctrine_tokens)>0
	if not token and game.gold<upgrade_price():return false
	if token:game.doctrine_tokens-=1
	else:game.gold-=upgrade_price()
	level+=1;refresh_art()
	if level==3 and doctrine_id=="":
		var options: Array=ArenaDoctrines.for_tower(kind)
		if not options.is_empty():
			if doctrine!="" and _apply_doctrine(doctrine):awaiting_doctrine=false
			else:awaiting_doctrine=true;game.pending_doctrine_site=site_id
	for soldier in troops:
		if is_instance_valid(soldier):soldier.refresh_stats()
	game.effect(position,65,Color("f4d28b"),"upgrade",0.55);game.audio.play("tower")
	if is_instance_valid(game.hud):game.hud.refresh_context();game.hud.refresh_tokens()
	return true
func choose_doctrine(id: String) -> bool:
	if not awaiting_doctrine or destroyed:return false
	if not _apply_doctrine(id):return false
	awaiting_doctrine=false;game.pending_doctrine_site=-1
	game.effect(position,72,Color("9fd8f0"),"upgrade",0.7)
	return true
func _apply_doctrine(id: String) -> bool:
	var entry: Dictionary=ArenaDoctrines.by_id(id)
	if entry.is_empty() or str(entry.tower)!=kind or doctrine_id!="":return false
	doctrine_id=id;doctrine_data=entry
	var forced:=str(entry.effects.get("target",""))
	if forced!="":target_mode=forced
	if kind=="barracks":sync_troops()
	return true
func sync_troops() -> void:
	if kind!="barracks":return
	troops=troops.filter(func(soldier):return is_instance_valid(soldier))
	var target:=maxi(1,int(doc_mod("soldier_count",3)))
	while troops.size()>target:
		var soldier: ArenaSoldier=troops.pop_back()
		game.blocking.release(soldier);game.soldiers.erase(soldier);soldier.queue_free()
	while troops.size()<target:
		var soldier:=ArenaSoldier.new();soldier.game=game;soldier.tower=self;soldier.position=rally_point
		game.actors.add_child(soldier);game.soldiers.append(soldier);troops.append(soldier)
	for index in range(troops.size()):troops[index].slot=index
	for soldier in troops:soldier.refresh_stats()
func sell() -> bool:
	if destroyed:return false
	destroyed=true;game.gold+=int((float(data.cost)*0.6+float(level-1)*data.cost*0.25)*(1.0+game.hero.mod("sell_bonus")))
	for soldier in troops:
		if is_instance_valid(soldier):game.blocking.release(soldier);game.soldiers.erase(soldier);soldier.queue_free()
	game.towers.erase(self);game.rebuild_navigation();queue_free();game.hud.close_context();return true
func set_rally(point: Vector2) -> bool:
	if kind!="barracks" or destroyed:return false
	var closest: Dictionary=game.nearest_road(point)
	if position.distance_to(closest.point)>145:return false
	rally_point=closest.point;game.effect(rally_point,25,Color("e9c37e"),"flag",0.5);return true
func _physics_process(delta: float) -> void:
	if not game.running or game.game_over or destroyed:return
	attack_clock=maxf(0,attack_clock-delta);fire_clock=maxf(0,fire_clock-delta)
	if kind=="barracks":return
	if attack_clock<=0:
		var enemy: Node2D=game.tower_target(self)
		if enemy!=null:
			var aura: float=game.hero.command_aura(position)
			var speed_link:=1.05 if game.hero.has_link("armament","command") and aura>0 else 1.0
			attack_clock=reload_time()/speed_link
			var power: float=shot_power()
			if game.hero.mod("warcredit")>0:
				power*=1.0+0.05*float(game.hero.warcredit_stacks())
			if game.hero.mod("warmachine")>0:
				if enemy==streak_target: streak_count+=1
				else: streak_target=enemy;streak_count=1
				power*=1.0+warmachine_bonus()
			if game.hero.perk("armament")>0:
				shot_count+=1
				if shot_count>=armament_every(): shot_count=0;power*=1.5
			power*=1.0+aura
			power*=doctrine_multiplier(enemy)
			if kind=="cannon":fire_cannon(enemy,power)
			else:fire_shots(enemy,power)
			fire_clock=0.13;game.audio.play("tower",-16)
	body.rotation=sin(fire_clock*30)*0.025
	queue_redraw()
func fire_shots(enemy: Node2D,power: float) -> void:
	var options: Dictionary={"target":enemy,"appearance":"magic" if kind=="mage" else "arrow","tower":self,"pen":penetration(),
		"mark":doc_mod("mark_time"),"mark_bonus":doc_mod("mark_bonus"),
		"slow_amount":doc_mod("slow_amount"),"slow_time":doc_mod("slow_time"),
		"freeze_stacks":int(doc_mod("frost_stacks")),"freeze_time":doc_mod("freeze_time")}
	var shots:=1
	if doc_mod("triple_chance")>0.0 and game.rng.randf()<doc_mod("triple_chance"):shots=3
	var origin:=position+Vector2(0,-65)
	for index in range(shots):
		var spread: float=(index-(shots-1)*0.5)*0.09
		var aim: Vector2=origin+(enemy.center()-origin).rotated(spread)
		game.fire_projectile(origin,aim,power,int(data.type),"tower",options)
func fire_cannon(enemy: Node2D,power: float) -> void:
	game.delayed_attack(enemy.position,splash_radius(),power,0,"tower",0.45,{"origin":position+Vector2(0,-45),"cannon":true,
		"pen":penetration(),"knockback":doc_mod("knockback"),
		"burn_dps":doc_mod("burn_dps"),"burn_time":doc_mod("burn_time"),"burn_radius":doc_mod("burn_radius")})
func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(1,0.38));draw_circle(Vector2.ZERO,35,Color(0.1,0.13,0.07,0.26));draw_set_transform(Vector2.ZERO)
	if game.selected_site==site_id:
		draw_arc(Vector2.ZERO,attack_range(),0,TAU,72,Color(data.colour,0.3),2,true)
	if awaiting_doctrine:
		draw_arc(Vector2.ZERO,38+sin(Time.get_ticks_msec()*0.004)*3,0,TAU,40,Color("9fd8f0"),2,true)
func armament_every() -> int: return 4 if game.hero.has_link("command","armament") else 5
func warmachine_bonus() -> float: return 0.2*float(mini(2,int(streak_count/3)))
