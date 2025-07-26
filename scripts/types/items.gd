extends Node

signal collect_item(item_type: ItemStack)

var items = []
var item_resource = preload("res://scenes/item.tscn")

func get_by_id(id: int) -> ItemType:
	for item in items:
		if item.id == id:
			return item
	return null
	
func spawn(item: ItemStack, location: Vector2) -> RigidBody2D:
	var item_object = item_resource.instantiate()
	item_object.set_item(item)
	item_object.global_position = location
	item_object.sleeping = false
	get_tree().current_scene.add_child(item_object)
	await get_tree().process_frame 
	
	var random_angle = randf_range(-PI, PI)
	var force_strength = randf_range(5, 10)
	var force_vector = Vector2.RIGHT.rotated(random_angle) * force_strength
	
	item_object.apply_impulse(force_vector)
	await get_tree().create_timer(0.5).timeout 
	if item_object == null:
		return null
	item_object.collectable = true
	return item_object
	
func _init() -> void:
	var atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(48.0, 0.0, 16.0, 16.0)
	var healing_potion = Consumable.new(0, "Healing Potion", atlas)
	healing_potion.description = "Heals +50 HP, 10 second cooldown."
	healing_potion.cooldown = true
	healing_potion.cooldown_seconds = 10.0
	healing_potion.infinite = false
	healing_potion.on_consume = func():
		var player = Man.get_player()
		if player != null:
			var heal_amount = min(50, player.max_health - player.health)
			player.health += heal_amount
			Toast.add("Healed +" + str(roundi(heal_amount)) + " HP!")

	items.append(healing_potion)
