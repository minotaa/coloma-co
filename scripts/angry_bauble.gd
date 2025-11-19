extends Entity

const SHOOT_INTERVAL := 2.0
const RETREAT_DISTANCE := 120.0
const APPROACH_DISTANCE := 180
const APPROACH_SPEED := 12.0
const RETREAT_SPEED := 15.0
const FLOAT_AMPLITUDE := 1.0
const FLOAT_SPEED := 2.0

var shoot_timer := 0.0
var move_mode := "idle"
var float_timer := 0.0

func initialize_entity() -> void:
	agent = $NavigationAgent2D
	sprite = $AnimatedSprite2D
	collision = $CollisionShape2D
	entity_name = "Angry Bauble"
	health = 300.0
	max_health = 300.0
	defense = 0.0
	id = 8
	sprite.play("bauble-down")

func get_gold_reward() -> int: return 25
func get_kill_type() -> String: return "angry_bauble"

func on_player_contact(player: Node) -> void:
	# Does NOT hurt players
	pass

func custom_physics_process(delta: float, _movement_multiplier: float) -> void:
	if not alive:
		return

	float_timer += delta * FLOAT_SPEED
	var offset_y = FLOAT_AMPLITUDE * sin(float_timer)
	sprite.position.y = -8 + offset_y
	collision.position.y = -8 + offset_y

	var player = get_nearest_player()
	if not player: return
	var dist_sq = global_position.distance_squared_to(player.global_position)
	var target_speed = APPROACH_SPEED * _movement_multiplier # base speed

	if dist_sq < RETREAT_DISTANCE*RETREAT_DISTANCE:
		move_mode = "retreat"
		target_speed = RETREAT_SPEED * _movement_multiplier 
		if agent.is_navigation_finished():
			agent.target_position = await get_retreat_position_away_from(player.global_position)
	elif dist_sq > APPROACH_DISTANCE*APPROACH_DISTANCE:
		move_mode = "approach"
		target_speed = APPROACH_SPEED * _movement_multiplier 
		if agent.is_navigation_finished():
			agent.target_position = player.global_position
	else:
		move_mode = "idle"
		agent.target_position = global_position
		target_speed = 0

	var next_pos = agent.get_next_path_position()
	if next_pos != Vector2.ZERO and target_speed > 0:
		var dir = (next_pos - global_position).normalized()
		velocity = dir * target_speed
	else:
		velocity = Vector2.ZERO

	update_sprite_direction((player.global_position - global_position).normalized())

	if move_mode == "idle":
		shoot_timer -= delta
		if shoot_timer <= 0:
			play_sfx("explosionbutlikemorepixelly", global_position)
			shoot_at_player(player.global_position)
			shoot_timer = SHOOT_INTERVAL

	global_position += velocity * delta

func shoot_at_player(target_pos: Vector2) -> void:
	var base_dir = (target_pos - global_position).normalized()
	for angle in [0, 45, -45]:
		var bullet = preload("res://scenes/bullet.tscn").instantiate()
		bullet.global_position = global_position
		bullet.direction = base_dir.rotated(deg_to_rad(angle))
		get_tree().current_scene.add_child(bullet)

# Retreat helper
func get_retreat_position_away_from(player_pos: Vector2) -> Vector2:
	var best_pos = global_position
	var best_dist = 0.0
	var original_target = agent.target_position

	for angle_deg in range(0, 360, 20):
		for radius in [64, 96, 128, 160, 192]:
			var candidate = global_position + Vector2.RIGHT.rotated(deg_to_rad(angle_deg)) * radius
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
		sprite.play("bauble-right" if dir.x > 0 else "bauble-left")
	else:
		sprite.play("bauble-down" if dir.y > 0 else "bauble-up")

func get_nearest_player() -> Node2D:
	var nearest: Node2D = null
	var nearest_distance = INF
	for p in get_tree().get_nodes_in_group("players"):
		if p is Node2D and p.alive:
			var d = global_position.distance_squared_to(p.global_position)
			if d < nearest_distance:
				nearest_distance = d
				nearest = p
	return nearest
