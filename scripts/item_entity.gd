extends RigidBody2D

@export var attraction_radius: float = 20.0
@export var attraction_force: float = 90.0 

@export var merge_radius: float = 10.0
@export var merge_check_interval: float = 0.5

@export var PUSHBACK_DURATION: float = 0.5
@export var PUSHBACK_FORCE: float = 150.0
var pushback_timer: float = 0.0

var damping_factor = 2.0
var collectable: bool = false
var item: ItemStack

func _ready() -> void:
	Entities.add_entity(self)

func _exit_tree() -> void:
	Entities.remove_entity(self)

func set_item(item: ItemStack) -> void:
	self.item = item
	$Sprite2D.texture = item.type.texture

func _physics_process(delta: float) -> void:
	if item:
		$Label.text = "x" + str(item.amount) + " " + item.type.name
	if pushback_timer > 0:
		pushback_timer -= delta
		return
	
	if not collectable:
		return
		
	var players: Array[Node] = get_tree().get_nodes_in_group("players")

	if players.is_empty():
		linear_velocity = linear_velocity.lerp(Vector2.ZERO, delta * damping_factor)
		return

	var closest_player: Node = null
	var closest_distance: float = INF

	for player in players:
		var d = global_position.distance_to(player.global_position)
		if d < closest_distance and not player.bag.is_full():
			closest_distance = d
			closest_player = player

	if closest_player and closest_distance <= attraction_radius:
		var direction: Vector2 = (closest_player.global_position - global_position).normalized()
		linear_velocity = direction * attraction_force
	else:
		linear_velocity = Vector2.ZERO

func _on_body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int) -> void:
	if body.is_in_group("players"):
		print(body.bag.list)
		if not body.bag.is_full():
			print("Collided with player, emitting collect event.")
			Items.emit_signal("collect_item", item)
			queue_free()
		else:
			body.get_node("AudioStreamPlayer2D").volume_db = 5.0
			body.get_node("AudioStreamPlayer2D").stream = load("res://assets/sounds/error.wav")
			body.get_node("AudioStreamPlayer2D").play()
			Toast.add("Your inventory is full.")
			var direction = (global_position - body.global_position).normalized()
			apply_impulse(direction * PUSHBACK_FORCE)
			pushback_timer = PUSHBACK_DURATION


func check_for_merge():
	for other in get_tree().get_nodes_in_group("items"):
		if other == self:
			continue
		
		if other.item.type.id == item.type.id and global_position.distance_to(other.global_position) <= merge_radius:
			merge_with(other)
			break

func merge_with(other: Node):
	if other is RigidBody2D and other.has_method("set_item"):
		print("Merging items: ", item.type.id)
		item.amount += other.item.amount
		other.queue_free()
