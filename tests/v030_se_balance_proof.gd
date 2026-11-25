extends SceneTree

## Three-Strategy Automated Proof Test (v0.32 PCG Multi-Floor + ×2.5 Horde Balance Verification).
## Proves empirically across deterministic 60Hz runs on Stage 1 ('forest') that:
##   1) OnlyRift_NoRecall -> DEFEAT (base overrun when ignoring Defense recalls)
##   2) OnlyDefense_NoRift -> DEFEAT (power-starved hero & towers overrun by ×2.5 Round 3-5 Siege)
##   3) DualDomain_Synergy -> VICTORY (farming PCG Rift, events/relics, recalling on warning, Lv3 Evo + Aegis)

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V030 BALANCE FAIL: " + message)


func _run_strategy(strategy: String) -> Dictionary:
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 24
	var game := load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	game.next_run_seed = 42
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run("lord", "forest")
	await process_frame

	# Standard opening defense anchor
	for pair in [[0, "archer"], [1, "barracks"], [2, "mage"]]:
		if game.gold >= int(ArenaDefinitions.tower(pair[1]).cost):
			game.build_tower(pair[0], pair[1])
	game.begin_wave()

	var sim_time := 0.0
	var rift_time := 0.0
	var recalls := 0
	var built_extra := false
	var step_guard := 0
	var dt_est := 0.133 # ~8 frames at 60fps per process_frame with time_scale=8

	while not game.game_over and step_guard < 9000:
		step_guard += 1
		await physics_frame
		sim_time += dt_est
		if game.active_domain == "rift":
			rift_time += dt_est

		# Resolve Rift Event modal deterministically (prefer forge power / relic / xp)
		if not game.active_event_offer.is_empty():
			game.choose_rift_event(0)

		# Open queued [Tab] passive choice and resolve cleanly (preferring active AoE/Tower Evo)
		if game.passive_engine != null and game.passive_engine.pending_ups > 0 and game.passive_offers.is_empty():
			game.open_pending_passive_choice()
		if not game.passive_offers.is_empty():
			var pick := str(game.passive_offers[0].id)
			for off in game.passive_offers:
				var oid := str(off.id)
				if bool(off.get("will_evo", false)) or oid in ["gravity_well", "orbital_laser", "phantom_slash", "chain_bolt", "orbit_blades", "frost_nova", "tower_storm", "tower_aegis", "multishot"]:
					pick = oid
					break
			game.choose_passive(pick)

		# Spend surplus gold on remaining defense slots or Core Aegis in non-greedy strategies
		if strategy != "OnlyRift_NoRecall":
			if not built_extra and game.gold >= 120 and game.site_tower(3) == null:
				if game.build_tower(3, "cannon"):
					built_extra = true
			if game.gold >= 130 and game.site_tower(4) == null:
				game.build_tower(4, "mage")
			if game.gold >= 130 and game.site_tower(5) == null:
				game.build_tower(5, "barracks")

		# Strategy execution
		if strategy == "OnlyRift_NoRecall":
			if game.active_domain == "defense" and game.rift_domain.portal_cooldown <= 0.0 and game.rift_domain.warp_phase == "":
				game.enter_rift()
			elif game.active_domain == "rift":
				_bot_kite_rift(game)

		elif strategy == "OnlyDefense_NoRift":
			if game.phase == "rest" and game.phase_clock < 12.0:
				game.begin_wave()
			if game.gold >= ArenaGame.CORE_AEGIS_COST and game.rift_domain.alarm_level >= 1 and game.core_overdrive_clock <= 0.0:
				game.charge_core_aegis()
			_bot_defend_front(game)

		else: # DualDomain_Synergy
			if game.phase == "rest" and game.phase_clock < 12.0:
				game.begin_wave()
			var rd := game.rift_domain
			var need_recall := rd.core_hit_alert > 0.0 or rd.max_road_ratio >= 0.72 or (game.siege_active and rd.max_road_ratio >= 0.35) or rd.rift_dwell_time >= 36.0
			if game.active_domain == "defense":
				var danger := game.siege_active or rd.alarm_level >= 1 or rd.core_hit_alert > 0.0 or rd.max_road_ratio >= 0.56
				if not danger and game.phase in ["spawn", "clear"] and game.wave_elapsed < 76.0 and rd.portal_cooldown <= 0.0 and rd.warp_phase == "":
					game.enter_rift()
				else:
					if game.gold >= ArenaGame.CORE_AEGIS_COST and (game.siege_active or rd.alarm_level >= 1) and game.core_overdrive_clock <= 0.0:
						game.charge_core_aegis()
					_bot_defend_front(game)
			else:
				if need_recall and (rd.rift_dwell_time >= 10.0 or rd.alarm_level >= 2 or rd.core_hit_alert > 0.0):
					if game.rift_domain.recall_to_defense(true):
						recalls += 1
				else:
					_bot_kite_rift(game)

	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8
	var summary := {
		"strategy": strategy,
		"victory": game.victory,
		"cycle": game.cycle,
		"core_hp": int(ceil(game.core_health)),
		"kills": game.kills,
		"run_lv": game.passive_engine.run_level if game.passive_engine != null else 1,
		"picks": game.passive_engine.picks_taken if game.passive_engine != null else 0,
		"relics": game.relic_engine.owned.size() if game.relic_engine != null else 0,
		"floors": game.rift_domain.floor_index if game.rift_domain != null else 1,
		"rooms": game.rift_domain.cleared_count() if game.rift_domain != null else 0,
		"built": game.built,
		"rift_sec": snappedf(rift_time, 0.1),
		"recalls": recalls,
		"sim_sec": snappedf(sim_time, 0.1),
		"game_over": game.game_over
	}
	print("SE_PROOF_TELEMETRY ", JSON.stringify(summary))
	game.running = false
	game.audio.shutdown()
	await process_frame
	OS.delay_msec(100)
	game.queue_free()
	await process_frame
	return summary


func _bot_defend_front(game: ArenaGame) -> void:
	if not is_instance_valid(game.hero) or game.hero.knocked_out:
		return
	var target_e: ArenaEnemy = null
	var best_prog := -1.0
	for e in game.domain_enemies("defense"):
		if is_instance_valid(e) and not e.dead and e.progress > best_prog:
			best_prog = e.progress
			target_e = e
	if target_e != null:
		if game.hero.position.distance_to(target_e.position) > 54.0:
			game.hero.command_move(target_e.position)
		if game.hero.position.distance_to(target_e.position) <= 150.0:
			if game.hero.skill_unlocked(0) and game.hero.cooldowns[0] <= 0.0:
				game.request_skill(0)
			elif game.hero.skill_unlocked(1) and game.hero.cooldowns[1] <= 0.0:
				game.request_skill(1)
	else:
		if game.hero.position.distance_to(Vector2(960.0, 450.0)) > 48.0:
			game.hero.command_move(Vector2(960.0, 450.0))


func _bot_kite_rift(game: ArenaGame) -> void:
	if not is_instance_valid(game.hero) or game.hero.knocked_out:
		return
	var rd := game.rift_domain
	var cur := rd.current_room_id(game.hero.position) if rd != null else "hub"
	if cur == "" and rd != null:
		cur = "hub"
	var cur_rm: Dictionary = rd.rooms.get(cur, {}) if rd != null else {}
	var best_pos := Vector2(cur_rm.get("center", ArenaRiftDomain.RIFT_ORIGIN + Vector2(2000.0, 2000.0)))
	var found_target := false
	# 1) Unclaimed active room reward (chest / miniboss cache / boss cache)
	if not cur_rm.is_empty() and bool(cur_rm.get("reward_active", false)) and not bool(cur_rm.get("reward_claimed", false)):
		best_pos = Vector2(cur_rm.get("reward_pos", best_pos))
		found_target = true
	# 2) Unused event shrine in current room
	if not found_target and not cur_rm.is_empty() and str(cur_rm.get("kind", "")) == "event" and not bool(cur_rm.get("event_used", false)) and str(cur_rm.get("state", "")) == "cleared":
		best_pos = Vector2(cur_rm.get("event_pos", best_pos))
		found_target = true
	# 3) Deep Descent Gate if cleared whole floor
	if not found_target and rd != null and rd.descent_gate_active and rd.active_combat_room.is_empty() and rd.cleared_count() >= rd.total_explore_rooms():
		if rd.near_descent_gate:
			rd.descend_next_floor(true)
			return
		best_pos = rd.descent_gate_pos
		found_target = true
	# 4) Uncollected XP gems nearby in Rift
	if not found_target:
		var best_pd := INF
		for p in game.pickups:
			if is_instance_valid(p) and not p._collected and p.domain == "rift":
				var d := game.hero.position.distance_to(p.position)
				if d < 420.0 and d < best_pd:
					best_pd = d
					best_pos = p.position
					found_target = true
	# 5) Live enemies in the Rift (prefer current room)
	if not found_target:
		var best_ed := INF
		for e in game.domain_enemies("rift"):
			if is_instance_valid(e) and not e.dead:
				var d := game.hero.position.distance_to(e.position)
				var same_r := str(e.get("rift_room_id")) == cur
				if same_r:
					d -= 1200.0
				if d < best_ed:
					best_ed = d
					best_pos = e.position + Vector2(36.0, 0.0)
					found_target = true
	# 6) BFS to nearest uncleared, event-ready, or reward-ready room over dynamic PCG graph
	if not found_target and rd != null and not cur_rm.is_empty():
		var target_rid := ""
		var parent_map: Dictionary = {}
		var queue: Array[String] = [cur]
		parent_map[cur] = ""
		while not queue.is_empty():
			var node_id: String = queue.pop_front()
			var nrm: Dictionary = rd.rooms.get(node_id, {})
			var want := node_id != cur and (
				str(nrm.get("state", "")) != "cleared"
				or (bool(nrm.get("reward_active", false)) and not bool(nrm.get("reward_claimed", false)))
				or (str(nrm.get("kind", "")) == "event" and not bool(nrm.get("event_used", false)))
			)
			if want:
				target_rid = node_id
				break
			for nb in nrm.get("neighbors", []):
				var nbs := str(nb)
				if not parent_map.has(nbs):
					parent_map[nbs] = node_id
					queue.append(nbs)
		if target_rid != "":
			var step_rid := target_rid
			while str(parent_map.get(step_rid, "")) != "" and str(parent_map.get(step_rid, "")) != cur:
				step_rid = str(parent_map[step_rid])
			var next_c := Vector2(rd.rooms[step_rid].center)
			var cur_c := Vector2(cur_rm.center)
			if absf(game.hero.position.x - next_c.x) > 48.0 and absf(game.hero.position.y - next_c.y) > 48.0:
				best_pos = cur_c
			else:
				best_pos = next_c
	if game.hero.position.distance_to(best_pos) > 26.0:
		game.hero.command_move(best_pos)
	if game.hero.skill_unlocked(0) and game.hero.cooldowns[0] <= 0.0:
		game.request_skill(0)
	elif game.hero.skill_unlocked(1) and game.hero.cooldowns[1] <= 0.0:
		game.request_skill(1)


func run() -> void:
	var s_rift := await _run_strategy("OnlyRift_NoRecall")
	var s_def := await _run_strategy("OnlyDefense_NoRift")
	var s_dual := await _run_strategy("DualDomain_Synergy")

	check(s_rift.game_over and not s_rift.victory, "OnlyRift_NoRecall must FAIL (got victory=%s)" % str(s_rift.victory))
	check(s_def.game_over and not s_def.victory, "OnlyDefense_NoRift must FAIL (got victory=%s)" % str(s_def.victory))
	check(s_dual.game_over and s_dual.victory and s_dual.core_hp > 0, "DualDomain_Synergy must WIN with core_hp > 0")
	check(s_dual.recalls >= 1 and s_dual.run_lv >= 3 and s_dual.picks <= ArenaPassiveEngine.MAX_TOTAL_PICKS, "DualDomain_Synergy actively uses Rift exploration & obeys 10-pick cap")
	print("V030 SE BALANCE PROOF CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)
