extends GPUParticles2D

@export var wind_change_interval := 5.0
var timer := 0.0

func _process(delta: float) -> void:
	timer += delta
	if timer > wind_change_interval:
		timer = 0.0
		var mat = process_material as ParticleProcessMaterial
		var random_dir = Vector3(randf_range(-1.0, 1.0), 1.0, 1.0).normalized()
		mat.direction = random_dir
