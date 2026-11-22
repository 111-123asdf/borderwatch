class_name ArenaDefenseOrders
extends RefCounted

var game: ArenaGame
var deck := ArenaRuleDeck.new()
var targeting := ""
var hint := ""
var flags := [Vector2.INF, Vector2.INF]
var transfer_used := false
var transfer_left := 0.0
var transfer_from := 0
var push_ready := 0.0
var lure_lane := -1
var long_bridge := false
var gate_lane := -1
var wall_left := 0.0
var wall_hp := 0.0
var wall_used := false
var wall_bond := 0
var beacon_used := false
var exposed_until := -1.0
var bounty_lane := -1
var bounty_active := false
var bounty_signed := false
var bounty_kills := 0
var bounty_line := 0.0
var crossing_fronts: Array[ArenaEnemy] = []
var chest_lane := -1
var chest_open := false
var chest_value := 0
var chest_count := 0
var marked: ArenaEnemy
var mark_used := false
var donor: ArenaTower
var receiver: ArenaTower
var borrowed_shot := false
var first_site := -1

func _init(battle: ArenaGame) -> void:
	game = battle

func has(effect: String) -> bool:
	return game.has_defense_effect(effect)

func main_ordinary(packet: Dictionary) -> bool:
	return not packet.elite and packet.kind not in ["moth","colossus"]

func counts(packets: Array, ordinary := true) -> Dictionary:
	var result := {}
	for p in packets:
		if ordinary and not main_ordinary(p): continue
		result[p.route] = int(result.get(p.route,0))+1
	return result

func tower_pair_possible(kinds: Array) -> bool:
	var owned := 0
	var free_sites := 0
	for i in game.level_definition.sites.size():
		var tower := game.site_tower(i)
		if tower != null:
			if tower.kind in kinds: owned += 1
		elif not game.site_locked(i): free_sites += 1
	if owned >= 2: return true
	var cheapest := 99999
	for kind in game.available_towers():
		if kind in kinds: cheapest = mini(cheapest,int(game.tower_display_data(kind).cost))
	return free_sites >= 2-owned and game.gold >= (2-owned)*cheapest

func available(id: String, cost: String, packets: Array) -> bool:
	var lanes := counts(packets)
	match id:
		"reform": return game.cycle<int(game.level_definition.waves) or not (has("bounty") or has("chest"))
		"lure":
			if game.level_id!="creek" or counts(packets,false).size()<2: return false
			return packets.any(func(p): return p.elite) if cost=="flank" else vanguard_advances(packets)
		"bridge": return not game.bridge_gate_config.is_empty()
		"muster": return tower_pair_possible(["barracks"])
		"battery": return tower_pair_possible(["archer","mage"])
		"mark": return game.run_towers.any(func(kind): return kind not in ["snare","barracks"]) and packets.any(func(p): return p.elite)
		"wall":
			if cost=="open_gate": return game.level_id=="creek" and counts(packets,false).size()>1
			return game.core_health>75
		"bounty","chest":
			if game.cycle==int(game.level_definition.waves) and has("wave_build_lock"): return false
			if id=="bounty" and cost=="stake" and game.gold<60: return false
			return lanes.values().any(func(n): return n >= (5 if id=="chest" else 3))
	return true

func vanguard_advances(packets: Array) -> bool:
	var ordinary := packets.filter(main_ordinary)
	return ordinary.size()>=3 and ordinary[2].at>ordinary[0].at

func plan(packets: Array) -> Array:
	if lure_lane>=0 and has("lure"):
		var flank := has("flank")
		var valid := packets.any(func(p): return p.elite) if flank else vanguard_advances(packets)
		if valid:
			var first := -1.0
			var n := 0
			for p in packets:
				if main_ordinary(p):
					p.route = lure_lane
					if n==0: first = p.at
					if not flank and n<3: p.at = first
					n += 1
				elif p.elite and flank:
					p.route = 1-lure_lane
					p.at = 0.0
	if lure_lane>=0:
		packets.sort_custom(func(a,b):
			if a.at!=b.at: return a.at<b.at
			if has("flank") and a.elite!=b.elite: return a.elite
			return a.serial<b.serial)
	var n := 0
	for p in packets:
		if p.route==bounty_lane and main_ordinary(p) and n<3:
			p.bounty = true
			n += 1
	return packets

func contract_line(lane: int) -> float:
	if not game.bridge_gate_config.is_empty() and lane==int(game.bridge_gate_config.route_id):
		if has("fixed_bridge"): return contract_road(lane).get_baked_length()*0.5
		return game.routes[lane].get_closest_offset(game.bridge_gate_config.fork)-12.0
	return game.routes[lane].get_baked_length()*0.5

func contract_road(lane: int) -> Curve2D:
	if lane==int(game.bridge_gate_config.get("route_id",-1)) and has("fixed_bridge") and long_bridge:
		return game.bridge_detour_curve
	return game.routes[lane]

func beacon_point(point: Vector2) -> Vector2:
	var best:=Vector2.INF
	for lane in game.routes.size():
		if lane==3 and not game.breach_open: continue
		var road: Curve2D=game.routes[lane]
		var target:=road.get_closest_point(point)
		if point.distance_squared_to(target)<point.distance_squared_to(best): best=target
	if game.bridge_detour_curve!=null:
		var target:=game.bridge_detour_curve.get_closest_point(point)
		if point.distance_squared_to(target)<point.distance_squared_to(best): best=target
	return best

func lane_options(order: String, packets: Array) -> Array:
	var all_lanes := counts(packets,false)
	var ordinary := counts(packets)
	var options := []
	for lane: int in all_lanes:
		var n: int = ordinary.get(lane,0)
		match order:
			"bounty":
				if n<3 or (has("stake") and game.gold<60): continue
				if chest_lane==lane and has("waive") and n<8: continue
			"chest":
				if n-(3 if has("waive") and bounty_lane==lane else 0)<5: continue
			"gate":
				if all_lanes.size()<2: continue
		options.append(lane)
	options.sort()
	return options

func prepare() -> void:
	targeting = ""
	first_site = -1
	hint = ""
	lure_lane = -1
	bounty_lane = -1
	chest_lane = -1
	gate_lane = -1
	marked = null
	mark_used = false
	donor = null
	receiver = null
	borrowed_shot = false
	transfer_used = false
	transfer_left = 0
	push_ready = 0
	wall_used = false
	beacon_used = false
	exposed_until = -1
	long_bridge = false

func begin(packets: Array) -> void:
	targeting = ""
	first_site = -1
	hint = ""
	if has("bridge"):
		game.bridge_sealed = long_bridge
		game.bridge_active_clock = 0
		game._apply_bridge_gate_state(long_bridge)
	if has("one_way") and (not flags[0].is_finite() or game.hero.position.distance_to(flags[0])>90):
		transfer_used = true
	if has("open_gate") and gate_lane<0:
		var options := lane_options("gate",packets)
		if not options.is_empty(): gate_lane = options[0]
	bounty_active = bounty_lane in lane_options("bounty",packets)
	bounty_signed = bounty_active
	crossing_fronts.clear()
	if bounty_lane>=0 and not bounty_signed: hint="签约条件已变，本波没有扣款"
	bounty_kills = 0
	if bounty_active:
		bounty_line = contract_line(bounty_lane)
		if has("stake"): game.gold -= 60
	chest_open = chest_lane in lane_options("chest",packets)
	chest_value = 0
	chest_count = 0

func wave_end() -> void:
	if chest_open: cash_chest()
	if wall_left>0: lower_wall(false)
	bounty_active = false
	transfer_left = 0
	exposed_until = -1
	game.delayed = game.delayed.filter(func(a): return a.source!="core")

func cash_amount() -> int:
	return floori(chest_value*(2.0 if chest_count==5 else (1.5 if chest_count>=3 else 1.0)))

func cash_chest() -> bool:
	if not chest_open: return false
	var value := cash_amount()
	game.gold += value
	chest_open = false
	hint = "钱箱入账 %d 金" % value
	return true

func kill_income(enemy: ArenaEnemy, base: int) -> int:
	if not enemy.rule_main: return base
	crossing_fronts.erase(enemy)
	var waived := enemy.rule_front and has("waive")
	if bounty_active and enemy.rule_front:
		bounty_kills += 1
		if bounty_kills==3:
			bounty_active = false
			game.gold += 140 if has("stake") else 80
			hint = "前线悬赏完成 · 奖金 80 金"
	if waived: return 0
	if chest_open and chest_count<5 and enemy.route_id==chest_lane and not enemy.elite and not enemy.is_boss():
		chest_count += 1
		chest_value += base
		return 0
	return base

func leaked(enemy: ArenaEnemy) -> int:
	if bounty_active and enemy.rule_front:
		bounty_active=false
		hint="前锋触核 · 悬赏失约"
	if enemy.rule_main and chest_open and enemy.route_id==chest_lane:
		chest_open = false
		hint = "钱箱失守 · 损失 %d 金" % chest_value
	if exposed_until>=game.wave_elapsed:
		exposed_until = -1
		return 40
	return 0

func wall_distance() -> float:
	return 440.0 if has("open_gate") else 120.0

func advance(enemy: ArenaEnemy, previous: float, road: Curve2D) -> void:
	if wall_left>0 and enemy.route_id!=gate_lane and not enemy.is_flying():
		var stop := road.get_baked_length()-wall_distance()
		if previous<=stop+0.01 and enemy.progress>=stop:
			if enemy.is_boss():
				break_wall()
			else:
				enemy.progress = stop
				enemy.facing = Vector2.RIGHT
				enemy.visual.show_pose("attack",enemy.facing)
				if enemy.melee_clock<=0:
					enemy.melee_clock = 1.0
					wall_hp -= float(enemy.data.damage)*enemy.damage_scale()*(1.25 if enemy.elite else 1.0)
					if wall_hp<=0: break_wall()
	if bounty_active and enemy.rule_front and enemy.progress>=bounty_line:
		if enemy not in crossing_fronts: crossing_fronts.append(enemy)

func break_wall() -> void:
	wall_left = 0
	wall_hp = 0
	wall_bond = 0
	hint = "城墙已破"

func lower_wall(counter: bool) -> void:
	if counter:
		for enemy: ArenaEnemy in game.enemies:
			if enemy.dead or enemy.is_guard or enemy.route_id==gate_lane or enemy.is_boss(): continue
			var stop := game.enemy_road(enemy).get_baked_length()-wall_distance()
			if absf(enemy.progress-stop)<=2: displace(enemy,100.0)
	game.core_health = minf(game.core_max,game.core_health+wall_bond)
	wall_bond = 0
	wall_left = 0
	wall_hp = 0

func wall_command() -> bool:
	if wall_left>0:
		lower_wall(true)
		return true
	if wall_used or (has("open_gate") and gate_lane<0) or (has("pledge") and game.core_health<=75): return false
	wall_bond = 75 if has("pledge") else 0
	game.core_health -= wall_bond
	wall_hp = 300
	wall_left = 10
	wall_used = true
	return true

func push_floor(enemy: ArenaEnemy) -> float:
	if enemy.road_curve!=null and not enemy.bridge_branch.is_empty():
		return enemy.road_curve.get_closest_offset(game.bridge_gate_config.fork)
	return 0.0

func displace(enemy: ArenaEnemy, distance: float) -> void:
	game.blocking.release_enemy(enemy)
	enemy.melee_target = null
	enemy.melee_windup = 0
	var road := game.enemy_road(enemy)
	enemy.progress = minf(enemy.progress,maxf(push_floor(enemy),enemy.progress-distance))
	enemy.position = road.sample_baked(enemy.progress,true)
	game.effect(enemy.position,28,Color("d7c485"),"hit",0.2)

func collision_target(enemy: ArenaEnemy) -> ArenaEnemy:
	var back := maxf(push_floor(enemy),enemy.progress-180)
	var other: ArenaEnemy
	for unit: ArenaEnemy in game.enemies:
		if unit==enemy or unit.dead or unit.elite or unit.is_boss() or unit.is_guard: continue
		if unit.route_id!=enemy.route_id or game.enemy_road(unit)!=game.enemy_road(enemy): continue
		if unit.progress<back or unit.progress>=enemy.progress: continue
		if other==null or unit.progress>other.progress: other = unit
	return other

func push(enemy: ArenaEnemy) -> bool:
	if not is_instance_valid(enemy) or enemy.dead or enemy.blocker!=game.hero or enemy.rule_pushed or enemy.is_boss(): return false
	var other := collision_target(enemy)
	var distance := 180.0
	if other!=null:
		distance = enemy.progress-other.progress
		other.stun = maxf(other.stun,0.8)
		enemy.stun = maxf(enemy.stun,0.8)
	displace(enemy,distance)
	enemy.rule_pushed = true
	push_ready = 6
	return true

func transfer() -> bool:
	if transfer_used or transfer_left>0 or game.hero.knocked_out or game.hero.action!="" or game.hero.rolling>0: return false
	if not flags[0].is_finite() or not flags[1].is_finite(): return false
	transfer_from = 0 if has("one_way") or game.hero.position.distance_to(flags[0])<=game.hero.position.distance_to(flags[1]) else 1
	if (has("one_way") and transfer_from!=0) or game.hero.position.distance_to(flags[transfer_from])>90: return false
	if not game.walkable(flags[1-transfer_from]): return false
	game.blocking.release(game.hero)
	game.hero.path.clear()
	game.hero.velocity = Vector2.ZERO
	transfer_left = 1.2
	if has("one_way"): finish_transfer()
	return true

func finish_transfer() -> void:
	transfer_left = 0
	if not game.can_manage_defense() or not game.walkable(flags[1-transfer_from]): return
	game.hero.position = flags[1-transfer_from]
	game.hero.path.clear()
	game.hero.velocity = Vector2.ZERO
	transfer_used = true
	game.effect(game.hero.position,40,Color("81d9c0"),"flag",0.4)

func tick(delta: float) -> void:
	# Projectiles and enemies are siblings. Allow lethal impacts in the crossing frame.
	for enemy in crossing_fronts:
		if bounty_active and (not is_instance_valid(enemy) or not enemy.dead):
			bounty_active=false
			hint="前锋越线 · 悬赏失约"
	crossing_fronts.clear()
	push_ready = maxf(0,push_ready-delta)
	if wall_left>0:
		wall_left = maxf(0,wall_left-delta)
		if wall_left==0: lower_wall(false)
	if transfer_left>0:
		var hero := game.hero
		if hero.knocked_out or hero.action!="" or not hero.path.is_empty() or Input.get_vector("move_left","move_right","move_up","move_down").length()>0.1 or not game.can_manage_defense():
			transfer_left = 0
		else:
			transfer_left -= delta
			if transfer_left<=0: finish_transfer()

func lane_name(lane: int) -> String:
	if lane<0: return "未指定"
	if game.level_id=="creek": return ["北路","南路"][lane]
	if game.level_id=="ruins": return ["西北","西南","东南","东北"][lane]
	return "主路"

func can_mark() -> bool:
	return not mark_used and has("mark")

func cancel_target() -> void:
	targeting = ""
	first_site = -1
	hint = ""

func command(id: String) -> bool:
	if not game.can_manage_defense() or game.get_tree().paused: return false
	var prep := game.phase=="rest"
	var blessing: String = {"flag_a":"relay","flag_b":"relay","gate":"wall"}.get(id,id)
	if not has(blessing): return false
	cancel_target()
	if prep and id in ["chest","bounty","lure","gate"]:
		if id=="gate" and not has("open_gate"): return false
		var packets := game.base_wave_packets(game.wave_pattern()) if id=="lure" else game.wave_packets(game.wave_pattern())
		var options := lane_options(id,packets)
		if options.is_empty(): return false
		var current: int = {"chest":chest_lane,"bounty":bounty_lane,"lure":lure_lane,"gate":gate_lane}[id]
		if id=="lure" and not available("lure","flank" if has("flank") else "vanguard",packets): return false
		if id!="gate": options.append(-1)
		var lane: int = options[(options.find(current)+1)%options.size()]
		match id:
			"chest": chest_lane = lane
			"bounty": bounty_lane = lane
			"lure":
				var previous:=lure_lane
				lure_lane = lane
				var changed := game.wave_packets(game.wave_pattern())
				if (bounty_lane>=0 and bounty_lane not in lane_options("bounty",changed)) or (chest_lane>=0 and chest_lane not in lane_options("chest",changed)):
					lure_lane=previous
					hint="先调整已签的悬赏或钱箱路线"
					return false
				if gate_lane not in lane_options("gate",changed): gate_lane=-1
			"gate": gate_lane = lane
		game.wave_preview = true
		return true
	if prep and id=="bridge":
		long_bridge = not long_bridge
		game.wave_preview = true
		return true
	if not prep:
		match id:
			"relay": return transfer()
			"wall": return wall_command()
			"chest": return cash_chest()
			"beacon":
				if beacon_used: return false
			"riposte":
				if push_ready>0 or game.hero.knocked_out: return false
	if (prep and id in ["flag_a","flag_b","battery"]) or id=="muster" or (not prep and id in ["beacon","riposte"]):
		targeting = id
		game.targeting_slot=-1
		game.rally_site=-1
		game.hud.close_context()
		hint = {"flag_a":"点地表放甲旗","flag_b":"点地表放乙旗","battery":"点供火塔，再点接收塔","muster":"点出发兵营，再点目的兵营","beacon":"点道路指定炮击落点","riposte":"点英雄正在拦截的敌人"}[id]
		return true
	return false

func target_enemy(point: Vector2) -> ArenaEnemy:
	var nearest: ArenaEnemy
	var best := 55.0
	for unit: ArenaEnemy in game.enemies:
		if unit.dead or unit.blocker!=game.hero or unit.rule_pushed or unit.is_boss(): continue
		var distance := minf(unit.position.distance_to(point),unit.center().distance_to(point))
		if distance<best:
			best = distance
			nearest = unit
	return nearest

func choose_point(point: Vector2) -> bool:
	if targeting=="" or not game.can_manage_defense() or game.get_tree().paused: return false
	match targeting:
		"flag_a","flag_b":
			if game.phase!="rest" or not game.walkable(point) or game.complete_defense_path(game.hero.position,point).is_empty(): return false
			var i := 0 if targeting=="flag_a" else 1
			if flags[1-i].is_finite() and point.distance_to(flags[1-i])<=90: return false
			flags[i] = point
			game.queue_redraw()
			if i==0 and has("one_way"): game.hero.command_move(point)
		"beacon":
			var aim := beacon_point(point)
			if game.phase=="rest" or beacon_used or point.distance_to(aim)>55: return false
			beacon_used = true
			exposed_until = game.wave_elapsed+4
			for delay in [2.0,3.0,4.0]:
				game.delayed_attack(aim,75,70,ArenaCombat.Type.MAGIC,"core",delay,{"origin":game.level_definition.core,"feedback":"beacon"})
		"riposte":
			var unit := target_enemy(point)
			if game.phase=="rest" or push_ready>0 or unit==null or not game.hero.begin_attack(unit): return false
			game.hero.push_attack = true
		"battery","muster":
			var tower: ArenaTower
			for item: ArenaTower in game.towers:
				if not item.destroyed and item.project_level==0 and item.position.distance_to(point)<44: tower=item
			var artillery := targeting=="battery"
			if tower==null or (artillery and (game.phase!="rest" or tower.kind not in ["archer","mage"])) or (not artillery and tower.kind!="barracks"): return false
			if first_site<0:
				first_site=tower.site_id
				hint="点接收塔" if artillery else "点目的兵营，再点本营可召回"
				return true
			var origin := game.site_tower(first_site)
			if origin==null or origin.destroyed:
				cancel_target()
				return false
			if artillery:
				if origin==tower: return false
				donor=origin
				receiver=tower
				borrowed_shot=false
			else:
				var goal := tower.rally_point
				if game.complete_defense_path(origin.destination_flag(),goal).is_empty(): return false
				origin.support_camp=null if origin==tower else tower
				for soldier: ArenaSoldier in origin.troops: soldier.march_to_flag()
		_: return false
	cancel_target()
	return true

func rally_changed(camp: ArenaTower) -> void:
	for tower: ArenaTower in game.towers:
		if tower.support_camp==camp:
			for soldier: ArenaSoldier in tower.troops: soldier.march_to_flag()

func tower_removed(tower: ArenaTower) -> void:
	if game.phase=="rest" and (donor==tower or receiver==tower):
		donor=null
		receiver=null
	elif receiver==tower: receiver=null
	elif donor==tower: donor=null
	if receiver==null or donor==null: borrowed_shot=false
	for origin: ArenaTower in game.towers:
		if origin.support_camp==tower:
			origin.support_camp=null
			for soldier: ArenaSoldier in origin.troops: soldier.march_to_flag()

func draw_ground() -> void:
	if not game.can_manage_defense(): return
	for i in flags.size():
		var p: Vector2=flags[i]
		if not p.is_finite(): continue
		var tint := Color("80d9c4") if i==0 else Color("efbe70")
		game.draw_line(p,p+Vector2(0,-38),tint,3,true)
		game.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-38),p+Vector2(20,-33),p+Vector2(0,-25)]),tint)
		if transfer_left>0 and i==transfer_from: game.draw_arc(p,22,-PI/2,-PI/2+TAU*(1-transfer_left/1.2),32,tint,4,true)
	if (bounty_active or (game.phase=="rest" and bounty_lane>=0)) and bounty_lane>=0:
		var road:=contract_road(bounty_lane)
		var off := contract_line(bounty_lane)
		var p:=road.sample_baked(off,true)
		var side:=p.direction_to(road.sample_baked(off+3,true)).orthogonal()*29
		game.draw_line(p-side,p+side,Color("f6c86b"),5,true)
	for enemy: ArenaEnemy in game.enemies:
		if enemy.dead: continue
		if (bounty_active and enemy.rule_front) or enemy==marked:
			game.draw_arc(enemy.position,enemy.radius+5,0,TAU,24,Color("eab556"),2,true)
	if wall_left>0 or (game.phase=="rest" and has("open_gate") and gate_lane>=0):
		for lane in game.routes.size():
			if lane==gate_lane or (lane==3 and not game.breach_open): continue
			var road: Curve2D=game.routes[lane]
			if lane==int(game.bridge_gate_config.get("route_id",-1)) and game.bridge_sealed: road=game.bridge_detour_curve
			var off := road.get_baked_length()-wall_distance()
			var p := road.sample_baked(off,true)
			var side := p.direction_to(road.sample_baked(off+3,true)).orthogonal()*33
			game.draw_line(p-side,p+side,Color("98d7c1"),9,true)
	if targeting=="beacon":
		game.draw_arc(beacon_point(game.mouse_world()),75,0,TAU,40,Color("eda76c"),3,true)
	elif targeting=="riposte":
		var unit := target_enemy(game.mouse_world())
		if unit!=null:
			var collision := collision_target(unit)
			var end := collision.progress if collision!=null else maxf(push_floor(unit),unit.progress-180)
			var road := game.enemy_road(unit)
			var pts := PackedVector2Array([unit.position])
			for off in range(int(unit.progress)-12,int(end),-12): pts.append(road.sample_baked(off,true))
			pts.append(road.sample_baked(end,true))
			game.draw_polyline(pts,Color("f6c86b"),4,true)
	for attack in game.delayed:
		if attack.source=="core": game.draw_arc(attack.point,75,0,TAU,32,Color("eda76c",0.6),2,true)
