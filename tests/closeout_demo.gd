extends "v06_playthrough.gd"
# Legal action recording. Only the pre-existing LV5 profile is a labelled fixture.
# Runs from normal resources, no enemy/HP/gold/wave-clock injection.
var seconds_limit:=95.0
func _process(delta: float) -> bool:
	var result:=super._process(delta)
	if game!=null and game.started and not stopping:
		if game.camera!=null and stage=="ruins":
			game.camera.focus(game.hero.position)
		if timer>=seconds_limit:
			print("CLOSEOUT DEMO hero=",hero_id," stage=",stage," normal_resources=true level=",hero_level," wave=",game.cycle," casts=",casts," kills=",game.kills," core=",game.core_health)
			passed=game.core_health>0 and casts>0 and game.kills>0
			stopping=true
			finish.call_deferred()
	return result
