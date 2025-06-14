extends Label

var float_speed = 30.0
var fade_speed = 2.0
var lifetime = 1.0
var elapsed = 0.0

func _process(delta):
	# Move up
	position.y -= float_speed * delta

	# Fade out
	elapsed += delta
	modulate.a = lerp(1.0, 0.0, elapsed / lifetime)

	if elapsed >= lifetime:
		queue_free()
