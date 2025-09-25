# DitherFade.gd
# Complete dithering fade script - add as Autoload
extends Node

var canvas_layer: CanvasLayer
var fade_rect: ColorRect
var dither_shader: Shader
var shader_material: ShaderMaterial
var is_fading = false

func _ready():
	canvas_layer = CanvasLayer.new()
	canvas_layer.set_name("DitherFadeLayer")
	canvas_layer.layer = 128
	add_child(canvas_layer)
	
	dither_shader = load("res://scripts/dither.gdshader")
	shader_material = ShaderMaterial.new()
	shader_material.shader = dither_shader
	
	# Create the fade rectangle
	fade_rect = ColorRect.new()
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.color = Color.WHITE  # Base color (shader handles the effect)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.material = shader_material
	canvas_layer.add_child(fade_rect)
	
	# Set initial shader parameters
	shader_material.set_shader_parameter("fade_amount", 0.0)
	shader_material.set_shader_parameter("fade_color", Vector3(0.0, 0.0, 0.0))  # Black
	shader_material.set_shader_parameter("dither_scale", 2.0)

# Call this function to dither fade to a new scene
func fade_to_scene(scene_path: String, fade_duration: float = 1.0, dither_scale: float = 2.0):
	if is_fading:
		return
	
	is_fading = true
	shader_material.set_shader_parameter("dither_scale", dither_scale)
	
	# Dither fade to black
	var tween = create_tween()
	tween.tween_method(_update_fade_amount, 0.0, 1.0, fade_duration / 2)
	
	# Wait for fade to complete, then change scene
	await tween.finished
	
	# Change the scene
	get_tree().change_scene_to_file(scene_path)
	
	# Dither fade back in
	tween = create_tween()
	tween.tween_method(_update_fade_amount, 1.0, 0.0, fade_duration / 2)
	
	await tween.finished
	is_fading = false

# Dither fade out only (useful for game over, etc.)
func fade_out(fade_duration: float = 1.0, max_dither_scale: float = 8.0):
	if is_fading:
		return

	is_fading = true

	var tween = create_tween()
	tween.parallel().tween_method(_update_fade_amount, 0.0, 1.0, fade_duration)
	tween.parallel().tween_method(_update_dither_scale, 1.0, max_dither_scale, fade_duration)
	await tween.finished

# Dither fade in from black
func fade_in(fade_duration: float = 1.0, max_dither_scale: float = 8.0):
	var tween = create_tween()
	tween.parallel().tween_method(_update_fade_amount, 1.0, 0.0, fade_duration)
	tween.parallel().tween_method(_update_dither_scale, max_dither_scale, 1.0, fade_duration)
	await tween.finished
	is_fading = false

# Set the fade color (default is black)
func set_fade_color(color: Color):
	var color_vec = Vector3(color.r, color.g, color.b)
	shader_material.set_shader_parameter("fade_color", color_vec)

# Internal function to update the shader parameter
func _update_fade_amount(amount: float):
	shader_material.set_shader_parameter("fade_amount", amount)

# Internal function to update the dither scale
func _update_dither_scale(scale: float):
	shader_material.set_shader_parameter("dither_scale", scale)
