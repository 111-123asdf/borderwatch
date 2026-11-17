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
var prisms: Array=[]
var enemy_revision:=0
var projectile_snapshot: Array=[]
var projectile_snapshot_tick:=-1
var projectile_snapshot_revision:=-1
var towers: Array=[]
var soldiers: Array=[]
var camps: Array=[]
var unlocked_sites: Array=[]
var corpses: Array=[]
var effects: Array=[]
var delayed: Array=[]
var zones: Array=[]
var numbers: Array=[]
var audio: ArenaAudio
var hud: ArenaHUD
var blocking: ArenaBlocking
var campaign: ArenaCampaign
var run_id:=""
var settlement: Dictionary={}
var run_towers: Array[String]=["archer","mage","cannon","barracks"]
var navigation:=AStarGrid2D.new()
var navigation_static:=PackedByteArray()
var navigation_dynamic: Array[Vector2i]=[]
var rng:=RandomNumberGenerator.new()
var camera: ArenaBattleCamera
var siege: ArenaRuinsSiege
var breach_open:=false
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
var pending_doctrine_site:=-1
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
var doctrine_tokens:=0
var wave_started_at:=0.0
var wave_kills:=0
var wave_log: Array=[]
var camp_reward_open:=false
var open_camp_id:=-1
var pending_camp_rewards: Array=[]
var elapsed:=0.0
var damage_stats: Dictionary={"hero":0.0,"tower":0.0,"soldier":0.0}
var quitting:=false
var shake:=0.0
var feel:=ArenaFeel.new()
var feel_lab:=false
var lab: ArenaFeelLab
var keystone_mode:=false
var keystones: Array[String]=[]
var resonance:=0.0
var resonance_casts:=0
var _suppress_resonance:=false
var altars: Array=[]
var orbit_angle:=0.0
var orbit_attack_clock:=0.0
var orbit_intercept_clock:=0.0
var altar_sheet: Texture2D
var tilemap_scene: Node
var atmosphere: Node
var bridge_gate_config: Dictionary={}
var bridge_sealed:=false
var bridge_lift:=0.0
var bridge_active_clock:=0.0
var bridge_cooldown:=0.0
var bridge_normal_curve: Curve2D
var bridge_detour_curve: Curve2D
const BRIDGE_SEAL_DURATION:=14.0
const BRIDGE_COOLDOWN_DURATION:=28.0
func _ready() -> void:
	rng.randomize();_input_map()
	actors=Node2D.new();actors.name="Actors";actors.y_sort_enabled=true;add_child(actors)
	terrain=Node2D.new();terrain.name="Terrain";add_child(terrain)
	ground=Sprite2D.new();ground.z_index=-20;ground.position=ArenaLevelCatalog.SIZE*0.5;add_child(ground)
	var site_art:=ArenaBattleArt.new();site_art.game=self;add_child(site_art)
	camera=ArenaBattleCamera.new();camera.game=self;camera.position=ArenaLevelCatalog.SIZE*0.5;add_child(camera);camera.make_current()
	var painter:=ArenaEffects.new();painter.game=self;painter.z_index=5;add_child(painter)
	audio=ArenaAudio.new();add_child(audio);blocking=ArenaBlocking.new(self)
	feel_lab=(OS.get_cmdline_user_args().has("--feel-lab") and not get_tree().has_meta("feel_lab_consumed")) or get_tree().has_meta("feel_lab_hero")
	if feel_lab:
		campaign=ArenaCampaign.new("",false)
		for key in ArenaDefinitions.HERO_IDS:campaign.data.levels[key]=5
	elif campaign==null:campaign=ArenaCampaign.playtest() if OS.get_cmdline_user_args().has("--playtest") else ArenaCampaign.new()
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,float(campaign.data.volume))))
	hud=ArenaHUD.new();hud.game=self;add_child(hud)
	get_tree().auto_accept_quit=false
	if feel_lab:
		_open_feel_lab.call_deferred()
	elif get_tree().has_meta("restart_hero"):
		var key: String=get_tree().get_meta("restart_hero");var stage: String=get_tree().get_meta("restart_level","forest")
		if get_tree().has_meta("restart_towers"):run_towers.assign(get_tree().get_meta("restart_towers"));get_tree().remove_meta("restart_towers")
		get_tree().remove_meta("restart_hero");get_tree().remove_meta("restart_level");start_run.call_deferred(key,stage,true)
	elif get_tree().has_meta("open_hero_hall"):
		hud.frontend.hero_id=str(get_tree().get_meta("open_hero_hall"));get_tree().remove_meta("open_hero_hall");hud.frontend.hall()
	elif get_tree().has_meta("open_world_map"):
		hud.frontend.stage=str(get_tree().get_meta("open_world_map"));get_tree().remove_meta("open_world_map");hud.frontend.levels()
	else:
		var cli_stage:=""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--stage="):cli_stage=arg.trim_prefix("--stage=")
		if cli_stage in ArenaLevelCatalog.IDS and campaign.can_deploy(cli_stage):
			start_run.call_deferred(campaign.selected_hero(),cli_stage)
		else:hud.show_entry()
func _open_feel_lab() -> void:
	var key: String=str(get_tree().get_meta("feel_lab_hero","knight"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lab-hero=") and not get_tree().has_meta("feel_lab_hero"):key=arg.trim_prefix("--lab-hero=")
	if get_tree().has_meta("feel_lab_hero"):get_tree().remove_meta("feel_lab_hero")
	if key not in ArenaDefinitions.HERO_IDS:key="knight"
	start_run(key,"forest");phase="lab";lab=ArenaFeelLab.new();add_child(lab);lab.open(self)
func _input_map() -> void:
	for name in {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN]}:
		if not InputMap.has_action(name):InputMap.add_action(name)
		for key in {"move_left":[KEY_A,KEY_LEFT],"move_right":[KEY_D,KEY_RIGHT],"move_up":[KEY_W,KEY_UP],"move_down":[KEY_S,KEY_DOWN]}[name]:
			var event:=InputEventKey.new();event.physical_keycode=key
			if not InputMap.action_has_event(name,event):InputMap.action_add_event(name,event)
	if not InputMap.has_action("shoot"):InputMap.add_action("shoot")
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT
	if not InputMap.action_has_event("shoot",event):InputMap.action_add_event("shoot",event)
func start_run(hero_id: String,stage: String,keep_loadout:=false) -> void:
	if started or hero_id not in ArenaDefinitions.HERO_IDS or stage not in ArenaLevelCatalog.IDS:return
	if not keep_loadout:run_towers=campaign.tower_loadout()
	run_id=str(Time.get_unix_time_from_system())+"-"+str(Time.get_ticks_usec())+"-"+str(randi());settlement={}
	level_id=stage;level_definition=ArenaLevelCatalog.definition(stage);breach_open=false;navigation_static.clear();navigation_dynamic.clear();routes.clear();zones.clear();pending_doctrine_site=-1;prisms.clear()
	keystone_mode=str(level_definition.get("perk_mode",""))=="keystone"
	keystones.clear();resonance=25.0 if keystone_mode else 0.0;resonance_casts=0;altars.clear();orbit_attack_clock=0.0;orbit_intercept_clock=0.0
	var altar_points: Array=level_definition.get("altars",[])
	for index in range(altar_points.size()):
		altars.append({"id":index,"point":altar_points[index],"charge":55.0,"mode":"stasis","active":0.0})
	if keystone_mode:
		if ResourceLoader.exists("res://assets/v016/ruins_altar.png"):altar_sheet=load("res://assets/v016/ruins_altar.png")
		elif ResourceLoader.exists("res://assets/v015/ruins_altar.png"):altar_sheet=load("res://assets/v015/ruins_altar.png")
	for points in level_definition.routes:routes.append(ArenaLevelCatalog.curve(points))
	bridge_gate_config=level_definition.get("bridge_gate",{}).duplicate(true)
	bridge_sealed=false;bridge_lift=0.0;bridge_active_clock=0.0;bridge_cooldown=0.0
	bridge_normal_curve=null;bridge_detour_curve=null
	if not bridge_gate_config.is_empty():
		var gate_route:=int(bridge_gate_config.get("route_id",1))
		if gate_route>=0 and gate_route<routes.size():bridge_normal_curve=routes[gate_route]
		var detour_pts: Array=bridge_gate_config.get("detour",[])
		if not detour_pts.is_empty():bridge_detour_curve=ArenaLevelCatalog.curve(detour_pts)
		if bridge_detour_curve!=null and bridge_normal_curve!=null:bridge_detour_curve.set_point_in(2,bridge_normal_curve.get_point_in(2))
	tilemap_scene=null
	ground.visible=true
	var floor_path: String=level_definition.get("map_art",ArenaBattleArt.map_path(level_id))
	if ResourceLoader.exists(floor_path):
		ground.position=world_size()*0.5;ground.texture=load(floor_path);ground.scale=world_size()/ground.texture.get_size()
		var paint_material:=ShaderMaterial.new();paint_material.shader=load("res://scripts/shaders/painted_ruins.gdshader");paint_material.set_shader_parameter("is_ruins",1.0 if stage=="ruins" else 0.0);ground.material=paint_material
	for rect in level_definition.blocked:_collision(rect)
	_collision(Rect2(level_definition.core-Vector2(32,30),Vector2(64,60)))
	_add_scenery()
	hero=ArenaHero.new();hero.game=self;hero.position=level_definition.hero_spawn;actors.add_child(hero);hero.configure(hero_id)
	if stage=="ruins":hero.visual.feedback.set_environment(hero.visual,Color(0.97,1.0,1.03),0.90)
	started=true;running=true;camera.configure()
	if stage=="ruins":siege=ArenaRuinsSiege.new();siege.game=self;add_child(siege)
	for index in range(level_definition.camps.size()):
		var camp:=ArenaCamp.new();camp.game=self;camp.id=index;camp.point=level_definition.camps[index]
		camps.append(camp)
	if ResourceLoader.exists("res://scripts/arena/arena_atmosphere.gd"):
		var atmo_script=load("res://scripts/arena/arena_atmosphere.gd")
		if atmo_script!=null and atmo_script.has_method("install"):
			atmosphere=atmo_script.call("install",self)
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
	if level_id=="ruins":
		var shrine:=Sprite2D.new();shrine.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;shrine.texture=load("res://assets/v017/core_ruins.png");shrine.position=level_definition.core;shrine.offset=Vector2(0,-170);shrine.scale=Vector2.ONE*145.0/512.0;actors.add_child(shrine)
	else:prop(6,level_definition.core,145)
	if str(level_definition.get("biome",""))=="ruins":return
	for index in range(level_definition.camps.size()):prop(4+index,level_definition.camps[index],115)
	for rect in level_definition.blocked:
		if rect in level_definition.get("water_rects",[]):continue
		if rect.size.y>220:continue
		prop(0 if rect.size.x<160 else 3,rect.get_center()+Vector2(0,rect.size.y*0.35),rect.size.x+40)
	for pair in [[Vector2(55,115),0],[Vector2(1505,130),1],[Vector2(1570,800),0],[Vector2(585,830),1],[Vector2(980,830),7]]:prop(pair[1],pair[0],125)
func static_walkable(point: Vector2) -> bool:
	if point.x<12 or point.y<88 or point.x>world_size().x-12 or point.y>world_size().y-12:return false
	for rect in level_definition.get("blocked",[]):
		if rect.grow(12).has_point(point):return false
	return not level_definition.has("core") or point.distance_to(level_definition.core)>=36
func rebuild_navigation() -> void:
	var grid:=Vector2i(ceil(world_size().x/20),ceil(world_size().y/20))
	if navigation_static.is_empty():
		navigation.region=Rect2i(Vector2i.ZERO,grid);navigation.cell_size=Vector2(20,20);navigation.offset=Vector2(10,10)
		navigation.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES;navigation.update();navigation_static.resize(grid.x*grid.y)
		for y in range(grid.y):
			for x in range(grid.x):
				var solid:=not static_walkable(Vector2(x*20+10,y*20+10));navigation_static[y*grid.x+x]=1 if solid else 0;navigation.set_point_solid(Vector2i(x,y),solid)
	for cell in navigation_dynamic:navigation.set_point_solid(cell,navigation_static[cell.y*grid.x+cell.x]==1)
	navigation_dynamic.clear()
	var centers: Array=[]
	for tower in towers:
		if is_instance_valid(tower) and not tower.destroyed:centers.append(tower.position)
	if bridge_lift>0.9:centers.append(bridge_gate_point())
	if siege!=null and not breach_open:centers.append(siege.point())
	for point in centers:
		var center:=Vector2i(Vector2(point)/20)
		for y in range(center.y-3,center.y+4):
			for x in range(center.x-3,center.x+4):
				var cell:=Vector2i(x,y)
				if navigation.is_in_boundsv(cell) and not walkable(Vector2(x*20+10,y*20+10)):
					navigation.set_point_solid(cell,true);navigation_dynamic.append(cell)
func walkable(point: Vector2) -> bool:
	if not static_walkable(point):return false
	if siege!=null and not breach_open and point.distance_to(Vector2(level_definition.breach.point))<48:return false
	for tower in towers:
		if is_instance_valid(tower) and not tower.destroyed and tower.position.distance_to(point)<30:return false
	if bridge_lift>0.9 and not bridge_gate_config.is_empty() and point.distance_to(bridge_gate_point())<34.0:return false
	return true
func navigation_path(origin: Vector2,target: Vector2) -> PackedVector2Array:
	target=target.clamp(Vector2(15,95),world_size()-Vector2(15,15))
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
		if key in run_towers and int(level_definition.towers.get(key,99))<=cycle:result.append(key)
	return result
func site_tower(index: int) -> ArenaTower:
	for tower in towers:
		if is_instance_valid(tower) and not tower.destroyed and tower.site_id==index:return tower
	return null
func site_locked(index: int) -> bool:
	var locked: Array=level_definition.get("locked_sites",[])
	return index in locked and index not in unlocked_sites
func unlock_price(index: int) -> int:
	var prices: Dictionary=level_definition.get("locked_prices",{})
	if prices.has(index):return int(prices[index])
	if prices.has(str(index)):return int(prices[str(index)])
	return int(level_definition.get("locked_site_price",200))
func unlock_site(index: int) -> bool:
	if not running or game_over or not site_locked(index):return false
	var price:=unlock_price(index)
	if gold<price:return false
	gold-=price;unlocked_sites.append(index)
	effect(level_definition.sites[index],60,Color("f4d28b"),"upgrade",0.6);audio.play("tower")
	if is_instance_valid(hud):hud.refresh_context()
	return true
func build_tower(index: int,kind: String) -> bool:
	if not running or game_over or index<0 or index>=level_definition.sites.size() or kind not in available_towers() or site_tower(index)!=null or site_locked(index):return false
	var cost: int=int(float(ArenaDefinitions.TOWERS[kind].cost)*(1.0-clampf(hero.mod("tower_cost")+(0.05 if hero.has_link("spoils","works") else 0.0),0.0,0.5)))
	if gold<cost:return false
	gold-=cost;var tower:=ArenaTower.new();tower.game=self;tower.kind=kind;tower.site_id=index;tower.position=level_definition.sites[index]
	actors.add_child(tower);towers.append(tower);built+=1;rebuild_navigation();audio.play("tower");hud.refresh_context();return true
func note_camp_engaged(id: int) -> void:
	if id>=0 and id<camps.size():camps[id].engage()
func note_hero_damage(amount: float,at: Vector2) -> void:
	for camp in camps:
		if camp.state=="active" and not camp.cleared() and camp.point.distance_to(at)<=260.0:camp.hero_damage+=amount
func telemetry() -> Dictionary:
	var camps_data: Array=[]
	for camp in camps:camps_data.append({"id":camp.id,"state":camp.state,"time":camp.clear_time(),"wait":camp.engage_time(),"damage":camp.hero_damage})
	return {"camps":camps_data,"waves":wave_log.duplicate(true)}
func camp_aura(point: Vector2) -> Dictionary:
	for camp in camps:
		if camp.covers(point):return {"speed":camp.enemy_speed,"damage":camp.enemy_damage}
	return {}
func overdue_camps() -> int:
	var total:=0
	for camp in camps:
		if camp.overdue and not camp.cleared():total+=1
	return total
func l2_count() -> int:
	var total:=0
	for tower in towers:
		if is_instance_valid(tower) and not tower.destroyed and tower.level==2:total+=1
	return total
func _camp_raid(camp: ArenaCamp) -> void:
	var road: Dictionary=nearest_road(camp.point)
	var length: float=routes[road.route].get_baked_length()
	var start: float=minf(float(road.progress),length*0.6)
	effect(camp.point,80,Color("e08a5a"),"blast",0.7)
	var raid_kind: String="construct_hound" if level_id=="ruins" else "fox"
	for index in range(3):spawn_enemy(raid_kind,int(road.route),maxf(0.0,start-24.0-index*14.0))
func queue_camp_reward(id: int) -> void:
	pending_camp_rewards.append(id)
	_pump_modals.call_deferred()
func pump_modals() -> void:_pump_modals.call_deferred()
func _pump_modals() -> void:
	if game_over or choice_open or camp_reward_open:return
	if is_instance_valid(hud) and hud.has_modal():return
	if not pending_camp_rewards.is_empty():
		open_camp_id=int(pending_camp_rewards.pop_front());camp_reward_open=true
		get_tree().paused=true;hud.show_camp_reward(open_camp_id)
	elif choice_queue>0:_open_choice()
func choose_camp_reward(id: int,kind: String) -> bool:
	if not camp_reward_open or id!=open_camp_id or kind not in ["hero","token","gold"]:return false
	camp_reward_open=false;get_tree().paused=false;hud.close_modal();suppress_primary=true
	match kind:
		"hero":
			if keystone_mode:
				hero.add_xp(160);hero.health=minf(hero.max_health,hero.health+hero.max_health*0.4);add_resonance(35.0)
				for altar in altars:altar.charge=minf(100.0,float(altar.charge)+35.0)
			else:queue_choice()
		"token":doctrine_tokens+=1
		"gold":gold+=100
	if is_instance_valid(hud):hud.refresh_tokens()
	_pump_modals.call_deferred()
	return true
func choose_doctrine(site: int,id: String) -> bool:
	var tower:=site_tower(site)
	if tower==null or not tower.choose_doctrine(id):return false
	pending_doctrine_site=-1
	if is_instance_valid(hud):hud.refresh_context()
	return true
func start_rest(duration: float) -> void:
	phase="rest";phase_clock=maxf(8.0,duration-hero.mod("rest_reduce"));rest_duration=phase_clock;wave_preview=false;rewarded=false
	hud.announce_unlock()
	if keystone_mode and cycle in [3,5,7]:
		var expected: int=[3,5,7].find(cycle)+1
		if keystones.size()<expected:queue_choice()
func request_wave() -> void:
	if not running or game_over or phase!="rest" or get_tree().paused:return
	if not wave_preview:wave_preview=true;return
	if not rewarded:
		var early:=maxf(0.0,rest_duration-phase_clock)
		var bonus:=12.0*(1.0+hero.mod("rest_bonus"))*clampf(phase_clock/rest_duration,0,1)
		if hero.has_link("horn","spoils"): bonus+=3.0*floor(early/5.0)
		if hero.has_link("spoils","horn"): bonus*=1.5
		gold+=mini(12,int(floor(bonus)));rewarded=true
	begin_wave()
func begin_wave() -> void:
	if phase!="rest":return
	phase="spawn";wave_preview=false;spawn_queue.clear();spawn_clock=0;wave_elapsed=0
	gold+=int(hero.mod("wave_gold"))
	if hero.has_link("works","spoils"): gold+=5
	var pattern:=ArenaLevelCatalog.wave(level_id,cycle)
	var pool: Array=pattern.get("route_pool",[])
	var index:=0
	wave_started_at=elapsed;wave_kills=0
	for group in pattern.units:
		var amount:=int(group[1]);var elite_count:=int(group[2]) if group.size()>2 else 0
		for unit in range(amount):
			var lane:=0
			if not pool.is_empty():
				lane=int(pool[index%pool.size()])
				if not breach_open and lane>=3 and routes.size()>3:lane=lane%3
			elif routes.size()>1:
				lane=index%2 if pattern.lead<0 else (int(pattern.lead) if index%4<3 else 1-int(pattern.lead))
			lane=clampi(lane,0,maxi(0,routes.size()-1))
			var at: float=index*(0.68 if cycle<4 else 0.5)+(4.5 if level_id=="creek" and cycle==1 and lane==1 else 0.0)
			spawn_queue.append({"kind":group[0],"route":lane,"elite":unit>=amount-elite_count,"at":at});index+=1
	if bool(level_definition.boss) and cycle==8:spawn_queue.append({"kind":str(level_definition.get("boss_kind","moth")),"route":0,"elite":false,"at":index*0.5+2})
	spawn_queue.sort_custom(func(a,b):return a.at<b.at)
	for camp in camps:
		camp.activate(cycle)
		if cycle>=ArenaCamp.DEADLINE_WAVE:camp.overdue=true
		if camp.needs_raid(cycle):camp.raid_sent=true;_camp_raid(camp)
func spawn_enemy(kind: String,lane: int,offset := 0.0,elite := false) -> ArenaEnemy:
	if lane<0 or lane>=routes.size():return null
	var enemy:=ArenaEnemy.new();enemy.game=self;enemy.kind=kind;enemy.route_id=lane;enemy.progress=offset;enemy.elite=elite;enemy.position=routes[lane].sample_baked(offset,true)
	actors.add_child(enemy);enemies.append(enemy);enemy_revision+=1
	if kind=="astral_prism":prisms.append(enemy)
	return enemy
func projectile_candidates() -> Array:
	var tick:=Engine.get_physics_frames()
	if tick!=projectile_snapshot_tick or projectile_snapshot_revision!=enemy_revision or projectile_snapshot.size()!=enemies.size():
		projectile_snapshot=enemies.duplicate();projectile_snapshot_tick=tick;projectile_snapshot_revision=enemy_revision
	return projectile_snapshot
func nearest_enemy(point: Vector2,distance: float,include_guards:=true) -> ArenaEnemy:
	var best: ArenaEnemy;var squared: float=distance*distance
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or (enemy.is_guard and not include_guards):continue
		var d: float=point.distance_squared_to(enemy.center())
		if d<squared:squared=d;best=enemy
	return best
func tower_target(tower: ArenaTower) -> ArenaEnemy:
	var best: ArenaEnemy;var score:=-INF
	var reach_squared:=pow(tower.attack_range(),2)
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or (enemy.is_guard and not enemy.siege_guard) or enemy.position.distance_squared_to(tower.position)>reach_squared:continue
		var next: float=enemy.progress/enemy_road(enemy).get_baked_length()
		if tower.target_mode=="strongest":next=enemy.health
		if next>score:score=next;best=enemy
	return best
func remove_enemy(enemy: ArenaEnemy) -> void:
	enemy.dead=true;blocking.release_enemy(enemy);enemies.erase(enemy);prisms.erase(enemy);enemy_revision+=1;enemy.queue_free()
func enemy_defeated(enemy: ArenaEnemy) -> void:
	blocking.release_enemy(enemy);enemies.erase(enemy);prisms.erase(enemy);enemy_revision+=1;kills+=1;wave_kills+=1
	gold+=int(enemy.data.gold)+int(hero.mod("gold_kill"));hero.add_xp(int(enemy.data.xp));hero.heal_on_kill()
	if keystone_mode:
		add_resonance(6.0)

	if enemy.kind=="rift_bomber":
		delayed_attack(enemy.position,82.0,42.0*enemy.damage_scale(),1,"enemy",0.95,{"telegraph":"rift_collapse"})
	if hero.mod("frostfire")>0 and enemy.burn_clock>0:
		var radius:=60.0*(1.3 if hero.has_link("chain","burn") else 1.0)
		area_damage(enemy.position,radius,60.0,1,"hero")
	var killer:=enemy.last_tower as ArenaTower
	if is_instance_valid(killer) and not killer.destroyed and killer.doc_mod("explode_radius")>0.0:
		area_damage(enemy.position,killer.doc_mod("explode_radius"),killer.base_power()*killer.doc_mod("explode_mult",1.0),int(killer.data.type),"tower")
	if enemy.is_guard and not enemy.siege_guard:
		var camp: ArenaCamp=camps[enemy.camp_id]
		camp.on_guard_down()
		if camp.remaining<=0 and not camp.cleared():
			camp.state="cleared";camp.cleared_at=elapsed;camps_cleared+=1
			effect(camp.point,65,Color("f6d68d"),"upgrade",0.9)
			queue_camp_reward(camp.id)
	if kind_has_visual(enemy):
		var ghost: ArenaCreature=enemy.visual;ghost.reparent(actors,true);ghost.show_pose("down",enemy.facing);corpses.append({"node":ghost,"life":0.65})
	if enemy.kind in ["construct_hound","rune_warden","astral_prism","rift_bomber","void_harvester","colossus"]:
		var shard_col:=Color("9ce8ff") if enemy.kind in ["astral_prism","void_harvester"] else Color("c9b99a")
		effect(enemy.center(),24.0 if enemy.elite else 18.0,shard_col,"shield_break" if enemy.kind in ["rune_warden","colossus"] else "magic_impact_painted",0.26)
		ArenaBattleArt.emit_world_dust(enemy.position+Vector2(-6,2),Vector2(-24,-18),22.0,Color("b4b0be"))
		ArenaBattleArt.emit_world_dust(enemy.position+Vector2(6,2),Vector2(24,-14),20.0,Color("9b96a6"))
	else:
		ArenaBattleArt.emit_world_dust(enemy.position,Vector2(0,-16),18.0,Color("a49d86"))
	enemy.queue_free()
func kind_has_visual(enemy: ArenaEnemy) -> bool:
	return is_instance_valid(enemy.visual) and enemy.visual.sprite_frames.has_animation("down")
func core_hit(amount: float) -> void:
	if game_over:return
	core_health=maxf(0,core_health-amount);audio.play("hurt");shake=2.5
	if feel.enabled:feel.trauma=minf(1.0,feel.trauma+0.65)
	if core_health<=0:finish(false)
func support_scale(point: Vector2) -> float:
	var result:=1.0
	if war_cry_clock>0 and point.distance_to(war_cry_position)<hero.war_cry_radius():result+=0.3+(0.15 if hero.mod("war_cry_bonus")>0 else 0.0)
	return result
func fire_projectile(origin: Vector2,target: Vector2,amount: float,kind: int,source: String,options: Dictionary={}) -> ArenaProjectile:
	var shot:=ArenaProjectile.new();shot.game=self;shot.position=origin;shot.direction=(target-origin).normalized();shot.damage=amount;shot.damage_type=kind;shot.source=source
	shot.speed=float(options.get("speed",590.0));shot.appearance=options.get("appearance","magic" if kind==1 else "arrow");shot.pierce=int(options.get("pierce",0));shot.expose=bool(options.get("expose",false));shot.target=options.get("target");shot.splash=float(options.get("splash",0));shot.burn=float(options.get("burn",0))
	shot.pen=float(options.get("pen",0));shot.mark=float(options.get("mark",0));shot.mark_bonus=float(options.get("mark_bonus",0))
	shot.slow_amount=float(options.get("slow_amount",0));shot.slow_time=float(options.get("slow_time",0))
	shot.freeze_stacks=int(options.get("freeze_stacks",0));shot.freeze_time=float(options.get("freeze_time",0))
	shot.knockback=float(options.get("knockback",0));shot.tower=options.get("tower");shot.bounce=int(options.get("bounce",0))
	shot.presentation=str(options.get("presentation",""));shot.feedback_tag=str(options.get("feedback","attack"))
	shot.z_index=20;actors.add_child(shot)
	if source=="enemy":shot.add_to_group("hostile_projectile")
	return shot
func cone_damage(point: Vector2,direction: Vector2,radius: float,amount: float,kind: int,source: String,stagger:=0.0,attack: String="attack") -> void:
	for enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.dead:continue
		var offset: Vector2=enemy.position-point
		if offset.length()<radius and (offset.length()<25 or offset.normalized().dot(direction)>0.3):enemy.take_hit(amount,kind,source,stagger,0.0,0.0,attack);enemy.push_back(6 if stagger>0 else 0)
func area_damage(point: Vector2,radius: float,amount: float,kind: int,source: String,stagger:=0.0,chill:=0.0,pen:=0.0,knockback:=0.0,attack: String="attack") -> void:
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(point)<=radius:
			enemy.take_hit(amount,kind,source,stagger,chill,pen,attack)
			if knockback>0:enemy.push_back(knockback)
func delayed_attack(point: Vector2,radius: float,amount: float,kind: int,source: String,delay: float,options: Dictionary={}) -> void:
	delayed.append({"point":point,"radius":radius,"damage":amount,"type":kind,"source":source,"life":delay,"duration":delay,"options":options})
func add_zone(point: Vector2,radius: float,dps: float,duration: float,kind: int,source: String) -> void:
	zones.append({"point":point,"radius":radius,"dps":dps,"life":duration,"duration":duration,"tick":0.0,"type":kind,"source":source})
func effect(point: Vector2,radius: float,colour: Color,kind: String,duration: float,direction:=Vector2.RIGHT) -> void:
	if effects.size()>90:effects.pop_front()
	effects.append({"point":point,"radius":radius,"colour":colour,"kind":kind,"life":duration,"duration":duration,"direction":direction})
func feedback(point: Vector2,damage: float,kind: int,kill: bool,source: String="hero",target: Node2D=null,attack: String="attack") -> void:
	feel.hit(self,point,damage,kind,kill,source,target,attack)
func queue_choice() -> void:
	choice_queue+=1
	_pump_modals.call_deferred()
func _card_available(key: String) -> bool:
	var card: Dictionary=ArenaPerks.card(key)
	if card.is_empty() or hero.perk(key)>=int(card.max) or bool(hero.awakened_perks.get(key,false)): return false
	var hero_only:=str(card.get("hero",""))
	if hero_only!="" and hero_only!=hero.class_id: return false
	var required: int=ArenaPerks.required_skill(key)
	if required>=0 and not hero.skill_unlocked(required):return false
	if required==-2 and not hero.skill_unlocked(0):return false
	if bool(card.get("evolution",false)):
		var req: Dictionary=card.get("requires",{})
		for req_key in req:
			if hero.effective_perk_rank(str(req_key))<int(req[req_key]): return false
	return true
func _card_weight(key: String) -> float:
	match str(ArenaPerks.card(key).get("rarity","common")):
		"rare": return 2.0
		"evo": return 6.0
		_: return 3.0
func _open_choice() -> void:
	if choice_open or camp_reward_open or choice_queue<=0 or game_over:return
	choices.clear()
	if keystone_mode:
		var pool_k: Array[String]=[]
		for item in ArenaKeystones.LIST:
			var kid: String=str(item.id)
			if kid not in keystones:pool_k.append(kid)
		while not pool_k.is_empty() and choices.size()<3:
			var picked_k: String=pool_k[rng.randi_range(0,pool_k.size()-1)]
			choices.append(picked_k);pool_k.erase(picked_k)
		if choices.is_empty():choice_queue=0;gold+=80;return
		choice_open=true;get_tree().paused=true;hud.show_keystone_choices(choices);return
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
	if not choice_open or key not in choices:return false
	if keystone_mode:
		if key in keystones:return false
		keystones.append(key)
		if key=="vanguard":
			for tower in towers:
				if is_instance_valid(tower) and not tower.destroyed and tower.kind=="barracks":tower.sync_troops()
		hero.recompute()
		effect(hero.center(),110.0,ArenaKeystones.by_id(key).get("color",Color("caa4ff")),"upgrade",0.6)
		choice_queue-=1;choice_open=false;get_tree().paused=false;hud.close_modal();suppress_primary=true
		_pump_modals.call_deferred()
		return true
	hero.awakened_perks[key]=true
	if not hero.apply_perk(key):return false
	choice_queue-=1;choice_open=false;get_tree().paused=false;hud.close_modal();suppress_primary=true
	_pump_modals.call_deferred()
	return true
func finish(won: bool) -> void:
	if game_over:return
	game_over=true;victory=won;running=false;get_tree().paused=false;targeting_slot=-1;selected_site=-1
	feel.clear(self)
	settlement=campaign.settle(run_id,level_id,won,8 if won else cycle-1)
	hud.show_result()
func retry_settlement() -> void:
	if not game_over or bool(settlement.get("ok",false)):return
	settlement=campaign.settle(run_id,level_id,victory,8 if victory else cycle-1);hud.show_result()
func restart_run() -> void:
	if feel_lab:
		get_tree().paused=false;hud.close_modal();lab.reset_targets();return
	get_tree().paused=false;get_tree().set_meta("restart_hero",hero.class_id);get_tree().set_meta("restart_level",level_id);get_tree().set_meta("restart_towers",run_towers.duplicate());get_tree().reload_current_scene()
func return_to_menu() -> void:
	if feel_lab:get_tree().set_meta("feel_lab_consumed",true)
	feel.clear(self)
	get_tree().paused=false;get_tree().set_meta("open_world_map",level_id if started else hud.frontend.stage);get_tree().reload_current_scene()
func open_hero_hall() -> void:
	if feel_lab:get_tree().set_meta("feel_lab_consumed",true)
	feel.clear(self)
	get_tree().paused=false;get_tree().set_meta("open_hero_hall",hero.class_id);get_tree().reload_current_scene()
func mouse_world() -> Vector2:return get_viewport().get_canvas_transform().affine_inverse()*get_viewport().get_mouse_position()
func input_blocked() -> bool:
	if hud.has_modal() or selected_site>=0 or targeting_slot>=0 or rally_site>=0:return true
	var hovered: Control=get_viewport().gui_get_hovered_control()
	return hovered!=null and hud.root.is_ancestor_of(hovered) and hovered.mouse_filter!=Control.MOUSE_FILTER_IGNORE
func request_skill(slot: int) -> void:
	if slot==2:
		if not keystone_mode or resonance<100.0 or hero.knocked_out or game_over or not running:return
		hud.close_context();targeting_slot=2;suppress_primary=true;return
	if slot not in [0,1] or not hero.skill_unlocked(slot) or hero.knocked_out or hero.cooldowns[slot]>0:return
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
			KEY_E:hero.cast(1,mouse_world())
			KEY_R:
				if keystone_mode:request_skill(2)
			KEY_G:
				if not bridge_gate_config.is_empty():trigger_bridge_gate()
			KEY_F:request_wave()
			KEY_ESCAPE:
				if targeting_slot>=0 or rally_site>=0:targeting_slot=-1;rally_site=-1
				elif selected_site>=0:hud.close_context()
				else:hud.show_pause()
		return
	if not (event is InputEventMouseButton and event.pressed):return
	var clicked: Vector2=get_viewport().get_canvas_transform().affine_inverse()*event.position
	if event.button_index==MOUSE_BUTTON_RIGHT:
		if targeting_slot>=0 or rally_site>=0 or selected_site>=0:targeting_slot=-1;rally_site=-1;hud.close_context()
		else:
			hero.command_move(clicked)
	elif event.button_index==MOUSE_BUTTON_LEFT:
		if targeting_slot==2:
			if cast_resonance(clicked):targeting_slot=-1
			suppress_primary=true;return
		if targeting_slot>=0:
			if hero.cast(targeting_slot,clicked):targeting_slot=-1
			suppress_primary=true;return
		if rally_site>=0:
			var tower:=site_tower(rally_site)
			if tower!=null and tower.set_rally(clicked):rally_site=-1
			suppress_primary=true;return
		for index in range(level_definition.sites.size()):
			if clicked.distance_to(level_definition.sites[index])<42:
				selected_site=index;hud.show_context(index);suppress_primary=true;return
		if not bridge_gate_config.is_empty() and clicked.distance_to(bridge_gate_point())<48.0:
			trigger_bridge_gate();suppress_primary=true;return
		if selected_site>=0:hud.close_context()
func _physics_process(delta: float) -> void:
	if not running or game_over:return
	elapsed+=delta;war_cry_clock=maxf(0,war_cry_clock-delta)
	blocking.update()
	_tick_stage3_systems(delta)
	if siege!=null:siege.tick(delta)
	if not feel_lab:
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
					wave_log.append({"wave":cycle,"time":snappedf(elapsed-wave_started_at,0.1),"kills":wave_kills,"core":core_health,"gold":gold})
					if cycle>=8:finish(true)
					else:cycle+=1;start_rest(16)
	var finished: Array=[]
	for attack in delayed:
		attack.life-=delta
		if attack.life<=0:
			if attack.source=="enemy":
				if not hero.knocked_out and hero.center().distance_to(attack.point)<attack.radius:hero.take_hit(attack.damage,attack.type)
			else:
				area_damage(attack.point,attack.radius,attack.damage,attack.type,attack.source,float(attack.options.get("stun",0)),0.0,float(attack.options.get("pen",0)),float(attack.options.get("knockback",0)),str(attack.options.get("feedback","attack")))
				if float(attack.options.get("burn_dps",0))>0:
					add_zone(attack.point,float(attack.options.get("burn_radius",64)),float(attack.options.get("burn_dps",0)),float(attack.options.get("burn_time",4.0)),attack.type,attack.source)
			var tag: String=str(attack.options.get("feedback",""))
			var look: String=("meteor_impact" if tag=="meteor" else "rain_impact") if feel.enabled and tag in ["meteor","arrow_rain"] else "blast"
			effect(attack.point,attack.radius,ArenaCombat.colour(attack.type),look,0.45)
			audio.play(("mage_meteor_hit" if tag=="meteor" else "ranger_rain") if feel.enabled and tag in ["meteor","arrow_rain"] else "explode",-14);finished.append(attack)
	for attack in finished:delayed.erase(attack)
	for zone in zones:
		zone.life-=delta;zone.tick+=delta
		if zone.tick>=0.25:
			zone.tick-=0.25
			area_damage(zone.point,zone.radius,float(zone.dps)*0.25,zone.type,zone.source)
	zones=zones.filter(func(zone):return float(zone.life)>0)
func _process(delta: float) -> void:
	if not started:return
	var ew:=0
	for i in range(effects.size()):
		var item: Dictionary=effects[i]
		var nl: float=float(item.life)-delta
		if nl>0.0:
			item.life=nl;effects[ew]=item;ew+=1
	if ew!=effects.size():effects.resize(ew)
	var nw:=0
	for i in range(numbers.size()):
		var item: Dictionary=numbers[i]
		var nl: float=float(item.life)-delta
		if nl>0.0:
			item.life=nl;item.point.y-=delta*27.0
			if item.has("merge"):item.merge=maxf(0.0,float(item.merge)-delta)
			numbers[nw]=item;nw+=1
	if nw!=numbers.size():numbers.resize(nw)
	var cw:=0
	for i in range(corpses.size()):
		var corpse: Dictionary=corpses[i]
		var cl: float=float(corpse.life)-delta
		if cl>0.0:
			corpse.life=cl
			if is_instance_valid(corpse.node):corpse.node.modulate.a=clampf(cl/0.25,0.0,1.0)
			corpses[cw]=corpse;cw+=1
		else:
			if is_instance_valid(corpse.node):corpse.node.queue_free()
	if cw!=corpses.size():corpses.resize(cw)
	feel.tick(self,delta)
	if is_instance_valid(atmosphere) and atmosphere.has_method("sync_battle"):
		atmosphere.call("sync_battle",delta)
	if not zones.is_empty() or keystone_mode or Engine.get_process_frames()%4==0:
		queue_redraw()
func _draw() -> void:
	if not started:return
	if ground.texture==null and not is_instance_valid(tilemap_scene):
		draw_rect(Rect2(Vector2.ZERO,world_size()),Color("88a65c"))
		for road in routes:
			draw_polyline(road.get_baked_points(),Color("667344"),80,true);draw_polyline(road.get_baked_points(),Color("d9bb7b"),67,true)
		for rect in level_definition.blocked:draw_rect(rect,Color("466947"))
	for zone in zones:
		draw_circle(zone.point,zone.radius,Color(1.0,0.55,0.2,0.05+0.05*clampf(float(zone.life)/maxf(0.1,float(zone.duration)),0.0,1.0)))
	for camp in camps:
		if camp.cleared():continue
		var aura_colour:=Color("c94e45") if camp.overdue else Color("d99855")
		var pulse:=0.88+0.12*sin(Time.get_ticks_msec()*0.004)
		draw_set_transform(camp.point+Vector2(0,8),0.0,Vector2(1.0,0.58))
		draw_circle(Vector2.ZERO,52.0*pulse,Color(aura_colour,0.11 if not camp.overdue else 0.16))
		for seg in range(8):
			var a0:=seg*(TAU/8.0)
			draw_arc(Vector2.ZERO,52.0,a0,a0+(TAU/8.0)*0.6,4,Color(aura_colour,0.52),2.0,true)
		draw_circle(Vector2.ZERO,8.0,Color(aura_colour,0.48))
		draw_set_transform(Vector2.ZERO)
	for index in range(level_definition.sites.size()):
		if site_tower(index)!=null:continue
		var point: Vector2=level_definition.sites[index]
		if ArenaGrounding.plinths!=null:
			continue
		if site_locked(index):
			draw_circle(point,31,Color(0.08,0.09,0.06,0.45));draw_arc(point,30,0,TAU,36,Color("7d7350"),3,true)
			draw_rect(Rect2(point+Vector2(-9,-1),Vector2(18,14)),Color("b9a271"))
			draw_arc(point+Vector2(0,-1),7,PI,TAU,16,Color("b9a271"),3,true)
			continue
		draw_line(point-Vector2(8,0),point+Vector2(8,0),Color("faf1cc"),2);draw_line(point-Vector2(0,8),point+Vector2(0,8),Color("faf1cc"),2)
	if wave_preview or (level_id=="ruins" and elapsed<8.0):
		for route_idx in range(routes.size()):
			if level_id=="ruins" and not breach_open and route_idx>=3:continue
			var preview_col: Color=Color(0.76,0.56,1.0,0.62) if (level_id=="ruins" and route_idx==3) else Color(1,0.82,0.35,0.5)
			draw_polyline(routes[route_idx].get_baked_points(),Color(preview_col,0.24),2,true)
			var road: Curve2D=routes[route_idx]
			for offset in range(110,int(road.get_baked_length())-45,190):
				var point:=road.sample_baked(offset,true);var direction:=(road.sample_baked(offset+5,true)-point).normalized()
				draw_polyline(PackedVector2Array([point-direction.rotated(0.6)*11,point,point-direction.rotated(-0.6)*11]),Color("edcf90"),2.5,true)
	_draw_stage3_overlays()
	if targeting_slot>=0 or rally_site>=0:
		var point:=mouse_world()
		var t_rad:=195.0 if targeting_slot==2 else (135.0 if targeting_slot>=0 else 25.0)
		var t_col:=Color("9eeaff") if targeting_slot==2 else Color("f2dd9c")
		draw_arc(point,t_rad,0,TAU,48,t_col,2.5 if targeting_slot==2 else 2.0,true)
func has_keystone(key: String) -> bool:
	return keystone_mode and key in keystones
func add_resonance(amount: float) -> void:
	if not keystone_mode or _suppress_resonance or amount<=0.0:return
	var mult: float=1.5 if has_keystone("overload_core") else 1.0
	resonance=minf(100.0,resonance+amount*mult)
func add_resonance_on_hit(damage: float) -> void:
	if not keystone_mode or _suppress_resonance or resonance>=100.0 or damage<=0.0:return
	add_resonance(minf(3.2,0.22+damage*0.032))
func cast_resonance(point: Vector2) -> bool:
	if not keystone_mode or resonance<100.0 or game_over or not running:return false
	var target_pt:=point.clamp(Vector2(20,96),world_size()-Vector2(20,20))
	resonance=0.0;resonance_casts+=1
	var power: float=190.0+hero.attack_damage()*2.4
	_suppress_resonance=true
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.position.distance_to(target_pt)<=195.0:
			if enemy.barrier_shield>0.0:enemy.barrier_shield*=0.5
			enemy.take_hit(power,1,"hero",1.6,0.0,0.25,"resonance")
	_suppress_resonance=false
	var salvo_count:=0
	for tower in towers:
		if is_instance_valid(tower) and not tower.destroyed and tower.position.distance_to(target_pt)<=310.0:
			if tower.trigger_bonus_salvo():salvo_count+=1
	if has_keystone("overload_core"):
		hero.cooldowns[0]=0.0;hero.recompute()
	effect(target_pt,195.0,Color("8be4ff"),"blast",0.65)
	effect(target_pt,165.0,Color("caa4ff"),"upgrade",0.75)
	shake=3.2;audio.play("phase")
	return true
func nearest_unhit_enemy(point: Vector2,distance: float,exclude_ids: Dictionary) -> ArenaEnemy:
	var best: ArenaEnemy;var best_d2:=distance*distance
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_guard or exclude_ids.has(enemy.get_instance_id()):continue
		var d2: float=point.distance_squared_to(enemy.center())
		if d2<best_d2:best_d2=d2;best=enemy
	return best
func prism_ward_reduction(point: Vector2) -> float:
	if prisms.is_empty():return 0.0
	for enemy in prisms:
		if is_instance_valid(enemy) and not enemy.dead and enemy.center().distance_squared_to(point)<=18225.0:
			return 0.12
	return 0.0
func trigger_fracture_burst(point: Vector2,damage: float) -> void:
	effect(point,92.0,Color("f6c26b"),"blast",0.35)
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.dead and enemy.center().distance_to(point)<=92.0:
			var dealt: float=minf(enemy.health+enemy.barrier_shield,damage)
			var ab: float=minf(enemy.barrier_shield,dealt);enemy.barrier_shield-=ab
			var hp_d: float=minf(enemy.health,dealt-ab);enemy.health-=hp_d;enemy.hurt_time=0.1
			damage_stats["hero"]=float(damage_stats.get("hero",0))+dealt
			feedback(enemy.center(),dealt,1,enemy.health<=0,"hero",enemy,"fracture_proc")
			if enemy.health<=0 and not enemy.dead:
				enemy.dead=true;hero.note_kill(false);enemy_defeated(enemy)
func trigger_conduit(origin: Vector2,bolt_damage: float) -> void:
	for tower in towers:
		if is_instance_valid(tower) and not tower.destroyed and tower.position.distance_to(origin)<=290.0:
			tower.trigger_bonus_salvo()
	var prev:=origin;var hit: Array[Node2D]=[]
	for bounce in range(4):
		var best: ArenaEnemy;var best_d2:=340.0*340.0
		for enemy in enemies:
			if not is_instance_valid(enemy) or enemy.dead or enemy in hit:continue
			var d2: float=prev.distance_squared_to(enemy.center())
			if d2<best_d2:best_d2=d2;best=enemy
		if best==null:break
		best.take_hit(bolt_damage,1,"hero",0.0,0.0,0.0,"conduit")
		effect(best.center(),26.0,Color("67d4ff"),"hit",0.22)
		hit.append(best);prev=best.center()
func altar_slow_at(point: Vector2) -> float:
	for altar in altars:
		if float(altar.active)>0.0 and str(altar.mode)=="stasis" and point.distance_squared_to(altar.point)<=57600.0:return 0.38
	return 0.0
func altar_overclock_bonus(point: Vector2) -> float:
	for altar in altars:
		if float(altar.active)>0.0 and str(altar.mode)=="overclock" and point.distance_squared_to(altar.point)<=57600.0:return 0.40
	return 0.0
func hero_overclock_bonus() -> float:
	if hero==null:return 0.0
	for altar in altars:
		if float(altar.active)>0.0 and str(altar.mode)=="overclock" and hero.position.distance_to(altar.point)<=240.0:return 0.25
	return 0.0
func point_in_altar_aura(point: Vector2) -> bool:
	for altar in altars:
		if point.distance_to(altar.point)<=240.0:return true
	return false
func activate_altar(index: int) -> bool:
	if index<0 or index>=altars.size() or not keystone_mode:return false
	if float(altars[index].charge)<100.0 or float(altars[index].active)>0.0:return false
	altars[index].charge=0.0;altars[index].active=12.0
	effect(altars[index].point,240.0,Color("8dbdcd"),"upgrade",0.65)
	audio.play("phase")
	return true
func enemy_road(enemy: ArenaEnemy) -> Curve2D:
	# Each enemy commits exactly once at the shared fork. Never remap live positions.
	if enemy.road_curve!=null:return enemy.road_curve
	var road: Curve2D=routes[enemy.route_id]
	if bridge_gate_config.is_empty() or enemy.route_id!=int(bridge_gate_config.get("route_id",1)):return road
	var fork: Vector2=bridge_gate_config.get("fork",Vector2(384,496))
	var fork_offset:=bridge_normal_curve.get_closest_offset(fork)
	if enemy.progress>=fork_offset:
		enemy.road_curve=bridge_detour_curve if bridge_sealed else bridge_normal_curve
		enemy.bridge_branch="detour" if bridge_sealed else "short"
		# The curves share an identical approach, including tangents at the fork.
		enemy.progress=enemy.road_curve.get_closest_offset(fork)+(enemy.progress-fork_offset)
		return enemy.road_curve
	return road
func bridge_has_crossers() -> bool:
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.bridge_branch=="short" and enemy.progress<=bridge_normal_curve.get_closest_offset(bridge_gate_point())+88.0:return true
	return hero!=null and not hero.knocked_out and hero.position.distance_to(bridge_gate_point())<48.0
func bridge_gate_point() -> Vector2:
	return bridge_gate_config.get("point",Vector2.ZERO)
func trigger_bridge_gate() -> bool:
	if not started or not running or game_over or bridge_gate_config.is_empty():return false
	if bridge_sealed or bridge_cooldown>0.0:return false
	if bridge_normal_curve==null or bridge_detour_curve==null:return false
	bridge_sealed=true;bridge_active_clock=BRIDGE_SEAL_DURATION;bridge_cooldown=BRIDGE_COOLDOWN_DURATION
	_apply_bridge_gate_state(true)
	var pt:=bridge_gate_point()
	effect(pt,96.0,Color("7fe8ff"),"upgrade",0.7)
	audio.play("phase")
	if is_instance_valid(atmosphere) and atmosphere.has_method("set_bridge_sealed"):
		atmosphere.call("set_bridge_sealed",pt,true)
	return true
func _apply_bridge_gate_state(_sealed: bool) -> void:
	# Future arrivals choose a branch; existing actors retain their Curve2D.
	queue_redraw()
func _tick_stage3_systems(delta: float) -> void:
	if not keystone_mode:return
	if not bridge_gate_config.is_empty():
		bridge_cooldown=maxf(0.0,bridge_cooldown-delta)
		if bridge_sealed:
			bridge_active_clock=maxf(0.0,bridge_active_clock-delta)
			if bridge_active_clock<=0.0:
				bridge_sealed=false
				_apply_bridge_gate_state(false)
				var pt:=bridge_gate_point()
				effect(pt,76.0,Color("f5cd6a"),"hit",0.5)
				if is_instance_valid(atmosphere) and atmosphere.has_method("set_bridge_sealed"):
					atmosphere.call("set_bridge_sealed",pt,false)
	var lift_target:=1.0 if bridge_sealed and not bridge_has_crossers() else 0.0
	var was_raised:=bridge_lift>0.9
	bridge_lift=move_toward(bridge_lift,lift_target,delta*2.0)
	if was_raised!=(bridge_lift>0.9):rebuild_navigation()
	for altar in altars:
		if float(altar.active)>0.0:
			altar.active=maxf(0.0,float(altar.active)-delta)
		else:
			altar.charge=minf(100.0,float(altar.charge)+4.5*delta)
			if float(altar.charge)>=100.0:
				for enemy in enemies:
					if is_instance_valid(enemy) and not enemy.dead and not enemy.is_guard and enemy.center().distance_to(altar.point)<=240.0:
						activate_altar(int(altar.id));break
	if has_keystone("orbit") and hero!=null and not hero.knocked_out:
		orbit_angle+=delta*3.4
		orbit_attack_clock=maxf(0.0,orbit_attack_clock-delta)
		orbit_intercept_clock=maxf(0.0,orbit_intercept_clock-delta)
		if orbit_attack_clock<=0.0:
			orbit_attack_clock=0.45
			var hits:=0
			for enemy in enemies.duplicate():
				if is_instance_valid(enemy) and not enemy.dead and enemy.center().distance_to(hero.center())<=108.0:
					enemy.take_hit(34.0,1,"hero",0.0,0.0,0.0,"orbit")
					hits+=1
					if hits>=3:break
			if hits>0:effect(hero.center(),92.0,Color("9ce7be"),"hit",0.15)
		if orbit_intercept_clock<=0.0:
			for proj in get_tree().get_nodes_in_group("hostile_projectile"):
				if is_instance_valid(proj) and proj.position.distance_to(hero.center())<=68.0:
					effect(proj.position,22.0,Color("9ce7be"),"hit",0.22);proj.queue_free();orbit_intercept_clock=2.5;break
func _draw_stage3_overlays() -> void:
	if not keystone_mode:return
	for altar in altars:
		var pt: Vector2=altar.point
		var active: bool=float(altar.active)>0.0
		var hovered:=mouse_world().distance_to(pt)<45.0
		if active or hovered:
			draw_circle(pt,240.0,Color(0.40,0.73,0.85,0.04 if active else 0.025))
			draw_arc(pt,240.0,0,TAU,64,Color(0.46,0.77,0.88,0.22),1.5,true)
		draw_set_transform(pt,0.0,Vector2(1,0.6))
		var pct: float=float(altar.active)/12.0 if active else float(altar.charge)/100.0
		draw_arc(Vector2.ZERO,31,-PI/2,-PI/2+TAU*pct,36,Color("8cbccf"),2.5,true)
		draw_set_transform(Vector2.ZERO)
		var crystal:=PackedVector2Array([pt+Vector2(0,-48),pt+Vector2(14,-26),pt+Vector2(0,-9),pt+Vector2(-14,-26)])
		draw_colored_polygon(crystal,Color("b0d9e1") if active else Color("7c9fae"))
		draw_polyline(PackedVector2Array([pt+Vector2(-14,-26),pt+Vector2(0,-9),pt+Vector2(14,-26)]),Color("496978"),2,true)
		draw_set_transform(pt,0.0,Vector2(1,0.5));draw_circle(Vector2.ZERO,22,Color("817e80"));draw_arc(Vector2.ZERO,22,0,TAU,32,Color("b8b7ac"),3,true);draw_set_transform(Vector2.ZERO)
	if not bridge_gate_config.is_empty():
		var bp:=bridge_gate_point()
		ArenaGrounding.ensure_textures()
		draw_texture_rect(ArenaGrounding.shadow,Rect2(bp-Vector2(62,22),Vector2(128,64)),false)
		if ArenaGrounding.mechanisms!=null:
			if bridge_lift<0.95:
				draw_texture_rect_region(ArenaGrounding.mechanisms,Rect2(bp-Vector2(64,56),Vector2(128,112)),Rect2(256,0,256,256),Color(1,1,1,1.0-bridge_lift*0.85))
			if bridge_lift>0.05:
				draw_texture_rect_region(ArenaGrounding.mechanisms,Rect2(bp-Vector2(64,58+bridge_lift*6.0),Vector2(128,112)),Rect2(512,0,256,256),Color(1,1,1,clampf(bridge_lift*1.15,0.0,1.0)))
		else:
			var deck:=Rect2(bp-Vector2(39,23+bridge_lift*34),Vector2(78,46*(1.0-bridge_lift*0.65)))
			draw_rect(deck,Color("806649"));draw_rect(deck,Color("bca37c"),false,2)
		if bridge_sealed or mouse_world().distance_to(bp)<75.0:
			draw_arc(bp+Vector2(0,5),48,-PI/2,-PI/2+TAU*(bridge_active_clock/BRIDGE_SEAL_DURATION if bridge_sealed else 1.0-bridge_cooldown/BRIDGE_COOLDOWN_DURATION),40,Color("7fe8ff") if bridge_sealed else Color("c8ac78"),2.5,true)
	if has_keystone("orbit") and hero!=null and not hero.knocked_out:
		var hc:=hero.center()
		for i in range(3):
			var ang:=orbit_angle+i*TAU/3.0
			var bp:=hc+Vector2(cos(ang),sin(ang)*0.68)*58.0
			var tang:=Vector2(-sin(ang),cos(ang)*0.68).normalized()
			draw_colored_polygon(PackedVector2Array([bp+tang*12.0,bp+tang.rotated(2.3)*8.0,bp+tang.rotated(-2.3)*8.0]),Color("9ce7be"))
			draw_arc(bp,5.0,0,TAU,12,Color("e9fff4"),1.5,true)
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:quit_game()
func quit_game() -> void:
	if quitting:return
	quitting=true;get_tree().paused=false;running=false;audio.shutdown()
	await get_tree().create_timer(0.15,true,false,true).timeout
	get_tree().quit()

func world_size() -> Vector2:return level_definition.get("size",ArenaLevelCatalog.SIZE)
func world_to_hud(point: Vector2) -> Vector2:return get_viewport().get_canvas_transform()*point
