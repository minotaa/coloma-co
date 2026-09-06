extends Entity

const SPAWN_DELAY := 1.0
const SHOOT_INTERVAL := 2.0
const RETREAT_DISTANCE := 70.0
const APPROACH_DISTANCE := 90.0
const APPROACH_SPEED := 10.0
const RETREAT_SPEED := 20.0

const FLOAT_AMPLITUDE := 1.0
const FLOAT_SPEED := 2.0

var shoot_timer := SPAWN_DELAY
var move_mode: String = "idle"
var float_timer := 0.0

func initialize_entity() -> void:
	agent = $NavigationAgent2D
	sprite = $AnimatedSprite2D
	collision = $CollisionShape2D
	entity_name = "Bauble"
	bestiary_description = "Shy enemies that shoot stars towards players. They also retreat when far away."
	developer_commentary = "Wings are hard to make. Also, honestly the baubles are a pushover if you get too close."
	dev_commentary_requirement = 250
	health = 100.0
	max_health = 100.0
	defense = 0.0
	id = 3
	speed = APPROACH_SPEED

	sprite.play("bauble-down")

func get_gold_reward() -> int:
	return 10

func get_kill_type() -> String:
	return "bauble"

func on_player_contact(player: Node) -> void:
	# Baubles do NOT hurt players on touch
	pass

func custom_physics_process(delta: float, movement_multiplier: float) -> void:
	# Floating bob effect
	float_timer += delta * FLOAT_SPEED
	var offset_y = FLOAT_AMPLITUDE * sin(float_timer)
	if sprite:
		sprite.position.y = -8 + offset_y
	if collision:
		collision.position.y = -8 + offset_y

	var player = get_nearest_player()
	if not player:
		return

	var dist_sq = global_position.distance_squared_to(player.global_position)
	var current_speed = APPROACH_SPEED * movement_multiplier # base speed

	# Decide movement mode
	if dist_sq < RETREAT_DISTANCE * RETREAT_DISTANCE:
		move_mode = "retreat"
		current_speed = RETREAT_SPEED * movement_multiplier 
		if agent.is_navigation_finished():
			agent.target_position = await get_retreat_position_away_from(player.global_position)
	elif dist_sq > APPROACH_DISTANCE * APPROACH_DISTANCE:
		move_mode = "approach"
		current_speed = APPROACH_SPEED * movement_multiplier 
		if agent.is_navigation_finished():
			agent.target_position = player.global_position
	else:
		move_mode = "idle"
		agent.target_position = global_position
		current_speed = 0

	# Move manually along path
	var next_pos = agent.get_next_path_position()
	if next_pos != Vector2.ZERO and current_speed > 0:
		var dir = (next_pos - global_position).normalized()
		velocity = dir * current_speed
	else:
		velocity = Vector2.ZERO

	# Always face the player
	update_sprite_direction((player.global_position - global_position).normalized())

	# Shooting only when idle
	if move_mode == "idle":
		shoot_timer -= delta
		if shoot_timer <= 0.0:
			play_sfx("explosionbutlikemorepixelly", global_position)
			shoot_at_player(player.global_position)
			shoot_timer = SHOOT_INTERVAL

	# Apply velocity manually
	global_position += velocity * delta

func shoot_at_player(target_pos: Vector2):
	var bullet = preload("res://scenes/bullet.tscn").instantiate()
	bullet.global_position = global_position
	bullet.direction = (target_pos - global_position).normalized()
	get_tree().current_scene.add_child(bullet)

func get_retreat_position_away_from(player_pos: Vector2) -> Vector2:
	var best_pos = global_position
	var best_dist = 0.0
	var original_target = agent.target_position

	for angle_deg in range(0, 360, 20):
		for radius in [64, 96, 128, 160, 192]:
			var offset = Vector2.RIGHT.rotated(deg_to_rad(angle_deg)) * radius
			var candidate = global_position + offset

			agent.target_position = candidate

			if not agent.is_target_reachable():
				continue

			var dist = candidate.distance_squared_to(player_pos)
			if dist > best_dist:
				best_dist = dist
				best_pos = candidate

	agent.target_position = original_target
	return best_pos

func update_sprite_direction(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			sprite.play("bauble-right")
		else:
			sprite.play("bauble-left")
	else:
		if dir.y > 0:
			sprite.play("bauble-down")
		else:
			sprite.play("bauble-up")
