extends TileMapLayer

@onready var tiles = $"../Tiles"
var harmful_areas: Dictionary = {}
var tree_shadows: Dictionary = {}
var affected_nav_cells: Dictionary = {}

func _use_tile_data_runtime_update(coords: Vector2i) -> bool:
	# Check if this coord should have nav disabled
	if coords in affected_nav_cells:
		return true
	return false

func _tile_data_runtime_update(coords: Vector2i, tile_data: TileData) -> void:
	# Disable navigation if this cell is marked as affected
	if coords in affected_nav_cells:
		tile_data.set_navigation_polygon(0, null)
		
	var tile_info = tiles.get_cell_tile_data(coords)
	if tile_info:
		# Handle harmful tiles
		if tile_info.get_custom_data("harmful"):
			_create_harmful_area(coords, tile_info)
		else:
			_remove_harmful_area(coords)
		
		# Handle tree shadows
		if tile_info.has_custom_data("tree"):
			_create_tree_shadow(coords, tile_info.get_custom_data("tree"))
		else:
			_remove_tree_shadow(coords)
	else:
		_remove_harmful_area(coords)
		_remove_tree_shadow(coords)

func _ready():
	# Find all tiles in the tiles layer and mark their nav cells
	_update_all_navigation_cells()
	
func _update_all_navigation_cells():
	affected_nav_cells.clear()
	
	for tile_coords in tiles.get_used_cells():
		var atlas_coords = tiles.get_cell_atlas_coords(tile_coords)
		var source_id = tiles.get_cell_source_id(tile_coords)
		
		if source_id == -1:
			continue
			
		var tile_set_source = tiles.tile_set.get_source(source_id)
		if tile_set_source is TileSetAtlasSource:
			var tile_size_in_atlas = tile_set_source.get_tile_size_in_atlas(atlas_coords)
			
			# Mark all cells covered by this tile for nav removal
			for x in range(tile_size_in_atlas.x):
				for y in range(tile_size_in_atlas.y):
					var affected_coord = tile_coords + Vector2i(x, y)
					affected_nav_cells[affected_coord] = true
	
	# Notify the navigation system to update
	notify_runtime_tile_data_update()

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
		if body.is_in_group("players") and body.has_method("take_damage"):
			body.take_damage(area.get_meta("damage"), name, area.global_position)
	)

	harmful_areas[coords] = area

func _remove_harmful_area(coords: Vector2i):
	if harmful_areas.has(coords):
		harmful_areas[coords].queue_free()
		harmful_areas.erase(coords)

func _create_tree_shadow(coords: Vector2i, size: float):
	if tree_shadows.has(coords):
		return
	
	var shadow_scene = preload("res://scenes/shadow.tscn")
	var shadow_instance = shadow_scene.instantiate()
	
	tiles.add_child(shadow_instance)
	shadow_instance.position = tiles.map_to_local(coords)
	shadow_instance.position.y += 16
	if size == 1.0:
		shadow_instance.position.y -= 11
	shadow_instance.scale = Vector2(size, size)
	tree_shadows[coords] = shadow_instance

func _remove_tree_shadow(coords: Vector2i):
	if tree_shadows.has(coords):
		tree_shadows[coords].queue_free()
		tree_shadows.erase(coords)
