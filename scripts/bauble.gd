extends CharacterBody2D

const SHOOT_INTERVAL := 2.0
const RETREAT_DISTANCE := 70.0  # Try to maintain this distance from the player
const APPROACH_DISTANCE := 90
const APPROACH_SPEED = 30.0
const RETREAT_SPEED = 80.0

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var normal_material: Material = sprite.material
@onready var shock_material = preload("res://scenes/shock.tres")

var move_mode = "idle"
var alive: bool = true
var explosion_scene = preload("res://scenes/explosion.tscn")
var shoot_timer := 0.0

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
	entity.health = 100.0
	entity.max_health = 100.0
	entity.defense = 0.0
	entity.name = "Bauble"
	entity.id = 3
	Entities.add_entity(entity)
	sprite.play("bauble-down")

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

func get_retreat_position_away_from(player_pos: Vector2) -> Vector2:
	var best_pos = global_position
	var best_dist = 0.0

	# Save the original target to restore after testing
	var original_target = agent.target_position

	for angle_deg in range(0, 360, 20):
		for radius in [64, 96, 128, 160, 192]:
			var angle_rad = deg_to_rad(angle_deg)
			var offset = Vector2(cos(angle_rad), sin(angle_rad)) * radius
			var candidate = global_position + offset

			# Temporarily test path to candidate
			agent.target_position = candidate
			var next_pos = agent.get_next_path_position()

			if next_pos != Vector2.ZERO:
				var dist = candidate.distance_squared_to(player_pos)
				if dist > best_dist:
					best_dist = dist
					best_pos = candidate

	# Restore original target
	agent.target_position = original_target

	return best_pos

const FLOAT_AMPLITUDE := 1.0  # How far up/down it floats (pixels)
const FLOAT_SPEED := 2.0      # How fast it floats
var float_timer := 0.0

func _physics_process(delta: float) -> void:
	float_timer += delta * FLOAT_SPEED
	var offset_y = FLOAT_AMPLITUDE * sin(float_timer)
	$AnimatedSprite2D.position.y = -8 + offset_y
	$CollisionShape2D.position.y = -8 + offset_y
	if (multiplayer.has_multiplayer_peer() and multiplayer.is_server()) or not multiplayer.has_multiplayer_peer():
		if entity != null:
			$ProgressBar.value = entity.health
			$ProgressBar.max_value = entity.max_health 
			$ProgressBar.visible = entity.health < entity.max_health

	var player = get_nearest_player()
	if player:
		var dist_squared = global_position.distance_squared_to(player.global_position)
		var target_speed = 40.0

		if dist_squared < RETREAT_DISTANCE * RETREAT_DISTANCE:
			# Retreating: run away fast
			move_mode = "retreat"
			target_speed = RETREAT_SPEED

			if agent.is_navigation_finished():
				var retreat_target = get_retreat_position_away_from(player.global_position)
				agent.target_position = retreat_target

		elif dist_squared > APPROACH_DISTANCE * APPROACH_DISTANCE:
			# Approaching: move slower toward player
			move_mode = "approach"
			target_speed = APPROACH_SPEED

			agent.target_position = player.global_position

		else:
			# Idle (safe zone): stop moving
			move_mode = "idle"
			agent.set_target_position(global_position)

		var next_pos = agent.get_next_path_position()

		if next_pos != Vector2.ZERO:
			var direction = (next_pos - global_position).normalized()
			velocity = direction * target_speed
			move_and_slide()

			# Face movement direction only if retreating
			if move_mode == "retreat":
				update_sprite_direction(direction)
			else:
				# Otherwise face nearest player
				var face_dir = (player.global_position - global_position).normalized()
				update_sprite_direction(face_dir)
		else:
			velocity = Vector2.ZERO

			# When idle with no movement, still face player
			if move_mode == "idle":
				var face_dir = (player.global_position - global_position).normalized()
				update_sprite_direction(face_dir)

		if move_mode == "idle":
		# Shooting logic
			shoot_timer -= delta
			if shoot_timer <= 0.0:
				if multiplayer.has_multiplayer_peer():
					play_sfx.rpc("explosionbutlikemorepixelly", global_position)
				else:
					play_sfx("explosionbutlikemorepixelly", global_position)
				shoot_at_player(player.global_position)
				shoot_timer = SHOOT_INTERVAL

			# Shooting
			#shoot_timer -= delta
			#if shoot_timer <= 0.0 and dist_to_player <= SHOOT_DISTANCE:
				#shoot_at_player(player.global_position)
				#shoot_timer = SHOOT_INTERVAL
	#for body in $Hurtbox.get_overlapping_bodies():
		#if body.is_in_group("players") and alive:
			#body.take_damage(10, global_position)
			#pass

@rpc("call_local")
func _show_damage_feedback(amount: int, center_position: Vector2):
	var floating_text_scene = preload("res://scenes/floating_text.tscn")
	var floating_text = floating_text_scene.instantiate()
	floating_text.text = str(amount)
	(floating_text as Label).label_settings.font_color = Color.WHITE
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
func take_damage(amount: float, from_position: Vector2, name: String) -> void:
	# Only let authority actually apply damage logic
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return

	print("Took ", amount, " damage")
	entity.health -= amount

	# Sync floating text on all peers
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
			Toast.add.rpc_id(int(name), "+10 Gold")
			get_parent().add_gold.rpc(name, 10)
		else:
			Toast.add("+10 Gold")
			get_parent().add_gold(name, 10)
		get_parent().add_kill(name, "bauble")

	sprite.material = shock_material
	await get_tree().create_timer(0.1).timeout
	sprite.material = normal_material

func update_sprite_direction(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			sprite.play("bauble-right")
		else:
			sprite.play("bauble-left")
	else:
		if dir.y > 0:
			sprite.play("bauble-down")
		else:
			sprite.play("bauble-up")

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

func shoot_at_player(target_pos: Vector2) -> void:
	var bullet = preload("res://scenes/bullet.tscn").instantiate()
	bullet.global_position = global_position
	bullet.direction = (target_pos - global_position).normalized()
	get_tree().current_scene.add_child(bullet)
