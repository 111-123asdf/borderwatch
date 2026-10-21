extends SceneTree

func _initialize() -> void:
	var checks := {
		"version_0.3": ProjectSettings.get_setting("application/config/version") == "0.3.0",
		"main_scene": ResourceLoader.exists("res://scenes/main.tscn"),
		"hero_portraits": ResourceLoader.exists("res://assets/ui/heroes-0.3.png"),
		"hero_run_atlas": ResourceLoader.exists("res://assets/ui/hero-run-0.3.png"),
		"cover_atlas": ResourceLoader.exists("res://assets/ui/cover-0.3.png"),
		"passive_icons": ResourceLoader.exists("res://assets/ui/passives.png"),
		"no_commercial_references": not DirAccess.dir_exists_absolute("res://paper video"),
		"no_tests": not FileAccess.file_exists("res://tests/game_tests.gd"),
		"no_readme": not FileAccess.file_exists("res://README.md"),
		"no_tools": not FileAccess.file_exists("res://tools/native_smoke.py"),
		"no_toolchain": not DirAccess.dir_exists_absolute("res://toolchain"),
		"no_handoff": not DirAccess.dir_exists_absolute("res://handoff"),
		"no_agent_instructions": not FileAccess.file_exists("res://AGENTS.md"),
		"no_handoff_manifest": not FileAccess.file_exists("res://HANDOFF-MANIFEST.json"),
		"no_local_drafts": not DirAccess.dir_exists_absolute("res://_local"),
		"no_git_metadata": not DirAccess.dir_exists_absolute("res://.git"),
		"no_ci_configuration": not DirAccess.dir_exists_absolute("res://.github"),
	}
	print("EXPORT AUDIT: " + JSON.stringify(checks))
	quit(0 if checks.values().all(func(passed): return passed) else 1)
