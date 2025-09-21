extends Node2D

const FLOAT_AMPLITUDE := 2.0  # How far up/down it floats (pixels)
const FLOAT_SPEED := 0.8      # How fast it floats
var float_timer := 0.0

func _process(delta):
	float_timer += delta * FLOAT_SPEED
	var offset_y = FLOAT_AMPLITUDE * sin(float_timer)
	$Sprite2D.position.y = offset_y
	$Area2D/CollisionShape2D.position.y = offset_y
