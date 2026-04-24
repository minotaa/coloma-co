extends Entity

const SPEED := 20
const HOP_INTERVAL := 2.0
const HOP_DURATION := 0.5
const HOP_HEIGHT := 6.0
const HOP_WINDUP_TIME := 0.5
const MAX_HOP_DISTANCE := 24.0
const SLIME_TRAIL_INTERVAL := 1.0

@onready var trail_parent = $".."
@onready var target_indicator = $Target

var cooldown: float = 2.5
var hop_timer := 0.0
var is_hopping := false
var hop_start_pos: Vector2
var hop_target_pos: Vector2
var hop_progress := 0.0
var is_winding_up := false
var windup_timer := 0.0
var trail_timer := 0.0
var ready_to_hop := false

func initialize_entity() -> void:
	agent = $NavigationAgent2D
	sprite = $AnimatedSprite2D
	entity_name = "Jumper Slime"
	bestiary_description = "Magic imbued slimes that shoot out stars upon landing on the ground, particularly lethal."
	developer_commentary = "This was so easy to make... it's a crime. May contain a The Binding of Isaac reference."
	dev_commentary_requirement = 100
	health = 125.0
	max_health = 125.0
	defense = 15.0
	id = 15
	speed = SPEED
	if sprite:
		sprite.play("default")
	hop_timer = HOP_INTERVAL
	target_indicator.visible = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	hop_start_pos = global_position
	hop_target_pos = global_position
	ready_to_hop = true

func get_gold_reward() -> int:
	return 100

func get_kill_type() -> String:
	return "jumper_slime"

func shoot_stars() -> void:
	var angles = [45, 135, 225, 315]
	for angle in angles:
		var bullet = preload("res://scenes/bullet.tscn").instantiate()
		bullet.global_position = global_position
		bullet.direction = Vector2.RIGHT.rotated(deg_to_rad(angle))
		bullet.scale = Vector2(0.8, 0.8)
		get_tree().current_scene.add_child(bullet)

func custom_physics_process(delta: float, _movement_multiplier: float) -> void:
	if not ready_to_hop:
		return
	if cooldown > 0.0:
		cooldown -= delta
		return
	if not alive:
		return
	agent.get_next_path_position()

	if is_hopping:
		trail_timer -= delta
		if trail_timer <= 0.0:
			shoot_stars()
			trail_timer = SLIME_TRAIL_INTERVAL

	# HOP LOGIC ----------------------------------
	if not is_hopping and not is_winding_up:
		hop_timer -= delta
		if hop_timer <= 0.0:
			var target = get_nearest_player()
			if target:
				var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
				agent.target_position = target.global_position + offset
				hop_start_pos = global_position
				hop_target_pos = agent.get_next_path_position()
				
				if target_indicator:
					target_indicator.global_position = hop_target_pos
					target_indicator.visible = true

				is_winding_up = true
				windup_timer = HOP_WINDUP_TIME

		return

	if is_winding_up:
		windup_timer -= delta
		if windup_timer <= 0.0:
			is_winding_up = false
			is_hopping = true
			hop_progress = 0.0
			play_sfx("jump", global_position, -10.0)
		return

	if is_hopping:
		hop_progress += delta / (HOP_DURATION / _movement_multiplier)
		if hop_progress >= 1.0:
			hop_progress = 1.0
			is_hopping = false
			target_indicator.visible = false
			hop_timer = HOP_INTERVAL

		var move_vec = hop_target_pos - hop_start_pos
		if move_vec.length() > MAX_HOP_DISTANCE:
			hop_target_pos = hop_start_pos + move_vec.normalized() * MAX_HOP_DISTANCE
		global_position = hop_start_pos + move_vec * hop_progress

		var t = hop_progress
		sprite.position.y = 4 * HOP_HEIGHT * t * (t - 1)
	else:
		sprite.position.y = 0

func on_player_contact(player: Node) -> void:
	if not alive:
		return
	if player.alive:
		player.take_damage(10, name, global_position)
