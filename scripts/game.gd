extends Node2D

@export var map_size: Vector2i = Vector2i(100, 100)
@export var tiles: Array[int] = [1, 2]
@export var scatter_chance: float = 0.1
var rng = RandomNumberGenerator.new()
@export var seed: int = 0

@onready var tile_layer = $Tiles
@onready var ground_layer = $Ground

func _ready() -> void:
	print("Generating world...")
	_generate_seed()
	print("Generated seed... now generating level.")
	_generate_world()
	print("Done!")

func _generate_seed() -> void:
	if seed != 0:
		rng.seed = seed
	else:
		rng.randomize()
	print("Seed: ", str(rng.seed))

func place_tile(pos: Vector2i, tile_index: int) -> void:
	# atlas coords: (tile_index, 0), since sprites laid out horizontally
	var atlas_coords := Vector2i(tile_index, 0)
	tile_layer.set_cell(pos, 0, atlas_coords)

var safe_radius := 5 # how many tiles away from 0,0 to keep empty

func _generate_world() -> void:
	ground_layer.clear()
	tile_layer.clear()

	var half_width := map_size.x / 2
	var half_height := map_size.y / 2

	for x in range(-half_width, map_size.x - half_width):
		for y in range(-half_height, map_size.y - half_height):
			var pos := Vector2i(x, y)

			# Ground tile: source 0, atlas pos 0,0
			ground_layer.set_cell(pos, 0, Vector2i(0, 0))

			# Place scattered tiles only if outside safe radius
			if tiles.size() > 0 and rng.randf() < scatter_chance:
				if pos.distance_to(Vector2i.ZERO) > safe_radius:
					var tile_index := tiles[rng.randi() % tiles.size()]
					place_tile(pos, tile_index)
