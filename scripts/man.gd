extends Node

@onready var main_menu_scene: PackedScene = preload("res://scenes/main_menu.tscn")

var modes: Array[Variant] = ["Defense", "Dungeon"]
var maps: Dictionary[Variant, Variant] = {
	"defense": ["Lysawood", "Solmere"],
	"dungeon": ["Lysawood"],
	"campaign": ["Joro"]
}

var map_paths: Dictionary[Variant, Variant] = {
	"Defense_Lysawood": "res://scenes/levels/defense/Plains.tscn",
	"Defense_Solmere": "res://scenes/levels/defense/Desert.tscn",
	"Dungeon_Lysawood": "res://scenes/levels/dungeon/plains_start_room.tscn",
	"Campaign_Myrkwood": "res://scenes/levels/campaign/campaign.tscn"
}

var playtime_points: int = 0
var selected_mode: String = "Defense"
var selected_map: String  = "Lysawood"

var controls: Dictionary[Variant, Variant] = {
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
	KEY_ENTER: "Open chat",
	KEY_COMMA: "Zoom out",
	KEY_PERIOD: "Zoom in"
}

var fullscreen: bool = false
var sfx_volume: float = 100.0
var music_volume: float = 100.0
var bag = Bag.new()
var equipped_weapon: Weapon = Catalog.get_by_id(1)
var equipped_armor: Armor = Catalog.get_by_id(2)
var game_loaded: bool = false
var cooldowns: Dictionary[Variant, Variant] = {}

@rpc("authority", "call_local")
func add_playtime_points(amount: int) -> void:
	playtime_points += amount
	if playtime_points % 100 == 0:
		var options = []
		for item in Catalog.items:
			if (item is Weapon or item is Armor) and not bag.has_item(item):
				options.append(item)
				
		if not options.is_empty():
			var item = options.pick_random()
			bag.add_item(ItemStack.new(item, 1))
			Toast.add("You earned: " + item.name + "! Equip it in Loadout in the main menu.")

func set_rich_presence(token: String) -> void:
	if NetworkManager.steam_enabled:
		var setting_presence = Steam.setRichPresence("steam_display", token)
		print("Setting rich presence to "+str(token)+": "+str(setting_presence))
	else:
		print("Steam is not enabled, not running this.")
		
func set_rich_presence_value(key: String, token: String) -> void:
	if NetworkManager.steam_enabled:
		var setting_presence = Steam.setRichPresence(key, token)
		print("Setting rich presence value " + key + " to "+str(token)+": "+str(setting_presence))
	else:
		print("Steam is not enabled, not running this.")	

func start_cooldown(item, seconds: float) -> void:  # Accept both Consumable and Tossable
	cooldowns[item.id] = {
		"end_time": Time.get_ticks_msec() / 1000.0 + seconds
	}

func get_cooldown_left(item) -> float:  # Accept both Consumable and Tossable
	if not cooldowns.has(item.id):
		return 0.0
	var time_left = cooldowns[item.id]["end_time"] - Time.get_ticks_msec() / 1000.0
	return max(time_left, 0.0)

func is_on_cooldown(item) -> bool:  # Accept both Consumable and Tossable
	return get_cooldown_left(item) > 0.0

func take_screenshot() -> void:
	var img: Image  = get_viewport().get_texture().get_image()
	var dir: String        = "user://screenshots/"
	var dir_obj: DirAccess = DirAccess.open(dir)
	if dir_obj == null:
		DirAccess.make_dir_recursive_absolute(dir)
	var filename: String = Time.get_datetime_string_from_system().replace(":", "-")
	img.save_png(dir + filename + ".png")
	print("Screenshot saved to: ", filename)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == Key.KEY_BACKSLASH:
		take_screenshot()

func load_game():
	game_loaded = true
	if not FileAccess.file_exists("user://game.mewo"):
		return
	var save_file: FileAccess = FileAccess.open("user://game.mewo", FileAccess.READ)
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
			var wooden_sword = ItemStack.new(Catalog.get_by_id(1), 1)
			var t_shirt = ItemStack.new(Catalog.get_by_id(2), 1)
			if bag.list.is_empty():
				bag.add_item(wooden_sword)
				bag.add_item(t_shirt)
				Toast.add("Gave you a Wooden Sword & T-Shirt.")
			if not bag.has_item(Catalog.get_by_id(1)):
				bag.add_item(wooden_sword)
				Toast.add("Gave you a Wooden Sword.")
			if not bag.has_item(Catalog.get_by_id(2)):
				bag.add_item(t_shirt)
				Toast.add("Gave you a T-Shirt.")
				
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
				var db_value = lerp(-55.0, 0.0, sfx_volume / 100.0)
				AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db_value)
		if data.has("music_volume"):
			music_volume = data["music_volume"]
			if music_volume <= 0.0:
				AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
			else:
				AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)
				var db_value = lerp(-55.0, 0.0, music_volume / 100.0)
				AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db_value)
				
		if data.has("equipped_weapon"):
			equipped_weapon = Catalog.get_by_id(data["equipped_weapon"])
		if data.has("equipped_armor"):
			equipped_armor = Catalog.get_by_id(data["equipped_armor"])
		if data.has("playtime_points"):
			playtime_points = data["playtime_points"]
	print("Loaded save data.")

func get_save_data() -> Dictionary:
	return {
		"bag": bag.to_list(),
		"equipped_weapon": equipped_weapon.id,
		"equipped_armor": equipped_armor.id,
		"fullscreen": fullscreen,
		"playtime_points": playtime_points,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume
	}

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if game_loaded:
			save_game("went to background")

func save_game(reason: String) -> void:
	var save_file: FileAccess = FileAccess.open("user://game.mewo", FileAccess.WRITE)
	save_file.store_line(JSON.stringify(get_save_data()))
	print("Saved the game. " + "(" + reason + ")")

func _ready() -> void:
	load_game()
	var timer = Timer.new()
	timer.wait_time = 60.0
	timer.timeout.connect(_on_minute_passed)
	add_child(timer)
	timer.start()
	
func _on_minute_passed() -> void:
	add_playtime_points(5)
	
@rpc("authority", "call_local", "reliable")
func start_game(mode: String, map: String) -> void:
	await Fade.fade_out(0.25)
	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Main Menu") or child.name.begins_with("Defense") or child.name.begins_with("Dungeon"):
			child.queue_free()
	if Man.selected_mode == "Dungeon":
		get_tree().current_scene.add_child(load("res://scenes/levels/dungeon/dungeon.tscn").instantiate(), true)
		await Fade.fade_in(0.25)
		return
	get_tree().current_scene.add_child(load(map_paths[mode + "_" + map]).instantiate(), true)
	await Fade.fade_in(0.25)
	
@rpc("authority", "call_local", "reliable")
func end_game() -> void:	
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		if multiplayer.peer_connected.is_connected(NetworkManager._player_joined):
			multiplayer.peer_connected.disconnect(NetworkManager._player_joined)

		if multiplayer.peer_disconnected.is_connected(NetworkManager._player_quit):
			multiplayer.peer_disconnected.disconnect(NetworkManager._player_quit)
		NetworkManager.players.clear()

		if multiplayer.multiplayer_peer is EOSGMultiplayerPeer:
			multiplayer.multiplayer_peer.close()
		else:
			multiplayer.multiplayer_peer.disconnect_peer(multiplayer.multiplayer_peer.get_unique_id())
			multiplayer.multiplayer_peer = null
	await Fade.fade_out(0.25)
	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Defense") or child.name.begins_with("Main Menu") or child.name.begins_with("Dungeon"):
			child.queue_free()
	get_tree().current_scene.add_child(main_menu_scene.instantiate(), true)
	await Fade.fade_in(0.25)
	
func get_player() -> Node2D:
	for player in get_tree().get_nodes_in_group("players"):
		if multiplayer.has_multiplayer_peer():
			if player.name == str(multiplayer.get_unique_id()):
				return player
		else:
			if player.name == "Player":
				return player
	return null
