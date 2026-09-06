extends Entity

const TARGET_DELAY := 5.0
const PULSE_MIN_SCALE := 0.8
const PULSE_MAX_SCALE := 1.2
const PULSE_DURATION := 1.2

const DROP_HEIGHT := 400.0
const DROP_SPEED := 900.0

const MIN_DAMAGE := 15.0
const MAX_DAMAGE := 30.0
const EXPLOSION_RADIUS := 20.0
const EXPLOSION_TIME := 0.4

@onready var target_marker = $Target
@onready var shell_sprite = $AnimatedSprite2D

var target_position: Vector2
var is_armed: bool = true
var pulse_tween: Tween

func initialize_entity() -> void:
	entity_name = "Bombrat Mortar"
	bestiary_description = "A stationary variant that marks a target before launching an explosive shell at it. Best to move once you see the reticle."
	developer_commentary = ""
	dev_commentary_requirement = 50
	health = 150.0
	max_health = 150.0
	defense = 0.0
	id = 16

	shell_sprite.visible = false
	shell_sprite.play("idle")
	target_marker.visible = true

	var target_player = get_nearest_player()
	if target_player:
		target_position = target_player.global_position
	else:
		target_position = global_position

	target_marker.global_position = target_position
	target_marker.scale = Vector2.ONE * PULSE_MIN_SCALE
	_start_pulse()

	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			get_tree().create_timer(TARGET_DELAY).timeout.connect(func(): _launch.rpc())
	else:
		get_tree().create_timer(TARGET_DELAY).timeout.connect(_launch)

func _start_pulse() -> void:
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(target_marker, "scale", Vector2.ONE * PULSE_MAX_SCALE, PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(target_marker, "scale", Vector2.ONE * PULSE_MIN_SCALE, PULSE_DURATION)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

@rpc("any_peer", "call_local", "reliable")
func _launch() -> void:
	if not alive:
		return
	is_armed = false
	if pulse_tween:
		pulse_tween.kill()
	target_marker.visible = false

	shell_sprite.visible = true
	shell_sprite.global_position = target_position - Vector2(0, DROP_HEIGHT)

	var fall_time = DROP_HEIGHT / DROP_SPEED
	var tween = create_tween()
	tween.tween_property(shell_sprite, "global_position", target_position, fall_time)\
		.set_trans(Tween.TRANS_LINEAR)
	tween.finished.connect(_detonate)

func _detonate() -> void:
	var explosion_scene = preload("res://scenes/lethal_explosion.tscn")
	var explosion = explosion_scene.instantiate()
	explosion.global_position = target_position
	explosion.emitting = true
	explosion.MIN_DAMAGE = MIN_DAMAGE
	explosion.MAX_DAMAGE = MAX_DAMAGE
	explosion.MAX_RADIUS = EXPLOSION_RADIUS
	explosion.EXPANSION_TIME = EXPLOSION_TIME

	get_parent().add_child(explosion, true)
	alive = false
	die()

func on_player_contact(player: Node) -> void:
	pass

func get_gold_reward() -> int:
	return 0

func get_kill_type() -> String:
	return "bombrat_mortar"
