extends CharacterBody2D

const SPEED = 40
const HOP_INTERVAL = 0.6
const HOP_DURATION = 0.2
const HOP_HEIGHT = 6.0
const KNOCKBACK_DURATION := 0.1
const KNOCKBACK_SPEED := 200.0


@onready var agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var normal_material: Material = sprite.material
@onready var shock_material = preload("res://scenes/shock.tres")
@onready var collision: CollisionShape2D = $CollisionShape2D

var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_timer: float = 0.0
var hop_timer: float = 0.0
var is_hopping: bool = false
var hop_start_pos: Vector2
var hop_target_pos: Vector2
var hop_progress: float = 0.0

var entity = Entity.new()

func _ready() -> void:
	entity.health = 50.0
	entity.max_health = 50.0
	entity.defense = 0.0
	entity.name = "Slime"
	entity.id = 0
	Entities.add_entity(entity)
	sprite.play("default")

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
	var direction = (global_position - from_position).normalized()
	knockback_velocity = direction * KNOCKBACK_SPEED
	knockback_timer = KNOCKBACK_DURATION
	print("Took ", amount, " damage")
	entity.health -= amount
	show_floating_text(amount, global_position)
	sprite.material = shock_material
	await get_tree().create_timer(0.1).timeout
	sprite.material = normal_material
	if entity.health <= 0:
		print("dead")
		die()

func die() -> void:
	collision.disabled = true
	Entities.remove_entity(entity)
	sprite.play("default") 
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(self, "queue_free"))

func _physics_process(delta: float) -> void:
	for body in $Hurtbox.get_overlapping_bodies():
		if body.is_in_group("players"):
			body.take_damage(10, global_position)
			pass
	if knockback_timer > 0.0:
		# Apply knockback
		global_position += knockback_velocity * delta
		knockback_timer -= delta
		sprite.position.y = 0  # Reset vertical bobbing during knockback
		return  # Skip normal hopping behavior while knocked back

	if not is_hopping:
		hop_timer -= delta
		if hop_timer <= 0.0:
			var target = get_nearest_player()
			if target:
				agent.target_position = target.global_position
				
				hop_start_pos = global_position
				hop_target_pos = agent.get_next_path_position()
				hop_progress = 0.0
				is_hopping = true
	else:
		hop_progress += delta / HOP_DURATION
		if hop_progress >= 1.0:
			hop_progress = 1.0
			is_hopping = false
			hop_timer = HOP_INTERVAL

		var move_vec = hop_target_pos - hop_start_pos
		global_position = hop_start_pos + move_vec * hop_progress

	# Update vertical offset of sprite (hop arc)
	if is_hopping:
		var t = hop_progress
		var height = 4 * HOP_HEIGHT * t * (t - 1)  # Parabolic curve
		sprite.position.y = height
	else:
		sprite.position.y = 0


func get_nearest_player() -> Node2D:
	var players: Array = get_tree().get_nodes_in_group("players")
	var nearest: Node2D = null
	var nearest_distance: float = INF

	for player in players:
		if player is Node2D:
			var dist: float = global_position.distance_squared_to(player.global_position)
			if dist < nearest_distance:
				nearest_distance = dist
				nearest = player

	return nearest
