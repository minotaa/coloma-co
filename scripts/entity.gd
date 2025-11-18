extends CharacterBody2D
class_name Entity 

# Entity properties
var entity_name: String = "Entity"
var health: float = 100.0
var max_health: float = 100.0
var defense: float = 0.0
var id: int = 0
var invulnerable: bool = false
var alive: bool = true

# Movement properties
var speed: float = 40.0
var knockback_velocity := Vector2.ZERO
var knockback_friction := 800.0

# Status effects
var active_effects: Array = []

# Common nodes (should be set up in child scenes)
@onready var sprite: AnimatedSprite2D
@onready var collision: CollisionShape2D
@onready var agent: NavigationAgent2D
@onready var progress_bar: ProgressBar
@onready var hurtbox: Area2D
@onready var normal_material: Material
@onready var shock_material = preload("res://scenes/shock.tres")

# Optional particles for status effects
@onready var status_particles: GPUParticles2D

func _ready() -> void:
	# Try to auto-find common nodes
	if has_node("AnimatedSprite2D"):
		sprite = $AnimatedSprite2D
		normal_material = sprite.material
	if has_node("CollisionShape2D"):
		collision = $CollisionShape2D
	if has_node("NavigationAgent2D"):
		agent = $NavigationAgent2D
	if has_node("ProgressBar"):
		progress_bar = $ProgressBar
	if has_node("Hurtbox"):
		hurtbox = $Hurtbox
	if has_node("Potion"):
		status_particles = $Potion
	
	# Add to global entity list
	Entities.add_entity(self)
	
	# Play spawn sound
	if multiplayer.has_multiplayer_peer():
		play_sfx.rpc("appear", global_position)
	else:
		play_sfx("appear", global_position)
	
	# Call custom initialization
	initialize_entity()

# Override this in child classes for custom initialization
func initialize_entity() -> void:
	pass

func _physics_process(delta: float) -> void:
	# Update status effects
	update_status_effects(delta)
	
	# Update visual feedback for status effects
	if status_particles and active_effects.size() > 0:
		status_particles.emitting = true
		status_particles.process_material.color = get_blended_effect_color()
	elif status_particles:
		status_particles.emitting = false
	
	# Handle knockback
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	else:
		knockback_velocity = Vector2.ZERO
	
	# Update progress bar (only on server or single player)
	if ((multiplayer.has_multiplayer_peer() and multiplayer.is_server()) or not multiplayer.has_multiplayer_peer()) and progress_bar:
		progress_bar.value = health
		progress_bar.max_value = max_health
		progress_bar.visible = health < max_health
	
	# Check hurtbox collisions with players
	if hurtbox and alive:
		for body in hurtbox.get_overlapping_bodies():
			if body.is_in_group("players") and body.alive:
				on_player_contact(body)
	
	# Apply movement speed penalty from status effects
	var movement_multiplier = 1.0
	if has_effect("Gunked"):
		movement_multiplier *= 0.5
	
	# Call custom physics process
	custom_physics_process(delta, movement_multiplier)
	
	move_and_slide()

# Override this in child classes for custom physics behavior
func custom_physics_process(delta: float, movement_multiplier: float) -> void:
	pass

# Override this to define what happens when touching a player
func on_player_contact(player: Node) -> void:
	player.take_damage(10, name, global_position)

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
	get_parent().add_child(floating_text, true)

	var random_offset = Vector2(
		randi_range(-8, 8),
		randi_range(-8, 8)
	)
	floating_text.position = center_position + random_offset

@rpc("call_local")
func _flash_material():
	if sprite:
		sprite.material = shock_material
		await get_tree().create_timer(0.1).timeout
		sprite.material = normal_material

@rpc("any_peer", "call_local")
func take_damage(amount: float, from_position: Vector2, source_name: String, crit: bool = false) -> void:
	# Only let authority actually apply damage logic
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	
	if invulnerable:
		return

	print(entity_name + " took ", amount, " damage")
	
	# Apply defense reduction
	var defense_factor = 1.0 - (defense / (defense + 100.0))
	var final_damage = amount * defense_factor
	
	health -= final_damage

	# Sync floating text on all peers
	if multiplayer.has_multiplayer_peer():
		_show_damage_feedback.rpc(final_damage, global_position, crit)
		_flash_material.rpc()
	else:
		_show_damage_feedback(final_damage, global_position, crit)
		_flash_material()

	if health <= 0 and alive:
		print(entity_name + " died")
		alive = false
		on_death(source_name)

func on_death(killer_name: String) -> void:
	# Override this in child classes for custom death behavior
	# Default implementation:
	die()
	
	# Give rewards
	var gold_reward = get_gold_reward()
	if multiplayer.has_multiplayer_peer():
		get_parent().add_gold.rpc(killer_name, gold_reward)
	else:
		get_parent().add_gold(killer_name, gold_reward)
	
	get_parent().add_kill(killer_name, get_kill_type())

# Override these in child classes
func get_gold_reward() -> int:
	return 10

func get_kill_type() -> String:
	return entity_name.to_lower()

func die() -> void:
	if collision:
		collision.disabled = true
	Entities.remove_entity(self)
	
	if sprite:
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_callback(Callable(self, "queue_free"))
	else:
		queue_free()
	
	if multiplayer.has_multiplayer_peer():
		play_sfx.rpc("appear", global_position, 0.0, 0.45)
	else:
		play_sfx("appear", global_position, 0.0, 0.45)

func apply_knockback(from_position: Vector2, strength: float):
	var direction = (global_position - from_position).normalized()
	knockback_velocity = direction * strength

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

# Status effect methods
func add_status_effect(effect: Effect) -> void:
	effect.on_apply.call(self)
	active_effects.append(effect)

func has_effect(effect_name: String) -> bool:
	for effect in active_effects:
		if effect.name == effect_name:
			return true
	return false

func reset_status_effects() -> void:
	for effect in active_effects:
		effect.on_end.call(self)
	active_effects.clear()

func update_status_effects(delta: float) -> void:
	for effect in active_effects.duplicate():
		if effect != null and is_instance_valid(effect):
			if effect.update(delta, self):
				active_effects.erase(effect)
		else:
			active_effects.erase(effect)

func get_blended_effect_color() -> Color:
	if active_effects.is_empty():
		return Color.WHITE
	
	var total_red := 0.0
	var total_green := 0.0
	var total_blue := 0.0
	var count := 0
	
	for effect in active_effects:
		if effect != null and is_instance_valid(effect):
			var color = effect.color
			total_red += color.r
			total_green += color.g
			total_blue += color.b
			count += 1
	
	if count == 0:
		return Color.WHITE
	
	return Color(
		total_red / count,
		total_green / count,
		total_blue / count,
		1.0
	)
