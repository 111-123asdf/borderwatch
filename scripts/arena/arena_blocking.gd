class_name ArenaBlocking
extends RefCounted
var game: Node2D
var assignments: Dictionary={}
func _init(owner_game: Node2D) -> void: game=owner_game
func load_for(blocker: Node2D) -> int:
	var total:=0
	for enemy in assignments:
		if is_instance_valid(enemy) and not enemy.dead and assignments[enemy]==blocker: total+=enemy.block_weight()
	return total
func release(blocker: Node2D) -> void:
	for enemy in assignments.keys():
		if not is_instance_valid(enemy) or assignments[enemy]==blocker:
			if is_instance_valid(enemy): enemy.blocker=null
			assignments.erase(enemy)
func release_enemy(enemy: Node2D) -> void:
	assignments.erase(enemy)
	if is_instance_valid(enemy): enemy.blocker=null
func update() -> void:
	var to_erase: Array = []
	var loads: Dictionary = {}
	for enemy in assignments:
		var blocker = assignments[enemy]
		if not is_instance_valid(enemy) or enemy.dead or not is_instance_valid(blocker) or not blocker.can_block() or enemy.position.distance_squared_to(blocker.position) > 6084.0:
			to_erase.append(enemy)
		else:
			loads[blocker] = int(loads.get(blocker, 0)) + enemy.block_weight()
	for enemy in to_erase:
		release_enemy(enemy)
	if game.enemies.is_empty():
		return
	var blockers: Array = []
	var taunting: Array = []
	if is_instance_valid(game.hero) and game.hero.can_block():
		blockers.append(game.hero)
	for soldier in game.soldiers:
		if is_instance_valid(soldier) and soldier.can_block():
			blockers.append(soldier)
			if soldier.taunt():
				taunting.append(soldier)
	if blockers.is_empty():
		return
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_guard or enemy.kind == "moth" or assignments.has(enemy):
			continue
		var w: int = enemy.block_weight()
		# Taunting soldiers pull nearby attackers before the normal hero-first order.
		var assigned := false
		for blocker in taunting:
			if enemy.position.distance_squared_to(blocker.position) > 3600.0:
				continue
			var cur: int = int(loads.get(blocker, 0))
			if cur + w > blocker.block_capacity():
				continue
			assignments[enemy] = blocker
			enemy.blocker = blocker
			loads[blocker] = cur + w
			assigned = true
			break
		if assigned:
			continue
		for blocker in blockers:
			if enemy.position.distance_squared_to(blocker.position) > 2401.0:
				continue
			var cur: int = int(loads.get(blocker, 0))
			if cur + w > blocker.block_capacity():
				continue
			assignments[enemy] = blocker
			enemy.blocker = blocker
			loads[blocker] = cur + w
			break
