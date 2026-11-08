class_name ArenaGame
extends Node2D
const START_GOLD:=280
var level_id: String="forest"
var level_definition: Dictionary={}
var routes: Array[Curve2D]=[]
var actors: Node2D
var terrain: Node2D
var ground: Sprite2D
var hero: ArenaHero
var enemies: Array=[]
var towers: Array=[]
var soldiers: Array=[]
var camps: Array=[]
var corpses: Array=[]
var effects: Array=[]
var delayed: Array=[]
var numbers: Array=[]
var audio: ArenaAudio
var hud: ArenaHUD
var blocking: ArenaBlocking
var progression: ArenaProgression
var navigation:=AStarGrid2D.new()
var rng:=RandomNumberGenerator.new()
var camera: Camera2D
var running:=false
var started:=false
var game_over:=false
var victory:=false
var gold:=START_GOLD
var core_max:=750.0
var core_health:=750.0
var cycle:=1
var phase: String="rest"
var phase_clock:=20.0
var rest_duration:=20.0
var wave_preview:=false
var rewarded:=false
var spawn_queue: Array=[]
var spawn_clock:=0.0
var wave_elapsed:=0.0
var selected_site:=-1
var targeting_slot:=-1
var rally_site:=-1
var suppress_primary:=false
var choices: Array[String]=[]
var choice_queue:=0
var choice_open:=false
var war_cry_clock:=0.0
var war_cry_position:=Vector2.ZERO
var kills:=0
var built:=0
var camps_cleared:=0
var elapsed:=0.0
var growth_reward:=0
var damage_stats: Dictionary={"hero":0.0,"tower":0.0,"soldier":0.0}
var quitting:=false
var shake:=0.0
func _ready() -> void:
	rng.randomize();_input_map()
	actors=Node2D.new();actors.name="Actors";actors.y_sort_enabled=true;add_child(actors)
	terrain=Node2D.new();terrain.name="Terrain";add_child(terrain)
	ground=Sprite2D.new();ground.z_index=-20;ground.position=ArenaLevelCatalog.SIZE*0.5;add_child(ground)
	camera=Camera2D.new();camera.position=ArenaLevelCatalog.SIZE*0.5;add_child(camera);camera.make_current()
	var painter:=ArenaEffects.new();painter.game=self;painter.z_index=5;add_child(painter)
	audio=ArenaAudio.new();add_child(audio);progression=ArenaProgression.new();blocking=ArenaBlocking.new(self)
	hud=ArenaHUD.new();hud.game=self;add_child(hud)
	get_tree().auto_accept_quit=false
	if get_tree().has_meta("restart_hero"):
		var key: String=get_tree().get_meta("restart_hero");var stage: String=get_tree().get_meta("restart_level","forest")
		get_tree().remove_meta("restart_hero");get_tree().remove_meta("restart_level");start_run.call_deferred(key,stage)
	else:hud.show_entry()
func _input_map() -> void:
	for name in {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN]}:
		if not InputMap.has_action(name):InputMap.add_action(name)
		for key in {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN]}[name]:
			var event:=InputEventKey.new();event.physical_keycode=key
			if not InputMap.action_has_event(name,event):InputMap.action_add_event(name,event)
	if not InputMap.has_action("shoot"):InputMap.add_action("shoot")
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("shoot",event):InputMap.action_add_event("shoot",event)
func start_run(hero_id: String,stage: String) -> void:
	if started or hero_id not in ArenaDefinitions.HERO_IDS or stage not in ArenaLevelCatalog.IDS:return
	level_id=stage;level_definition=ArenaLevelCatalog.definition(stage);routes.clear()
	for points in level_definition.routes:routes.append(ArenaLevelCatalog.curve(points))
	var floor_path: String="res://assets/v06/map_"+level_id+".png"
	if ResourceLoader.exists(floor_path):
		ground.texture=load(floor_path);ground.scale=Vector2(1600.0/ground.texture.get_width(),900.0/ground.texture.get_height())
	for rect in level_definition.blocked:_collision(rect)
	_collision(Rect2(level_definition.core-Vector2(32,30),Vector2(64,60)))
	_add_scenery()
	hero=ArenaHero.new();hero.game=self;hero.position=level_definition.hero_spawn;actors.add_child(hero);hero.configure(hero_id)
	started=true;running=true
	for index in range(level_definition.camps.size()):
		var point: Vector2=level_definition.camps[index]
		camps.append({"point":point,"remaining":3,"cleared":false})
		for unit in range(3):
			var enemy:=ArenaEnemy.new();enemy.game=self;enemy.kind="fox" if unit<2 else "wisp";enemy.is_guard=true;enemy.camp_id=index;enemy.home=point+Vector2.RIGHT.rotated(unit*TAU/3)*35;enemy.position=enemy.home
			actors.add_child(enemy);enemies.append(enemy)
	rebuild_navigation();start_rest(20);hud.show_battle();queue_redraw()
func _collision(rect: Rect2) -> void:
	var body:=StaticBody2D.new();body.position=rect.get_center();body.collision_layer=1;body.collision_mask=2
	var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=rect.size;collision.shape=shape;body.add_child(collision);terrain.add_child(body)
func prop(index: int,point: Vector2,width: float) -> void:
	if not ResourceLoader.exists("res://assets/v06/props.png"):return
	var sheet: Texture2D=load("res://assets/v06/props.png");var image:=AtlasTexture.new();image.atlas=sheet
	image.region=Rect2(index%4*sheet.get_width()/4.0,index/4*sheet.get_height()/2.0,sheet.get_width()/4.0,sheet.get_height()/2.0)
	var node:=Sprite2D.new();node.texture=image;node.position=point;node.offset.y=-image.get_height()*ArenaArtAnchors.offset_for("prop_"+str(index));node.scale=Vector2.ONE*width/image.get_width();node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;actors.add_child(node)
func _add_scenery() -> void:
	prop(6,level_definition.core,145)
	for index in range(level_definition.camps.size()):prop(4+index,level_definition.camps[index],115)
	for rect in level_definition.blocked:
		if rect in level_definition.get("water_rects",[]):continue
		if rect.size.y>220:continue
		prop(0 if rect.size.x<160 else 3,rect.get_center()+Vector2(0,rect.size.y*0.35),rect.size.x+40)
	for pair in [[Vector2(55,115),0],[Vector2(1505,130),1],[Vector2(1570,800),0],[Vector2(585,830),1],[Vector2(980,830),7]]:prop(pair[1],pair[0],125)
func rebuild_navigation() -> void:
	navigation.region=Rect2i(0,0,80,45);navigation.cell_size=Vector2(20,20);navigation.offset=Vector2(10,10)
	navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;navigation.update()
	for y in range(45):
		for x in range(80):
			var point:=Vector2(x*20+10,y*20+10);var solid:=not walkable(point)
			navigation.set_point_solid(Vector2i(x,y),solid)
func walkable(point: Vector2) -> bool:
	if point.x<12 or point.y<88 or point.x>1588 or point.y>888:return false
	for rect in level_definition.get("blocked",[]):
		if rect.grow(12).has_point(point):return false
	for tower in towers:
		if is_instance_valid(tower) and not tower.destroyed and tower.position.distance_to(point)<30:return false
	if level_definition.has("core") and point.distance_to(level_definition.core)<36:return false
	return true
func navigation_path(origin: Vector2,target: Vector2) -> PackedVector2Array:
	target=target.clamp(Vector2(15,95),Vector2(1585,885))
	var a:=Vector2i(origin/20);var b:=Vector2i(target/20)
	if not navigation.is_in_boundsv(a) or not navigation.is_in_boundsv(b):return PackedVector2Array()
	if navigation.is_point_solid(b):return PackedVector2Array()
	var result: PackedVector2Array=navigation.get_point_path(a,b,true)
	if not result.is_empty():result[0]=origin
	return result
func nearest_road(point: Vector2) -> Dictionary:
	var best: Dictionary={"route":0,"progress":0.0,"point":Vector2.ZERO};var distance:=INF
	for index in range(routes.size()):
		var progress: float=routes[index].get_closest_offset(point);var sample: Vector2=routes[index].sample_baked(progress,true)
		if sample.distance_squared_to(point)<distance:
			distance=sample.distance_squared_to(point);best={"route":index,"progress":progress,"point":sample}
	return best
func available_towers() -> Array[String]:
	var result: Array[String]=[]
	for key in ArenaDefinitions.TOWER_IDS:
		if int(level_definition.towers.get(key,99))<=cycle:result.append(key)
	return result
func site_tower(index: int) -> ArenaTower:
	for tower in towers:
		if is_instance_valid(tower) and not tower.destroyed and tower.site_id==index:return tower
	return null
func build_tower(index: int,kind: String) -> bool:
	if not running or game_over or index<0 or index>=level_definition.sites.size() or kind not in available_towers() or site_tower(index)!=null:return false
	var cost: int=int(float(ArenaDefinitions.TOWERS[kind].cost)*(1.0-clampf(hero.mod("tower_cost")+(0.05 if hero.has_link("spoils","works") else 0.0),0.0,0.5)))
	if gold<cost:return false
	gold-=cost;var tower:=ArenaTower.new();tower.game=self;tower.kind=kind;tower.site_id=index;tower.position=level_definition.sites[index]
	actors.add_child(tower);towers.append(tower);built+=1;rebuild_navigation();audio.play("tower");hud.refresh_context();return true
func start_rest(duration: float) -> void:
	phase="rest";phase_clock=maxf(8.0,duration-hero.mod("rest_reduce"));rest_duration=phase_clock;wave_preview=false;rewarded=false
	hud.announce_unlock()
func request_wave() -> void:
	if not running or game_over or phase!="rest" or get_tree().paused:return
	if not wave_preview:wave_preview=true;return
	if not rewarded:
		var early:=maxf(0.0,rest_duration-phase_clock)
		var bonus:=12.0*(1.0+hero.mod("rest_bonus"))*clampf(phase_clock/rest_duration,0,1)
		if hero.has_link("horn","spoils"): bonus+=3.0*floor(early/5.0)
		if hero.has_link("spoils","horn"): bonus*=1.5
		gold+=int(floor(bonus));rewarded=true
	begin_wave()
func begin_wave() -> void:
	if phase!="rest":return
	phase="spawn";wave_preview=false;spawn_queue.clear();spawn_clock=0;wave_elapsed=0
	gold+=int(hero.mod("wave_gold"))
	if hero.has_link("works","spoils"): gold+=5
	var pattern:=ArenaLevelCatalog.wave(level_id,cycle)
	var index:=0
	for group in pattern.units:
		for unit in range(group[1]):
			var lane:=0
			if routes.size()>1:lane=index%2 if pattern.lead<0 else (int(pattern.lead) if index%4<3 else 1-int(pattern.lead))
			var at: float=index*(0.68 if cycle<4 else 0.5)+(4.5 if level_id=="creek" and cycle==1 and lane==1 else 0.0)
			spawn_queue.append({"kind":group[0],"route":lane,"elite":cycle>=4 and index%9==8,"at":at});index+=1
	if bool(level_definition.boss) and cycle==8:spawn_queue.append({"kind":"moth","route":0,"elite":false,"at":index*0.5+2})
	spawn_queue.sort_custom(func(a,b):return a.at<b.at)
func spawn_enemy(kind: String,lane: int,offset := 0.0,elite := false) -> ArenaEnemy:
	if lane<0 or lane>=routes.size():return null
	var enemy:=ArenaEnemy.new();enemy.game=self;enemy.kind=kind;enemy.route_id=lane;enemy.progress=offset;enemy.elite=elite;enemy.position=routes[lane].sample_baked(offset,true)
	actors.add_child(enemy);enemies.append(enemy);return enemy
func nearest_enemy(point: Vector2,distance: float,include_guards:=true) -> ArenaEnemy:
	var best: ArenaEnemy;var squared: float=distance*distance
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or (enemy.is_guard and not include_guards):continue
		var d: float=point.distance_squared_to(enemy.center())
		if d<squared:squared=d;best=enemy
	return best
func tower_target(tower: ArenaTower) -> ArenaEnemy:
	var best: ArenaEnemy;var score:=-INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_guard or enemy.position.distance_to(tower.position)>tower.attack_range():continue
		var next: float=enemy.progress/routes[enemy.route_id].get_baked_length()
		if tower.target_mode=="strongest":next=enemy.health
		if next>score:score=next;best=enemy
	return best
func remove_enemy(enemy: ArenaEnemy) -> void:
	enemy.dead=true;blocking.release_enemy(enemy);enemies.erase(enemy);enemy.queue_free()
func enemy_defeated(enemy: ArenaEnemy) -> void:
	blocking.release_enemy(enemy);enemies.erase(enemy);kills+=1
	gold+=int(enemy.data.gold)+int(hero.mod("gold_kill"));hero.add_xp(int(enemy.data.xp));hero.heal_on_kill()
	if hero.mod("frostfire")>0 and enemy.burn_clock>0:
		var radius:=60.0*(1.3 if hero.has_link("chain","burn") else 1.0)
		area_damage(enemy.position,radius,60.0,1,"hero")
	if enemy.is_guard:
		camps[enemy.camp_id].remaining-=1
		if int(camps[enemy.camp_id].remaining)<=0 and not camps[enemy.camp_id].cleared:
			camps[enemy.camp_id].cleared=true;camps_cleared+=1;gold+=60;queue_choice();effect(camps[enemy.camp_id].point,65,Color("f6d68d"),"upgrade",0.9)
	if kind_has_visual(enemy):
		var ghost: ArenaCreature=enemy.visual;ghost.reparent(actors,true);ghost.show_pose("down",enemy.facing);corpses.append({"node":ghost,"life":0.65})
	enemy.queue_free()
func kind_has_visual(enemy: ArenaEnemy) -> bool:
	return is_instance_valid(enemy.visual) and enemy.visual.sprite_frames.has_animation("down")
func core_hit(amount: float) -> void:
	if game_over:return
	core_health=maxf(0,core_health-amount);audio.play("hurt");shake=2.5
	if core_health<=0:finish(false)
func support_scale(point: Vector2) -> float:
	var result:=1.0
	if war_cry_clock>0 and point.distance_to(war_cry_position)<hero.war_cry_radius():result+=0.3+(0.15 if hero.mod("war_cry_bonus")>0 else 0.0)
	return result
func fire_projectile(origin: Vector2,target: Vector2,amount: float,kind: int,source: String,options: Dictionary={}) -> ArenaProjectile:
	var shot:=ArenaProjectile.new();shot.game=self;shot.position=origin;shot.direction=(target-origin).normalized();shot.damage=amount;shot.damage_type=kind;shot.source=source
	shot.speed=float(options.get("speed",590.0));shot.appearance=options.get("appearance","magic" if kind==1 else "arrow");shot.pierce=int(options.get("pierce",0));shot.expose=bool(options.get("expose",false));shot.target=options.get("target");shot.splash=float(options.get("splash",0));shot.burn=float(options.get("burn",0))
	shot.z_index=20;actors.add_child(shot)
	if source=="enemy":shot.add_to_group("hostile_projectile")
	return shot
func cone_damage(point: Vector2,direction: Vector2,radius: float,amount: float,kind: int,source: String,stagger:=0.0) -> void:
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead:continue
		var offset: Vector2=enemy.position-point
		if offset.length()<radius and (offset.length()<25 or offset.normalized().dot(direction)>0.3):enemy.take_hit(amount,kind,source,stagger);enemy.push_back(6 if stagger>0 else 0)
func area_damage(point: Vector2,radius: float,amount: float,kind: int,source: String,stagger:=0.0,chill:=0.0) -> void:
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(point)<=radius:enemy.take_hit(amount,kind,source,stagger,chill)
func delayed_attack(point: Vector2,radius: float,amount: float,kind: int,source: String,delay: float,options: Dictionary={}) -> void:
	delayed.append({"point":point,"radius":radius,"damage":amount,"type":kind,"source":source,"life":delay,"duration":delay,"options":options})
func effect(point: Vector2,radius: float,colour: Color,kind: String,duration: float,direction:=Vector2.RIGHT) -> void:
	if effects.size()>90:effects.pop_front()
	effects.append({"point":point,"radius":radius,"colour":colour,"kind":kind,"life":duration,"duration":duration,"direction":direction})
func feedback(point: Vector2,damage: float,kind: int,kill: bool) -> void:
	effect(point,12 if not kill else 21,ArenaCombat.colour(kind),"hit",0.16 if not kill else 0.27)
	if numbers.size()<24:numbers.append({"point":point,"text":str(int(ceil(damage))),"colour":ArenaCombat.colour(kind),"life":0.55})
	if damage>90:shake=1.4
	audio.play("kill" if kill else "hit",-16 if not kill else -12)
func queue_choice() -> void:
	choice_queue+=1
	if not choice_open:_open_choice.call_deferred()
func _card_available(key: String) -> bool:
	var card: Dictionary=ArenaPerks.card(key)
	if card.is_empty() or hero.perk(key)>=int(card.max): return false
	var hero_only:=str(card.get("hero",""))
	if hero_only!="" and hero_only!=hero.class_id: return false
	if bool(card.get("evolution",false)):
		var req: Dictionary=card.get("requires",{})
		for req_key in req:
			if hero.perk(str(req_key))<int(req[req_key]): return false
	return true
func _card_weight(key: String) -> float:
	match str(ArenaPerks.card(key).get("rarity","common")):
		"rare": return 2.0
		"evo": return 6.0
		_: return 3.0
func _open_choice() -> void:
	if choice_open or choice_queue<=0 or game_over:return
	choices.clear()
	var pool: Array=[]
	for card in ArenaPerks.CARDS:
		if _card_available(str(card.id)): pool.append(str(card.id))
	while not pool.is_empty() and choices.size()<3:
		var total:=0.0
		for key in pool: total+=_card_weight(str(key))
		var roll:=rng.randf()*total
		var picked: String=str(pool[0])
		for key in pool:
			roll-=_card_weight(str(key))
			if roll<=0: picked=str(key);break
		choices.append(picked);pool.erase(picked)
	if choices.is_empty():choice_queue=0;gold+=40;return
	choice_open=true;get_tree().paused=true;hud.show_choices(choices)
func choose_perk(key: String) -> bool:
	if not choice_open or key not in choices or not hero.apply_perk(key):return false
	choice_queue-=1;choice_open=false;get_tree().paused=false;hud.close_modal();suppress_primary=true
	if choice_queue>0:_open_choice.call_deferred()
	return true
func finish(won: bool) -> void:
	if game_over:return
	game_over=true;victory=won;running=false;get_tree().paused=false;targeting_slot=-1;selected_site=-1
	growth_reward=progression.grant_experience(hero.class_id,ArenaProgression.battle_reward(kills,cycle if won else cycle-1,won))
	hud.show_result()
func restart_run() -> void:
	get_tree().paused=false;get_tree().set_meta("restart_hero",hero.class_id);get_tree().set_meta("restart_level",level_id);get_tree().reload_current_scene()
func return_to_menu() -> void:get_tree().paused=false;get_tree().reload_current_scene()
func mouse_world() -> Vector2:return get_viewport().get_canvas_transform().affine_inverse()*get_viewport().get_mouse_position()
func input_blocked() -> bool:
	if hud.has_modal() or selected_site>=0 or targeting_slot>=0 or rally_site>=0:return true
	var hovered: Control=get_viewport().gui_get_hovered_control()
	return hovered!=null and hud.root.is_ancestor_of(hovered) and hovered.mouse_filter!=Control.MOUSE_FILTER_IGNORE
func request_skill(slot: int) -> void:
	if hero.knocked_out or hero.cooldowns[slot]>0:return
	hud.close_context()
	if slot==1 and hero.class_id!="knight":targeting_slot=slot;suppress_primary=true
	else:hero.cast(slot,hero.position+hero.facing*120)
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:suppress_primary=false
	if wave_preview and event is InputEventMouseButton and event.pressed and not hud.wave_button.get_global_rect().has_point(event.position):wave_preview=false
func _unhandled_input(event: InputEvent) -> void:
	if not started or game_over or get_tree().paused:return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:hero.cast(0,mouse_world())
			KEY_SPACE:hero.cast(1,mouse_world())
			KEY_F:request_wave()
			KEY_ESCAPE:
				if targeting_slot>=0 or rally_site>=0:targeting_slot=-1;rally_site=-1
				elif selected_site>=0:hud.close_context()
				else:hud.show_pause()
		return
	if not (event is InputEventMouseButton and event.pressed):return
	if event.button_index==MOUSE_BUTTON_RIGHT:
		if targeting_slot>=0 or rally_site>=0 or selected_site>=0:targeting_slot=-1;rally_site=-1;hud.close_context()
		else:hero.command_move(mouse_world())
	elif event.button_index==MOUSE_BUTTON_LEFT:
		if targeting_slot>=0:
			if hero.cast(targeting_slot,mouse_world()):targeting_slot=-1
			suppress_primary=true;return
		if rally_site>=0:
			var tower:=site_tower(rally_site)
			if tower!=null and tower.set_rally(mouse_world()):rally_site=-1
			suppress_primary=true;return
		for index in range(level_definition.sites.size()):
			if mouse_world().distance_to(level_definition.sites[index])<42:
				selected_site=index;hud.show_context(index);suppress_primary=true;return
		if selected_site>=0:hud.close_context()
func _physics_process(delta: float) -> void:
	if not running or game_over:return
	elapsed+=delta;war_cry_clock=maxf(0,war_cry_clock-delta)
	blocking.update()
	if phase=="rest":
		phase_clock-=delta
		if phase_clock<=0:begin_wave()
	else:
		wave_elapsed+=delta
		while not spawn_queue.is_empty() and float(spawn_queue[0].at)<=wave_elapsed:
			var packet: Dictionary=spawn_queue.pop_front();spawn_enemy(packet.kind,packet.route,0,packet.elite)
		if spawn_queue.is_empty():
			var live:=0
			for enemy in enemies:
				if is_instance_valid(enemy) and not enemy.dead and not enemy.is_guard:live+=1
			if live==0:
				if cycle>=8:finish(true)
				else:cycle+=1;start_rest(16)
	var finished: Array=[]
	for attack in delayed:
		attack.life-=delta
		if attack.life<=0:
			if attack.source=="enemy":
				if not hero.knocked_out and hero.center().distance_to(attack.point)<attack.radius:hero.take_hit(attack.damage,attack.type)
			else:area_damage(attack.point,attack.radius,attack.damage,attack.type,attack.source,float(attack.options.get("stun",0)))
			effect(attack.point,attack.radius,ArenaCombat.colour(attack.type),"blast",0.45);audio.play("explode",-14);finished.append(attack)
	for attack in finished:delayed.erase(attack)
func _process(delta: float) -> void:
	if not started:return
	for item in effects:item.life-=delta
	effects=effects.filter(func(item):return item.life>0)
	for item in numbers:item.life-=delta;item.point.y-=delta*27
	numbers=numbers.filter(func(item):return item.life>0)
	for corpse in corpses:
		corpse.life-=delta
		if is_instance_valid(corpse.node):corpse.node.modulate.a=clampf(corpse.life/0.25,0,1)
	for corpse in corpses.duplicate():
		if corpse.life<=0:
			if is_instance_valid(corpse.node):corpse.node.queue_free()
			corpses.erase(corpse)
	shake=maxf(0,shake-delta*12);camera.offset=Vector2(sin(elapsed*71),cos(elapsed*49))*shake
	queue_redraw()
func _draw() -> void:
	if not started:return
	if ground.texture==null:
		draw_rect(Rect2(Vector2.ZERO,ArenaLevelCatalog.SIZE),Color("88a65c"))
		for road in routes:
			draw_polyline(road.get_baked_points(),Color("667344"),80,true);draw_polyline(road.get_baked_points(),Color("d9bb7b"),67,true)
		for rect in level_definition.blocked:draw_rect(rect,Color("466947"))
	for index in range(level_definition.sites.size()):
		if site_tower(index)!=null:continue
		var point: Vector2=level_definition.sites[index]
		draw_circle(point+Vector2(0,4),30,Color(0.2,0.22,0.11,0.18));draw_arc(point,29,0,TAU,36,Color("e1ce9b"),3,true)
		draw_line(point-Vector2(8,0),point+Vector2(8,0),Color("faf1cc"),2);draw_line(point-Vector2(0,8),point+Vector2(0,8),Color("faf1cc"),2)
	if wave_preview:
		for road in routes:draw_polyline(road.get_baked_points(),Color(1,0.82,0.35,0.5),3,true)
	if targeting_slot>=0 or rally_site>=0:
		var point:=mouse_world();draw_arc(point,135 if targeting_slot>=0 else 25,0,TAU,48,Color("f2dd9c"),2,true)
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:quit_game()
func quit_game() -> void:
	if quitting:return
	quitting=true;get_tree().paused=false;running=false;audio.shutdown()
	await get_tree().create_timer(0.15,true,false,true).timeout
	get_tree().quit()
