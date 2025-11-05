extends Control

var item = null  # Can be Consumable or Tossable

func set_item(consumable) -> void:  # Accept both Consumable and Tossable
	item = consumable
	if item == null:
		$TextureRect.texture = null
		$Label.text = ""
		$ProgressBar.visible = false
		$Button.disabled = false
		return
	
	$TextureRect.texture = item.texture
	$ProgressBar.visible = item.cooldown

func _process(delta: float) -> void:
	if item == null:
		return

	var player = Man.get_player()
	var stack = player.bag.get_item_stack(item)

	var cooldown_left = Man.get_cooldown_left(item)
	var cooldown_active = cooldown_left > 0.0

	$Button.disabled = (not player.alive) or cooldown_active

	if stack != null:
		$Label.text = str(stack.amount) + "x"
		if item.cooldown:
			var percent = (cooldown_left / item.cooldown_seconds) * 100.0
			$ProgressBar.value = percent
			$ProgressBar.visible = cooldown_active
	else:
		set_item(null)


func _on_pressed() -> void:
	if item == null:
		return
	
	var player = Man.get_player()
	
	if not item.infinite:
		player.bag.take_item(item, 1)

	# Handle Consumable
	if item is Consumable:
		item.on_consume.call()
	
	# Handle Tossable
	elif item is Tossable:
		# Get spawn position (slightly in front of player based on facing direction)
		var spawn_pos = player.global_position
		if player.has_node("Marker2D"):  # If you have a spawn marker
			spawn_pos = player.get_node("Marker2D").global_position
		else:
			# Default: spawn a bit in front based on player's facing/direction
			var offset = Vector2(20, 0)  # Adjust as needed
			if player.has_method("get_facing_direction"):
				offset = player.get_facing_direction() * 20
			spawn_pos += offset
		
		# Spawn tossable (this should be done via RPC for multiplayer)
		if multiplayer.has_multiplayer_peer():
			_spawn_tossable.rpc(item.id, spawn_pos)
		else:
			_spawn_tossable(item.id, spawn_pos)

	if item.cooldown:
		Man.start_cooldown(item, item.cooldown_seconds)


@rpc("any_peer", "call_local", "reliable")
func _spawn_tossable(item_id: int, position: Vector2) -> void:
	# Get the item from the catalog
	var tossable_item = Catalog.get_by_id(item_id)
	if not tossable_item or not tossable_item is Tossable:
		return
	
	var tossable_scene = load("res://scenes/tossable.tscn")
	var entity = tossable_scene.instantiate()
	entity.global_position = position
	
	# Add to the current scene (world)
	get_tree().current_scene.add_child(entity, true)
	
	entity.setup_tossable(tossable_item)
