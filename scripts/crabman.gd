extends Entity

enum State { BURROWED, UNBURROWING, DASHING, BURROWING }

const BURROW_RANGE := 120.0
const SURFACE_RANGE := 60.0        # must be this close (or closer) to trigger unburrowing
const OUT_OF_RANGE_TIME := 1.2     # seconds beyond SURFACE_RANGE before re-burrowing

const BASE_DASH_SPEED := 20.0
const MAX_DASH_SPEED := 120.0
const RAMP_TIME := 8.0             # seconds to reach max dash speed

var state: State = State.BURROWED
var current_target: Node2D = null
var out_of_range_timer: float = 0.0
var dash_ramp_time: float = 0.0
var stun_time: float = 0.0

@onready var nav_agent: NavigationAgent2D = agent

func initialize_entity() -> void:
	knockback_friction = 1.0
	entity_name = "Crabthing"
	bestiary_description = "Species of sea creature that crawls in shells. Stays burrowed until you get close, then bursts out and charges, gaining speed the longer it chases. Hitting it resets its momentum."
	developer_commentary = "These were a monstrosity to draw, I did not like drawing these at all. I literally just drew the Crabthing over Clementine."
	dev_commentary_requirement = 85
	health = 1000.0
	max_health = 1000.0
	defense = 0.0
	id = 5
	speed = BASE_DASH_SPEED

	invulnerable = true

	if sprite:
		sprite.visible = false
		sprite.animation_finished.connect(_on_animation_finished)

	if agent:
		agent.path_max_distance = 2000
		agent.target_desired_distance = 8

func get_gold_reward() -> int:
	return 50

func get_kill_type() -> String:
	return "crabman"

@rpc("any_peer", "call_local")
func take_damage(amount: float, from_position: Vector2, source_name: String, crit: bool = false) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if invulnerable:
		return

	var defense_factor = 1.0 - (defense / (defense + 100.0))
	var final_damage = amount * defense_factor
	health -= final_damage

	# Knockback + stun, same feel as before
	var kb_dir = (global_position - from_position).normalized()
	knockback_velocity = kb_dir * 10.0

	var hp_ratio = clamp(health / max_health, 0.0, 1.0)
	var base_stun = lerp(0.05, 0.6, 1.0 - hp_ratio)
	stun_time = base_stun * clamp(final_damage / 20.0, 0.5, 5.0)

	# Losing the ramp on hit, only matters mid-dash
	if state == State.DASHING:
		dash_ramp_time = 0.0

	if multiplayer.has_multiplayer_peer():
		_show_damage_feedback.rpc(final_damage, global_position, crit)
		_flash_material.rpc()
	else:
		_show_damage_feedback(final_damage, global_position, crit)
		_flash_material()

	if health <= 0 and alive:
		alive = false
		on_death(source_name)

func custom_physics_process(delta: float, movement_multiplier: float) -> void:
	update_target()

	if stun_time > 0.0 and state == State.DASHING:
		stun_time -= delta
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		return

	match state:
		State.BURROWED:
			_process_burrowed()
		State.UNBURROWING, State.BURROWING:
			velocity = Vector2.ZERO
		State.DASHING:
			_process_dashing(delta, movement_multiplier)

func update_target() -> void:
	if state == State.BURROWED:
		current_target = get_nearest_player()
	elif not current_target or not current_target.alive:
		current_target = get_nearest_player()

func _process_burrowed() -> void:
	velocity = Vector2.ZERO  # stays put underground until a player gets close
	if not current_target:
		return
	if global_position.distance_to(current_target.global_position) <= SURFACE_RANGE:
		_begin_unburrow()

func _begin_unburrow() -> void:
	state = State.UNBURROWING
	velocity = Vector2.ZERO
	if sprite:
		sprite.visible = true
		sprite.play_backwards("crabman-burrow")

func _on_animation_finished() -> void:
	match state:
		State.UNBURROWING:
			_start_dashing()
		State.BURROWING:
			_finish_burrow()

func _start_dashing() -> void:
	state = State.DASHING
	invulnerable = false
	dash_ramp_time = 0.0
	out_of_range_timer = 0.0

func _process_dashing(delta: float, movement_multiplier: float) -> void:
	if not current_target:
		_begin_burrow()
		return

	var dist = global_position.distance_to(current_target.global_position)
	if dist > BURROW_RANGE:
		out_of_range_timer += delta
		if out_of_range_timer >= OUT_OF_RANGE_TIME:
			_begin_burrow()
			return
	else:
		out_of_range_timer = 0.0

	dash_ramp_time += delta
	var ramp_pct = clamp(dash_ramp_time / RAMP_TIME, 0.0, 1.0)
	var current_speed = lerp(BASE_DASH_SPEED, MAX_DASH_SPEED, ramp_pct)

	var direction = (current_target.global_position - global_position).normalized()
	velocity = direction * current_speed * movement_multiplier
	update_sprite_direction(direction)

func _begin_burrow() -> void:
	state = State.BURROWING
	invulnerable = true
	velocity = Vector2.ZERO
	if sprite:
		sprite.play("crabman-burrow")

func _finish_burrow() -> void:
	state = State.BURROWED
	if sprite:
		sprite.visible = false

func on_player_contact(player: Node) -> void:
	if state != State.DASHING:
		return
	if player and player.has_method("take_damage"):
		player.take_damage(8, name, global_position)

func update_sprite_direction(dir: Vector2) -> void:
	if not sprite:
		return
	if abs(dir.x) > abs(dir.y):
		sprite.play("crabman-right" if dir.x > 0 else "crabman-left")
	else:
		sprite.play("crabman-down" if dir.y > 0 else "crabman-up")
