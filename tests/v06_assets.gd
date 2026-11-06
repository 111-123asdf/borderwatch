extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("ASSET FAIL: "+message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	for hero in ArenaDefinitions.HERO_IDS:
		var actor:=ArenaActor.new();root.add_child(actor);actor.configure(hero)
		check(actor.has_complete_set(),"all hero directions/states "+hero)
		for view in ["side","up","down"]:
			for state in ArenaActor.STATES:
				var name: String=state+"_"+view
				check(actor.sprite_frames.get_frame_count(name)==6,"six animation frames "+name)
				var weight:=0.0
				for i in range(6):weight+=actor.sprite_frames.get_frame_duration(name,i)
				check(is_equal_approx(weight,6.0),"phase holds preserve total action duration "+name)
				var frame: Texture2D=actor.sprite_frames.get_frame_texture(name,2)
				check(not frame.get_image().is_invisible(),"nonempty hero state "+hero+name)
		actor.queue_free()
	for key in ["fox","brute","wisp","spearman","spore","moth","soldier"]:
		var creature:=ArenaCreature.new();root.add_child(creature);creature.configure(key)
		for name in ["walk","attack","down"]:
			check(creature.sprite_frames.has_animation(name) and creature.sprite_frames.get_frame_count(name)==6,"creature sequence "+key+name)
		creature.queue_free()
	for path in ["map_forest","map_creek","props","towers"]:
		check(ResourceLoader.exists("res://assets/v06/"+path+".png"),"final asset "+path)
	var atlas: Texture2D=load("res://assets/v06/towers.png")
	for x in range(4):
		var previous:=PackedByteArray()
		for y in range(3):
			var region:=atlas.get_image().get_region(Rect2i(x*atlas.get_width()/4,y*atlas.get_height()/3,atlas.get_width()/4,atlas.get_height()/3))
			check(not region.is_invisible(),"tower tier nonempty")
			var bytes:=region.get_data();check(bytes!=previous,"tower tiers have distinct drawings");previous=bytes
	await process_frame
	print("V06 ASSET CHECKS: %d, FAILURES: %d"%[checks,failures]);quit(0 if failures==0 else 1)
