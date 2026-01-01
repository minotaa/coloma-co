extends Node2D

var MAX_RADIUS: float = 24.0 / 3  # Maximum explosion radius
var MIN_DAMAGE: float = 20.0  # Damage at edge of explosion
var MAX_DAMAGE: float = 80.0  # Damage at epicenter
var EXPANSION_TIME: float = 0.4  # How long the explosion takes to expand

@onready var area: Area2D = $Area2D
var damaged_bodies: Array = []  # Track who we've already damaged

func _ready() -> void:
	if area.get_child(0) is CollisionShape2D:
		var collision_shape = area.get_child(0) as CollisionShape2D
		if collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = 0.0
			
	var tween = create_tween()
	tween.tween_method(set_explosion_radius, 0.0, MAX_RADIUS, EXPANSION_TIME)
	
	await get_tree().create_timer(EXPANSION_TIME + 0.1).timeout
	queue_free()

func set_explosion_radius(radius: float) -> void:
	if area.get_child(0) is CollisionShape2D:
		var collision_shape = area.get_child(0) as CollisionShape2D
		if collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = radius
	check_and_damage_bodies()

func check_and_damage_bodies() -> void:
	for body in area.get_overlapping_bodies():
		if body.is_in_group("players") and body.alive and body not in damaged_bodies:
			var distance = global_position.distance_to(body.global_position)
			
			var damage_factor = 1.0 - (distance / MAX_RADIUS)
			damage_factor = clamp(damage_factor, 0.0, 1.0)
			var damage = lerp(MIN_DAMAGE, MAX_DAMAGE, damage_factor)
			
			body.take_damage(damage, name, global_position)
			damaged_bodies.append(body)
