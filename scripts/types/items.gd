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
			player.heal(50)
	items.append(healing_potion)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(0.0, 0.0, 16.0, 16.0)
	var wooden_sword = Weapon.new(1, "Wooden Sword", atlas)
	wooden_sword.damage = 25.0
	wooden_sword.description = "A regular wooden sword."
	wooden_sword.type = "SWORD"
	wooden_sword.data = {
		"reach": 1.55
	}
	items.append(wooden_sword)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(16.0, 0.0, 16.0, 16.0)
	var hoodie = Armor.new(2, "T-Shirt", atlas)
	hoodie.description = "Doesn't give any benefits but looks nice!"
	hoodie.defense = 0.0
	hoodie.health = 0.0
	items.append(hoodie)

	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(48.0, 16.0, 16.0, 16.0)
	var strength_potion = Consumable.new(3, "Strength Potion", atlas)
	strength_potion.description = "Multiplies your damage by 2.5x for 30 seconds. 60 second cooldown."
	strength_potion.cooldown = true
	strength_potion.cooldown_seconds = 60.0
	strength_potion.infinite = false
	strength_potion.on_consume = func():
		var player = Man.get_player()
		if player != null:
			var strength = Effect.new("Strength", Color.from_rgba8(255, 69, 69), 30.0)
			player.add_status_effect(strength)
			Toast.add("You have Strength for 30 seconds.")
	items.append(strength_potion)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(112.0, 16.0, 16.0, 16.0)
	var daggers = Weapon.new(4, "Throwing Daggers", atlas)
	daggers.damage = 75.0
	daggers.description = "Click in any direction to throw daggers, however you have limited ammo."
	daggers.type = "THROWABLE"
	daggers.data = {
		"clip": 16,
		"reload_time": 2.15,
		"speed": 250.0,
		"texture": preload("res://assets/sprites/dagger.png")
	}
	items.append(daggers)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(96.0, 16.0, 16.0, 16.0)
	var boomerang = Weapon.new(5, "Boomerang", atlas)
	boomerang.damage = 25.0
	boomerang.description = "Click in any direction to throw boomerang."
	boomerang.type = "BOOMERANG"
	items.append(boomerang)
	
