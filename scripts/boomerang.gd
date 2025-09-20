extends Area2D

var direction: Vector2
@export var weapon_id: int = 0
const BASE_SPEED: float = 250.0
@export var SOURCE: String = "Player"

var returning: bool = false
var flight_time: float = 0.0
const MAX_DISTANCE: float = 100.0 # adjust as needed
var hit_enemies = []

func _ready() -> void:
	$Timer.start() 

func _physics_process(delta: float) -> void:
	var source_node = get_parent().get_node(SOURCE)
	if source_node == null:
		return
	$Sprite2D.rotation_degrees += 25
	flight_time += delta
	
	# Speed scales with time away (linearly)
	var current_speed = BASE_SPEED + flight_time * 50.0 # tweak multiplier
	
	if returning:
		source_node = get_parent().get_node(SOURCE)
		var to_source = (source_node.global_position - global_position).normalized()
		position += to_source * current_speed * delta
		if global_position.distance_to(source_node.global_position) < 8.0:
			source_node.get_boomerang_back()
			queue_free()
	else:
		position += direction * current_speed * delta
		
		# Force return if too far
		source_node = get_parent().get_node(SOURCE)
		if source_node == null:
			return
		if global_position.distance_to(source_node.global_position) > MAX_DISTANCE:
			returning = true
			hit_enemies.clear()

	for body in get_overlapping_bodies():
		if body.is_in_group("enemies") and body.alive and body not in hit_enemies:
			if get_parent().get_node(SOURCE).is_multiplayer_authority():
				get_parent().get_node(SOURCE)._process_hit(body, Items.get_by_id(weapon_id).damage)
			hit_enemies.append(body)

func _on_timer_timeout() -> void:
	returning = true
	hit_enemies.clear()
