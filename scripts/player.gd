extends CharacterBody2D

const SPEED = 75.0

var directions = {
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT,
	"up": Vector2.UP,
	"down": Vector2.DOWN
}

var last_direction = "down"

func play_animation(name: String, backwards: bool = false, speed: float = 1) -> void:
	if backwards == false:
		$AnimatedSprite2D.play(name, speed)
	else:
		$AnimatedSprite2D.play(name, speed * -1, true)

func play_idle_animation() -> void:
	play_animation("idle_" + last_direction)
	
func _process_input(delta) -> void:
	velocity = Input.get_vector("left", "right", "up", "down", 0.1)

	var velocity_length = velocity.length_squared()
	if velocity_length > 0:
		velocity_length = min(1, 0.5 + velocity_length)
		if abs(velocity.x) > abs(velocity.y):
			if velocity.x > 0:
				last_direction = "right"
				play_animation("walk_right", false, velocity_length)
			else:
				last_direction = "left"
				play_animation("walk_left", false, velocity_length)
		else:
			if velocity.y > 0:
				last_direction = "down"
				play_animation("walk_down", false, velocity_length)
			else:
				last_direction = "up"
				play_animation("walk_up", false, velocity_length)
	
	velocity *= SPEED
	
	if velocity.x == 0 and velocity.y == 0:
		if $AnimatedSprite2D.animation == "walk_left" or $AnimatedSprite2D.animation == "walk_up" or $AnimatedSprite2D.animation == "walk_down" or $AnimatedSprite2D.animation == "walk_right":
			play_idle_animation()
	
	move_and_slide()

func _physics_process(delta: float) -> void:
	_process_input(delta)
