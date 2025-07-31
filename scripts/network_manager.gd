extends Node

var PORT: int = 1213
const DEFAULT_SERVER_IP: String = "127.0.0.1"
const MAX_PLAYERS: int = 5

var players = []
var player_name: String

signal player_joined(peer_id)
signal update_players(players)
signal player_quit(peer_id)
signal eos_initialized()

# EOSG Setup
func _ready() -> void:
	HLog.log_level = HLog.LogLevel.DEBUG

	var init_opts = EOS.Platform.InitializeOptions.new()
	init_opts.product_name = "Myrkwood: Offshoot"
	init_opts.product_version = ProjectSettings.get_setting("application/config/version")

	var create_opts = EOS.Platform.CreateOptions.new()
	create_opts.product_id = "63a9c00ce38d4464a882852da063d7c6"
	create_opts.sandbox_id = "941ad0e8d9d0466db96408d76d1c4b30"
	create_opts.deployment_id = "70b48dd2b5fe4a6e9a1d578b39e04c9e"
	create_opts.client_id = "xyza7891b4a4I1ezxh8bW3DEzjIz8QNx"
	create_opts.client_secret = "D0V9SSeiYeEfsfePfz5sxPmG+cQBURZ2Ym0otyy7suA"

	# openssl rand -hex 64
	create_opts.encryption_key = "471971b30a7e708cb2284a16524a3d34da6ea3d4af33ebd4c46dfb7f7d7d6c62fe5cc7e6f2934301623adf1b44d3a4d8f506a06188839d4e51b781f60b0dbf40"

	# enable overlay on windows only for some reason??
	if OS.get_name() == "Windows":
		HAuth.auth_login_flags = EOS.Auth.LoginFlags.None
		create_opts.flags = EOS.Platform.PlatformFlags.WindowsEnableOverlayOpengl

	# set up SDK
	var init_res := await HPlatform.initialize_async(init_opts)
	if not EOS.is_success(init_res):
		printerr("Failed to initialize EOS SDK: ", EOS.result_str(init_res))
		# TODO: consequences
		return
	
	var create_success := await HPlatform.create_platform_async(create_opts)
	if not create_success:
		printerr("Failed to create EOS Platform")
		# TODO: consequences
		return

	# Setup Logs from EOS
	HPlatform.log_msg.connect(_on_eos_log_msg)
	# This will control which logs you get from EOS SDK
	var log_res := HPlatform.set_eos_log_level(EOS.Logging.LogCategory.AllCategories, EOS.Logging.LogLevel.Verbose)
	if not EOS.is_success(log_res):
		printerr("Failed to set logging level")
		# TODO: consequences
		return

	HAuth.logged_in.connect(_on_eos_logged_in)

	eos_initialized.emit()

	# During development use the devauth tool to login
	#HAuth.login_devtool_async("localhost:4545", "CREDENTIAL_NAME_HERE")

	# Only on mobile device (Login without any credentials)
	# await HAuth.login_anonymous_async()

func _on_eos_logged_in():
	print("EOS logged in successfully: product_user_id=%s" % HAuth.product_user_id)

func _on_eos_log_msg(msg: EOS.Logging.LogMessage) -> void:
	print("SDK %s | %s" % [msg.category, msg.message])

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
		
