extends Node

var tiles = []

func get_by_id(id: int) -> Tile:
	for tile in tiles:
		if tile.id == id:
			return tile
	return null

func _init() -> void:
	var stone = Tile.new("Stone", 0)
	stone.on_break = func(location: Vector2):
		print("Stone broken at: ", location)
	tiles.append(stone)
