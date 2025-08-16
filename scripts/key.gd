@tool
extends Control

@export var keycode: String = "MOUSE_BUTTON_LEFT":
	set(value):
		keycode = value
		_update_display()

# Mouse button textures
const MOUSE_MAPPING = {
	"MOUSE_BUTTON_LEFT": "res://assets/sprites/lmb.png",
	"MOUSE_BUTTON_RIGHT": "res://assets/sprites/rmb.png",
	"MOUSE_BUTTON_MIDDLE": "res://assets/sprites/mmb.png"
}

# Special keys mapping to symbols
const SPECIAL_KEYS = {
	KEY_TAB: "⇥",
	KEY_UP: "↑",
	KEY_DOWN: "↓",
	KEY_LEFT: "←",
	KEY_RIGHT: "→",
	KEY_COMMA: ",",
	KEY_PERIOD: ".",
	KEY_SHIFT: "⇧"
}

func _ready() -> void:
	_update_display()

func _update_display() -> void:
	if not is_inside_tree():
		return
	
	if keycode in MOUSE_MAPPING:
		$Label.hide()
		$TextureRect.hide()
		$TextureRect2.texture = load(MOUSE_MAPPING[keycode])
		$TextureRect2.show()
		$TextureRect2.scale = Vector2(0.5, 0.5)
	else:
		var key_int = int(keycode)
		var display_text = ""
		if SPECIAL_KEYS.has(key_int):
			display_text = SPECIAL_KEYS[key_int]
		else:
			display_text = OS.get_keycode_string(key_int)
		$Label.text = display_text
		$Label.show()
		$TextureRect.show()
		$TextureRect2.hide()