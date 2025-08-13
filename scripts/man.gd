extends Node

@onready var main_menu_scene = preload("res://scenes/main_menu.tscn")
@onready var game_scene = preload("res://scenes/map.tscn")

var bag = Bag.new()
var equipped_weapon: Weapon = Items.get_by_id(1)
var game_loaded: bool = false

func load_game():
	game_loaded = true
	if not FileAccess.file_exists("user://game.mewo"):
		return
	var save_file = FileAccess.open("user://game.mewo", FileAccess.READ)
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			continue
		var data = json.get_data()
		if data.has("bag"):
			bag.set_list_from_save(data["bag"])
			if bag.list.is_empty():
				var wooden_sword = ItemStack.new(Items.get_by_id(1), 1)
		if data.has("equipped_weapon"):
			equipped_weapon = Items.get_by_id(data["equipped_weapon"])
	print("Loaded save data.")

func get_save_data() -> Dictionary:
	return {
		"bag": bag.to_list(),
		"equipped_weapon": equipped_weapon.id
	}

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if game_loaded:
			save_game("went to background")

func save_game(reason: String) -> void:
	var save_file = FileAccess.open("user://game.mewo", FileAccess.WRITE)
	save_file.store_line(JSON.stringify(get_save_data()))
	print("Saved the game. " + "(" + reason + ")")

func _ready() -> void:
	load_game()
	
@rpc("authority", "call_local", "reliable")
func start_game() -> void:
	get_tree().current_scene.add_child(game_scene.instantiate(), true)

	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Main Menu"):
			child.queue_free()

	
@rpc("authority", "call_local", "reliable")
func end_game() -> void:
	get_tree().current_scene.add_child(main_menu_scene.instantiate(), true)
	
	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Game") or child.name.begins_with("Main Menu"):
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
