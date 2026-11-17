extends "v06_playthrough.gd"
# Continuous automatic action preview. Normal in-run resources; not a full clear.
var camera_segment:=-1
func _process(delta: float) -> bool:
	var result:=super._process(delta)
	if game!=null and game.started:
		var segment:=int(timer/11.0)
		if segment!=camera_segment:
			camera_segment=segment
			if segment in [0,3]:game.camera.toggle_overview() if not game.camera.overview else game.camera.focus(game.hero.position)
			elif segment==1:game.camera.focus(game.bridge_gate_point())
			else:game.camera.focus(game.hero.position)
	if timer>=55.0 and not stopping:
		print("V017 CONTINUOUS PREVIEW: 55 seconds, normal in-run resources, automatic player")
		passed=true;stopping=true;finish.call_deferred()
	return result
