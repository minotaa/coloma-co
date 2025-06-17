extends Node2D

var rng = RandomNumberGenerator.new()
var wave: int = 0
var gold: int = 0
var bombrats_left: int = 0
var started: bool = false

var bombrat = preload("res://scenes/bombrat.tscn")
var slime = preload("res://scenes/slime.tscn")
var player_scene = preload("res://scenes/player.tscn")

@onready var spawner_layer = $Spawner

func _ready() -> void:
	if not multiplayer.has_multiplayer_peer():
		# Singleplayer: spawn one player normally
		var p = player_scene.instantiate()
		p.name = "Player"
		call_deferred("add_child", p, true)
		spawn_wave()
		return

	# Multiplayer: spawn players from the current list
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		for player_data in NetworkManager.players:
			var peer_id = player_data["id"]
			var p = player_scene.instantiate()
			p.name = str(peer_id)
			p.get_node("Username").text = player_data["username"]
			p.global_position = Vector2(0,0)
			p.set_multiplayer_authority(peer_id)
			call_deferred("add_child", p, true)

		# Connect signals for player joins and quits
		NetworkManager.player_joined.connect(player_joined)
		NetworkManager.player_quit.connect(player_quit)

		# Only the server spawns waves
		spawn_wave()
		started = true

func _process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	bombrats_left = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.entity.id == 1:
			bombrats_left += 1

	if bombrats_left <= 0 and started == true:
		Toast.add.rpc("Wave complete!")
		spawn_wave()

@rpc("authority", "call_remote")
func update_wave(wave: int) -> void:
	self.wave = wave
	
@rpc("authority", "call_remote")
func update_gold(gold: int) -> void:
	self.gold = gold

func player_joined(id) -> void:
	if not multiplayer.is_server():
		return

	var player = player_scene.instantiate()
	player.name = str(id)
	call_deferred("add_child", player, true)

func player_quit(id) -> void:
	if not multiplayer.is_server():
		return

	print("[" + str(multiplayer.multiplayer_peer.get_unique_id()) + "] removing " + str(id) + " from the game")
	for child in get_children():
		if child.name == str(id):
			child.call_deferred("queue_free")

func spawn_wave() -> void:
	wave += 1
	update_wave.rpc(wave)
	match wave:
		1:
			spawn_bombrat("north")
			spawn_bombrat("south")
		2:
			spawn_bombrat("north")
			spawn_bombrat("south")
			spawn_bombrat("west")
			spawn_bombrat("east")
		3:
			spawn_bombrat("north")
			spawn_bombrat("south")
			spawn_bombrat("west")
			spawn_bombrat("east")
			spawn_bombrats(2)
		4:
			spawn_bombrat("north")
			spawn_bombrat("south")
			spawn_bombrat("west")
			spawn_bombrat("east")
			spawn_bombrats(3)
			spawn_slime("north")
			spawn_slime("south")
		5:
			spawn_bombrat("north")
			spawn_bombrat("south")
			spawn_bombrat("west")
			spawn_bombrat("east")
			spawn_bombrats(5)
			spawn_slimes(3)
		_:
			spawn_bombrat("north")
			spawn_bombrats(6 + wave)
			spawn_slimes(4 + int(wave / 2))

func spawn_bombrats(count: int) -> void:
	for i in count:
		await get_tree().create_timer(1.5).timeout
		var directions = ["north", "south", "west", "east"]
		spawn_bombrat(directions.pick_random())

func spawn_slimes(count: int) -> void:
	for i in count:
		await get_tree().create_timer(1.5).timeout
		var directions = ["north", "south", "west", "east"]
		spawn_slime(directions.pick_random())

func spawn_slime(direction: String) -> void:
	var matching_cells: Array[Vector2i] = []
	var cells = spawner_layer.get_used_cells()

	for cell_loc in cells:
		var data = spawner_layer.get_cell_tile_data(cell_loc)
		if not data:
			continue
		if data.get_custom_data("type") != "corner":
			continue

		match direction:
			"north":
				if cell_loc.y < 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"south":
				if cell_loc.y > 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"west":
				if cell_loc.x < 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)
			"east":
				if cell_loc.x > 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)

	if matching_cells:
		var selected_cell = matching_cells.pick_random()
		var spawn_pos = spawner_layer.map_to_local(selected_cell) + Vector2(spawner_layer.tile_set.tile_size) / 2
		var s = slime.instantiate()
		s.global_position = spawn_pos
		add_child(s, true)

func spawn_bombrat(direction: String) -> void:
	var matching_cells: Array[Vector2i] = []
	var cells = spawner_layer.get_used_cells()

	for cell_loc in cells:
		var data = spawner_layer.get_cell_tile_data(cell_loc)
		if not data:
			continue
		if data.get_custom_data("type") != "main":
			continue

		match direction:
			"north":
				if cell_loc.y < 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"south":
				if cell_loc.y > 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"west":
				if cell_loc.x < 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)
			"east":
				if cell_loc.x > 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)

	if matching_cells:
		var selected_cell = matching_cells.pick_random()
		var spawn_pos = spawner_layer.map_to_local(selected_cell) + Vector2(spawner_layer.tile_set.tile_size) / 2
		var bomb = bombrat.instantiate()
		bomb.global_position = spawn_pos
		print(spawn_pos)
		add_child(bomb, true)
		#$MultiplayerSpawner.spawn()
