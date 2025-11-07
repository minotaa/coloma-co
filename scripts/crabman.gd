extends Entity

const SPEED: float = 135.0

var stun_time: float = 0.0
var current_target: Node2D = null

# Crab likes low friction knockback

@onready var nav_agent: NavigationAgent2D = agent  # use the agent provided by Entity
# (we keep a local alias nav_agent for readability, but 'agent' is the same)

func initialize_entity() -> void:
	knockback_friction = 1.0
	entity_name = "Crabthing"
	health = 1250.0
	max_health = 1250.0
	defense = 0.0
	id = 5
	speed = SPEED

	# play initial animation if sprite exists
	if sprite:
		sprite.play("crabman-down")

	# configure agent if present
	if agent:
		agent.path_max_distance = 2000
		agent.target_desired_distance = 8

func get_gold_reward() -> int:
	return 50

func get_kill_type() -> String:
	return "crabman"

#
# Override take_damage to preserve crab-specific knockback + stun math,
# but reuse Entity's visual feedback & death handling.
#
@rpc("any_peer", "call_local")
func take_damage(amount: float, from_position: Vector2, source_name: String, crit: bool = false) -> void:
	# Only let authority actually apply damage logic (same as Entity)
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

	if invulnerable:
		return

	# Apply defense reduction (same formula as Entity)
	var defense_factor = 1.0 - (defense / (defense + 100.0))
	var final_damage = amount * defense_factor

	print(entity_name + " took ", final_damage, " damage")

	# Apply damage
	health -= final_damage

	# Calculate knockback + stun (Crab-specific)
	var kb_dir = (global_position - from_position).normalized()
	var kb_strength = clamp(final_damage * 40.0, 10.0, 100.0)
	knockback_velocity = kb_dir * kb_strength

	var hp_ratio = clamp(health / max_health, 0.0, 1.0)
	var base_stun = lerp(0.05, 0.6, 1.0 - hp_ratio) # more stun when lower hp
	stun_time = base_stun * clamp(final_damage / 20.0, 0.5, 2.0)

	# Sync floating text and flash across peers (reuse Entity's RPCs)
	if multiplayer.has_multiplayer_peer():
		_show_damage_feedback.rpc(final_damage, global_position, crit)
		_flash_material.rpc()
	else:
		_show_damage_feedback(final_damage, global_position, crit)
		_flash_material()

	# If died, call Entity's on_death flow
	if health <= 0 and alive:
		print(entity_name + " died")
		alive = false
		on_death(source_name)

#
# Movement / AI: runs inside Entity._physics_process via custom_physics_process
#
func custom_physics_process(delta: float, movement_multiplier: float) -> void:
	# Update target (simple cached target like before)
	update_target()

	# If stunned, apply knockback-only movement (damped by Entity's knockback handling)
	if stun_time > 0.0:
		stun_time -= delta
		# During stun we rely on Entity's knockback handling which already modifies `velocity`
		# but we also want the crab to be pushed by knockback only:
		velocity = knockback_velocity
		# additionally damp the knockback here with the same friction
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		return

	# Normal navigation-driven movement
	if current_target and current_target.alive:
		agent.target_position = current_target.global_position
		if not agent.is_navigation_finished():
			var next_point = agent.get_next_path_position()
			if next_point != Vector2.ZERO:
				var direction = (next_point - global_position).normalized()
				velocity = direction * SPEED * movement_multiplier
			else:
				velocity = Vector2.ZERO
		else:
			velocity = Vector2.ZERO
	else:
		velocity = Vector2.ZERO

	# Sprite direction update (when not stunned)
	if velocity != Vector2.ZERO and sprite:
		update_sprite_direction(velocity)

#
# Keep the same target selection behavior
#
func update_target() -> void:
	if not current_target or not current_target.alive:
		current_target = get_nearest_player()
		if current_target and agent:
			agent.target_position = current_target.global_position

#
# Reuse Entity's get_nearest_player() if available; otherwise fallback.
# (Entity already provides get_nearest_player, so we don't redefine it)
#

#
# Override player contact damage to match original crab (8 damage)
#
func on_player_contact(player: Node) -> void:
	if player and player.has_method("take_damage"):
		player.take_damage(8, global_position)

#
# Sprite animation helper (uses sprite from Entity)
#
func update_sprite_direction(dir: Vector2) -> void:
	if not sprite:
		return

	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			sprite.play("crabman-right")
		else:
			sprite.play("crabman-left")
	else:
		if dir.y > 0:
			sprite.play("crabman-down")
		else:
			sprite.play("crabman-up")
