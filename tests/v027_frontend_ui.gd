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
		push_error("V027 FAIL: " + message)


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


func run() -> void:
	test_v027_ui_assets()
	await test_title_and_world_map()
	await test_hero_hall_and_tower_workshop()
	await cleanup()
	print("V027 FRONTEND UI CHECKS: %d, FAILURES: %d" % [checks, failures])
	quit(0 if failures == 0 else 1)


func test_v027_ui_assets() -> void:
	var required: Array[String] = [
		"title_bg", "title_logo", "world_map", "hall_bg", "tower_pedestal_bg",
		"panel_obsidian", "panel_inset_dark", "rail_steel", "card_frame_steel", "card_frame_gold",
		"btn_cyan", "btn_gold", "btn_steel", "btn_muted",
		"dock_hero", "dock_tower", "dock_codex",
		"stage_shield_open", "stage_shield_cleared", "stage_lock_seal",
		"stat_hp", "stat_atk", "stat_spd", "stat_rng", "stat_shield",
		"star_on", "star_off", "lock_badge", "equipped_pip"
	]
	for hid: String in ArenaDefinitions.HERO_IDS:
		required.append("hero_card_" + hid)
	for key: String in required:
		var tex: Texture2D = ArenaMenuArt.v027(key)
		check(tex != null and not tex.get_image().is_invisible(), "v027 texture loaded & non-empty: " + key)

	for full_key: String in ["title_bg", "world_map", "hall_bg"]:
		var img: Image = ArenaMenuArt.v027(full_key).get_image()
		check(img.get_width() == 1600 and img.get_height() == 900, full_key + " is 1600x900")

	var logo_img: Image = ArenaMenuArt.v027("title_logo").get_image()
	check(logo_img.get_pixel(0, 0).a < 0.05, "title_logo corners keyed transparent")
	var cx: int = logo_img.get_width() / 2
	var cy: int = logo_img.get_height() / 2
	check(logo_img.get_pixel(cx, cy).a > 0.9, "title_logo center crest remains opaque")

	for hid: String in ArenaDefinitions.HERO_IDS:
		var hc: Image = ArenaMenuArt.v027("hero_card_" + hid).get_image()
		check(hc.get_width() == 360 and hc.get_height() == 540, "hero_card_%s matches 2:3 360x540 slot" % hid)


func test_title_and_world_map() -> void:
	game = load("res://scenes/arena.tscn").instantiate() as ArenaGame
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	current_scene = game
	await frames(3)

	var buttons := game.hud.menu.find_children("*", "Button", true, false)
	check(buttons.size() == 3, "title has exactly StartCampaign, Settings, ExitGame buttons")
	var logo_node := game.hud.menu.find_child("TitleLogo", true, false) as TextureRect
	check(logo_node != null and logo_node.texture == ArenaMenuArt.v027("title_logo"), "title renders v027 TitleLogo")
	var prog := game.hud.menu.get_node_or_null("TitleProgress") as Label
	check(prog != null and prog.text.ends_with("0 / 6"), "TitleProgress shows 0 / 6")

	game.hud.frontend.levels()
	await frames(2)
	var scenery := game.hud.menu.find_child("Scenery", true, false) as TextureRect
	check(scenery != null and scenery.texture == ArenaMenuArt.v027("world_map"), "world map loads v027 4-biome map")
	check(game.hud.menu.find_child("WorldDock", true, false) == null, "legacy WorldDock stays removed")
	var tray := game.hud.menu.find_child("WorldLoadout", true, false) as Control
	check(tray != null and tray.size.x < 600.0, "WorldLoadout stays compact (<600px)")
	var tray_rect := Rect2(tray.position, tray.size)

	for id: String in ArenaLevelCatalog.IDS:
		var node := game.hud.menu.find_child("Level_" + id, true, false) as Control
		check(node != null, "world stage node exists: " + id)
		var nr := Rect2(node.position, node.size)
		check(not nr.intersects(tray_rect), "stage node %s clears bottom WorldLoadout" % id)
		check(node.position.x >= 40.0 and node.position.x <= 1500.0, "stage node %s inside horizontal safe bounds" % id)

	check(ArenaLevelCatalog.FUTURE_LOCKS.size() == 4, "4 reserved future biome lock seals defined across remaining chapters")
	game.hud.frontend.prepare("forest")
	await frames(2)
	check(is_instance_valid(game.hud.frontend.stage_panel), "prepare opens StagePanel")
	check(game.hud.frontend.stage_panel.position.x >= 820.0, "StagePanel clears Vector2(600, 700) click area")
	game.hud.frontend.close_stage()


func test_hero_hall_and_tower_workshop() -> void:
	game.hud.frontend.hall()
	await frames(2)
	var menu_id: int = game.hud.menu.get_instance_id()
	var scenery := game.hud.menu.find_child("Scenery", true, false) as TextureRect
	check(scenery != null and scenery.texture == ArenaMenuArt.v027("hall_bg"), "hero hall uses calm slate hall_bg")
	check(game.hud.menu.find_children("*", "CPUParticles2D", true, false).is_empty(), "hero hall has zero screen dust particles")
	var card_id: int = game.hud.frontend.card.get_instance_id()
	var clip := game.hud.frontend.card.find_child("CardClip", true, false) as Control
	check(clip != null and clip.clip_contents, "hero CardClip enforces clean crop")

	for hid: String in ArenaDefinitions.HERO_IDS:
		game.hud.frontend.select_hall(hid)
		check(game.hud.menu.get_instance_id() == menu_id, "hero switch preserves menu node: " + hid)
		check(game.hud.frontend.card.get_instance_id() == card_id, "hero switch preserves card node: " + hid)
		check(game.hud.frontend.card_art.texture == ArenaMenuArt.v027("hero_card_" + hid), "hero card swaps full-bleed 2:3 art: " + hid)
		game.campaign.data.levels[hid] = 5
		game.hud.frontend.select_hall(hid)
		var talent_rank := int(game.campaign.bonuses(hid).passive)
		for slot in range(2):
			game.hud.frontend.select_skill(slot)
			check(game.hud.frontend.skill_body.text == ArenaDefinitions.skill_text(hid,slot,talent_rank), "hero hall uses the current combat description: "+hid)
		game.hud.frontend.select_skill(2)
		check(game.hud.frontend.skill_body.text == ArenaDefinitions.hero_talent_text(hid,talent_rank), "hero hall uses the current talent rank: "+hid)

	# Lock badge check: level 1 has E locked -> lock badge visible; level 4 -> unlocked & badge hidden
	game.campaign.data.levels["lord"] = 1
	game.hud.frontend.select_hall("lord")
	check(game.hud.frontend.skill_lock_badges[1].visible, "E skill lock badge visible at LV.1")
	game.campaign.data.levels["lord"] = 4
	game.hud.frontend.select_hall("lord")
	check(not game.hud.frontend.skill_lock_badges[1].visible, "E skill lock badge hides at LV.4")

	game.hud.frontend.towers()
	await frames(2)
	for i: int in range(4):
		var slot := game.hud.menu.find_child("LoadoutSlot_" + str(i), true, false) as Button
		check(slot != null, "equipped ring LoadoutSlot_%d exists" % i)
	game.hud.frontend.select_tower("lens")
	check(game.hud.frontend.stat_icons[1].texture == ArenaMenuArt.icon(15), "magic tower preserves magic indicator icon")
	game.hud.frontend.select_tier(3)
	var first_doc_tex: Texture2D = game.hud.frontend.card_art.texture
	check(first_doc_tex != null, "Tier 3 showcase displays live pixel tower sprite")
	game.hud.frontend.select_route(1)
	check(game.hud.frontend.card_art.texture != first_doc_tex and game.hud.frontend.route_name.text == "巡光镜", "previewing a specialization updates its artwork")
	check(game.hud.frontend.enhancement_list.get_node("Enhancement_0/Title").text == "首光棱镜" and game.campaign.tower_doctrine("lens") == "focus", "enhancements follow the preview while the saved choice stays put")

	game.hud.frontend.settings()
	await frames(1)
	check(game.hud.has_modal(), "settings opens unified obsidian modal cleanly")
	game.hud.close_modal()
