extends Entity

const SPEED := 4.8
var explosion_scene = preload("res://scenes/explosion.tscn")

func initialize_entity() -> void:
	agent = $NavigationAgent2D
	sprite = $AnimatedSprite2D
	entity_name = "Big Bombrat"
	bestiary_description = "A bigger, stronger version of the Bombrat. Will deal double damage to the gem if it makes it to the gem."
	developer_commentary = "They're more of a distraction if anything, is that a sign of good game design? You're not supposed to fight these things first, you'll find it more easier to kill the regular Bombrats first. Not much of commentary, more of a tip, but whatever."
	dev_commentary_requirement = 1250
	health = 500.0
	max_health = 500.0
	defense = 0.0
	id = 4
	speed = SPEED

	sprite.play("bombrat-down")

func get_gold_reward() -> int:
	return 20

func get_kill_type() -> String:
	return "big_bombrat"

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
	get_parent().add_child(explosion)

	# Damage gems in range (same logic as original)
	for area in $Hurtbox.get_overlapping_areas():
		if area.is_in_group("gem"):
			area.take_damage(20.0)

	play_sfx("better6", global_position)

	# Kill entity (dies normally, gold + kill credit handled by Entity)
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
