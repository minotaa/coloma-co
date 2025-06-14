extends Area2D

const FLOAT_AMPLITUDE := 8.0  # How far up/down it floats (pixels)
const FLOAT_SPEED := 2.0      # How fast it floats

@onready var sprite: Sprite2D = $Sprite2D

var float_timer := 0.0

func _process(delta):
	float_timer += delta * FLOAT_SPEED
	var offset_y = FLOAT_AMPLITUDE * sin(float_timer)
	sprite.position.y = offset_y
