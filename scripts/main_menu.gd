extends Node2D

func _ready() -> void:
	$UI/Main/Title.text = ProjectSettings.get_setting("application/config/name")
	$UI/Main/Version.text = "v" + ProjectSettings.get_setting("application/config/version")
	if NetworkManager.dev_mode:
		$"UI/Main/Multiplayer Buttons/Online2".visible = true
		$"UI/Main/Multiplayer Buttons/Name".visible = true
		$"UI/Main/Multiplayer Buttons/Address".visible = true

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
	$UI/Main/Mode.text = "-- select your mode --"
	$UI/Main/Buttons.visible = true
	$UI/Main/Join.visible = false
	$"UI/Main/LAN Buttons".visible = false
	$UI/Main/Players.visible = false
	$Demoman/Username.visible = false
	$"UI/Main/Multiplayer Buttons".visible = false
	$Demoman/Username.text = "Player" 	
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		NetworkManager.update_players.disconnect(_on_update_players)
		multiplayer.peer_connected.disconnect(NetworkManager._player_joined)
		multiplayer.peer_disconnected.disconnect(NetworkManager._player_quit)
		
		multiplayer.multiplayer_peer.disconnect_peer(multiplayer.multiplayer_peer.get_unique_id())
		multiplayer.multiplayer_peer = null
		NetworkManager.players = []

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
	$UI/Main/Mode.text = "-- multiplayer game (host) --"
	_on_update_players(NetworkManager.players)

func _on_singleplayer_pressed() -> void:
	if multiplayer != null and multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.disconnect_peer(multiplayer.multiplayer_peer.get_unique_id())
		multiplayer.multiplayer_peer = null
		NetworkManager.players = []
	Man.start_game()

func _on_update_players(players: Array) -> void:
	var container = $UI/Main/Players/ScrollContainer/VBoxContainer
	for children in container.get_children():
		children.queue_free()

	for player in players:
		var entry = preload("res://scenes/multiplayer_player_entry.tscn").instantiate()
		entry.get_node("Label").text = player["username"]
		container.add_child(entry, true)
	$UI/Main/Players/Count.text = "Players (" + str(players.size()) + "/6)"

func _on_join_pressed() -> void:
	if $"UI/Main/Multiplayer Buttons/LineEdit".text != null and $"UI/Main/Multiplayer Buttons/LineEdit".text != "":
		NetworkManager.player_name = $"UI/Main/Multiplayer Buttons/LineEdit".text
	else:
		NetworkManager.player_name = "Player"
	Toast.add("Connecting to " + $UI/Main/Join/Address.text + "...")
	var result = await NetworkManager.join_server($UI/Main/Join/Address.text, NetworkManager.player_name)
	if result == false:
		Toast.add("Couldn't connect to the server.")
		_on_back_pressed()
	else:
		NetworkManager.update_players.connect(_on_update_players)
		Toast.add("Successfully connected to the server!")
		$UI/Main/Join.visible = false
		$UI/Main/Players.visible = true
		_on_update_players(NetworkManager.players)
		$UI/Main/Mode.text = "-- multiplayer game --"
		$UI/Main/Players/Start.visible = false
	
func _on_lan_join_pressed() -> void:
	$"UI/Main/LAN Buttons".visible = false
	$UI/Main/Join.visible = true
	$UI/Main/Mode.text = "-- enter server details --"

func _on_start_pressed() -> void:
	if multiplayer.is_server():
		Man.start_game.rpc()

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
	HAuth.login_anonymous_async($"UI/Main/Multiplayer Buttons/LineEdit".text)

func _on_address_text_submitted(new_text:String) -> void:
	$UI/Main/Join/Join.emit_signal("pressed")
