class_name BattlefieldEffects
extends Node2D

var game: Node2D
var particles: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var slashes: Array[Dictionary] = []
var animations: Array[Dictionary] = []
var beams: Array[Dictionary] = []
var explosion_texture: Texture2D

func _ready() -> void:
	explosion_texture = Art.texture("Effects/Explosion/Explosions.png")

func _process(delta: float) -> void:
	for particle in particles:
		particle.life -= delta
		particle.point += particle.velocity * delta
		particle.velocity *= pow(0.08, delta)
	particles = particles.filter(func(item): return item.life > 0)
	for ring in rings:
		ring.life -= delta
	rings = rings.filter(func(item): return item.life > 0)
	for bolt in bolts:
		bolt.life -= delta
	bolts = bolts.filter(func(item): return item.life > 0)
	for slash in slashes: slash.life -= delta
	slashes = slashes.filter(func(item): return item.life > 0)
	for animation in animations: animation.time += delta
	animations = animations.filter(func(item): return item.time < 0.45)
	for beam in beams: beam.life -= delta
	beams = beams.filter(func(item): return item.life > 0)
	queue_redraw()

func _draw() -> void:
	_draw_landmarks()
	for beam in beams:
		draw_line(beam.start, beam.end, Color(beam.color, beam.life / 0.12 * 0.25), beam.width * 2.5, true)
		draw_line(beam.start, beam.end, beam.color, beam.width, true)
		draw_line(beam.start, beam.end, Color("edfef7"), 2, true)
	for pickup in game.pickups:
		var point: Vector2 = pickup.point
		draw_circle(point, 9, Color(0.4, 0.9, 0.85, 0.12))
		draw_colored_polygon(PackedVector2Array([point + Vector2(0, -6), point + Vector2(4, 0), point + Vector2(0, 6), point + Vector2(-4, 0)]), Color("a5e5d4"))
	for animation in animations:
		var diameter: float = animation.radius * 2.3
		var frame := mini(8, int(animation.time * 20))
		draw_texture_rect_region(explosion_texture, Rect2(animation.point - Vector2.ONE * diameter * 0.5, Vector2.ONE * diameter), Rect2(frame * 192, 0, 192, 192), Color(1, 1, 1, 0.75))
	for slash in slashes:
		var progress: float = 1 - slash.life / slash.total
		var color: Color = slash.color
		color.a = 1 - progress
		draw_arc(slash.point, slash.radius, slash.angle - 1.15 + progress * 0.8, slash.angle + 1.1, 24, Color(color, color.a * 0.25), 16, true)
		draw_arc(slash.point, slash.radius, slash.angle - 1.1 + progress, slash.angle + 1.0, 24, color, 4, true)
	for hazard in game.hazards:
		var progress: float = 1 - hazard.remaining / hazard.total
		var point: Vector2 = hazard.point
		var radius: float = hazard.radius
		draw_circle(point, radius, Color(0.7, 0.17, 0.15, 0.15))
		draw_arc(point, radius, 0, TAU, 64, Color("f59973"), 3, true)
		draw_arc(point, radius * progress, 0, TAU, 64, Color("ffce92"), 3, true)
		draw_line(point - Vector2(12, 12), point + Vector2(12, 12), Color("ffe2ba"), 3, true)
		draw_line(point - Vector2(-12, 12), point + Vector2(-12, 12), Color("ffe2ba"), 3, true)
	for ring in rings:
		var progress: float = 1 - ring.life / ring.total
		var color: Color = ring.color
		color.a *= 1 - progress
		draw_arc(ring.point, maxf(1, ring.radius * progress), 0, TAU, 48, color, 5 * (1 - progress) + 1, true)
	for bolt in bolts:
		draw_polyline(bolt.points, Color(0.65, 0.95, 1, bolt.life / 0.2), 4, true)
	for particle in particles:
		var color: Color = particle.color
		color.a *= particle.life / particle.total
		draw_circle(particle.point, particle.size * minf(1, particle.life * 8), color)
	if is_instance_valid(game.selected):
		var tower: Tower = game.selected
		draw_arc(tower.position, tower.attack_range(), 0, TAU, 80, Color(0.8, 0.96, 0.83, 0.4), 2, true)
	for index in range(Rules.BUILD_SITES.size()):
		var point: Vector2 = Rules.BUILD_SITES[index]
		if game.nearest_tower(point, 12) != null: continue
		var color := Color("e7cf9c") if game.wave == 0 and index < 2 else Color("9baf89")
		draw_circle(point, 29, Color(0.19, 0.28, 0.21, 0.35))
		for segment in range(8): draw_arc(point, 28, TAU * segment / 8.0, TAU * (segment + 0.6) / 8.0, 5, Color(color, 0.8), 2, true)
		draw_line(point - Vector2(7, 0), point + Vector2(7, 0), color, 2, true)
		draw_line(point - Vector2(0, 7), point + Vector2(0, 7), color, 2, true)

func _draw_landmarks() -> void:
	for region in range(3):
		for node_index in range(Rules.CAMP_NODES):
			if game.completed_waves < Rules.CAMP_UNLOCK[region]: continue
			var point: Vector2 = Rules.CAMPS[region] if Rules.CAMP_NODES <= 1 else Rules.EXPLORATION_ROUTES[region][node_index]
			var cleared: bool = game.camps[region].progress > node_index
			var current: bool = game.camps[region].progress == node_index
			var color := Color("91ceaf") if cleared else (Color("f0d48c") if current else Color("9faaa1"))
			draw_arc(point, 29, 0, TAU, 32, Color(color, 0.65), 2, true)
			draw_line(point + Vector2(0, -25), point + Vector2(0, -67), color.darkened(0.25), 4)
			draw_colored_polygon(PackedVector2Array([point + Vector2(1, -66), point + Vector2(27, -59), point + Vector2(1, -48)]), color)
			if current: draw_arc(point, 38 + sin(game.elapsed * 3) * 2, 0, TAU, 36, Color(color, 0.3), 2, true)
	var crystal := Rules.CORE + Vector2(0, -150 + sin(game.elapsed * 2) * 4)
	draw_circle(crystal, 36, Color(0.5, 0.95, 0.9, 0.075))
	draw_circle(crystal, 25, Color(0.5, 0.95, 0.9, 0.09))
	draw_colored_polygon(PackedVector2Array([crystal + Vector2(0, -23), crystal + Vector2(12, 0), crystal + Vector2(0, 21), crystal + Vector2(-12, 0)]), Color("2d5869"))
	draw_colored_polygon(PackedVector2Array([crystal + Vector2(0, -18), crystal + Vector2(8, 0), crystal + Vector2(0, 16), crystal + Vector2(-8, 0)]), Color("96e6db"))
	draw_colored_polygon(PackedVector2Array([crystal + Vector2(0, -18), crystal + Vector2(0, 16), crystal + Vector2(-8, 0)]), Color("68bdc7"))
	for camp_index in range(3):
		if game.completed_waves < Rules.CAMP_UNLOCK[camp_index]: continue
		var point: Vector2 = Rules.CAMPS[camp_index] + Vector2(0, 25)
		if game.camps[camp_index].chest_claimed:
			draw_arc(point, 25, 0, TAU, 24, Color(0.7, 0.8, 0.65, 0.4), 2, true)
			continue
		var color := Color("efcd7c") if game.camps[camp_index].cleared else Color("b6ad82")
		draw_arc(point, 32 + sin(game.elapsed * 3) * 2, 0, TAU, 32, Color(color, 0.65), 2, true)
		draw_rect(Rect2(point + Vector2(-21, -22), Vector2(42, 30)), Color("323b3b"))
		draw_rect(Rect2(point + Vector2(-18, -19), Vector2(36, 24)), Color("a17648"))
		draw_rect(Rect2(point + Vector2(-18, -19), Vector2(36, 6)), color)
		draw_rect(Rect2(point + Vector2(-18, 1), Vector2(36, 4)), color)
		draw_rect(Rect2(point + Vector2(-4, -14), Vector2(8, 13)), color)
