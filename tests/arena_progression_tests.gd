extends SceneTree

# Uses unique files in the test user directory. Battle values below are fixture
# inputs for persistence/settlement checks, not a natural playthrough.
var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("PROGRESSION FAIL: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var prefix := "user://arena_progression_test_%d" % OS.get_process_id()
	var path := prefix + ".cfg"
	var old_path := prefix + "_old.cfg"
	var corrupt_path := prefix + "_corrupt.cfg"
	var old := FileAccess.open(old_path, FileAccess.WRITE)
	old.store_string("old profile must stay intact")
	old.close()
	check(ArenaProgression.SAVE_PATH != "user://hero_progression.cfg", "Arena uses a different profile from the previous mode")
	var first := ArenaProgression.new(path, true)
	check(first.bonuses("knight").health == 0.0 and first.points("knight") == 0, "New hero has no bonus or points")
	check(ArenaProgression.battle_reward(0, 0, false) == 0, "Immediate defeat grants no experience")
	check(first.grant_experience("knight", 80) == 80 and first.points("knight") == 1, "Battle experience creates one point")
	check(first.upgrade("knight", "health") and first.bonuses("knight").health == 3.0, "A point buys one small health bonus")
	check(not first.upgrade("knight", "health"), "No second upgrade without points")
	check(first.grant_experience("ranger", 80) == 80 and first.upgrade("ranger", "shield"), "A second hero can progress independently")
	var reloaded := ArenaProgression.new(path, true)
	check(reloaded.entry("knight").xp == 80 and reloaded.bonuses("knight").health == 3.0, "Profile survives a fresh object")
	check(reloaded.entry("ranger").shield == 1 and reloaded.entry("mage").xp == 0, "Hero profiles remain separate")
	check(FileAccess.get_file_as_string(old_path) == "old profile must stay intact", "Writing the arena profile does not modify the older profile")
	check(reloaded.grant_experience("knight", 10000) == ArenaProgression.MAX_XP - 80, "Experience stops at the maximum")
	for index in range(4): check(reloaded.upgrade("knight", "health"), "Health upgrade %d can be spent" % index)
	check(not reloaded.upgrade("knight", "health") and reloaded.bonuses("knight").health == 15.0, "Health is capped at five ranks")
	var broken := FileAccess.open(corrupt_path, FileAccess.WRITE)
	var corrupt_content := "[meta]\nversion=1\n[knight]\nxp=\"bad\"\n"
	broken.store_string(corrupt_content)
	broken.close()
	var bad := ArenaProgression.new(corrupt_path, true)
	check(bad.locked and bad.grant_experience("knight", 80) == -1, "Damaged profile is locked against overwriting")
	check(FileAccess.get_file_as_string(corrupt_path) == corrupt_content, "Damaged profile remains untouched")
	var unavailable := ArenaProgression.new(prefix + "_missing/profile.cfg", true)
	check(unavailable.grant_experience("knight", 80) == -1 and unavailable.entry("knight").xp == 0 and not unavailable.last_error.is_empty(), "Write failure reports an error and rolls back")
	var game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_with_hero("knight")
	var original_health: float = game.hero.max_health
	game.progression.grant_experience("knight", 80)
	game.progression.upgrade("knight", "health")
	game.hero.configure("knight")
	check(game.hero.max_health == original_health + 3.0, "Chosen health bonus takes effect at configure")
	game.stats.kills = 5
	game.hero.take_damage(9999.0)
	var after_finish: int = game.progression.entry("knight").xp
	game.core_hit(9999.0)
	check(game.progression_reward == 10 and game.progression.entry("knight").xp == after_finish, "Settlement grants real-kill reward exactly once")
	await process_frame
	check(game.defeat_reason == "hero" and game.hud.result_label.text.begins_with("英雄倒下"), "Hero death shows hero defeat and later core damage cannot change it")
	check("成长经验 +10" in game.hud.result_label.text and "未写入" in game.hud.result_label.text, "Test-mode result discloses unsaved experience")
	game.queue_free()
	await process_frame
	var core_game = load("res://scenes/arena.tscn").instantiate()
	root.add_child(core_game)
	await process_frame
	core_game.start_with_hero("knight")
	core_game.stats.kills = 5
	core_game.core_hit(9999.0)
	await process_frame
	check(core_game.hero.health > 0.0 and core_game.defeat_reason == "core" and core_game.hud.result_label.text.begins_with("核心失守"), "Core defeat is shown while hero is alive")
	check(core_game.progression_reward == 10, "Core defeat retains the existing settlement reward")
	core_game.hero_died()
	check(core_game.defeat_reason == "core" and core_game.progression_reward == 10, "Later hero death cannot replace core defeat or settle again")
	core_game.queue_free()
	await process_frame
	await create_timer(1.0, true, false, true).timeout
	for file_path in [path, path + ".tmp", old_path, corrupt_path]:
		if FileAccess.file_exists(file_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
	print("ARENA PROGRESSION CHECKS: %d, FAILURES: %d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
