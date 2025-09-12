extends Node2D

var click1 = preload("res://assets/sounds/click1.wav")
var click2 = preload("res://assets/sounds/click.wav")

func play_ui_sfx(stream: AudioStream) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.bus = "SFX"
	sfx.volume_db = -10.0
	add_child(sfx)

	sfx.play()

	sfx.finished.connect(func():
		sfx.queue_free()
	)

func _connect_button_sfx(button: Button):
	button.mouse_entered.connect(func():
		play_ui_sfx(click2)
	)
	button.pressed.connect(func():
		play_ui_sfx(click1)
	)

func _ready() -> void:
	Man.set_rich_presence("#In_MainMenu")
	for button in find_children("", "Button", true):
		if button is Button:
			_connect_button_sfx(button)

	#$UI/Main/Title.text = "Myrkwood: Offshoot" #ProjectSettings.get_setting("application/config/name")
	$UI/Main/Version.text = "v" + ProjectSettings.get_setting("application/config/version")

	if NetworkManager.dev_mode:
		$"UI/Main/Multiplayer Buttons/Online2".visible = true
		$"UI/Main/Multiplayer Buttons/Name".visible = true
		$"UI/Main/Multiplayer Buttons/Address".visible = true

	print('HEY APRIL WERE CONNECTING')
	if NetworkManager.eos_is_initialized:
		_eos_initialized()
	else:
		HPlatform.platform_created.connect(_eos_initialized)
	$UI/Main/Options/General/CheckBox.button_pressed = Man.fullscreen
	$UI/Main/Options/General/HSlider.value = Man.sfx_volume

func init_online_buttons() -> void:
	$"UI/Main/Online Buttons".visible = true

func _eos_initialized() -> void:
	print('HEY APRIL WERE _eos_initialized')
	HAuth.logged_in.connect(_eos_on_logged_in)
	$"UI/Main/Multiplayer Buttons/Online".disabled = false

func _eos_on_logged_in() -> void:
	print('HEY APRIL WERE _eos_on_logged_in -> ' + HAuth.product_user_id)
	if $"UI/Main/Multiplayer Buttons".visible == true:
		$"UI/Main/Multiplayer Buttons".visible = false
		init_online_buttons()

func _on_online_host_pressed() -> void:
	NetworkManager.host_online_server()
	NetworkManager.update_players.connect(_on_update_players)
	Toast.add("Players can now connect to your game by joining it!")
	
	$"UI/Main/Online Buttons".visible = false
	$UI/Main/Players.visible = true
	$UI/Main/Mode.text = "-- multiplayer game (host) --"
	_on_update_players(NetworkManager.players)

func _on_lan_pressed() -> void:
	$UI/Main/Buttons.visible = false
	$"UI/Main/Multiplayer Buttons".visible = false
	$"UI/Main/LAN Buttons".visible = true
	$UI/Main/Mode.text = "-- select your multiplayer mode --"
	if $"UI/Main/Multiplayer Buttons/LineEdit".text != "":
		$Demoman/Username.visible = true
		$Demoman/Username.text = $"UI/Main/Multiplayer Buttons/LineEdit".text

func _on_multiplayer_pressed() -> void:
	$UI/Main/Buttons.visible = false
	$"UI/Main/Multiplayer Buttons".visible = true

func _on_back_pressed() -> void:
	if $UI/Main/Options.visible and not $UI/Main/Options/General.visible: # doing this instead of adding something that'd make this way more easier for me in the future.
		$UI/Main/Options/Controls.visible = false
		$UI/Main/Options/General.visible = true
	else:
		$UI/Main/Mode.text = "-- select your mode --"
		$UI/Main/Buttons.visible = true
		$"UI/Main/Singleplayer Mode Selector".visible = false
		$UI/Main/Join.visible = false
		$"UI/Main/LAN Buttons".visible = false
		$UI/Main/Players.visible = false
		$UI/Main/Options.visible = false
		$Demoman/Username.visible = false
		$"UI/Main/Multiplayer Buttons".visible = false
		$"UI/Main/Online Join".visible = false
		$"UI/Main/Online Buttons".visible = false
		$Demoman/Username.text = "Player"

	if multiplayer != null and multiplayer.has_multiplayer_peer():
		if NetworkManager.update_players.is_connected(_on_update_players):
			NetworkManager.update_players.disconnect(_on_update_players)

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

func _on_host_pressed() -> void:
	if $"UI/Main/Multiplayer Buttons/LineEdit".text != null and $"UI/Main/Multiplayer Buttons/LineEdit".text != "":
		NetworkManager.player_name = $"UI/Main/Multiplayer Buttons/LineEdit".text
	else:
		NetworkManager.player_name = "Player"
		$Demoman/Username.visible = true
		$Demoman/Username.text = "Player"

	NetworkManager.host_server(NetworkManager.PORT)
	NetworkManager.update_players.connect(_on_update_players)
	Toast.add("Players can now connect to your game by joining it!")
	#get_tree().change_scene_to_file("res://scenes/map.tscn")
	$"UI/Main/LAN Buttons".visible = false
	$UI/Main/Players.visible = true
	$"UI/Main/Players/Copy UserID".visible = false
	$UI/Main/Mode.text = "-- multiplayer game (host) --"
	_on_update_players(NetworkManager.players)

func _on_singleplayer_pressed() -> void:
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		if multiplayer.multiplayer_peer is EOSGMultiplayerPeer:
			multiplayer.multiplayer_peer.close()
		else:
			multiplayer.multiplayer_peer.disconnect_peer(multiplayer.multiplayer_peer.get_unique_id())
			multiplayer.multiplayer_peer = null
		NetworkManager.players = []
	#Man.start_game()
	update_mode_selector()
	$"UI/Main/Singleplayer Mode Selector".visible = true
	$"UI/Main/Buttons".visible = false
	
func update_mode_selector() -> void:
	$"UI/Main/Singleplayer Mode Selector/Panel/Mode Selector/Label".text = Man.selected_mode 
	$"UI/Main/Singleplayer Mode Selector/Panel/Map Selector/Label".text = Man.selected_map 
	$"UI/Main/Multiplayer Mode Selector/Panel/Mode Selector/Label".text = Man.selected_mode 
	$"UI/Main/Multiplayer Mode Selector/Panel/Map Selector/Label".text = Man.selected_map 
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		NetworkManager.send_mode.rpc(Man.selected_mode, Man.selected_map)
		NetworkManager.update_players.emit(NetworkManager.players)

func _on_update_players(players: Array) -> void:
	print("updating players")
	Man.set_rich_presence("#In_Lobby")
	Man.set_rich_presence_value("players", str(NetworkManager.players.size()))
	var container = $UI/Main/Players/ScrollContainer/VBoxContainer
	for children in container.get_children():
		children.queue_free()

	for player in players:
		var entry = preload("res://scenes/multiplayer_player_entry.tscn").instantiate()
		entry.get_node("Label").text = player["username"]
		container.add_child(entry, true)
	$UI/Main/Players/Count.text = "Players (" + str(players.size()) + "/6)"
	$"UI/Main/Players/Details".text = "Mode: " + Man.selected_mode + "\nMap: " + Man.selected_map
	$"UI/Main/Players/Mode Selector/Panel/Mode Selector/Label".text = Man.selected_mode
	$"UI/Main/Players/Mode Selector/Panel/Map Selector/Label".text = Man.selected_map
 	
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
	else:
		NetworkManager.update_players.connect(_on_update_players)
		Toast.add("Successfully connected to the server!")
		$UI/Main/Join.visible = false
		$"UI/Main/Online Join".visible = false
		$UI/Main/Players.visible = true
		_on_update_players(NetworkManager.players)
		$UI/Main/Mode.text = "-- multiplayer game --"
		$UI/Main/Players/Start.visible = false
		$"UI/Main/Players/Mode Selector".visible = false
		$"UI/Main/Players/Copy UserID".visible = false

func _on_join_pressed() -> void:
	if $"UI/Main/Multiplayer Buttons/LineEdit".text != null and $"UI/Main/Multiplayer Buttons/LineEdit".text != "":
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
		_on_back_pressed()
	else:
		NetworkManager.update_players.connect(_on_update_players)
		Toast.add("Successfully connected to the server!")
		$UI/Main/Join.visible = false
		$UI/Main/Players.visible = true
		_on_update_players(NetworkManager.players)
		$UI/Main/Mode.text = "-- multiplayer game --"
		$UI/Main/Players/Start.visible = false
		$"UI/Main/Players/Mode Selector".visible = false
		$"UI/Main/Players/Copy UserID".visible = false
	
func _on_lan_join_pressed() -> void:
	$"UI/Main/LAN Buttons".visible = false
	$UI/Main/Join.visible = true
	$UI/Main/Mode.text = "-- enter server details --"

func _on_online_join_pressed() -> void:
	$"UI/Main/Online Buttons".visible = false
	$"UI/Main/Online Join".visible = true

func _on_start_pressed() -> void:
	if multiplayer.is_server():
		play_ui_sfx(preload("res://assets/sounds/success.wav"))
		Man.start_game.rpc(Man.selected_mode, Man.selected_map)
		Man.set_rich_presence("#Multiplayer")
		Man.set_rich_presence_value("map", Man.selected_map)

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_username_text_changed(new_text: String) -> void:
	if new_text == "":
		$Demoman/Username.visible = false
	else:
		$Demoman/Username.text = new_text
		$Demoman/Username.visible = true

func _on_dev_online_pressed() -> void:
	HAuth.login_devtool_async($"UI/Main/Multiplayer Buttons/Address".text, $"UI/Main/Multiplayer Buttons/Name".text)

func _on_online_pressed() -> void:
	if not NetworkManager.steam_enabled:
		if HAuth.product_user_id == "":
			var result = await HAuth.login_anonymous_async($"UI/Main/Multiplayer Buttons/LineEdit".text)
			if result == false:
				Toast.add("An error occurred while attempting to sign in.")
				play_ui_sfx(preload("res://assets/sounds/deny.wav"))
		else:
			$"UI/Main/Multiplayer Buttons".visible = false
			init_online_buttons()
	else:
		var params = EOS.Connect.LoginOptions.new()
		var creds = EOS.Connect.Credentials.new()
		creds.type = EOS.ExternalCredentialType.SteamSessionTicket
		var ticket = Steam.getAuthSessionTicket()
		var buffer = ticket["buffer"]
		
		creds.token = buffer.hex_encode()
		
		params.credentials = creds
		var result = await HAuth.login_game_services_async(params)
		if result == false:
			Toast.add("An error occurred while attempting to sign in.")
			play_ui_sfx(preload("res://assets/sounds/deny.wav"))
		print("sure, this works, why not?")

func _on_address_text_submitted(new_text:String) -> void:
	$UI/Main/Join/Join.emit_signal("pressed")

func _on_userid_text_submitted(new_text:String) -> void:
	$"UI/Main/Online Join/Join".emit_signal("pressed")

func _on_copy_userid_pressed() -> void:
	DisplayServer.clipboard_set(HAuth.product_user_id)
	Toast.add("Copied your user ID to your clipboard. Send it to friends so they can join your game.")

func _on_options_pressed() -> void:
	$UI/Main/Buttons.visible = false
	$UI/Main/Options.visible = true

func _on_fullscreen_check_box_toggled(toggled_on: bool) -> void:
	var mode: int = 0
	if toggled_on:
		mode = 3
	DisplayServer.window_set_mode(mode)
	Man.fullscreen = toggled_on

func _on_volume_slider_drag_ended(value_changed: bool) -> void:
	play_ui_sfx(preload("res://assets/sounds/f_slash.wav"))
	
func _on_volume_slider_value_changed(value: float) -> void:
	Man.sfx_volume = value
	if value <= 0.0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), true)
	else:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), false)
		var db_value = lerp(-55.0, 0.0, value / 100.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db_value)

func _on_controls_pressed() -> void:
	$UI/Main/Options/General.visible = false
	$UI/Main/Options/Controls.visible = true
	var keybind_scene = preload("res://scenes/keybind.tscn")
	for children in $UI/Main/Options/Controls/ScrollContainer/VBoxContainer.get_children():
		children.queue_free()
	for control in Man.controls.keys():
		var key = keybind_scene.instantiate()
		key.get_node("HBoxContainer/Label").text = Man.controls[control]
		key.get_node("HBoxContainer/Key").keycode = str(control)
		$UI/Main/Options/Controls/ScrollContainer/VBoxContainer.add_child(key)

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
	
func _on_mode_selector_start_pressed() -> void:
	play_ui_sfx(preload("res://assets/sounds/success.wav"))
	Man.start_game(Man.selected_mode, Man.selected_map)
	Man.set_rich_presence("#Singleplayer")
	Man.set_rich_presence_value("map", Man.selected_map)
