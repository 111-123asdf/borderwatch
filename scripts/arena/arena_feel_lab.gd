class_name ArenaFeelLab
extends Node
# Developer entry in the same runtime, explicit level-5 fixture, no persistent saves.
var game: ArenaGame
var panel: PanelContainer
var status: Label
var baseline: CheckButton
var size_button: CheckButton
var reduced: CheckButton

func open(owner_game: ArenaGame) -> void:
	game=owner_game
	game.campaign.data.tutorial_done=true
	panel=PanelContainer.new();panel.name="FeelLab";panel.position=Vector2(1250,105);panel.size=Vector2(330,400)
	panel.add_theme_stylebox_override("panel",ArenaMenuArt.style(1));game.hud.root.add_child(panel)
	var box:=VBoxContainer.new();box.add_theme_constant_override("separation",7);panel.add_child(box)
	var title:=Label.new();title.text="英雄手感实验场";title.add_theme_font_size_override("font_size",24);box.add_child(title)
	var heroes:=GridContainer.new();heroes.columns=3;box.add_child(heroes)
	for id in ArenaDefinitions.HERO_IDS:
		var hero_button:=Button.new();hero_button.name="LabHero_"+id;hero_button.text={"lord":"领主","druid":"德鲁伊","healer":"爱神","werewolf":"狼王","gunner":"星衡"}[id];hero_button.custom_minimum_size=Vector2(98,70);hero_button.add_theme_font_size_override("font_size",22);hero_button.disabled=id==game.hero.class_id;hero_button.pressed.connect(select_hero.bind(id));heroes.add_child(hero_button)
	status=Label.new();status.text="测试夹具 · 永久5级\n不写入正常存档";status.add_theme_font_size_override("font_size",22);box.add_child(status)
	baseline=CheckButton.new();baseline.name="LabBaseline";baseline.text="基础反馈对照";baseline.toggled.connect(func(_value):apply());box.add_child(baseline)
	size_button=CheckButton.new();size_button.name="LabScale";size_button.text="人物视觉 ×1.3";size_button.button_pressed=true;size_button.toggled.connect(func(_value):apply());box.add_child(size_button)
	reduced=CheckButton.new();reduced.name="LabReduced";reduced.text="减少动态";reduced.toggled.connect(func(_value):apply());box.add_child(reduced)
	for toggle in [baseline,size_button,reduced]:
		toggle.custom_minimum_size=Vector2(300,58);toggle.add_theme_font_size_override("font_size",22)
	var commands:=GridContainer.new();commands.columns=2;box.add_child(commands)
	for item in [["LabTargets","重新布置敌人",reset_targets],["LabSkill",game.hero.data.small,small],["LabCry",game.hero.data.ultimate,ultimate],["LabExit","返回正式地图",leave]]:
		var button:=Button.new();button.name=item[0];button.text=item[1];button.custom_minimum_size=Vector2(147,70);button.add_theme_font_size_override("font_size",19);button.pressed.connect(item[2]);commands.add_child(button)
	if game.get_tree().has_meta("feel_lab_options"):
		var options: Dictionary=game.get_tree().get_meta("feel_lab_options");game.get_tree().remove_meta("feel_lab_options")
		baseline.set_pressed_no_signal(options.old);size_button.set_pressed_no_signal(options.large);reduced.set_pressed_no_signal(options.reduced);apply()
	reset_targets()

func select_hero(key: String) -> void:
	if key not in ArenaDefinitions.HERO_IDS:return
	game.feel.clear(game);game.get_tree().paused=false
	game.get_tree().set_meta("feel_lab_hero",key)
	game.get_tree().set_meta("feel_lab_options",{"old":baseline.button_pressed,"large":size_button.button_pressed,"reduced":reduced.button_pressed})
	game.get_tree().reload_current_scene()

func apply() -> void:
	game.feel.clear(game);game.effects.clear();game.numbers.clear()
	game.feel.enabled=not baseline.button_pressed;game.audio.sampled=game.feel.enabled
	for player in game.audio.players:player.stop()
	game.audio.last_play.clear();game.audio.variants.clear();game.audio.cursor=0
	game.feel.unit_scale=1.3 if size_button.button_pressed else 1.0
	game.campaign.data.reduced_motion=reduced.button_pressed
	game.hero.visual.configure(game.hero.class_id,ArenaHeroArt.height(game.hero.class_id,game.feel.enabled,game.feel.unit_scale),game.feel.enabled)
	game.hero.visual.feedback.reduced=reduced.button_pressed
	game.hero.cancel_action();game.hero.visual.show_state("idle",Vector2.RIGHT)
	for enemy in game.enemies:
		if is_instance_valid(enemy):enemy.visual.feedback.enabled=game.feel.enabled

func reset_targets() -> void:
	game.running=true;game.game_over=false;game.core_health=game.core_max
	game.feel.clear(game);game.effects.clear();game.numbers.clear()
	for corpse in game.corpses:
		if is_instance_valid(corpse.node):corpse.node.queue_free()
	game.corpses.clear();game.hero.war_cry=0;game.hero.attack_cooldown=0
	game.gold=ArenaGame.START_GOLD;game.kills=0;game.wave_kills=0;game.damage_stats={"hero":0.0,"tower":0.0,"soldier":0.0}
	game.hero.shots=0
	game.hero.knocked_out=false;game.hero.revive_clock=0;game.hero.rolling=0
	for enemy in game.enemies.duplicate():
		if is_instance_valid(enemy):game.remove_enemy(enemy)
	game.hero.position=game.routes[0].sample_baked(600.0);game.hero.path.clear();game.hero.health=game.hero.max_health
	game.hero.cooldowns=[0.0,0.0];game.hero.cancel_action()
	for beast in game.hero.companions:
		beast.show();beast.health=beast.max_health();beast.recovery=0.0;beast.windup=0.0;beast.orders_left=0.0;beast.boost=0.0;beast.position=game.hero.position+Vector2(-28 if beast.slot==0 else 28,12)
	for offset in [45.0,82.0,125.0,170.0]:game.spawn_enemy("fox" if offset<150 else "brute",0,600.0-offset)
	game.hero.facing=(game.routes[0].sample_baked(560.0)-game.hero.position).normalized()
	status.text="5级测试档 · 不保存\n左键/WASD/右键 · Q/E"

func small() -> void:
	game.hero.cast(0,game.hero.position+game.hero.facing*100)
func ultimate() -> void:
	game.hero.cast(1,game.hero.position+game.hero.facing*100)
func leave() -> void:
	game.feel.clear(game)
	# The reload deliberately drops the one-shot CLI fixture marker.
	game.get_tree().set_meta("feel_lab_consumed",true);game.return_to_menu()
