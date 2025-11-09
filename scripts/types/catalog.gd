extends Node

signal collect_item(item_type: ItemStack)

var items = []
var upgrades = []
var item_resource = preload("res://scenes/item.tscn")

func get_by_id(id: int) -> ItemType:
	for item in items:
		if item.id == id:
			return item
	for upgrade in upgrades:
		if upgrade.id == id:
			return upgrade
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
	healing_potion.purchasable = true
	healing_potion.price = 100
	healing_potion.shop_type = "ANY"
	healing_potion.cooldown_seconds = 10.0
	healing_potion.infinite = false
	healing_potion.on_consume = func():
		var player = Man.get_player()
		if player != null:
			player.heal(50)
			player.play_sfx("glug", player.global_position, 10.0)
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
	strength_potion.purchasable = true
	strength_potion.price = 500
	strength_potion.description = "Multiplies your damage by 2.5x for 30 seconds. 60 second cooldown."
	strength_potion.cooldown = true
	strength_potion.cooldown_seconds = 60.0
	strength_potion.infinite = false
	strength_potion.shop_type = "ANY"
	strength_potion.on_consume = func():
		var player = Man.get_player()
		if player != null:
			var strength = Effect.new("Strength", Color.from_rgba8(255, 145, 41, 255), 30.0)
			player.add_status_effect(strength)
			player.play_sfx("glug", player.global_position, 10.0)
			Toast.add("You have Strength for 30 seconds.")
	items.append(strength_potion)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(112.0, 16.0, 16.0, 16.0)
	var daggers = Weapon.new(4, "Throwing Daggers", atlas)
	daggers.damage = 45.0
	daggers.description = "Click in any direction to throw daggers, however you have limited ammo."
	daggers.type = "THROWABLE"
	daggers.data = {
		"clip": 16,
		"reload_time": 2.0,
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
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(16.0, 16.0, 16.0, 16.0)
	var mini_strength_potion = Consumable.new(6, "Mini Strength Potion", atlas)
	mini_strength_potion.description = "Multiplies your damage by 2.5x for 15 seconds. 30 second cooldown."
	mini_strength_potion.cooldown = true
	mini_strength_potion.purchasable = true
	mini_strength_potion.shop_type = "ANY"
	mini_strength_potion.price = 250
	mini_strength_potion.cooldown_seconds = 30.0
	mini_strength_potion.infinite = false
	mini_strength_potion.on_consume = func():
		var player = Man.get_player()
		if player != null:
			var strength = Effect.new("Strength", Color.from_rgba8(255, 145, 41, 255), 15.0)
			player.add_status_effect(strength)
			player.play_sfx("glug", player.global_position, 10.0)
			Toast.add("You have Strength for 15 seconds.")
	items.append(mini_strength_potion)

	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(96.0, 0.0, 16.0, 16.0)
	var mini_healing_potion = Consumable.new(7, "Mini Healing Potion", atlas)
	mini_healing_potion.description = "Heals +25 HP, 5 second cooldown."
	mini_healing_potion.cooldown = true
	mini_healing_potion.purchasable = true
	mini_healing_potion.price = 50
	mini_healing_potion.shop_type = "ANY"
	mini_healing_potion.cooldown_seconds = 5.0
	mini_healing_potion.infinite = false
	mini_healing_potion.on_consume = func():
		var player = Man.get_player()
		if player != null:
			player.heal(25)
			player.play_sfx("glug", player.global_position, 10.0)
	items.append(mini_healing_potion)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(128.0, 16.0, 16.0, 16.0)
	var damage_upgrade = Upgrade.new(8, "Damage Upgrade", atlas)
	damage_upgrade.description = "Upgrade the damage of your weapon by 10."
	damage_upgrade.max_level = 10 
	damage_upgrade.purchasable = true 
	damage_upgrade.price = 1000
	damage_upgrade.shop_type = "ANY"
	upgrades.append(damage_upgrade)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(144.0, 16.0, 16.0, 16.0)
	var defense_upgrade = Upgrade.new(9, "Defense Upgrade", atlas)
	defense_upgrade.description = "Upgrade your defense by 5."
	defense_upgrade.max_level = 5
	defense_upgrade.purchasable = true 
	defense_upgrade.price = 750
	defense_upgrade.shop_type = "ANY"
	upgrades.append(defense_upgrade)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(160.0, 16.0, 16.0, 16.0)
	var health_upgrade = Upgrade.new(10, "Health Upgrade", atlas)
	health_upgrade.description = "Upgrade your health by 10."
	health_upgrade.max_level = 10
	health_upgrade.purchasable = true 
	health_upgrade.price = 850
	health_upgrade.shop_type = "ANY"
	upgrades.append(health_upgrade)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(192.2, 16.0, 16.0, 16.0)
	var pajamas = Armor.new(11, "Pajamas", atlas)
	pajamas.description = "Has a 20% chance to block any damage."
	pajamas.health = -20
	items.append(pajamas)

	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(208.0, 16.0, 16.0, 16.0)
	var blunderbuss = Weapon.new(12, "Blunderbuss", atlas)
	blunderbuss.damage = 15.0
	blunderbuss.description = "Does pitiful damage from far away but is devastating up close."
	blunderbuss.type = "BLUNDERBUSS"
	blunderbuss.data = {
		"clip": 4,
		"reload_time": 1.0,
		"speed": 350.0,
		"texture": preload("res://assets/sprites/bullet.png")
	}
	items.append(blunderbuss)

	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(224.0, 16.0, 16.0, 16.0)
	var dealmaker = Armor.new(13, "Dealmaker", atlas)
	dealmaker.description = "Grants 50% more gold."
	dealmaker.defense = 5.0
	dealmaker.health = 10.0
	items.append(dealmaker)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(240.0, 16.0, 16.0, 16.0)
	var vampire_fangs = Armor.new(14, "Vampire Fangs", atlas)
	vampire_fangs.description = "Grants HP upon killing an enemy."
	vampire_fangs.defense = -35.0
	vampire_fangs.health = 50.0
	items.append(vampire_fangs)

	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(0.0, 32.0, 16.0, 16.0)
	var enrichment_potion = Consumable.new(15, "Enrichment Potion", atlas)
	enrichment_potion.description = "Heals +100 HP over time, 15 second cooldown."
	enrichment_potion.cooldown = true
	enrichment_potion.purchasable = true
	enrichment_potion.price = 200
	enrichment_potion.shop_type = "ANY"
	enrichment_potion.cooldown_seconds = 15.0
	enrichment_potion.infinite = false
	enrichment_potion.on_consume = func():
		var player = Man.get_player()
		if player != null:
			var regeneration = Effect.new("Enrichment", Color.from_rgba8(56, 177, 67, 255), 10.0, 0, 1)
			regeneration.on_effect = func(target):
				target.heal(5)
			player.add_status_effect(regeneration)
			player.play_sfx("glug", player.global_position, 20.0)
			Toast.add("You have Enrichment for 20 seconds.")
	items.append(enrichment_potion)

	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(16.0, 32.0, 16.0, 16.0)
	var mini_enrichment_potion = Consumable.new(16, "Mini Enrichment Potion", atlas)
	mini_enrichment_potion.description = "Heals +50 HP over time, 7.5 second cooldown."
	mini_enrichment_potion.cooldown = true
	mini_enrichment_potion.purchasable = true
	mini_enrichment_potion.price = 100
	mini_enrichment_potion.shop_type = "ANY"
	mini_enrichment_potion.cooldown_seconds = 7.5
	mini_enrichment_potion.infinite = false
	mini_enrichment_potion.on_consume = func():
		var player = Man.get_player()
		if player != null:
			var regeneration = Effect.new("Regeneration", Color.from_rgba8(56, 177, 67, 255), 10.0, 0, 1)
			regeneration.on_effect = func(target):
				target.heal(5)
			player.add_status_effect(regeneration)
			player.play_sfx("glug", player.global_position, 10.0)
			Toast.add("You have Regeneration for 10 seconds.")
	items.append(mini_enrichment_potion)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(32.0, 32.0, 16.0, 16.0)
	var focus_potion = Consumable.new(17, "Focus Potion", atlas)
	focus_potion.description = "Increases your critical hit chance by +50% for 30 seconds."
	focus_potion.cooldown = true
	focus_potion.purchasable = true
	focus_potion.price = 125
	focus_potion.shop_type = "ANY"
	focus_potion.cooldown_seconds = 20.0
	focus_potion.infinite = false
	focus_potion.on_consume = func():
		var player = Man.get_player()
		if player != null:
			var focus = Effect.new("Focus", Color.from_rgba8(73, 209, 205, 255), 30.0, 0, 1)
			player.add_status_effect(focus)
			player.play_sfx("glug", player.global_position, 10.0)
			Toast.add("You have Focus for 30 seconds.")
	items.append(focus_potion)

	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(48.0, 32.0, 16.0, 16.0)
	var mini_focus_potion = Consumable.new(18, "Mini Focus Potion", atlas)
	mini_focus_potion.description = "Increases your critical hit chance by +50% for 15 seconds."
	mini_focus_potion.cooldown = true
	mini_focus_potion.purchasable = true
	mini_focus_potion.price = 75
	mini_focus_potion.shop_type = "ANY"
	mini_focus_potion.cooldown_seconds = 30.0
	mini_focus_potion.infinite = false
	mini_focus_potion.on_consume = func():
		var player = Man.get_player()
		if player != null:
			var focus = Effect.new("Focus", Color.from_rgba8(73, 209, 205, 255), 15.0, 0, 1)
			player.add_status_effect(focus)
			player.play_sfx("glug", player.global_position, 10.0)
			Toast.add("You have Focus for 15 seconds.")
	items.append(mini_focus_potion)

	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(64.0, 32.0, 16.0, 16.0)
	var lucky_apple = Consumable.new(19, "Lucky Apple", atlas)
	lucky_apple.description = "Increases your Gold gain by 50% for 60 seconds."
	lucky_apple.cooldown = true
	lucky_apple.purchasable = true
	lucky_apple.price = 200
	lucky_apple.shop_type = "ANY"
	lucky_apple.cooldown_seconds = 5.0
	lucky_apple.infinite = false
	lucky_apple.on_consume = func():
		var player = Man.get_player()
		if player != null:
			var prosperous = Effect.new("Prosperity", Color.from_rgba8(255, 222, 45, 255), 60.0, 0, 1)
			player.add_status_effect(prosperous)
			player.play_sfx("glug", player.global_position, 10.0)
			Toast.add("You have Prosperity for 60 seconds.")
	items.append(lucky_apple)

	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(80.0, 32.0, 16.0, 16.0)
	var overheal_potion = Consumable.new(20, "Overheal Potion", atlas)
	overheal_potion.description = "Adds 50 Overheal HP."
	overheal_potion.cooldown = true
	overheal_potion.purchasable = true
	overheal_potion.price = 500
	overheal_potion.shop_type = "ANY"
	overheal_potion.cooldown_seconds = 20.0
	overheal_potion.infinite = false
	overheal_potion.on_consume = func():
		var player = Man.get_player()
		if player != null:
			player.overheal = min(player.overheal + 50.0, player.get_max_overheal())
			player.play_sfx("glug", player.global_position, 10.0)
			Toast.add("You just got 50 Overheal HP.")
	items.append(overheal_potion)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(96.0, 32.0, 16.0, 16.0)
	var mini_overheal_potion = Consumable.new(21, "Mini Overheal Potion", atlas)
	mini_overheal_potion.description = "Adds 25 Overheal HP."
	mini_overheal_potion.cooldown = true
	mini_overheal_potion.purchasable = true
	mini_overheal_potion.price = 250
	mini_overheal_potion.shop_type = "ANY"
	mini_overheal_potion.cooldown_seconds = 20.0
	mini_overheal_potion.infinite = false
	mini_overheal_potion.on_consume = func():
		var player = Man.get_player()
		if player != null:
			player.overheal = min(player.overheal + 25.0, player.get_max_overheal())
			player.play_sfx("glug", player.global_position, 10.0)
			Toast.add("You just got 25 Overheal HP.")
	items.append(mini_overheal_potion)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(112.0, 32.0, 16.0, 16.0)
	var healing_totem = Tossable.new(22, "Healing Totem", atlas)
	healing_totem.description = "Heals anyone in its radius. Active for 60 seconds."
	healing_totem.cooldown = true
	healing_totem.purchasable = true
	healing_totem.price = 500
	healing_totem.shop_type = "ANY"
	healing_totem.cooldown_seconds = 60.0
	healing_totem.duration = 60.0
	healing_totem.infinite = false
	healing_totem.update_interval = 3.0

	var heal_range = 60.0
	var heal_amount = 5.0

	healing_totem.on_toss = func(target, location):
		pass

	healing_totem.on_update = func(target, location):
		var pulse = preload("res://scenes/pulse.tscn").instantiate()
		pulse.process_material.color = Color.from_rgba8(56, 177, 67, 255)
		pulse.emitting = true
		target.add_child(pulse)
		print("Healing totem update called at: ", location)
		var space_state = target.get_world_2d().direct_space_state
		var query = PhysicsShapeQueryParameters2D.new()
		var shape = CircleShape2D.new()
		shape.radius = heal_range
		query.shape = shape
		query.transform = Transform2D(0, location)
		query.collision_mask = 1
		
		var results = space_state.intersect_shape(query)
		print("Found ", results.size(), " objects in range")
		for result in results:
			var body = result.collider
			print("Found body: ", body.name, " - has heal method: ", body.has_method("heal"))
			if body.has_method("heal"):
				body.heal(heal_amount)
				print("Healed ", body.name, " for ", heal_amount)
				
	healing_totem.on_end = func(target, location):
		pass # Totem expires

	items.append(healing_totem)

	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(128.0, 32.0, 16.0, 16.0)  # Adjust region for wind totem sprite
	var wind_totem = Tossable.new(23, "Wind Totem", atlas)
	wind_totem.description = "Blows enemies away from its radius. Active for 30 seconds."
	wind_totem.cooldown = true
	wind_totem.purchasable = true
	wind_totem.price = 800
	wind_totem.shop_type = "ANY"
	wind_totem.cooldown_seconds = 45.0
	wind_totem.duration = 30.0
	wind_totem.infinite = false
	wind_totem.update_interval = 1.0  # Pushes every second

	var wind_range = 80.0
	var knockback_force = 80.0

	wind_totem.on_toss = func(target, location):
		pass

	wind_totem.on_update = func(target, location):
		var pulse = preload("res://scenes/pulse.tscn").instantiate()
		pulse.process_material.color = Color.from_rgba8(200, 230, 255, 255)  # Light blue/cyan for wind
		pulse.emitting = true
		target.add_child(pulse)
		
		var space_state = target.get_world_2d().direct_space_state
		var query = PhysicsShapeQueryParameters2D.new()
		var shape = CircleShape2D.new()
		shape.radius = wind_range
		query.shape = shape
		query.transform = Transform2D(0, location)
		query.collision_mask = 2  # Assuming enemies are on layer 2 (bit 1)
		
		var results = space_state.intersect_shape(query)
		for result in results:
			var body = result.collider
			if body.has_method("apply_knockback") or body is CharacterBody2D:
				# Calculate direction away from totem
				var direction = (body.global_position - location).normalized()
				
				# Apply knockback
				if body.has_method("apply_knockback"):
					body.apply_knockback(location, knockback_force)
				elif body is CharacterBody2D:
					# Fallback: directly push the velocity
					body.velocity += direction * knockback_force
				
				print("Pushed ", body.name, " away with force ", knockback_force)
				
	wind_totem.on_end = func(target, location):
		pass  # Totem expires

	items.append(wind_totem)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(144.0, 32.0, 16.0, 16.0)  # Adjust region for strength totem sprite
	var strength_totem = Tossable.new(24, "Strength Totem", atlas)
	strength_totem.description = "Grants Strength to allies in its radius. Active for 30 seconds."
	strength_totem.cooldown = true
	strength_totem.purchasable = true
	strength_totem.price = 600
	strength_totem.shop_type = "ANY"
	strength_totem.cooldown_seconds = 60.0
	strength_totem.duration = 45.0
	strength_totem.infinite = false
	strength_totem.update_interval = 5.0  # Apply strength every 5 seconds

	var strength_range = 80.0

	strength_totem.on_toss = func(target, location):
		pass

	strength_totem.on_update = func(target, location):
		var pulse = preload("res://scenes/pulse.tscn").instantiate()
		pulse.process_material.color = Color.from_rgba8(255, 145, 41, 255)  # Orange for strength
		pulse.emitting = true
		target.add_child(pulse)
		
		var space_state = target.get_world_2d().direct_space_state
		var query = PhysicsShapeQueryParameters2D.new()
		var shape = CircleShape2D.new()
		shape.radius = strength_range
		query.shape = shape
		query.transform = Transform2D(0, location)
		query.collision_mask = 1  # Players layer
		
		var results = space_state.intersect_shape(query)
		for result in results:
			var body = result.collider
			if body.has_method("add_status_effect"):
				var strength = Effect.new("Strength", Color.from_rgba8(255, 145, 41, 255), 5.0)
				body.add_status_effect(strength)
				print("Applied Strength effect to ", body.name)
				
	strength_totem.on_end = func(target, location):
		pass  # Totem expires
	items.append(strength_totem)

	# ID 25 - Crit Boost I-III
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(160.0, 32.0, 16.0, 16.0)
	var crit_boost = Upgrade.new(25, "Crit Boost", atlas)
	crit_boost.description = "Increase your critical hit chance by 5%."
	crit_boost.max_level = 3
	crit_boost.purchasable = true
	crit_boost.price = 950
	crit_boost.shop_type = "ANY"
	upgrades.append(crit_boost)

	# ID 26 - Lifesteal Boost I-V
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(176.0, 32.0, 16.0, 16.0)
	var lifesteal_boost = Upgrade.new(26, "Lifesteal Boost", atlas)
	lifesteal_boost.description = "Adds on-kill lifesteal. With Vampire Fangs, adds on-hit lifesteal instead."
	lifesteal_boost.max_level = 5
	lifesteal_boost.purchasable = true
	lifesteal_boost.price = 1000
	lifesteal_boost.shop_type = "ANY"
	upgrades.append(lifesteal_boost)

	# ID 27 - Piercing I-V
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(192.0, 32.0, 16.0, 16.0)
	var piercing = Upgrade.new(27, "Piercing", atlas)
	piercing.description = "Your attacks ignore a portion of enemy defense."
	piercing.max_level = 5
	piercing.purchasable = true
	piercing.price = 1000
	piercing.shop_type = "ANY"
	upgrades.append(piercing)

	# ID 28 - Slow on Hit I-III
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(208.0, 32.0, 16.0, 16.0)
	var slow_on_hit = Upgrade.new(28, "Slow on Hit", atlas)
	slow_on_hit.description = "Chance to apply Gunked status to enemies when hitting them."
	slow_on_hit.max_level = 3
	slow_on_hit.purchasable = true
	slow_on_hit.price = 1250
	slow_on_hit.shop_type = "ANY"
	upgrades.append(slow_on_hit)

	# ID 29 - Overheal Increase I-III
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(224.0, 32.0, 16.0, 16.0)
	var overheal_increase = Upgrade.new(29, "Overheal Increase", atlas)
	overheal_increase.description = "Increase your maximum overheal capacity."
	overheal_increase.max_level = 3
	overheal_increase.purchasable = true
	overheal_increase.price = 850
	overheal_increase.shop_type = "ANY"
	upgrades.append(overheal_increase)

	# ID 30 - Damage Reflection I-V
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(240.0, 32.0, 16.0, 16.0)
	var damage_reflection = Upgrade.new(30, "Damage Reflection", atlas)
	damage_reflection.description = "Chance to reflect damage back to attackers. Enhanced by Cactus Armor."
	damage_reflection.max_level = 5
	damage_reflection.purchasable = true
	damage_reflection.price = 1000
	damage_reflection.shop_type = "ANY"
	upgrades.append(damage_reflection)

	# ID 31 - Dodge I-V
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(0.0, 48.0, 16.0, 16.0)
	var dodge = Upgrade.new(31, "Dodge", atlas)
	dodge.description = "Chance to completely avoid incoming damage. Enhanced by Pajamas."
	dodge.max_level = 5
	dodge.purchasable = true
	dodge.price = 1250
	dodge.shop_type = "ANY"
	upgrades.append(dodge)

	# ID 32 - Berserk I-III
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(16.0, 48.0, 16.0, 16.0)
	var berserk = Upgrade.new(32, "Berserk", atlas)
	berserk.description = "When low on health, increase your attack and critical damage."
	berserk.max_level = 3
	berserk.purchasable = true
	berserk.price = 1000
	berserk.shop_type = "ANY"
	upgrades.append(berserk)

	# ID 33 - Swiftness I-III
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(32.0, 48.0, 16.0, 16.0)
	var swiftness = Upgrade.new(33, "Swiftness", atlas)
	swiftness.description = "Increase your movement speed."
	swiftness.max_level = 3
	swiftness.purchasable = true
	swiftness.price = 500
	swiftness.shop_type = "ANY"
	upgrades.append(swiftness)

	# ID 34 - Cooldown Reduction I-V
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(48.0, 48.0, 16.0, 16.0)
	var cooldown_reduction = Upgrade.new(34, "Cooldown Reduction", atlas)
	cooldown_reduction.description = "Decrease cooldown time on consumables."
	cooldown_reduction.max_level = 5
	cooldown_reduction.purchasable = true
	cooldown_reduction.price = 750
	cooldown_reduction.shop_type = "ANY"
	upgrades.append(cooldown_reduction)

	# ID 35 - Extra Inventory Slot I
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(64.0, 48.0, 16.0, 16.0)
	var extra_inventory = Upgrade.new(35, "Extra Inventory Slot", atlas)
	extra_inventory.description = "Adds an additional inventory slot."
	extra_inventory.max_level = 1
	extra_inventory.purchasable = true
	extra_inventory.price = 1500
	extra_inventory.shop_type = "ANY"
	upgrades.append(extra_inventory)

	# ID 36 - Potion Amplifier I-II
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(80.0, 48.0, 16.0, 16.0)
	var potion_amplifier = Upgrade.new(36, "Potion Amplifier", atlas)
	potion_amplifier.description = "Potions are 15% more effective."
	potion_amplifier.max_level = 2
	potion_amplifier.purchasable = true
	potion_amplifier.price = 800
	potion_amplifier.shop_type = "ANY"
	upgrades.append(potion_amplifier)

	# ID 37 - Gold from Combat I-III
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(96.0, 48.0, 16.0, 16.0)
	var gold_from_combat = Upgrade.new(37, "Gold from Combat", atlas)
	gold_from_combat.description = "Gain more gold from killing enemies. Dealmaker changes this to on-hit."
	gold_from_combat.max_level = 3
	gold_from_combat.purchasable = true
	gold_from_combat.price = 1000
	gold_from_combat.shop_type = "ANY"
	upgrades.append(gold_from_combat)

	# ID 38 - Rabid I
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(112.0, 48.0, 16.0, 16.0)
	var rabid = Upgrade.new(38, "Rabid", atlas)
	rabid.description = "Gain a guaranteed critical hit after each kill."
	rabid.max_level = 1
	rabid.purchasable = true
	rabid.price = 1250
	rabid.shop_type = "ANY"
	upgrades.append(rabid)

	# ID 39 - Chain Hits I-IV
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(128.0, 48.0, 16.0, 16.0)
	var chain_hits = Upgrade.new(39, "Chain Hits", atlas)
	chain_hits.description = "Consecutive hits on the same enemy reduce their defense."
	chain_hits.max_level = 4
	chain_hits.purchasable = true
	chain_hits.price = 1000
	chain_hits.shop_type = "ANY"
	upgrades.append(chain_hits)

	# ID 40 - Overdrive I
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(144.0, 48.0, 16.0, 16.0)
	var overdrive = Upgrade.new(40, "Overdrive", atlas)
	overdrive.description = "Increase damage at full health, but lower your defense."
	overdrive.max_level = 1
	overdrive.purchasable = true
	overdrive.price = 1500
	overdrive.shop_type = "ANY"
	upgrades.append(overdrive)

	# ID 41 - Natural Regeneration I-III
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(160.0, 48.0, 16.0, 16.0)
	var natural_regen = Upgrade.new(41, "Natural Regeneration", atlas)
	natural_regen.description = "Slowly heal 3% HP every 10 seconds."
	natural_regen.max_level = 3
	natural_regen.purchasable = true
	natural_regen.price = 1000
	natural_regen.shop_type = "ANY"
	upgrades.append(natural_regen)
	
	atlas = AtlasTexture.new()
	atlas.atlas = load("res://assets/sprites/items.png")
	atlas.region = Rect2(176.0, 48.0, 16.0, 16.0)
	var joros_blessing = Consumable.new(42, "Joro's Blessing", atlas)
	joros_blessing.description = "10 seconds of complete invulnerability."
	joros_blessing.cooldown = true
	joros_blessing.purchasable = true
	joros_blessing.price = 500
	joros_blessing.shop_type = "ANY"
	joros_blessing.cooldown_seconds = 60.0
	joros_blessing.infinite = false
	joros_blessing.on_consume = func():
		var player = Man.get_player()
		if player != null:
			var invulnerability = Effect.new("Invulnerability", Color.from_rgba8(227, 227, 227, 255), 10.0, 0, 1)
			player.add_status_effect(invulnerability)
			player.play_sfx("glug", player.global_position, 10.0)
			Toast.add("You have Invulnerability for 10 seconds.")
	items.append(joros_blessing)
