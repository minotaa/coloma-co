extends Node2D

@onready var area: Area2D = $Area2D

func _ready() -> void:
	rotation += randi_range(0, 180)
	await get_tree().create_timer(6.5).timeout
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.tween_property(self, "rotation", rotation + TAU, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ZERO, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	for body in area.get_overlapping_bodies():
		if body != null and body.is_in_group("players") and body.alive:
			if not body.has_effect("Gunked"):
				var gunked = Effect.new("Gunked", Color.from_rgba8(0, 150, 255, 255), 8.0, 0, 0)
				body.add_status_effect(gunked)
				if multiplayer.has_multiplayer_peer():
					Toast.add.rpc_id(int(body.name), "You've been Gunked for 8 seconds!")
				else:
					Toast.add("You've been Gunked for 8 seconds!")
