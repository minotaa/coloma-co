extends Control

func _ready() -> void:
	_update_values()
	
func _update_values() -> void:
	if Man.is_mobile():
		$General/ScrollContainer/VBoxContainer/Fullscreen.visible = false
	$General/ScrollContainer/VBoxContainer/Fullscreen/CheckBox.button_pressed = Man.fullscreen
	$"General/ScrollContainer/VBoxContainer/Flick Control/CheckBox2".button_pressed = Man.flick_control
	$General/ScrollContainer/VBoxContainer/SFX/HSlider.value = Man.sfx_volume
	$General/ScrollContainer/VBoxContainer/Music/HSlider.value = Man.music_volume
	$General/ScrollContainer/VBoxContainer/Zoom/HSlider.value = Man.zoom

func _notification(what: int) -> void:
	if what == 31:
		_update_values()

func _on_controls_pressed() -> void:
	if not Man.is_in_game():
		get_node("../../../..").current_state = get_node("../../../..").MenuState.OPTIONS_CONTROLS
		get_node("../../../..").state_nodes[get_node("../../../..").MenuState.OPTIONS].visible = true
	$General.visible = false
	$Controls.visible = true
	
	var keybind_scene = preload("res://scenes/keybind.tscn")
	var container = $Controls/ScrollContainer/VBoxContainer
	for child in container.get_children():
		child.queue_free()
	
	for control in Man.controls.keys():
		var key = keybind_scene.instantiate()
		key.get_node("HBoxContainer/Label").text = Man.controls[control]
		key.get_node("HBoxContainer/Key").keycode = str(control)
		container.add_child(key)
	
	# Wait for buttons to be ready, then focus back button
	await get_tree().process_frame
	# Focus the back button
	if get_node("../..").has_node("Back"):
		get_node("../../Back").grab_focus()
	else:
		# Fallback: try to find any back button in Options
		for child in get_node("../..").find_children("Back", "Button", true):
			child.grab_focus()
			break

func _on_credits_pressed() -> void:
	if not Man.is_in_game():
		get_node("../../../..").current_state = get_node("../../../..").MenuState.OPTIONS_CREDITS
		get_node("../../../..").state_nodes[get_node("../../../..").MenuState.OPTIONS].visible = true
	$General.visible = false
	$Credits.visible = true
	
	# Focus the back button
	if get_node("../..").has_node("Back"):
		get_node("../../Back").grab_focus()
	else:
		# Fallback: try to find any back button in Options
		for child in get_node("../..").find_children("Back", "Button", true):
			child.grab_focus()
			break

func _on_fullscreen_check_box_toggled(toggled_on: bool) -> void:
	var mode: int = 0
	if toggled_on:
		mode = 3
	DisplayServer.window_set_mode(mode)
	Man.fullscreen = toggled_on

func _on_sfx_slider_drag_ended(value_changed: bool) -> void:
	Man.play_ui_sfx(preload("res://assets/sounds/f_slash.wav"))

func _on_sfx_slider_value_changed(value: float) -> void:
	Man.sfx_volume = value
	if value <= 0.0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), true)
	else:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), false)
		var db_value = lerp(-55.0, 0.0, value / 100.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), db_value)

func _on_music_slider_value_changed(value: float) -> void:
	Man.music_volume = value
	if value <= 0.0:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), true)
	else:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), false)
		var db_value = lerp(-55.0, 0.0, value / 100.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), db_value)

func _on_music_slider_drag_ended(value_changed: bool) -> void:
	Man.play_ui_sfx(preload("res://assets/sounds/f_slash.wav"), "Music")

func _on_zoom_slider_drag_ended(value_changed: bool) -> void:
	pass

func _on_zoom_slider_value_changed(value: float) -> void:
	Man.zoom = value
