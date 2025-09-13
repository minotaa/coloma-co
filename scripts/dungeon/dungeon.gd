@tool
extends Node2D

@export var all_rooms: Array = [
	preload("res://scenes/levels/dungeon/plains_long_hallway.tscn"),
	preload("res://scenes/levels/dungeon/plains_tall_hallway.tscn"),
	preload("res://scenes/levels/dungeon/plains_start_room.tscn")
]

var room_data: Array = []
var placed_rooms: Array = []
var open_exits: Array = []

func _ready() -> void:
	_init_room_data()

func _init_room_data() -> void:
	room_data.clear()
	for room_scene in all_rooms:
		if not room_scene: 
			continue
		var inst = room_scene.instantiate()
		room_data.append({
			"scene": room_scene,
			"type": inst.type,
			"weight": inst.weight
		})
		inst.queue_free()

# Merge tiles from a room's TileMapLayer into the dungeon TileMapLayer
func merge_room(room_tilemap: TileMapLayer, offset: Vector2i, dungeon_tilemap: TileMapLayer):
	for cell in room_tilemap.get_used_cells():
		var tile_id = room_tilemap.get_cell(cell)
		if tile_id == -1:
			continue
		dungeon_tilemap.set_cell(cell + offset, tile_id)

# Place a room instance and merge its tiles
func place_room(room_scene: PackedScene, offset: Vector2i):
	var room_instance = room_scene.instantiate()
	add_child(room_instance)

	var room_layer = room_instance.get_node("TileMapLayer")
	for cell in room_layer.get_used_cells():
		var tile_id = room_layer.get_cell(cell)
		if tile_id == -1:
			continue
		$TileMapLayer.set_cell(cell + offset, tile_id)

	room_layer.visible = false
	return room_instance

# Track open exits in a room
func add_open_exits(room_instance):
	for i in room_instance.exits.size():
		open_exits.append({"room": room_instance, "exit_index": i})

# Pick a random room weighted by its 'weight' property, ignoring start rooms
func pick_room_weighted() -> PackedScene:
	var total_weight = 0
	for r in room_data:
		if r.type != "start":
			total_weight += r.weight

	var pick = randi() % total_weight

	for r in room_data:
		if r.type != "start":
			pick -= r.weight
			if pick < 0:
				return r.scene

	# fallback
	for r in room_data:
		if r.type != "start":
			return r.scene

	return all_rooms[0]  # should never reach

func get_opposite_dir(dir: String) -> String:
	match dir:
		"north": return "south"
		"south": return "north"
		"east": return "west"
		"west": return "east"
		_: return ""

# Compute the tile offset to align new room exit with existing exit
func compute_offset(existing_exit, new_exit, existing_room_pos: Vector2i) -> Vector2i:
	var existing_exit_global = existing_room_pos + existing_exit.pos
	return existing_exit_global - new_exit.pos

# Place a room connected to an open exit
func place_room_at_exit(exit_data):
	var existing_room = exit_data["room"]
	var exit_idx = exit_data["exit_index"]
	var existing_exit = existing_room.exits[exit_idx]

	var new_room_scene = pick_room_weighted()
	var new_room_instance = new_room_scene.instantiate()

	for i in new_room_instance.exits.size():
		var new_exit = new_room_instance.exits[i]
		if get_opposite_dir(new_exit.dir) == existing_exit.dir:
			var existing_exit_global = existing_room.position + existing_exit.pos
			var offset = existing_exit_global - new_exit.pos
			var placed = place_room(new_room_scene, offset)
			for j in placed.exits.size():
				if j != i: 
					open_exits.append({"room": placed, "exit_index": j})
			open_exits.erase(exit_data)
			return
	open_exits.erase(exit_data)
