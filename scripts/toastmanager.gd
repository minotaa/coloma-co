extends Node

var canvas_layer: CanvasLayer
var toast_resource = preload("res://scenes/toast.tscn")
var toasts = []
var toast_queue = []  # Holds queued toasts
var max_toasts = 5

const MARGIN_TOP = 20
const MARGIN_BETWEEN = 5
const FADE_DURATION = 0.8
const TOAST_LIFETIME = 2.5


func _ready() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.set_name("ToastLayer")
	canvas_layer.layer = 128
	add_child(canvas_layer)

func add(text: String):
	var config = {
		"text": text
	}
	if toasts.size() < max_toasts:
		_show_toast(config)
	else:
		toast_queue.append(config)

func _show_toast(config):
	var toast = toast_resource.instantiate()
	canvas_layer.add_child(toast)
	toasts.insert(0, toast)  # New toasts go at the front
	toast.init(config)

	# Ensure proper positioning after layout updates
	await get_tree().process_frame  
	_reposition_toasts()

	# Connect to toast removal signal
	toast.connect("toast_faded", Callable(self, "_on_toast_removed").bind(toast))

func _reposition_toasts():
	var current_y = MARGIN_TOP
	for toast in toasts:
		toast.move_to(current_y)  
		current_y += toast.size.y + MARGIN_BETWEEN  

func _on_toast_removed(toast):
	toasts.erase(toast)
	_reposition_toasts()
	
	# If toasts are queued, show the next one
	if toast_queue.size() > 0:
		_show_toast(toast_queue.pop_front())
