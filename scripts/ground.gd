extends TileMapLayer

@onready var tiles = $"../Tiles"
var harmful_areas: Dictionary = {}

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	if coords in tiles.get_used_cells_by_id(0):
		return true
	return false

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	if coords in tiles.get_used_cells_by_id(0):
		tile_data.set_navigation_polygon(0, null)
		
	var tile_info = tiles.get_cell_tile_data(coords)
	if tile_info and tile_info.get_custom_data("harmful"):
		_create_harmful_area(coords, tile_info)
	else:
		_remove_harmful_area(coords)

func _create_harmful_area(coords: Vector2i, tile_info: TileData):
	if harmful_areas.has(coords):
		return

	var area = Area2D.new()
	var shape = CollisionShape2D.new()
	
	if tile_info.get_collision_polygons_count(0) > 0:
		var poly = tile_info.get_collision_polygon_points(0, 0)
		for i in range(poly.size()):
			poly[i] *= 1.1
		var collision_shape = ConvexPolygonShape2D.new()
		collision_shape.points = poly
		shape.shape = collision_shape
	else:
		var tile_shape = tile_info.get_collision_shape(0, 0)
		if tile_shape:
			shape.shape = tile_shape.duplicate()

	area.add_child(shape)
	tiles.add_child(area)
	area.position = tiles.map_to_local(coords) 
	
	var damage_amount = tile_info.get_custom_data("damage") if tile_info.has_custom_data("damage") else 10
	area.set_meta("damage", damage_amount)
	
	area.body_entered.connect(func(body):
		print("this worked")
		if body.is_in_group("players") and body.has_method("take_damage"):
			body.take_damage(area.get_meta("damage"), area.global_position)
	)

	harmful_areas[coords] = area

func _remove_harmful_area(coords: Vector2i):
	if harmful_areas.has(coords):
		harmful_areas[coords].queue_free()
		harmful_areas.erase(coords)
