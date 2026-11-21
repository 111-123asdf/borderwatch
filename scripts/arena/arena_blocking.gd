class_name ArenaBlocking
extends RefCounted
var game: Node2D
var assignments: Dictionary={}
func _init(owner_game: Node2D) -> void: game=owner_game
func load_for(blocker: Node2D) -> int:
	var total:=0
	for enemy in assignments:
		if is_instance_valid(enemy) and not enemy.dead and assignments[enemy]==blocker: total+=weight_for(enemy,blocker)
	return total
func weight_for(enemy: ArenaEnemy,blocker: Node2D) -> int:
	if blocker is ArenaSoldier and not enemy.is_boss():
		if game.tower_lab or (game.defense_rules and int(enemy.data.capacity)==1): return 1
	return enemy.block_weight()
func holds_position(enemy: ArenaEnemy,blocker: Node2D) -> bool:
	if not is_instance_valid(enemy) or enemy.dead or not is_instance_valid(blocker) or not blocker.can_block(): return false
	var radius:=78.0
	if blocker is ArenaSoldier:
		if not blocker.can_engage(enemy): return false
		radius=maxf(radius,blocker.taunt_radius())
	return enemy.position.distance_squared_to(blocker.position)<=radius*radius
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
		if not holds_position(enemy,blocker):
			to_erase.append(enemy)
		else:
			loads[blocker] = int(loads.get(blocker, 0)) + weight_for(enemy,blocker)
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
		# Taunting soldiers pull nearby attackers before the normal hero-first order.
		var assigned := false
		for blocker in taunting:
			if not blocker.can_engage(enemy) or enemy.position.distance_squared_to(blocker.position)>pow(blocker.taunt_radius(),2.0):
				continue
			var w:=weight_for(enemy,blocker)
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
			if enemy.position.distance_squared_to(blocker.position) > 2401.0 or (blocker is ArenaSoldier and not blocker.can_engage(enemy)):
				continue
			var w:=weight_for(enemy,blocker)
			var cur: int = int(loads.get(blocker, 0))
			if cur + w > blocker.block_capacity():
				continue
			assignments[enemy] = blocker
			enemy.blocker = blocker
			loads[blocker] = cur + w
			break
