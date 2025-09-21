extends Node2D

var smoke_scene = preload("res://scenes/smoke.tscn")
var player_scene = preload("res://scenes/player.tscn")
var filler_tile = Vector2i(3, 0)

var valid_rooms = [
	preload("res://scenes/levels/dungeon/plains_tall_hallway.tscn")
]

var waves = [
	{
		"requirement": 0,
		"content": [
			[{ "slime": 5 }, { "bauble": 2 }]
		]
	},
	{
		"requirement": 0,
		"content": [
			[{ "slime": 3 }], 
			[{ "slime": 5 }, { "bauble": 2 }]
		]
	},
	{
		"requirement": 5,
		"content": [
			[{ "slime": 3 }], 
			[{ "slime": 5 }, { "bauble": 2 }],
			[{ "slime": 8 }, { "bauble": 5 }],
			[{ "mother_slime": 2 }, { "slime": 12 }],
		]
	}
]

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

# Room tracking system
var rooms = {}  # Dictionary: room_id -> {bounds: Rect2i, cells: Array[Vector2i], filler_area: Rect2i}
var next_room_id = 0
var deleted_rooms = {}  # Dictionary: room_id -> {bounds: Rect2i, filler_area: Rect2i} - rooms converted to filler

# Wave system
var completed_rooms = 0
var current_wave_index = 0
var current_subwave_index = 0
var spawning_active = false
var room_ids_in_order = []
var kills = {}

@onready var spawner_layer = $Spawner

@rpc("authority", "call_local")
func add_gold(id: String, amount: int) -> void:
	get_node(id).gold += amount
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

func _ready() -> void:
	multiplayer.multiplayer_peer = null
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
	$TileMapLayer.clear()
	
	# Only spawn the start room initially
	var start_id = merge_room(preload("res://scenes/levels/dungeon/plains_start_room.tscn").instantiate(), Vector2(0, 0))
	room_ids_in_order = [start_id]
	
	# Position barrier at the north exit of start room to indicate next room spawn
	position_barrier_at_room_exit(start_id, "north")
	
	# Start countdown to spawn first room
	await get_tree().create_timer(2.0).timeout
	countdown_and_spawn_room()
	return

func move_barrier(where_to: Vector2) -> void:
	$Barrier.get_node("Label").text = "5"
	await get_tree().create_timer(1.0).timeout
	$Barrier.get_node("Label").text = "4"
	await get_tree().create_timer(1.0).timeout
	$Barrier.get_node("Label").text = "3"
	await get_tree().create_timer(1.0).timeout
	$Barrier.get_node("Label").text = "2"
	await get_tree().create_timer(1.0).timeout
	$Barrier.get_node("Label").text = "1"
	await get_tree().create_timer(1.0).timeout
	var smoke = smoke_scene.instantiate()
	smoke.global_position = $Barrier.global_position
	smoke.emitting = true
	add_child(smoke, true)
	$Barrier.global_position = where_to
	Toast.add("The barrier has moved!")

func merge_room(room: Node, offset: Vector2i) -> int:
	var room_layer = room.get_node_or_null("TileMapLayer")
	var room_spawner = room.get_node_or_null("Spawner")
	
	if not room_layer:
		print("[GENERATOR] Room has no TileMapLayer, skipping")
		return -1
	
	# Get room bounds for filler calculation
	var room_cells = room_layer.get_used_cells()
	if room_cells.is_empty():
		print("[GENERATOR] Room has no cells, skipping")
		room.queue_free()
		return -1
	
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
	
	# Fill 16-tile radius around the room with filler tiles
	var filler_radius = 20
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
	
	# Store room data for tracking
	var room_id = next_room_id
	next_room_id += 1
	rooms[room_id] = {
		"bounds": Rect2i(min_pos, max_pos - min_pos + Vector2i.ONE),
		"cells": placed_cells,
		"filler_area": Rect2i(filler_min, filler_max - filler_min + Vector2i.ONE)
	}
	
	room.queue_free()
	return room_id

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
	return true

func delete_room_progressive(room_id: int) -> bool:
	if not rooms.has(room_id):
		print("[GENERATOR] Room ID ", room_id, " not found")
		return false
	
	var room_data = rooms[room_id]
	
	# Clear all room tiles
	for cell in room_data.cells:
		$TileMapLayer.set_cell(cell, -1)
	
	# Clear spawner tiles in this room's area
	var filler_area = room_data.filler_area
	for x in range(filler_area.position.x, filler_area.end.x):
		for y in range(filler_area.position.y, filler_area.end.y):
			var pos = Vector2i(x, y)
			# Clear spawner tiles in this area
			if spawner_layer.get_cell_source_id(pos) != -1:
				spawner_layer.set_cell(pos, -1)
	
	# Progressive filler cleanup
	var remaining_room_bounds = []
	for other_id in rooms:
		if other_id != room_id:
			remaining_room_bounds.append(rooms[other_id].bounds)
	
	# Clear filler area intelligently
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
			
			# Safe to delete if not needed by other rooms
			if not needed_by_other_room:
				$TileMapLayer.set_cell(pos, -1)
	
	# Remove from tracking
	rooms.erase(room_id)
	print("[GENERATOR] Deleted room ", room_id, " progressively")
	return true

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
	
	# Move to deleted_rooms tracking for later cleanup
	deleted_rooms[room_id] = {
		"bounds": room_data.bounds,
		"filler_area": room_data.filler_area
	}
	
	# Remove from active rooms
	rooms.erase(room_id)
	print("[GENERATOR] Converted room ", room_id, " to filler")
	return true

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

func update_barrier_label() -> void:
	var current_wave = get_current_wave()
	if not current_wave.is_empty():
		var completed_waves = current_subwave_index - 1  # Subtract 1 because we increment before spawning
		var total_waves = current_wave.content.size()
		# Ensure completed doesn't go negative
		completed_waves = max(0, completed_waves)
		$Barrier.get_node("Label").text = str(completed_waves) + "/" + str(total_waves)

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
	
	# Increment wave index BEFORE spawning
	current_subwave_index += 1
	# Update barrier to show current progress (0 completed when wave just started)
	update_barrier_label()
	
	for enemy_data in subwave:
		for enemy_type in enemy_data:
			var count = enemy_data[enemy_type]
			for i in range(count):
				spawn_enemy(enemy_type)
	
	# Start checking for wave completion
	check_wave_completion()

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
	if not spawning_active:
		return
		
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("[WAVE] Checking completion. Enemies remaining: ", enemies.size())
	
	if enemies.size() == 0:
		print("[WAVE] Wave complete, spawning next...")
		# All enemies defeated, spawn next wave
		await get_tree().create_timer(1.0).timeout  # Brief pause between waves
		spawn_current_wave()
	else:
		# Check again in a moment
		await get_tree().create_timer(0.5).timeout
		check_wave_completion()

func complete_room() -> void:
	spawning_active = false
	completed_rooms += 1
	current_subwave_index = 0
	
	print("[ROOM] Room completed! Total completed: ", completed_rooms)
	
	# Show completion
	var current_wave = get_current_wave()
	if not current_wave.is_empty():
		var total_waves = current_wave.content.size()
		$Barrier.get_node("Label").text = str(total_waves) + "/" + str(total_waves)
	
	# Wait a moment, then start countdown for next room
	await get_tree().create_timer(2.0).timeout
	countdown_and_spawn_room()

func spawn_next_room() -> void:
	var random_room_scene = valid_rooms.pick_random()
	var room_instance = random_room_scene.instantiate()
	
	# Get the room's exits
	var room_exits = room_instance.exits if room_instance.has_method("get") and "exits" in room_instance else []
	
	# Calculate offset based on connecting to the last room's north exit
	var offset = Vector2i(0, 0)
	if room_ids_in_order.size() > 0:
		var last_room_id = room_ids_in_order[-1]
		var last_room_bounds = get_room_bounds(last_room_id)
		
		# Find the north exit position of the last room
		var connection_point = Vector2i(
			last_room_bounds.position.x + last_room_bounds.size.x / 2,
			last_room_bounds.position.y
		)
		
		# Find a south exit in the new room to connect to
		var connection_found = false
		for room_exit in room_exits:
			if room_exit.dir == "south":
				var exit_pos = Vector2i(room_exit.pos.x, room_exit.pos.y)
				offset = connection_point - exit_pos
				connection_found = true
				break
		
		# Fallback: place room above last room
		if not connection_found:
			offset = Vector2i(
				last_room_bounds.position.x,
				last_room_bounds.position.y - 15
			)
	
	var new_room_id = merge_room(room_instance, offset)
	room_ids_in_order.append(new_room_id)
	
	# Stage 1: Convert old rooms to filler (keep last 3 active)
	while room_ids_in_order.size() > 3:
		var oldest_room_id = room_ids_in_order.pop_front()
		convert_room_to_filler(oldest_room_id)
	
	# Stage 2: Completely remove very distant filler areas
	cleanup_distant_filler()

func move_barrier_to_previous_room() -> void:
	if room_ids_in_order.size() < 2:
		return
	
	# Get the second-to-last room (current/previous room where waves happen)
	var current_room_id = room_ids_in_order[-2]
	var current_room_bounds = get_room_bounds(current_room_id)
	
	# Position barrier at the top of the current room to indicate progression
	var barrier_target = $TileMapLayer.map_to_local(Vector2i(
		current_room_bounds.position.x + current_room_bounds.size.x / 2,
		current_room_bounds.position.y - 3
	))
	
	$Barrier.global_position = barrier_target

func position_barrier_at_room_exit(room_id: int, exit_direction: String) -> void:
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
	# Countdown from 5 to spawn room
	$Barrier.get_node("Label").text = "5"
	await get_tree().create_timer(1.0).timeout
	$Barrier.get_node("Label").text = "4"
	await get_tree().create_timer(1.0).timeout
	$Barrier.get_node("Label").text = "3"
	await get_tree().create_timer(1.0).timeout
	$Barrier.get_node("Label").text = "2"
	await get_tree().create_timer(1.0).timeout
	$Barrier.get_node("Label").text = "1"
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
	
	# Start wave system
	spawning_active = true
	current_subwave_index = 0
	update_barrier_label()
	spawn_current_wave()
