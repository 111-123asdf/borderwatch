extends SceneTree

## Three-Strategy Automated Proof Test (v0.32 PCG Multi-Floor + ×2.5 Horde Balance Verification).
## Proves empirically across deterministic 60Hz runs on Stage 1 ('forest') that:
##   1) OnlyRift_NoRecall -> DEFEAT (base overrun when ignoring Defense recalls)
##   2) OnlyDefense_NoRift -> DEFEAT (power-starved hero & towers overrun by ×2.5 Round 3-5 Siege)
##   3) DualDomain_Synergy -> VICTORY (Rift passives and relics, recall and tower investment)

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V030 BALANCE FAIL: " + message)


func _run_strategy(strategy: String, stage := "forest", hero_id := "lord", hero_level := 1, loadout: Array[String] = [], seed := 42, benchmark := false) -> Dictionary:
	Engine.time_scale = 8.0
	Engine.max_physics_steps_per_frame = 24
	var game := load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	game.campaign.data.levels[hero_id] = hero_level
	if not loadout.is_empty():
		game.campaign.equip_towers(loadout)
	game.next_run_seed = seed
	root.add_child(game)
	current_scene = game
	await process_frame
	game.start_run(hero_id, stage)
	await process_frame

	var roster := loadout
	if benchmark and roster.is_empty():
		roster.assign(ArenaDefinitions.DEFAULT_TOWERS)
	var leaks := {}
	var required_boss_leaks: Array[Dictionary] = []
	game.event_bus.subscribe("enemy_escaped", func(payload):
		var key := "%s/%s" % [payload.wave, payload.kind]
		leaks[key] = int(leaks.get(key, 0)) + 1
		if payload.required:
			required_boss_leaks.append(payload.duplicate()))
	var gold_by_source := {}
	game.event_bus.subscribe("gold_earned", func(payload):
		var source := str(payload.source)
		gold_by_source[source] = int(gold_by_source.get(source, 0)) + int(payload.amount))
	var starting_gold := game.gold
	if benchmark:
		for _slot in range(3):
			_build_benchmark_roster(game, roster, 3)
	elif loadout.is_empty():
		# Keep the same opening for all three comparison strategies.
		for pair in [[0, "archer"], [1, "barracks"], [2, "mage"]]:
			if game.gold >= int(ArenaDefinitions.tower(pair[1]).cost):
				game.build_tower(pair[0], pair[1])
	else:
		_build_roster(game, loadout, 3)
	game.begin_wave()

	var sim_time := 0.0
	var rift_time := 0.0
	var recalls := 0
	var built_extra := false
	var step_guard := 0
	var event_spent := 0
	var first_pick_time := -1.0
	var first_evo_time := -1.0
	var towers_after_round_two := -1
	var gold_after_round_two := -1
	var dt_est := 0.133 # ~8 frames at 60fps per process_frame with time_scale=8

	while not game.game_over and step_guard < (13500 if benchmark else 9000):
		step_guard += 1
		await physics_frame
		sim_time += dt_est
		if game.cycle >= 3 and towers_after_round_two < 0:
			towers_after_round_two = game.built
			gold_after_round_two = game.gold
		if game.active_domain == "rift":
			rift_time += dt_est

		# Resolve Rift Event modal deterministically (prefer forge power / relic / xp)
		if not game.active_event_offer.is_empty():
			var price := int(game.active_event_offer.options[0].get("cost_gold", 0))
			if game.choose_rift_event(0):
				event_spent += price

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
			if game.choose_passive(pick):
				if first_pick_time < 0.0:
					first_pick_time = game.elapsed
				if first_evo_time < 0.0 and game.passive_engine.is_evo(pick):
					first_evo_time = game.elapsed

		# Build coverage while the regular tower upgrade system spends the shared wallet.
		if benchmark:
			if strategy != "OnlyRift_NoRecall":
				_build_benchmark_roster(game, roster, game.level_definition.sites.size())
		elif not loadout.is_empty():
			_build_roster(game, loadout, 6)
		elif strategy != "OnlyRift_NoRecall":
			if not built_extra and game.gold >= 120 and game.site_tower(3) == null:
				if game.build_tower(3, "cannon"):
					built_extra = true
			if game.gold >= 130 and game.site_tower(4) == null:
				game.build_tower(4, "mage")
			if game.gold >= 130 and game.site_tower(5) == null:
				game.build_tower(5, "barracks")

		if benchmark and game.active_domain == "defense" and game.siege_active and game.rift_domain.max_road_ratio > 0.35:
			if not game.bridge_gate_config.is_empty():
				game.trigger_bridge_gate()
			elif game.stage_gimmicks != null:
				game.stage_gimmicks.trigger_active()

		# Strategy execution
		if strategy == "OnlyRift_NoRecall":
			if game.active_domain == "defense" and game.rift_domain.portal_cooldown <= 0.0 and game.rift_domain.warp_phase == "":
				game.enter_rift()
			elif game.active_domain == "rift":
				_bot_kite_rift(game, benchmark)

		elif strategy == "OnlyDefense_NoRift":
			if game.phase == "rest" and game.phase_clock < 12.0:
				game.begin_wave()
			_bot_defend_front(game, benchmark)

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
					_bot_defend_front(game, benchmark)
			else:
				if need_recall and (rd.rift_dwell_time >= 10.0 or rd.alarm_level >= 2 or rd.core_hit_alert > 0.0):
					if game.rift_domain.recall_to_defense(true):
						recalls += 1
				else:
					_bot_kite_rift(game, benchmark)

	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8
	var tower_spent := 0
	for tower in game.towers:
		tower_spent += tower.invested_gold + tower.project_gold
	var unlock_spent := 0
	for site in game.unlocked_sites:
		unlock_spent += game.unlock_price(site)
	var gold_spent := tower_spent + unlock_spent + event_spent
	var summary := {
		"seed": seed,
		"hero": hero_id,
		"hero_level": hero_level,
		"stage": stage,
		"leaks_by_wave_and_kind": leaks,
		"required_boss_leaks": required_boss_leaks,
		"first_pick_sec": snappedf(first_pick_time, 0.1),
		"first_evo_sec": snappedf(first_evo_time, 0.1),
		"gold_earned": game.gold - starting_gold + gold_spent,
		"gold_spent": gold_spent,
		"gold_end": game.gold,
		"gold_by_source": gold_by_source,
		"towers_after_round_two": towers_after_round_two,
		"gold_after_round_two": gold_after_round_two,
		"gems": int(game.settlement.get("amount", 0)),
		"strategy": strategy,
		"victory": game.victory,
		"cycle": game.cycle,
		"total_waves": game.total_waves(),
		"settled": bool(game.settlement.get("ok", false)),
		"pending_enemies": game.spawn_queue.size(),
		"remaining_enemies": game.domain_enemies("defense").size(),
		"boss_defeated": game.boss_defeated,
		"tower_kinds": game.towers.map(func(tower): return tower.kind),
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


func _build_roster(game: ArenaGame, loadout: Array[String], limit: int) -> void:
	if game.built >= limit or not game.can_change_towers():
		return
	var available := game.available_towers()
	for site in range(game.level_definition.sites.size()):
		if game.site_locked(site) or game.site_tower(site) != null:
			continue
		var kind := loadout[game.built % loadout.size()]
		if kind not in available:
			return
		if not game.build_tower(site, kind) or game.built >= limit:
			return


func _build_benchmark_roster(game: ArenaGame, loadout: Array[String], limit: int) -> void:
	if game.built >= limit or not game.can_change_towers():
		return
	var kind := loadout[game.built % loadout.size()]
	var spec := ArenaDefinitions.tower(kind)
	if kind not in game.available_towers() or game.gold < int(spec.cost):
		return
	var best_site := -1
	var best_score := -INF
	var reach := float(spec.reach)
	for site in range(game.level_definition.sites.size()):
		if game.site_tower(site) != null:
			continue
		if game.site_locked(site) and (game.cycle < 3 or game.gold < game.unlock_price(site) + int(spec.cost)):
			continue
		var pos := Vector2(game.level_definition.sites[site])
		var score := 0.0
		for road in game.routes:
			var len: float = road.get_baked_length()
			for part in range(2, 20):
				var ratio := float(part) / 20.0
				var point: Vector2 = road.sample_baked(len * ratio, true)
				if pos.distance_squared_to(point) > reach * reach:
					continue
				var density := 0
				for tower in game.towers:
					if tower.position.distance_squared_to(point) <= pow(tower.attack_range(), 2.0):
						density += 1
				score += (1.0 + ratio) / (1.0 + float(density))
		if score > best_score:
			best_site = site
			best_score = score
	if best_site >= 0 and (not game.site_locked(best_site) or game.unlock_site(best_site)):
		game.build_tower(best_site, kind)


func _bot_defend_front(game: ArenaGame, benchmark := false) -> void:
	if not is_instance_valid(game.hero) or game.hero.knocked_out:
		return
	var target_e: ArenaEnemy = null
	var required_boss: ArenaEnemy = null
	var best_prog := -1.0
	for e in game.domain_enemies("defense"):
		if not is_instance_valid(e) or e.dead or (benchmark and e.is_flying() and not game.hero.can_hit_flying()):
			continue
		var progress: float = e.progress
		if benchmark:
			progress /= maxf(1.0, game.enemy_road(e).get_baked_length())
			if required_boss == null and game._is_required_boss(e):
				required_boss = e
		if progress > best_prog:
			best_prog = progress
			target_e = e
	if required_boss != null and best_prog < 0.92:
		target_e = required_boss
	if target_e != null:
		if benchmark:
			var reach := game.hero.attack_reach()
			var distance := game.hero.position.distance_to(target_e.position)
			if distance > reach * 0.92 or (reach > 180.0 and distance < reach * 0.25):
				var core := Vector2(game.level_definition.core)
				game.hero.command_move(target_e.position + target_e.position.direction_to(core) * reach * 0.58)
			if distance < reach:
				_bot_cast(game.hero, target_e.position)
				if target_e == required_boss:
					game.hero.begin_attack(target_e, target_e.center())
			return
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


func _bot_cast(hero: ArenaHero, target: Vector2) -> void:
	if not hero.action.is_empty() or hero.knocked_out:
		return
	if hero.skill_unlocked(1) and hero.cooldowns[1] <= 0.0:
		hero.cast(1, target)
	elif hero.skill_unlocked(0) and hero.cooldowns[0] <= 0.0:
		hero.cast(0, target)


func _bot_kite_rift(game: ArenaGame, benchmark := false) -> void:
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
		if rd.can_descend_now():
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
	if benchmark:
		_bot_cast(game.hero, best_pos)
	elif game.hero.skill_unlocked(0) and game.hero.cooldowns[0] <= 0.0:
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
	check(s_dual.recalls >= 1 and s_dual.run_lv >= 3 and s_dual.picks <= ArenaPassiveEngine.MAX_TOTAL_PICKS, "DualDomain_Synergy actively uses Rift exploration and obeys the passive cap")
	check(s_dual.towers_after_round_two >= 5, "the forest economy funds five towers before round three")
	check(s_dual.gold_end < 1500, "forest victory leaves a usable reserve instead of surplus in the thousands")
	var traced_income := 0
	for income in s_dual.gold_by_source.values():
		traced_income += int(income)
	check(traced_income == s_dual.gold_earned, "all gold income reconciles with actual expenses and ending balance")
	print("V030 SE BALANCE PROOF CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)
