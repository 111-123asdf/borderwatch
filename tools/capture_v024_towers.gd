extends SceneTree
var out_dir := ProjectSettings.globalize_path("res://test-results/v024-showcase")
var game: ArenaGame

func _initialize() -> void:
	if DirAccess.make_dir_recursive_absolute(out_dir) != OK:
		push_error("Invalid showcase output directory: " + out_dir)
		quit(1)
		return
	call_deferred("run")

func frames(n := 4) -> void:
	for _i in range(n):
		await process_frame

func snap(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := out_dir.path_join(filename)
	if img.save_png(path) != OK:
		push_error("Could not save showcase frame: " + path)
		quit(1)
		return
	print("SAVED: ", path)

func cleanup() -> void:
	if is_instance_valid(game):
		game.running = false
		game.audio.shutdown()
		await frames(2)
		OS.delay_msec(120)
		game.queue_free()
		await frames(2)

func setup_battle(hero_id: String, stage: String, loadout: Array = []) -> void:
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	for id in ArenaDefinitions.HERO_IDS:
		game.campaign.data.levels[id] = 5
	if not loadout.is_empty():
		game.campaign.equip_towers(loadout)
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.start_run(hero_id, stage)
	await frames(2)
	if not game.rule_offers.is_empty():
		game.choose_defense_rule("")
	await frames(2)

func finish_tower_fast(t: ArenaTower) -> void:
	if t != null and t.project_level != 0:
		t._physics_process(1.1)

func run() -> void:
	# 1. Tower Workshop: 7 Gold-Framed Portraits + L3 Specialization Preview
	game = load("res://scenes/arena.tscn").instantiate()
	game.campaign = ArenaCampaign.new("", false)
	root.add_child(game)
	current_scene = game
	await frames(3)
	game.hud.frontend.towers()
	await frames(2)
	game.hud.frontend.select_tower("mage")
	game.hud.frontend.select_tier(3)
	game.hud.frontend.select_route(1)  # 奥火塔
	await frames(4)
	await snap("01_workshop_l3_preview.png")
	await cleanup()

	# 2. Ruins 5 Plinths (normal, highground, choke, conduit, locked) + Gold Build Menu + Construction Scaffold
	await setup_battle("lord", "ruins", ["archer", "mage", "cannon", "storm"])
	game.cycle = 5
	game.phase = "rest"
	game.gold = 2000
	game.build_tower(1, "cannon")
	var t_scaf := game.site_tower(1)
	if t_scaf != null:
		t_scaf._physics_process(0.35)
	game.hud.show_context(0)
	await frames(4)
	await snap("02_plinths_and_build_menu.png")
	await cleanup()

	# 3. Original 4 Towers L3 + Soldiers + Pixel Arrows / Arcfire / Burning Mortar Blast / Flags
	await setup_battle("lord", "forest", ["archer", "mage", "cannon", "barracks"])
	game.cycle = 5
	game.phase = "spawn"
	game.gold = 5000
	var b_specs := [
		[0, "archer", "sentinel"],
		[1, "mage", "arcfire"],
		[2, "cannon", "burning"],
		[3, "barracks", "shield"],
		[4, "archer", "piercer"],
		[5, "barracks", "charge"],
	]
	for sp in b_specs:
		var idx := int(sp[0])
		if idx >= game.level_definition.sites.size(): continue
		if game.site_locked(idx): game.unlock_site(idx)
		game.build_tower(idx, str(sp[1]))
		var tw := game.site_tower(idx)
		finish_tower_fast(tw)
		tw.upgrade(); finish_tower_fast(tw)
		tw.upgrade(str(sp[2])); finish_tower_fast(tw)
	# Clear initial upgrade halos so combat VFX and crisp towers show unobstructed
	game.effects.clear()
	var mob_pts := [380.0, 420.0, 460.0, 500.0, 540.0]
	var enemies_o: Array[ArenaEnemy] = []
	for p_off in mob_pts:
		var e := game.spawn_enemy("tusk_fighter", 0, p_off)
		e.max_health = 3000; e.health = 3000
		enemies_o.append(e)
	var t_arch := game.site_tower(0)
	var t_mage := game.site_tower(1)
	var t_can := game.site_tower(2)
	var t_pier := game.site_tower(4)
	if t_can != null:
		t_can.fire_cannon(enemies_o[2], 70.0)
	await create_timer(0.24).timeout
	if t_mage != null:
		t_mage._fire_at(enemies_o[1], true)
	if t_arch != null:
		t_arch._fire_at(enemies_o[1], true)
	if t_pier != null:
		t_pier._fire_at(enemies_o[3], true)
	await create_timer(0.14).timeout
	await snap("03_original4_combat_vfx.png")
	await cleanup()

	# 4. New 3 Towers L3 + Hunter Barracks: Surge/Fork Lightning, Escalating Solar Beam, Snare Net & Barb Traps
	await setup_battle("gunner", "forest", ["storm", "lens", "snare", "barracks"])
	game.cycle = 5
	game.phase = "spawn"
	game.gold = 5000
	var n_specs := [
		[0, "storm", "surge"],
		[1, "lens", "focus"],
		[2, "snare", "net"],
		[3, "barracks", "hunter"],
		[4, "storm", "fork"],
		[5, "snare", "barb"],
	]
	for sp in n_specs:
		var idx := int(sp[0])
		if idx >= game.level_definition.sites.size(): continue
		if game.site_locked(idx): game.unlock_site(idx)
		game.build_tower(idx, str(sp[1]))
		var tw := game.site_tower(idx)
		finish_tower_fast(tw)
		tw.upgrade(); finish_tower_fast(tw)
		tw.upgrade(str(sp[2])); finish_tower_fast(tw)
	game.effects.clear()
	var t_st0 := game.site_tower(0)
	var t_ln1 := game.site_tower(1)
	var t_sn2 := game.site_tower(2)
	var t_st4 := game.site_tower(4)
	var n_enemies: Array[ArenaEnemy] = []
	for k in range(5):
		var pos_x := t_st0.position.x + 35.0 + float(k) * 58.0
		var pos_y := t_st0.position.y + (20.0 if k % 2 == 0 else -15.0)
		var e := game.spawn_enemy("bear_vanguard", 0, 320.0)
		e.position = Vector2(pos_x, pos_y)
		e.max_health = 3000; e.health = 3000
		n_enemies.append(e)
	if t_sn2 != null:
		n_enemies[4].position = t_sn2.rally_point + Vector2(4, 0)
		t_sn2.attack_clock = 0.0
		t_sn2.try_snare()
	if t_ln1 != null:
		for _l in range(4):
			t_ln1.fire_lens(n_enemies[1], 32.0)
	if t_st0 != null:
		t_st0.fire_chain(n_enemies[0], 45.0)
	if t_st4 != null:
		t_st4.fire_chain(n_enemies[2], 45.0)
	await frames(2)
	await snap("04_new3_combat_vfx.png")
	await cleanup()

	# 5. Full Gallery: All 7 Towers x 5 Forms (35 Towers) + 4 Soldier Variants at Actual World Scale
	await setup_battle("lord", "forest")
	game.running = false
	var layer := CanvasLayer.new()
	layer.layer = 50
	game.add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.22, 0.19, 1.0)
	bg.size = Vector2(1600, 900)
	layer.add_child(bg)
	var kinds := ["archer", "mage", "cannon", "barracks", "storm", "lens", "snare"]
	var forms := {
		"archer": ["lv1", "lv2", "sentinel", "repeater", "piercer"],
		"mage": ["lv1", "lv2", "frost", "arcfire", "breaker"],
		"cannon": ["lv1", "lv2", "siege", "burning", "frag"],
		"barracks": ["lv1", "lv2", "shield", "hunter", "charge"],
		"storm": ["lv1", "lv2", "fork", "relay", "surge"],
		"lens": ["lv1", "lv2", "focus", "sweep", "far_lens"],
		"snare": ["lv1", "lv2", "net", "barb", "ratchet"],
	}
	for r_i in range(kinds.size()):
		var k: String = kinds[r_i]
		var flist: Array = forms[k]
		var base_y := 116.0 + float(r_i) * 124.0
		for c_i in range(flist.size()):
			var f_id: String = str(flist[c_i])
			var tier := 1 if c_i == 0 else (2 if c_i == 1 else 3)
			var doc := "" if tier < 3 else f_id
			var x_pos := 110.0 + float(c_i) * 255.0
			var gal_scale := 0.84
			var pl := Sprite2D.new()
			pl.texture = load("res://assets/towers_v024/plinth_normal.png")
			pl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pl.position = Vector2(x_pos, base_y + 3.0)
			pl.scale = Vector2(108.0 / 192.0, 72.0 / 128.0) * gal_scale
			layer.add_child(pl)
			var sp := Sprite2D.new()
			sp.texture = ArenaBattleArt.tower_frame_texture(k, tier, doc, 0)
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var pl_c := ArenaBattleArt.contact(k, tier, sp.texture.get_size(), doc)
			sp.scale = pl_c.scale * gal_scale
			sp.offset = (Vector2(0.5, 0.5) - Vector2(pl_c.uv)) * sp.texture.get_size()
			sp.position = Vector2(x_pos, base_y)
			layer.add_child(sp)
			var lbl := Label.new()
			lbl.text = k + "_" + f_id
			lbl.position = Vector2(x_pos + 52.0, base_y - 18.0)
			lbl.add_theme_font_size_override("font_size", 11)
			layer.add_child(lbl)
	# Right column: 4 soldier variants
	for si in range(4):
		var skeys: Array[String] = ["soldier_base", "soldier_shield", "soldier_hunter", "soldier_charge"]
		var skey: String = skeys[si]
		var cr := ArenaCreature.new()
		layer.add_child(cr)
		cr.configure(skey, 52.0 if skey == "soldier_shield" else 47.0)
		cr.show_pose("attack", Vector2.RIGHT)
		cr.frame = 3
		cr.pause()
		cr.position = Vector2(1420.0, 190.0 + float(si) * 180.0)
		var slbl := Label.new()
		slbl.text = skey
		slbl.position = cr.position + Vector2(-46, 16)
		layer.add_child(slbl)
	await frames(4)
	await snap("05_gallery_all35_towers.png")
	await cleanup()

	# 6. Melee Duel & Perfect Dodge Readability: Directional Cone + Urgent Glint + Perfect Dodge Counter Stance
	await setup_battle("lord", "forest", ["archer", "mage", "cannon", "barracks"])
	game.cycle = 3
	game.phase = "spawn"
	game.spawn_queue.clear()
	var hero := game.hero
	hero.position = Vector2(760.0, 440.0)
	hero.facing = Vector2.RIGHT
	hero.dodge_cooldown = 0.0
	var proj := game.fire_projectile(hero.center() + Vector2(-46.0, 0.0), hero.center() + Vector2(60.0, 0.0), 15.0, 0, "enemy", {"speed": 260.0, "appearance": "viper_arrow"})
	hero.try_dodge(Vector2.UP)
	await frames(2)
	var van := game.spawn_enemy("bear_vanguard", 0, 300.0)
	van.position = hero.position + Vector2(72.0, 6.0)
	van.facing = Vector2.LEFT
	van.melee_clock = 0.0
	van.melee(hero)
	van.melee_windup = 0.16
	if is_instance_valid(van.visual):
		van.visual.frame = 2
	var tusk := game.spawn_enemy("tusk_fighter", 0, 285.0)
	tusk.position = hero.position + Vector2(-95.0, 28.0)
	game.set_physics_process(false)
	hero.set_physics_process(false)
	van.set_physics_process(false)
	tusk.set_physics_process(false)
	if is_instance_valid(proj):
		proj.set_physics_process(false)
	van.queue_redraw()
	hero.queue_redraw()
	await frames(3)
	await snap("06_melee_duel_and_dodge.png")
	await cleanup()

	quit(0)
