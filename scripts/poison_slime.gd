extends Entity

const SPEED := 40
const HOP_INTERVAL := 1.0
const HOP_DURATION := 0.2
const HOP_HEIGHT := 6.0
const HOP_WINDUP_TIME := 0.3

@onready var target_indicator = $Target

var cooldown: float = 2.5
var hop_timer := HOP_INTERVAL
var is_hopping := false
var hop_start_pos: Vector2
var hop_target_pos: Vector2
var hop_progress := 0.0
var is_winding_up := false
var windup_timer := 0.0

func initialize_entity() -> void:
	agent = $NavigationAgent2D
	sprite = $AnimatedSprite2D
	entity_name = "Poison Slime"
	health = 225.0
	max_health = 225.0
	defense = 0.0
	id = 7
	speed = SPEED
	sprite.play("default")
	target_indicator.visible = false

func get_gold_reward() -> int:
	return 20

func get_kill_type() -> String:
	return "poison_slime"

func custom_physics_process(delta: float, _movement_multiplier: float) -> void:
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
				play_sfx.rpc("jump", global_position, -10.0)
			else:
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
		global_position = hop_start_pos + move_vec * hop_progress

		# Jump arc
		var t = hop_progress
		sprite.position.y = 4 * HOP_HEIGHT * t * (t - 1)
	else:
		sprite.position.y = 0

	# Player collision: damage + poison effect
	for body in $Hurtbox.get_overlapping_bodies():
		if body != null and body.is_in_group("players") and alive:
			body.take_damage(12, name, global_position)
			if randf() < 0.3 and body.alive and not body.has_effect("Poison"):
				var poison = Effect.new("Poison", Color.from_rgba8(55, 198, 0, 255), 10.0, 0, 2)
				var enemy_pos = global_position
				poison.on_effect = func(target):
					target.take_damage(2, name, enemy_pos)
				body.add_status_effect(poison)
				if multiplayer.has_multiplayer_peer():
					Toast.add.rpc_id(int(body.name), "You've been Poisoned for 10 seconds!")
				else:
					Toast.add("You've been Poisoned for 10 seconds!")

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
