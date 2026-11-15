class_name ArenaCamp
extends RefCounted
# One authored elite outpost: dormant until wave two, aura, deadline, raid, reward.
var game: Node2D
var id:=0
var point:=Vector2.ZERO
var aura_radius:=220.0
var enemy_speed:=0.12
var enemy_damage:=0.10
var state: String="dormant"
var remaining:=0
var overdue:=false
var raid_sent:=false
var activated_at:=-1.0
var engaged_at:=-1.0
var cleared_at:=-1.0
var hero_damage:=0.0
const ACTIVATED_WAVE:=2
const DEADLINE_WAVE:=4
const RAID_WAVE:=5
func cleared() -> bool: return state=="cleared"
func engage() -> void:
	if engaged_at<0.0:engaged_at=game.elapsed
func clear_time() -> float:
	var started:=engaged_at if engaged_at>=0.0 else activated_at
	return cleared_at-started if started>=0.0 and cleared_at>=0.0 else -1.0
func engage_time() -> float: return engaged_at-activated_at if engaged_at>=0.0 and activated_at>=0.0 else -1.0
func covers(at: Vector2) -> bool:
	if cleared() or state=="dormant":return false
	return overdue or at.distance_to(point)<=aura_radius
func activate(wave: int) -> void:
	if state!="dormant" or wave<ACTIVATED_WAVE:return
	state="active";activated_at=game.elapsed
	_spawn("captain",0,false)
	_spawn("spearman",1,true)
	_spawn("fox",2,true)
func _spawn(kind: String,index: int,elite: bool) -> ArenaEnemy:
	var enemy:=ArenaEnemy.new();enemy.game=game;enemy.kind=kind;enemy.is_guard=true;enemy.elite=elite;enemy.camp_id=id
	enemy.home=point+Vector2.RIGHT.rotated(index*TAU/3.0)*44;enemy.position=enemy.home
	game.actors.add_child(enemy);game.enemies.append(enemy);remaining+=1
	return enemy
func on_guard_down() -> void: remaining=maxi(0,remaining-1)
func needs_raid(wave: int) -> bool: return wave>=RAID_WAVE and not raid_sent and not cleared()
