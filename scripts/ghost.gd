extends CharacterBody2D

const WANDER_SPEED := 30.0
const CHARGE_SPEED := 120.0
const CHARGE_OVERSHOOT := 50.0  # How far past the player to charge
const CHARGE_COOLDOWN := 2.0
const RAYCAST_LENGTH := 90.0
const CONTACT_DAMAGE := 15.0

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var raycast_up: RayCast2D = $Up
@onready var raycast_down: RayCast2D = $Down
@onready var raycast_left: RayCast2D = $Left
@onready var raycast_right: RayCast2D = $Right
@onready var normal_material: Material = sprite.material
@onready var shock_material = preload("res://scenes/shock.tres")

var move_mode := "wander"  # "wander", "aggro", "charging", "cooldown"
var alive: bool = true
var is_aggro: bool = false
var charge_target: Vector2 = Vector2.ZERO
var charge_cooldown_timer := 0.0
var wander_timer := 0.0
var wander_target: Vector2 = Vector2.ZERO
var facing_direction: Vector2 = Vector2.DOWN

var entity = Entity.new()

@rpc("any_peer", "call_local")
func play_sfx(stream_name: String, position: Vector2, volume: float = 0.0, pitch_scale: float = 1.0) -> void:
	var sfx = AudioStreamPlayer2D.new()
	var path = "res://assets/sounds/" + stream_name + ".wav"
	sfx.stream = load(path)
	sfx.volume_db = volume
	sfx.pitch_scale = pitch_scale
	sfx.bus = "SFX"
	sfx.global_position = position
	add_child(sfx)

	sfx.play()
	sfx.finished.connect(func():
		sfx.queue_free()
	)

func _ready() -> void:
	if multiplayer.has_multiplayer_peer():
		play_sfx.rpc("appear", global_position)
	else:
		play_sfx("appear", global_position)
	
	entity.health = 400.0
	entity.max_health = 400.0
	entity.defense = 0.0
	entity.name = "Ghost"
	entity.id = 10
	Entities.add_entity(entity)
	
	sprite.play("ghost-down")
	
	# Setup raycasts (they should already be positioned correctly in the scene)
	raycast_up.enabled = true
	raycast_down.enabled = true
	raycast_left.enabled = true
	raycast_right.enabled = true
	
	# Start wandering
	set_new_wander_target()

func die() -> void:
	$Hurtbox/CollisionShape2D.disabled = true
	Entities.remove_entity(entity)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(self, "queue_free"))
	if multiplayer.has_multiplayer_peer():
		play_sfx.rpc("appear", global_position, 0.0, 0.45)
	else:
		play_sfx("appear", global_position, 0.0, 0.45)

func set_new_wander_target() -> void:
	# Pick a random point within a radius to wander to
	var angle = randf() * TAU
	var distance = randf_range(100, 200)
	wander_target = global_position + Vector2(cos(angle), sin(angle)) * distance
	agent.target_position = wander_target
	wander_timer = randf_range(2.0, 4.0)

func check_raycasts_for_player() -> bool:
	# Check all four raycasts for player collision
	var raycasts = [raycast_up, raycast_down, raycast_left, raycast_right]
	
	for raycast in raycasts:
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			if collider and collider.is_in_group("players"):
				return true
	
	return false

const FLOAT_AMPLITUDE := 1.0
const FLOAT_SPEED := 2.0
var float_timer := 0.0

func _physics_process(delta: float) -> void:
	# Floating animation
	float_timer += delta * FLOAT_SPEED
	var offset_y = FLOAT_AMPLITUDE * sin(float_timer)
	$AnimatedSprite2D.position.y = offset_y
	$CollisionShape2D.position.y = offset_y
	
	# Body damage
	for body in $Hurtbox.get_overlapping_bodies():
		if body.is_in_group("players") and alive and move_mode == "charging":
			body.take_damage(CONTACT_DAMAGE, global_position)
				# Apply status effect here later
		
	# Update health bar
	if (multiplayer.has_multiplayer_peer() and multiplayer.is_server()) or not multiplayer.has_multiplayer_peer():
		if entity != null:
			$ProgressBar.value = entity.health
			$ProgressBar.max_value = entity.max_health 
			$ProgressBar.visible = entity.health < entity.max_health

	# Check raycasts for player detection
	if not is_aggro and check_raycasts_for_player():
		become_aggro()

	match move_mode:
		"wander":
			wander_behavior(delta)
		"aggro":
			aggro_behavior(delta)
		"charging":
			charging_behavior(delta)
		"cooldown":
			cooldown_behavior(delta)

func wander_behavior(delta: float) -> void:
	wander_timer -= delta
	
	if wander_timer <= 0 or agent.is_navigation_finished():
		set_new_wander_target()
	
	var next_pos = agent.get_next_path_position()
	if next_pos != Vector2.ZERO:
		var direction = (next_pos - global_position).normalized()
		facing_direction = direction
		velocity = direction * WANDER_SPEED
		move_and_slide()
		update_sprite_direction(direction, false)
	else:
		velocity = Vector2.ZERO

func become_aggro() -> void:
	is_aggro = true
	move_mode = "aggro"
	if multiplayer.has_multiplayer_peer():
		play_sfx.rpc("ghost", global_position)  # Add appropriate sound
	else:
		play_sfx("ghost", global_position)
	$Exclaim.emitting = true

func aggro_behavior(delta: float) -> void:
	var player = get_nearest_player()
	if not player:
		# Lost player, return to wandering
		is_aggro = false
		move_mode = "wander"
		set_new_wander_target()
		return
	
	# Set up charge
	var direction_to_player = (player.global_position - global_position).normalized()
	charge_target = player.global_position + direction_to_player * CHARGE_OVERSHOOT
	facing_direction = direction_to_player
	move_mode = "charging"
	
	if multiplayer.has_multiplayer_peer():
		play_sfx.rpc("ghost", global_position)  # Add appropriate sound
	else:
		play_sfx("ghost", global_position)

func charging_behavior(delta: float) -> void:
	var direction = (charge_target - global_position).normalized()
	velocity = direction * CHARGE_SPEED
	move_and_slide()
	update_sprite_direction(direction, true)
	
	# Check if we've reached or passed the target
	if global_position.distance_squared_to(charge_target) < 100:
		move_mode = "cooldown"
		charge_cooldown_timer = CHARGE_COOLDOWN
		velocity = Vector2.ZERO

func cooldown_behavior(delta: float) -> void:
	charge_cooldown_timer -= delta
	velocity = Vector2.ZERO
	
	if charge_cooldown_timer <= 0:
		var player = get_nearest_player()
		if player and global_position.distance_squared_to(player.global_position) < 20000:  # ~140px
			move_mode = "aggro"
		else:
			is_aggro = false
			move_mode = "wander"
			set_new_wander_target()

func update_sprite_direction(dir: Vector2, aggro: bool) -> void:
	var suffix = "-aggro" if aggro else ""
	
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

@rpc("call_local")
func _show_damage_feedback(amount: int, center_position: Vector2, crit: bool):
	var floating_text_scene = preload("res://scenes/floating_text.tscn")
	var floating_text = floating_text_scene.instantiate()
	floating_text.text = str(amount)
	(floating_text as Label).label_settings = LabelSettings.new()
	(floating_text as Label).label_settings.font = preload("res://assets/fonts/slkscr.ttf")
	(floating_text as Label).label_settings.font_size = 17
	if crit:
		(floating_text as Label).label_settings.font_color = Color.YELLOW
	else:
		(floating_text as Label).label_settings.font_color = Color.WHITE
	(floating_text as Label).label_settings.shadow_color = Color(0, 0, 0, 0.80)
	$"..".add_child(floating_text, true)

	var random_offset = Vector2(
		randi_range(-8, 8),
		randi_range(-8, 8)
	)
	floating_text.position = center_position + random_offset

@rpc("call_local")
func _flash_material():
	sprite.material = shock_material
	await get_tree().create_timer(0.1).timeout
	sprite.material = normal_material

@rpc("any_peer", "call_local")
func take_damage(amount: float, from_position: Vector2, name: String, crit: bool) -> void:
	# Only let authority actually apply damage logic
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

	print("Took ", amount, " damage")
	entity.health -= amount

	# Sync floating text on all peers
	if multiplayer.has_multiplayer_peer():
		_show_damage_feedback.rpc(amount, global_position, crit)
		_flash_material.rpc()
	else:
		_show_damage_feedback(amount, global_position, crit)
		_flash_material()

	if entity.health <= 0 and alive:
		print("dead")
		die()
		alive = false
		if multiplayer.has_multiplayer_peer():
			get_parent().add_gold.rpc(name, 40)
		else:
			get_parent().add_gold(name, 40)
		get_parent().add_kill(name, "ghost")

	sprite.material = shock_material
	await get_tree().create_timer(0.1).timeout
	sprite.material = normal_material
