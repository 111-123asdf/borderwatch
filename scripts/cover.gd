class_name ArenaCover
extends StaticBody2D

var dimensions := Vector2(96, 64)
var stone := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = dimensions
	collision.shape = rectangle
	add_child(collision)
	var sprite := Sprite2D.new()
	sprite.texture = load("res://assets/ui/cover-0.3.png")
	sprite.hframes = 2
	sprite.frame = 1 if stone else 0
	sprite.scale = Vector2(108.0 / (sprite.texture.get_width() / 2.0), 144.0 / sprite.texture.get_height())
	sprite.position.y = -15
	add_child(sprite)

func _draw() -> void:
	draw_rect(Rect2(-dimensions * 0.5 + Vector2(4, 8), dimensions), Color(0.1, 0.19, 0.16, 0.22))
