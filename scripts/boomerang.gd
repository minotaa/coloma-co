extends Area2D

var direction: Vector2
@export var weapon_id: int = 0
var BASE_SPEED: float = 250.0
@export var SOURCE: String = "Player"

var returning: bool = false
var flight_time: float = 0.0
const MAX_DISTANCE: float = 100.0 # adjust as needed
var hit_enemies = []

# New variables for weapon_id 45 chain behavior
var seeking_second_target: bool = false
var second_target: Node = null
var arc_progress: float = 0.0
var arc_start_pos: Vector2
var arc_mid_offset: Vector2

func _ready() -> void:
	$Timer.start() 

func _physics_process(delta: float) -> void:
	if weapon_id != 0:
		$Sprite2D.texture = Catalog.get_by_id(weapon_id).texture
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
	elif seeking_second_target and weapon_id == 45:
		# Seek the second target with circular arc motion
		if second_target != null and is_instance_valid(second_target) and second_target.alive:
			# Progress along the arc (0 to 1)
			var arc_speed = 2.5 # Adjust this to control arc travel speed
			arc_progress = min(arc_progress + delta * arc_speed, 1.0)
			
			# Quadratic bezier curve for smooth arc
			var start = arc_start_pos
			var end = second_target.global_position
			var control = start + arc_mid_offset
			
			# Bezier interpolation
			var new_pos = start.lerp(control, arc_progress).lerp(control.lerp(end, arc_progress), arc_progress)
			position = new_pos
			
			# Update direction for visual consistency
			if arc_progress < 1.0:
				var next_progress = min(arc_progress + 0.01, 1.0)
				var next_pos = start.lerp(control, next_progress).lerp(control.lerp(end, next_progress), next_progress)
				direction = (next_pos - position).normalized()
		else:
			# Target became invalid, start returning
			returning = true
			hit_enemies.clear()
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
			if not multiplayer.has_multiplayer_peer() or get_parent().get_node(SOURCE).is_multiplayer_authority():
				get_parent().get_node(SOURCE)._process_hit(body, Catalog.get_by_id(weapon_id).damage + get_parent().get_node(SOURCE).get_bonus_damage())
			hit_enemies.append(body)
			
			# Special behavior for weapon_id 45
			if weapon_id == 45:
				if hit_enemies.size() == 1:
					# Just hit first enemy, find nearest second target
					find_nearest_enemy_target()
				elif seeking_second_target and body == second_target:
					# Hit the second target, start returning
					returning = true
					seeking_second_target = false
					second_target = null
					hit_enemies.clear()
					
		if body.is_in_group("players") and body.alive and body != self:
			if multiplayer.has_multiplayer_peer():
				body.knockback.rpc_id(body.name.to_int(), SOURCE)
			else:
				body.knockback(SOURCE)

func find_nearest_enemy_target() -> void:
	var nearest_distance = INF
	var nearest_enemy = null
	
	# Get all enemies in the scene
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy.alive and enemy not in hit_enemies:
			var distance = global_position.distance_to(enemy.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_enemy = enemy
	
	if nearest_enemy != null:
		second_target = nearest_enemy
		seeking_second_target = true
		arc_progress = 0.0
		arc_start_pos = global_position
		
		# Create an arc offset perpendicular to the line between positions
		var to_target = (nearest_enemy.global_position - global_position)
		var perpendicular = Vector2(-to_target.y, to_target.x).normalized()
		var arc_height = to_target.length() * 0.5 # Adjust multiplier for more/less pronounced arc
		arc_mid_offset = to_target * 0.5 + perpendicular * arc_height
	else:
		# No valid target found, start returning
		returning = true
		hit_enemies.clear()

func _on_timer_timeout() -> void:
	# Only force return if not seeking second target
	if weapon_id != 45 or not seeking_second_target:
		returning = true
		hit_enemies.clear()
