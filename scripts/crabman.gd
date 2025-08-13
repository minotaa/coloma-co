extends CharacterBody2D

const SPEED: float = 135.0
var alive: bool = true
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_friction := 1.0
var stun_time: float = 0.0

@onready var normal_material: Material = $AnimatedSprite2D.material
@onready var shock_material = preload("res://scenes/shock.tres")
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var target_line: Line2D = $Line2D

var entity = Entity.new()
var current_target: Node2D = null

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
		play_sfx("appear", global_position)
	else:
		play_sfx.rpc("appear", global_position)
	entity.health = 1250.0
	entity.max_health = 1250.0
	entity.defense = 0.0
	entity.name = "Crabthing"
	entity.id = 5
	Entities.add_entity(entity)
	$AnimatedSprite2D.play("crabman-down")
	nav_agent.path_max_distance = 2000
	nav_agent.target_desired_distance = 8

@rpc("call_local")
func _show_damage_feedback(amount: int, center_position: Vector2):
	var floating_text_scene: PackedScene = preload("res://scenes/floating_text.tscn")
	var floating_text: Node = floating_text_scene.instantiate()
	(floating_text as Label).text = str(amount)
	(floating_text as Label).label_settings.font_color = Color.WHITE
	$"..".add_child(floating_text, true)

	var random_offset: Vector2 = Vector2(
									 randi_range(-8, 8),
									 randi_range(-8, 8)
								 )
	floating_text.position = center_position + random_offset

@rpc("call_local")
func _flash_material():
	$AnimatedSprite2D.material = shock_material
	await get_tree().create_timer(0.1).timeout
	$AnimatedSprite2D.material = normal_material

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

func update_target() -> void:
	if not current_target or not current_target.alive:
		current_target = get_nearest_player()
		if current_target:
			nav_agent.target_position = current_target.global_position

#func update_line() -> void:
#	if current_target and current_target.alive:
#		target_line.visible = true
#		target_line.clear_points()
#		target_line.add_point(Vector2.ZERO)
#		var sprite = current_target.get_node("AnimatedSprite2D")
#		var tex_size = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_size()
#		var center_pos = current_target.global_position + (tex_size * sprite.scale / 2)
#		target_line.add_point(to_local(center_pos))
#	else:
#		target_line.visible = false

@rpc("any_peer", "call_local")
func take_damage(amount: float, from_position: Vector2, name: String) -> void:
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

	print("Took ", amount, " damage")
	entity.health -= amount
	
	var kb_dir = (global_position - from_position).normalized()
	var kb_strength = clamp(amount * 40.0, 10.0, 100.0)
	knockback_velocity = kb_dir * kb_strength
	
	var hp_ratio = clamp(entity.health / entity.max_health, 0.0, 1.0)
	var base_stun = lerp(0.05, 0.6, 1.0 - hp_ratio) # more stun when lower hp
	stun_time = base_stun * clamp(amount / 20.0, 0.5, 2.0)
	
	if multiplayer.has_multiplayer_peer():
		_show_damage_feedback.rpc(amount, global_position)
		_flash_material.rpc()
	else:
		_show_damage_feedback(amount, global_position)
		_flash_material()

	if entity.health <= 0 and alive:
		print("dead")
		die()
		alive = false
		if multiplayer.has_multiplayer_peer():
			Toast.add.rpc_id(int(name), "+50 Gold")
			get_parent().add_gold.rpc(name, 50)
		else:
			Toast.add("+50 Gold")
			get_parent().add_gold(name, 50)
		get_parent().add_kill(name, "crabman")

	$AnimatedSprite2D.material = shock_material
	await get_tree().create_timer(0.1).timeout
	$AnimatedSprite2D.material = normal_material

func die() -> void:
	$CollisionShape2D.disabled = true
	Entities.remove_entity(entity)
	$AnimatedSprite2D.play("crabman-down")
	var tween = create_tween()
	tween.tween_property($AnimatedSprite2D, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(self, "queue_free"))

func update_sprite_direction(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			$AnimatedSprite2D.play("crabman-right")
		else:
			$AnimatedSprite2D.play("crabman-left")
	else:
		if dir.y > 0:
			$AnimatedSprite2D.play("crabman-down")
		else:
			$AnimatedSprite2D.play("crabman-up")
			
func _physics_process(delta: float) -> void:
	if (multiplayer.has_multiplayer_peer() and multiplayer.is_server()) or not multiplayer.has_multiplayer_peer():
		if entity != null:
			$ProgressBar.value = entity.health
			$ProgressBar.max_value = entity.max_health
			$ProgressBar.visible = entity.health != entity.max_health

		# AI target logic
		update_target()

		# If stunned, apply knockback movement only
		if stun_time > 0.0:
			stun_time -= delta
			# apply knockback movement
			velocity = knockback_velocity
			# damp knockback
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
		else:
			# Normal navigation-driven movement
			if current_target and current_target.alive:
				nav_agent.target_position = current_target.global_position
				if nav_agent.is_navigation_finished() == false:
					var next_point = nav_agent.get_next_path_position()
					var direction = (next_point - global_position).normalized()
					velocity = direction * SPEED
				else:
					velocity = Vector2.ZERO
			else:
				velocity = Vector2.ZERO

		# apply movement (server authoritative)
		if velocity != Vector2.ZERO:
			move_and_slide()
		
	if stun_time <= 0.0:
		update_sprite_direction(velocity)

	# draw/update the target line on all peers
	#update_line()

	for body in $Hurtbox.get_overlapping_bodies():
		if body.is_in_group("players") and alive:
			body.take_damage(8, global_position)
