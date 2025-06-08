extends Node2D

var rng = RandomNumberGenerator.new()
@export var map_size: Vector2i = Vector2i(100, 100)
@export var tiles: Array[int] = [1, 2]
@export var scatter_chance: float = 0.1
@export var seed: int = 0

@onready var tile_layer = $Tiles
@onready var ground_layer = $Ground
@onready var canvas_modulate := $CanvasModulate

const DAY_COLOR := Color.WHITE
const NIGHT_COLOR := Color(35 / 255.0, 26 / 255.0, 98 / 255.0)

const SECONDS_PER_TICK := 8.333 # real-world seconds per 10 in-game minutes
const MINUTES_PER_TICK := 10
const TOTAL_MINUTES_IN_DAY := 24 * 60

var current_minutes := 6 * 60 # Start at 6:00 AM
var time_accumulator := 0.0

func _ready() -> void:
	print("Generating world...")
	_generate_seed()
	print("Generated seed... now generating level.")
	_generate_world()
	print("Done!")
	_update_sky_color()

func _process(delta: float) -> void:
	time_accumulator += delta
	_update_sky_color()
	if time_accumulator >= SECONDS_PER_TICK:
		time_accumulator -= SECONDS_PER_TICK
		current_minutes = (current_minutes + MINUTES_PER_TICK) % TOTAL_MINUTES_IN_DAY

func _update_sky_color() -> void:
	var t := _get_day_progress_ratio()
	canvas_modulate.color = DAY_COLOR.lerp(NIGHT_COLOR, t)

# 0.0 = fully day, 1.0 = fully night
func _get_day_progress_ratio() -> float:
	# Optional: tweak to your own cycle
	# 6:00 - 18:00 is day, 18:00 - 6:00 is night
	var hour := current_minutes / 60.0
	if hour >= 6.0 and hour < 18.0:
		# Daytime: progress from 0 to 1 from 6:00 to 18:00
		return clamp((hour - 6.0) / 12.0, 0.0, 1.0)
	else:
		# Nighttime: progress from 1 to 0 from 18:00 to 6:00
		if hour < 6.0:
			hour += 24.0
		return clamp(1.0 - ((hour - 18.0) / 12.0), 0.0, 1.0)
		
func get_game_time_string() -> String:
	var total_minutes := current_minutes % TOTAL_MINUTES_IN_DAY
	var hours := int(total_minutes / 60)
	var minutes := total_minutes % 60

	var suffix := "AM"
	if hours >= 12:
		suffix = "PM"

	var display_hour := hours % 12
	if display_hour == 0:
		display_hour = 12

	return "%d:%02d %s" % [display_hour, minutes, suffix]

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
	tile_layer.set_cell(Vector2(0, 0), 1, Vector2(0, 0))
