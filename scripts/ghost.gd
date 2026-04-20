extends Entity

const WANDER_SPEED := 30.0
const CHARGE_SPEED := 120.0
const CHARGE_OVERSHOOT := 50.0  # How far past the player to charge
const CHARGE_COOLDOWN := 2.0
const RAYCAST_LENGTH := 90.0
const CONTACT_DAMAGE := 15.0

@onready var raycast_up: RayCast2D = $Up
@onready var raycast_down: RayCast2D = $Down
@onready var raycast_left: RayCast2D = $Left
@onready var raycast_right: RayCast2D = $Right
@onready var exclaim = $Exclaim

var move_mode := "wander"  # "wander", "aggro", "charging", "cooldown"
var is_aggro: bool = false
var charge_target: Vector2 = Vector2.ZERO
var charge_cooldown_timer := 0.0
var wander_timer := 0.0
var wander_target: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.DOWN
var float_timer := 0.0

func initialize_entity() -> void:
	entity_name = "Ghost"
	bestiary_description = "Apparitions from beyond, can't do anything to mortals, but still watch out, they can still make you feel weak."
	developer_commentary = "Initially, they dealt damage and were just stronger versions of the slimes, with a gimmick that they were neutral until you stepped in range, I thought it'd be better if they simply did no damage and created Weak to give it the ability to detriment the player."
	dev_commentary_requirement = 25
	health = 400.0
	max_health = 400.0
	defense = 0.0
	id = 10
	speed = WANDER_SPEED

	if sprite:
		sprite.play("ghost-down")

	# Enable raycasts if present
	if raycast_up:
		raycast_up.enabled = true
	if raycast_down:
		raycast_down.enabled = true
	if raycast_left:
		raycast_left.enabled = true
	if raycast_right:
		raycast_right.enabled = true

	# Exclaim particle (optional)
	if exclaim:
		exclaim.emitting = false

	set_new_wander_target()

func get_gold_reward() -> int:
	return 40

func get_kill_type() -> String:
	return "ghost"

# --- Movement & AI (called from Entity._physics_process) ---
func custom_physics_process(delta: float, movement_multiplier: float) -> void:
	# Knockback handled by Entity; floating animation + collision offset
	float_timer += delta * 2.0
	var offset_y = 1.0 * sin(float_timer)
	if sprite:
		sprite.position.y = offset_y
	if collision:
		collision.position.y = offset_y

	# Body contact: Entity calls on_player_contact when players overlap hurtbox.
	# We'll only damage players while charging by overriding on_player_contact below.

	# Raycast detection -> become aggro
	if not is_aggro and check_raycasts_for_player():
		become_aggro()

	# AI state machine
	match move_mode:
		"wander":
			wander_behavior(delta, movement_multiplier)
		"aggro":
			aggro_behavior(delta)
		"charging":
			charging_behavior(delta)
		"cooldown":
			cooldown_behavior(delta)

	# Set velocity clamp: Entity will call move_and_slide() after this function.
	# (We set velocity, don't call move_and_slide here.)

# --- Behaviors ---
func set_new_wander_target() -> void:
	var angle = randf() * TAU
	var distance = randf_range(100, 200)
	wander_target = global_position + Vector2(cos(angle), sin(angle)) * distance
	if agent:
		agent.target_position = wander_target
	wander_timer = randf_range(2.0, 4.0)

func wander_behavior(delta: float, movement_multiplier: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0 or (agent and agent.is_navigation_finished()):
		set_new_wander_target()

	var next_pos = agent.get_next_path_position() if agent else Vector2.ZERO
	if next_pos != Vector2.ZERO:
		var direction = (next_pos - global_position).normalized()
		facing_direction = direction
		velocity = direction * WANDER_SPEED * movement_multiplier
		update_sprite_direction(direction, false)
	else:
		velocity = Vector2.ZERO

func become_aggro() -> void:
	is_aggro = true
	move_mode = "aggro"
	if multiplayer.has_multiplayer_peer():
		play_sfx.rpc("ghost", global_position)
	else:
		play_sfx("ghost", global_position)
	if exclaim:
		exclaim.emitting = true

func aggro_behavior(delta: float) -> void:
	var player = get_nearest_player()
	if not player:
		is_aggro = false
		move_mode = "wander"
		set_new_wander_target()
		return

	var direction_to_player = (player.global_position - global_position).normalized()
	charge_target = player.global_position + direction_to_player * CHARGE_OVERSHOOT
	facing_direction = direction_to_player
	move_mode = "charging"

	if multiplayer.has_multiplayer_peer():
		play_sfx.rpc("ghost", global_position)
	else:
		play_sfx("ghost", global_position)

func charging_behavior(delta: float) -> void:
	var direction = (charge_target - global_position).normalized()
	velocity = direction * CHARGE_SPEED
	update_sprite_direction(direction, true)

	# If close enough to target, enter cooldown
	if global_position.distance_squared_to(charge_target) < 100:
		move_mode = "cooldown"
		charge_cooldown_timer = CHARGE_COOLDOWN
		velocity = Vector2.ZERO

func cooldown_behavior(delta: float) -> void:
	charge_cooldown_timer -= delta
	velocity = Vector2.ZERO
	if charge_cooldown_timer <= 0:
		var player = get_nearest_player()
		if player and global_position.distance_squared_to(player.global_position) < 20000: # ~140px
			move_mode = "aggro"
		else:
			is_aggro = false
			move_mode = "wander"
			set_new_wander_target()

# --- Raycast detection ---
func check_raycasts_for_player() -> bool:
	var raycasts = [raycast_up, raycast_down, raycast_left, raycast_right]
	for ray in raycasts:
		if ray and ray.is_colliding():
			var collider = ray.get_collider()
			if collider and collider.is_in_group("players"):
				return true
	return false

func on_player_contact(player: Node) -> void:
	if move_mode == "charging" and player and player.alive:
		if not player.has_effect("Weak"):
			var brittle = Effect.new("Weak", Color.from_rgba8(200, 200, 255, 255), 10.0, 0, 0)
			var texture = AtlasTexture.new()
			texture.atlas = load("res://assets/sprites/status_effects.png")
			texture.region = Rect2(128.0, 0.0, 16.0, 16.0)
			brittle.texture = texture
			if multiplayer.has_multiplayer_peer():
				Toast.add.rpc_id(int(player.name), "You've been Weakened for 10 seconds!")
			else:
				Toast.add("You've been Weakened for 10 seconds!")
			player.add_status_effect(brittle)
		player.take_damage(0, name, global_position)
			
# --- Sprite helper ---
func update_sprite_direction(dir: Vector2, aggro: bool) -> void:
	var suffix = "-aggro" if aggro else ""
	if not sprite:
		return
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			sprite.play("ghost-right" + suffix)
		else:
			sprite.play("ghost-left" + suffix)
	else:
		if dir.y > 0:
			sprite.play("ghost-down" + suffix)
		else:
			sprite.play("ghost-up" + suffix)

# Note: Entity already provides get_nearest_player(), take_damage(), _show_damage_feedback(), _flash_material(), die(), play_sfx(), and hurtbox wiring.
# This script relies on those implementations.
