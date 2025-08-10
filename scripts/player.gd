extends CharacterBody2D

var current_log_path: String
var original_zoom := Vector2(5.0, 5.0)
var zoom_multiplier := 1.0
var directions := {
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT,
	"up": Vector2.UP,
	"down": Vector2.DOWN
}
var last_direction := "down"
const SWORD_HITBOX_TIME := 0.15
var sword_hitbox_timer := 0.0
var sword_hitbox_active := false
var hit_enemies := []
var knockback_velocity := Vector2.ZERO
var knockback_friction := 800.0
var hit_cooldown := 0.0
var max_hit_cooldown := 0.35

const SPEED := 120.0
const SPRINT_MULTIPLIER := 1.45
var exhausted := false # When you deplete your sprint completely you will become exhausted
var sprint := 220.0
var alive: bool = true
var max_health := 100.0
var health := 100.0
var damage := 25.0
var strength := 0
var sword_reach := 1.55  # Base reach
var gold: int = 0

var revival_time: float = 0.0
const MAX_REVIVAL_TIME: float = 10.0 # like in seconds and stuff
var bag = Bag.new()

# stats and stuff
var total_damage_taken: float = 0.0
var damage_taken: float = 0.0
var total_damage_dealt: float = 0.0
var damage_dealt: float = 0.0
var total_gold_collected: int = 0
var gold_collected: int = 0
var total_damage_healed: float = 0.0
var damage_healed: float = 0.0
var total_kills: int = 0
var kills: int = 0

var active_effects: Array = []

func add_status_effect(effect: Effect) -> void:
	effect.on_apply.call(self)
	active_effects.append(effect)

func has_effect(effect_name: String) -> bool:
	for effect in active_effects:
		if effect.name == effect_name:
			return true
	return false

func reset_status_effects() -> void:
	for effect in active_effects:
		effect.on_end.call(self)
	active_effects.clear()

@onready var hitting_particles_instance = preload("res://scenes/hitting_particles.tscn")
@onready var bombrat_counter := $UI/Main/HBoxContainer/Bombrats/HBoxContainer/Label
@onready var camera := get_viewport().get_camera_2d()
@onready var marker_container := $UI/Main/Markers
@onready var marker_scene := preload("res://scenes/marker.tscn")

var active_markers := {}

func get_bombrats_to_track():
	var bombrats = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.entity.id == 1 or enemy.entity.id == 4:
			bombrats.append(enemy)
	return bombrats
	
func get_big_bombrats_to_track():
	var bombrats = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.entity.id == 4:
			bombrats.append(enemy)
	return bombrats

func reset_game() -> void:
	kills = 0
	total_kills = 0
	damage_dealt = 0.0
	damage_healed = 0.0
	damage_taken = 0.0
	gold_collected = 0
	health = max_health
	revival_time = 0.0
	gold = 0
	sprint = 220
	alive = true
	bag = Bag.new()
	global_position = Vector2(0, 0)
	play_idle_animation()
	$"UI/Main/Game Over".visible = false
	$UI/Main/Death.visible = false
	show_ui()

func end_game() -> void:
	hide_ui()
	var stats_text := "Your final stats:\n"
	stats_text += "Final wave:\t " + str(get_parent().wave)
	stats_text += "\nGold:\t " + str(gold_collected) + " (" + percent(gold_collected, total_gold_collected) + ")\n"
	stats_text += "Kills:\t " + str(kills) + " (" + percent(kills, total_kills) + ")\n"
	stats_text += "Damage Dealt:\t " + str(roundi(damage_dealt)) + " (" + percent(damage_dealt, total_damage_dealt) + ")\n"
	stats_text += "Damage Taken:\t " + str(roundi(damage_taken)) + " (" + percent(damage_taken, total_damage_taken) + ")\n"
	stats_text += "Damage Healed:\t " + str(roundi(damage_healed)) + " (" + percent(damage_healed, total_damage_healed) + ")"
	$"UI/Main/Game Over".visible = true
	$"UI/Main/Game Over/Panel/Meta".text = stats_text
	if (not multiplayer.has_multiplayer_peer()) or 1 == multiplayer.get_unique_id():
		$"UI/Main/Game Over/Panel/Play Again".visible = true
		$"UI/Main/Game Over/Panel/Main Menu".visible = true
	else:
		$"UI/Main/Game Over/Panel/Play Again".visible = false
		$"UI/Main/Game Over/Panel/Main Menu".visible = false

func _enter_tree() -> void:
	if multiplayer.has_multiplayer_peer():
		set_multiplayer_authority(name.to_int())

func send_title(title: String, delay: float) -> void:
	print("Showing title \"" + title + "\" to player.")
	$UI/Main/Title.text = title
	await get_tree().create_timer(delay).timeout
	$UI/Main/Title.text = ""
	
func _ready() -> void:	
	if multiplayer.has_multiplayer_peer():
		set_multiplayer_authority(name.to_int())
		for player in NetworkManager.players:
			if player["id"] == name.to_int():
				$Username.text = player["username"]
		$Username.visible = true
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		$UI.visible = false
		$PointLight2D.visible = false
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		$Camera2D.make_current()
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		if not DirAccess.dir_exists_absolute("user://chats"):
			DirAccess.make_dir_absolute("user://chats")
			
		var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
		current_log_path = "user://chats/%s.log" % timestamp
		
		var file = FileAccess.open(current_log_path, FileAccess.WRITE)
		if file:
			file.store_line("--- Chat session started at %s ---" % timestamp)
		file.close()
		
func heal(amount: float) -> void:	
	if alive:
		var old_health = health
		health = min(health + amount, max_health)
		var healed = roundi(health - old_health)
		damage_healed += healed
		total_damage_healed += healed
		
		if healed > 0:
			var text = "+" + str(healed) + " HP"
			if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
				Toast.add.rpc_id(int(name), text)
			else:
				Toast.add(text)
		$Healing.emitting = true

	
func take_damage(amount: float, location: Vector2 = Vector2.ZERO) -> void:
	if hit_cooldown > 0.0 or not alive:
		return
	print("Player took ", amount, " damage")
	hit_cooldown = max_hit_cooldown
	health = health - amount
	damage_taken += amount
	total_damage_taken += amount
	apply_knockback(location, 220.0)
	show_floating_text(amount, global_position)
	if health <= 0:
		die()
	$AnimatedSprite2D.material = preload("res://scenes/shock.tres")
	await get_tree().create_timer(0.1).timeout
	$AnimatedSprite2D.material = null

func percent(current: float, total: float) -> String:
	if total > 0.0:
		return str(roundi((current / total) * 100)) + "%"
	return "0%"



func die() -> void:
	$AnimatedSprite2D.play("death")
	$AnimatedSprite2D.material = preload("res://scenes/shock.tres")
	Toast.add.rpc_id(int(name), "You're dead... you will respawn in 10 seconds.")
	revival_time = MAX_REVIVAL_TIME
	alive = false
	hide_ui()
	$"UI/Main/Death".visible = true	
	var stats_text := "This life:\n"
	stats_text += "Gold:\t " + str(gold_collected) + " (" + percent(gold_collected, total_gold_collected) + ")\n"
	stats_text += "Kills:\t " + str(kills) + " (" + percent(kills, total_kills) + ")\n"
	stats_text += "Damage Dealt:\t " + str(roundi(damage_dealt)) + " (" + percent(damage_dealt, total_damage_dealt) + ")\n"
	stats_text += "Damage Taken:\t " + str(roundi(damage_taken)) + " (" + percent(damage_taken, total_damage_taken) + ")\n"
	stats_text += "Damage Healed:\t " + str(roundi(damage_healed)) + " (" + percent(damage_healed, total_damage_healed) + ")"

	$"UI/Main/Death/Panel/Meta".text = stats_text
	reset_status_effects()
	
	#health = max_health
	#gold = max(roundi(gold / 2), 0)
	#Toast.add("You respawned! You lost half your gold.")
	#play_idle_animation()
	#$AnimatedSprite2D.material = null
	#global_position = Vector2.ZERO
	#alive = true

func play_animation(name: String, backwards: bool = false, speed: float = 1) -> void:
	if backwards == false:
		$AnimatedSprite2D.play(name, speed)
	else:
		$AnimatedSprite2D.play(name, speed * -1, true)

func apply_knockback(from_position: Vector2, strength: float):
	var direction = (global_position - from_position).normalized()
	knockback_velocity = direction * strength

func play_idle_animation() -> void:
	play_animation("idle_" + last_direction)

func show_floating_text(amount: int, center_position: Vector2):
	var floating_text_scene = preload("res://scenes/floating_text.tscn")
	var floating_text = floating_text_scene.instantiate()
	floating_text.text = str(amount)
	(floating_text as Label).label_settings.font_color = Color.RED
	$"..".add_child(floating_text, true)

	var random_offset = Vector2(
		randi_range(-8, 8),
		randi_range(-8, 8)
	)
	floating_text.position = center_position + random_offset

func _process_input(delta) -> void:
	# Handle movement input
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if $UI/Main/ChatBar.has_focus() and alive:
		play_idle_animation()
	if not alive or $UI/Main/ChatBar.has_focus() or $"UI/Main/Game Over".visible:
		return
	if Input.is_action_just_pressed("interact"):
		if not $UI/Main/Shop.visible:
			for area in $Area2D.get_overlapping_areas():
				if (area as Area2D).is_in_group("gem"):
					$UI/Main/Shop.visible = true
					play_idle_animation()
					$UI/Main/Shop/Panel/HBoxContainer/Gold.text = str(gold)
		else:
			$UI/Main/Shop.visible = false
			
	if $UI/Main/Shop.visible:
		return
	velocity = Input.get_vector("left", "right", "up", "down", 0.1)
	var velocity_length = velocity.length_squared()
	var is_moving = velocity_length > 0

	if is_moving:
		velocity_length = min(1, 0.5 + velocity_length)

		# Determine last movement direction
		if abs(velocity.x) > abs(velocity.y):
			if velocity.x > 0:
				last_direction = "right"
			else:
				last_direction = "left"
		else:
			if velocity.y > 0:
				last_direction = "down"
			else:
				last_direction = "up"

		# Only play walk animation if not currently attacking
		if not $AnimatedSprite2D.animation.begins_with("sword_"):
			play_animation("walk_" + last_direction, false, velocity_length)
	else:
		# If idle and not attacking, play idle animation
		if $AnimatedSprite2D.animation.begins_with("walk_"):
			play_idle_animation()

	# Determine attack direction
	var attack_dir := ""

	if Input.is_action_just_pressed("attack_up"):
		attack_dir = "up"
	elif Input.is_action_just_pressed("attack_down"):
		attack_dir = "down"
	elif Input.is_action_just_pressed("attack_left"):
		attack_dir = "left"
	elif Input.is_action_just_pressed("attack_right"):
		attack_dir = "right"
	elif Input.is_action_just_pressed("attack"):
		var mouse_pos = get_global_mouse_position()
		var direction_vec = (mouse_pos - global_position).normalized()

		if abs(direction_vec.x) > abs(direction_vec.y):
			if direction_vec.x > 0.0:
				attack_dir = "right"
			else:
				attack_dir = "left"
		else:
			if direction_vec.y > 0.0:
				attack_dir = "down"
			else:
				attack_dir = "up"

	# Perform attack if a direction was determined
	if attack_dir != "":
		play_animation("sword_" + attack_dir)
		_enable_sword_hitbox(attack_dir)
		sword_hitbox_timer = SWORD_HITBOX_TIME
		sword_hitbox_active = true


	# Apply velocity and move
	velocity *= SPEED
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	else:
		knockback_velocity = Vector2.ZERO
	
	if Input.is_action_pressed("sprint") and sprint > 0 and not exhausted:
		velocity *= SPRINT_MULTIPLIER
		if velocity.length() > 0:
			sprint -= 1
	
	if Input.is_action_pressed("info") and not $UI/Main/Shop.visible:
		$UI/Main/Tab.visible = true
		for children in $UI/Main/Tab/ScrollContainer/VBoxContainer.get_children():
			children.queue_free()
		
		if multiplayer.has_multiplayer_peer():
			$UI/Main/Tab/Title.text = "Players (" + str(NetworkManager.players.size()) + ")"
			for player in NetworkManager.players:
				var kills = 0
				if get_parent().kills.has(str(player["id"])) and get_parent().kills[str(player["id"])].has("bombrat"):
					kills = get_parent().kills[str(player["id"])]["bombrat"]
				var tab_entry = preload("res://scenes/tab_entry.tscn").instantiate()
				tab_entry.get_node("Name").text = player["username"]
				tab_entry.get_node("Kills").text = str(kills)
				tab_entry.get_node("Gold").text = str(get_parent().get_node(str(player["id"])).gold)
				$UI/Main/Tab/ScrollContainer/VBoxContainer.add_child(tab_entry)
		else:
			$UI/Main/Tab/Title.text = "Player"
			var tab_entry = preload("res://scenes/tab_entry.tscn").instantiate()
			tab_entry.get_node("Name").text = "Player"
			tab_entry.get_node("Gold").text = str(gold)
			var kills = 0
			if get_parent().kills.has("Player") and get_parent().kills["Player"].has("bombrat"):
				var big_bombrat = 0
				if get_parent().kills["Player"].has("big_bombrat"):
					big_bombrat = get_parent().kills["Player"]["big_bombrat"]
				kills = get_parent().kills["Player"]["bombrat"] + big_bombrat
			tab_entry.get_node("Kills").text = str(kills)
			$UI/Main/Tab/ScrollContainer/VBoxContainer.add_child(tab_entry)
	else:
		$UI/Main/Tab.visible = false
	
	move_and_slide()

func press_inventory_slot(index: int) -> void:
	var slots = $UI/Main/Inventory.get_children()
	if index < 0 or index >= slots.size():
		return

	var slot = slots[index]
	var button = slot.get_node("Button")
	var timer = slot.get_node("Timer")
	var item = slot.item

	var cooldown_active = item and item.cooldown and timer.time_left > 0.0

	if alive and not cooldown_active:
		button.emit_signal("pressed")
		
func change_zoom(delta: float) -> void:
	zoom_multiplier = clamp(zoom_multiplier + delta, 0.50, 2.0)
	_update_camera_zoom()

	$UI/Main/Zoom/Label.text = "x%.2f" % zoom_multiplier
	$UI/Main/Zoom.visible = true
	$UI/Main/Zoom/Timer.start()
	
func _update_camera_zoom() -> void:
	$Camera2D.zoom = original_zoom * zoom_multiplier

func _on_zoom_timeout() -> void:
	$UI/Main/Zoom.visible = false
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not $UI/Main/ChatBar.visible:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				change_zoom(0.25)
			MOUSE_BUTTON_WHEEL_DOWN:
				change_zoom(-0.25) 
	if event.is_action_pressed("zoom_in") and not $UI/Main/ChatBar.visible:
		change_zoom(0.25)
	elif event.is_action_pressed("zoom_out") and not $UI/Main/ChatBar.visible:
		change_zoom(-0.25)
	
func _unhandled_input(event: InputEvent) -> void:
	if multiplayer.has_multiplayer_peer() and !is_multiplayer_authority():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			49:
				press_inventory_slot(0)
			50:
				press_inventory_slot(1)
			51:
				press_inventory_slot(2)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		$UI/Main/ChatBar.grab_focus()

func _enable_sword_hitbox(direction: String) -> void:
	var hitbox = $SwordHbox

	for child in hitbox.get_children():
		if child is CollisionShape2D:
			child.disabled = true

	if hitbox.has_node(direction):
		var shape_node = hitbox.get_node(direction)
		if shape_node is CollisionShape2D:
			shape_node.disabled = false

			var shape: Shape2D =  shape_node.shape
			var reach_factor := sword_reach / 2.0

			if shape is RectangleShape2D:
				#var slash = preload("res://scenes/slash.tscn").instantiate()
				#slash.emitting = true
				if direction == "up":
					shape.size = Vector2(58.0, 20.5 * reach_factor)
					shape_node.position = Vector2(0, -20 * reach_factor)
					#slash.process_material.gravity = Vector3(0.0, -98.0, 0.0)
					#slash.process_material.angle_min = 0
					#slash.process_material.angle_max = 0
					
				elif direction == "down":
					shape.size = Vector2(58.0, 20.5 * reach_factor)
					shape_node.position = Vector2(0, 20 * reach_factor)
					#slash.process_material.gravity = Vector3(0.0, 98.0, 0.0)
					#slash.process_material.angle_min = -180
					#slash.process_material.angle_max = -180

				elif direction == "left":
					shape.size = Vector2(20.5 * reach_factor, 58.0)
					shape_node.position = Vector2(-20 * reach_factor, 0)
					#slash.process_material.gravity = Vector3(-98.0, 0.0, 0.0)
					#slash.process_material.angle_min = 90
					#slash.process_material.angle_max = 90
					
				elif direction == "right":
					shape.size = Vector2(20.5 * reach_factor, 58.0)
					shape_node.position = Vector2(20 * reach_factor, 0)
				
				#slash.global_position = shape_node.global_position
				#get_parent().add_child(slash, true)

func _disable_all_sword_hitboxes() -> void:
	for child in $SwordHbox.get_children():
		if child is CollisionShape2D:
			child.disabled = true

func show_ui() -> void:
	$UI/Main/Markers.visible = true
	$UI/Main/HealthBar.visible = true
	$UI/Main/SprintBar.visible = true
	$UI/Main/Inventory.visible = true
	$UI/Main/HBoxContainer.visible = true

func hide_ui() -> void:
	$UI/Main/Markers.visible = false
	$UI/Main/HealthBar.visible = false
	$UI/Main/SprintBar.visible = false
	$UI/Main/Inventory.visible = false
	$UI/Main/HBoxContainer.visible = false
	$UI/Main/Tab.visible = false
	$UI/Main/Shop.visible = false

const FADE_SPEED := 5.0

func _is_mouse_over_chat_bar() -> bool:
	if not $UI/Main/ChatBar.visible:
		return false
	var local_mouse_pos = $UI/Main/ChatBar.get_local_mouse_position()
	return $UI/Main/ChatBar.get_rect().has_point(local_mouse_pos)

func update_particle_color() -> void:
	if active_effects.size() == 0:
		$Potion.emitting = false
		return

	$Potion.emitting = true

	var r_sum := 0.0
	var g_sum := 0.0
	var b_sum := 0.0

	for effect in active_effects:
		var c = effect.color
		r_sum += c.r
		g_sum += c.g
		b_sum += c.b

	var count = active_effects.size()
	var blended_color = Color(r_sum / count, g_sum / count, b_sum / count)

	# Set the particle color
	$Potion.process_material.color = blended_color

func _physics_process(delta: float) -> void:
	#position = clamp_player_position(position)
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	update_particle_color()
	if alive:
		for effect in active_effects.duplicate():
			if effect.update(delta, self):
				active_effects.erase(effect)
	var focused = $UI/Main/ChatBar.has_focus()
	var hovered := _is_mouse_over_chat_bar()
	if focused or hovered:
		$UI/Main/ChatBar.modulate.a = lerp($UI/Main/ChatBar.modulate.a, 1.0, FADE_SPEED * delta)
	else:
		$UI/Main/ChatBar.modulate.a = lerp($UI/Main/ChatBar.modulate.a, 0.0, FADE_SPEED * delta)
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		$UI/Main/HealthBar.max_value = max_health
		$UI/Main/HealthBar.value = health
		$UI/Main/SprintBar.value = sprint
		if sprint >= 220:
			exhausted = false
			$UI/Main/SprintBar.visible = false
		else:
			$UI/Main/SprintBar.visible = true
		$UI/Main/HealthBar/Label.text = str(roundi(health)) + "/" + str(roundi(max_health))
	hit_cooldown = max(hit_cooldown - delta, 0.0)
	if $"UI/Main/Death".visible:
		$"UI/Main/Death/Panel/Respawn Timer".text = "You will respawn in " + str(roundi(revival_time)) + " seconds..."
	if not alive:
		revival_time -= delta
		if revival_time <= 0.0:
			revival_time = 0.0
			damage_dealt = 0.0
			damage_healed = 0.0
			damage_taken = 0.0
			gold_collected = 0.0
			kills = 0
			$"UI/Main/Death".visible = false
			health = max_health
			gold = max(roundi(gold / 2), 0)
			Toast.add.rpc_id(int(name), "You respawned! You lost half your gold.")
			play_idle_animation()
			$AnimatedSprite2D.material = null
			global_position = Vector2.ZERO
			alive = true
			show_ui()
	_process_input(delta)
	if sprint <= 0:
		exhausted = true
	if exhausted:
		velocity *= 0.55
	if (velocity.length() == 0 and sprint < 220) or (exhausted and sprint < 220):
		if not exhausted:
			sprint += 1
		else:
			sprint += 0.5
	if velocity.length() == SPEED and sprint < 220:
		sprint += 0.45
	var slots = $UI/Main/Inventory.get_children()

	for i in slots.size():
		var slot = slots[i]
		var icon = slot.get_node("TextureRect")
		var amount_label = slot.get_node("Label")
		var progress_bar = slot.get_node("ProgressBar")

		if i < bag.list.size():
			var stack = bag.list[i]
			slot.set_item(stack.type)
			icon.visible = true
			amount_label.visible = stack.amount > 1
			progress_bar.visible = stack.type.cooldown
		else:
			icon.visible = false
			amount_label.visible = false
			progress_bar.visible = false

	if sword_hitbox_active:
		for body in $SwordHbox.get_overlapping_bodies():
			if body.is_in_group("enemies") and body not in hit_enemies:
				_process_hit(body)
				hit_enemies.append(body)
		
		sword_hitbox_timer -= delta
		if sword_hitbox_timer <= 0.0:
			sword_hitbox_active = false
			hit_enemies.clear()
			_disable_all_sword_hitboxes()
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.entity.id == 1 or enemy.entity.id == 4:
			count += 1
	if count > 0:
		bombrat_counter.text = "%d" % count

	if $UI/Main.visible and (not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()):
		$UI/Main/HBoxContainer/Wave/Label.text = "Wave: " + str(get_parent().wave)
		$UI/Main/HBoxContainer/Gold/HBoxContainer/Label.text = str(gold)

	for bombrat in get_bombrats_to_track():
		if not is_instance_valid(bombrat):
			continue
		
		if bombrat.get_node("VisibleOnScreenNotifier2D").is_on_screen():
			_remove_marker(bombrat)
			continue
			
		var dir = (bombrat.global_position - global_position).normalized()
		var direction_node = _get_direction_node_from_vector(dir)

		if direction_node == null:
			_remove_marker(bombrat)
			continue

		var marker = active_markers.get(bombrat)
		if marker == null:
			marker = marker_scene.instantiate()
			direction_node.add_child(marker)
			active_markers[bombrat] = marker

		marker.position = _calculate_offset_in_direction_node(dir, direction_node)

		# Snap to cardinal direction
		match direction_node.name:
			"Up":
				marker.rotation = 0
			"Right":
				marker.rotation = PI / 2
			"Down":
				marker.rotation = PI
			"Left":
				marker.rotation = -PI / 2

	for bombrat in get_big_bombrats_to_track():
		if not is_instance_valid(bombrat):
			continue
		
		if bombrat.get_node("VisibleOnScreenNotifier2D").is_on_screen():
			_remove_marker(bombrat)
			continue
			
		var dir = (bombrat.global_position - global_position).normalized()
		var direction_node = _get_direction_node_from_vector(dir)

		if direction_node == null:
			_remove_marker(bombrat)
			continue

		var marker = active_markers.get(bombrat)
		if marker == null:
			marker = marker_scene.instantiate()
			direction_node.add_child(marker)
			active_markers[bombrat] = marker

		marker.position = _calculate_offset_in_direction_node(dir, direction_node)
		marker.scale = Vector2(1.5, 1.5)

		# Snap to cardinal direction
		match direction_node.name:
			"Up":
				marker.rotation = 0
			"Right":
				marker.rotation = PI / 2
			"Down":
				marker.rotation = PI
			"Left":
				marker.rotation = -PI / 2
	
	for tracked in active_markers.keys():
		if not is_instance_valid(tracked) or not get_bombrats_to_track().has(tracked):
			_remove_marker(tracked)


func _remove_marker(bombrat):
	if active_markers.has(bombrat):
		active_markers[bombrat].queue_free()
		active_markers.erase(bombrat)

func _get_direction_node_from_vector(vec: Vector2) -> Control:
	var abs_x = abs(vec.x)
	var abs_y = abs(vec.y)

	if abs_x > abs_y:
		return marker_container.get_node("Right") if vec.x > 0 else marker_container.get_node("Left")
	else:
		return marker_container.get_node("Down") if vec.y > 0 else marker_container.get_node("Up")

func _calculate_offset_in_direction_node(dir: Vector2, node: Control) -> Vector2:
	var size = node.get_size()
	
	if node.name == "Up" or node.name == "Down":
		var x = clamp(dir.x * size.x * 0.25 + size.x / 2, 8, size.x - 8)
		var y = size.y / 2
		return Vector2(x, y)
	elif node.name == "Left" or node.name == "Right":
		var x = size.x / 2
		var y = clamp(dir.y * size.y * 0.25 + size.y / 2, 8, size.y - 8)
		return Vector2(x, y)
	else:
		return size / 2  # fallback
		
func _animation_finished() -> void:
	if $AnimatedSprite2D.animation.begins_with("sword_"):
		play_idle_animation()

@rpc("any_peer", "call_local")
func add_hit_particles(position: Vector2, angle: float):
	var hitting_particles = hitting_particles_instance
	var particles = hitting_particles.instantiate()
	get_parent().add_child(particles, true)
	particles.global_position = position
	particles.rotation = angle
	particles.emitting = true

func _process_hit(body):
	if body.is_in_group("enemies"):
		# Apply separate Strength buff multiplier if active
		var strength_multiplier = 2.5 if has_effect("Strength") else 1.0

		# Damage before defense, using normal strength stat scaling
		var damage_before_defense = (damage * (1.0 + strength / 100.0)) * strength_multiplier

		# Defense reduction formula
		var defense = body.entity.defense
		var defense_factor = 1.0 - (defense / (defense + 100.0))

		# Final damage after defense
		var total_damage = damage_before_defense * defense_factor

		# Positioning and visuals
		var direction = body.global_position - global_position
		var midpoint = global_position + direction * 0.5
		var angle = direction.angle()

		damage_dealt += total_damage
		total_damage_dealt += total_damage

		# Multiplayer-safe damage + particles
		if multiplayer.has_multiplayer_peer():
			body.take_damage.rpc(total_damage, global_position, name)
			add_hit_particles.rpc(midpoint, angle)
		else:
			body.take_damage(total_damage, global_position, name)
			add_hit_particles(midpoint, angle)

func _on_shop_close_button_pressed() -> void:
	$UI/Main/Shop.visible = false

func add_message(message: String, player_name: String) -> void:
	if multiplayer.has_multiplayer_peer():
		print("[" + str(multiplayer.get_unique_id()) + "] Received message: ", message)
	var chat_message = load("res://scenes/chat_message.tscn").instantiate()
	chat_message.text = player_name + ": " + message
	chat_message.visible = true
	chat_message.modulate = Color(1, 1, 1, 1)
	$UI/Main/Chat/VBoxContainer.add_child(chat_message, true)
	_write_chat_log(player_name, message)
	await get_tree().process_frame
	$UI/Main/Chat.scroll_vertical = $UI/Main/Chat.get_v_scroll_bar().max_value

func _write_chat_log(player_name: String, message: String) -> void:
	var log_line = "[%s] %s: %s" % [
		Time.get_datetime_string_from_system(),
		player_name,
		message
	]
	var file = FileAccess.open(current_log_path, FileAccess.READ_WRITE)
	if file:
		file.seek_end()
		file.store_line(log_line)
		file.close()
		
func _on_chat_bar_submitted(new_text: String) -> void:
	$UI/Main/ChatBar.text = ""
	$UI/Main/ChatBar.release_focus()
	if new_text == "":
		return

	var player_name = NetworkManager.player_name if NetworkManager.player_name != "" else "Player"
	if multiplayer.has_multiplayer_peer():
		NetworkManager.send_message.rpc(new_text, player_name)
	else:
		add_message(new_text, player_name)

func _on_chat_bar_focus_entered() -> void:
	for child in $UI/Main/Chat/VBoxContainer.get_children():
		child.visible = true
		child.modulate = Color(1, 1, 1, 1)
		for node in child.get_children():
			if node is Timer:
				node.stop()
	await get_tree().process_frame
	$UI/Main/Chat.scroll_vertical = $UI/Main/Chat.get_v_scroll_bar().max_value

func _on_chat_bar_focus_exited() -> void:
	for child in $UI/Main/Chat/VBoxContainer.get_children():
		if child.should_fade:
			child.visible = true
			child.modulate = Color(1, 1, 1, 1)
			for node in child.get_children():
				if node is Timer:
					node.start()
		else:
			child.visible = false

func _on_play_again_pressed() -> void:
	if multiplayer.is_server():
		get_parent().reset.rpc()
	elif not multiplayer.has_multiplayer_peer():
		get_parent().reset()

func _on_main_menu_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		Man.end_game.rpc()
	else:
		Man.end_game()

func _on_chatbar_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		$UI/Main/ChatBar.text = ""
		$UI/Main/ChatBar.release_focus()
		get_viewport().set_input_as_handled()
