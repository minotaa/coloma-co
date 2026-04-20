extends Entity

const SPEED := 40
const HOP_INTERVAL := 1.2
const HOP_DURATION := 0.8
const HOP_HEIGHT := 12.0
const MAX_HOP_DISTANCE := 24.0
const HOP_WINDUP_TIME := 0.3

@onready var target_indicator = $Target

var cooldown: float = 2.5
var hop_timer := 0.0
var is_hopping := false
var hop_start_pos: Vector2
var hop_target_pos: Vector2
var hop_progress := 0.0
var is_winding_up := false
var windup_timer := 0.0
var ready_to_hop := false

func initialize_entity() -> void:
	agent = $NavigationAgent2D
	sprite = $AnimatedSprite2D
	entity_name = "Mother Slime"
	health = 250.0
	max_health = 250.0
	defense = 0.0
	id = 6
	speed = SPEED
	hop_timer = HOP_INTERVAL
	sprite.play("default")
	target_indicator.visible = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	hop_start_pos = global_position
	hop_target_pos = global_position
	ready_to_hop = true

func get_gold_reward() -> int:
	return 20

func get_kill_type() -> String:
	return "mother_slime"

func on_death(killer_name: String) -> void:
	for i in range(randi_range(2, 6)):
		var slime_scene: PackedScene
		var rand = randf()
		if rand <= 0.33:
			slime_scene = preload("res://scenes/gunk_slime.tscn")
		elif rand <= 0.66:
			slime_scene = preload("res://scenes/poison_slime.tscn")
		else:
			slime_scene = preload("res://scenes/slime.tscn")
		var new_slime = slime_scene.instantiate()
		new_slime.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))
		get_parent().add_child(new_slime, true)
	queue_free()

func custom_physics_process(delta: float, _movement_multiplier: float) -> void:
	if not ready_to_hop:
		return
	if cooldown > 0.0:
		cooldown -= delta
		return
	if not alive:
		return

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
			if multiplayer.has_multiplayer_peer():
				play_sfx.rpc("bigjump", global_position)
			else:
				play_sfx("bigjump", global_position)
		return

	if is_hopping:
		hop_progress += delta / HOP_DURATION / _movement_multiplier
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

	for body in $Hurtbox.get_overlapping_bodies():
		if body != null and body.is_in_group("players") and alive:
			body.take_damage(20, name, global_position)

func get_nearest_player() -> Node2D:
	var players: Array = get_tree().get_nodes_in_group("players")
	var nearest: Node2D = null
	var nearest_distance: float = INF

	for player in players:
		if player is Node2D and player.alive:
			var dist: float = global_position.distance_squared_to(player.global_position)
			if dist < nearest_distance:
				nearest_distance = dist
				nearest = player

	return nearest
