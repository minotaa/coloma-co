extends Area2D

var direction: Vector2
const SPEED: float = 80.0

func _physics_process(delta: float) -> void:
	$Sprite2D.rotation_degrees += 3
	position += direction * SPEED * delta
	
	# Check for player collision
	for body in get_overlapping_bodies():
		if body.is_in_group("players") and body.alive:
			if multiplayer.has_multiplayer_peer():
				explode.rpc()
			else:
				explode()
			return
		
		explode()
		return

@rpc("any_peer", "call_local", "reliable")
func explode() -> void:
	var explosion_scene = preload("res://scenes/lethal_explosion.tscn")
	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	explosion.emitting = true
	get_parent().add_child(explosion)
	queue_free()
	print("Bullet exploded!")

func _on_timer_timeout() -> void:
	queue_free()
	print("Removed bullet.")
