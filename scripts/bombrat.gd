extends CharacterBody2D

const SPEED = 4.0

@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var normal_material: Material = sprite.material
@onready var shock_material = preload("res://scenes/shock.tres")

var entity = Entity.new()

func _ready() -> void:
	entity.health = 500.0
	entity.max_health = 500.0
	entity.defense = 10.0
	entity.name = "Bombrat"
	entity.id = 1
	Entities.add_entity(entity)
	sprite.play("bombrat-down")

func die() -> void:
	collision.disabled = true
	Entities.remove_entity(entity)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(self, "queue_free"))

func explode() -> void:
	for body in $Hurtbox.get_overlapping_bodies():
		if body.is_in_group("gem"):
			body.take_damage(0.10)  # 10% damage
	die()

func _physics_process(delta: float) -> void:
	for body in $Hurtbox.get_overlapping_bodies():
		if body.is_in_group("gem"):
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

func show_floating_text(amount: int, center_position: Vector2):
	var floating_text_scene = preload("res://scenes/floating_text.tscn")
	var floating_text = floating_text_scene.instantiate()
	floating_text.text = str(amount)
	(floating_text as Label).label_settings.font_color = Color.WHITE
	get_parent().add_child(floating_text)

	var random_offset = Vector2(
		randi_range(-8, 8),
		randi_range(-8, 8)
	)
	floating_text.position = center_position + random_offset

func take_damage(amount: float, from_position: Vector2) -> void:
	print("Took ", amount, " damage")
	entity.health -= amount
	show_floating_text(amount, global_position)
	sprite.material = shock_material
	await get_tree().create_timer(0.1).timeout
	sprite.material = normal_material
	if entity.health <= 0:
		print("dead")
		die()

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
