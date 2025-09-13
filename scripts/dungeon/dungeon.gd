@tool
extends Node2D

@export var all_rooms: Array = []
@export var start_room: PackedScene
@export var max_rooms: int = 10

const CELL_SIZE = 16

var rng = RandomNumberGenerator.new()
var placed_rooms: Array = []
var dungeon_grid: Dictionary = {}

var _started: bool = false
@export var started: bool:
	set(value):
		if value:
			generate_dungeon()
			_started = false
	get:
		return _started

func _ready():
	if Engine.is_editor_hint():
		print("[GENERATOR] Editor ready, you can toggle 'started' to test")

func generate_dungeon() -> void:
	print("[GENERATOR] Starting dungeon generation")
	clear_previous()
	if not start_room:
		print("[GENERATOR] No start room provided, aborting")
		return
	var start_instance = start_room.instantiate()
	merge_room_into_dungeon(start_instance, Vector2i.ZERO)
	placed_rooms.append(start_instance)
	update_dungeon_grid(start_instance, Vector2i.ZERO)
	print("[GENERATOR] Placed start room at position %s" % str(start_instance.position))

	var open_exits = get_exits(start_instance)
	var room_count = 1

	while open_exits.size() > 0 and room_count < max_rooms:
		var exit_data = open_exits.pop_front()
		var placed = false
		var attempt_count = 0
		while not placed and attempt_count < 20:
			attempt_count += 1
			var new_room_scene = pick_random_room()
			if not new_room_scene:
				print("[GENERATOR] No candidate room found, skipping exit")
				break
			var new_room_instance = new_room_scene.instantiate()
			print("[GENERATOR] Attempting to place room: %s" % new_room_instance.name)
			print("  Type: %s" % str(new_room_instance.type if new_room_instance.type != null else "unknown"))
			var exit_dirs = []
			for e in new_room_instance.exits:
				exit_dirs.append(e.dir)
			print("  Exits: %s" % str(exit_dirs))

			for new_exit in get_exits(new_room_instance):
				if are_exits_compatible(exit_data.dir, new_exit.dir):
					var line_offset = compute_line_offset(exit_data.pos, exit_data.dir, new_exit.pos)
					print("  Calculated placement offset along exit line: %s" % str(line_offset))

					if room_fits_on_grid(new_room_instance, line_offset):
						merge_room_into_dungeon(new_room_instance, line_offset)
						update_dungeon_grid(new_room_instance, line_offset)
						placed_rooms.append(new_room_instance)
						room_count += 1
						for e in get_exits(new_room_instance):
							if e.index != new_exit.index:
								open_exits.append(e)
						placed = true
						break
			new_room_instance.queue_free()

			if not placed:
				print("[GENERATOR] Attempt %d failed at exit %s" % [attempt_count, str(exit_data.pos)])

			await get_tree().create_timer(0.1).timeout

		if not placed:
			print("[GENERATOR] Could not place any room at exit %s after 20 attempts" % str(exit_data.pos))

	print("[GENERATOR] Finished generation with %d rooms" % room_count)

func compute_line_offset(existing_exit_pos: Vector2i, existing_exit_dir: String, new_exit_pos: Vector2i) -> Vector2i:
	# Treat exits as central points, move the new room so the new_exit aligns with existing_exit + direction vector
	var target_cell = existing_exit_pos + get_exit_direction_vector(existing_exit_dir)
	return target_cell - new_exit_pos

func get_exits(room: Node) -> Array:
	if room.exits.size() == 0:
		print("[GENERATOR] Room has no exits array, skipping")
		return []
	var exits_array = []
	for i in range(room.exits.size()):
		var exit = room.exits[i]
		exits_array.append({"pos": exit.pos, "dir": exit.dir, "room": room, "index": i})
	return exits_array

func merge_room_into_dungeon(room: Node, offset: Vector2i) -> void:
	var room_layer = room.get_node_or_null("TileMapLayer")
	if not room_layer:
		print("[GENERATOR] Room has no TileMapLayer, skipping")
		return
	for cell in room_layer.get_used_cells():
		var source_id = room_layer.get_cell_source_id(cell)
		var atlas_coords = room_layer.get_cell_atlas_coords(cell)
		if source_id == -1:
			continue
		$TileMapLayer.set_cell(cell + offset, source_id, atlas_coords)
	room.queue_free()

func room_fits_on_grid(room: Node, offset: Vector2i) -> bool:
	var room_layer = room.get_node_or_null("TileMapLayer")
	if not room_layer:
		return false
	for cell in room_layer.get_used_cells():
		var target_cell = cell + offset
		if dungeon_grid.has(target_cell):
			print("[GENERATOR] Overlap detected at %s" % str(target_cell))
			return false
	return true

func update_dungeon_grid(room: Node, offset: Vector2i) -> void:
	var room_layer = room.get_node_or_null("TileMapLayer")
	if not room_layer:
		return
	for cell in room_layer.get_used_cells():
		dungeon_grid[cell + offset] = true

func are_exits_compatible(dir1: String, dir2: String) -> bool:
	match dir1:
		"north": return dir2 == "south"
		"south": return dir2 == "north"
		"east": return dir2 == "west"
		"west": return dir2 == "east"
		_: return false

func get_exit_direction_vector(dir: String) -> Vector2i:
	match dir:
		"north": return Vector2i(0, -1)
		"south": return Vector2i(0, 1)
		"east": return Vector2i(1, 0)
		"west": return Vector2i(-1, 0)
		_: return Vector2i.ZERO

func clear_previous():
	$TileMapLayer.clear()
	placed_rooms.clear()
	dungeon_grid.clear()
	print("[GENERATOR] Cleared previous dungeon")

func pick_random_room() -> PackedScene:
	if all_rooms.is_empty():
		return null
	var idx = rng.randi_range(0, all_rooms.size() - 1)
	print("[GENERATOR] Picked candidate room index %d" % idx)
	return all_rooms[idx]