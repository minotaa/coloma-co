extends Entity

const HOP_INTERVAL = 1.0
const HOP_DURATION = 0.2
const HOP_HEIGHT = 6.0
const HOP_WINDUP_TIME = 0.3
const MAX_HOP_DISTANCE := 24.0

var cooldown: float = 2.5
var hop_timer: float = 0.0
var is_hopping: bool = false
var hop_start_pos: Vector2
var hop_target_pos: Vector2
var hop_progress: float = 0.0
var is_winding_up = false
var windup_timer = 0.0
var ready_to_hop: bool = false

@onready var target_indicator = $Target

func initialize_entity() -> void:
	entity_name = "Slime"
	health = 75.0
	max_health = 75.0
	defense = 0.0
	id = 0
	speed = 40.0
	
	if sprite:
		sprite.play("default")
	
	# Wait for the node to fully settle into the world before allowing movement
	await get_tree().physics_frame
	await get_tree().physics_frame
	hop_start_pos = global_position
	hop_target_pos = global_position
	ready_to_hop = true

func get_gold_reward() -> int:
	return 12

func get_kill_type() -> String:
	return "slime"

func custom_physics_process(delta: float, movement_multiplier: float) -> void:
	if not ready_to_hop:
		return
	if cooldown > 0.0:
		cooldown -= delta
		return
	if not alive:
		return
	agent.get_next_path_position()
	
	# Cancel hop if knocked back
	if knockback_velocity.length() > 0.1:
		sprite.position.y = 0
		hop_timer = HOP_INTERVAL
		is_hopping = false
		is_winding_up = false
		if target_indicator:
			target_indicator.visible = false
		return

	# Hop logic
	if not is_hopping and not is_winding_up:
		hop_timer -= delta
		if hop_timer <= 0.0:
			var target = get_nearest_player()
			if target:
				var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
				agent.target_position = target.global_position + offset
				
				# Clamp hop target to MAX_HOP_DISTANCE
				var next_pos = agent.get_next_path_position()
				var to_target = next_pos - global_position
				if to_target.length() > MAX_HOP_DISTANCE:
					next_pos = global_position + to_target.normalized() * MAX_HOP_DISTANCE
				
				hop_start_pos = global_position
				hop_target_pos = next_pos
				
				if target_indicator:
					target_indicator.global_position = hop_target_pos
					target_indicator.visible = true

				is_winding_up = true
				windup_timer = HOP_WINDUP_TIME

	elif is_winding_up:
		windup_timer -= delta
		if windup_timer <= 0.0:
			is_winding_up = false
			is_hopping = true
			hop_progress = 0.0
			play_sfx("jump", global_position, -10.0)

	elif is_hopping:
		hop_progress += delta / (HOP_DURATION / movement_multiplier)
		if hop_progress >= 1.0:
			hop_progress = 1.0
			is_hopping = false
			if target_indicator:
				target_indicator.visible = false
			hop_timer = HOP_INTERVAL

		var move_vec = hop_target_pos - hop_start_pos
		global_position = hop_start_pos + move_vec * hop_progress

	# Update vertical offset of sprite (hop arc)
	if is_hopping and sprite:
		var t = hop_progress
		var height = 4 * HOP_HEIGHT * t * (t - 1)
		sprite.position.y = height
	elif sprite:
		sprite.position.y = 0
