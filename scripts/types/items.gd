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
	
#	atlas = AtlasTexture.new()
#	atlas.atlas = load("res://assets/sprites/items.png")
#	atlas.region = Rect2(80.0, 16.0, 16.0, 16.0)
#	var bombrat_shell = Consumable.new(1, "Bombrat Shell", atlas)
#	bombrat_shell.description = "A shell gathered from a bombrats, explodes causing 75 DMG to anything nearby."
#	bombrat_shell.cooldown = true
#	bombrat_shell.cooldown_seconds = 45.0
#	bombrat_shell.infinite = false
#	bombrat_shell.on_consume = func():
#		var explosion = load("res://scenes/explosion.tscn").instantiate()
#		explosion.global_position = Man.get_player().global_position
#		explosion.emitting = true
#		get_parent().add_child(explosion, true)
#		for enemy in Man.get_player().get_node("Area2D").get_overlapping_bodies():
#			if enemy.is_in_group("enemies"):
#				var damage_before_defense = 125
#				var defense = enemy.entity.defense
#				var defense_factor = 1.0 - (defense / (defense + 100.0))
#				var total_damage = damage_before_defense * defense_factor
#				var direction = enemy.global_position - Man.get_player().global_position
#				var midpoint = Man.get_player().global_position + direction * 0.5
#				var angle = direction.angle()
#				Man.get_player().damage_dealt += total_damage 
#				Man.get_player().total_damage_dealt += total_damage
#				if multiplayer.has_multiplayer_peer():
#					enemy.take_damage.rpc(total_damage, Man.get_player().global_position, Man.get_player().name)
#					Man.get_player().add_hit_particles.rpc(midpoint, angle)
#				else:
#					enemy.take_damage(total_damage, Man.get_player().global_position, Man.get_player().name)
#					Man.get_player().add_hit_particles(midpoint, angle)
#	items.append(bombrat_shell)
	
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
	atlas.region = Rect2(96.0, 16.0, 16.0, 16.0)
	var generic_boomerang = Weapon.new(2, "Wooden Boomerang", atlas)
	generic_boomerang.damage = 50.0
	generic_boomerang.description = "A regular wooden boomerang."
	generic_boomerang.type = "BOOMERANG"
	generic_boomerang.data = {
		"reach": 1.0
	}
	items.append(generic_boomerang)

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
