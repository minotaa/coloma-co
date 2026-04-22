extends Entity

const SPEED: float = 30.0
const ATTACK_RANGE: float = 100.0
const WAKE_UP_TIME: float = 1.8

var current_target: Node2D = null
var last_facing: String = "down"
var wake_timer: float = 0.0
var is_awake: bool = false
var is_curled: bool = false
var is_uncurling: bool = false

@onready var nav_agent: NavigationAgent2D = agent

func initialize_entity() -> void:
	entity_name = "Protector Golem"
	bestiary_description = "Constructs of magic akin to totems, gentle creatures that seem to not particularly hold any ill will but will aid the creatures of the land."
	developer_commentary = "No description but pretty good lore right?"
	dev_commentary_requirement = 50
	health = 500.0
	max_health = 500.0
	defense = 150.0
	id = 14
	speed = SPEED

	if sprite:
		sprite.play("golem-curl")
		await sprite.animation_finished
		sprite.stop()
		sprite.frame = sprite.sprite_frames.get_frame_count("golem-curl") - 1
		is_curled = true

	if agent:
		agent.path_max_distance = 2000
		agent.target_desired_distance = ATTACK_RANGE

func get_gold_reward() -> int:
	return 200

func get_kill_type() -> String:
	return "protector_golem"

func custom_physics_process(delta: float, movement_multiplier: float) -> void:
	update_target()

	if current_target and current_target.alive:
		var dist = global_position.distance_to(current_target.global_position)

		if dist <= ATTACK_RANGE:
			velocity = Vector2.ZERO
			is_awake = false
			wake_timer = 0.0
			play_idle_animation()
			on_enemies_in_range(get_entities_in_range(ATTACK_RANGE))
		else:
			if not is_awake:
				wake_timer += delta
				velocity = Vector2.ZERO
				play_idle_animation()
				if wake_timer >= WAKE_UP_TIME:
					is_awake = true
			else:
				agent.target_position = current_target.global_position
				var next_point = agent.get_next_path_position()
				if not agent.is_navigation_finished() and next_point != Vector2.ZERO:
					var direction = (next_point - global_position).normalized()
					velocity = direction * SPEED * movement_multiplier
					update_sprite_direction(velocity)
				else:
					velocity = Vector2.ZERO
					play_idle_animation()
	else:
		velocity = Vector2.ZERO
		is_awake = false
		wake_timer = 0.0
		play_curl_animation()

func update_target() -> void:
	var nearest = get_nearest_entity()
	if current_target != nearest:
		current_target = nearest
		is_awake = false
		wake_timer = 0.0

func uncurl() -> void:
	if not is_curled or not sprite or is_uncurling:
		return
	is_uncurling = true
	sprite.play_backwards("golem-curl")
	await sprite.animation_finished
	is_curled = false
	is_uncurling = false
	if sprite:
		sprite.play("golem-idle")

func play_curl_animation() -> void:
	if not sprite or is_curled or is_uncurling:
		return
	is_curled = true
	sprite.play("golem-curl")

func get_nearest_entity() -> Node2D:
	var nearest: Node2D = null
	var nearest_dist: float = INF

	for entity in get_tree().get_nodes_in_group("enemies"):
		if entity.id == id or entity.id == 4 or entity.id == 1:
			continue
		if not entity.alive:
			continue

		var dist = global_position.distance_squared_to(entity.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = entity

	return nearest

func get_entities_in_range(r: float) -> Array:
	var result: Array = []
	for entity in get_tree().get_nodes_in_group("enemies"):
		if entity.id == id or entity.id == 4 or entity.id == 1:
			continue
		if not entity.alive:
			continue
		if global_position.distance_to(entity.global_position) <= r:
			result.append(entity)
	return result

func on_enemies_in_range(enemies: Array) -> void:
	pass

func on_player_contact(_player: Node) -> void:
	pass

func play_idle_animation() -> void:
	if not sprite:
		return
	if is_curled or is_uncurling:
		uncurl()
		return
	if sprite.animation != "golem-idle":
		sprite.play("golem-idle")

func update_sprite_direction(dir: Vector2) -> void:
	if not sprite:
		return

	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			last_facing = "right"
			sprite.play("golem-right")
		else:
			last_facing = "left"
			sprite.play("golem-left")
	else:
		if dir.y > 0:
			last_facing = "down"
			sprite.play("golem-down")
		else:
			last_facing = "up"
			sprite.play("golem-up")
