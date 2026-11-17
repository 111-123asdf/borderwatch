class_name ArenaAttackTiming
extends RefCounted

## Zero-sum PREP -> RELEASE -> RECOVER state helper.
## Deducts anticipation duration from cooldown so steady-state DPS stays unchanged.

enum Phase { IDLE, PREP, RELEASE, RECOVER }

var phase: int = Phase.IDLE
var prep_duration: float = 0.0
var release_duration: float = 0.0
var recover_duration: float = 0.0
var timer: float = 0.0
var total_cycle: float = 0.0
var post_cooldown: float = 0.0
var target: Node2D = null
var target_point: Vector2 = Vector2.ZERO

func reset() -> void:
	phase = Phase.IDLE
	timer = 0.0
	target = null

func is_preparing() -> bool:
	return phase == Phase.PREP

func begin(cycle_time: float, prep_s: float, release_s: float, recover_s: float, in_target: Node2D, in_point: Vector2) -> void:
	var clamped_prep: float = clampf(prep_s, 0.0, maxf(0.02, cycle_time * 0.45))
	total_cycle = maxf(0.05, cycle_time)
	prep_duration = clamped_prep
	release_duration = maxf(0.02, release_s)
	recover_duration = maxf(0.04, recover_s)
	post_cooldown = maxf(0.02, total_cycle - clamped_prep)
	target = in_target
	target_point = in_point
	phase = Phase.PREP
	timer = prep_duration

func cancel() -> void:
	phase = Phase.IDLE
	timer = 0.0
	target = null

## Advances timing by delta. Returns true on the single frame transitioning PREP -> RELEASE.
func step(delta: float) -> bool:
	if phase == Phase.IDLE:
		return false
	timer -= delta
	if phase == Phase.PREP and timer <= 0.0:
		phase = Phase.RELEASE
		timer = release_duration
		return true
	if phase == Phase.RELEASE and timer <= 0.0:
		phase = Phase.RECOVER
		timer = recover_duration
		return false
	if phase == Phase.RECOVER and timer <= 0.0:
		phase = Phase.IDLE
		timer = 0.0
	return false

func prep_progress() -> float:
	if phase != Phase.PREP or prep_duration <= 0.001:
		return 0.0
	return clampf(1.0 - timer / prep_duration, 0.0, 1.0)

func release_progress() -> float:
	if phase != Phase.RELEASE or release_duration <= 0.001:
		return 0.0
	return clampf(1.0 - timer / release_duration, 0.0, 1.0)

func recover_progress() -> float:
	if phase != Phase.RECOVER or recover_duration <= 0.001:
		return 0.0
	return clampf(1.0 - timer / recover_duration, 0.0, 1.0)
