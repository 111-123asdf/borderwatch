class_name ArenaBattleCamera
extends Camera2D
var game: ArenaGame
var overview:=false
var dragging:=false
var saw_pointer:=false
func large_map() -> bool:return game!=null and game.started and game.world_size().x>1600
func sync_domain() -> void:
	if game == null or not game.started: return
	overview = false
	dragging = false
	offset = Vector2.ZERO
	game.feel.trauma = 0.0
	zoom = Vector2.ONE
	if game.active_domain == "rift":
		if is_instance_valid(game.hero):
			position = game.hero.position
		elif game.rift_domain != null:
			position = game.rift_domain.rift_world_rect().get_center()
		else:
			position = ArenaRiftDomain.RIFT_ORIGIN + Vector2(2000.0, 1500.0)
	else:
		position = game.level_definition.core if large_map() else game.world_size() * 0.5
	clamp_to_map()
	force_update_scroll()
func configure() -> void:
	overview=false;zoom=Vector2.ONE;position=game.level_definition.core if large_map() else game.world_size()*0.5
	clamp_to_map();force_update_scroll()
func clamp_to_map() -> void:
	var half: Vector2=get_viewport_rect().size*0.5/zoom
	if game != null and game.active_domain == "rift":
		var rrect := game.rift_domain.rift_world_rect() if game.rift_domain != null else Rect2(ArenaRiftDomain.RIFT_ORIGIN, Vector2(5600.0, 4200.0))
		half = half.min(rrect.size * 0.5)
		position = position.clamp(rrect.position + half, rrect.end - half)
		return
	var world:=game.world_size()
	half=half.min(world*0.5)
	position=position.clamp(half,world-half)
func toggle_overview() -> void:
	if not large_map():return
	overview=not overview
	zoom=Vector2.ONE*(0.78 if overview else 1.0)
	if overview:position=game.world_size()*0.5
	clamp_to_map();force_update_scroll()
func focus(point: Vector2) -> void:
	if not large_map():return
	overview=false;zoom=Vector2.ONE;position=point;clamp_to_map();force_update_scroll()
func _input(event: InputEvent) -> void:
	if not large_map() or get_tree().paused or (game != null and game.active_domain == "rift"):return
	if event is InputEventMouseMotion:saw_pointer=true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE:
		dragging=event.pressed;get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging:
		if overview:overview=false;zoom=Vector2.ONE
		position-=event.relative/zoom;clamp_to_map();get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_M:toggle_overview();get_viewport().set_input_as_handled()
		elif event.keycode==KEY_C and game.hero!=null:focus(game.hero.position);get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	if game == null or not game.started or not game.running or get_tree().paused:
		return
	if game.active_domain == "rift":
		if is_instance_valid(game.hero):
			var follow_t := 1.0 if bool(game.campaign.data.reduced_motion) else 1.0 - exp(-9.5 * minf(delta, 0.08))
			position = position.lerp(game.hero.position, follow_t)
			clamp_to_map()
		return
	if not large_map() or not saw_pointer or overview or dragging or game.hud.has_modal():return
	var mouse:=get_viewport().get_mouse_position();var viewport:=get_viewport_rect().size
	if mouse.x<0 or mouse.y<0 or mouse.x>viewport.x or mouse.y>viewport.y:return
	var hover:=get_viewport().gui_get_hovered_control()
	if hover!=null and game.hud.root.is_ancestor_of(hover) and hover.mouse_filter!=Control.MOUSE_FILTER_IGNORE:return
	var direction:=Vector2.ZERO
	if mouse.x<12:direction.x=-1
	elif mouse.x>viewport.x-12:direction.x=1
	if mouse.y<12:direction.y=-1
	elif mouse.y>viewport.y-12:direction.y=1
	position+=direction.normalized()*560*delta;clamp_to_map()
