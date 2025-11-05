extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite2D

var tossable: Tossable = null
var smoke_scene: PackedScene = preload("res://scenes/smoke.tscn")

# Jump animation properties
var jump_height: float = 80.0
var jump_duration: float = 0.5
var land_position: Vector2
var start_position: Vector2
var jump_timer: float = 0.0
var is_jumping: bool = true

# Effect properties
var duration_timer: float = 0.0
var update_timer: float = 0.0

func _ready():
	# Store positions for jump animation
	land_position = global_position
	start_position = global_position  # Start at spawn position
	
	if tossable:
		setup_tossable(tossable)

func setup_tossable(item: Tossable):
	tossable = item
	
	# Set sprite texture
	sprite.texture = tossable.texture
	
	# Call the on_toss callback
	if tossable.on_toss:
		tossable.on_toss.call(self, global_position)

func _physics_process(delta: float):
	if is_jumping:
		_handle_jump(delta)
	else:
		_handle_effect(delta)

func _handle_jump(delta: float):
	jump_timer += delta
	var progress = jump_timer / jump_duration
	
	if progress >= 1.0:
		# Finished jumping
		global_position = land_position
		is_jumping = false
		progress = 1.0
	else:
		# Parabolic jump arc
		var t = progress
		var height_curve = sin(t * PI)  # Smooth arc: 0 -> 1 -> 0
		
		# Keep horizontal position at land spot, only animate Y
		global_position = land_position
		global_position.y -= height_curve * jump_height

func _handle_effect(delta: float):
	if not tossable:
		return
	
	# Handle duration (lifetime)
	if tossable.duration > 0:
		duration_timer += delta
		if duration_timer >= tossable.duration:
			_end_effect()
			return
	
	# Handle update intervals
	update_timer += delta
	
	# Call on_update based on interval (0 = every frame)
	if tossable.update_interval == 0:
		# Every frame
		if tossable.on_update:
			tossable.on_update.call(self, global_position)
	elif update_timer >= tossable.update_interval:  # Changed from tossable.duration
		# Fixed interval
		update_timer = 0.0
		if tossable.on_update:
			tossable.on_update.call(self, global_position)

func _end_effect():
	# Call the on_end callback
	if tossable and tossable.on_end:
		tossable.on_end.call(self, global_position)
	
	# Spawn smoke poof
	var smoke = smoke_scene.instantiate()
	smoke.global_position = global_position
	smoke.emitting = true
	get_parent().add_child(smoke)
	
	# Remove self
	queue_free()
