extends Entity

const SPAWN_DELAY := 1.0
const SHOOT_INTERVAL := 2.0
const RETREAT_DISTANCE := 70.0
const APPROACH_DISTANCE := 90
const APPROACH_SPEED := 10.0
const RETREAT_SPEED := 20.0
const FLOAT_AMPLITUDE := 1.0
const FLOAT_SPEED := 2.0

var move_mode := "idle"
var shoot_timer := SPAWN_DELAY
var float_timer := 0.0

var explosion_scene = preload("res://scenes/explosion.tscn")

func initialize_entity() -> void:
	agent = $NavigationAgent2D
	entity_name = "Explosive Bauble"
	bestiary_description = "Bauble variant that specializes in shooting specialized explosive Stars. They can detonate on players or on walls. Stay away if you value your life!"
	developer_commentary = "Explosive Baubles are designed after grenades, their special stars are meant to give a more distinct appearance from other stars."
	dev_commentary_requirement = 10
	health = 250
	max_health = 250
	defense = 0
	id = 12
	sprite.play("bauble-down")

func on_player_contact(player: Node) -> void:
	pass

func custom_physics_process(delta: float, movement_multiplier: float) -> void:
	float_timer += delta * FLOAT_SPEED
	var offset_y = FLOAT_AMPLITUDE * sin(float_timer)
	sprite.position.y = -8 + offset_y
	collision.position.y = -8 + offset_y

	var player = get_nearest_player()
	if not player: return
	var dist_sq = global_position.distance_squared_to(player.global_position)
	var speed = APPROACH_SPEED * movement_multiplier # base speed

	if dist_sq < RETREAT_DISTANCE*RETREAT_DISTANCE:
		move_mode = "retreat"
		speed = RETREAT_SPEED * movement_multiplier 
		if agent.is_navigation_finished():
			agent.target_position = await get_retreat_position_away_from(player.global_position)
	elif dist_sq > APPROACH_DISTANCE*APPROACH_DISTANCE:
		move_mode = "approach"
		speed = APPROACH_SPEED * movement_multiplier 
		if agent.is_navigation_finished():
			agent.target_position = player.global_position
	else:
		move_mode = "idle"
		agent.target_position = global_position
		speed = 0

	var next_pos = agent.get_next_path_position()
	if next_pos != Vector2.ZERO and speed > 0:
		var dir = (next_pos - global_position).normalized()
		velocity = dir * speed
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
	var bullet = preload("res://scenes/explosive_bullet.tscn").instantiate()
	bullet.global_position = global_position
	bullet.direction = (target_pos - global_position).normalized()
	get_tree().current_scene.add_child(bullet)

# --- Retreat helper ---
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
			if agent.get_next_path_position() != Vector2.ZERO:
				var dist = candidate.distance_squared_to(player_pos)
				if dist > best_dist:
					best_dist = dist
					best_pos = candidate

	agent.target_position = original_target
	return best_pos

func get_kill_type() -> String:
	return "explosive_bauble"

# --- Sprite facing ---
func update_sprite_direction(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		sprite.play("bauble-right" if dir.x > 0 else "bauble-left")
	else:
		sprite.play("bauble-down" if dir.y > 0 else "bauble-up")
