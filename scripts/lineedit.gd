extends LineEdit

var initial_position: Vector2
var is_keyboard_open: bool = false

func _ready():
	# Store the initial position when the node is ready
	initial_position = global_position
	
	# Connect to focus signals
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

func _process(_delta):
	if has_focus() and Man.is_mobile():
		var keyboard_height = DisplayServer.virtual_keyboard_get_height()
		if OS.get_name() == "iOS":
			keyboard_height -= 250
		
		# Check if keyboard state changed
		if keyboard_height > 0 and not is_keyboard_open:
			# Keyboard just opened
			is_keyboard_open = true
			_adjust_position_for_keyboard(keyboard_height)
		elif keyboard_height == 0 and is_keyboard_open:
			# Keyboard just closed
			is_keyboard_open = false
			_reset_position()

func _on_focus_entered():
	# When focus is gained, start checking for keyboard
	pass

func _on_focus_exited():
	# When focus is lost, reset position
	if is_keyboard_open:
		is_keyboard_open = false
		_reset_position()

func _adjust_position_for_keyboard(keyboard_height: float):
	# Calculate how much we need to move up
	var viewport_size = get_viewport_rect().size
	var field_bottom = global_position.y + size.y
	var available_space = viewport_size.y - keyboard_height
	
	# If the field would be obscured by the keyboard, move it up
	if field_bottom > available_space:
		var offset = field_bottom - available_space + 20  # 20px padding
		global_position.y = initial_position.y - offset

func _reset_position():
	# Move back to original position
	global_position = initial_position
