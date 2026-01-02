extends Entity

const SPEED := 40
const HOP_INTERVAL := 1.0
const HOP_DURATION := 0.2
const HOP_HEIGHT := 6.0
const HOP_WINDUP_TIME := 0.3
const SLIME_TRAIL_INTERVAL := 0.15

@onready var trail_parent = $".."
@onready var target_indicator = $Target

var hop_timer := 0.0
var is_hopping := false
var hop_start_pos: Vector2
var hop_target_pos: Vector2
var hop_progress := 0.0

var is_winding_up := false
var windup_timer := 0.0

var trail_timer := 0.0

func initialize_entity() -> void:
	agent = $NavigationAgent2D
	sprite = $AnimatedSprite2D
	entity_name = "Gunk Slime"
	health = 500.0
	max_health = 500.0
	defense = 0.0
	id = 11
	speed = SPEED

	if sprite:
		sprite.play("default")

	hop_timer = HOP_INTERVAL
	target_indicator.visible = false


func get_gold_reward() -> int:
	return 24

func get_kill_type() -> String:
	return "gunk_slime"

func spawn_slime_trail() -> void:
	var splatter_scene = preload("res://scenes/splatter.tscn")
	var splatter = splatter_scene.instantiate()
	splatter.global_position = global_position
	trail_parent.add_child(splatter)

func can_navigate_to(pos: Vector2) -> bool:
	agent.target_position = pos

	return agent.is_navigation_finished() == false \
		and agent.get_current_navigation_path().size() > 1

func custom_physics_process(delta: float, _movement_multiplier: float) -> void:
	# Slime trail while in air
	if is_hopping:
		trail_timer -= delta
		if trail_timer <= 0.0:
			spawn_slime_trail()
			trail_timer = SLIME_TRAIL_INTERVAL

	# HOP LOGIC ----------------------------------
	if not is_hopping and not is_winding_up:
		hop_timer -= delta
		if hop_timer <= 0.0:
			var target = get_nearest_player()
			if target:
				var offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))
				var desired_pos = target.global_position + offset

				hop_start_pos = global_position

				if can_navigate_to(desired_pos):
					hop_target_pos = agent.get_next_path_position()
				else:
					# Standing on nothing / invalid nav → hop in place
					hop_target_pos = hop_start_pos

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
		global_position = hop_start_pos + move_vec * hop_progress

		# Jump arc
		var t = hop_progress
		sprite.position.y = 4 * HOP_HEIGHT * t * (t - 1)
	else:
		sprite.position.y = 0


# Player contact → only gunk + damage, no targeting junk
func on_player_contact(player: Node) -> void:
	if not alive:
		return

	if player.alive:
		# 30% chance to apply Gunked
		if randf() < 0.3 and not player.has_effect("Gunked"):
			var gunked = Effect.new("Gunked", Color.from_rgba8(0, 150, 255, 255), 8.0, 0, 0)
			if multiplayer.has_multiplayer_peer():
				Toast.add.rpc_id(int(player.name), "You've been Gunked for 8 seconds!")
			else:
				Toast.add("You've been Gunked for 8 seconds!")
			player.add_status_effect(gunked)

		player.take_damage(10, name, global_position)
