extends Node

@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	get_tree().current_scene.add_child(preload("res://scenes/map.tscn").instantiate())

	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Main Menu"):
			child.queue_free()

	
@rpc("authority", "call_local", "reliable")
func end_game() -> void:
	get_tree().current_scene.add_child(preload("res://scenes/map.tscn").instantiate())

	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Game"):
			child.queue_free()

func get_player() -> Node2D:
	for player in get_tree().get_nodes_in_group("players"):
		if multiplayer.has_multiplayer_peer():
			if player.name == str(multiplayer.get_unique_id()):
				return player
		else:
			if player.name == "Player":
				return player
	return null
