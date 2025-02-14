extends Node

var tiles = []
var item_resource = preload("res://scenes/item.tscn")

func get_by_id(id: int) -> Tile:
	for tile in tiles:
		if tile.id == id:
			return tile
	return null

func _init() -> void:
	var stone = Tile.new("Stone", 0)
	stone.on_break = func(location: Vector2):
		print("Stone broken at: ", location)
		Items.spawn(ItemStack.new(Items.get_by_id(0), 1), location)
	tiles.append(stone)

	var quartz = Tile.new("Quartz", 1)
	quartz.on_break = func(location: Vector2):
		print("Quartz broken at: ", location)
		Items.spawn(ItemStack.new(Items.get_by_id(1), 1), location)
	tiles.append(quartz)
