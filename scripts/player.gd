extends CharacterBody2D

const SPEED = 75.0

@onready var tilemap: TileMapLayer = $"../Tiles"
@onready var progress_bar: TextureProgressBar = $UI/Main/ProgressBar

var directions = {
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT,
	"up": Vector2.UP,
	"down": Vector2.DOWN
}
var last_direction = "down"

var target_tile: Vector2i
var mining_progress = 0.0
var mining_time = 0.0
var is_mining = false

var bag = Bag.new()

func _ready() -> void:
	Items.connect("collect_item", collect_item)
	bag.list = [ItemStack.new(Items.get_by_id(0), 24)]
	
func collect_item(item: ItemStack) -> void:
	Toast.add("Collected x" + str(item.amount) + " " + str(item.type.name))
	print(bag.add_fragile_item(item))

func play_animation(name: String, backwards: bool = false, speed: float = 1) -> void:
	if backwards == false:
		$AnimatedSprite2D.play(name, speed)
	else:
		$AnimatedSprite2D.play(name, speed * -1, true)

func play_idle_animation() -> void:
	play_animation("idle_" + last_direction)
	
func _process_input(delta) -> void:
	velocity = Input.get_vector("left", "right", "up", "down", 0.1)

	var velocity_length = velocity.length_squared()
	if velocity_length > 0:
		velocity_length = min(1, 0.5 + velocity_length)
		if abs(velocity.x) > abs(velocity.y):
			if velocity.x > 0:
				last_direction = "right"
				play_animation("walk_right", false, velocity_length)
			else:
				last_direction = "left"
				play_animation("walk_left", false, velocity_length)
		else:
			if velocity.y > 0:
				last_direction = "down"
				play_animation("walk_down", false, velocity_length)
			else:
				last_direction = "up"
				play_animation("walk_up", false, velocity_length)
	
	velocity *= SPEED
	
	if velocity.x == 0 and velocity.y == 0:
		if $AnimatedSprite2D.animation == "walk_left" or $AnimatedSprite2D.animation == "walk_up" or $AnimatedSprite2D.animation == "walk_down" or $AnimatedSprite2D.animation == "walk_right":
			play_idle_animation()
			
	#var texts = [
		#"Short",
		#"Medium length toast",
		#"This one is a bit longer to test alignment",
		#"A really long toast message that should still stack properly",
		#"Small"
	#]
	#Toast.add(texts.pick_random())
	
	if Input.is_action_pressed("mine") and target_tile and !is_mining:
		start_mining(target_tile)
	elif is_mining and (!target_tile or !Input.is_action_pressed("mine")):
		reset_mining()

	move_and_slide()

func _physics_process(delta: float) -> void:
	_process_input(delta)
	progress_bar.position = get_viewport().get_mouse_position() + Vector2(10, 10)
	var mouse_pos = tilemap.local_to_map(tilemap.get_local_mouse_position())
	var tile_data = tilemap.get_cell_tile_data(mouse_pos)

	if tile_data and not nearby_tiles.has(mouse_pos) and Input.is_action_just_pressed("mine"):
		Toast.add("Too far away.")

	if tile_data and nearby_tiles.has(mouse_pos):
		target_tile = mouse_pos
	else:
		target_tile = Vector2i.ZERO

	if is_mining and target_tile not in nearby_tiles:
		reset_mining()

	if is_mining and target_tile:
		mining_progress += delta
		progress_bar.visible = true
		progress_bar.value = (mining_progress / mining_time) * 100

		if mining_progress >= mining_time:
			mine_tile(target_tile)
			reset_mining()
	else:
		mining_progress = 0.0
		progress_bar.value = 0
		progress_bar.visible = false

func start_mining(tile_coords: Vector2i):
	var tile_data = tilemap.get_cell_tile_data(tile_coords)
	if tile_data and tile_data.get_custom_data("mineable"):
		is_mining = true
		mining_progress = 0.0
		mining_time = tile_data.get_custom_data("hardness")
		progress_bar.visible = true
		print("Started mining: ", tile_coords)

func reset_mining():
	is_mining = false
	mining_progress = 0.0
	progress_bar.visible = false
	progress_bar.value = 0

func mine_tile(tile_coords: Vector2i):
	var tile_data = tilemap.get_cell_tile_data(tile_coords)
	if tile_data:
		var tile_id = tile_data.get_custom_data("tile_id")
		handle_tile_logic(tile_id, tile_coords)
		tilemap.set_cell(tile_coords)  # Remove tile
		print("Mined tile: ", tile_id)
		#Toast.add("Mined tile: " + str(tile_id))

func handle_tile_logic(tile_id, tile_coords):
	Tiles.get_by_id(tile_id).on_break.call(tilemap.map_to_local(tile_coords))
	print("Mined tile with ID: ", tile_id)

var nearby_tiles: Array[Vector2i] = []

func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body is TileMapLayer:
		var tile_coords: Vector2i = tilemap.get_coords_for_body_rid(body_rid)
		var tile_data = tilemap.get_cell_tile_data(tile_coords)
		if tile_data and tile_data.get_custom_data("mineable"):
			nearby_tiles.append(tile_coords)

func _on_body_shape_exited(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	if body is TileMapLayer:
		var tile_coords = tilemap.get_coords_for_body_rid(body_rid)
		if tile_coords in nearby_tiles:
			nearby_tiles.erase(tile_coords)
