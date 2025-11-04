extends Node2D

var smoke_scene = preload("res://scenes/smoke.tscn")
var player_scene = preload("res://scenes/player.tscn")
var filler_tile = Vector2i(3, 0)

var valid_rooms: Array[String] = [
	"res://scenes/levels/dungeon/plains_tall_hallway.tscn",
	"res://scenes/levels/dungeon/plains_bigger_hallway.tscn",
	"res://scenes/levels/dungeon/plains_curvy_way.tscn",
	"res://scenes/levels/dungeon/plains_loop.tscn",
	"res://scenes/levels/dungeon/plains_zig_zag_hallway.tscn"
]

var start_rooms = {
	"Plains": "res://scenes/levels/dungeon/plains_start_room.tscn"
}

var shop_rooms = {
	"Plains": "res://scenes/levels/dungeon/plains_shop.tscn"
}

var waves = []

# Enemy scene preloads
var rapid_bauble = preload("res://scenes/rapid_bauble.tscn")
var angry_bauble = preload("res://scenes/angry_bauble.tscn")
var bombrat = preload("res://scenes/bombrat.tscn")
var big_bombrat = preload("res://scenes/big_bombrat.tscn")
var slime = preload("res://scenes/slime.tscn")
var mother_slime = preload("res://scenes/mother_slime.tscn")
var poison_slime = preload("res://scenes/poison_slime.tscn")
var bauble = preload("res://scenes/bauble.tscn")
var crabman = preload("res://scenes/crabman.tscn")
var gem = preload("res://scenes/gem.tscn")
var shopkeeper = preload("res://scenes/shopkeeper.tscn")
var ghost = preload("res://scenes/ghost.tscn")
var gunk_slime = preload("res://scenes/gunk_slime.tscn")
var explosive_bauble = preload("res://scenes/explosive_bauble.tscn")

# Room tracking system
var rooms = {}  # Dictionary: room_id -> {bounds: Rect2i, cells: Array[Vector2i], filler_area: Rect2i}
var next_room_id = 0
var deleted_rooms = {}  # Dictionary: room_id -> {bounds: Rect2i, filler_area: Rect2i} - rooms converted to filler

# Shop system
var shop_active = false
var shop_timer = 0.0
var shop_duration = 60.0
var current_shopkeepers = []

# Wave system
var completed_rooms = 0
var current_wave_index = 0
var current_subwave_index = 0
var completed_subwaves = 0  # Track actually completed subwaves
var spawning_active = false
var currently_spawning = false
var room_ids_in_order = []
var kills = {}

# Void detection
var void_check_counter = 0
var wave_check_counter = 0

@onready var spawner_layer = $Spawner
@onready var decoration_layer = $Tiles

func play_music(stream: AudioStream, looping: bool = false) -> AudioStreamPlayer:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.bus = "Music"
	sfx.volume_db = -10.0
	add_child(sfx)

	sfx.play()

	if looping:
		sfx.finished.connect(func():
			sfx.play()
		)
	else:
		sfx.finished.connect(func():
			sfx.queue_free()
		)
	
	return sfx

var equipment = {}
@rpc("any_peer", "call_local", "reliable") 
func send_equipment(name: String, equipped_weapon: int, equipped_armor: int) -> void:
	equipment[str(name)] = {}
	equipment[str(name)]["equipped_weapon"] = equipped_weapon
	equipment[str(name)]["equipped_armor"] = equipped_armor
	
@rpc("authority", "call_local")
func add_gold(id: String, amount: int) -> void:
	if equipment[id]["equipped_armor"] == 13:
		amount *= 2
	if multiplayer.has_multiplayer_peer():
		get_node(id).add_gold_notification.rpc_id(int(id), amount)
	else:
		get_node(id).add_gold_notification(amount)
	get_node(id).gold_collected += amount
	get_node(id).total_gold_collected += amount

func add_kill(player_id: String, enemy_type: String) -> void:
	if not kills.has(player_id):
		kills[player_id] = {}
	if not kills[player_id].has(enemy_type):
		kills[player_id][enemy_type] = 0
	kills[player_id][enemy_type] += 1
	get_node(str(player_id)).kills += 1
	get_node(str(player_id)).total_kills += 1
	if multiplayer.has_multiplayer_peer():
		update_kills.rpc(kills)

@rpc("authority", "call_remote")
func update_kills(kills: Dictionary) -> void:
	self.kills = kills

func end() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()

@rpc("any_peer", "call_local")
func are_we_sure_everyone_is_dead() -> void:
	if is_server_or_singleplayer():
		for player in get_tree().get_nodes_in_group("players"):
			if player.lives > 0:
				return
		if multiplayer.has_multiplayer_peer():
			Toast.add.rpc("Everyone has died! The game is over.")
		else:
			Toast.add("Everyone has died! The game is over.")
		end()

@rpc("authority", "call_local")
func reset() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		player.reset_game()
	completed_rooms = 0
	current_wave_index = 0
	current_subwave_index = 0
	completed_subwaves = 0
	spawning_active = false
	currently_spawning = false
	rooms = {}
	next_room_id = 0
	deleted_rooms = {}
	room_ids_in_order = []
	$TileMapLayer.clear()
	
	# Only spawn the start room initially
	var start_id: int
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		merge_room.rpc(start_rooms[Man.selected_map], Vector2(0, 0))
		start_id = last_room_id
	else:
		merge_room(start_rooms[Man.selected_map], Vector2(0, 0))
		start_id = last_room_id
	room_ids_in_order = [start_id]
	
	# Position barrier at the north exit of start room to indicate next room spawn
	position_barrier_at_room_exit(start_id, "north")
	
	if is_server_or_singleplayer():
		countdown_and_spawn_room()
	return

func _ready() -> void:
	play_music(preload("res://assets/sounds/MO_ingame_v2.wav"), true)
	var file = FileAccess.open("res://waves.json", FileAccess.READ)
	if not file:
		push_error("Failed to load waves.json")
		return
	waves = JSON.parse_string(file.get_as_text())
	file.close()
	
	$TileMapLayer.clear()
	
	# Only spawn the start room initially
	var start_id: int
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		merge_room.rpc(start_rooms[Man.selected_map], Vector2(0, 0))
		start_id = last_room_id
	else:
		merge_room(start_rooms[Man.selected_map], Vector2(0, 0))
		start_id = last_room_id
	room_ids_in_order = [start_id]
	
	# Position barrier at the north exit of start room to indicate next room spawn
	position_barrier_at_room_exit(start_id, "north")
	
	if not multiplayer.has_multiplayer_peer():
		# Singleplayer: spawn one player normally
		var p = player_scene.instantiate()
		p.name = "Player"
		p.type = "Dungeon"
		p.global_position = Vector2(128, 128)
		call_deferred("add_child", p, true)
		
		var smoke = smoke_scene.instantiate()
		smoke.global_position = p.global_position
		smoke.emitting = true
		add_child(smoke, true)
		p.setup_ui("Dungeon")
	
	# Multiplayer: spawn players from the current list
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var radius = 30  # Radius of the spawn circle
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		var spawn_center = Vector2(128, 128)  # Center of start room

		for player_data in NetworkManager.players:
			var peer_id = player_data["id"]
			var p = player_scene.instantiate()
			p.name = str(peer_id)
			p.type = "Dungeon"
			p.get_node("Username").text = player_data["username"]

			# Random angle around the circle
			var angle = rng.randf_range(0.0, TAU)
			var offset = Vector2(cos(angle), sin(angle)) * radius
			p.global_position = spawn_center + offset
			call_deferred("add_child", p, true)
			
			var smoke = smoke_scene.instantiate()
			smoke.global_position = p.global_position
			smoke.emitting = true
			add_child(smoke, true)
		
		await get_tree().create_timer(1.0).timeout
		for player in get_tree().get_nodes_in_group("players"):
			player.setup_ui.rpc("Dungeon")
			print("Setting Dungeon UI for " + player.name + ".")
	
	# Start countdown to spawn first room
	if is_server_or_singleplayer():
		countdown_and_spawn_room()
	return

func _physics_process(delta: float) -> void:
	# Void check
	void_check_counter += 1
	if void_check_counter >= 30:
		void_check_counter = 0
		check_players_for_void()

	# Wave or shop checks
	if is_server_or_singleplayer():
		if shop_active:
			shop_timer -= delta
			if int(shop_timer) % 1 == 0:
				update_barrier_label_for_shop()
			if shop_timer <= 0:
				end_shop_phase()
		else:
			wave_check_counter += 1
			if wave_check_counter >= 30:
				wave_check_counter = 0
				check_wave_completion()

func is_server_or_singleplayer() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

var last_room_id: int
func get_last_room_id() -> int:
	return last_room_id

# NEW: Synchronize room data to all clients
@rpc("authority", "call_local")
func sync_room_data(rooms_data: Dictionary, deleted_rooms_data: Dictionary, room_ids_order: Array) -> void:
	rooms = rooms_data
	deleted_rooms = deleted_rooms_data
	room_ids_in_order = room_ids_order
	print("[SYNC] Room data synchronized - Active rooms: ", rooms.keys(), " Order: ", room_ids_in_order)

@rpc("authority", "call_local")
func merge_room(room_path: String, offset: Vector2i) -> void:
	var room = load(room_path).instantiate()
	var room_layer = room.get_node_or_null("TileMapLayer")
	var room_spawner = room.get_node_or_null("Spawner")
	var room_decoration = room.get_node_or_null("Decorations")
	
	if not room_layer:
		print("[GENERATOR] Room has no TileMapLayer, skipping")
		return
	
	# Get room bounds for filler calculation
	var room_cells = room_layer.get_used_cells()
	if room_cells.is_empty():
		print("[GENERATOR] Room has no cells, skipping")
		room.queue_free()
		return
	
	# Find the bounds of the room
	var min_pos = room_cells[0]
	var max_pos = room_cells[0]
	for cell in room_cells:
		min_pos.x = min(min_pos.x, cell.x)
		min_pos.y = min(min_pos.y, cell.y)
		max_pos.x = max(max_pos.x, cell.x)
		max_pos.y = max(max_pos.y, cell.y)
	
	# Apply offset to bounds
	min_pos += offset
	max_pos += offset
	
	# Fill 24-tile radius around the room with filler tiles
	var filler_radius = 24
	var filler_min = Vector2i(min_pos.x - filler_radius, min_pos.y - filler_radius)
	var filler_max = Vector2i(max_pos.x + filler_radius, max_pos.y + filler_radius)
	
	# Set filler tiles (only where there are no existing tiles)
	for x in range(filler_min.x, filler_max.x + 1):
		for y in range(filler_min.y, filler_max.y + 1):
			var pos = Vector2i(x, y)
			# Only set filler if the cell is empty (source_id == -1 means empty)
			if $TileMapLayer.get_cell_source_id(pos) == -1:
				$TileMapLayer.set_cell(pos, 0, filler_tile)  # Assuming source_id 0 for filler
	
	# Copy room tiles (this overwrites filler tiles where the room exists)
	var placed_cells = []
	for cell in room_cells:
		var source_id = room_layer.get_cell_source_id(cell)
		var atlas_coords = room_layer.get_cell_atlas_coords(cell)
		if source_id == -1:
			continue
		var final_pos = cell + offset
		$TileMapLayer.set_cell(final_pos, source_id, atlas_coords)
		placed_cells.append(final_pos)
	
	# Copy spawner tiles if the room has a Spawner layer
	if room_spawner:
		var spawner_cells = room_spawner.get_used_cells()
		for cell in spawner_cells:
			var source_id = room_spawner.get_cell_source_id(cell)
			var atlas_coords = room_spawner.get_cell_atlas_coords(cell)
			if source_id == -1:
				continue
			var final_pos = cell + offset
			spawner_layer.set_cell(final_pos, source_id, atlas_coords)

	# Copy decorations tiles if the room has a Decorations layer
	if room_decoration:
		var decoration_cells = room_decoration.get_used_cells()
		for cell in decoration_cells:
			var source_id = room_decoration.get_cell_source_id(cell)
			var atlas_coords = room_decoration.get_cell_atlas_coords(cell)
			if source_id == -1:
				continue
			var final_pos = cell + offset
			decoration_layer.set_cell(final_pos, source_id, atlas_coords)
	$TileMapLayer._update_all_navigation_cells()
	
	# Store room data for tracking
	var room_id = next_room_id
	next_room_id += 1
	rooms[room_id] = {
		"bounds": Rect2i(min_pos, max_pos - min_pos + Vector2i.ONE),
		"cells": placed_cells,
		"filler_area": Rect2i(filler_min, filler_max - filler_min + Vector2i.ONE)
	}
	
	var exits_world := []
	if room.has_method("get") and "exits" in room:
		var room_exits = room.get("exits")
		for exit in room_exits:
			# exit.pos is expected to be room-local tile coordinates; convert to Vector2i and add offset
			var exit_pos = Vector2i(int(exit.pos.x), int(exit.pos.y)) + offset
			exits_world.append({"dir": exit.dir, "pos": exit_pos})
	rooms[room_id]["exits"] = exits_world
	
	room.queue_free()
	last_room_id = room_id
	
	# NEW: Sync room data to clients after any room changes
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_room_data.rpc(rooms, deleted_rooms, room_ids_in_order)

@rpc("authority", "call_local")
func delete_room(room_id: int, cleanup_filler: bool = true) -> bool:
	if not rooms.has(room_id):
		print("[GENERATOR] Room ID ", room_id, " not found")
		return false
	
	var room_data = rooms[room_id]
	
	# Clear all room tiles
	for cell in room_data.cells:
		$TileMapLayer.set_cell(cell, -1)
	
	if cleanup_filler:
		# Get all remaining room bounds to determine safe cleanup areas
		var remaining_room_bounds = []
		for other_id in rooms:
			if other_id != room_id:
				remaining_room_bounds.append(rooms[other_id].bounds)
		
		# Clear filler area intelligently
		var filler_area = room_data.filler_area
		for x in range(filler_area.position.x, filler_area.end.x):
			for y in range(filler_area.position.y, filler_area.end.y):
				var pos = Vector2i(x, y)
				
				# Only clear if it's a filler tile
				var atlas_coords = $TileMapLayer.get_cell_atlas_coords(pos)
				if atlas_coords != filler_tile:
					continue
				
				# Check if this filler tile is still needed by any remaining room
				var needed_by_other_room = false
				for bounds in remaining_room_bounds:
					# Check if this filler position is within 16 tiles of any remaining room
					var expanded_bounds = Rect2i(
						bounds.position - Vector2i(16, 16),
						bounds.size + Vector2i(32, 32)
					)
					if expanded_bounds.has_point(pos):
						needed_by_other_room = true
						break
				
				# Also check if this tile is actually part of another room's cells
				if not needed_by_other_room:
					for other_id in rooms:
						if other_id == room_id:
							continue
						if pos in rooms[other_id].cells:
							needed_by_other_room = true
							break
				
				# Safe to delete if not needed by other rooms
				if not needed_by_other_room:
					$TileMapLayer.set_cell(pos, -1)
	
	# Remove from tracking
	rooms.erase(room_id)
	print("[GENERATOR] Deleted room ", room_id, " with cleanup: ", cleanup_filler)
	
	# NEW: Sync room data to clients after deletion
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_room_data.rpc(rooms, deleted_rooms, room_ids_in_order)
	
	return true

@rpc("authority", "call_local")
func convert_room_to_filler(room_id: int) -> bool:
	if not rooms.has(room_id):
		print("[GENERATOR] Room ID ", room_id, " not found for conversion")
		return false
	
	var room_data = rooms[room_id]
	
	# Convert room tiles to filler tiles
	for cell in room_data.cells:
		$TileMapLayer.set_cell(cell, 0, filler_tile)
	
	# Clear spawner tiles in this room's bounds only
	var room_bounds = room_data.bounds
	for x in range(room_bounds.position.x, room_bounds.end.x):
		for y in range(room_bounds.position.y, room_bounds.end.y):
			var pos = Vector2i(x, y)
			if spawner_layer.get_cell_source_id(pos) != -1:
				spawner_layer.set_cell(pos, -1)
			if decoration_layer.get_cell_source_id(pos) != -1:
				decoration_layer.set_cell(pos, -1)
	
	# Move to deleted_rooms tracking for later cleanup
	deleted_rooms[room_id] = {
		"bounds": room_data.bounds,
		"filler_area": room_data.filler_area
	}
	
	# Remove from active rooms
	rooms.erase(room_id)
	print("[GENERATOR] Converted room ", room_id, " to filler")
	
	# NEW: Sync room data to clients after conversion
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_room_data.rpc(rooms, deleted_rooms, room_ids_in_order)
	
	return true

@rpc("authority", "call_local")
func cleanup_distant_filler() -> void:
	if room_ids_in_order.is_empty():
		return
	
	var current_room_id = room_ids_in_order[-1]
	var current_room_bounds = get_room_bounds(current_room_id)
	var current_center = current_room_bounds.get_center()
	
	# Distance threshold - remove filler if it's more than 100 tiles away
	var cleanup_distance = 100.0
	
	var rooms_to_cleanup = []
	for room_id in deleted_rooms:
		var deleted_room_data = deleted_rooms[room_id]
		var deleted_center = deleted_room_data.bounds.get_center()
		var distance = current_center.distance_to(deleted_center)
		
		if distance > cleanup_distance:
			rooms_to_cleanup.append(room_id)
	
	# Actually remove the distant filler
	for room_id in rooms_to_cleanup:
		var deleted_room_data = deleted_rooms[room_id]
		var filler_area = deleted_room_data.filler_area
		
		# Remove all tiles in the filler area
		for x in range(filler_area.position.x, filler_area.end.x):
			for y in range(filler_area.position.y, filler_area.end.y):
				var pos = Vector2i(x, y)
				$TileMapLayer.set_cell(pos, -1)
		
		deleted_rooms.erase(room_id)
		print("[GENERATOR] Cleaned up distant filler for room ", room_id)
	
	# NEW: Sync room data to clients after cleanup
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		sync_room_data.rpc(rooms, deleted_rooms, room_ids_in_order)

func get_room_bounds(room_id: int) -> Rect2i:
	if rooms.has(room_id):
		return rooms[room_id].bounds
	return Rect2i()

func get_all_room_ids() -> Array:
	return rooms.keys()

# Wave system functions
func start_wave_system() -> void:
	spawning_active = true
	update_barrier_label()
	spawn_current_wave()

var progress: String = ""

@rpc("authority", "call_local")
func set_progress(_progress: String) -> void:
	progress = _progress

func update_barrier_label() -> void:
	var current_wave = get_current_wave()
	if not current_wave.is_empty():
		var total_waves = current_wave.content.size()
		$Barrier.get_node("Label").text = str(completed_subwaves) + "/" + str(total_waves)
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			set_progress.rpc(str(completed_subwaves) + "/" + str(total_waves))
		else:
			set_progress(str(completed_subwaves) + "/" + str(total_waves))

func get_current_wave() -> Dictionary:
	var applicable_waves = []
	for wave in waves:
		if completed_rooms >= wave.requirement:
			applicable_waves.append(wave)
	return applicable_waves.pick_random()

func spawn_current_wave() -> void:
	var current_wave = get_current_wave()
	if current_wave.is_empty():
		print("[WAVE] No valid wave found for requirement: ", completed_rooms)
		return
	
	if current_subwave_index >= current_wave.content.size():
		# All waves complete for this room
		complete_room()
		return
	
	var subwave = current_wave.content[current_subwave_index]
	print("[WAVE] Spawning subwave ", current_subwave_index, ": ", subwave)
	
	# Store total waves for this room when we start the first subwave
	if current_subwave_index == 0:
		var total_waves = current_wave.content.size()
		# Update label to show initial 0/total state
		$Barrier.get_node("Label").text = "0/" + str(total_waves)
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			set_progress.rpc("0/" + str(total_waves))
		else:
			set_progress("0/" + str(total_waves))
	
	# Increment wave index BEFORE spawning
	current_subwave_index += 1
	
	# Set spawning flag to prevent premature wave completion
	currently_spawning = true
	
	for enemy_data in subwave:
		for enemy_type in enemy_data:
			var count = enemy_data[enemy_type]
			for i in range(count):
				spawn_enemy(enemy_type)
				# Add 1.5 second delay between each enemy spawn
				if i < count - 1:  # Don't wait after the last enemy
					await get_tree().create_timer(1.5).timeout
	
	# Done spawning enemies
	currently_spawning = false

func spawn_enemy(enemy_type: String) -> void:
	var matching_cells: Array[Vector2i] = []
	var cells = spawner_layer.get_used_cells()

	# Prioritize spawners in the latest room first
	if room_ids_in_order.size() > 0:
		var latest_room_id = room_ids_in_order[-1]
		var latest_room_bounds = get_room_bounds(latest_room_id)
		
		# Find spawners within the latest room bounds
		for cell_loc in cells:
			if latest_room_bounds.has_point(cell_loc):
				var data = spawner_layer.get_cell_tile_data(cell_loc)
				if not data:
					continue
				if data.get_custom_data("spawner_type") == "corner":
					matching_cells.append(cell_loc)
		
		# If no corner spawners in latest room, try main spawners in latest room
		if matching_cells.is_empty():
			for cell_loc in cells:
				if latest_room_bounds.has_point(cell_loc):
					var data = spawner_layer.get_cell_tile_data(cell_loc)
					if data and data.get_custom_data("spawner_type") == "main":
						matching_cells.append(cell_loc)

	# Fallback: try corner spawners anywhere
	if matching_cells.is_empty():
		for cell_loc in cells:
			var data = spawner_layer.get_cell_tile_data(cell_loc)
			if not data:
				continue
			if data.get_custom_data("spawner_type") == "corner":
				matching_cells.append(cell_loc)

	# Final fallback: main spawners anywhere
	if matching_cells.is_empty():
		matching_cells = cells.filter(func(c):
			var d = spawner_layer.get_cell_tile_data(c)
			return d and d.get_custom_data("spawner_type") == "main"
		)		
		
	if matching_cells.is_empty():
		print("[SPAWN] No valid spawners found!")
		return
		
	var selected_cell = matching_cells.pick_random()
	var spawn_pos = spawner_layer.map_to_local(selected_cell) + Vector2(spawner_layer.tile_set.tile_size) / 2
	
	var enemy_scene
	match enemy_type:
		"slime":
			enemy_scene = slime
		"poison_slime":
			enemy_scene = poison_slime
		"mother_slime":
			enemy_scene = mother_slime
		"bauble":
			enemy_scene = bauble
		"rapid_bauble":
			enemy_scene = rapid_bauble
		"angry_bauble":
			enemy_scene = angry_bauble
		"bombrat":
			enemy_scene = bombrat
		"big_bombrat":
			enemy_scene = big_bombrat
		"crabman":
			enemy_scene = crabman
		"ghost":
			enemy_scene = ghost
		"gunk_slime":
			enemy_scene = gunk_slime
		"explosive_bauble":
			enemy_scene = explosive_bauble
		_:
			print("[SPAWN] Unknown enemy type: ", enemy_type)
			return
	
	var enemy = enemy_scene.instantiate()
	enemy.global_position = spawn_pos
	add_child(enemy, true)
	
	var smoke = smoke_scene.instantiate()
	smoke.global_position = spawn_pos
	smoke.emitting = true
	add_child(smoke, true)

func check_wave_completion() -> void:
	if not spawning_active or currently_spawning:
		return
		
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	if enemies.size() == 0:
		print("[WAVE] Wave complete, spawning next...")
		# Increment completed subwaves and update label with current wave's total
		completed_subwaves += 1
		var current_wave = get_current_wave()
		if not current_wave.is_empty():
			var total_waves = current_wave.content.size()
			$Barrier.get_node("Label").text = str(completed_subwaves) + "/" + str(total_waves)
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
				set_progress.rpc(str(completed_subwaves) + "/" + str(total_waves))
			else:
				set_progress(str(completed_subwaves) + "/" + str(total_waves))
		
		# All enemies defeated, spawn next wave after brief delay
		currently_spawning = true  # Prevent multiple triggers
		await get_tree().create_timer(1.0).timeout
		currently_spawning = false
		spawn_current_wave()

@rpc("authority", "call_local")
func send_rooms(rooms: int) -> void:
	completed_rooms = rooms

func complete_room() -> void:
	spawning_active = false
	completed_rooms += 1
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		send_rooms.rpc(completed_rooms)
	current_subwave_index = 0
	completed_subwaves = 0  # Reset for next room
	
	print("[ROOM] Room completed! Total completed: ", completed_rooms)
	
	if (completed_rooms + 1) % 10 == 0:
		spawn_shop_room()
		start_shop_phase()
		return
	
	# Wait a moment, then start countdown for next room
	countdown_and_spawn_room()

func spawn_next_room() -> void:
	var random_room_scene = valid_rooms.pick_random()
	var room_instance = load(random_room_scene).instantiate()
	
	# Get the room's exits
	var room_exits = room_instance.exits if room_instance.has_method("get") and "exits" in room_instance else []
	
	# Calculate offset based on connecting exits properly
	var offset = Vector2i(0, 0)
	if room_ids_in_order.size() > 0:
		var last_room_id = room_ids_in_order[-1]
		var last_room_bounds = get_room_bounds(last_room_id)
		
		var connection_point: Vector2i = Vector2i.ZERO
		var connection_found = false
		
		# --- NEW: read the stored exits from the last (merged) room instead of re-instancing random scenes ---
		if rooms.has(last_room_id) and rooms[last_room_id].has("exits"):
			var last_room_exits = rooms[last_room_id]["exits"]
			for exit in last_room_exits:
				if exit.dir == "north":
					connection_point = exit.pos
					connection_found = true
					break
		# --------------------------------------------------------------------
		
		# If we have a connection_point from the last room, try to align new room's south exit to it
		if connection_found and room_exits.size() > 0:
			for room_exit in room_exits:
				if room_exit.dir == "south":
					var room_south_exit = Vector2i(int(room_exit.pos.x), int(room_exit.pos.y))
					# Calculate offset so the south exit of new room aligns with north exit of previous room
					offset = connection_point - room_south_exit
					connection_found = true
					print("[ROOM] Connected via exits: previous north (", connection_point, ") to new south (", room_south_exit, ") with offset (", offset, ")")
					break
		
		# Fallbacks: if we couldn't find exits or match them, keep existing centered fallback logic
		if not connection_found:
			var temp_room_layer = room_instance.get_node_or_null("TileMapLayer")
			if temp_room_layer:
				var new_room_cells = temp_room_layer.get_used_cells()
				if not new_room_cells.is_empty():
					var new_min_pos = new_room_cells[0]
					var new_max_pos = new_room_cells[0]
					for cell in new_room_cells:
						new_min_pos.x = min(new_min_pos.x, cell.x)
						new_min_pos.y = min(new_min_pos.y, cell.y)
						new_max_pos.x = max(new_max_pos.x, cell.x)
						new_max_pos.y = max(new_max_pos.y, cell.y)
					
					var new_room_center_x = new_min_pos.x + (new_max_pos.x - new_min_pos.x) / 2
					var last_room_center_x = last_room_bounds.position.x + last_room_bounds.size.x / 2
					
					offset = Vector2i(
						last_room_center_x - new_room_center_x,
						last_room_bounds.position.y - new_max_pos.y - 1
					)
					print("[ROOM] No exit connection found, using centered fallback offset: ", offset)
	
	var new_room_id: int 
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		merge_room.rpc(random_room_scene, offset)	
		new_room_id = last_room_id 
	else:
		merge_room(random_room_scene, offset)
		new_room_id = last_room_id
	room_ids_in_order.append(new_room_id)
	
	# Stage 1: Convert old rooms to filler (keep last 3 active)
	while room_ids_in_order.size() > 3:
		var oldest_room_id = room_ids_in_order.pop_front()
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			convert_room_to_filler.rpc(oldest_room_id)
		else:
			convert_room_to_filler(oldest_room_id)
	
	# Stage 2: Completely remove very distant filler areas
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		cleanup_distant_filler.rpc()
	else:
		cleanup_distant_filler()

func position_barrier_at_room_exit(room_id: int, exit_direction: String) -> void:
	if not rooms.has(room_id) or not rooms[room_id].has("exits"):
		print("[BARRIER] No exits found for room ", room_id, ", using fallback positioning")
		position_barrier_fallback(room_id, exit_direction)
		return
	
	var room_exits = rooms[room_id]["exits"]
	var target_exit = null
	
	# Find the specific exit we want to position the barrier at
	for exit in room_exits:
		if exit.dir == exit_direction:
			target_exit = exit
			break
	
	if target_exit == null:
		print("[BARRIER] No ", exit_direction, " exit found for room ", room_id, ", using fallback")
		position_barrier_fallback(room_id, exit_direction)
		return
	
	# Position barrier at the actual exit location with appropriate offset
	var exit_tile_pos = target_exit.pos
	var barrier_pos: Vector2
	
	match exit_direction:
		"north":
			# Place barrier 2 tiles north of the exit
			barrier_pos = $TileMapLayer.map_to_local(Vector2i(exit_tile_pos.x, exit_tile_pos.y - 2))
		"south":
			# Place barrier 2 tiles south of the exit
			barrier_pos = $TileMapLayer.map_to_local(Vector2i(exit_tile_pos.x, exit_tile_pos.y + 2))
		"east":
			# Place barrier 2 tiles east of the exit
			barrier_pos = $TileMapLayer.map_to_local(Vector2i(exit_tile_pos.x + 2, exit_tile_pos.y))
		"west":
			# Place barrier 2 tiles west of the exit
			barrier_pos = $TileMapLayer.map_to_local(Vector2i(exit_tile_pos.x - 2, exit_tile_pos.y))
	
	$Barrier.global_position = barrier_pos
	print("[BARRIER] Positioned at actual ", exit_direction, " exit: ", exit_tile_pos, " -> ", barrier_pos)

# Fallback positioning method (original logic) for when exits aren't available
func position_barrier_fallback(room_id: int, exit_direction: String) -> void:
	var room_bounds = get_room_bounds(room_id)
	if room_bounds == Rect2i():
		return
	
	var barrier_pos: Vector2
	match exit_direction:
		"north":
			barrier_pos = $TileMapLayer.map_to_local(Vector2i(
				room_bounds.position.x + room_bounds.size.x / 2,
				room_bounds.position.y - 2
			))
		"south":
			barrier_pos = $TileMapLayer.map_to_local(Vector2i(
				room_bounds.position.x + room_bounds.size.x / 2,
				room_bounds.end.y + 2
			))
		"east":
			barrier_pos = $TileMapLayer.map_to_local(Vector2i(
				room_bounds.end.x + 2,
				room_bounds.position.y + room_bounds.size.y / 2
			))
		"west":
			barrier_pos = $TileMapLayer.map_to_local(Vector2i(
				room_bounds.position.x - 2,
				room_bounds.position.y + room_bounds.size.y / 2
			))
	
	$Barrier.global_position = barrier_pos

func countdown_and_spawn_room() -> void:
	# Countdown from 3 to spawn room
	$Barrier.get_node("Label").text = "3"
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		set_progress.rpc("3")
	else:
		set_progress("3")
	await get_tree().create_timer(1.0).timeout
	$Barrier.get_node("Label").text = "2"
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		set_progress.rpc("2")
	else:
		set_progress("2")
	await get_tree().create_timer(1.0).timeout
	$Barrier.get_node("Label").text = "1"
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		set_progress.rpc("1")
	else:
		set_progress("1")
	await get_tree().create_timer(1.0).timeout
	
	# Poof effect and spawn room
	var smoke = smoke_scene.instantiate()
	smoke.global_position = $Barrier.global_position
	smoke.emitting = true
	add_child(smoke, true)
	
	spawn_next_room()
	
	# Move barrier to top of new room and start waves
	var new_room_id = room_ids_in_order[-1]
	position_barrier_at_room_exit(new_room_id, "north")
	
	# Start wave system - reset completed subwaves for new room
	spawning_active = true
	current_subwave_index = 0
	completed_subwaves = 0
	update_barrier_label()
	spawn_current_wave()

func check_players_for_void() -> void:
	# Only run void detection on server or in singleplayer
	if not is_server_or_singleplayer():
		return
		
	# Get all players using the proper group
	var players = get_tree().get_nodes_in_group("players")
	
	for player in players:
		if is_player_in_void(player):
			if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
				teleport_player_to_safety.rpc(player.name)
			else:
				teleport_player_to_safety(player.name)

func is_player_in_void(player: Node2D) -> bool:
	var player_tile_pos = $TileMapLayer.local_to_map(player.global_position)
	var tile_source_id = $TileMapLayer.get_cell_source_id(player_tile_pos)
	var tile_atlas_id = $TileMapLayer.get_cell_atlas_coords(player_tile_pos)
	
	# Player is in void if there's no tile at their position or they're on filler
	return tile_source_id == -1 or tile_atlas_id == filler_tile

# NEW: Find the best room exit position for teleportation
func find_room_exit_position(room_id: int, preferred_direction: String = "") -> Vector2:
	if not rooms.has(room_id) or not rooms[room_id].has("exits"):
		return Vector2.ZERO
	
	var room_exits = rooms[room_id]["exits"]
	
	# If we have a preferred direction, try to find that exit first
	if preferred_direction != "":
		for exit in room_exits:
			if exit.dir == preferred_direction:
				return $TileMapLayer.map_to_local(exit.pos)
	
	# Otherwise, prioritize exits in this order: south, north, east, west
	var priority_order = ["south", "north", "east", "west"]
	for direction in priority_order:
		for exit in room_exits:
			if exit.dir == direction:
				return $TileMapLayer.map_to_local(exit.pos)
	
	# If no exits found, return room center as fallback
	var room_bounds = get_room_bounds(room_id)
	var center_pos = Vector2i(
		room_bounds.position.x + room_bounds.size.x / 2,
		room_bounds.position.y + room_bounds.size.y / 2
	)
	return $TileMapLayer.map_to_local(center_pos)



@rpc("authority", "call_local")
func teleport_player_to_safety(player_name: String) -> void:
	var player: Node2D
	for players in get_tree().get_nodes_in_group("players"):
		if players.name == player_name:
			player = players
	if player == null:
		print("[SAFETY] Couldn't find player by name: " + player_name + ".")
		return
	
	# NEW: Try to find the best room exit position for teleportation
	var safe_position = Vector2.ZERO
	
	# First, try to find an exit in the latest active room
	if not room_ids_in_order.is_empty():
		var latest_room_id = room_ids_in_order[-1]
		safe_position = find_room_exit_position(latest_room_id, "south")  # Prefer south exit (entrance)
		
		# If no exit found in latest room, try other active rooms
		if safe_position == Vector2.ZERO:
			for i in range(room_ids_in_order.size() - 1, -1, -1):  # Go backwards through rooms
				var room_id = room_ids_in_order[i]
				safe_position = find_room_exit_position(room_id)
				if safe_position != Vector2.ZERO:
					break
	
	# Fallback: use the old nearest safe position method
	if safe_position == Vector2.ZERO:
		safe_position = find_nearest_safe_position(player.global_position)
	
	if safe_position != Vector2.ZERO:
		player.global_position = safe_position
		
		# Add visual effect
		var smoke = smoke_scene.instantiate()
		smoke.global_position = player.global_position
		smoke.emitting = true
		add_child(smoke, true)
		
		print("[SAFETY] Teleported player to exit position: ", safe_position)

func find_nearest_safe_position(from_position: Vector2) -> Vector2:
	var search_radius = 100  # Search within 50 tiles
	var from_tile = $TileMapLayer.local_to_map(from_position)
	
	# Spiral search for nearest valid tile
	for radius in range(1, search_radius + 1):
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				# Only check border of current radius
				if abs(x) != radius and abs(y) != radius:
					continue
					
				var check_pos = from_tile + Vector2i(x, y)
				var tile_source_id = $TileMapLayer.get_cell_source_id(check_pos)
				var tile_atlas = $TileMapLayer.get_cell_atlas_coords(check_pos)
				
				# Valid tile that's not filler
				if tile_source_id != -1 and tile_atlas != filler_tile:
					return $TileMapLayer.map_to_local(check_pos)
	
	# Fallback: try to find any active room center
	if not room_ids_in_order.is_empty():
		var latest_room_id = room_ids_in_order[-1]
		var room_bounds = get_room_bounds(latest_room_id)
		var center_pos = Vector2i(
			room_bounds.position.x + room_bounds.size.x / 2,
			room_bounds.position.y + room_bounds.size.y / 2
		)
		return $TileMapLayer.map_to_local(center_pos)
	
	# Final fallback
	return Vector2(128, 128)  # Original spawn position

# --- SHOP SYSTEM ---

func start_shop_phase() -> void:
	shop_timer = shop_duration
	shop_active = true
	update_barrier_label_for_shop()

	# Spawn Shopkeeper(s) on sewer spawners in the latest room
	var latest_room_id = room_ids_in_order[-1]
	var latest_bounds = get_room_bounds(latest_room_id)
	var sewer_spawners: Array[Vector2i] = []
	for cell in spawner_layer.get_used_cells():
		if latest_bounds.has_point(cell):
			var data = spawner_layer.get_cell_tile_data(cell)
			if data and data.get_custom_data("spawner_type") == "sewer":
				sewer_spawners.append(cell)

	if sewer_spawners.size() > 0:
		var min_pos = Vector2.INF
		var max_pos = -Vector2.INF
	
		for spawner_cell in sewer_spawners:
			var cell_pos = spawner_layer.map_to_local(spawner_cell) + Vector2(spawner_layer.tile_set.tile_size) / 2
			min_pos = min_pos.min(cell_pos)
			max_pos = max_pos.max(cell_pos)
	
		var midpoint = (min_pos + max_pos) / 2.0
		
		midpoint.y -= 12
		midpoint.x -= 10
		
		var s = shopkeeper.instantiate()
		s.global_position = midpoint
		add_child(s, true)
		current_shopkeepers.append(s)


func spawn_shop_room() -> void:
	print("[SHOP] Spawning shop room after ", completed_rooms, " completed rooms")

	var shop_room_path = shop_rooms[Man.selected_map]
	var shop_instance = load(shop_room_path).instantiate()
	var offset: Vector2i = Vector2i.ZERO

	# Find connection point from the last room
	if room_ids_in_order.size() > 0:
		last_room_id = room_ids_in_order[-1]
		var connection_point: Vector2i
		var connection_found := false

		if rooms.has(last_room_id) and rooms[last_room_id].has("exits"):
			for exit in rooms[last_room_id]["exits"]:
				if exit.dir == "north": # assume shop connects north
					connection_point = exit.pos
					connection_found = true
					break

		# Align shop's south exit to that connection point
		if connection_found:
			if shop_instance.exits != null:
				for exit in shop_instance.exits:
					if exit.dir == "south":
						offset = connection_point - exit.pos
						break
			shop_instance.queue_free()

	# Merge the shop room
	var shop_room_id: int
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		merge_room.rpc(shop_room_path, offset)
		shop_room_id = last_room_id
	else:
		merge_room(shop_room_path, offset)
		shop_room_id = last_room_id

	# Append the shop room to our order
	room_ids_in_order.append(shop_room_id)

	# Keep only the last 3 rooms alive
	while room_ids_in_order.size() > 3:
		var oldest_room_id = room_ids_in_order.pop_front()
		if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
			convert_room_to_filler.rpc(oldest_room_id)
		else:
			convert_room_to_filler(oldest_room_id)

	# Cleanup filler tiles
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		cleanup_distant_filler.rpc()
	else:
		cleanup_distant_filler()

	# Place barrier at the shop's exit (north side)
	position_barrier_at_room_exit(shop_room_id, "north")

func end_shop_phase() -> void:
	# Despawn Shopkeepers
	for s in current_shopkeepers:
		if is_instance_valid(s):
			s.queue_free()
	current_shopkeepers.clear()

	shop_active = false
	shop_timer = 0.0
	# Continue to next room
	countdown_and_spawn_room()

func update_barrier_label_for_shop() -> void:
	var seconds_left = int(shop_timer)
	$Barrier.get_node("Label").text = "Shop: " + str(seconds_left)
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		set_progress.rpc("Shop: " + str(seconds_left))
	else:
		set_progress("Shop: " + str(seconds_left))
