extends Node

func _ready():
	# Create screenshots directory if it doesn't exist
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")

func _input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_BACKSLASH:
			take_screenshot()

func take_screenshot():
	# Get the viewport
	var img = get_viewport().get_texture().get_image()
	
	# Generate filename with timestamp
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
	var filename = "screenshot_%s.png" % timestamp
	var path = "user://screenshots/%s" % filename
	
	# Save the image
	var error = img.save_png(path)
	
	if error == OK:
		print("Screenshot saved to: %s" % path)
		print("Actual path: %s" % ProjectSettings.globalize_path(path))
	else:
		print("Error saving screenshot: ", error)
