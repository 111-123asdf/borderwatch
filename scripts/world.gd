class_name ForestWorld
extends Node2D

var game: Node2D
var sand: Dictionary = {}
var ground: Texture2D
var decoration: Array[Dictionary] = []
var cover_rects: Array[Rect2] = []

func _ready() -> void:
	ground = Art.texture("Terrain/Ground/Tilemap_Flat.png")
	var tone := ShaderMaterial.new()
	tone.shader = load("res://assets/terrain_tone.gdshader")
	material = tone
	for column in range(int(Rules.WORLD_SIZE.x / 64)):
		for row in range(int(Rules.WORLD_SIZE.y / 64)):
			var point := Vector2(column * 64 + 32, row * 64 + 32)
			if Rules.road_distance(point) < 82 or point.distance_to(Rules.CORE) < 170:
				sand[Vector2i(column, row)] = true
			for route in Rules.EXPLORATION_ROUTES:
				var previous: Vector2 = Rules.CORE + Vector2(180, 100)
				for node in route:
					var closest := Geometry2D.get_closest_point_to_segment(point, previous, node)
					if point.distance_to(node) < 295 or point.distance_to(closest) < 70: sand[Vector2i(column, row)] = true
					previous = node
	var random := RandomNumberGenerator.new()
	random.seed = 1946
	for decoration_index in range(1900):
		var point := Vector2(random.randf_range(60, Rules.WORLD_SIZE.x - 60), random.randf_range(80, Rules.WORLD_SIZE.y - 60))
		if sand.has(Vector2i(point / 64)) or point.distance_to(Rules.CORE) < 175:
			continue
		decoration.append({"point": point, "texture": Art.texture("Deco/%02d.png" % random.randi_range(1, 18)), "scale": random.randf_range(0.75, 1.1)})
	queue_redraw()

func populate(actors: Node2D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 7852
	for tree_index in range(1350):
		var point := Vector2(random.randf_range(40, Rules.WORLD_SIZE.x - 40), random.randf_range(100, Rules.WORLD_SIZE.y - 40))
		if point.distance_to(Rules.CORE) < 640 or Rules.road_distance(point) < 150:
			continue
		var blocked := false
		for route in Rules.EXPLORATION_ROUTES:
			var previous: Vector2 = Rules.CORE + Vector2(180, 100)
			for node in route:
				var closest := Geometry2D.get_closest_point_to_segment(point, previous, node)
				if point.distance_to(node) < 350 or point.distance_to(closest) < 135: blocked = true
				previous = node
		if blocked:
			continue
		var tree := Node2D.new()
		tree.position = point
		var visual := Art.sprite("Resources/Trees/Tree.png", Vector2i(4, 3), random.randi_range(0, 3))
		visual.position.y = -72
		visual.scale = Vector2.ONE * random.randf_range(0.85, 1.1)
		tree.add_child(visual)
		actors.add_child(tree)
	var castle := Node2D.new()
	castle.position = Rules.CORE + Vector2(0, -54)
	var castle_visual := Art.sprite("Factions/Knights/Buildings/Castle/Castle_Blue.png")
	castle_visual.scale = Vector2.ONE * 0.7
	castle_visual.position.y = -65
	castle.add_child(castle_visual)
	actors.add_child(castle)
	var obstacle := StaticBody2D.new()
	obstacle.position = Rules.CORE + Vector2(0, -80)
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(184, 112)
	collision.shape = rectangle
	obstacle.add_child(collision)
	actors.add_child(obstacle)
	cover_rects.append(Rect2(Rules.CORE + Vector2(-92, -136), Vector2(184, 112)))
	for region in range(3):
		for node in Rules.EXPLORATION_ROUTES[region]:
			for offset in Rules.COVER_OFFSETS:
				var cover := ArenaCover.new()
				cover.position = node + offset
				cover.stone = region > 0
				actors.add_child(cover)
				cover_rects.append(Rect2(cover.position - cover.dimensions * 0.5, cover.dimensions))

func _draw() -> void:
	if ground == null:
		return
	for column in range(int(Rules.WORLD_SIZE.x / 64)):
		for row in range(int(Rules.WORLD_SIZE.y / 64)):
			var cell := Vector2i(column, row)
			var target := Rect2(column * 64, row * 64, 64, 64)
			var south := clampf((target.position.y - 1300) / 500, 0, 1)
			var east := clampf((target.position.x - 3500) / 700, 0, 1)
			var grass_tint := Color("dbefd4").lerp(Color("b3c2a2"), south).lerp(Color("a1c3b4"), east)
			draw_texture_rect_region(ground, target, Rect2(64, 64, 64, 64), grass_tint)
			if not sand.has(cell):
				continue
			var source_column := 1
			var source_row := 1
			if not sand.has(cell + Vector2i.LEFT): source_column = 0
			elif not sand.has(cell + Vector2i.RIGHT): source_column = 2
			if not sand.has(cell + Vector2i.UP): source_row = 0
			elif not sand.has(cell + Vector2i.DOWN): source_row = 2
			var trail_tint := Color("dbc69a").lerp(Color("c4b8a1"), south).lerp(Color("b1c3c9"), east)
			draw_texture_rect_region(ground, target, Rect2(320 + source_column * 64, source_row * 64, 64, 64), trail_tint)
	for item in decoration:
		var size := Vector2.ONE * 64 * float(item.scale)
		draw_texture_rect(item.texture, Rect2(item.point - size * 0.5, size), false, Color(0.85, 0.94, 0.82, 0.8))
	for route in Rules.PATHS:
		for point_index in range(route.size() - 1):
			var start: Vector2 = route[point_index]
			var direction: Vector2 = (route[point_index + 1] - start).normalized()
			var length: float = start.distance_to(route[point_index + 1])
			for marker_index in range(int(length / 200)):
				var point := start + direction * (80 + marker_index * 200)
				var side := direction.orthogonal()
				draw_polyline(PackedVector2Array([point - direction * 9 + side * 7, point, point - direction * 9 - side * 7]), Color(0.55, 0.43, 0.24, 0.4), 3, false)

