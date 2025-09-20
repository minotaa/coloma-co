extends Area2D

var direction: Vector2
@export var weapon_id: int = 4
var SPEED: float = 250.0
@export var SOURCE: String = "Player"

# acceleration variables
var accel: float = 0.0
const ACCEL_RATE: float = 800.0 # pixels/sec^2, tweak this

func _ready() -> void:
	$Sprite2D.texture = Items.get_by_id(weapon_id).data["texture"]
	SPEED = Items.get_by_id(weapon_id).data["speed"]
	$Sprite2D.rotation = direction.angle() + PI/2

func _physics_process(delta: float) -> void:
	if get_parent().get_node(SOURCE) == null:
		return
	accel += ACCEL_RATE * delta
	var current_speed = SPEED + accel

	global_position += direction * current_speed * delta

	for body in get_overlapping_bodies():
		if body.is_in_group("enemies") and body.alive:
			if get_parent().get_node(SOURCE).is_multiplayer_authority():
				get_parent().get_node(SOURCE)._process_hit(body, Items.get_by_id(weapon_id).damage)
			queue_free()
			print("Removed throwable.")
			pass

func _on_timer_timeout() -> void:
	queue_free()
	print("Removed throwable.")
