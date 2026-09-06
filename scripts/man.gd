extends Node

@onready var main_menu_scene: PackedScene = preload("res://scenes/main_menu.tscn")

var modes: Array[Variant] = ["Defense", "Dungeons"]
var explanations: Dictionary[String, String] = {
	"Defense": "Fight off enemies in this wave-based defense mode, building up coins and acquiring perks to help you as the waves get harder! How long will you last?",
	"Dungeons": "Explore procedurally generated dungeons, going through various rooms and visiting shops to get new items. How far can you make it?",
	"Tutorial": "Learn how to play the game."
}
var maps: Dictionary[Variant, Variant] = {
	"defense": ["Lysawood", "Solmere"],
	"dungeons": ["Lysawood", "Solmere"],
	"campaign": ["Joro"]
}
var dont_do_this_again: bool = false

var map_paths: Dictionary[Variant, Variant] = {
	"Defense_Lysawood": "res://scenes/levels/defense/Plains.tscn",
	"Defense_Solmere": "res://scenes/levels/defense/Desert.tscn",
	"Dungeons_Lysawood": "res://scenes/levels/dungeon/dungeon.tscn",
	"Dungeons_Solmere": "res://scenes/levels/dungeon/dungeon.tscn"
	#"Campaign_Myrkwood": "res://scenes/levels/campaign/campaign.tscn" # Unused
}

var achievements: Dictionary[String, bool] = {
	"COMPLETE_BESTIARY_HALFWAY": false,
	"COMPLETE_BESTIARY_FULL": false,
	"WAVE_30": false,
	"WAVE_50": false,
	"ROOM_30": false,
	"ROOM_50": false,
	"DEFEAT_BOMBRAT_KING": false,
	"COMPLETE_TUTORIAL": false,
	"GET_ALL_ARMOR": false,
	"GET_ALL_WEAPON": false,
	"GET_ALL_WEAPONS_ARMOR": false,
	"KILL_10_000": false,
	"KILL_25_000": false,
	"KILL_50_000": false,
	"KILL_100_000": false,
	"LEVEL_5": false,
	"LEVEL_10": false,
	"LEVEL_25": false,
	"HIT_ENEMY_GOLEM_25": false,
	"HIT_ENEMY_GOLEM_50": false,
	"PLAY_FULL_LOBBY": false,
	"BREAK_BONE_HELMET": false
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
var flick_control: bool = false
var sfx_volume: float = 100.0
var music_volume: float = 100.0
var zoom: float = 1.0
var bag = Bag.new()
var equipped_weapon: Weapon = Catalog.get_by_id(1)
var equipped_armor: Armor = Catalog.get_by_id(2)
var game_loaded: bool = false
var cooldowns: Dictionary[Variant, Variant] = {}
var current_level: int = 0
var current_xp: float = 0.0
var xp_scaling: float = 1.5
var kills = {}
var golem_annoying_thing = {}
var tutorial_active: bool = false
var tutorial_step: int = 0
var tutorial_completed: bool = false
var golem_stupid_rating: int = 0

var highest_wave: int = 0
var highest_rooms: int = 0
var enemies_killed: int = 0

var enemy_data = {
	"rapid_bauble": {
		"entity_name": "Rapid Bauble",
		"dev_commentary_requirement": 50,
		"bestiary_description": "A faster, stronger variant of the Bauble. These will shoot out rapid amounts of stars.",
		"developer_commentary": "These feel fun but aren't really fun when you... play it, maybe that's a problem.",
		"health": 320.0,
		"max_health": 320.0,
		"defense": 0.0,
		"id": 9
	},
	"angry_bauble": {
		"entity_name": "Angry Bauble",
		"dev_commentary_requirement": 100,
		"bestiary_description": "More aggressive version of the Bauble, shoots more stars, shoots faster, what else is there to say?",
		"developer_commentary": "To be honest, can't remember the inspiration for this enemy. But, it's a cool one, I'll give you that, somehow It's more threatening than the Rapid Bauble, which is honestly strange.",
		"health": 300.0,
		"max_health": 300.0,
		"defense": 0.0,
		"id": 8
	},
	"bombrat": {
		"entity_name": "Bombrat",
		"dev_commentary_requirement": 2500,
		"bestiary_description": "Objectives of the Defense gamemode, will ignore players and beeline towards the Gem. Destroy them to progress in the wave.",
		"developer_commentary": "They're described as cats that look like bombs, which I honestly see, pixel art and art in general is not my strongest suite, though I will say a certain detail I wanted to add was the fact that their ears always faced the same direction no matter where they were going, like Mickey Mouse. Though, that might just be an excuse for laziness, who knows?",
		"health": 125.0,
		"max_health": 125.0,
		"defense": 0.0,
		"id": 1
	},
	"big_bombrat": {
		"entity_name": "Big Bombrat",
		"dev_commentary_requirement": 1250,
		"bestiary_description": "A bigger, stronger version of the Bombrat. Will deal double damage to the gem if it makes it to the gem.",
		"developer_commentary": "They're more of a distraction if anything, is that a sign of good game design? You're not supposed to fight these things first, you'll find it more easier to kill the regular Bombrats first. Not much of commentary, more of a tip, but whatever.",
		"health": 500.0,
		"max_health": 500.0,
		"defense": 0.0,
		"id": 4
	},
	"bombrat_mortar": {
		"entity_name": "Bombrat Mortar",
		"dev_commentary_requirement": 200,
		"bestiary_description": "Flaming high speed versions of the Bombrats, avoid their targets at all costs.",
		"developer_commentary": "You ever see marshmallows burning on the fire? That.",
		"health": 0,
		"max_health": 0,
		"defense": 0,
		"id": 16
	},
	"slime": {
		"entity_name": "Slime",
		"dev_commentary_requirement": 500,
		"bestiary_description": "A slow moving enemy, doesn't attack the gem, will attack the player. Doesn't hurt unless it hops on you.",
		"developer_commentary": "A throwback to the original Myrkwood. I honestly just put the original sprite in and then figured it out it looked ugly when putting it in until shrinking it down to 16x16. But this enemy is fun.",
		"health": 75.0,
		"max_health": 75.0,
		"defense": 0.0,
		"id": 0
	},
	"mother_slime": {
		"entity_name": "Mother Slime",
		"dev_commentary_requirement": 75,
		"bestiary_description": "Slower, fatter variants of slimes. These slimes do more damage, but move slower. They will spawn slimes upon dying. Good for collecting gold.",
		"developer_commentary": "This slime variant was more of a cliche if anything. Though the concept of slimes having a fat mama seems amusing.",
		"health": 250.0,
		"max_health": 250.0,
		"defense": 0.0,
		"id": 6
	},
	"poison_slime": {
		"entity_name": "Poison Slime",
		"dev_commentary_requirement": 100,
		"bestiary_description": "A stronger variant of the slime that may inflict Poison when touched.",
		"developer_commentary": "This is... also a throwback to the original Myrkwood.",
		"health": 225.0,
		"max_health": 225.0,
		"defense": 0.0,
		"id": 7
	},
	"bauble": {
		"entity_name": "Bauble",
		"dev_commentary_requirement": 250,
		"bestiary_description": "Shy enemies that shoot stars towards players. They also retreat when far away.",
		"developer_commentary": "Wings are hard to make. Also, honestly the baubles are a pushover if you get too close.",
		"health": 100.0,
		"max_health": 100.0,
		"defense": 0.0,
		"id": 3
	},
	"crabthing": {
		"entity_name": "Crabthing",
		"dev_commentary_requirement": 85,
		"bestiary_description": "Species of sea creature that crawls in shells. Targets a player and relentlessly pursues it, walks faster than the player. Gets staggered when hit too much.",
		"developer_commentary": "These were a monstrosity to draw, I did not like drawing these at all. I literally just drew the Crabthing over Clementine.",
		"health": 1000.0,
		"max_health": 1000.0,
		"defense": 0.0,
		"id": 5
	},
	"ghost": {
		"entity_name": "Ghost",
		"dev_commentary_requirement": 25,
		"bestiary_description": "Apparitions from beyond, can't do anything to mortals, but still watch out, they can still make you feel weak.",
		"developer_commentary": "Initially, they dealt damage and were just stronger versions of the slimes, with a gimmick that they were neutral until you stepped in range, I thought it'd be better if they simply did no damage and created Weak to give it the ability to detriment the player.",
		"health": 250.0,
		"max_health": 250.0,
		"defense": -10.0,
		"id": 10
	},
	"gunk_slime": {
		"entity_name": "Gunk Slime",
		"dev_commentary_requirement": 50,
		"bestiary_description": "Thick, denser variants of the regular slimes. So gooey that they leave behind trails of their slime, touching them or the slime will slow down anyone who crosses upon it.",
		"developer_commentary": "Honestly, they were a blast to make, the splatter effect & the effect was fun and I'm honestly sad they don't show up sooner.",
		"health": 500.0,
		"max_health": 500.0,
		"defense": 0.0,
		"id": 11
	},
	"explosive_bauble": {
		"entity_name": "Explosive Bauble",
		"dev_commentary_requirement": 10,
		"bestiary_description": "Bauble variant that specializes in shooting specialized explosive Stars. They can detonate on players or on walls. Stay away if you value your life!",
		"developer_commentary": "Explosive Baubles are designed after grenades, their special stars are meant to give a more distinct appearance from other stars.",
		"health": 250.0,
		"max_health": 250.0,
		"defense": 0.0,
		"id": 12
	},
	"bombrat_king": {
		"entity_name": "Bombrat King",
		"dev_commentary_requirement": 2,
		"bestiary_description": "The king of most bombrats, has a timer when spawning that requires you to defeat it within a certain amount of time. Spawns shockwaves every so often.",
		"developer_commentary": "Hey it's like the Bob-omb King! I just noticed that, the similarity was not intended, I'll give you that much. I just didn't wanna call it a Mother or a Father like the Mother Slime.",
		"health": 2250.0,
		"max_health": 2250.0,
		"defense": 20.0,
		"id": 13
	},
	"jumper_slime": {
		"entity_name": "Jumper Slime",
		"dev_commentary_requirement": 100,
		"bestiary_description": "Magic imbued slimes that shoot out stars upon landing on the ground, particularly lethal.",
		"developer_commentary": "This was so easy to make... it's a crime. May contain a The Binding of Isaac reference.",
		"health": 125.0,
		"max_health": 125.0,
		"defense": 15.0,
		"id": 15
	},
	"protector_golem": {
		"entity_name": "Protector Golem",
		"dev_commentary_requirement": 50,
		"bestiary_description": "Constructs of magic akin to totems, gentle creatures that seem to not particularly hold any ill will but will aid the creatures of the land.",
		"developer_commentary": "No description but pretty good lore right?",
		"health": 500.0,
		"max_health": 500.0,
		"defense": 115.0,
		"id": 14
	}
}

func play_ui_sfx(stream: AudioStream, bus: String = "SFX") -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.bus = bus
	sfx.volume_db = -10.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(func(): sfx.queue_free())

func level_up():
	current_xp -= calculate_xp_for_level(current_level)
	current_level += 1
	if is_in_game() and get_player() != null:
		get_player().show_level_up_animation(current_level, current_xp, calculate_xp_for_level(current_level))
		
	 # Every 100 XP, give a random item reward
	var options = []
	for item in Catalog.items:
		if (item is Weapon or item is Armor) and not bag.has_item(item):
			options.append(item)

	if not options.is_empty():
		var item = options.pick_random()
		bag.add_item(ItemStack.new(item, 1))
		Toast.add("You earned: " + item.name + "! Equip it in Loadout in the main menu.")
	print("Level up! Now level ", current_level)

func calculate_xp_for_level(level: int) -> float:
	# Formula: base_xp * (scaling ^ (level - 1))
	# Level 1->2: 100 XP
	# Level 2->3: 150 XP
	# Level 3->4: 225 XP, etc.
	return 100.0 * pow(xp_scaling, level - 1)

func get_level_color(level: int) -> Color:
	match level:
		var l when l < 5:
			return Color.GRAY  # Beginner (1-4)
		var l when l < 10:
			return Color.WHITE  # Novice (5-9)
		var l when l < 20:
			return Color.GREEN  # Experienced (10-19)
		var l when l < 30:
			return Color.CYAN  # Skilled (20-29)
		var l when l < 40:
			return Color.BLUE  # Expert (30-39)
		var l when l < 50:
			return Color.PURPLE  # Master (40-49)
		var l when l < 75:
			return Color.ORANGE  # Legend (50-74)
		var l when l < 100:
			return Color.RED  # Mythic (75-99)
		_:
			return Color.GOLD  # Divine (100+)

@rpc("authority", "call_local")
func add_xp(amount: float) -> void:
	current_xp += amount
	
	# Check if we leveled up (possibly multiple times)
	while current_xp >= calculate_xp_for_level(current_level):
		level_up()

func set_rich_presence(token: String) -> void:
	if NetworkManager.steam_enabled:
		var setting_presence = Engine.get_singleton("Steam").setRichPresence("steam_display", token)
		print("Setting rich presence to "+str(token)+": "+str(setting_presence))
	else:
		print("Steam is not enabled, not running this.")
		
func set_rich_presence_value(key: String, token: String) -> void:
	if NetworkManager.steam_enabled:
		var setting_presence = Engine.get_singleton("Steam").setRichPresence(key, token)
		print("Setting rich presence value " + key + " to "+str(token)+": "+str(setting_presence))
	else:
		print("Steam is not enabled, not running this.")	

func start_cooldown(item, seconds: float) -> void:  # Accept both Consumable and Tossable
	var final_seconds = seconds
	
	var player = Man.get_player()
	if player and player.upgrade_bag.has_item(Catalog.get_by_id(34)):
		var cooldown_level = player.upgrade_bag.get_item_stack(Catalog.get_by_id(34)).data["level"]
		var cooldown_reduction = cooldown_level * 0.10
		final_seconds = seconds * (1.0 - cooldown_reduction)
	
	cooldowns[item.id] = {
		"end_time": Time.get_ticks_msec() / 1000.0 + final_seconds
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

func is_mobile() -> bool:
	return OS.get_name() == "Android" or OS.get_name() == "iOS"

func is_desktop() -> bool:
	return not is_mobile()

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
			if playtime_points > 0:
				add_xp(roundi(playtime_points * 0.2))
				playtime_points = 0
		if data.has("highest_wave"):
			highest_wave = data["highest_wave"]
		if data.has("highest_rooms"):
			highest_rooms = data["highest_rooms"]
		if data.has("enemies_killed"):
			enemies_killed = data["enemies_killed"]
		if data.has("current_level"):
			current_level = data["current_level"]
		if data.has("current_xp"):
			current_xp = data["current_xp"]
		if data.has("flick_control"):
			flick_control = data["flick_control"]
		if data.has("zoom"):
			zoom = data["zoom"]
		if data.has("kills"):
			kills = data["kills"]
		if data.has("tutorial_completed"):
			tutorial_completed = data["tutorial_completed"]
		if data.has("selected_map"):
			selected_map = data["selected_map"]
		if data.has("golem_stupid_rating"):
			golem_stupid_rating = data["golem_stupid_rating"]
	
	if NetworkManager.steam_enabled:
		for this_achievement in achievements.keys():
			var steam_achievement = Steam.getAchievement(this_achievement)

			# Does the achievement actually exist in the Steamworks back-end?
			if not steam_achievement['ret']:
				print("Steam does not have this achievement, ignoring it")
				continue
			achievements[this_achievement] = steam_achievement['achieved']
	print("Loaded save data.")

func set_achievement(this_achievement: String) -> void:
	if not achievements.has(this_achievement):
		print("This achievement does not exist locally: %s" % this_achievement)
		return
	achievements[this_achievement] = true

	if not Steam.setAchievement(this_achievement):
		print("Failed to set achievement: %s" % this_achievement)
		return

	print("Set acheivement: %s" % this_achievement)
	store_steam_data()

func store_steam_data() -> void:
	if not Steam.storeStats():
		print("Failed to store data on Steam, should be stored locally")
		return
	print("Data successfully sent to Steam")
	
@rpc("any_peer", "call_local", "reliable")
func send_kill(enemy_type: String) -> void:
	if not kills.has(enemy_type):
		kills[enemy_type] = 0
	kills[enemy_type] += 1
	print("Added kill for " + enemy_type + " (" + str(kills[enemy_type]) + " kills).")

func get_save_data() -> Dictionary:
	return {
		"bag": bag.to_list(),
		"equipped_weapon": equipped_weapon.id,
		"equipped_armor": equipped_armor.id,
		"fullscreen": fullscreen,
		"playtime_points": playtime_points,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"highest_wave": highest_wave,
		"highest_rooms": highest_rooms,
		"enemies_killed": enemies_killed,
		"current_level": current_level,
		"current_xp": current_xp,
		"flick_control": flick_control,
		"zoom": zoom,
		"kills": kills,
		"tutorial_completed": tutorial_completed,
		"selected_map": selected_map,
		"golem_stupid_rating": golem_stupid_rating
	}

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if game_loaded:
			save_game("went to background")

func save_game(reason: String) -> void:
	var save_file: FileAccess = FileAccess.open("user://game.mewo", FileAccess.WRITE)
	save_file.store_line(JSON.stringify(get_save_data()))
	print("Saved the game. " + "(" + reason + ")")
	if HAuth.product_user_id != "":
		HStats.ingest_stat_async("rooms", highest_rooms)
		HStats.ingest_stat_async("waves", highest_wave)
	if current_level >= 5:
		set_achievement("LEVEL_5")
	if current_level >= 10:
		set_achievement("LEVEL_10")
	if current_level >= 25:
		set_achievement("LEVEL_25")
	if highest_rooms >= 30:
		set_achievement("ROOM_30")
	if highest_rooms >= 50:
		set_achievement("ROOM_50")
	if highest_wave >= 30:
		set_achievement("WAVE_30")
	if highest_wave >= 50:
		set_achievement("WAVE_50")
	if enemies_killed >= 10_000:
		set_achievement("KILL_10_000")
	if enemies_killed >= 25_000:
		set_achievement("KILL_25_000")
	if enemies_killed >= 50_000:
		set_achievement("KILL_50_000")
	if enemies_killed >= 100_000:
		set_achievement("KILL_100_000")
	if tutorial_completed:
		set_achievement("COMPLETE_TUTORIAL")
	if kills.has("bombrat_king"):
		set_achievement("DEFEAT_BOMBRAT_KING")
		
	var found_armor = 0
	var found_weapons = 0
	var total_armor = 0
	var total_weapons = 0
	
	for item in Catalog.items:
		if item is Weapon:
			total_weapons += 1
			if bag.has_item(item):
				found_weapons += 1
		if item is Armor:
			total_armor += 1
			if bag.has_item(item):
				found_armor += 1
	if found_armor == total_armor:
		set_achievement("GET_ALL_ARMOR")
	if found_weapons == total_weapons:
		set_achievement("GET_ALL_WEAPONS")
	if found_armor == total_armor and found_weapons == total_weapons:
		set_achievement("GET_ALL_WEAPONS_ARMOR")
	if roundi(await get_bestiary_completion()) >= 100:
		set_achievement("COMPLETE_BESTIARY_FULL")
	if roundi(await get_bestiary_completion()) >= 50:
		set_achievement("COMPLETE_BESTIARY_HALFWAY")
	if golem_stupid_rating >= 25:
		set_achievement("HIT_ENEMY_GOLEM_25")
	if golem_stupid_rating >= 50:
		set_achievement("HIT_ENEMY_GOLEM_50")

func get_bestiary_completion() -> float:
	var completed := 0.0

	for enemy_name in Man.enemy_data.keys():
		if not Man.kills.has(enemy_name):
			continue
		var enemy = Man.enemy_data[enemy_name]
		var kills: int = Man.kills[enemy_name]
		completed += 1 if kills >= enemy.dev_commentary_requirement else 0.5

	return float(completed) / float(Man.enemy_data.size()) * 100.0

func _ready() -> void:
	load_game()
	
func is_in_game() -> bool:
	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Defense") or child.name.begins_with("Dungeons"):
			return true
	return false
	
@rpc("authority", "call_local", "reliable")
func start_game(mode: String, map: String) -> void:
	await Fade.fade_out(0.25)
	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Main Menu") or child.name.begins_with("Defense") or child.name.begins_with("Dungeons"):
			child.queue_free()
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
		if child.name.begins_with("Defense") or child.name.begins_with("Main Menu") or child.name.begins_with("Dungeons"):
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
