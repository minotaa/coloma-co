extends CharacterBody2D

const SHOOT_INTERVAL := 2.0
const SHOOT_DISTANCE := 256.0  # Only shoot if player is within this range
const RETREAT_DISTANCE := 100.0  # Try to maintain this distance from the player
const SPEED = 80.0


@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var normal_material: Material = sprite.material
@onready var shock_material = preload("res://scenes/shock.tres")

var alive: bool = true
var explosion_scene = preload("res://scenes/explosion.tscn")
var shoot_timer := 0.0

var entity = Entity.new()

func _ready() -> void:
	entity.health = 175.0
	entity.max_health = 175.0
	entity.defense = 0.0
	entity.name = "Bauble"
	entity.id = 2
	Entities.add_entity(entity)
	sprite.play("bauble-down")

func die() -> void:
	$Hurtbox/CollisionShape2D.disabled = true
	Entities.remove_entity(entity)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(self, "queue_free"))

func _physics_process(delta: float) -> void:
	if (multiplayer.has_multiplayer_peer() and multiplayer.is_server()) or not multiplayer.has_multiplayer_peer():
		if entity != null:
			$ProgressBar.value = entity.health
			$ProgressBar.max_value = entity.max_health 
			$ProgressBar.visible = entity.health < entity.max_health

		var player = get_nearest_player()
		if player:
			var to_player = player.global_position - global_position
			var dist_squared = to_player.length_squared()

			# If too close, retreat using navigation
			if dist_squared < RETREAT_DISTANCE * RETREAT_DISTANCE:
				var retreat_direction = -(to_player.normalized())
				var retreat_target = global_position + retreat_direction * 64.0  # Step back a little
				agent.target_position = retreat_target

				var next_position = agent.get_next_path_position()
				var direction = (next_position - global_position).normalized()
				velocity = direction * SPEED

				var collision = move_and_collide(velocity * delta)
				update_sprite_direction(velocity)
			else:
				velocity = Vector2.ZERO

			# Shooting
			#shoot_timer -= delta
			#if shoot_timer <= 0.0 and dist_to_player <= SHOOT_DISTANCE:
				#shoot_at_player(player.global_position)
				#shoot_timer = SHOOT_INTERVAL
	for body in $Hurtbox.get_overlapping_bodies():
		if body.is_in_group("players") and alive:
			body.take_damage(10, global_position)
			pass

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
