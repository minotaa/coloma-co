extends Node2D

# Audio
var click1 = preload("res://assets/sounds/click1.wav")
var click2 = preload("res://assets/sounds/click.wav")

# State management
enum MenuState {
	TITLE_SCREEN,
	PLAY_BUTTONS,
	SINGLEPLAYER_MODE_SELECTOR,
	MULTIPLAYER_MODE_SELECTOR,
	LOADOUT,
	LOADOUT_ARMOR_GRID,
	LOADOUT_WEAPON_GRID,
	LOADOUT_BESTIARY,
	OPTIONS,
	OPTIONS_CONTROLS,
	OPTIONS_CREDITS,
	MULTIPLAYER_BUTTONS,
	ONLINE_BUTTONS,
	LAN_BUTTONS,
	ONLINE_JOIN,
	JOIN,
	PLAYERS
}

var current_state: MenuState = MenuState.TITLE_SCREEN

# State node references (cached for performance)
var state_nodes := {}

func _ready() -> void:
	_cache_state_nodes()
	_setup_audio()
	_setup_initial_values()
	_connect_all_buttons()
	_setup_online_integration()
	_setup_input_detection()
	
	transition_to(MenuState.TITLE_SCREEN)
	_check_for_auto_join()
	
	await Fade.fade_out(0.0)
	if Man.selected_map == "Solmere":
		$Demoman.global_position = Vector2(0, 544)
		$Leaves.emitting = false
		$Dust.emitting = true
	else:
		$Demoman.global_position = Vector2(0, 0)
		$Leaves.emitting = true
		$Dust.emitting = false
	await get_tree().create_timer(0.25).timeout
	await Fade.fade_in(0.25)

func _check_for_auto_join() -> void:
	"""Check if game was launched with a join parameter and auto-connect"""
	if NetworkManager.invitation != "":
		var userid = NetworkManager.invitation
		NetworkManager.invitation = ""
		print("Auto-joining game with user ID: " + userid)
		Toast.add("Joining friend's game...")
		
		# Wait for EOS to initialize and get display name
		if HAuth.product_user_id == "" or HAuth.display_name == "" or HAuth.display_name.is_empty():
			print("Waiting for login and display name...")
			
			# Wait for display_name_changed signal with timeout
			await HAuth.display_name_changed
			
			# Add a small delay to ensure everything is ready
			await get_tree().create_timer(0.5).timeout
			
			if HAuth.product_user_id == "" or HAuth.display_name == "" or HAuth.display_name.is_empty():
				Toast.add("Failed to get username before joining")
				return
			
			print("Display name set to: " + HAuth.display_name)
		
		# Auto-join the server
		var result = await NetworkManager.join_online_server(userid)
		
		if result:
			NetworkManager.update_players.connect(_on_update_players)
			Toast.add("Successfully joined friend's game!")
			
			$UI/Main/Mode.text = "-- multiplayer game --"
			$UI/Main/Players/Start.visible = false
			$"UI/Main/Players/Mode Selector".visible = false
			$"UI/Main/Players/Copy UserID".visible = false
			$UI/Main/Players/Details.visible = true
			$UI/Main/Players/Panel2.visible = true
			
			transition_to(MenuState.PLAYERS)
		else:
			Toast.add("Failed to join friend's game")
			play_ui_sfx(preload("res://assets/sounds/deny.wav"))

func _cache_state_nodes() -> void:
	"""Cache references to all state container nodes"""
	state_nodes[MenuState.TITLE_SCREEN] = $UI/Main/Buttons
	state_nodes[MenuState.PLAY_BUTTONS] = $"UI/Main/Play Buttons"
	state_nodes[MenuState.SINGLEPLAYER_MODE_SELECTOR] = $"UI/Main/Singleplayer Mode Selector"
	state_nodes[MenuState.LOADOUT] = $UI/Main/Loadout
	state_nodes[MenuState.OPTIONS] = $UI/Main/Options
	state_nodes[MenuState.MULTIPLAYER_BUTTONS] = $"UI/Main/Multiplayer Buttons"
	state_nodes[MenuState.ONLINE_BUTTONS] = $"UI/Main/Online Buttons"
	state_nodes[MenuState.LAN_BUTTONS] = $"UI/Main/LAN Buttons"
	state_nodes[MenuState.ONLINE_JOIN] = $"UI/Main/Online Join"
	state_nodes[MenuState.JOIN] = $UI/Main/Join
	state_nodes[MenuState.PLAYERS] = $UI/Main/Players

func _setup_audio() -> void:
	play_music(preload("res://assets/sounds/MO_titlescreen.wav"), true)
	
func _setup_initial_values() -> void:
	$UI/Main/Version.text = "v" + ProjectSettings.get_setting("application/config/version")
	$Demoman/Camera2D.zoom = Vector2(6.0 * Man.zoom, 6.0 * Man.zoom)
	Man.set_rich_presence("#In_MainMenu")
	
	# Dev mode visibility
	if NetworkManager.dev_mode:
		$"UI/Main/Multiplayer Buttons/Online2".visible = true
		$"UI/Main/Multiplayer Buttons/Name".visible = true
		$"UI/Main/Multiplayer Buttons/Address".visible = true
	if NetworkManager.steam_enabled:
		$"UI/Main/Multiplayer Buttons/LineEdit".visible = false

func _physics_process(delta: float) -> void:
	if ($Demoman/Camera2D.zoom.x / 6.0) != Man.zoom:
		$Demoman/Camera2D.zoom = Vector2(6.0 * Man.zoom, 6.0 * Man.zoom)

func _connect_all_buttons() -> void:
	"""Connect all button signals to their handlers"""
	for button in find_children("", "Button", true):
		if button is Button:
			_connect_button_sfx(button)

func _setup_online_integration() -> void:
	if NetworkManager.eos_is_initialized:
		_eos_initialized()
	else:
		HPlatform.platform_created.connect(_eos_initialized)

# ============================================================================
# STATE TRANSITION SYSTEM
# ============================================================================

func transition_to(new_state: MenuState) -> void:
	"""Transition to a new menu state"""
	_exit_state(current_state)
	current_state = new_state
	await _enter_state(current_state)

func _exit_state(state: MenuState) -> void:
	"""Handle cleanup when exiting a state"""
	match state:
		MenuState.PLAYERS:
			_cleanup_multiplayer()
		MenuState.LOADOUT:
			_show_title_elements(true)

func _enter_state(state: MenuState) -> void:
	"""Handle setup when entering a state"""
	_hide_all_states()
	
	match state:
		MenuState.TITLE_SCREEN:
			_show_title_elements(true)
			_enter_title_screen()
		MenuState.PLAY_BUTTONS:
			_enter_play_buttons()
		MenuState.SINGLEPLAYER_MODE_SELECTOR:
			_enter_singleplayer_mode_selector()
		MenuState.LOADOUT:
			_enter_loadout()
		MenuState.LOADOUT_ARMOR_GRID:
			_enter_loadout_armor_grid()
		MenuState.LOADOUT_WEAPON_GRID:
			_enter_loadout_weapon_grid()
		MenuState.LOADOUT_BESTIARY:
			_enter_bestiary()
		MenuState.OPTIONS:
			_enter_options()
		MenuState.OPTIONS_CONTROLS:
			_enter_options_controls()
		MenuState.OPTIONS_CREDITS:
			_enter_options_credits()
		MenuState.MULTIPLAYER_BUTTONS:
			_enter_multiplayer_buttons()
		MenuState.ONLINE_BUTTONS:
			_enter_online_buttons()
		MenuState.LAN_BUTTONS:
			_enter_lan_buttons()
		MenuState.ONLINE_JOIN:
			_enter_online_join()
		MenuState.JOIN:
			_enter_join()
		MenuState.PLAYERS:
			_enter_players()

func _hide_all_states() -> void:
	"""Hide all state containers"""
	for node in state_nodes.values():
		if node:
			node.visible = false
	
	# Hide additional UI elements
	$UI/Main/Mode.text = ""
	$Demoman/Username.visible = false

# ============================================================================
# STATE ENTER FUNCTIONS
# ============================================================================

func _enter_title_screen() -> void:
	state_nodes[MenuState.TITLE_SCREEN].visible = true
	$UI/Main/Buttons/VBoxContainer/Play.grab_focus()
	if Man.is_mobile():
		$UI/Main/Buttons/VBoxContainer/Quit.visible = false
	$UI/Main/Mode.text = "-- select your mode --"
	_update_button_focus_styles(false)
	_show_title_elements(true)

func _enter_play_buttons() -> void:
	state_nodes[MenuState.PLAY_BUTTONS].visible = true
	$"UI/Main/Play Buttons/Singleplayer".grab_focus()

func _enter_singleplayer_mode_selector() -> void:
	state_nodes[MenuState.SINGLEPLAYER_MODE_SELECTOR].visible = true
	update_mode_selector()
	$"UI/Main/Singleplayer Mode Selector/Start".grab_focus()

func _enter_loadout() -> void:
	state_nodes[MenuState.LOADOUT].visible = true
	$UI/Main/Loadout/Back.grab_focus()
	$UI/Main/Loadout/Panel/Main.visible = true
	$UI/Main/Loadout/Panel/Bestiary.visible = false
	$UI/Main/Loadout/Panel/Grid.visible = false
	$UI/Main/Loadout/Panel/Main/Bestiary.text = "Bestiary (" + str(roundi(await Man.get_bestiary_completion())) + "%)"
	$UI/Main/Loadout/Panel/Main/Level.text = "Level " + str(Man.current_level)
	$UI/Main/Loadout/Panel/Main/XP.value = Man.current_xp
	$UI/Main/Loadout/Panel/Main/XP.max_value = Man.calculate_xp_for_level(Man.current_level)
	_show_title_elements(false)
	update_loadout()
	_reset_loadout_back_button_focus()

func _enter_bestiary() -> void:
	state_nodes[MenuState.LOADOUT].visible = true
	_show_title_elements(false)
	
	$UI/Main/Loadout/Panel/Grid.visible = false
	$UI/Main/Loadout/Panel/Main.visible = false
	$UI/Main/Loadout/Panel/Bestiary.visible = true
	for child in $UI/Main/Loadout/Panel/Bestiary/ScrollContainer/VBoxContainer.get_children():
		child.queue_free()
	$UI/Main/Loadout/Panel/Bestiary/Panel.visible = false
	$UI/Main/Loadout/Back.grab_focus()
	for e in Man.kills.keys():
		var enemy = await Man.get_enemy(e)
		var entry = preload("res://scenes/bestiary_entry.tscn").instantiate()
		entry.text = enemy.name + "   " + str(int(Man.kills[e])) + " kills"
		$UI/Main/Loadout/Panel/Bestiary/ScrollContainer/VBoxContainer.add_child(entry)
		entry.connect("pressed", Callable(_select_bestiary_entry).bind(e))
	_configure_focus_neighbors_with_back($UI/Main/Loadout/Panel/Bestiary/ScrollContainer/VBoxContainer)
	_connect_all_buttons()

func _select_bestiary_entry(enemy_name) -> void:
	if not $UI/Main/Loadout/Panel/Bestiary/Panel.visible:
		$UI/Main/Loadout/Panel/Bestiary/Panel.visible = true
	var enemy = await Man.get_enemy(enemy_name)
	$UI/Main/Loadout/Panel/Bestiary/Panel/Title.text = enemy.name
	$UI/Main/Loadout/Panel/Bestiary/Panel/Description/Label.text = enemy.bestiary_description
	if Man.kills[enemy_name] >= enemy.dev_commentary_requirement:
		$UI/Main/Loadout/Panel/Bestiary/Panel/DevDescription/Label.text = enemy.developer_commentary
	else:
		$UI/Main/Loadout/Panel/Bestiary/Panel/DevDescription/Label.text = "Kill " + str(int(enemy.dev_commentary_requirement - Man.kills[enemy_name])) + " more of this enemy to get a developer description."
	$UI/Main/Loadout/Panel/Bestiary/Panel/Stats/Label.text = "ID: " + str(int(enemy.id)) + " - HP: " + str(int(enemy.health)) + " - DEF: " + str(int(enemy.defense))
	print(enemy)

func _enter_loadout_armor_grid() -> void:
	state_nodes[MenuState.LOADOUT].visible = true
	_show_title_elements(false)
	
	var loadout_button_scene = preload("res://scenes/loadout_button.tscn")
	$UI/Main/Loadout/Panel/Grid.visible = true
	$UI/Main/Loadout/Panel/Main.visible = false
	$UI/Main/Loadout/Panel/Bestiary.visible = false
	$UI/Main/Loadout/Panel/Grid/Title.text = "Armor"
	
	var grid = $UI/Main/Loadout/Panel/Grid/ScrollContainer/GridContainer
	# Properly disconnect and free old children
	for child in grid.get_children():
		if child.pressed.is_connected(Callable()):
			for connection in child.get_signal_connection_list("pressed"):
				child.pressed.disconnect(connection["callable"])
		child.queue_free()
	
	# Wait a frame to ensure old nodes are cleaned up
	await get_tree().process_frame
	
	for item in Man.bag.list:
		if item.type is Armor:
			var btn = loadout_button_scene.instantiate()
			btn.get_node("TextureRect").texture = item.type.texture
			grid.add_child(btn, true)
			var armor_item = item.type  # Capture the item in a local variable
			btn.pressed.connect(func(): 
				select_armor(armor_item)
				transition_to(MenuState.LOADOUT)
			)
	
	# Wait for buttons to be ready in scene tree
	await get_tree().process_frame
	_configure_focus_neighbors_with_back(grid)



func _enter_loadout_weapon_grid() -> void:
	state_nodes[MenuState.LOADOUT].visible = true
	_show_title_elements(false)
	
	var loadout_button_scene = preload("res://scenes/loadout_button.tscn")
	$UI/Main/Loadout/Panel/Grid.visible = true
	$UI/Main/Loadout/Panel/Main.visible = false
	$UI/Main/Loadout/Panel/Bestiary.visible = false
	$UI/Main/Loadout/Panel/Grid/Title.text = "Weapons"
	
	var grid = $UI/Main/Loadout/Panel/Grid/ScrollContainer/GridContainer
	# Properly disconnect and free old children
	for child in grid.get_children():
		if child.pressed.is_connected(Callable()):
			for connection in child.get_signal_connection_list("pressed"):
				child.pressed.disconnect(connection["callable"])
		child.queue_free()
	
	# Wait a frame to ensure old nodes are cleaned up
	await get_tree().process_frame
	
	for item in Man.bag.list:
		if item.type is Weapon:
			var btn = loadout_button_scene.instantiate()
			btn.get_node("TextureRect").texture = item.type.texture
			grid.add_child(btn, true)
			var weapon_item = item.type  # Capture the item in a local variable
			btn.pressed.connect(func(): 
				select_weapon(weapon_item)
				transition_to(MenuState.LOADOUT)
			)
	
	# Wait for buttons to be ready in scene tree
	await get_tree().process_frame
	_configure_focus_neighbors_with_back(grid)

func _enter_options() -> void:
	state_nodes[MenuState.OPTIONS].visible = true
	$UI/Main/Options/Options/General.visible = true
	$UI/Main/Options/Options/Controls.visible = false
	$UI/Main/Options/Options/Credits.visible = false
	$UI/Main/Options/Options/General/ScrollContainer/VBoxContainer/Fullscreen/CheckBox.grab_focus()

func _enter_options_controls() -> void:
	state_nodes[MenuState.OPTIONS].visible = true
	$UI/Main/Options/Options/General.visible = false
	$UI/Main/Options/Options/Controls.visible = true
	
	var keybind_scene = preload("res://scenes/keybind.tscn")
	var container = $UI/Main/Options/Controls/ScrollContainer/VBoxContainer
	for child in container.get_children():
		child.queue_free()
	
	for control in Man.controls.keys():
		var key = keybind_scene.instantiate()
		key.get_node("HBoxContainer/Label").text = Man.controls[control]
		key.get_node("HBoxContainer/Key").keycode = str(control)
		container.add_child(key)
	
	# Wait for buttons to be ready, then focus back button
	await get_tree().process_frame
	if $UI/Main/Options/Options/Controls.has_node("Back"):
		$UI/Main/Options/Options/Controls/Back.grab_focus()
	else:
		# Fallback: try to find any back button in Options
		for child in $UI/Main/Options.find_children("Back", "Button", true):
			child.grab_focus()
			break

func _enter_options_credits() -> void:
	state_nodes[MenuState.OPTIONS].visible = true
	$UI/Main/Options/Options/General.visible = false
	$UI/Main/Options/Options/Credits.visible = true
	
	# Focus the back button
	if $UI/Main/Options/Options/Credits.has_node("Back"):
		$UI/Main/Options/Options/Credits/Back.grab_focus()
	else:
		# Fallback: try to find any back button in Options
		for child in $UI/Main/Options.find_children("Back", "Button", true):
			child.grab_focus()
			break

func _enter_multiplayer_buttons() -> void:
	state_nodes[MenuState.MULTIPLAYER_BUTTONS].visible = true
	$"UI/Main/Multiplayer Buttons/Online".grab_focus()
	if $"UI/Main/Multiplayer Buttons/LineEdit".text != "":
		$Demoman/Username.visible = true
		$Demoman/Username.text = $"UI/Main/Multiplayer Buttons/LineEdit".text

func _enter_online_buttons() -> void:
	state_nodes[MenuState.ONLINE_BUTTONS].visible = true
	$"UI/Main/Online Buttons/Host".grab_focus()

func _enter_lan_buttons() -> void:
	state_nodes[MenuState.LAN_BUTTONS].visible = true
	$UI/Main/Mode.text = "-- select your multiplayer mode --"
	$"UI/Main/LAN Buttons/Host".grab_focus()
	if $"UI/Main/Multiplayer Buttons/LineEdit".text != "":
		$Demoman/Username.visible = true
		$Demoman/Username.text = $"UI/Main/Multiplayer Buttons/LineEdit".text

func _enter_online_join() -> void:
	state_nodes[MenuState.ONLINE_JOIN].visible = true
	$"UI/Main/Online Join/UserID".grab_focus()
	if Man.is_mobile():
		$"UI/Main/Online Join/UserID/Paste".visible = true
	else:
		$"UI/Main/Online Join/UserID/Paste".visible = true

func _enter_join() -> void:
	state_nodes[MenuState.JOIN].visible = true
	$UI/Main/Mode.text = "-- enter server details --"
	$"UI/Main/Join/Address".grab_focus()

func _enter_players() -> void:
	state_nodes[MenuState.PLAYERS].visible = true
	_on_update_players(NetworkManager.players)
	_configure_players_focus()

func _show_title_elements(show: bool) -> void:
	$UI/Main/Title.visible = show
	$UI/Main/Title2.visible = show
	$UI/Main/Version.visible = show

# ============================================================================
# BUTTON HANDLERS (now use state transitions)
# ============================================================================

func _on_play_pressed() -> void:
	transition_to(MenuState.PLAY_BUTTONS)

func _on_loadout_pressed() -> void:
	transition_to(MenuState.LOADOUT)

func _on_options_pressed() -> void:
	transition_to(MenuState.OPTIONS)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_singleplayer_pressed() -> void:
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		_cleanup_multiplayer()
	transition_to(MenuState.SINGLEPLAYER_MODE_SELECTOR)

func _on_multiplayer_pressed() -> void:
	transition_to(MenuState.MULTIPLAYER_BUTTONS)

func _on_online_pressed() -> void:
	if HAuth.product_user_id == "":
		if not NetworkManager.steam_enabled:
			var result = await HAuth.login_anonymous_async($"UI/Main/Multiplayer Buttons/LineEdit".text)
			if result == false:
				Toast.add("An error occurred while attempting to sign in.")
				play_ui_sfx(preload("res://assets/sounds/deny.wav"))
				return
		else:
			NetworkManager.initiate_steam_login_to_eos()
	
	transition_to(MenuState.ONLINE_BUTTONS)

func _on_lan_pressed() -> void:
	transition_to(MenuState.LAN_BUTTONS)

func _on_online_host_pressed() -> void:
	NetworkManager.host_online_server()
	NetworkManager.update_players.connect(_on_update_players)
	Toast.add("Players can now connect to your game by joining it!")
	
	$UI/Main/Mode.text = "-- multiplayer game (host) --"
	$UI/Main/Players/Details.visible = false
	$UI/Main/Players/Panel2.visible = false
	$"UI/Main/Players/Copy UserID".visible = true
	$UI/Main/Players/Start.visible = true
	$"UI/Main/Players/Mode Selector".visible = true
	$UI/Main/Version.visible = false
	$UI/Main/Players/Back.text = "Disband"
	
	transition_to(MenuState.PLAYERS)

func _on_online_join_pressed() -> void:
	transition_to(MenuState.ONLINE_JOIN)

#func _notification(what: int) -> void:
	#if what == NOTIFICATION_WM_SIZE_CHANGED:
		#dumb = 

func _on_host_pressed() -> void:
	if $"UI/Main/Multiplayer Buttons/LineEdit".text != "":
		NetworkManager.player_name = $"UI/Main/Multiplayer Buttons/LineEdit".text
	else:
		NetworkManager.player_name = "Player"
		$Demoman/Username.visible = true
		$Demoman/Username.text = "Player"
	
	NetworkManager.host_server(NetworkManager.PORT)
	NetworkManager.update_players.connect(_on_update_players)
	Toast.add("Players can now connect to your game by joining it!")
	
	$UI/Main/Mode.text = "-- multiplayer game (host) --"
	$"UI/Main/Players/Copy UserID".visible = false
	$UI/Main/Players/Details.visible = false
	$UI/Main/Players/Panel2.visible = false
	$UI/Main/Players/Start.visible = true
	$"UI/Main/Players/Mode Selector".visible = true
	$UI/Main/Version.visible = false
	$UI/Main/Players/Back.text = "Disband"
	
	transition_to(MenuState.PLAYERS)

func _on_lan_join_pressed() -> void:
	transition_to(MenuState.JOIN)

func _on_online_join_join_pressed() -> void:
	Toast.add("Connecting to " + $"UI/Main/Online Join/UserID".text + "...")
	$"UI/Main/Online Join/Join".disabled = true
	$"UI/Main/Online Join/Back".disabled = true
	
	var result = await NetworkManager.join_online_server($"UI/Main/Online Join/UserID".text)
	$"UI/Main/Online Join/Join".disabled = false
	$"UI/Main/Online Join/Back".disabled = false
	
	if result == false:
		Toast.add("Couldn't connect to the server")
		play_ui_sfx(preload("res://assets/sounds/deny.wav"))
		$"UI/Main/Online Join/UserID".grab_focus()
	else:
		NetworkManager.update_players.connect(_on_update_players)
		Toast.add("Successfully connected to the server!")
		
		$UI/Main/Players/Back.text = "Leave"
		$UI/Main/Mode.text = "-- multiplayer game --"
		$UI/Main/Players/Start.visible = false
		$"UI/Main/Players/Mode Selector".visible = false
		$"UI/Main/Players/Copy UserID".visible = false
		$UI/Main/Players/Details.visible = true
		$UI/Main/Players/Panel2.visible = true
		$UI/Main/Version.visible = false
		
		transition_to(MenuState.PLAYERS)

func _on_join_pressed() -> void:
	if $"UI/Main/Multiplayer Buttons/LineEdit".text != "":
		NetworkManager.player_name = $"UI/Main/Multiplayer Buttons/LineEdit".text
	else:
		NetworkManager.player_name = "Player"
	
	Toast.add("Connecting to " + $UI/Main/Join/Address.text + "...")
	$"UI/Main/Join/Join".disabled = true
	$"UI/Main/Join/Back".disabled = true
	$"UI/Main/Join/Address".editable = false
	
	var result = await NetworkManager.join_server($UI/Main/Join/Address.text, NetworkManager.player_name)
	
	$"UI/Main/Join/Join".disabled = false
	$"UI/Main/Join/Back".disabled = false
	$"UI/Main/Join/Address".editable = true
	
	if result == false:
		Toast.add("Couldn't connect to the server.")
		play_ui_sfx(preload("res://assets/sounds/deny.wav"))
		$"UI/Main/Join/Address".grab_focus()
	else:
		NetworkManager.update_players.connect(_on_update_players)
		Toast.add("Successfully connected to the server!")
		
		$UI/Main/Players/Back.text = "Leave"
		$UI/Main/Mode.text = "-- multiplayer game --"
		$UI/Main/Players/Start.visible = false
		$"UI/Main/Players/Mode Selector".visible = false
		$"UI/Main/Players/Copy UserID".visible = false
		$UI/Main/Players/Details.visible = true
		$UI/Main/Players/Panel2.visible = true
		$UI/Main/Version.visible = false
		
		transition_to(MenuState.PLAYERS)

func _on_armor_button_pressed() -> void:
	await transition_to(MenuState.LOADOUT_ARMOR_GRID)

func _on_weapon_button_pressed() -> void:
	await transition_to(MenuState.LOADOUT_WEAPON_GRID)

func _on_controls_pressed() -> void:
	transition_to(MenuState.OPTIONS_CONTROLS)

func _on_credits_pressed() -> void:
	transition_to(MenuState.OPTIONS_CREDITS)

func _on_back_pressed() -> void:
	# Handle back navigation based on current state
	match current_state:
		MenuState.LOADOUT_ARMOR_GRID, MenuState.LOADOUT_WEAPON_GRID, MenuState.LOADOUT_BESTIARY:
			transition_to(MenuState.LOADOUT)
		MenuState.LOADOUT:
			transition_to(MenuState.TITLE_SCREEN)
		MenuState.OPTIONS_CONTROLS, MenuState.OPTIONS_CREDITS:
			transition_to(MenuState.OPTIONS)
		MenuState.OPTIONS:
			transition_to(MenuState.TITLE_SCREEN)
		MenuState.PLAY_BUTTONS:
			transition_to(MenuState.TITLE_SCREEN)
		MenuState.SINGLEPLAYER_MODE_SELECTOR:
			transition_to(MenuState.PLAY_BUTTONS)
		MenuState.MULTIPLAYER_BUTTONS:
			transition_to(MenuState.PLAY_BUTTONS)
		MenuState.ONLINE_BUTTONS:
			transition_to(MenuState.MULTIPLAYER_BUTTONS)
		MenuState.LAN_BUTTONS:
			transition_to(MenuState.MULTIPLAYER_BUTTONS)
		MenuState.ONLINE_JOIN:
			transition_to(MenuState.ONLINE_BUTTONS)
		MenuState.JOIN:
			transition_to(MenuState.LAN_BUTTONS)
		MenuState.PLAYERS:
			_cleanup_multiplayer()
			transition_to(MenuState.TITLE_SCREEN)
		_:
			transition_to(MenuState.TITLE_SCREEN)

func _on_start_pressed() -> void:
	if multiplayer.is_server():
		play_ui_sfx(preload("res://assets/sounds/success.wav"))
		Man.start_game.rpc(Man.selected_mode, Man.selected_map)
		Man.set_rich_presence("#Multiplayer")
		Man.set_rich_presence_value("map", Man.selected_map)

func _on_mode_selector_start_pressed() -> void:
	play_ui_sfx(preload("res://assets/sounds/success.wav"))
	Man.start_game(Man.selected_mode, Man.selected_map)
	Man.set_rich_presence("#Singleplayer")
	Man.set_rich_presence_value("map", Man.selected_map)

# ============================================================================
# HELPER FUNCTIONS (unchanged functionality)
# ============================================================================

func play_ui_sfx(stream: AudioStream, bus: String = "SFX") -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.bus = bus
	sfx.volume_db = -10.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(func(): sfx.queue_free())

func play_music(stream: AudioStream, looping: bool = false) -> AudioStreamPlayer:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.bus = "Music"
	sfx.volume_db = -10.0
	add_child(sfx)
	sfx.play()
	
	if looping:
		sfx.finished.connect(func(): sfx.play())
	else:
		sfx.finished.connect(func(): sfx.queue_free())
	
	return sfx

func _connect_button_sfx(button: Button) -> void:
	button.mouse_entered.connect(func(): play_ui_sfx(click2))
	button.pressed.connect(func(): play_ui_sfx(click1))

func _eos_initialized() -> void:
	HAuth.logged_in.connect(_eos_on_logged_in)
	$"UI/Main/Multiplayer Buttons/Online".disabled = false

func _eos_on_logged_in() -> void:
	if current_state == MenuState.MULTIPLAYER_BUTTONS:
		transition_to(MenuState.ONLINE_BUTTONS)

func init_online_buttons() -> void:
	$"UI/Main/Online Buttons".visible = true

func _on_update_players(players: Array) -> void:
	Man.set_rich_presence("#In_Lobby")
	Man.set_rich_presence_value("players", str(NetworkManager.players.size()))
	
	var container = $UI/Main/Players/ScrollContainer/VBoxContainer
	for child in container.get_children():
		child.queue_free()
	
	for player in players:
		var entry = preload("res://scenes/multiplayer_player_entry.tscn").instantiate()
		var level_color = Man.get_level_color(player.get("level", 1))
		var level = player.get("level", 1)
		entry.get_node("Label").text = "[color=#" + level_color.to_html() + "][" + str(level) + "][/color] " + player["username"]
		container.add_child(entry, true)
	
	$UI/Main/Players/Count.text = "Players (" + str(players.size()) + "/6)"
	$"UI/Main/Players/Details".text = "Mode: " + Man.selected_mode + "\nMap: " + Man.selected_map
	$"UI/Main/Players/Mode Selector/Panel/Mode Selector/Label".text = Man.selected_mode
	$"UI/Main/Players/Mode Selector/Panel/Map Selector/Label".text = Man.selected_map

func update_mode_selector() -> void:
	$"UI/Main/Singleplayer Mode Selector/Panel/Mode Selector/Label".text = Man.selected_mode
	$"UI/Main/Singleplayer Mode Selector/Panel/Map Selector/Label".text = Man.selected_map
	
	$"UI/Main/Singleplayer Mode Selector/Panel2/Title".text = Man.selected_mode
	$"UI/Main/Singleplayer Mode Selector/Panel2/ScrollContainer/Description".text = Man.explanations[Man.selected_mode]
	
	if Man.selected_map == "Solmere":
		$Demoman.global_position = Vector2(0, 544)
		$Leaves.emitting = false
		$Dust.emitting = true
	else:
		$Demoman.global_position = Vector2(0, 0)
		$Leaves.emitting = true
		$Dust.emitting = false

	
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		NetworkManager.send_mode.rpc(Man.selected_mode, Man.selected_map)
		NetworkManager.update_players.emit(NetworkManager.players)

func update_loadout() -> void:
	$UI/Main/Loadout/Panel/Main/ArmorIcon.texture = Man.equipped_armor.texture
	$UI/Main/Loadout/Panel/Main/WeaponIcon.texture = Man.equipped_weapon.texture
	
	var found_armor = 0
	var found_weapons = 0
	var total_armor = 0
	var total_weapons = 0
	
	for item in Catalog.items:
		if item is Weapon:
			total_weapons += 1
			if Man.bag.has_item(item):
				found_weapons += 1
		if item is Armor:
			total_armor += 1
			if Man.bag.has_item(item):
				found_armor += 1
	
	$UI/Main/Loadout/Panel/Main/Armor.text = "Armor (" + str(found_armor) + "/" + str(total_armor) + ")"
	$UI/Main/Loadout/Panel/Main/Weapon.text = "Weapon (" + str(found_weapons) + "/" + str(total_weapons) + ")"
	$UI/Main/Loadout/Panel/Main/ArmorMeta.text = Man.equipped_armor.name + "\n" + Man.equipped_armor.description
	$UI/Main/Loadout/Panel/Main/WeaponMeta.text = Man.equipped_weapon.name + "\n" + Man.equipped_weapon.description
	$UI/Main/Loadout/Panel/Main/Meta.text = "+" + str(roundi(Man.equipped_weapon.damage)) + " damage\n+" + str(roundi(Man.equipped_armor.defense)) + " defense"

func select_weapon(item: Weapon) -> void:
	Man.equipped_weapon = item
	Toast.add("Set your weapon to: " + item.name)
	Man.save_game("set weapon")

func select_armor(item: Armor) -> void:
	Man.equipped_armor = item
	Toast.add("Set your armor to: " + item.name)
	Man.save_game("set armor")

func _cleanup_multiplayer() -> void:
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		if NetworkManager.update_players.is_connected(_on_update_players):
			NetworkManager.update_players.disconnect(_on_update_players)
		
		if multiplayer.peer_connected.is_connected(NetworkManager._player_joined):
			multiplayer.peer_connected.disconnect(NetworkManager._player_joined)
		
		if multiplayer.peer_disconnected.is_connected(NetworkManager._player_quit):
			multiplayer.peer_disconnected.disconnect(NetworkManager._player_quit)
		
		NetworkManager.players.clear()
		
		print(multiplayer.multiplayer_peer)
		if multiplayer.multiplayer_peer is EOSGMultiplayerPeer:
			multiplayer.multiplayer_peer.close()
			multiplayer.multiplayer_peer = null
		else:
			multiplayer.multiplayer_peer.disconnect_peer(multiplayer.multiplayer_peer.get_unique_id())
			multiplayer.multiplayer_peer = null

func _configure_focus_neighbors(grid: GridContainer) -> void:
	var buttons := grid.get_children()
	var cols := grid.columns
	
	for i in range(buttons.size()):
		var b := buttons[i]
		
		if i - cols >= 0:
			b.focus_neighbor_top = b.get_path_to(buttons[i - cols])
		if i + cols < buttons.size():
			b.focus_neighbor_bottom = b.get_path_to(buttons[i + cols])
		if i % cols != 0:
			b.focus_neighbor_left = b.get_path_to(buttons[i - 1])
		if (i % cols) != (cols - 1) and (i + 1) < buttons.size():
			b.focus_neighbor_right = b.get_path_to(buttons[i + 1])
	
	if buttons.size() > 0:
		buttons[0].grab_focus()

func _configure_focus_neighbors_with_back(grid: GridContainer) -> void:
	"""Configure grid focus neighbors AND link with Back button"""
	var buttons := grid.get_children()
	var cols := grid.columns
	var back_button = $UI/Main/Loadout/Back
	
	for i in range(buttons.size()):
		var b := buttons[i]
		
		# Up navigation
		if i - cols >= 0:
			b.focus_neighbor_top = b.get_path_to(buttons[i - cols])
		else:
			# Top row connects to Back button
			b.focus_neighbor_top = b.get_path_to(back_button)
		
		# Down navigation
		if i + cols < buttons.size():
			b.focus_neighbor_bottom = b.get_path_to(buttons[i + cols])
		
		# Left navigation
		if i % cols != 0:
			b.focus_neighbor_left = b.get_path_to(buttons[i - 1])
		
		# Right navigation
		if (i % cols) != (cols - 1) and (i + 1) < buttons.size():
			b.focus_neighbor_right = b.get_path_to(buttons[i + 1])
	
	# Configure Back button to connect to top row of grid
	if buttons.size() > 0:
		# Back button down goes to first item in grid
		back_button.focus_neighbor_bottom = back_button.get_path_to(buttons[0])
		back_button.focus_neighbor_top = back_button.get_path_to(buttons[0])
		
		# Calculate how many buttons are in the top row
		var top_row_count = min(cols, buttons.size())
		
		# Back button left/right navigate along top row
		if top_row_count > 1:
			back_button.focus_neighbor_left = back_button.get_path_to(buttons[top_row_count - 1])
			back_button.focus_neighbor_right = back_button.get_path_to(buttons[0])
		
		# Focus the Back button so user can immediately navigate
		back_button.grab_focus()

func _reset_loadout_back_button_focus() -> void:
	"""Reset Back button focus neighbors to default (for Main panel)"""
	var back_button = $UI/Main/Loadout/Back
	var armor_button = $UI/Main/Loadout/Panel/Main/ArmorButton
	var weapon_button = $UI/Main/Loadout/Panel/Main/WeaponButton
	var bestiary_button = $UI/Main/Loadout/Panel/Main/Bestiary
	
	# Reset to connect with Armor/Weapon buttons
	back_button.focus_neighbor_top = back_button.get_path_to(bestiary_button)
	back_button.focus_neighbor_bottom = back_button.get_path_to(armor_button)
	back_button.focus_neighbor_left = back_button.get_path_to(bestiary_button)
	back_button.focus_neighbor_right = back_button.get_path_to(armor_button)

# ============================================================================
# MODE/MAP SELECTOR HANDLERS
# ============================================================================

func _on_mode_selector_left_pressed() -> void:
	var index = Man.modes.find(Man.selected_mode)
	if index == -1:
		index = 0
	index = (index - 1 + Man.modes.size()) % Man.modes.size()
	Man.selected_mode = Man.modes[index]
	var mode_key = Man.selected_mode.to_lower()
	Man.selected_map = Man.maps[mode_key][0]
	update_mode_selector()

func _on_mode_selector_right_pressed() -> void:
	var index = Man.modes.find(Man.selected_mode)
	if index == -1:
		index = 0
	index = (index + 1) % Man.modes.size()
	Man.selected_mode = Man.modes[index]
	var mode_key = Man.selected_mode.to_lower()
	Man.selected_map = Man.maps[mode_key][0]
	update_mode_selector()

func _on_map_selector_left_pressed() -> void:
	var mode_key = Man.selected_mode.to_lower()
	var maps_for_mode = Man.maps[mode_key]
	var index = maps_for_mode.find(Man.selected_map)
	if index == -1:
		index = 0
	index = (index - 1 + maps_for_mode.size()) % maps_for_mode.size()
	Man.selected_map = maps_for_mode[index]
	update_mode_selector()

func _on_map_selector_right_pressed() -> void:
	var mode_key = Man.selected_mode.to_lower()
	var maps_for_mode = Man.maps[mode_key]
	var index = maps_for_mode.find(Man.selected_map)
	if index == -1:
		index = 0
	index = (index + 1) % maps_for_mode.size()
	Man.selected_map = maps_for_mode[index]
	update_mode_selector()

# Players screen mode/map selector handlers (same behavior as singleplayer)
func _on_players_mode_selector_left_pressed() -> void:
	_on_mode_selector_left_pressed()

func _on_players_mode_selector_right_pressed() -> void:
	_on_mode_selector_right_pressed()

func _on_players_map_selector_left_pressed() -> void:
	_on_map_selector_left_pressed()

func _on_players_map_selector_right_pressed() -> void:
	_on_map_selector_right_pressed()


# ============================================================================
# MISC HANDLERS
# ============================================================================

func _on_username_text_changed(new_text: String) -> void:
	if new_text == "":
		$Demoman/Username.visible = false
	else:
		$Demoman/Username.text = new_text
		$Demoman/Username.visible = true
	HAuth.display_name = new_text

func _on_dev_online_pressed() -> void:
	HAuth.login_devtool_async($"UI/Main/Multiplayer Buttons/Address".text, $"UI/Main/Multiplayer Buttons/Name".text)

func _on_address_text_submitted(new_text: String) -> void:
	$UI/Main/Join/Join.emit_signal("pressed")

func _on_userid_text_submitted(new_text: String) -> void:
	$"UI/Main/Online Join/Join".emit_signal("pressed")

func _on_copy_userid_pressed() -> void:
	DisplayServer.clipboard_set(HAuth.product_user_id)
	Toast.add("Copied your user ID to your clipboard. Send it to friends so they can join your game.")

# ============================================================================
# INPUT DETECTION (Controller/Keyboard/Mouse)
# ============================================================================

var using_controller := false

func _setup_input_detection() -> void:
	"""Setup the input detection system"""
	pass  # Already handled in _input

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		using_controller = false
		_update_button_focus_styles(false)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		using_controller = true
		_update_button_focus_styles(true)
	#elif event is InputEventKey:
		#using_controller = true
		#_update_button_focus_styles(true)

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER) and $UI/Main/Players.visible:
		print("yup")
		$UI/Main/Players/ChatBar.grab_focus()

func _update_button_focus_styles(show_focus: bool) -> void:
	"""Update all button focus styles based on input method"""
	for button in find_children("", "Button", true):
		if button is Button:
			if show_focus:
				button.add_theme_stylebox_override("focus", preload("res://scenes/outline but for ui lol.tres"))
			else:
				button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

# ============================================================================
# PLAYERS SCREEN FOCUS CONFIGURATION
# ============================================================================

func _configure_players_focus() -> void:
	"""Configure focus neighbors for the Players screen based on host/client status"""
	var start_button = $UI/Main/Players/Start
	var back_button = $UI/Main/Players/Back
	var copy_userid_button = $"UI/Main/Players/Copy UserID"
	var mode_selector = $"UI/Main/Players/Mode Selector"
	
	var is_host = multiplayer.is_server()
	
	if is_host:
		# Host can see mode selector and possibly copy userid
		if copy_userid_button.visible:
			# Start -> up -> Copy UserID
			start_button.focus_neighbor_top = start_button.get_path_to(copy_userid_button)
			copy_userid_button.focus_neighbor_bottom = copy_userid_button.get_path_to(start_button)
		else:
			# Start -> up -> mode selector
			var mode_left = mode_selector.get_node("Panel/Mode Selector/Left")
			start_button.focus_neighbor_top = start_button.get_path_to(mode_left)
	else:
		# Client - no special up navigation from Start
		start_button.focus_neighbor_top = NodePath()
	
	# Focus the Start button by default
	start_button.grab_focus()


func _on_flick_control_check_box_toggled(toggled_on: bool) -> void:
	Man.flick_control = toggled_on

func _on_chatbar_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if $UI/Main/Players/ChatBar.has_focus():
			$UI/Main/Players/ChatBar.text = ""
			$UI/Main/Players/ChatBar.release_focus()
			get_viewport().set_input_as_handled()
			
func add_message(message: String, player_name: String) -> void:
	if multiplayer.has_multiplayer_peer():
		print("[" + str(multiplayer.get_unique_id()) + "] Received message: ", message)
	var chat_message = load("res://scenes/chat_message.tscn").instantiate()
	chat_message.text = player_name + ": " + message
	chat_message.visible = true
	chat_message.modulate = Color(1, 1, 1, 1)
	$UI/Main/Players/Chat/VBoxContainer.add_child(chat_message, true)
	_write_chat_log(player_name, message)
	await get_tree().process_frame
	$UI/Main/Players/Chat.scroll_vertical = $UI/Main/Players/Chat.get_v_scroll_bar().max_value

func _write_chat_log(player_name: String, message: String) -> void:
	if not DirAccess.dir_exists_absolute("user://chats"):
		DirAccess.make_dir_absolute("user://chats")
		
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var current_log_path = "user://chats/%s.log" % timestamp
	var log_line = "[%s] %s: %s" % [
		Time.get_datetime_string_from_system(),
		player_name,
		message
	]
	var file = FileAccess.open(current_log_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_line(log_line)
		file.close()
		
func _on_chat_bar_submitted(new_text: String) -> void:
	$UI/Main/Players/ChatBar.text = ""
	$UI/Main/Players/ChatBar.release_focus()
	if new_text == "":
		return

	var player_name = NetworkManager.player_name if NetworkManager.player_name != "" else "Player"
	if multiplayer.has_multiplayer_peer():
		NetworkManager.send_message.rpc(new_text, player_name)
	else:
		add_message(new_text, player_name)

func _on_chat_bar_focus_entered() -> void:
	for child in $UI/Main/Players/Chat/VBoxContainer.get_children():
		child.visible = true
		child.modulate = Color(1, 1, 1, 1)
		for node in child.get_children():
			if node is Timer:
				node.stop()
	await get_tree().process_frame
	$UI/Main/Players/Chat.scroll_vertical = $UI/Main/Players/Chat.get_v_scroll_bar().max_value

func _on_chat_bar_focus_exited() -> void:
	for child in $UI/Main/Players/Chat/VBoxContainer.get_children():
		if child.should_fade:
			child.visible = true
			child.modulate = Color(1, 1, 1, 1)
			for node in child.get_children():
				if node is Timer:
					node.start()
		else:
			child.visible = false

func _on_online_join_userid_paste_pressed() -> void:
	$"UI/Main/Online Join/UserID".text = DisplayServer.clipboard_get()

func _on_lan_join_address_paste_pressed() -> void:
	$UI/Main/Join/Address.text = DisplayServer.clipboard_get()
