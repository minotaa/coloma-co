extends Entity

const SPEED := 13.0
var explosion_scene = preload("res://scenes/explosion.tscn")

func initialize_entity() -> void:
	entity_name = "Bombrat"
	health = 125.0
	max_health = 125.0
	defense = 0.0
	id = 1
	speed = SPEED

	sprite.play("bombrat-down")

func get_gold_reward() -> int:
	return 5

func get_kill_type() -> String:
	return "bombrat"

func on_player_contact(player: Node) -> void:
	# Bombrat does not hurt players
	pass

func _physics_process(delta: float) -> void:
	if not alive:
		return
		
	# Update progress bar (only on server or single player)
	if ((multiplayer.has_multiplayer_peer() and multiplayer.is_server()) or not multiplayer.has_multiplayer_peer()) and progress_bar:
		progress_bar.value = health
		progress_bar.max_value = max_health
		progress_bar.visible = health < max_health

	# Check if touching a gem → explode immediately
	for area in $Hurtbox.get_overlapping_areas():
		if area.is_in_group("gem"):
			alive = false  # prevent multiple explosions
			explode()
			return

	# Move toward the nearest gem
	var target = get_nearest_gem()
	if not target:
		velocity = Vector2.ZERO
		return

	# Navigation
	agent.target_position = target.global_position
	var next_pos = agent.get_next_path_position()

	if next_pos != Vector2.ZERO:
		var dir = (next_pos - global_position).normalized()
		velocity = dir * speed
		update_sprite_direction(dir)
	else:
		velocity = Vector2.ZERO

	# Move manually ignoring collisions with players
	global_position += velocity * delta

func explode() -> void:
	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	explosion.emitting = true
	get_parent().add_child(explosion, true)

	# Damage gems in range (same as original logic)
	for area in $Hurtbox.get_overlapping_areas():
		if area.is_in_group("gem"):
			area.take_damage(10.0) # 10%

	play_sfx("better5", global_position)

	die()

func get_nearest_gem() -> Node2D:
	var gems = get_tree().get_nodes_in_group("gem")
	var nearest: Node2D = null
	var best_dist := INF

	for gem in gems:
		if gem is Node2D:
			var d = global_position.distance_squared_to(gem.global_position)
			if d < best_dist:
				best_dist = d
				nearest = gem

	return nearest

func update_sprite_direction(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			sprite.play("bombrat-right")
		else:
			sprite.play("bombrat-left")
	else:
		if dir.y > 0:
			sprite.play("bombrat-down")
		else:
			sprite.play("bombrat-up")
