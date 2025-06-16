extends CharacterBody2D

var directions = {
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT,
	"up": Vector2.UP,
	"down": Vector2.DOWN
}
var last_direction = "down"
const SWORD_HITBOX_TIME := 0.15
var sword_hitbox_timer := 0.0
var sword_hitbox_active := false
var hit_enemies = []
var knockback_velocity := Vector2.ZERO
var knockback_friction := 800.0
var hit_cooldown = 0.0
var max_hit_cooldown = 0.35

const SPEED = 95.0
var max_health = 100.0
var health = 100.0
var damage = 25
var strength = 0
var sword_reach := 1.4  # Base reach
var gold: int = 0

var bag = Bag.new()

@onready var bombrat_counter := $UI/Main/Board/Bombrats

func _enter_tree() -> void:
	if multiplayer.has_multiplayer_peer():
		set_multiplayer_authority(name.to_int())

func _ready() -> void:	
	if multiplayer.has_multiplayer_peer():
		set_multiplayer_authority(name.to_int())
		for player in NetworkManager.players:
			if player["id"] == name.to_int():
				$Username.text = player["username"]
		$Username.visible = true
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		$UI.visible = false
		$PointLight2D.visible = false
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		$Camera2D.make_current()

func take_damage(amount: float, location: Vector2 = Vector2.ZERO) -> void:
	if hit_cooldown > 0.0:
		return
	print("Player took ", amount, " damage")
	hit_cooldown = max_hit_cooldown
	health = health - amount
	apply_knockback(location, 220.0)
	show_floating_text(amount, global_position)
	if health <= 0:
		die()
	$AnimatedSprite2D.material = preload("res://scenes/shock.tres")
	await get_tree().create_timer(0.1).timeout
	$AnimatedSprite2D.material = null

func die() -> void:
	pass

func play_animation(name: String, backwards: bool = false, speed: float = 1) -> void:
	if backwards == false:
		$AnimatedSprite2D.play(name, speed)
	else:
		$AnimatedSprite2D.play(name, speed * -1, true)

func apply_knockback(from_position: Vector2, strength: float):
	var direction = (global_position - from_position).normalized()
	knockback_velocity = direction * strength

func play_idle_animation() -> void:
	play_animation("idle_" + last_direction)

func show_floating_text(amount: int, center_position: Vector2):
	var floating_text_scene = preload("res://scenes/floating_text.tscn")
	var floating_text = floating_text_scene.instantiate()
	floating_text.text = str(amount)
	(floating_text as Label).label_settings.font_color = Color.RED
	$"..".add_child(floating_text)

	var random_offset = Vector2(
		randi_range(-8, 8),
		randi_range(-8, 8)
	)
	floating_text.position = center_position + random_offset

func _process_input(delta) -> void:
	# Handle movement input
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	velocity = Input.get_vector("left", "right", "up", "down", 0.1)
	var velocity_length = velocity.length_squared()
	var is_moving = velocity_length > 0

	if is_moving:
		velocity_length = min(1, 0.5 + velocity_length)

		# Determine last movement direction
		if abs(velocity.x) > abs(velocity.y):
			if velocity.x > 0:
				last_direction = "right"
			else:
				last_direction = "left"
		else:
			if velocity.y > 0:
				last_direction = "down"
			else:
				last_direction = "up"

		# Only play walk animation if not currently attacking
		if not $AnimatedSprite2D.animation.begins_with("sword_"):
			play_animation("walk_" + last_direction, false, velocity_length)
	else:
		# If idle and not attacking, play idle animation
		if $AnimatedSprite2D.animation.begins_with("walk_"):
			play_idle_animation()

	# Handle sword attack
	if Input.is_action_just_pressed("attack"):
		play_animation("sword_" + last_direction)
		_enable_sword_hitbox(last_direction)
		sword_hitbox_timer = SWORD_HITBOX_TIME
		sword_hitbox_active = true

	# Apply velocity and move
	velocity *= SPEED
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	else:
		knockback_velocity = Vector2.ZERO
	
	move_and_slide()

func _enable_sword_hitbox(direction: String) -> void:
	var hitbox = $SwordHbox

	for child in hitbox.get_children():
		if child is CollisionShape2D:
			child.disabled = true

	if hitbox.has_node(direction):
		var shape_node = hitbox.get_node(direction)
		if shape_node is CollisionShape2D:
			shape_node.disabled = false

			var shape = shape_node.shape
			var reach_factor := sword_reach / 2.0

			if shape is RectangleShape2D:
				if direction == "up":
					shape.size = Vector2(58.0, 20.5 * reach_factor)
					shape_node.position = Vector2(0, -20 * reach_factor)

				elif direction == "down":
					shape.size = Vector2(58.0, 20.5 * reach_factor)
					shape_node.position = Vector2(0, 20 * reach_factor)

				elif direction == "left":
					shape.size = Vector2(20.5 * reach_factor, 58.0)
					shape_node.position = Vector2(-20 * reach_factor, 0)

				elif direction == "right":
					shape.size = Vector2(20.5 * reach_factor, 58.0)
					shape_node.position = Vector2(20 * reach_factor, 0)


func _disable_all_sword_hitboxes() -> void:
	for child in $SwordHbox.get_children():
		if child is CollisionShape2D:
			child.disabled = true

#func clamp_player_position(player_pos: Vector2) -> Vector2:
	#var half_width = get_parent().map_size.x / 2 * 16.0
	#var half_height = get_parent().map_size.y / 2 * 16.0
	#
	#player_pos.x = clamp(player_pos.x, -half_width, half_width)
	#player_pos.y = clamp(player_pos.y, -half_height, half_height)
	#return player_pos

func _physics_process(delta: float) -> void:
	#position = clamp_player_position(position)
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		$UI/Main/HealthBar.max_value = max_health
		$UI/Main/HealthBar.value = health
		$UI/Main/HealthBar/Label.text = str(roundi(health)) + "/" + str(roundi(max_health))
	hit_cooldown = max(hit_cooldown - delta, 0.0)
	_process_input(delta)
	if sword_hitbox_active:
		for body in $SwordHbox.get_overlapping_bodies():
			if body.is_in_group("enemies") and body not in hit_enemies:
				_process_hit(body)
				hit_enemies.append(body)
		
		sword_hitbox_timer -= delta
		if sword_hitbox_timer <= 0.0:
			sword_hitbox_active = false
			hit_enemies.clear()
			_disable_all_sword_hitboxes()
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.entity.id == 1:
			count += 1
	if count > 0:
		bombrat_counter.text = "Bombrats left: %d" % count

	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		$UI/Main/Board/Wave.text = "Wave: " + str(get_parent().wave)
		$UI/Main/Board/Gold.text = "Gold: " + str(gold)

func _animation_finished() -> void:
	if $AnimatedSprite2D.animation.begins_with("sword_"):
		play_idle_animation()

func _process_hit(body):
	print("processed hit")
	if body.is_in_group("enemies"):
		var damage_before_defense = damage * (1.0 + strength / 100.0)
		var defense = body.entity.defense
		var defense_factor = 1.0 - (defense / (defense + 100.0))
		var total_damage = damage_before_defense * defense_factor
		body.take_damage(total_damage, global_position)
	
