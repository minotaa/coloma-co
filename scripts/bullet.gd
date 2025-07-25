extends Area2D

var direction: Vector2
const SPEED: float = 80.0

func _physics_process(delta: float) -> void:
	$Sprite2D.rotation_degrees += 3
	position += direction * SPEED * delta
	for body in get_overlapping_bodies():
		if body.is_in_group("players") and body.alive:
			body.take_damage(20, global_position)
			queue_free()
			print("Removed bullet")
			pass

func _on_timer_timeout() -> void:
	queue_free()
	print("Removed bullet.")
