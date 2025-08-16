extends Node

@onready var main_menu_scene = preload("res://scenes/main_menu.tscn")
@onready var game_scene = preload("res://scenes/map.tscn")

var controls = {
	KEY_W: "Move forward",
	KEY_A: "Move left",
	KEY_S: "Move backward",
	KEY_D: "Move right",
	KEY_E: "Interact",
	"MOUSE_BUTTON_LEFT": "Attack",
	KEY_UP: "Attack up",
	KEY_LEFT: "Attack left",
	KEY_DOWN: "Attack down",
	KEY_RIGHT: "Attack right",
	KEY_TAB: "View info",
	KEY_SHIFT: "Sprint",
	KEY_1: "1st Inventory Slot",
	KEY_2: "2nd Inventory Slot",
	KEY_3: "3rd Inventory Slot",
	KEY_COMMA: "Zoom out",
	KEY_PERIOD: "Zoom in"
}

var fullscreen: bool = false
var sfx_volume: float = 100.0
var bag = Bag.new()
var equipped_weapon: Weapon = Items.get_by_id(1)
var game_loaded: bool = false
var cooldowns = {}

func start_cooldown(item: Consumable, seconds: float) -> void:
	cooldowns[item.id] = {
		"end_time": Time.get_ticks_msec() / 1000.0 + seconds
	}

func get_cooldown_left(item: Consumable) -> float:
	if not cooldowns.has(item.id):
		return 0.0
	var time_left = cooldowns[item.id]["end_time"] - Time.get_ticks_msec() / 1000.0
	return max(time_left, 0.0)

func is_on_cooldown(item: Consumable) -> bool:
	return get_cooldown_left(item) > 0.0

func take_screenshot() -> void:
	var img: Image = get_viewport().get_texture().get_image()
	var dir = "user://screenshots/"
	var dir_obj = DirAccess.open(dir)
	if dir_obj == null:
		DirAccess.make_dir_recursive_absolute(dir)
	var filename = Time.get_datetime_string_from_system().replace(":", "-")
	img.save_png(dir + filename + ".png")
	print("Screenshot saved to: ", filename)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == Key.KEY_BACKSLASH:
		take_screenshot()

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
		if data.has("fullscreen"):
			var mode: int = 0
			if data["fullscreen"]:
				mode = 3
			fullscreen = data["fullscreen"]
			DisplayServer.window_set_mode(mode)
		if data.has("sfx_volume"):
			sfx_volume = data["sfx_volume"]
			if sfx_volume <= 0.0:
				AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), true)
			else:
				AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), false)
				var db_value = lerp(-80.0, 0.0, sfx_volume / 100.0)
				AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db_value)
		if data.has("equipped_weapon"):
			equipped_weapon = Items.get_by_id(data["equipped_weapon"])
	print("Loaded save data.")

func get_save_data() -> Dictionary:
	return {
		"bag": bag.to_list(),
		"equipped_weapon": equipped_weapon.id,
		"fullscreen": fullscreen
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
	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Main Menu") or child.name.begins_with("Game"):
			child.queue_free()
	get_tree().current_scene.add_child(game_scene.instantiate(), true)
	
@rpc("authority", "call_local", "reliable")
func end_game() -> void:	
	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Game") or child.name.begins_with("Main Menu"):
			child.queue_free()
	get_tree().current_scene.add_child(main_menu_scene.instantiate(), true)
	
func get_player() -> Node2D:
	for player in get_tree().get_nodes_in_group("players"):
		if multiplayer.has_multiplayer_peer():
			if player.name == str(multiplayer.get_unique_id()):
				return player
		else:
			if player.name == "Player":
				return player
	return null
