extends SceneTree

var checks := 0
var failures := 0
var game: ArenaGame


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("V028 FAIL: " + message)


func frames(count := 2) -> void:
	for _i in range(count):
		await process_frame


func cleanup() -> void:
	paused = false
	if is_instance_valid(game):
		game.running = false
		game.audio.shutdown()
		await frames(2)
		OS.delay_msec(120)
		game.queue_free()
		await frames(2)
	game = null


func run() -> void:
	await test_legacy_purge()
	test_deck_and_assets()
	await test_six_stages_unified()
	await test_ui_flow_and_unrestricted_towers()
	print("V028 PASSIVE SYSTEM CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func test_legacy_purge() -> void:
	var deleted: Array[String] = [
		"arena_perks.gd", "arena_perk_codex.gd", "arena_perk_network.gd",
		"arena_keystones.gd", "arena_passives.gd", "arena_conditions.gd",
		"arena_rule_deck.gd", "arena_defense_orders.gd"
	]
	for fname: String in deleted:
		check(not FileAccess.file_exists("res://scripts/arena/" + fname), "deleted legacy file stays gone: " + fname)

	game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	current_scene = game
	await frames(2)
	for legacy_fn: String in ["show_codex", "show_choices", "show_passive_choices", "show_keystone_choices", "show_rule_choice"]:
		check(not game.hud.has_method(legacy_fn), "ArenaHUD removes legacy method: " + legacy_fn)
	game.hud.frontend.levels()
	await frames(2)
	check(game.hud.root.find_child("被动图鉴", true, false) == null, "world map removes 被动图鉴 dock entry")
	await cleanup()


func test_deck_and_assets() -> void:
	check(ArenaPassiveEngine.PASSIVES.size() == 14, "v0.31 passive engine holds 14 distinct active-FX passives")
	var pe := ArenaPassiveEngine.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var offers := pe.draw_offers(rng, 3)
	check(offers.size() == 3, "draws 3 passive offers cleanly")
	for card: Dictionary in offers:
		var sn := str(card.get("short_name", ""))
		check(sn.length() >= 2 and sn.length() <= 6, "short_name compact: " + sn)
		check(not str(card.get("tagline", "")).is_empty(), "non-empty 1-line tagline")
		var tex: Texture2D = ArenaMenuArt.passive_medal(str(card.id))
		check(tex != null and not tex.get_image().is_invisible(), "passive medal non-empty: " + str(card.id))


func test_six_stages_unified() -> void:
	for stage: String in ArenaLevelCatalog.IDS:
		game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
		game.campaign = ArenaCampaign.new("", false)
		root.add_child(game)
		current_scene = game
		await frames(2)
		game.start_run("lord", stage)
		await frames(2)
		check(not paused and game.passive_offers.is_empty(), stage + " deploys cleanly into battle without curse popups")
		check(game.total_waves() == 5 and game.rift_domain != null, stage + " mounts 5-round campaign and Rift domain")
		if stage == "ruins":
			check(game.hud.root.find_child("Resonance", true, false) == null, "ruins removes Resonance R button")
			check(game.hud.bridge_button != null, "ruins keeps drawbridge G button")
			check(game.trigger_bridge_gate(), "ruins drawbridge triggers cleanly")
		await cleanup()


func test_ui_flow_and_unrestricted_towers() -> void:
	game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	current_scene = game
	await frames(2)
	game.rng.seed = 3
	game.start_run("lord", "creek")
	await frames(2)

	game.gain_run_xp(120.0)
	await frames(2)
	check(not paused and game.passive_offers.is_empty() and game.passive_engine.pending_ups == 1, "XP level up queues silently without interrupting combat")
	check(game.hud.passive_ready_badge != null and game.hud.passive_ready_badge.visible, "PassiveReadyBadge highlights pending [Tab] choice")
	check(game.open_pending_passive_choice(), "open_pending_passive_choice opens queued passive modal")
	await frames(2)
	check(paused and game.passive_offers.size() == 3, "queued open presents 3 passive choices")
	var first_id := str(game.passive_offers[0].id)
	var detail_btn := game.hud.modal.find_child("PassiveDetail_" + first_id, true, false) as Button
	detail_btn.pressed.emit()
	await frames(2)
	var popover := game.hud.modal.find_child("PassiveDetailPopover", true, false) as Panel
	check(popover != null and popover.visible, "clicking 详情 opens PassiveDetailPopover")
	check(paused and game.passive_offers.size() == 3, "详情 popover does not select or close cards")
	var close_btn := popover.find_child("ClosePassiveDetail", true, false) as Button
	close_btn.pressed.emit()
	await frames(1)
	check(not popover.visible, "ClosePassiveDetail dismisses detail popover")

	var card_btn := game.hud.modal.find_child("PassiveOffer_" + first_id, true, false) as Button
	check(game.hud.is_passive_input_locked(), "0.55s anti-misclick lock active immediately on modal open")
	card_btn.pressed.emit()
	await frames(1)
	check(paused and game.passive_engine.rank(first_id) == 0, "anti-misclick blocks accidental instant click")
	OS.delay_msec(600)
	await frames(1)
	check(not game.hud.is_passive_input_locked(), "anti-misclick unlocks after 0.55s")
	card_btn.pressed.emit()
	await frames(2)
	check(not paused and game.passive_offers.is_empty() and game.passive_engine.rank(first_id) == 1, "selecting passive closes modal and increments rank")

	game.hud.update_clock = 0.0
	game.hud._process(0.1)
	await frames(2)

	var strip := game.hud.owned_passives_box
	check(strip != null and strip.visible and strip.position.x >= 1000.0, "OwnedPassivesStrip visible in bottom-right safe slot")
	var owned_slot := strip.find_child("OwnedPassive_" + first_id, true, false) as Button
	check(owned_slot != null, "OwnedPassive_%s exists in strip" % first_id)
	owned_slot.pressed.emit()
	await frames(1)
	check(game.hud.owned_passive_popover != null and game.hud.owned_passive_popover.visible, "clicking bottom-right badge opens OwnedPassivePopover")

	game.hud.show_pause()
	await frames(2)
	check(paused and game.hud.has_modal(), "Pause opens obsidian handbook")
	check(game.hud.modal.find_child("OpenSettingsFromPause", true, false) != null, "Pause handbook offers quick keybind access")
	game.hud.resume()
	await frames(2)

	game.gold = 2000
	game.begin_wave()
	check(game.phase == "spawn", "wave enters active combat")
	check(game.can_change_towers() and game.can_sell_towers(), "mid-wave building & selling are unlocked")
	check(game.build_tower(0, "archer"), "mid-wave tower build succeeds")
	var t := game.site_tower(0)
	t.finish_project()
	t.gain_auto_xp(60.0)
	check(t.level == 2 and t.sell(), "automated tower levels to L2 & mid-wave sell succeeds")

	game.finish(true)
	await frames(2)
	check(game.hud.modal != null and game.hud.modal.find_child("RetryRun", true, false) != null, "result modal exposes RetryRun")
	check(game.hud.modal.find_child("ResultHeroHall", true, false) != null, "result modal exposes ResultHeroHall")
	await cleanup()
