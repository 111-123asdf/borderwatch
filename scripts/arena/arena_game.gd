class_name ArenaGame
extends Node2D
const START_GOLD:=300
const DEFENSE_BOUNTY_SCALE := [0.36, 0.27, 0.20, 0.13, 0.10]
const BLOOD_ALTAR_OVERFLOW_GOLD := 45
const BLOOD_ALTAR_ATTACK_COST := 120
const BLOOD_ALTAR_REST_XP := 140.0
const FORGE_AEGIS_GOLD := 40
const PEDESTAL_OVERFLOW_GOLD := 60
const PEDESTAL_XP_GOLD := 55
const PEDESTAL_XP := 260.0
const FORGE_OVERDRIVE_SPEED := 0.35
const CORE_SHIELD_MAX:=300.0
var event_bus := ArenaEventBus.new()
var passive_engine := ArenaPassiveEngine.new()
var relic_engine := ArenaRelicEngine.new()
var rift_domain: ArenaRiftDomain
var active_domain: String="defense"
var pickups: Array=[]
var passive_offers: Array[Dictionary]=[]
var active_event_offer: Dictionary={}
var next_run_seed: int = 0
var defense_rules := true
var boss_defeated := false
var required_boss_escaped := false
var level_id: String="forest"
var level_definition: Dictionary={}
var routes: Array[Curve2D]=[]
var actors: Node2D
var terrain: Node2D
var ground: Sprite2D
var hero: ArenaHero
var enemies: Array=[]
var route_lengths: Array[float]=[]
var enemy_revision:=0
var projectile_snapshot: Array=[]
var projectile_snapshot_tick:=-1
var projectile_snapshot_revision:=-1
var towers: Array=[]
var soldiers: Array=[]
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
var run_tower_doctrines: Dictionary = {}
var navigation:=AStarGrid2D.new()
var navigation_static:=PackedByteArray()
var navigation_dynamic: Array[Vector2i]=[]
var rng:=RandomNumberGenerator.new()
var camera: ArenaBattleCamera
var siege: ArenaRuinsSiege
var stage_gimmicks: ArenaStageGimmicks
var breach_open:=false
var running:=false
var started:=false
var game_over:=false
var victory:=false
var mouse_shoot_held:=false
var gold:=START_GOLD
var core_max:=750.0
var core_health:=750.0
var core_shield:=0.0
var core_overdrive_clock:=0.0
var cycle:=1
var phase: String="rest"
var phase_clock:=15.0
var rest_duration:=15.0
var wave_preview:=false
var rewarded:=false
var spawn_queue: Array=[]
var wave_elapsed:=0.0
var siege_alert_at:=85.0
var siege_start_at:=95.0
var siege_alert_active:=false
var siege_active:=false
var early_wave_calls:=0
var selected_site:=-1
var targeting_slot:=-1
var rally_site:=-1
var suppress_primary:=false
var kills:=0
var built:=0
var elapsed:=0.0
var damage_stats: Dictionary={"hero":0.0,"tower":0.0,"soldier":0.0}
var quitting:=false
var shake:=0.0
var feel:=ArenaFeel.new()
var feel_lab:=false
var lab: ArenaFeelLab
var tower_lab:=false
var tower_trial_stats: Dictionary={"arrows":0,"arrow_hits":0,"weakness_used":0,"pulses":0,"pulse_hits":0,"inner_hits":0,"shells":0,"shell_hits":0,"shell_core_hits":0}
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
const EXIT_WARD_COOLDOWN:=35.0
var exit_ward_cd:=0.0
var exit_ward_flash:=0.0
var exit_ward_last_target:=Vector2.ZERO
var exit_ward_triggers:=0
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
	tower_lab=not feel_lab and OS.get_cmdline_user_args().has("--tower-lab")
	defense_rules=not (feel_lab or tower_lab)
	if feel_lab:
		campaign=ArenaCampaign.new("",false)
		for key in ArenaDefinitions.HERO_IDS:campaign.data.levels[key]=5
	elif campaign==null and tower_lab:
		campaign=ArenaCampaign.playtest(ArenaCampaign.TOWER_TRIAL_PATH) if OS.get_cmdline_user_args().has("--playtest") else ArenaCampaign.new(ArenaCampaign.TOWER_TRIAL_PATH)
	elif campaign==null:campaign=ArenaCampaign.playtest() if OS.get_cmdline_user_args().has("--playtest") else ArenaCampaign.new()
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,float(campaign.data.volume))))
	hud=ArenaHUD.new();hud.game=self;add_child(hud)
	get_tree().auto_accept_quit=false
	if feel_lab:
		_open_feel_lab.call_deferred()
	elif get_tree().has_meta("restart_hero"):
		var key: String=get_tree().get_meta("restart_hero");var stage: String=get_tree().get_meta("restart_level","forest")
		if get_tree().has_meta("restart_towers"):run_towers.assign(get_tree().get_meta("restart_towers"));get_tree().remove_meta("restart_towers")
		if get_tree().has_meta("restart_tower_doctrines"):
			run_tower_doctrines = get_tree().get_meta("restart_tower_doctrines")
			get_tree().remove_meta("restart_tower_doctrines")
		get_tree().remove_meta("restart_hero");get_tree().remove_meta("restart_level");start_run.call_deferred(key,stage,true)
	elif get_tree().has_meta("open_hero_hall"):
		hud.frontend.hero_id=str(get_tree().get_meta("open_hero_hall"));get_tree().remove_meta("open_hero_hall");hud.frontend.hall()
	elif get_tree().has_meta("open_world_map"):
		hud.frontend.stage=str(get_tree().get_meta("open_world_map"));get_tree().remove_meta("open_world_map");hud.frontend.levels()
	else:
		var cli_stage:=""
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--stage="):cli_stage=arg.trim_prefix("--stage=")
		if cli_stage in ArenaLevelCatalog.IDS and campaign.can_deploy(cli_stage,defense_rules):
			start_run.call_deferred(campaign.selected_hero(),cli_stage)
		else:hud.show_entry()
func _open_feel_lab() -> void:
	var key: String=str(get_tree().get_meta("feel_lab_hero","lord"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lab-hero=") and not get_tree().has_meta("feel_lab_hero"):key=arg.trim_prefix("--lab-hero=")
	if get_tree().has_meta("feel_lab_hero"):get_tree().remove_meta("feel_lab_hero")
	key=ArenaDefinitions.resolve_hero_id(key)
	if key not in ArenaDefinitions.HERO_IDS:key="lord"
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
	if started or not ArenaDefinitions.is_valid_hero_id(hero_id) or stage not in ArenaLevelCatalog.IDS:return
	hero_id=ArenaDefinitions.resolve_hero_id(hero_id)
	if not keep_loadout:run_towers=campaign.tower_loadout()
	if tower_lab: run_towers.assign(ArenaDefinitions.DEFAULT_TOWERS)
	elif not campaign._valid_towers(run_towers): run_towers=campaign.tower_loadout()
	if not keep_loadout or run_tower_doctrines.is_empty():
		run_tower_doctrines.clear()
		for kind in run_towers:
			run_tower_doctrines[kind] = campaign.tower_doctrine(kind)
	if next_run_seed != 0:
		rng.seed = next_run_seed
		next_run_seed = 0
	gold=280 if tower_lab else START_GOLD
	run_id=str(Time.get_unix_time_from_system())+"-"+str(Time.get_ticks_usec())+"-"+str(randi());settlement={}
	level_id=stage;level_definition=ArenaLevelCatalog.definition(stage);breach_open=false;mouse_shoot_held=false;navigation_static.clear();navigation_dynamic.clear();routes.clear();route_lengths.clear();zones.clear();pickups.clear();passive_offers.clear();active_event_offer.clear()
	active_domain="defense";core_shield=0.0;core_overdrive_clock=0.0
	siege_alert_active=false;siege_active=false;early_wave_calls=0
	event_bus.clear();passive_engine.reset();passive_engine.bind(self,event_bus)
	relic_engine.reset();relic_engine.bind(self,event_bus)
	boss_defeated = false
	required_boss_escaped = false
	exit_ward_cd=0.0;exit_ward_flash=0.0;exit_ward_last_target=Vector2.ZERO;exit_ward_triggers=0
	for points in level_definition.routes:
		var c := ArenaLevelCatalog.curve(points)
		routes.append(c)
		route_lengths.append(c.get_baked_length())
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
		var is_v029_map := stage in ["saltport","lighthouse","ruins","sanctum"]
		if is_v029_map:
			ground.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			ground.material=null
		else:
			ground.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
			var paint_material:=ShaderMaterial.new();paint_material.shader=load("res://scripts/shaders/painted_ruins.gdshader");paint_material.set_shader_parameter("is_ruins",0.0);ground.material=paint_material
	for rect in level_definition.blocked:_collision(rect)
	_add_scenery()
	hero=ArenaHero.new();hero.game=self;hero.position=level_definition.hero_spawn;actors.add_child(hero);hero.configure(hero_id)
	if stage in ["ruins","sanctum"]:hero.visual.feedback.set_environment(hero.visual,Color(0.97,1.0,1.03),0.90)
	started=true;running=true;camera.configure()
	if stage=="ruins":siege=ArenaRuinsSiege.new();siege.game=self;add_child(siege)
	if stage in ["saltport","lighthouse","ruins","sanctum"]:
		stage_gimmicks=ArenaStageGimmicks.new();stage_gimmicks.game=self;add_child(stage_gimmicks)
	if not feel_lab and not tower_lab:
		rift_domain=ArenaRiftDomain.new();add_child(rift_domain);rift_domain.configure(self,stage)
	if ResourceLoader.exists("res://scripts/arena/arena_atmosphere.gd"):
		var atmo_script=load("res://scripts/arena/arena_atmosphere.gd")
		if atmo_script!=null and atmo_script.has_method("install"):
			atmosphere=atmo_script.call("install",self)
	rebuild_navigation();hud.show_battle();start_rest(15);queue_redraw()
func _collision(rect: Rect2) -> void:
	var body:=StaticBody2D.new();body.position=rect.get_center();body.collision_layer=1;body.collision_mask=2
	var collision:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=rect.size;collision.shape=shape;body.add_child(collision);terrain.add_child(body)

func prop(index: int,point: Vector2,width: float) -> void:
	if not ResourceLoader.exists("res://assets/v06/props.png"):return
	var sheet: Texture2D=load("res://assets/v06/props.png");var image:=AtlasTexture.new();image.atlas=sheet
	image.region=Rect2(index%4*sheet.get_width()/4.0,index/4*sheet.get_height()/2.0,sheet.get_width()/4.0,sheet.get_height()/2.0)
	var node:=Sprite2D.new();node.texture=image;node.position=point;node.offset.y=-image.get_height()*ArenaArtAnchors.offset_for("prop_"+str(index));node.scale=Vector2.ONE*width/image.get_width();node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR;actors.add_child(node)
func _add_scenery() -> void:
	ArenaExitGate.install(self)
	if level_id in ["saltport","lighthouse","ruins","sanctum"] or str(level_definition.get("biome",""))=="ruins":return
	for rect in level_definition.blocked:
		if rect in level_definition.get("water_rects",[]):continue
		if rect.size.y>220:continue
		prop(0 if rect.size.x<160 else 3,rect.get_center()+Vector2(0,rect.size.y*0.35),rect.size.x+40)
	for pair in [[Vector2(55,115),0],[Vector2(1505,130),1],[Vector2(1570,800),0],[Vector2(585,830),1],[Vector2(980,830),7]]:prop(pair[1],pair[0],125)
func static_walkable(point: Vector2) -> bool:
	if point.x<12 or point.y<88 or point.x>world_size().x-12 or point.y>world_size().y-12:return false
	for rect in level_definition.get("blocked",[]):
		if rect.grow(12).has_point(point):return false
	return true
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
		if key in run_towers and (tower_lab or (defense_rules and level_id=="forest") or int(level_definition.towers.get(key,99))<=cycle):result.append(key)
	return result

func tower_display_data(kind: String) -> Dictionary:
	if tower_lab and kind in ArenaDefinitions.DEFAULT_TOWERS: return ArenaTowerTrial.offer(kind)
	if defense_rules and kind in ArenaDefinitions.DEFAULT_TOWERS: return ArenaTowerTrial.defense_offer(kind)
	return ArenaDefinitions.tower(kind)
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
	if not can_change_towers() or not site_locked(index):return false
	var price:=unlock_price(index)
	if gold<price:return false
	gold-=price;unlocked_sites.append(index)
	effect(level_definition.sites[index],60,Color("f4d28b"),"upgrade",0.6);audio.play("tower")
	if is_instance_valid(hud):hud.refresh_context()
	return true
func build_tower(index: int,kind: String) -> bool:
	if not can_change_towers() or index<0 or index>=level_definition.sites.size() or kind not in available_towers() or site_tower(index)!=null or site_locked(index):return false
	var cost: int=int(ArenaDefinitions.TOWERS[kind].cost)
	if gold<cost:return false
	gold-=cost;var tower:=ArenaTower.new();tower.game=self;tower.kind=kind;tower.site_id=index;tower.position=level_definition.sites[index]
	if timed_tower_work(): tower.start_construction(cost)
	else: tower.invested_gold=cost
	actors.add_child(tower);towers.append(tower);built+=1;rebuild_navigation();audio.play("tower");hud.refresh_context();return true
func domain_enemies(dom: String="") -> Array:
	var target_dom := active_domain if dom.is_empty() else dom
	var res: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.domain == target_dom:
			res.append(e)
	return res

func pump_modals() -> void:_pump_modals.call_deferred()
func _pump_modals() -> void:
	if game_over:return
	if is_instance_valid(hud) and hud.has_modal():return
	if not passive_offers.is_empty():
		get_tree().paused=true
		hud.show_passive_choice(passive_offers)
func start_rest(duration: float) -> void:
	phase="rest";phase_clock=maxf(8.0,duration);rest_duration=phase_clock;wave_preview=false;rewarded=false
	siege_alert_active=false;siege_active=false
	hud.announce_unlock()

func open_pending_passive_choice() -> bool:
	if not running or game_over or feel_lab or tower_lab:
		return false
	if passive_engine == null or passive_engine.pending_ups <= 0 or not passive_offers.is_empty():
		return false
	if is_instance_valid(hud) and hud.has_modal():
		return false
	_offer_passive_choice()
	return not passive_offers.is_empty()

func _offer_passive_choice() -> void:
	if not passive_offers.is_empty() or passive_engine.pending_ups <= 0 or feel_lab or tower_lab:
		return
	passive_offers = passive_engine.draw_offers(rng, 3)
	if passive_offers.is_empty():
		passive_engine.pending_ups = 0
		return
	get_tree().paused = true
	_pump_modals()

func choose_passive(id: String) -> bool:
	if not running or game_over or passive_offers.is_empty():
		return false
	var idx := passive_offers.find_custom(func(c): return str(c.id) == id)
	if idx < 0:
		return false
	if not passive_engine.apply_choice(id):
		return false
	passive_offers.clear()
	hud.close_modal()
	if is_instance_valid(hud) and hud.has_method("refresh_owned_passives"):
		hud.refresh_owned_passives()
	get_tree().paused = false
	suppress_primary = Input.is_action_pressed("shoot")
	if is_instance_valid(hero):
		hero.recompute()
	if passive_engine.pending_ups > 0:
		open_pending_passive_choice.call_deferred()
	return true

func gain_run_xp(amount: float, _at_pos := Vector2.INF) -> void:
	if amount <= 0.0 or game_over or not running or feel_lab or tower_lab:
		return
	var gained := passive_engine.add_xp(amount)
	if gained > 0:
		if is_instance_valid(hero):
			numbers.append({
				"point": hero.center() + Vector2(0.0, -38.0),
				"text": "★ 进化就绪! 按[Tab]选被动",
				"colour": Color("ffe97a"),
				"life": 1.2,
				"duration": 1.2,
				"critical": true
			})
		audio.play("phase", -10.0, 1.35)
		if is_instance_valid(hud) and hud.has_method("pulse_passive_badge"):
			hud.pulse_passive_badge()

func open_rift_event(room_id: String) -> bool:
	if not running or game_over or feel_lab or tower_lab or rift_domain == null:
		return false
	if not active_event_offer.is_empty() or not passive_offers.is_empty():
		return false
	if is_instance_valid(hud) and hud.has_modal():
		return false
	if not rift_domain.rooms.has(room_id):
		return false
	var rm: Dictionary = rift_domain.rooms[room_id]
	if bool(rm.get("event_used", false)):
		return false
	var ekind := str(rm.get("event_kind", "star_pedestal"))
	var opts: Array[Dictionary] = []
	if ekind == "blood_altar":
		opts = [
			{"id": "sac_hp_relic", "title": "鲜血献祭 · 夺取遗物", "tag": "遗物", "desc": "献出最多 25%% 当前生命（生命不会因此低于 15），随机获得一件遗物。已持满 %d 件则获得 %d 金币。" % [ArenaRelicEngine.MAX_RELICS,BLOOD_ALTAR_OVERFLOW_GOLD]},
			{"id": "sac_gold_atk", "title": "战神血誓 · 持续增伤", "tag": "%d 金" % BLOOD_ALTAR_ATTACK_COST, "desc": "消耗 %d 金币，本局英雄伤害加成 +16%%。" % BLOOD_ALTAR_ATTACK_COST, "cost_gold": BLOOD_ALTAR_ATTACK_COST},
			{"id": "sanctum_rest", "title": "星血沐浴 · 稳健复苏", "tag": "治疗", "desc": "回复 55%% 最大生命，有护盾上限时溢疗可转为护盾。获得 %d 基础经验。" % BLOOD_ALTAR_REST_XP}
		]
	elif ekind == "forge_anvil":
		opts = [
			{"id": "forge_power", "title": "重铸塔锋 · 威力增幅", "tag": "本局增益", "desc": "本局攻击塔伤害加成 +18%，基地获得至多 85 圣盾。"},
			{"id": "forge_speed", "title": "精密齿轮 · 极速填装", "tag": "本局增益", "desc": "本局攻击塔攻速加成 +18%。"},
			{"id": "forge_aegis", "title": "堡垒金钟 · 厚盾强援", "tag": "即时救急", "desc": "基地获得至多 220 圣盾，攻击塔攻速 +%d%% 持续 10 秒，另获 %d 金币。" % [roundi(FORGE_OVERDRIVE_SPEED*100.0),FORGE_AEGIS_GOLD]}
		]
	else:
		opts = [
			{"id": "pedestal_relic", "title": "摘取星辉遗物", "tag": "遗物", "desc": "随机获得一件遗物。已持满 %d 件则获得 %d 金币和至多 90 基地圣盾。" % [ArenaRelicEngine.MAX_RELICS,PEDESTAL_OVERFLOW_GOLD]},
			{"id": "pedestal_xp", "title": "汲取星核宝库", "tag": "急速进化", "desc": "立即获得 %d 基础经验和 %d 金币。" % [PEDESTAL_XP,PEDESTAL_XP_GOLD]},
			{"id": "pedestal_ward", "title": "祈愿双域固防", "tag": "防线加固", "desc": "基地最多回复 120 耐久并获得至多 160 圣盾，英雄恢复全部生命。"}
		]
	active_event_offer = {
		"room_id": room_id,
		"event_kind": ekind,
		"title": "血契魔坛" if ekind == "blood_altar" else ("防线工匠铁砧" if ekind == "forge_anvil" else "星辉秘宝台"),
		"subtitle": "抉择一份深渊馈赠 · 按 1 / 2 / 3 或点击选项（含0.45秒防误触保护）",
		"options": opts
	}
	get_tree().paused = true
	if is_instance_valid(hud) and hud.has_method("show_rift_event_modal"):
		hud.show_rift_event_modal(active_event_offer)
	return true

func close_rift_event_without_use() -> void:
	active_event_offer.clear()
	if is_instance_valid(hud):
		hud.close_modal()
	get_tree().paused = false
	suppress_primary = Input.is_action_pressed("shoot")

func choose_rift_event(option_idx: int) -> bool:
	if active_event_offer.is_empty():
		return false
	var opts: Array = active_event_offer.get("options", [])
	if option_idx < 0 or option_idx >= opts.size():
		return false
	var opt: Dictionary = opts[option_idx]
	var cost_g := int(opt.get("cost_gold", 0))
	if gold < cost_g:
		return false
	gold -= cost_g
	var rid := str(active_event_offer.get("room_id", ""))
	if rift_domain != null and rift_domain.rooms.has(rid):
		rift_domain.rooms[rid].event_used = true
	var oid := str(opt.id)
	var h: ArenaHero = hero
	match oid:
		"sac_hp_relic":
			if is_instance_valid(h) and not h.knocked_out:
				h.health -= minf(h.health*0.25,maxf(0.0,h.health-15.0))
			var rel1 := relic_engine.grant_random_relic(rng)
			if rel1.is_empty():
				gain_gold(BLOOD_ALTAR_OVERFLOW_GOLD, "rift_event")
		"sac_gold_atk":
			relic_engine.altar_hero_dmg_bonus += 0.16
			if is_instance_valid(h):
				numbers.append({"point": h.center() + Vector2(0, -34), "text": "血誓 · 攻击永久+16%!", "colour": Color("ff7890"), "life": 1.2, "duration": 1.2, "critical": true})
		"sanctum_rest":
			if is_instance_valid(h) and not h.knocked_out:
				h._heal_self(h.max_health * 0.55, true)
			gain_run_xp(BLOOD_ALTAR_REST_XP)
		"forge_power":
			relic_engine.forge_tower_power_bonus += 0.18
			add_core_shield(85.0)
			if is_instance_valid(h):
				numbers.append({"point": h.center() + Vector2(0, -34), "text": "铁砧锻造 · 攻击塔伤害 +18%", "colour": Color("7fe8ff"), "life": 1.2, "duration": 1.2, "critical": true})
		"forge_speed":
			relic_engine.forge_tower_speed_bonus += 0.18
			if is_instance_valid(h):
				numbers.append({"point": h.center() + Vector2(0, -34), "text": "铁砧齿轮 · 攻击塔攻速 +18%", "colour": Color("7fe8ff"), "life": 1.2, "duration": 1.2, "critical": true})
		"forge_aegis":
			add_core_shield(220.0)
			core_overdrive_clock = maxf(core_overdrive_clock, 10.0)
			gain_gold(FORGE_AEGIS_GOLD, "rift_event")
		"pedestal_relic":
			var rel2 := relic_engine.grant_random_relic(rng)
			if rel2.is_empty():
				gain_gold(PEDESTAL_OVERFLOW_GOLD, "rift_event")
				add_core_shield(90.0)
		"pedestal_xp":
			gain_gold(PEDESTAL_XP_GOLD, "rift_event")
			gain_run_xp(PEDESTAL_XP)
		"pedestal_ward":
			core_health = minf(core_max, core_health + 120.0)
			add_core_shield(160.0)
			if is_instance_valid(h) and not h.knocked_out:
				h._heal_self(h.max_health, true)
	active_event_offer.clear()
	if is_instance_valid(hud):
		hud.close_modal()
		if hud.has_method("refresh_owned_relics"):
			hud.refresh_owned_relics()
	get_tree().paused = false
	suppress_primary = Input.is_action_pressed("shoot")
	if is_instance_valid(h):
		h.recompute()
	audio.play("phase", -7.0, 1.32)
	return true

func gain_gold(amount: int, source: String) -> void:
	if amount <= 0:
		return
	gold += amount
	if event_bus != null:
		event_bus.emit_event("gold_earned", {"amount": amount, "source": source})

func add_core_shield(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before := core_shield
	core_shield = minf(CORE_SHIELD_MAX, core_shield + amount)
	return core_shield-before

func clear_rift_attacks() -> void:
	for actor in actors.get_children():
		if actor is ArenaProjectile and actor.domain == "rift":
			actor.set_physics_process(false)
			actor.queue_free()
	delayed = delayed.filter(func(attack): return attack.options.get("domain", "defense") != "rift")
	zones = zones.filter(func(zone): return zone.domain != "rift")
	for enemy in domain_enemies("rift"):
		enemy.burn_clock = 0.0
		enemy.burn_dps = 0.0
	passive_engine.clear_rift_attacks()

func enter_rift() -> bool:
	return rift_domain != null and rift_domain.enter_rift()

func recall_to_defense() -> bool:
	return rift_domain != null and rift_domain.recall_to_defense()

func toggle_domain() -> void:
	if active_domain == "rift":
		recall_to_defense()
	elif not enter_rift() and rift_domain != null and running and not feel_lab and not tower_lab:
		if rift_domain.portal_cooldown > 0.0:hud.show_order_notice("传送门充能中 · %d 秒" % ceili(rift_domain.portal_cooldown))
		elif is_instance_valid(hero) and hero.knocked_out:hud.show_order_notice("英雄复活后可进入裂隙")

func spawn_pickup(pos: Vector2, dom: String, kind: String, xp_val: int, gold_val := 0) -> ArenaXpPickup:
	var dom_pickups: Array = []
	for p in pickups:
		if is_instance_valid(p) and not bool(p._collected) and str(p.domain) == dom:
			dom_pickups.append(p)
	if dom_pickups.size() >= 72:
		var best_p: ArenaXpPickup = null
		var best_d := 180.0
		for raw_p in dom_pickups:
			var cand := raw_p as ArenaXpPickup
			var d := cand.position.distance_to(pos)
			if d < best_d:
				best_d = d
				best_p = cand
		if best_p == null and not dom_pickups.is_empty():
			best_p = dom_pickups[0] as ArenaXpPickup
		if best_p != null:
			best_p.xp_value += xp_val
			best_p.gold_value += gold_val
			if best_p.kind == "cyan" and xp_val >= 30:
				best_p.kind = "violet"
			best_p.scale = Vector2.ONE * minf(1.45, best_p.scale.x + 0.08)
			best_p.queue_redraw()
			return best_p
	var item := ArenaXpPickup.new()
	item.game = self
	item.domain = dom
	item.kind = kind
	item.xp_value = xp_val
	item.gold_value = gold_val
	item.position = pos
	var ang := rng.randf_range(0.0, TAU)
	item.pop_vel = Vector2.from_angle(ang) * rng.randf_range(65.0, 125.0)
	actors.add_child(item)
	pickups.append(item)
	return item

func _can_call_wave() -> bool:
	if not can_manage_defense() or active_domain != "defense" or get_tree().paused:
		return false
	if not passive_offers.is_empty() or not active_event_offer.is_empty():
		return false
	return rift_domain == null or rift_domain.warp_phase.is_empty()

func can_preview_wave() -> bool:
	return phase == "rest" and _can_call_wave()

func preview_wave_bonus() -> int:
	return mini(12, floori(12.0*clampf(phase_clock/maxf(rest_duration,1.0),0.0,1.0))) if can_preview_wave() and not rewarded else 0

func request_wave() -> void:
	if not can_preview_wave():
		return
	if not wave_preview:wave_preview=true;return
	if not rewarded:
		gain_gold(preview_wave_bonus(), "wave_call"); rewarded = true
	begin_wave()

func next_wave_button_state() -> Dictionary:
	if not _can_call_wave():
		return {"mode": "disabled", "label": "防线未启", "bonus_gold": 0, "enabled": false, "tip": ""}
	if phase == "rest":
		var bonus_r := clampi(int(round(clampf(phase_clock / maxf(1.0, rest_duration), 0.25, 1.0) * 28.0 * relic_engine.early_wave_bonus_mult())), 6, 24)
		return {"mode": "rest", "label": "▶ 立刻开第%d轮 (+%dg) [F]" % [cycle, bonus_r], "bonus_gold": bonus_r, "enabled": true, "tip": "立刻结束整备开启第 %d 轮并获 +%d 早开赏金 [快捷键 F]" % [cycle, bonus_r]}
	if wave_elapsed < siege_start_at - 0.8:
		var rem_s := siege_start_at - 0.5 - wave_elapsed
		var bonus_f := clampi(int(round((16.0 + rem_s * 0.42) * relic_engine.early_wave_bonus_mult())), 18, 50)
		return {"mode": "fast_siege", "label": "⚡ 提前召攻城 (+%dg) [F]" % bonus_f, "bonus_gold": bonus_f, "enabled": true, "tip": "缩短 %ds 游击窗，余下游击队在 10 秒内依次出场，立即获 +%d 金 [F]" % [ceili(rem_s), bonus_f]}
	if spawn_queue.is_empty() and cycle < total_waves():
		var bonus_s := int(round(40.0 * relic_engine.early_wave_bonus_mult()))
		return {"mode": "stack_next", "label": "🔥 叠开第%d轮 (+%dg) [F]" % [cycle + 1, bonus_s], "bonus_gold": bonus_s, "enabled": true, "tip": "不干等清怪，直接叠开第 %d 轮并奖 +%d 金（适合塔防成型的割草高手 [F]）" % [cycle + 1, bonus_s]}
	if cycle >= total_waves() and spawn_queue.is_empty():
		var tip := "击退剩余敌潮并击败指定首领" if bool(level_definition.boss) and not boss_defeated else "击退剩余敌潮，守住核心即可获胜"
		return {"mode": "final_busy", "label": "⚔ 最终轮决战中", "bonus_gold": 0, "enabled": false, "tip": tip}
	return {"mode": "siege_spawning", "label": "⚔ 攻城出兵中 (%d/%d)" % [cycle, total_waves()], "bonus_gold": 0, "enabled": false, "tip": "本轮攻城大军正在出动，出兵完毕后可按 [F] 提前叠开下一轮"}

func request_next_wave_anytime() -> Dictionary:
	var st := next_wave_button_state()
	var mode := str(st.mode)
	var bonus := int(st.bonus_gold)
	if not bool(st.enabled):
		return {"ok": false, "mode": mode}
	if mode == "rest":
		if not rewarded:
			gain_gold(bonus, "wave_call")
			rewarded = true
		wave_preview = true
		early_wave_calls += 1
		begin_wave()
		numbers.append({"point": level_definition.core + Vector2(-40, -40), "text": "★ 提前开轮 +%d金!" % bonus, "colour": Color("ffe678"), "life": 1.0, "duration": 1.0, "critical": true})
		audio.play("phase", -8.0, 1.18)
		return {"ok": true, "mode": mode, "bonus": bonus}
	if mode == "fast_siege":
		var target_t := siege_start_at - 0.5
		var skirmish := spawn_queue.filter(func(packet): return float(packet.at) < siege_start_at)
		for index in range(skirmish.size()):
			skirmish[index].at = target_t + 10.0 * float(index) / maxi(1, skirmish.size() - 1)
		spawn_queue.sort_custom(ArenaLevelCatalog.packet_precedes)
		wave_elapsed = target_t
		siege_alert_active = true
		gain_gold(bonus, "wave_call")
		early_wave_calls += 1
		numbers.append({"point": level_definition.core + Vector2(-48, -42), "text": "⚡ 攻城号角 · 提前召潮 +%d金!" % bonus, "colour": Color("ffe678"), "life": 1.15, "duration": 1.15, "critical": true})
		audio.play("heavy_hit", -8.0, 1.24)
		audio.play("phase", -8.0, 1.12)
		return {"ok": true, "mode": mode, "bonus": bonus}
	if mode == "stack_next":
		cycle += 1
		_start_defense_wave()
		gain_gold(bonus, "wave_call")
		early_wave_calls += 1
		numbers.append({"point": level_definition.core + Vector2(-46, -42), "text": "🔥 叠开第 %d 轮 +%d金!" % [cycle, bonus], "colour": Color("ff9e58"), "life": 1.20, "duration": 1.20, "critical": true})
		audio.play("phase", -7.0, 1.28)
		return {"ok": true, "mode": mode, "bonus": bonus}
	return {"ok": false, "mode": mode}
func begin_wave() -> void:
	if not running or game_over or phase != "rest" or not passive_offers.is_empty() or not active_event_offer.is_empty():
		return
	_start_defense_wave()

func _start_defense_wave() -> void:
	phase = "spawn"
	wave_preview = false
	wave_elapsed = 0.0
	siege_alert_active = false
	siege_active = false
	spawn_queue = wave_packets(wave_pattern())
	if stage_gimmicks != null:
		stage_gimmicks.on_wave_started(cycle)
	if is_instance_valid(hud):
		hud.refresh_context()
func wave_packets(pattern: Dictionary) -> Array:
	var closed_route := -1
	if level_id == "ruins" and not breach_open:
		closed_route = 2
	elif level_id == "sanctum" and (cycle < 3 or (stage_gimmicks != null and stage_gimmicks.is_rift_suppressed())):
		closed_route = 3
	var seed_for_reinforcements: Variant = null
	if defense_rules:
		seed_for_reinforcements = rift_domain.run_seed if rift_domain != null else 1
	return ArenaLevelCatalog.plan_wave(pattern, level_definition, cycle, closed_route, seed_for_reinforcements, siege_start_at)

func wave_pattern() -> Dictionary:
	var authored:=ArenaLevelCatalog.wave(level_id,cycle)
	if defense_rules and level_id=="ruins" and cycle==3:
		authored.lead=-1
		authored.route_pool=[0,1,2] if breach_open else [0,1]
	return authored
func spawn_enemy(kind: String,lane: int,offset := 0.0,elite := false,swarm_fodder := false) -> ArenaEnemy:
	if lane<0 or lane>=routes.size():return null
	var enemy:=ArenaEnemy.new();enemy.game=self;enemy.kind=kind;enemy.route_id=lane;enemy.progress=offset;enemy.elite=elite;enemy.is_swarm_fodder=swarm_fodder
	enemy.position=routes[lane].sample_baked(offset,true)
	register_enemy(enemy)
	return enemy
func register_enemy(enemy: ArenaEnemy) -> void:
	actors.add_child(enemy)
	enemies.append(enemy)
	enemy_revision+=1
func projectile_candidates() -> Array:
	var tick:=Engine.get_physics_frames()
	if tick!=projectile_snapshot_tick or projectile_snapshot_revision!=enemy_revision or projectile_snapshot.size()!=enemies.size():
		projectile_snapshot=enemies.duplicate();projectile_snapshot_tick=tick;projectile_snapshot_revision=enemy_revision
	return projectile_snapshot
func nearest_enemy(point: Vector2,distance: float,include_guards:=true,dom:="defense") -> ArenaEnemy:
	var best: ArenaEnemy;var squared: float=distance*distance
	for enemy in domain_enemies(dom):
		if not is_instance_valid(enemy) or enemy.dead or (enemy.is_guard and not include_guards):continue
		var d: float=point.distance_squared_to(enemy.center())
		if d<squared:squared=d;best=enemy
	return best
func total_waves() -> int:
	return ArenaLevelCatalog.total_waves(level_id)

func active_boss() -> ArenaEnemy:
	var fallback: ArenaEnemy = null
	for enemy in domain_enemies("defense"):
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		if enemy.is_boss():
			return enemy
		if enemy.has_method("is_mini_boss") and enemy.is_mini_boss() and fallback == null:
			fallback = enemy
	return fallback

func tower_target(tower: ArenaTower) -> ArenaEnemy:
	if tower_lab and tower.kind in ["archer","cannon"]: return tower.plan_trial_attack(0.0).get("target")
	return tower_target_from(tower)

func tower_target_from(tower: ArenaTower) -> ArenaEnemy:
	var best: ArenaEnemy;var score:=-INF
	var reach_squared:=pow(tower.attack_range(),2)
	var can_aa := tower.can_hit_flying()
	var fixed_blast := tower.bombard_point.is_finite()
	var origin := tower.firing_position()
	if not origin.is_finite(): return null
	for enemy in domain_enemies("defense"):
		if not is_instance_valid(enemy) or enemy.dead or (not can_aa and enemy.is_flying()) or enemy.position.distance_squared_to(origin)>reach_squared:continue
		if fixed_blast:
			var core:=tower.trial_shell_core()
			var predicted: Vector2=enemy.position+enemy.travel_velocity()*0.68
			if minf(enemy.position.distance_to(tower.bombard_point),predicted.distance_to(tower.bombard_point))>core: continue
		var next: float=enemy.progress/enemy_road(enemy).get_baked_length()
		if tower.target_mode=="strongest":next=enemy.health
		elif tower.kind=="lens" and enemy==tower.focus_target: next=INF
		if next>score:score=next;best=enemy
	if best!=null and defense_rules and tower.kind=="cannon" and tower.target_mode=="first" and not fixed_blast:
		return tower.plan_trial_attack(0.0).get("target",best)
	return best

func trial_tower_targets(tower: ArenaTower) -> Array[ArenaEnemy]:
	var result: Array[ArenaEnemy]=[]
	var radius_squared:=pow(tower.attack_range(),2)
	var origin:=tower.firing_position()
	for enemy in domain_enemies("defense"):
		if trial_tower_can_hit(enemy) and (tower.can_hit_flying() or not enemy.is_flying()) and enemy.position.distance_squared_to(origin)<=radius_squared: result.append(enemy)
	return result

func trial_tower_can_hit(enemy: ArenaEnemy) -> bool:
	return is_instance_valid(enemy) and not enemy.dead

func _unregister_enemy(enemy: ArenaEnemy) -> bool:
	if not is_instance_valid(enemy):
		return false
	var index := enemies.find(enemy)
	if index < 0:
		return false
	enemy.dead = true
	blocking.release_enemy(enemy)
	enemies.remove_at(index)
	enemy_revision += 1
	return true

func remove_enemy(enemy: ArenaEnemy) -> void:
	if _unregister_enemy(enemy):
		enemy.queue_free()

func _is_required_boss(enemy: ArenaEnemy) -> bool:
	if enemy.domain != "defense" or enemy.is_guard or not bool(level_definition.boss):
		return false
	return enemy.kind == str(level_definition.get("boss_kind", "moth")) and (enemy.is_boss() or enemy.is_mini_boss())

func enemy_escaped(enemy: ArenaEnemy) -> void:
	if not _unregister_enemy(enemy):
		return
	var required := _is_required_boss(enemy)
	if required:
		required_boss_escaped = true
	var leak_damage := int(core_max) if enemy.is_boss() else ArenaDefinitions.leak_damage(enemy.kind, enemy.elite)
	if not enemy.is_boss() and enemy.is_swarm_fodder:
		leak_damage = maxi(6, int(round(float(leak_damage) * 0.75)))
	if event_bus != null:
		event_bus.emit_event("enemy_escaped", {"kind": enemy.kind, "wave": cycle, "health": enemy.health, "max_health": enemy.max_health, "required": required})
	core_hit(leak_damage)
	enemy.queue_free()

func enemy_defeated(enemy: ArenaEnemy, source := "", direct := false, void_followup := false) -> void:
	if not _unregister_enemy(enemy):
		return
	if _is_required_boss(enemy):
		boss_defeated = true
	kills+=1
	var was_ctrl := float(enemy.slow)>0.0 or float(enemy.stun)>0.0 or float(enemy.marked)>0.0 or float(enemy.tower_control_clock)>0.0 or int(enemy.tower_frost_layers)>0
	var v_cursed := int(enemy.get_meta("void_cursed", 0))
	if event_bus != null:
		event_bus.emit_event("enemy_killed", {
			"enemy": enemy, "position": enemy.position, "domain": enemy.domain, "was_controlled": was_ctrl,
			"void_cursed": v_cursed, "source": source, "direct": direct, "void_followup": void_followup
		})
	if enemy.is_rift_mob:
		if rift_domain != null:
			rift_domain.on_rift_mob_killed(enemy)
		if not feel_lab and not tower_lab:
			var g_mult := relic_engine.gold_xp_mult()
			if enemy.is_bounty_elite:
				for i in range(2):
					spawn_pickup(enemy.position, "rift", "violet", 36, 0)
				spawn_pickup(enemy.position, "rift", "gold_core", 58, 0)
				spawn_pickup(enemy.position, "rift", "bounty_bag", 28, int(round(16.0 * g_mult)))
			elif enemy.elite:
				spawn_pickup(enemy.position, "rift", "violet", 30, int(round(2.0 * g_mult)))
			else:
				spawn_pickup(enemy.position, "rift", "cyan", 12)
	else:
		var base_g := float(enemy.data.gold) * (0.62 if enemy.is_swarm_fodder else 1.0) * relic_engine.gold_xp_mult()
		var bounty_floor := 5
		if defense_rules:
			base_g *= DEFENSE_BOUNTY_SCALE[clampi(cycle - 1, 0, DEFENSE_BOUNTY_SCALE.size() - 1)]
			bounty_floor = 1
		gain_gold(maxi(bounty_floor, int(round(base_g))), "defense_bounty")
		if not feel_lab and not tower_lab:
			gain_run_xp(float(enemy.data.get("xp", 10)) * 0.10, enemy.position)
	if not enemy.is_rift_mob and enemy.kind=="twilight_avenger":
		delayed_attack(enemy.position,86.0,48.0*enemy.damage_scale(),1,"enemy",0.35,{"telegraph":"crystal_spikes","hits_soldiers":true,"fx_kind":"blast","fx_color":Color("c45eff"),"domain":"defense"})
		for tower in towers:
			if is_instance_valid(tower) and not tower.destroyed and tower.position.distance_to(enemy.position)<=94.0:
				tower.apply_jam(2.5,0.35)
		for ally in domain_enemies("defense"):
			if is_instance_valid(ally) and not ally.dead and not ally.is_guard and ally.position.distance_to(enemy.position)<=140.0:
				ally.roar_buff_clock=maxf(ally.roar_buff_clock,3.5)
	elif not enemy.is_rift_mob and enemy.kind=="avenger_rider" and not enemy.is_guard:
		spawn_enemy("twilight_avenger",enemy.route_id,enemy.progress,enemy.elite)
		effect(enemy.center(),40.0,Color("b668ff"),"summon",0.40)
	elif not enemy.is_rift_mob and enemy.kind=="twilight_golem":
		delayed_attack(enemy.position,92.0,40.0*enemy.damage_scale(),1,"enemy",0.25,{"telegraph":"crystal_spikes","hits_soldiers":true,"debuff":{"kind":"stun","duration":0.80},"fx_kind":"slam","fx_color":Color("cb74ff"),"domain":"defense"})
	if not enemy.is_rift_mob and stage_gimmicks!=null:
		stage_gimmicks.on_enemy_killed(enemy)
	if kind_has_visual(enemy):
		var ghost: ArenaCreature=enemy.visual;ghost.reparent(actors,true);ghost.show_pose("down",enemy.facing);corpses.append({"node":ghost,"life":0.65})
	if level_id in ["ruins","sanctum"]:
		var shard_col:=Color("c884ff") if enemy.kind in ["soul_reaver","vile_eyenest","void_gazer","baj_nimen"] else Color("c9b99a")
		effect(enemy.center(),24.0 if enemy.elite else 18.0,shard_col,"shield_break" if enemy.kind in ["twilight_golem","bloodsoil_behemoth","bloodsoil_boss","baj_nimen"] else "magic_impact_painted",0.26)
		ArenaBattleArt.emit_world_dust(enemy.position+Vector2(-6,2),Vector2(-24,-18),22.0,Color("b4b0be"))
		ArenaBattleArt.emit_world_dust(enemy.position+Vector2(6,2),Vector2(24,-14),20.0,Color("9b96a6"))
	elif level_id in ["saltport","lighthouse"]:
		effect(enemy.center(),22.0 if enemy.elite else 16.0,Color("66e8f2"),"abyss_burst",0.28)
		ArenaBattleArt.emit_world_dust(enemy.position,Vector2(0,-16),20.0,Color("7fdce6"))
	else:
		ArenaBattleArt.emit_world_dust(enemy.position,Vector2(0,-16),18.0,Color("a49d86"))
	enemy.queue_free()
func kind_has_visual(enemy: ArenaEnemy) -> bool:
	return is_instance_valid(enemy.visual) and enemy.visual.sprite_frames.has_animation("down")
func exit_ward_ready() -> bool:
	return not tower_lab and exit_ward_cd <= 0.0

func try_exit_ward_teleport(enemy: ArenaEnemy, road: Curve2D) -> bool:
	if not exit_ward_ready() or not is_instance_valid(enemy) or enemy.dead or enemy.is_guard or enemy.is_boss() or road == null:
		return false
	var from_pt := enemy.center()
	exit_ward_cd = EXIT_WARD_COOLDOWN
	exit_ward_flash = 0.55
	exit_ward_last_target = from_pt
	exit_ward_triggers += 1
	blocking.release_enemy(enemy)
	enemy.melee_windup = 0.0
	enemy.windup = 0.0
	enemy.ability_windup = 0.0
	enemy.ability_kind = ""
	enemy.charge_left = 0.0
	enemy.chase_left = 0.0
	enemy.returning = false
	effect(from_pt, 38.0, Color("6ce8ff"), "blast", 0.36)
	audio.play("phase", -8)
	if enemy.is_mini_boss():
		enemy.push_back(90.0)
		enemy.chill(0.45, 3.0)
		enemy.stun = maxf(enemy.stun, 0.60)
		numbers.append({"point": enemy.center() + Vector2(0.0, -24.0), "text": "防线震退!", "colour": Color("8ceeff"), "life": 0.9, "duration": 0.9})
		return true
	var dest_progress := maxf(24.0, road.get_baked_length() * 0.45)
	enemy.progress = minf(enemy.progress, dest_progress)
	enemy.position = road.sample_baked(enemy.progress, true)
	enemy.stun = maxf(enemy.stun, 0.55)
	enemy.queue_redraw()
	effect(enemy.center(), 42.0, Color("86f2ff"), "upgrade", 0.42)
	ArenaBattleArt.emit_world_dust(enemy.position, Vector2(0.0, -18.0), 22.0, Color("a2ecff"))
	numbers.append({"point": enemy.center() + Vector2(0.0, -24.0), "text": "防线传送!", "colour": Color("8ceeff"), "life": 0.9, "duration": 0.9})
	return true

func core_hit(amount: float) -> void:
	if game_over or amount <= 0.0:
		return
	var absorbed := minf(core_shield, amount)
	core_shield -= absorbed
	var remaining := amount - absorbed
	if remaining > 0.0:
		core_health=maxf(0,core_health-remaining)
	audio.play("hurt")
	if active_domain == "defense":
		shake=2.5
		if feel.enabled:feel.trauma=minf(1.0,feel.trauma+0.65)
	if rift_domain != null:
		rift_domain.note_core_hit()
	if core_health<=0:finish(false)
func fire_projectile(origin: Vector2,target: Vector2,amount: float,kind: int,source: String,options: Dictionary={}) -> ArenaProjectile:
	var shot:=ArenaProjectile.new();shot.game=self;shot.position=origin;shot.direction=(target-origin).normalized();shot.damage=amount;shot.damage_type=kind;shot.source=source
	shot.domain=str(options.get("domain", "defense" if source == "tower" else active_domain))
	shot.speed=float(options.get("speed",590.0));shot.appearance=options.get("appearance","magic" if kind==1 else "arrow");shot.pierce=int(options.get("pierce",0));shot.expose=bool(options.get("expose",false));shot.target=options.get("target");shot.splash=float(options.get("splash",0));shot.burn=float(options.get("burn",0))
	shot.pen=float(options.get("pen",0));shot.mark=float(options.get("mark",0));shot.mark_bonus=float(options.get("mark_bonus",0))
	shot.slow_amount=float(options.get("slow_amount",0));shot.slow_time=float(options.get("slow_time",0))
	shot.freeze_stacks=int(options.get("freeze_stacks",0));shot.freeze_time=float(options.get("freeze_time",0))
	shot.knockback=float(options.get("knockback",0));shot.tower=options.get("tower");shot.bounce=int(options.get("bounce",0))
	shot.presentation=str(options.get("presentation",""));shot.feedback_tag=str(options.get("feedback","attack"))
	shot.tower_kind=str(options.get("tower_kind",""));shot.tower_level=int(options.get("tower_level",1));shot.doctrine_id=str(options.get("doctrine_id",""))
	if options.has("debuffs") and options.debuffs is Array:shot.debuffs=options.debuffs.duplicate(true)
	shot.condition_hit=options.get("condition_hit",{})
	shot.trial_pierce_scales.assign(options.get("trial_pierce_scales",[]))
	shot.trial_flight_left=float(options.get("trial_flight_left",0.0))
	shot.arc_height=float(options.get("arc_height",0.0))
	shot.arc_origin=origin
	shot.arc_total_dist=maxf(24.0,origin.distance_to(target))
	shot.draw_dir=shot.direction
	shot.stagger_on_hit=float(options.get("stagger_on_hit",0.0))
	shot.z_index=20;actors.add_child(shot)
	if source=="enemy":shot.add_to_group("hostile_projectile")
	return shot
func cone_damage(point: Vector2,direction: Vector2,radius: float,amount: float,kind: int,source: String,stagger:=0.0,attack: String="attack",condition_hit: Dictionary={}) -> void:
	var dom := str(condition_hit.get("domain", "defense" if source == "tower" else active_domain))
	if dom == "rift" and source == "hero" and rift_domain != null:
		rift_domain.damage_barrels_in_radius(point + direction * (radius * 0.45), radius * 0.72, amount, dom)
	for enemy in domain_enemies(dom):
		if not is_instance_valid(enemy) or enemy.dead or (enemy.has_method("is_flying") and enemy.is_flying()):continue
		var offset: Vector2=enemy.position-point
		if offset.length()<radius and (offset.length()<25 or offset.normalized().dot(direction)>0.3):enemy.take_hit(amount,kind,source,stagger,0.0,0.0,attack,direction,Vector2.INF,condition_hit);enemy.push_back(6 if stagger>0 else 0)
func area_damage(point: Vector2,radius: float,amount: float,kind: int,source: String,stagger:=0.0,chill:=0.0,pen:=0.0,knockback:=0.0,attack: String="attack",hits_flying:=true,condition_hit: Dictionary={}) -> void:
	var dom := str(condition_hit.get("domain", "defense" if source == "tower" else active_domain))
	if dom == "rift" and source == "hero" and attack != "crystal_barrel" and rift_domain != null:
		rift_domain.damage_barrels_in_radius(point, radius, amount, dom)
	var ground_only := (not hits_flying) or (attack in ["shell","cannon","burn_tick","werewolf_transform"])
	var excluded := int(condition_hit.get("exclude_target",0))
	for enemy in domain_enemies(dom):
		if is_instance_valid(enemy) and not enemy.dead and (excluded == 0 or enemy.get_instance_id() != excluded) and (not ground_only or not (enemy.has_method("is_flying") and enemy.is_flying())) and enemy.position.distance_to(point)<=radius:
			enemy.take_hit(amount,kind,source,stagger,chill,pen,attack,point.direction_to(enemy.position),Vector2.INF,condition_hit)
			if knockback>0:enemy.push_back(knockback)
func delayed_attack(point: Vector2,radius: float,amount: float,kind: int,source: String,delay: float,options: Dictionary={}) -> void:
	delayed.append({"point":point,"radius":radius,"damage":amount,"type":kind,"source":source,"life":delay,"duration":delay,"options":options})
func add_zone(point: Vector2,radius: float,dps: float,duration: float,kind: int,source: String,zone_kind:="burn",dom:="defense") -> void:
	zones.append({"point":point,"radius":radius,"dps":dps,"life":duration,"duration":duration,"tick":0.0,"type":kind,"source":source,"kind":zone_kind,"domain":dom})
func effect(point: Vector2,radius: float,colour: Color,kind: String,duration: float,direction:=Vector2.RIGHT,meta: Dictionary={}) -> void:
	if effects.size()>110:effects.pop_front()
	effects.append({"point":point,"radius":radius,"colour":colour,"kind":kind,"life":duration,"duration":duration,"direction":direction,"meta":meta})
func feedback(point: Vector2,damage: float,kind: int,kill: bool,source: String="hero",target: Node2D=null,attack: String="attack", incoming := Vector2.ZERO, shielded := false, condition_result: Dictionary={}) -> void:
	feel.hit(self,point,damage,kind,kill,source,target,attack,incoming,shielded,condition_result)
func finish(won: bool) -> void:
	if game_over:return
	game_over=true;victory=won;running=false;get_tree().paused=false;targeting_slot=-1;selected_site=-1
	passive_offers.clear()
	feel.clear(self)
	settlement=campaign.settle(run_id,level_id,won,total_waves() if won else cycle-1)
	hud.show_result()
func retry_settlement() -> void:
	if not game_over or bool(settlement.get("ok",false)):return
	settlement=campaign.settle(run_id,level_id,victory,total_waves() if victory else cycle-1);hud.show_result()
func restart_run() -> void:
	if feel_lab:
		get_tree().paused=false;hud.close_modal();lab.reset_targets();return
	get_tree().paused=false;get_tree().set_meta("restart_hero",hero.class_id);get_tree().set_meta("restart_level",level_id);get_tree().set_meta("restart_towers",run_towers.duplicate())
	get_tree().set_meta("restart_tower_doctrines",run_tower_doctrines.duplicate())
	get_tree().reload_current_scene()
func return_to_menu() -> void:
	if feel_lab:get_tree().set_meta("feel_lab_consumed",true)
	feel.clear(self)
	get_tree().paused=false;get_tree().set_meta("open_world_map",level_id if started else hud.frontend.stage);get_tree().reload_current_scene()
func open_hero_hall() -> void:
	if feel_lab:get_tree().set_meta("feel_lab_consumed",true)
	feel.clear(self)
	get_tree().paused=false;get_tree().set_meta("open_hero_hall",hero.class_id);get_tree().reload_current_scene()
func mouse_world() -> Vector2:return get_viewport().get_canvas_transform().affine_inverse()*get_viewport().get_mouse_position()
func portal_transition_active() -> bool:
	return rift_domain != null and not rift_domain.warp_phase.is_empty()
func input_blocked() -> bool:
	if portal_transition_active() or hud.has_modal() or selected_site>=0 or targeting_slot>=0 or rally_site>=0:return true
	var hovered: Control=get_viewport().gui_get_hovered_control()
	return hovered!=null and hud.root.is_ancestor_of(hovered) and hovered.mouse_filter!=Control.MOUSE_FILTER_IGNORE
func skill_needs_target(slot: int) -> bool:
	if hero==null:return false
	if slot==0:return hero.class_id in ["lord","druid"]
	return false
func request_skill(slot: int, from_hotkey := false) -> void:
	if not running or game_over or not is_instance_valid(hero) or slot not in [0,1] or hud.has_modal() or portal_transition_active():return
	if not hero.skill_unlocked(slot):
		if from_hotkey:hud.show_order_notice("英雄养成至 %d 级解锁此技能" % ArenaDefinitions.SKILL_UNLOCK_LEVELS[slot])
		return
	if hero.knocked_out or hero.debuff_stun_clock>0.0 or hero.cooldowns[slot]>0.0:
		if from_hotkey:
			var reason := "英雄倒下，等待复活" if hero.knocked_out else ("眩晕期间无法施放" if hero.debuff_stun_clock>0.0 else "技能冷却中 · %d 秒" % ceili(hero.cooldowns[slot]))
			hud.show_order_notice(reason)
		return
	hud.close_context()
	hud.order_notice_left = 0.0
	rally_site = -1
	if skill_needs_target(slot):
		if from_hotkey and targeting_slot==slot:
			if hero.cast(slot,mouse_world()):targeting_slot=-1
			suppress_primary=true;mouse_shoot_held=false;queue_redraw();return
		targeting_slot=slot;suppress_primary=true;mouse_shoot_held=false;queue_redraw()
	else:
		targeting_slot=-1;mouse_shoot_held=false
		hero.cast(slot,mouse_world() if from_hotkey else hero.position+hero.facing*120)
		queue_redraw()
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		# A held press starts blocked. Only the world input handler can arm a battle click.
		suppress_primary=event.pressed
		mouse_shoot_held=false
	if wave_preview and event is InputEventMouseButton and event.pressed:
		if not hud.wave_button.get_global_rect().has_point(event.position) and not hud.preview.get_global_rect().has_point(event.position):
			wave_preview=false
func _unhandled_input(event: InputEvent) -> void:
	if not started or game_over or get_tree().paused:return
	if portal_transition_active():return
	if event is InputEventKey and event.pressed and not event.echo:
		var dodge_k := campaign.keybind("dodge") if campaign != null else KEY_V
		var recall_k := campaign.keybind("recall") if campaign != null else KEY_R
		var portal_k := campaign.keybind("portal") if campaign != null else KEY_T
		if event.keycode == dodge_k:
			if is_instance_valid(hero) and not hud.has_modal():hero.try_dodge()
			return
		if event.keycode == recall_k:
			if rift_domain != null and active_domain == "rift":rift_domain.recall_to_defense()
			return
		if event.keycode == portal_k:
			toggle_domain()
			return
		match event.keycode:
			KEY_TAB:
				open_pending_passive_choice()
			KEY_Q:request_skill(0,true)
			KEY_E:request_skill(1,true)
			KEY_G:
				if can_manage_defense() and active_domain == "defense":
					if not bridge_gate_config.is_empty():trigger_bridge_gate()
					elif stage_gimmicks!=null:stage_gimmicks.trigger_active()
			KEY_F:
				if active_domain == "defense":request_next_wave_anytime()
				elif active_domain == "rift" and rift_domain != null and rift_domain.can_descend_now():
					rift_domain.descend_next_floor()
			KEY_ESCAPE:
				if targeting_slot>=0 or rally_site>=0:targeting_slot=-1;rally_site=-1;hud.order_notice_left=0.0;queue_redraw()
				elif selected_site>=0:hud.close_context()
				elif wave_preview:wave_preview=false;queue_redraw()
				else:hud.show_pause()
		return
	if not (event is InputEventMouseButton and event.pressed):return
	var clicked: Vector2=get_viewport().get_canvas_transform().affine_inverse()*event.position
	if event.button_index==MOUSE_BUTTON_RIGHT:
		if targeting_slot>=0 or rally_site>=0 or selected_site>=0:
			targeting_slot=-1;rally_site=-1;hud.order_notice_left=0.0;hud.close_context();queue_redraw()
		else:
			if hero.command_move(clicked):
				effect(hero.path[-1],16.0,Color("8fe0d0"),"order_confirm",0.34)
			else:
				effect(clicked,13.0,Color("f3a18e"),"order_rejected",0.34)
	elif event.button_index==MOUSE_BUTTON_LEFT:
		if targeting_slot>=0:
			if hero.cast(targeting_slot,clicked):targeting_slot=-1
			suppress_primary=true;mouse_shoot_held=false;queue_redraw();return
		if not can_manage_defense():return
		if active_domain == "defense":
			if rally_site>=0:
				var tower:=site_tower(rally_site)
				if tower==null or tower.is_sealed() or tower.project_level==1:
					rally_site=-1
					hud.show_order_notice("此塔暂时无法接受指令")
				elif (tower.set_bombard(clicked) if tower.can_set_bombard() else tower.set_rally(clicked)):
					rally_site=-1
					hud.order_notice_left=0.0
					effect(tower.bombard_point if tower.can_set_bombard() else tower.rally_point,19.0,Color("f2dd9c"),"order_confirm",0.43)
				else:
					effect(clicked,13.0,Color("f3a18e"),"order_rejected",0.34)
					hud.show_order_notice("此处无法部署 · 请选择高亮范围内的有效位置")
				suppress_primary=true;mouse_shoot_held=false;queue_redraw();return
			for index in range(level_definition.sites.size()):
				if clicked.distance_to(level_definition.sites[index])<42:
					selected_site=index;hud.show_context(index);suppress_primary=true;mouse_shoot_held=false;return
			if not bridge_gate_config.is_empty() and clicked.distance_to(bridge_gate_point())<48.0:
				trigger_bridge_gate();suppress_primary=true;mouse_shoot_held=false;return
			if stage_gimmicks!=null and stage_gimmicks.try_click(clicked):
				suppress_primary=true;mouse_shoot_held=false;return
		elif active_domain == "rift" and rift_domain != null and rift_domain.can_descend_now() and clicked.distance_to(rift_domain.descent_gate_pos) < 58.0:
			if rift_domain.descend_next_floor():
				suppress_primary=true;mouse_shoot_held=false;return
		if selected_site>=0:
			hud.close_context();suppress_primary=true;mouse_shoot_held=false;return
		suppress_primary=false;mouse_shoot_held=true
		if is_instance_valid(hero) and not hero.knocked_out:
			hero.queued_attack_point=clicked
func _physics_process(delta: float) -> void:
	if not running or game_over:return
	elapsed+=delta
	core_overdrive_clock=maxf(0.0,core_overdrive_clock-delta)
	exit_ward_flash=maxf(0.0,exit_ward_flash-delta)
	if phase!="rest" and exit_ward_cd>0.0:
		exit_ward_cd=maxf(0.0,exit_ward_cd-delta)
	passive_engine.tick(delta)
	blocking.update()
	_tick_stage3_systems(delta)
	if siege!=null:siege.tick(delta)
	if not feel_lab:
		_tick_defense_wave(delta)
		if game_over:
			return
	if not tower_lab and can_change_towers():
		for tower: ArenaTower in towers:
			tower.upgrade()
	if rift_domain!=null:rift_domain.tick(delta)
	var finished: Array=[]
	for attack in delayed:
		attack.life-=delta
		if attack.life<=0:
			if str(attack.source)=="neutral":
				finished.append(attack)
				continue
			if attack.source=="enemy":
				var atk_dom := str(attack.options.get("domain", "defense"))
				if hero.domain == atk_dom and not hero.knocked_out and hero.center().distance_to(attack.point)<attack.radius:
					var hit_dir: Vector2 = (hero.center() - Vector2(attack.point)).normalized() if hero.center().distance_to(Vector2(attack.point)) > 1.0 else Vector2.RIGHT
					if hero.is_perfect_dodge_active():
						hero.trigger_perfect_dodge(null,hit_dir)
					elif hero.protection <= 0.0:
						hero.take_hit(attack.damage,attack.type,false,hit_dir)
						if attack.options.has("debuff"):
							var raw_db: Variant = attack.options.get("debuff")
							var db_list: Array = raw_db if raw_db is Array else [raw_db]
							for db in db_list:
								if db is Dictionary:
									hero.apply_debuff(str(db.get("kind","")), float(db.get("duration",0.0)), float(db.get("strength",0.0)))
				if hero.domain == atk_dom:
					for beast in hero.companions:
						if is_instance_valid(beast) and beast.visible and beast.health>0 and beast.center().distance_to(attack.point)<attack.radius:beast.take_hit(attack.damage,attack.type)
				if atk_dom == "defense" and bool(attack.options.get("hits_soldiers",false)):
					for soldier in soldiers:
						if is_instance_valid(soldier) and not soldier.dead and soldier.position.distance_to(attack.point)<attack.radius:
							soldier.take_hit(attack.damage,attack.type,false)
				if attack.options.has("spawn_zone") and attack.options.spawn_zone is Dictionary:
					var z: Dictionary = attack.options.spawn_zone
					add_zone(attack.point, float(z.get("radius",92.0)), float(z.get("dps",7.0)), float(z.get("duration",4.8)), 1, "enemy", str(z.get("kind","toxic_cloud")), atk_dom)
			elif attack.options.has("tower_trial_shell"):
				resolve_trial_shell(attack)
			else:
				var p_hit: Dictionary = attack.options.get("condition_hit",{}).duplicate()
				if attack.options.has("domain"): p_hit["domain"] = attack.options.domain
				elif not p_hit.has("domain"): p_hit["domain"] = "defense" if attack.source == "tower" else active_domain
				area_damage(attack.point,attack.radius,attack.damage,attack.type,attack.source,float(attack.options.get("stun",0)),0.0,float(attack.options.get("pen",0)),float(attack.options.get("knockback",0)),str(attack.options.get("feedback","attack")),true,p_hit)
			if attack.source!="enemy" and float(attack.options.get("burn_dps",0))>0:
				add_zone(attack.point,float(attack.options.get("burn_radius",64)),float(attack.options.get("burn_dps",0)),float(attack.options.get("burn_time",4.0)),attack.type,attack.source,"burn",str(attack.options.get("domain","defense")))
			var tag: String=str(attack.options.get("feedback",""))
			var is_shell := tag=="shell" or bool(attack.options.get("cannon",false))
			if is_shell:
				var c_doc := str(attack.options.get("doctrine_id",""))
				var blast_col := Color("ff5c28") if c_doc=="burning" else (Color("ffd058") if c_doc=="siege" else Color("ff8c38"))
				effect(attack.point,attack.radius,blast_col,"cannon_blast",0.72,Vector2.RIGHT,{"doctrine":c_doc,"tier":int(attack.options.get("cannon_tier",1))})
				if feel.enabled and active_domain=="defense":
					feel.trauma = minf(1.0, feel.trauma + (0.36 if c_doc=="siege" else 0.28))
			else:
				var fx_kind := str(attack.options.get("fx_kind","blast"))
				var fx_col := Color(attack.options.get("fx_color",ArenaCombat.colour(attack.type)))
				effect(attack.point,attack.radius,fx_col,fx_kind,0.45)
			audio.play("explode",-14);finished.append(attack)
	for attack in finished:delayed.erase(attack)
	for zone in zones:
		zone.life-=delta;zone.tick+=delta
		if zone.tick>=0.25:
			zone.tick-=0.25
			if str(zone.source)=="enemy":
				if is_instance_valid(hero) and not hero.knocked_out and hero.domain == str(zone.get("domain","defense")) and hero.position.distance_to(zone.point)<=float(zone.radius):
					hero.apply_debuff("slow",0.65,0.35)
					hero.apply_debuff("poison",1.3,float(zone.dps))
				if str(zone.get("domain","defense")) == "defense":
					for tower in towers:
						if is_instance_valid(tower) and not tower.destroyed and tower.position.distance_to(zone.point)<=float(zone.radius)+26.0:
							tower.apply_jam(0.60,0.35)
			else:
				area_damage(zone.point,zone.radius,float(zone.dps)*0.25,zone.type,zone.source,0.0,0.0,0.0,0.0,"burn_tick",true,{"domain":str(zone.get("domain","defense")),"passive_proc":true})
	zones=zones.filter(func(zone):return float(zone.life)>0)

func _tick_defense_wave(delta: float) -> void:
	if phase == "rest":
		phase_clock = maxf(0.0, phase_clock - delta)
		if phase_clock <= 0.0:
			begin_wave()
		return

	wave_elapsed += delta
	if not tower_lab:
		siege_alert_active = wave_elapsed >= siege_alert_at and wave_elapsed < siege_start_at
		siege_active = wave_elapsed >= siege_start_at
	while not spawn_queue.is_empty() and float(spawn_queue[0].at) <= wave_elapsed:
		var packet: Dictionary = spawn_queue.pop_front()
		spawn_enemy(packet.kind, packet.route, 0, packet.elite, bool(packet.get("swarm_fodder", false)))
	if not spawn_queue.is_empty():
		return
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and not enemy.is_guard and enemy.domain == "defense":
			return

	if cycle < total_waves():
		cycle += 1
		start_rest(15)
	elif not defense_rules or not bool(level_definition.boss) or boss_defeated:
		finish(true)
	elif required_boss_escaped:
		# The last chance to defeat the required boss has passed.
		core_hit(core_health + core_shield)

func resolve_trial_shell(attack: Dictionary) -> int:
	var options: Dictionary=attack.options
	var struck:=0
	var focused:=int(options.get("focus_id",0))
	for enemy: ArenaEnemy in enemies.duplicate():
		if not trial_tower_can_hit(enemy) or enemy.is_flying() or (focused!=0 and enemy.get_instance_id()!=focused): continue
		var distance:=enemy.position.distance_to(attack.point)
		if distance>float(attack.radius): continue
		var edge_power: float = options.get("shell_edge_power",0.5)
		var damage:=float(attack.damage)*lerpf(1.0,edge_power,distance/float(attack.radius))
		enemy.take_hit(damage,ArenaCombat.Type.PHYSICAL,"tower",0.0,0.0,float(options.pen),"cannon",attack.point.direction_to(enemy.position),Vector2.INF,options.get("condition_hit",{}))
		if not enemy.dead and float(options.get("knockback",0.0))>0.0: enemy.push_back(options.knockback)
		struck+=1
		if distance<=float(options.core_radius):
			tower_trial_stats.shell_core_hits+=1
			if not enemy.dead: enemy.tower_shock(float(options.stun),float(options.tower_trial_shell),attack.point)
	tower_trial_stats.shells+=1
	if struck>0: tower_trial_stats.shell_hits+=1
	return struck

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
	if not zones.is_empty() or not bridge_gate_config.is_empty() or targeting_slot>=0 or rally_site>=0 or Engine.get_process_frames()%4==0:
		queue_redraw()
	_sync_magma_nodes()
var _zone_smoke_tex: Texture2D
var _magma_shader: Shader
var _magma_nodes: Array[ColorRect] = []

func _sync_magma_nodes() -> void:
	if _magma_shader == null and ResourceLoader.exists("res://scripts/shaders/magma_zone.gdshader"):
		_magma_shader = load("res://scripts/shaders/magma_zone.gdshader") as Shader
	var burn_zones: Array = []
	for z in zones:
		if str(z.get("kind", "burn")) == "burn" and str(z.get("domain", "defense")) == active_domain:
			burn_zones.append(z)
	while _magma_nodes.size() < burn_zones.size():
		var rect := ColorRect.new()
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.z_index = -3
		if _magma_shader != null:
			var mat := ShaderMaterial.new()
			mat.shader = _magma_shader
			rect.material = mat
		add_child(rect)
		_magma_nodes.append(rect)
	for i in range(_magma_nodes.size()):
		var node := _magma_nodes[i]
		if i >= burn_zones.size() or not running or game_over:
			node.visible = false
		else:
			var z: Dictionary = burn_zones[i]
			var r := float(z.radius)
			node.visible = true
			node.position = Vector2(z.point) - Vector2(r, r * 0.74)
			node.size = Vector2(r * 2.0, r * 1.48)
			if node.material is ShaderMaterial:
				(node.material as ShaderMaterial).set_shader_parameter("fade", clampf(float(z.life) / maxf(0.1, float(z.duration)), 0.0, 1.0))

func _get_zone_smoke() -> Texture2D:
	if _zone_smoke_tex != null:
		return _zone_smoke_tex
	var sz := 48
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var lobes := [
		[Vector2(24, 26), 13.0], [Vector2(16, 27), 9.5], [Vector2(32, 27), 9.5],
		[Vector2(20, 20), 9.0], [Vector2(29, 21), 8.5], [Vector2(24, 17), 7.5],
		[Vector2(24, 30), 8.5]
	]
	for y in range(sz):
		for x in range(sz):
			var p := Vector2(float(x), float(y))
			var density := 0.0
			for lb in lobes:
				var c: Vector2 = lb[0]
				var r: float = float(lb[1])
				var d := p.distance_to(c) / r
				if d < 1.0:
					density = maxf(density, clampf(smoothstep(0.0, 0.58, 1.0 - d) * 1.15, 0.0, 1.0))
			density = clampf(density, 0.0, 1.0)
			if density > 0.04:
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, density))
	_zone_smoke_tex = ImageTexture.create_from_image(img)
	return _zone_smoke_tex

func _draw() -> void:
	if not started:return
	if level_id!=ArenaSaltport.ID and ground.texture==null and not is_instance_valid(tilemap_scene):
		draw_rect(Rect2(Vector2.ZERO,world_size()),Color("88a65c"))
		for road in routes:
			draw_polyline(road.get_baked_points(),Color("667344"),80,true);draw_polyline(road.get_baked_points(),Color("d9bb7b"),67,true)
		for rect in level_definition.blocked:draw_rect(rect,Color("466947"))
	for zone in zones:
		var z_fade := clampf(float(zone.life)/maxf(0.1,float(zone.duration)),0.0,1.0)
		var z_rad := float(zone.radius)
		var z_pt := Vector2(zone.point)
		var zone_smoke := _get_zone_smoke()
		if str(zone.get("kind","burn"))=="toxic_cloud":
			for m_i in range(14):
				var frac := (float(m_i) + 0.3) / 14.0
				var mr := z_rad * 0.66 * sqrt(frac)
				var ma := float(m_i) * 2.39996 + elapsed * (0.42 if m_i % 2 == 0 else -0.34)
				var drift_y := -8.0 - sin(elapsed * 2.2 + float(m_i)) * 4.0
				var mp := z_pt + Vector2(cos(ma) * mr, sin(ma) * mr * 0.52 + drift_y)
				var psz := (48.0 + float(m_i % 3) * 12.0) * (0.90 + 0.10 * sin(elapsed * 3.0 + float(m_i)))
				var col_m := Color(0.18, 0.66, 0.24, 0.62 * z_fade) if (m_i % 3 != 0) else Color(0.44, 0.18, 0.58, 0.52 * z_fade)
				if zone_smoke != null:
					draw_set_transform(mp, sin(float(m_i) * 1.3 + elapsed * 0.4) * 0.35, Vector2(1.0, 0.74))
					draw_texture_rect(zone_smoke, Rect2(-Vector2.ONE * psz * 0.56 + Vector2(0, 4), Vector2.ONE * psz * 1.12), false, Color(0.08, 0.28, 0.12, 0.58 * z_fade))
					draw_texture_rect(zone_smoke, Rect2(-Vector2.ONE * psz * 0.5, Vector2.ONE * psz), false, col_m)
					if m_i % 2 == 0:
						draw_texture_rect(zone_smoke, Rect2(-Vector2.ONE * psz * 0.34 - Vector2(0, 3), Vector2.ONE * psz * 0.68), false, Color(0.54, 0.94, 0.38, 0.44 * z_fade))
					draw_set_transform(Vector2.ZERO)
			for b_i in range(7):
				var b_age := fmod(elapsed * 0.85 + float(b_i) * 0.29, 1.0)
				var ba := float(b_i) * 1.15 + z_pt.x * 0.03
				var br := z_rad * (0.18 + 0.50 * fmod(float(b_i) * 0.37, 1.0))
				var bp := (z_pt + Vector2(cos(ba) * br, sin(ba) * br * 0.52 - 6.0 - b_age * 18.0)).snapped(Vector2(2, 2))
				var ba_alpha := sin(b_age * PI) * 0.90 * z_fade
				draw_rect(Rect2(bp - Vector2(3, 3), Vector2(6, 6)), Color(0.10, 0.20, 0.10, ba_alpha))
				draw_rect(Rect2(bp - Vector2(2, 2), Vector2(4, 4)), Color(0.58, 0.96, 0.46, ba_alpha))
				draw_rect(Rect2(bp - Vector2(1, 1), Vector2(2, 2)), Color(0.88, 1.0, 0.78, ba_alpha))
		else:
			for s_i in range(6):
				var s_age := fmod(elapsed * 1.15 + float(s_i) * 0.21, 1.0)
				var sa := float(s_i) * 1.15 + z_pt.y * 0.02
				var sr := z_rad * 0.55 * fmod(float(s_i) * 0.47 + 0.2, 1.0)
				var sp := (z_pt + Vector2(cos(sa) * sr, sin(sa) * sr * 0.52 - s_age * 26.0)).snapped(Vector2(2, 2))
				draw_rect(Rect2(sp - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1.0, 0.86, 0.42, (1.0 - s_age) * 0.88 * z_fade))
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
	if wave_preview or (level_id in ["ruins","sanctum"] and elapsed<8.0):
		var incoming: Array = []
		if wave_preview: incoming=wave_packets(wave_pattern()).map(func(packet): return packet.route)
		for route_idx in range(routes.size()):
			if level_id=="ruins" and not breach_open and route_idx>=2:continue
			if level_id=="sanctum" and cycle<5 and route_idx>=3:continue
			if not incoming.is_empty() and route_idx not in incoming:continue
			var preview_col: Color=Color(0.76,0.56,1.0,0.68) if ((level_id=="ruins" and route_idx==2) or (level_id=="sanctum" and route_idx==3)) else Color(1,0.82,0.35,0.5)
			if (level_id==ArenaSaltport.ID and route_idx==1) or (level_id=="lighthouse" and route_idx==2):preview_col=Color("a1ede1")
			draw_polyline(routes[route_idx].get_baked_points(),Color(preview_col,0.45 if level_id in [ArenaSaltport.ID,"lighthouse"] else 0.28),2,true)
			var road: Curve2D=routes[route_idx]
			for offset in range(110,int(road.get_baked_length())-45,190):
				var point:=road.sample_baked(offset,true);var direction:=(road.sample_baked(offset+5,true)-point).normalized()
				draw_polyline(PackedVector2Array([point-direction.rotated(0.6)*11,point,point-direction.rotated(-0.6)*11]),(preview_col if level_id in [ArenaSaltport.ID,"lighthouse"] else Color("edcf90")),2.5,true)
	_draw_stage3_overlays()
	if selected_site>=0 and hud.context.visible and not hud.preview_tower.is_empty() and site_tower(selected_site)==null:
		var key: String=hud.preview_tower
		var center: Vector2=level_definition.sites[selected_site]
		var traits: Array = level_definition.get("site_traits",[])
		var highground: bool = selected_site < traits.size() and traits[selected_site] == "highground"
		var base_reach := ArenaTowerTrial.stat(key,"reach",1) if tower_lab else ArenaTower.field_range(tower_display_data(key),1)
		var reach: float = base_reach * (1.18 if highground else 1.0)
		var tint: Color=ArenaDefinitions.TOWERS[key].colour
		draw_circle(center,reach,Color(tint,0.13))
		draw_arc(center,reach,0,TAU,72,Color(tint,0.9),2.4,true)
	if targeting_slot>=0 or rally_site>=0:
		var point:=mouse_world()
		var t_rad:=25.0
		var t_col:=Color("f2dd9c")
		if rally_site>=0 and targeting_slot<0:
			var tower:=site_tower(rally_site)
			if tower!=null and (tower_lab or defense_rules):
				var preview:=tower.order_preview(point)
				if preview.is_finite(): point=preview
				else: t_col=Color("b8715d")
				if tower.kind=="snare": t_rad=tower.snare_radius()
				if tower.kind=="cannon":
					t_rad=tower.splash_radius()
					if tower_lab or defense_rules: draw_arc(point,tower.trial_shell_core(),0,TAU,38,t_col,1.25,true)
				draw_arc(tower.position,tower.ground_order_range(),0,TAU,56,Color(t_col,0.27),1.25,true)
		if targeting_slot==0 and is_instance_valid(hero) and hero.class_id=="lord":
			point=hero.skill_target(point)
			var dir:=(point-hero.position).normalized() if point.distance_to(hero.position)>5.0 else hero.facing
			var ang:=dir.angle()
			var cone_r:=hero.lord_slash_range()
			var span:=acos(0.3)
			var poly:=PackedVector2Array([hero.position])
			for step in range(21):
				var a:=ang-span+span*2.0*float(step)/20.0
				poly.append(hero.position+Vector2.from_angle(a)*cone_r)
			draw_colored_polygon(poly,Color(0.92,0.28,0.36,0.18))
			draw_arc(hero.position,cone_r,ang-span,ang+span,28,Color("f4687a"),2.4,true)
			draw_line(hero.position,hero.position+Vector2.from_angle(ang-span)*cone_r,Color("f4687a"),2.0,true)
			draw_line(hero.position,hero.position+Vector2.from_angle(ang+span)*cone_r,Color("f4687a"),2.0,true)
		elif targeting_slot==0 and is_instance_valid(hero) and hero.class_id=="druid":
			draw_arc(hero.position,ArenaHero.SKILL_TARGET_RANGE,0,TAU,64,Color(0.60,0.92,0.62,0.26),1.6,true)
			var clamped_pt:=hero.skill_target(point)
			var aoe_col:=Color("86e88e")
			draw_circle(clamped_pt,ArenaHero.DRUID_ORDER_RADIUS,Color(aoe_col.r,aoe_col.g,aoe_col.b,0.12))
			draw_arc(clamped_pt,ArenaHero.DRUID_ORDER_RADIUS,0,TAU,48,aoe_col,2.0,true)
			draw_line(clamped_pt+Vector2(-10,0),clamped_pt+Vector2(10,0),aoe_col,2.0,true)
			draw_line(clamped_pt+Vector2(0,-10),clamped_pt+Vector2(0,10),aoe_col,2.0,true)
		else:
			draw_arc(point,t_rad,0,TAU,48,t_col,2.0,true)
func nearest_unhit_enemy(point: Vector2,distance: float,exclude_ids: Dictionary,dom:="defense") -> ArenaEnemy:
	var best: ArenaEnemy;var best_d2:=distance*distance
	for enemy in domain_enemies(dom):
		if not is_instance_valid(enemy) or enemy.dead or exclude_ids.has(enemy.get_instance_id()):continue
		if enemy.is_guard:continue
		var d2: float=point.distance_squared_to(enemy.center())
		if d2<best_d2:best_d2=d2;best=enemy
	return best
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
	if bridge_gate_config.is_empty(): return
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
func _draw_stage3_overlays() -> void:
	if bridge_gate_config.is_empty(): return
	var bp:=bridge_gate_point()
	ArenaGrounding.ensure_textures()
	draw_texture_rect(ArenaGrounding.shadow,Rect2(bp-Vector2(62,22),Vector2(128,64)),false)
	if ArenaGrounding.mechanisms!=null:
		if bridge_lift<0.95:
			draw_texture_rect_region(ArenaGrounding.mechanisms,Rect2(bp-Vector2(64,56),Vector2(128,112)),Rect2(256,0,256,256),Color(0.76,0.68,0.90,1.0-bridge_lift*0.85))
		if bridge_lift>0.05:
			draw_texture_rect_region(ArenaGrounding.mechanisms,Rect2(bp-Vector2(64,58+bridge_lift*6.0),Vector2(128,112)),Rect2(512,0,256,256),Color(0.76,0.68,0.90,clampf(bridge_lift*1.15,0.0,1.0)))
	else:
		var deck:=Rect2(bp-Vector2(39,23+bridge_lift*34),Vector2(78,46*(1.0-bridge_lift*0.65)))
		draw_rect(deck,Color("806649"));draw_rect(deck,Color("bca37c"),false,2)
	if bridge_sealed:
		var b_frac := clampf(bridge_active_clock/BRIDGE_SEAL_DURATION, 0.0, 1.0)
		var bar_p := (bp + Vector2(-24, -42)).snapped(Vector2(2, 2))
		draw_rect(Rect2(bar_p - Vector2(1, 1), Vector2(50, 6)), Color("0f1826", 0.92))
		draw_rect(Rect2(bar_p, Vector2(48.0 * b_frac, 4.0)), Color("7fe8ff"))
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST:quit_game()
	elif what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		mouse_shoot_held=false
		suppress_primary=true
		if is_instance_valid(hero):hero.queued_attack_point=Vector2.INF
func quit_game() -> void:
	if quitting:return
	quitting=true;get_tree().paused=false;running=false;audio.shutdown()
	await get_tree().create_timer(0.15,true,false,true).timeout
	get_tree().quit()

func world_size() -> Vector2:return level_definition.get("size",ArenaLevelCatalog.SIZE)
func can_manage_defense() -> bool:
	return running and not game_over
func can_change_towers() -> bool:
	return can_manage_defense() and passive_offers.is_empty() and active_domain == "defense"
func can_sell_towers() -> bool:
	return can_change_towers()
func timed_tower_work() -> bool:
	return defense_rules or tower_lab
func hero_move_bounds() -> Rect2:
	return Rect2(Vector2(15,95),world_size()-Vector2(30,115))
func world_to_hud(point: Vector2) -> Vector2:return get_viewport().get_canvas_transform()*point
