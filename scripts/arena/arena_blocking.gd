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
	for enemy in assignments.keys():
		var blocker=assignments[enemy]
		if not is_instance_valid(enemy) or enemy.dead or not is_instance_valid(blocker) or not blocker.can_block() or enemy.position.distance_to(blocker.position)>78:
			release_enemy(enemy)
	var blockers: Array=[game.hero]
	for soldier in game.soldiers:
		if is_instance_valid(soldier): blockers.append(soldier)
	for enemy in game.enemies:
		if not is_instance_valid(enemy) or enemy.dead or enemy.is_guard or enemy.kind=="moth" or assignments.has(enemy): continue
		# Taunting soldiers pull nearby attackers before the normal hero-first order.
		for blocker in blockers:
			if not is_instance_valid(blocker) or not blocker.has_method("taunt") or not blocker.taunt(): continue
			if not blocker.can_block() or enemy.position.distance_to(blocker.position)>60: continue
			if load_for(blocker)+enemy.block_weight()>blocker.block_capacity(): continue
			assignments[enemy]=blocker;enemy.blocker=blocker;break
		if assignments.has(enemy): continue
		for blocker in blockers:
			if not is_instance_valid(blocker) or not blocker.can_block(): continue
			if enemy.position.distance_to(blocker.position)>49: continue
			if load_for(blocker)+enemy.block_weight()>blocker.block_capacity(): continue
			assignments[enemy]=blocker;enemy.blocker=blocker;break
