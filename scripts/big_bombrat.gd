extends CharacterBody2D

const SPEED = 5.0

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var normal_material: Material = sprite.material
@onready var shock_material = preload("res://scenes/shock.tres")

var alive: bool = true
var explosion_scene = preload("res://scenes/explosion.tscn")

var entity = Entity.new()

func _ready() -> void:
	entity.health = 550.0
	entity.max_health = 550.0
	entity.defense = 0.0
	entity.name = "Big Bombrat"
	entity.id = 4
	Entities.add_entity(entity)
	sprite.play("bombrat-down")

func die() -> void:
	$Hurtbox/CollisionShape2D.disabled = true
	Entities.remove_entity(entity)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(self, "queue_free"))

func explode() -> void:
	print("exploded")
	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	explosion.emitting = true
	$"..".add_child(explosion, true)
	for area in $Hurtbox.get_overlapping_areas():
		if area.is_in_group("gem"):
			area.take_damage(20.0)  # 10% damage
	die()

func _physics_process(delta: float) -> void:
	if (multiplayer.has_multiplayer_peer() and multiplayer.is_server()) or not multiplayer.has_multiplayer_peer():
		if entity != null:
			$ProgressBar.value = entity.health
			$ProgressBar.max_value = entity.max_health 
			if entity.health == entity.max_health:
				$ProgressBar.visible = false
			else:
				$ProgressBar.visible = true
	for area in $Hurtbox.get_overlapping_areas():
		if area.is_in_group("gem") and alive:
			print("found gem")
			explode()
			return

	var target = get_nearest_gem()
	if target:
		agent.target_position = target.global_position
		var next_pos = agent.get_next_path_position()
		var direction = (next_pos - global_position).normalized()
		velocity = direction * SPEED
		global_position += velocity * delta

		update_sprite_direction(velocity)

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
			Toast.add.rpc_id(int(name), "+20 Gold")
			get_parent().add_gold.rpc(name, 20)
		else:
			Toast.add("+20 Gold")
			get_parent().add_gold(name, 20)
		get_parent().add_kill(name, "big_bombrat")

	sprite.material = shock_material
	await get_tree().create_timer(0.1).timeout
	sprite.material = normal_material

func update_sprite_direction(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			sprite.play("bombrat-right")
		else:
			sprite.play("bombrat-left")
	else:
		if dir.y > 0:
			sprite.play("bombrat-down")
		else:
			sprite.play("bombrat-up")

func get_nearest_gem() -> Node2D:
	var gems: Array = get_tree().get_nodes_in_group("gem")
	var nearest: Node2D = null
	var nearest_distance: float = INF

	for gem in gems:
		if gem is Node2D:
			var dist = global_position.distance_squared_to(gem.global_position)
			if dist < nearest_distance:
				nearest_distance = dist
				nearest = gem
	return nearest
