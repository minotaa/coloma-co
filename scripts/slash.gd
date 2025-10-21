extends Line2D

@export var fade_speed := 0.02
@export var points_per_segment := 12  # how many interpolated points between each pair
@export var draw_speed := 0.05  # How long it takes to draw the slash (in seconds)

var full_points: Array[Vector2] = []
var draw_progress := 0.0
var is_drawing := true
var reverse_draw := false  # Whether to draw from end to start

func show_slash(global_points: Array[Vector2]) -> void:
	clear_points()
	if global_points.is_empty():
		return

	# Convert to local coordinates (Line2D points are local to the node)
	var local_points: Array[Vector2] = []
	for gp in global_points:
		local_points.append(to_local(gp))

	# Interpolate with Catmull-Rom to produce a smooth curve
	full_points = _catmull_rom_chain(local_points, points_per_segment)
	
	# Randomly decide if we draw forwards or backwards
	reverse_draw = randf() > 0.5
	
	# Start with no points visible
	draw_progress = 0.0
	is_drawing = true
	modulate.a = 1.0

func _process(delta: float) -> void:
	if is_drawing:
		# Animate drawing the slash
		draw_progress += delta / draw_speed
		
		if draw_progress >= 1.0:
			draw_progress = 1.0
			is_drawing = false
		
		# Update visible points based on progress
		clear_points()
		var visible_count = int(full_points.size() * draw_progress)
		
		if reverse_draw:
			# Draw from end to start
			var start_index = full_points.size() - visible_count
			for i in range(start_index, full_points.size()):
				add_point(full_points[i])
			
			# Interpolate partial point
			if visible_count < full_points.size() and visible_count > 0:
				var t = fmod(full_points.size() * draw_progress, 1.0)
				var current_index = full_points.size() - visible_count - 1
				if current_index >= 0:
					var next_point = full_points[current_index + 1]
					var current_point = full_points[current_index]
					add_point(current_point.lerp(next_point, t))
		else:
			# Draw from start to end (original behavior)
			for i in range(visible_count):
				add_point(full_points[i])
			
			# Interpolate partial point
			if visible_count < full_points.size() and visible_count > 0:
				var t = fmod(full_points.size() * draw_progress, 1.0)
				var last_point = full_points[visible_count - 1]
				var next_point = full_points[visible_count]
				add_point(last_point.lerp(next_point, t))
	else:
		# Fade out after drawing is complete
		modulate.a = max(0.0, modulate.a - fade_speed * delta)
		if modulate.a <= 0.0:
			queue_free()

# --- Catmull-Rom utilities ---
func _catmull_rom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	# standard Catmull-Rom spline formula (t in [0,1])
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1) +
		(-p0 + p2) * t +
		(2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
		(-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)

func _catmull_rom_chain(points: Array[Vector2], steps: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if points.size() == 0:
		return out

	# Pad endpoints so the chain includes endpoints smoothly
	var pts: Array[Vector2] = []
	pts.append(points[0])
	for p in points:
		pts.append(p)
	pts.append(points[points.size() - 1])

	# For each segment, produce 'steps' interpolated points
	for i in range(pts.size() - 3):
		var p0 := pts[i]
		var p1 := pts[i + 1]
		var p2 := pts[i + 2]
		var p3 := pts[i + 3]
		for s in range(steps):
			var t := float(s) / float(steps)
			out.append(_catmull_rom(p0, p1, p2, p3, t))

	# Ensure final real point is present
	out.append(points[points.size() - 1])
	return out
