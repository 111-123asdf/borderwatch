extends SceneTree

func _initialize() -> void:
	var output := FileAccess.open("res://docs/godot-copyright.txt", FileAccess.WRITE)
	output.store_string("Godot Engine " + Engine.get_version_info().string + "\n\n" + Engine.get_license_text() + "\n\n")
	output.store_string("THIRD-PARTY COMPONENTS\n\n")
	for item in Engine.get_copyright_info():
		output.store_string(JSON.stringify(item, "\t") + "\n\n")
	var licenses := Engine.get_license_info()
	for key in licenses:
		output.store_string(str(key) + "\n" + str(licenses[key]) + "\n\n")
	output.close()
	quit()
