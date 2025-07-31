extends Node

var PORT: int = 1213
const DEFAULT_SERVER_IP: String = "127.0.0.1"
const MAX_PLAYERS: int = 5

var players = []
var player_name: String

signal player_joined(peer_id)
signal update_players(players)
signal player_quit(peer_id)

# -----------------------
# Connection Functions
# -----------------------

func join_server(address: String, username: String = "Player") -> bool:
	if not username.is_valid_identifier():
		username = "Player"
	player_name = username
	if address == "localhost":
		address = "127.0.0.1"
	var split_address = address.split(":")
	var valid_address: String
	var port: int
	if split_address.size() == 1:
		valid_address = split_address[0]
		port = PORT
	elif split_address.size() > 2:
		print("Too many address segments")
		return false
	else:
		valid_address = split_address[0]
		port = split_address[1].to_int()
	
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(valid_address, port)
	print("Connecting to " + valid_address + ":" + str(port))
	if error != OK:
		print("Error occurred while connecting: " + str(error))
		return false

	multiplayer.multiplayer_peer = peer
	multiplayer.server_disconnected.connect(server_disconnected)
	multiplayer.connection_failed.connect(connection_failed)

	# Wait a moment for connection to establish
	var ticks = 0
	var max_ticks = 100 # 10 seconds 
	while multiplayer.multiplayer_peer != null and (not multiplayer.multiplayer_peer.get_connection_status() == 2 or multiplayer.get_unique_id() == 1):
		if ticks >= max_ticks:
			Toast.add("Timed out.")
			print("Timed out, reached maximum ticks.")
			return false
		print("Stalling...")
		ticks += 1
		await get_tree().create_timer(0.1).timeout

	if multiplayer.multiplayer_peer == null:
		return false
	
	# Tell the server our username
	send_info.rpc(multiplayer.get_unique_id(), username)

	print("[" + str(multiplayer.get_unique_id()) + "] Connected to the server")
	return true


func host_server(port: int) -> bool:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(port, MAX_PLAYERS)
	if error != OK:
		print("Error while starting server: " + str(error))
		if get_tree().current_scene.get_node("Game") != null:
			get_tree().current_scene.get_node("Game").queue_free()
			get_tree().current_scene.add_child(preload("res://scenes/main_menu.tscn").instantiate(), true)
		else:
			if get_tree().current_scene.get_node("Main Menu") != null:
				get_tree().current_scene.get_node("Main Menu").queue_free()
			get_tree().current_scene.add_child(preload("res://scenes/main_menu.tscn").instantiate(), true)
		Toast.add("An error occurred while starting server.")
		return false

	print("Created server with IP " + DEFAULT_SERVER_IP + " on port " + str(PORT))
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_player_joined)
	multiplayer.peer_disconnected.connect(_player_quit)

	# Host joins as ID 1
	players.append({
		"id": 1,
		"username": player_name
	})
	update_players.emit(players)

	return true

# -----------------------
# Server-Side Logic
# -----------------------

func _player_joined(id: int) -> void:
	print("[server] Player joined with ID " + str(id))
	server_player_joined.rpc(id)

func _player_quit(id: int) -> void:
	print("[server] Player quit with ID " + str(id))
	for player in players:
		if str(player["id"]) == str(id):
			Toast.add.rpc(player["username"] + " left the server!")
	players = players.filter(func(p): return p["id"] != id)
	broadcast_players.rpc(players)
	player_quit.emit(id)

@rpc("any_peer", "call_local", "reliable")
func send_message(message: String, player_name: String) -> void:
	for player in get_tree().get_nodes_in_group("players"):
		player.add_message(message, player_name)

@rpc("any_peer", "call_local", "reliable")
func send_info(id: int, username: String) -> void:
	if multiplayer.is_server():
		print("[server] Received username from peer " + str(id) + ": " + username)
		# Add or update the player
		var existing = players.any(func(p): return p["id"] == id)
		if not existing:
			players.append({
				"id": id,
				"username": username
			})
			print("[server] Updated players list:")
			for p in players:
				print(p)
		Toast.add.rpc(username + " joined the server!")
		broadcast_players.rpc(players)
		update_players.emit(players)

# -----------------------
# Client-Side Notifications
# -----------------------

@rpc("authority", "call_local", "reliable")
func broadcast_players(new_list: Array) -> void:
	players = new_list
	update_players.emit(players)

@rpc("authority", "call_local", "reliable")
func server_player_joined(id: int) -> void:
	print("[" + str(multiplayer.get_unique_id()) + "] [client] Player joined: " + str(id))
	player_joined.emit(id)

@rpc("authority", "call_local", "reliable")
func server_player_quit(id: int) -> void:
	print("[" + str(multiplayer.get_unique_id()) + "] [client] Player quit: " + str(id))
	player_quit.emit(id)

# -----------------------
# Disconnect Handling
# -----------------------

func server_disconnected() -> void:
	print("Disconnected from server")
	Toast.add("Disconnected from the server.")
	multiplayer.server_disconnected.disconnect(server_disconnected)
	multiplayer.connection_failed.disconnect(connection_failed)
	multiplayer.multiplayer_peer = null
	if get_tree().current_scene.get_node("Game") != null:
		get_tree().current_scene.get_node("Game").queue_free()
		get_tree().current_scene.add_child(preload("res://scenes/main_menu.tscn").instantiate(), true)
	else:
		if get_tree().current_scene.get_node("Main Menu") != null:
			get_tree().current_scene.get_node("Main Menu").queue_free()
		get_tree().current_scene.add_child(preload("res://scenes/main_menu.tscn").instantiate(), true)
		
func connection_failed() -> void:
	print("Connection failed")
	Toast.add("Connection failed.")
	multiplayer.server_disconnected.disconnect(server_disconnected)
	multiplayer.connection_failed.disconnect(connection_failed)
	multiplayer.multiplayer_peer = null
	if get_tree().current_scene.get_node("Game") != null:
		get_tree().current_scene.get_node("Game").queue_free()
		get_tree().current_scene.add_child(preload("res://scenes/main_menu.tscn").instantiate(), true)
	else:
		if get_tree().current_scene.get_node("Main Menu") != null:
			get_tree().current_scene.get_node("Main Menu").queue_free()
		get_tree().current_scene.add_child(preload("res://scenes/main_menu.tscn").instantiate(), true)
		
