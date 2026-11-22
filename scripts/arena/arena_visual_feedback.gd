class_name ArenaVisualFeedback
extends RefCounted
# Presentation only: never changes the owner's position, combat timers or collision.
const FLASH = preload("res://scripts/arena/impact_flash.gdshader")
var base_scale := Vector2.ONE
var base_speed := 1.0
var age := 1.0
var stop_left := 0.0
var strength := 0.0
var incoming := Vector2.ZERO
var enabled := true
var reduced := false
var disable_squash := false
var material: ShaderMaterial
func set_environment(sprite: AnimatedSprite2D,tint: Color,saturation: float) -> void:
	if material==null:material=ShaderMaterial.new();material.shader=FLASH;sprite.material=material
	material.set_shader_parameter("environment_tint",tint);material.set_shader_parameter("environment_saturation",saturation)

func impact(sprite: AnimatedSprite2D, heavy := false, direction := Vector2.ZERO) -> void:
	if not enabled:return
	incoming = direction.normalized()
	age=0.0;strength=1.0 if heavy else 0.72
	if not reduced:
		stop_left=maxf(stop_left,0.055 if heavy else 0.032)
	if material==null:
		material=ShaderMaterial.new();material.shader=FLASH;sprite.material=material

func freeze_after_release() -> void:
	if enabled and not reduced:stop_left=maxf(stop_left,0.055)

func clear(sprite: AnimatedSprite2D) -> void:
	age=1.0;stop_left=0.0;strength=0.0
	sprite.scale=base_scale;sprite.speed_scale=base_speed
	if material!=null:material.set_shader_parameter("flash_strength",0.0)

func tick(sprite: AnimatedSprite2D, delta: float) -> void:
	age+=delta;stop_left=maxf(0.0,stop_left-delta)
	if not enabled:clear(sprite);return
	var pulse:=pow(maxf(0.0,1.0-age/0.12),2.0)*strength
	var amount:=(0.025 if reduced else 0.08) if not disable_squash else 0.0
	sprite.scale=base_scale*Vector2(1.0+amount*pulse,1.0-amount*pulse)
	sprite.speed_scale=0.0 if stop_left>0 else base_speed
	if material!=null:material.set_shader_parameter("flash_strength",maxf(0.0,1.0-age/0.06)*(0.18 if reduced else 0.65))
