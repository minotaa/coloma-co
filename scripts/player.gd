extends CharacterBody2D

var shop_items = []  # Current shop inventory
var current_shop_seed = 0  # Seed from server for deterministic random selection
var rerolls_available = 3  # Number of rerolls player can use
var reroll_cost = 50  # Gold cost per reroll
var type: String = ""
var guaranteed_crit = false
var current_log_path: String
var original_zoom := Vector2(4.0, 4.0)
var leveling_bar_rest_position: Vector2
var zoom_multiplier := 1.0
var directions := {
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT,
	"up": Vector2.UP,
	"down": Vector2.DOWN
}
var has_boomerang: bool = true
var clip: int = 0
var reload_time: float = 0.0
var last_direction := "down"
const SWORD_HITBOX_TIME := 0.15
var sword_hitbox_timer := 0.0
var sword_hitbox_active := false
var hit_enemies := []
var knockback_velocity := Vector2.ZERO
var knockback_friction := 800.0
var hit_cooldown := 0.0
var max_hit_cooldown := 0.35

const FADE_SPEED := 5.0
const SPEED := 120.0
const SPRINT_MULTIPLIER := 1.45
var exhausted := false # When you deplete your sprint completely you will become exhausted
var sprint := 220.0
var step_timer := 0.0
var step_interval := 0.4
var alive: bool = true
var lives: int = 4
var added_gold: int = 0
var added_gold_display: int = 0
var added_gold_timeout: float = 0.0
var damage := 25.0
var strength := 0
var sword_reach := 1.55  # Base reach
var gold: int = 10 * Man.current_level

var revival_time: float = 0.0
const MAX_REVIVAL_TIME: float = 10.0 # like in seconds and stuff
var bag = Bag.new()
var upgrade_bag = Bag.new()
var health := get_max_health()
var overheal := 0.0
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

@rpc("authority", "call_local", "reliable")
func add_gold_notification(amount: int) -> void:
	if has_effect("Prosperity"):
		amount *= 2
	
	# Check for Gold from Combat upgrade
	if upgrade_bag.has_item(Catalog.get_by_id(37)):
		var gold_level = upgrade_bag.get_item_stack(Catalog.get_by_id(37)).data["level"]
		# Each level increases gold from combat by 10%
		var gold_bonus = 1.0 + (gold_level * 0.10)
		amount = int(amount * gold_bonus)
	
	var bonus = 1.0 + (0.02 * Man.current_level)
	amount = int(amount * bonus)
	
	if type == "Defense":
		added_gold += amount
		added_gold_timeout = 2.0
		if added_gold > 0:
			$UI/Defense/HBoxContainer/Gold/HBoxContainer/Label.text = str(gold) + " (+" + str(added_gold) + ")"
		else:
			$UI/Defense/HBoxContainer/Gold/HBoxContainer/Label.text = str(gold)
	elif type == "Dungeon":
		added_gold += amount
		added_gold_timeout = 2.0
		if added_gold > 0:
			$UI/Dungeon/HBoxContainer/Gold/HBoxContainer/Label.text = str(gold) + " (+" + str(added_gold) + ")"
		else:
			$UI/Dungeon/HBoxContainer/Gold/HBoxContainer/Label.text = str(gold)
		
func get_slots() -> int:
	var slots = 3
	if upgrade_bag.has_item(Catalog.get_by_id(41)):
		slots += 1
	return slots 

func get_crit_chance() -> float:
	var crit_chance = 15.0
	if has_effect("Focus"):
		crit_chance += 50.0
	if upgrade_bag.has_item(Catalog.get_by_id(25)):
		crit_chance += 5 * upgrade_bag.get_item_stack(Catalog.get_by_id(25)).data["level"]
	return crit_chance
			
func get_bonus_damage() -> float:
	var bonus_damage := 0.0
	if upgrade_bag.has_item(Catalog.get_by_id(8)):
		bonus_damage += 10 * upgrade_bag.get_item_stack(Catalog.get_by_id(8)).data["level"]
	return bonus_damage

func get_defense() -> float:
	var defense := 0.0
	if upgrade_bag.has_item(Catalog.get_by_id(9)):
		defense += 5 * upgrade_bag.get_item_stack(Catalog.get_by_id(9)).data["level"]
	defense += Man.equipped_armor.defense
	if upgrade_bag.has_item(Catalog.get_by_id(40)):
		if health >= get_max_health():
			defense -= 15
	return defense

func get_max_overheal() -> float:
	var max_overheal := 100.0
	if upgrade_bag.has_item(Catalog.get_by_id(29)):
		max_overheal += 25 * upgrade_bag.get_item_stack(Catalog.get_by_id(29)).data["level"]
	return max_overheal

func get_max_health() -> float:
	var max_health := 100.0
	if upgrade_bag.has_item(Catalog.get_by_id(10)):
		max_health += 10 * upgrade_bag.get_item_stack(Catalog.get_by_id(10)).data["level"]
	max_health += Man.equipped_armor.health
	return max_health

func add_status_effect(effect: Effect) -> void:
	# Check for Potion Amplifier upgrade (ID 36)
	if upgrade_bag.has_item(Catalog.get_by_id(36)):
		var amplifier_level = upgrade_bag.get_item_stack(Catalog.get_by_id(36)).data["level"]
		# Level 1: 15% longer, Level 2: 30% longer
		var duration_multiplier = 1.0 + (amplifier_level * 0.15)
		effect.duration *= duration_multiplier
	
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

@onready var boomerang_scene = preload("res://scenes/boomerang.tscn")
@onready var throwable_scene = preload("res://scenes/throwable.tscn")
@onready var hitting_particles_instance = preload("res://scenes/hitting_particles.tscn")
@onready var bombrat_counter := $UI/Defense/HBoxContainer/Bombrats/HBoxContainer/Label
@onready var camera := get_viewport().get_camera_2d()
@onready var marker_container := $UI/Defense/Markers
@onready var marker_scene := preload("res://scenes/marker.tscn")
@onready var hit_sound := preload("res://assets/sounds/better3.wav")
@onready var heal_sound := preload("res://assets/sounds/maybeheal.wav")

var active_markers := {}

func get_bombrats_to_track():
	var bombrats = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.id == 1 or enemy.id == 4:
			bombrats.append(enemy)
	return bombrats
	
func get_big_bombrats_to_track():
	var bombrats = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.id == 4:
			bombrats.append(enemy)
	return bombrats

func reset_game() -> void:
	kills = 0
	total_kills = 0
	damage_dealt = 0.0
	damage_healed = 0.0
	damage_taken = 0.0
	gold_collected = 0
	health = get_max_health()
	revival_time = 0.0
	gold = 5 * Man.current_level
	sprint = 220
	lives = 4
	alive = true
	bag = Bag.new()
	upgrade_bag = Bag.new()
	global_position = Vector2(0, 0)
	play_idle_animation()
	$"UI/Defense/Game Over".visible = false
	$UI/Defense/Death.visible = false
	$"UI/Dungeon/Game Over".visible = false
	$UI/Dungeon/Death.visible = false
	show_ui()

func end_game() -> void:
	$AnimatedSprite2D.play("death")
	$AnimatedSprite2D.material = preload("res://scenes/shock.tres")
	alive = false
	revival_time = -1
	hide_ui()
	Man.enemies_killed += total_kills
	var stats_text := "Your final stats:\n"
	stats_text += "\nGold:\t " + str(gold_collected) + " (" + percent(gold_collected, total_gold_collected) + ")\n"
	stats_text += "Kills:\t " + str(kills) + " (" + percent(kills, total_kills) + ")\n"
	stats_text += "Damage Dealt:\t " + str(roundi(damage_dealt)) + " (" + percent(damage_dealt, total_damage_dealt) + ")\n"
	stats_text += "Damage Taken:\t " + str(roundi(damage_taken)) + " (" + percent(damage_taken, total_damage_taken) + ")\n"
	stats_text += "Damage Healed:\t " + str(roundi(damage_healed)) + " (" + percent(damage_healed, total_damage_healed) + ")"
	if type == "Defense":
		$"UI/Dungeon/Game Over/Panel/Subtitle".text = "The gem has broken."
		stats_text += "\nFinal wave:\t " + str(get_parent().wave)
		if get_parent().wave > Man.highest_wave:
			Man.highest_wave = get_parent().wave
		$"UI/Defense/Game Over".visible = true
		$"UI/Defense/Game Over/Panel/Meta".text = stats_text
		if (not multiplayer.has_multiplayer_peer()) or 1 == multiplayer.get_unique_id():
			$"UI/Defense/Game Over/Panel/Play Again".visible = true
			$"UI/Defense/Game Over/Panel/Main Menu".visible = true
		else:
			$"UI/Defense/Game Over/Panel/Play Again".visible = false
			$"UI/Defense/Game Over/Panel/Main Menu".visible = false
	elif type == "Dungeon":
		if multiplayer.has_multiplayer_peer():
			get_parent().are_we_sure_everyone_is_dead.rpc()
		else:
			get_parent().are_we_sure_everyone_is_dead()
		if get_parent().completed_rooms:
			Man.highest_rooms = get_parent().completed_rooms
		$"UI/Dungeon/Game Over/Panel/Subtitle".text = "You lost all your lives."
		stats_text += "\nRooms completed: " + str(roundi(get_parent().completed_rooms))
		$"UI/Dungeon/Game Over".visible = true
		$"UI/Dungeon/Game Over/Panel/Meta".text = stats_text
		if (not multiplayer.has_multiplayer_peer()) or 1 == multiplayer.get_unique_id():
			$"UI/Dungeon/Game Over/Panel/Play Again".visible = true
			$"UI/Dungeon/Game Over/Panel/Main Menu".visible = true
		else:
			$"UI/Dungeon/Game Over/Panel/Play Again".visible = false
			$"UI/Dungeon/Game Over/Panel/Main Menu".visible = false

func send_title(title: String, delay: float) -> void:
	print("Showing title \"" + title + "\" to player.")
	$UI/Defense/Title.text = title
	await get_tree().create_timer(delay).timeout
	$UI/Defense/Title.text = ""
	
func play_ui_sfx(stream: AudioStream) -> void:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.bus = "SFX" # Optional: route through your SFX bus
	sfx.volume_db = -10.0
	add_child(sfx)

	sfx.play()

	sfx.finished.connect(func():
		sfx.queue_free()
	)
	
func _connect_button_sfx(button: Button):
	button.mouse_entered.connect(func():
		play_ui_sfx(preload("res://assets/sounds/click.wav"))
	)
	button.pressed.connect(func():
		play_ui_sfx(preload("res://assets/sounds/click1.wav"))
	)
	
func _enter_tree() -> void:
	if multiplayer.has_multiplayer_peer():
		set_multiplayer_authority(name.to_int())

func _ready() -> void:	
	leveling_bar_rest_position = $UI/Global/Leveling.position
	$UI/Global/Leveling.position.y = leveling_bar_rest_position.y - 200
	for button in find_children("", "Button", true):
		if button is Button:
			_connect_button_sfx(button)
	if multiplayer.has_multiplayer_peer():
		set_multiplayer_authority(name.to_int())
		for player in NetworkManager.players:
			if player["id"] == name.to_int():
				$Username.text = player["username"]
		$Username.visible = true
	
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		$UI.visible = false
		$Clip.visible = false
		$PointLight2D.visible = false
		$AudioListener2D.clear_current()
	if multiplayer.has_multiplayer_peer() and is_multiplayer_authority():
		$Camera2D.make_current()
		get_parent().send_equipment.rpc(name, Man.equipped_weapon.id, Man.equipped_armor.id)
	if not multiplayer.has_multiplayer_peer():
		get_parent().send_equipment(str(name), Man.equipped_weapon.id, Man.equipped_armor.id)
	
	if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
		if not DirAccess.dir_exists_absolute("user://chats"):
			DirAccess.make_dir_absolute("user://chats")
			
		var timestamp = Time.get_datetime_string_from_system().replace(":", "-")
		current_log_path = "user://chats/%s.log" % timestamp
		
		var file = FileAccess.open(current_log_path, FileAccess.WRITE)
		if file:
			file.store_line("--- Chat session started at %s ---" % timestamp)
		file.close()
		if Man.equipped_weapon.type == "THROWABLE":
			play_ui_sfx(preload("res://assets/sounds/click1.wav"))
			Toast.add("Reloaded your throwable.")
			clip = Man.equipped_weapon.data["clip"]
			$Clip.visible = true 
		if Man.equipped_weapon.type == "BLUNDERBUSS":
			play_ui_sfx(preload("res://assets/sounds/click1.wav"))
			Toast.add("Reloaded your Blunderbuss.")
			clip = Man.equipped_weapon.data["clip"]
			$Clip.visible = true 
		
@rpc("any_peer", "call_local", "reliable")
func refresh_shop(new_seed: int):
	current_shop_seed = new_seed
	rerolls_available = 3  # Reset rerolls on server refresh
	generate_shop_inventory()
	
	# If shop is currently open, update it
	var shop_node = $UI/Defense/Shop if type == "Defense" else $UI/Dungeon/Shop
	if shop_node.visible:
		populate_shop_ui()
		update_shop_ui()

func show_level_up_animation(new_level: int, overflow_xp: float = 0.0, max_xp: float = 100.0):
	var leveling_bar = $UI/Global/Leveling
	
	var level_label = leveling_bar.get_node("Level")
	var xp_bar = leveling_bar.get_node("XP")
	level_label.text = "LEVEL " + str(new_level - 1)
	xp_bar.value = xp_bar.max_value
	var tween = create_tween()
	tween.set_parallel(false)
	tween.tween_property(leveling_bar, "position:y", leveling_bar_rest_position.y, 0.5)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.3)
	tween.tween_callback(func():
		level_label.text = "LEVEL " + str(new_level)
		xp_bar.value = 0
	)

	tween.tween_interval(0.2)
	if overflow_xp > 0:
		var overflow_percent = (overflow_xp / max_xp) * xp_bar.max_value
		tween.tween_property(xp_bar, "value", overflow_percent, 0.4)
	tween.tween_interval(1.0)
	tween.tween_property(leveling_bar, "position:y", leveling_bar_rest_position.y - 200, 0.4)\
		.set_ease(Tween.EASE_IN)\
		.set_trans(Tween.TRANS_BACK)

@rpc("any_peer", "call_local", "reliable")
func setup_ui(type: String) -> void:
	#if is_multiplayer_authority():
	self.type = type
	print("Setting up UI - type: '%s'" % type)
	for children in $UI.get_children():
		children.visible = false
	if type != "":
		print("Showing UI for type: %s" % type)
		$UI.get_node(str(type)).visible = true
	else:
		print("Type is empty, no specific UI shown")
	$UI/Global.visible = true
		
func heal(amount: float) -> void:	
	if alive:
		var old_health = health
		health = min(health + amount, get_max_health())
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
		if multiplayer.has_multiplayer_peer():
			play_sfx.rpc("maybeheal", global_position)
		else:
			play_sfx("maybeheal", global_position)
	
func _on_regen_timeout() -> void:
	if upgrade_bag.has_item(Catalog.get_by_id(41)) and alive:
		var regen_level = upgrade_bag.get_item_stack(Catalog.get_by_id(41)).data["level"]
		# Each level increases heal: 3%, 4%, 5%
		var heal_percent = 0.03 + (regen_level - 1) * 0.01
		var heal_amount = get_max_health() * heal_percent
		heal(heal_amount)
		
		var next_interval = 10.0 - ((regen_level - 1) * 2.0)
		$Timer.wait_time = next_interval
	
func take_damage(amount: float, location: Vector2 = Vector2.ZERO) -> void:
	if hit_cooldown > 0.0 or not alive:
		return
		
	if has_effect("Invulnerability"):
		hit_cooldown = max_hit_cooldown
		return
		
	var dodge_chance = 0.0
	if Man.equipped_armor.id == 11:
		dodge_chance += 0.2
	if upgrade_bag.has_item(Catalog.get_by_id(31)):
		dodge_chance += (0.5 * upgrade_bag.get_item_stack(Catalog.get_by_id(31)).data["level"])
	if dodge_chance > 0.0:
		if randf() < dodge_chance:
			play_ui_sfx(preload("res://assets/sounds/mama.wav"))
			Toast.add("Your Pajamas negated the damage!")
			hit_cooldown = max_hit_cooldown
			return
			
	screen_shake(3.0, 0.3)
	var defense = get_defense()
	var defense_factor = 1.0 - (defense / (defense + 100.0))
	var final_damage = amount * defense_factor

	print("Player took ", final_damage, " damage (raw: ", amount, ", defense: ", defense, ")")

	hit_cooldown = max_hit_cooldown
	
	if upgrade_bag.has_item(Catalog.get_by_id(41)):
		$Timer.stop()
		await get_tree().create_timer(5.0).timeout
		var regen_level = upgrade_bag.get_item_stack(Catalog.get_by_id(41)).data["level"]
		var next_interval = 10.0 - ((regen_level - 1) * 2.0)
		$Timer.start(next_interval)
	
	# Handle overheal absorption
	if overheal > 0:
		var halved_damage = final_damage * 0.5
		if overheal >= halved_damage:
			# Overheal absorbs all damage
			overheal -= halved_damage
			final_damage = 0
		else:
			# Overheal absorbs what it can, rest goes to health
			final_damage -= overheal
			overheal = 0
	
	health -= final_damage
	damage_taken += final_damage
	total_damage_taken += final_damage

	if multiplayer.has_multiplayer_peer():
		play_sfx.rpc("hit", global_position, 10.0)
	else:
		play_sfx("hit", global_position, 10.0)

	apply_knockback(location, 220.0)

	if multiplayer.has_multiplayer_peer():
		show_floating_text.rpc(final_damage, global_position)
	else:
		show_floating_text(final_damage, global_position)

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
	alive = false
	hide_ui()
	if type == "Dungeon" and lives <= 0:
		Toast.add("You lost all your lives, you're out of the game!")
		end_game()
		return
	if multiplayer.has_multiplayer_peer():
		Toast.add.rpc_id(int(name), "You're dead... you will respawn in 10 seconds.")
	else:
		Toast.add("You're dead... you will respawn in 10 seconds.")
	revival_time = MAX_REVIVAL_TIME
	var stats_text := "This life:\n"
	stats_text += "Gold:\t " + str(gold_collected) + " (" + percent(gold_collected, total_gold_collected) + ")\n"
	stats_text += "Kills:\t " + str(kills) + " (" + percent(kills, total_kills) + ")\n"
	stats_text += "Damage Dealt:\t " + str(roundi(damage_dealt)) + " (" + percent(damage_dealt, total_damage_dealt) + ")\n"
	stats_text += "Damage Taken:\t " + str(roundi(damage_taken)) + " (" + percent(damage_taken, total_damage_taken) + ")\n"
	stats_text += "Damage Healed:\t " + str(roundi(damage_healed)) + " (" + percent(damage_healed, total_damage_healed) + ")"
	if type == "Defense":
		$"UI/Defense/Death".visible = true	
		$"UI/Defense/Death/Panel/Meta".text = stats_text
	if type == "Dungeon":
		$UI/Dungeon/Death.visible = true
		stats_text += "\nRooms:\t " + str(roundi(get_parent().completed_rooms))
		$"UI/Dungeon/Death/Panel/Meta".text = stats_text
	
	reset_status_effects()
	
	#health = max_health
	#gold = max(roundi(gold / 2), 0)
	#Toast.add("You respawned! You lost half your gold.")
	#play_idle_animation()
	#$AnimatedSprite2D.material = null
	#global_position = Vector2.ZERO
	#alive = true

@rpc("any_peer", "call_local")
func play_sfx(stream_name: String, position: Vector2, volume: float = 0.0, pitch_scale: float = 1.0) -> void:
	var sfx = AudioStreamPlayer2D.new()
	var path = "res://assets/sounds/" + stream_name + ".wav"
	sfx.stream = load(path)
	sfx.volume_db = volume
	sfx.pitch_scale = pitch_scale
	sfx.bus = "SFX"
	sfx.global_position = position
	add_child(sfx)

	sfx.play()
	sfx.finished.connect(func():
		sfx.queue_free()
	)

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

@rpc("any_peer", "call_local")
func show_floating_text(amount: int, center_position: Vector2):
	var floating_text_scene = preload("res://scenes/floating_text.tscn")
	var floating_text = floating_text_scene.instantiate()
	floating_text.text = str(amount)
	(floating_text as Label).label_settings = LabelSettings.new()
	(floating_text as Label).label_settings.font = preload("res://assets/fonts/slkscr.ttf")
	(floating_text as Label).label_settings.font_size = 17
	(floating_text as Label).label_settings.font_color = Color.RED
	(floating_text as Label).label_settings.shadow_color = Color(0, 0, 0, 0.80)
	$"..".add_child(floating_text, true)

	var random_offset = Vector2(
		randi_range(-8, 8),
		randi_range(-8, 8)
	)
	floating_text.position = center_position + random_offset

var shop_rng = RandomNumberGenerator.new()

func generate_shop_inventory():
	shop_items.clear()
	
	shop_rng.seed = current_shop_seed
	print("Generating shop with seed: ", current_shop_seed)
	
	var current_shop_type = "DEFENSE" if type == "Defense" else "DUNGEON"
	
	var available_items = []
	for item in Catalog.items:
		if (item as ItemType).purchasable and \
		   ((item as ItemType).shop_type == current_shop_type or \
			(item as ItemType).shop_type == "ANY"):
			available_items.append(item)
	
	print("Available items: ", available_items.size())
	
	var available_upgrades = []
	for upgrade in Catalog.upgrades:
		if (upgrade as ItemType).purchasable:
			available_upgrades.append(upgrade)
	
	print("Available upgrades: ", available_upgrades.size())
	
	# Shuffle and select items...
	for i in range(available_items.size() - 1, 0, -1):
		var j = shop_rng.randi_range(0, i)
		var temp = available_items[i]
		available_items[i] = available_items[j]
		available_items[j] = temp
	
	for i in range(min(3, available_items.size())):
		shop_items.append(available_items[i])
	
	print("Selected items: ", shop_items.size())
	
	# Shuffle and select upgrades...
	for i in range(available_upgrades.size() - 1, 0, -1):
		var j = shop_rng.randi_range(0, i)
		var temp = available_upgrades[i]
		available_upgrades[i] = available_upgrades[j]
		available_upgrades[j] = temp
	
	if available_upgrades.size() > 0:
		shop_items.append(available_upgrades[0])
	
	print("Total shop items: ", shop_items.size())

func populate_shop_ui():
	var shop_node = $UI/Defense/Shop if type == "Defense" else $UI/Dungeon/Shop
	var grid = shop_node.get_node("Panel/ScrollContainer/GridContainer")
	
	# Clear existing items
	for child in grid.get_children():
		child.queue_free()
	
	# Add current shop items
	for item in shop_items:
		var catalog_item = load("res://scenes/catalog_item.tscn").instantiate()
		catalog_item.set_item(item)
		grid.add_child(catalog_item, true)
	
	# Wait for items to be added to scene tree
	await get_tree().process_frame
	
	# Configure focus neighbors for the shop grid
	_configure_shop_focus_neighbors(grid, shop_node)

func _configure_shop_focus_neighbors(hbox: HBoxContainer, shop_node: Node) -> void:
	"""Configure focus neighbors for shop items in horizontal layout"""
	var buttons := []
	
	# Collect all focusable buttons from catalog items
	for child in hbox.get_children():
		# Find the button within each catalog_item Control
		if child.get_child_count() > 0:
			for sub_child in child.get_children():
				if sub_child is Button:
					# Enable focus mode
					sub_child.focus_mode = Control.FOCUS_ALL
					# Apply focus style based on current input method
					if using_controller:
						sub_child.add_theme_stylebox_override("focus", preload("res://scenes/outline but for ui lol.tres"))
					else:
						sub_child.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
					buttons.append(sub_child)
					break
	
	if buttons.is_empty():
		return
	
	# Configure horizontal navigation (left/right only)
	for i in range(buttons.size()):
		var b = buttons[i]
		
		# Left navigation
		if i > 0:
			b.focus_neighbor_left = b.get_path_to(buttons[i - 1])
		
		# Right navigation
		if i < buttons.size() - 1:
			b.focus_neighbor_right = b.get_path_to(buttons[i + 1])
	
	# Find Reroll and Close buttons
	var reroll_button = shop_node.find_child("Reroll", true, false)
	var close_button = shop_node.find_child("Close", true, false)
	if not close_button:
		close_button = shop_node.find_child("Back", true, false)
	
	# Enable focus on control buttons and apply style
	if reroll_button and reroll_button is Button:
		reroll_button.focus_mode = Control.FOCUS_ALL
		if using_controller:
			reroll_button.add_theme_stylebox_override("focus", preload("res://scenes/outline but for ui lol.tres"))
		else:
			reroll_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			
	if close_button and close_button is Button:
		close_button.focus_mode = Control.FOCUS_ALL
		if using_controller:
			close_button.add_theme_stylebox_override("focus", preload("res://scenes/outline but for ui lol.tres"))
		else:
			close_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	# Connect all items to Reroll button (up)
	if reroll_button and reroll_button is Button:
		for button in buttons:
			button.focus_neighbor_top = button.get_path_to(reroll_button)
		
		# Reroll button down goes to first item
		reroll_button.focus_neighbor_bottom = reroll_button.get_path_to(buttons[0])
		
		# Reroll button left/right navigate along the row
		reroll_button.focus_neighbor_left = reroll_button.get_path_to(buttons[buttons.size() - 1])
		reroll_button.focus_neighbor_right = reroll_button.get_path_to(buttons[0])
	
	# Connect all items to Close button (down)
	if close_button and close_button is Button:
		for button in buttons:
			button.focus_neighbor_bottom = button.get_path_to(close_button)
		
		# Close button up goes to first item
		close_button.focus_neighbor_top = close_button.get_path_to(buttons[0])
		
		# Close button left/right navigate along the row
		close_button.focus_neighbor_left = close_button.get_path_to(buttons[buttons.size() - 1])
		close_button.focus_neighbor_right = close_button.get_path_to(buttons[0])
	
	# Connect Reroll and Close buttons to each other
	if reroll_button and close_button:
		reroll_button.focus_neighbor_top = reroll_button.get_path_to(close_button)
		close_button.focus_neighbor_bottom = close_button.get_path_to(reroll_button)
	
	# Focus Reroll button by default
	if reroll_button:
		reroll_button.grab_focus()
	elif close_button:
		close_button.grab_focus()
	elif buttons.size() > 0:
		buttons[0].grab_focus()

func reroll_shop():
	if gold >= reroll_cost and rerolls_available > 0:
		gold -= reroll_cost
		rerolls_available -= 1
		
		# Generate new local seed for reroll
		var reroll_seed = current_shop_seed + rerolls_available
		current_shop_seed = reroll_seed
		
		generate_shop_inventory()
		populate_shop_ui()
		update_shop_ui()
		return true
	return false

func update_shop_ui():
	var shop_node = $UI/Defense/Shop if type == "Defense" else $UI/Dungeon/Shop
	shop_node.get_node("Panel/HBoxContainer/Gold").text = str(gold)
	
	# Update reroll button text/availability
	var reroll_btn = shop_node.get_node("Panel/Reroll")  # You'll need to add this
	if reroll_btn:
		reroll_btn.text = "Reroll (%d left - %d gold)" % [rerolls_available, reroll_cost]
		reroll_btn.disabled = gold < reroll_cost or rerolls_available <= 0

func _process_input(delta) -> void:
	# Handle movement input
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if $UI/Global/ChatBar.has_focus() and alive:
		play_idle_animation()
	if not alive or $UI/Global/ChatBar.has_focus() or $"UI/Defense/Game Over".visible or $"UI/Dungeon/Game Over".visible or $UI/Global/Pause.visible:
		return
	if Input.is_action_just_pressed("interact"):
		print("interacted")
		var shop_node = $UI/Defense/Shop if type == "Defense" else $UI/Dungeon/Shop
		
		if not shop_node.visible:
			# Check if player is near a gem
			for area in $Area2D.get_overlapping_areas():
				if (area as Area2D).is_in_group("gem"):
					shop_node.visible = true
					play_idle_animation()
					populate_shop_ui()
					update_shop_ui()
					break
		else:
			shop_node.visible = false
			
	if $UI/Defense/Shop.visible:
		return
	if $UI/Dungeon/Shop.visible:
		return
	velocity = Input.get_vector("left", "right", "up", "down", 0.1)
	var velocity_length = velocity.length_squared()
	var is_moving = velocity_length > 0

	var walking_sounds = ["walk1", "walk2", "walk3", "walk4"]
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
		if $AnimatedSprite2D.animation.begins_with("walk_"):
			play_idle_animation()

	# Determine attack direction
	if Man.equipped_weapon.type == "SWORD":
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
			if multiplayer.has_multiplayer_peer():
				play_sfx.rpc(["slash1", "slash2"].pick_random(), global_position, -20.0)
			else:
				play_sfx(["slash1", "slash2"].pick_random(), global_position, -20.0)
			play_animation("sword_" + attack_dir)
			_enable_sword_hitbox(attack_dir)
			sword_hitbox_timer = SWORD_HITBOX_TIME
			sword_hitbox_active = true
		
	elif Man.equipped_weapon.type == "BOOMERANG":
		if Input.is_action_just_pressed("attack") and has_boomerang:
			play_animation("throw_" + last_direction)
			var mouse_pos = get_global_mouse_position()
			var direction = (mouse_pos - global_position).normalized()
			
			if multiplayer.has_multiplayer_peer():
				create_boomerang.rpc(Man.equipped_weapon.id, global_position, direction, name)
			else:
				create_boomerang(Man.equipped_weapon.id, global_position, direction, name)
			has_boomerang = false
		
		# Handle directional keyboard controls
		elif has_boomerang and (Input.is_action_pressed("attack_up") or Input.is_action_pressed("attack_down") or Input.is_action_pressed("attack_left") or Input.is_action_pressed("attack_right")):
			play_animation("throw_" + last_direction)
			# Calculate direction based on pressed keys
			var direction = Vector2.ZERO
			if Input.is_action_pressed("attack_up"):
				direction.y -= 1
			if Input.is_action_pressed("attack_down"):
				direction.y += 1
			if Input.is_action_pressed("attack_left"):
				direction.x -= 1
			if Input.is_action_pressed("attack_right"):
				direction.x += 1
			
			direction = direction.normalized()
			
			if multiplayer.has_multiplayer_peer():
				create_boomerang.rpc(Man.equipped_weapon.id, global_position, direction, name)
			else:
				create_boomerang(Man.equipped_weapon.id, global_position, direction, name)
			has_boomerang = false
	elif Man.equipped_weapon.type == "THROWABLE":
		if clip > 0:
			if Input.is_action_just_pressed("attack"):
				play_animation("throw_" + last_direction)
				var mouse_pos = get_global_mouse_position()
				var direction = (mouse_pos - global_position).normalized()
				if multiplayer.has_multiplayer_peer():
					create_throwable.rpc(Man.equipped_weapon.id, global_position, direction, name)
				else:
					create_throwable(Man.equipped_weapon.id, global_position, direction, name)
				clip -= 1
				if clip <= 0:
					reload_time = Man.equipped_weapon.data["reload_time"]
				play_sfx(["fwip1", "fwip2", "fwip3", "fwip4"].pick_random(), global_position)
			if (Input.is_action_just_pressed("attack_up") or Input.is_action_just_pressed("attack_down") or Input.is_action_just_pressed("attack_left") or Input.is_action_just_pressed("attack_right")):
				play_animation("throw_" + last_direction)
				var direction = Vector2.ZERO
				if Input.is_action_just_pressed("attack_up"):
					direction.y -= 1
				if Input.is_action_just_pressed("attack_down"):
					direction.y += 1
				if Input.is_action_just_pressed("attack_left"):
					direction.x -= 1
				if Input.is_action_just_pressed("attack_right"):
					direction.x += 1
				
				direction = direction.normalized()
				
				if multiplayer.has_multiplayer_peer():
					create_throwable.rpc(Man.equipped_weapon.id, global_position, direction, name)
				else:
					create_throwable(Man.equipped_weapon.id, global_position, direction, name)
			
				clip -= 1
				if clip <= 0:
					reload_time = Man.equipped_weapon.data["reload_time"]
				play_sfx(["fwip1", "fwip2", "fwip3", "fwip4"].pick_random(), global_position)
	elif Man.equipped_weapon.type == "BLUNDERBUSS":
		if clip > 0:
			if Input.is_action_just_pressed("attack"):
				play_animation("throw_" + last_direction)
				var mouse_pos = get_global_mouse_position()
				var direction = (mouse_pos - global_position).normalized()
				
				# Shoot 3 projectiles with spread
				var spread_angle = deg_to_rad(15)  # Adjust this for wider/tighter spread
				for i in range(-1, 2):  # -1, 0, 1
					var angle_offset = i * spread_angle
					var spread_direction = direction.rotated(angle_offset)
					
					if multiplayer.has_multiplayer_peer():
						create_throwable.rpc(Man.equipped_weapon.id, global_position, spread_direction, name)
					else:
						create_throwable(Man.equipped_weapon.id, global_position, spread_direction, name)
				
				clip -= 1
				if clip <= 0:
					reload_time = Man.equipped_weapon.data["reload_time"]
				play_sfx("shoot", global_position, 10.0)
				screen_shake(2.0, 0.15)
				
			if (Input.is_action_just_pressed("attack_up") or Input.is_action_just_pressed("attack_down") or Input.is_action_just_pressed("attack_left") or Input.is_action_just_pressed("attack_right")):
				play_animation("throw_" + last_direction)
				var direction = Vector2.ZERO
				if Input.is_action_just_pressed("attack_up"):
					direction.y -= 1
				if Input.is_action_just_pressed("attack_down"):
					direction.y += 1
				if Input.is_action_just_pressed("attack_left"):
					direction.x -= 1
				if Input.is_action_just_pressed("attack_right"):
					direction.x += 1
				
				direction = direction.normalized()
				
				# Shoot 3 projectiles with spread
				var spread_angle = deg_to_rad(15)
				for i in range(-1, 2):
					var angle_offset = i * spread_angle
					var spread_direction = direction.rotated(angle_offset)
					
					if multiplayer.has_multiplayer_peer():
						create_throwable.rpc(Man.equipped_weapon.id, global_position, spread_direction, name)
					else:
						create_throwable(Man.equipped_weapon.id, global_position, spread_direction, name)
				
				clip -= 1
				if clip <= 0:
					reload_time = Man.equipped_weapon.data["reload_time"]
				play_sfx("shoot", global_position, 10.0)
				screen_shake(2.0, 0.15)

	# Apply velocity and move
	velocity *= SPEED
	if upgrade_bag.has_item(Catalog.get_by_id(33)):
		velocity *= 1.05 * upgrade_bag.get_item_stack(Catalog.get_by_id(33)).data["level"]
	#play_sfx(walking_sounds.pick_random(), randf_range(-5.0, 5.0))
	if knockback_velocity.length() > 0.1:
		velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	else:
		knockback_velocity = Vector2.ZERO
	
	if Input.is_action_pressed("sprint") and sprint > 0 and not exhausted:
		velocity *= SPRINT_MULTIPLIER
		if velocity.length() > 0:
			sprint -= 1
			
	if velocity.length() > 0:
		step_timer -= delta
		if step_timer <= 0.0:
			if multiplayer.has_multiplayer_peer():
				play_sfx.rpc(walking_sounds.pick_random(), global_position, randf_range(-15.0, -10.0))
			else:
				play_sfx(walking_sounds.pick_random(), global_position, randf_range(-15.0, -10.0))
			step_timer = step_interval + randf_range(0.02, 0.08)
			if Input.is_action_pressed("sprint"):
				step_timer /= 2
	else:
		step_timer = 0.0
	
	if Input.is_action_pressed("info") and not $UI/Defense/Shop.visible:
		$UI/Defense/Tab.visible = true
		for children in $UI/Defense/Tab/ScrollContainer/VBoxContainer.get_children():
			children.queue_free()
		
		if multiplayer.has_multiplayer_peer():
			$UI/Defense/Tab/Title.text = "Players (" + str(NetworkManager.players.size()) + ")"
			for player in NetworkManager.players:
				var kills = 0
				if get_parent().kills.has(str(player["id"])) and get_parent().kills[str(player["id"])].has("bombrat"):
					kills = get_parent().kills[str(player["id"])]["bombrat"]
				var tab_entry = preload("res://scenes/tab_entry.tscn").instantiate()
				tab_entry.get_node("Name").text = player["username"]
				tab_entry.get_node("Kills").text = str(kills)
				tab_entry.get_node("Gold").text = str(get_parent().get_node(str(player["id"])).gold)
				$UI/Defense/Tab/ScrollContainer/VBoxContainer.add_child(tab_entry)
		else:
			$UI/Defense/Tab/Title.text = "Player"
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
			$UI/Defense/Tab/ScrollContainer/VBoxContainer.add_child(tab_entry)
	else:
		$UI/Defense/Tab.visible = false
	
	if has_effect("Gunked"):
		velocity /= 2 
	move_and_slide()

func screen_shake(intensity: float, duration: float):
	var original_offset = $Camera2D.offset
	var shake_count = int(duration / 0.05)  # Shake every 0.05 seconds
	
	for i in shake_count:
		$Camera2D.offset = original_offset + Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		await get_tree().create_timer(0.05).timeout
	
	$Camera2D.offset = original_offset  # Reset to original

@rpc("any_peer", "call_local", "reliable")
func create_boomerang(w_id: int, spawn_pos: Vector2, throw_dir: Vector2, source_path: String):
	var boomerang = boomerang_scene.instantiate()
	boomerang.weapon_id = w_id
	boomerang.global_position = spawn_pos
	boomerang.direction = throw_dir
	boomerang.SOURCE = source_path
	
	get_parent().add_child(boomerang, true)
	play_sfx(["fwip1", "fwip2", "fwip3", "fwip4"].pick_random(), spawn_pos)
	
@rpc("any_peer", "call_local", "reliable")
func create_throwable(w_id: int, spawn_pos: Vector2, throw_dir: Vector2, source_path: String):
	var throwable = throwable_scene.instantiate()  # Make sure you have this scene reference
	throwable.weapon_id = w_id
	throwable.global_position = spawn_pos
	throwable.direction = throw_dir
	throwable.SOURCE = source_path
	
	get_parent().add_child(throwable, true)
	play_sfx(["fwip1", "fwip2", "fwip3", "fwip4"].pick_random(), spawn_pos)

func press_inventory_slot(index: int) -> void:
	if type == "Defense":
		var slots = $UI/Defense/Inventory.get_children()
		if index < 0 or index >= get_slots():
			return

		var slot = slots[index]
		var item = slot.item

		var cooldown_active = item and item.cooldown and Man.is_on_cooldown(item)

		if alive and not cooldown_active:
			slot.get_node("Button").emit_signal("pressed")
	elif type == "Dungeon":
		var slots = $UI/Dungeon/Inventory.get_children()
		if index < 0 or index >= get_slots():
			return

		var slot = slots[index]
		var item = slot.item

		var cooldown_active = item and item.cooldown and Man.is_on_cooldown(item)

		if alive and not cooldown_active:
			slot.get_node("Button").emit_signal("pressed")
		
func change_zoom(delta: float) -> void:
	zoom_multiplier = clamp(zoom_multiplier + delta, 0.50, 2.0)
	_update_camera_zoom()

	$UI/Global/Zoom/Label.text = "x%.2f" % zoom_multiplier
	$UI/Global/Zoom.visible = true
	$UI/Global/Zoom/Timer.start()
	
func _update_camera_zoom() -> void:
	$Camera2D.zoom = original_zoom * zoom_multiplier

func _on_zoom_timeout() -> void:
	$UI/Global/Zoom.visible = false
	
var using_controller := false
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not $UI/Global/ChatBar.has_focus() and not $UI/Defense/Shop.visible and not $UI/Dungeon/Shop.visible:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				change_zoom(0.25)
			MOUSE_BUTTON_WHEEL_DOWN:
				change_zoom(-0.25) 
	if event.is_action_pressed("zoom_in") and not $UI/Global/ChatBar.has_focus():
		change_zoom(0.25)
	elif event.is_action_pressed("zoom_out") and not $UI/Global/ChatBar.has_focus():
		change_zoom(-0.25)
	if not $UI/Global/ChatBar.has_focus() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if $UI/Global/Pause.visible: 
			$UI/Global/Pause.visible = false
		else:
			$UI/Global/Pause.visible = true
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		using_controller = false
		_update_button_focus_styles(false)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		using_controller = true
		_update_button_focus_styles(true)
	elif event is InputEventKey:
		using_controller = true
		_update_button_focus_styles(true)

func _update_button_focus_styles(show_focus: bool) -> void:
	"""Update all button focus styles based on input method"""
	for button in find_children("", "Button", true):
		if button is Button:
			if show_focus:
				button.add_theme_stylebox_override("focus", preload("res://scenes/outline but for ui lol.tres"))
			else:
				button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
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
			52:
				press_inventory_slot(3)
	if (not $UI/Defense/Shop.visible and not $UI/Dungeon/Shop.visible) and (not $"UI/Defense/Game Over".visible and not $"UI/Dungeon/Game Over".visible):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
			$UI/Global/ChatBar.grab_focus()

@rpc("any_peer", "call_local", "reliable")
func knockback(from_player) -> void:
	if not alive:
		return
	var player = get_parent().get_node(NodePath(from_player))
	if player == null:
		return
	# Calculate knockback direction and apply it
	var knockback_strength = 180.0  # Adjust this value to control knockback power
	apply_knockback(player.position, knockback_strength)
	
	# Optional: Play a light impact sound
	if multiplayer.has_multiplayer_peer():
		play_sfx.rpc("swoosh2louder", global_position, -15.0, randf_range(1.2, 1.4))
	else:
		play_sfx("swoosh2louder", global_position, -15.0, randf_range(1.2, 1.4))

func clear_slashes() -> void:
	for child in get_children():
		if child.name.begins_with("Slash"):
			child.queue_free()

func _enable_sword_hitbox(direction: String) -> void:
	var hitbox = $SwordHbox
	clear_slashes()
	# Disable all sword hitboxes first
	for child in hitbox.get_children():
		if child is CollisionShape2D:
			child.disabled = true

	# Enable the correct directional hitbox
	if not hitbox.has_node(direction):
		return
	
	var shape_node = hitbox.get_node(direction)
	if not (shape_node is CollisionShape2D):
		return
	
	shape_node.disabled = false

	var shape: Shape2D = shape_node.shape
	var reach_factor := sword_reach / 2.0

	if shape is RectangleShape2D:
		match direction:
			"up":
				shape.size = Vector2(58.0, 20.5 * reach_factor)
				shape_node.position = Vector2(0, -20 * reach_factor)
			"down":
				shape.size = Vector2(58.0, 20.5 * reach_factor)
				shape_node.position = Vector2(0, 20 * reach_factor)
			"left":
				shape.size = Vector2(20.5 * reach_factor, 58.0)
				shape_node.position = Vector2(-20 * reach_factor, 0)
			"right":
				shape.size = Vector2(20.5 * reach_factor, 58.0)
				shape_node.position = Vector2(20 * reach_factor, 0)

	# Spawn the slash effect
	var slash_scene := preload("res://scenes/slash_effect.tscn")
	var slash = slash_scene.instantiate()
	add_child(slash, true)
	slash.show_slash(get_fan_slash_points(global_position, direction, reach_factor))

func get_fan_slash_points(player_pos: Vector2, direction: String, reach_factor: float, segments: int = 12, fan_angle: float = 60.0) -> Array[Vector2]:
	var points: Array[Vector2] = []
	
	# Simple 36 unit offset based on direction
	var offset := Vector2.ZERO
	match direction:
		"up":
			offset = Vector2(0, 42)
		"down":
			offset = Vector2(0, -42)
		"left":
			offset = Vector2(42, 0)
		"right":
			offset = Vector2(-42, 0)
	
	# Start position is player + offset
	var start_pos = player_pos + offset
	
	# Base direction vector
	var base_direction := Vector2.ZERO
	match direction:
		"up":
			base_direction = Vector2(0, -1)
		"down":
			base_direction = Vector2(0, 1)
		"left":
			base_direction = Vector2(-1, 0)
		"right":
			base_direction = Vector2(1, 0)
	
	# Slash size (58.0 units)
	var slash_size = 58.0
	
	# Convert fan angle to radians
	var half_fan = deg_to_rad(fan_angle / 2.0)
	
	# Randomness parameters
	var wobble_amount = 0.0  # How much the slash wobbles in degrees
	var length_variation = 0.0  # Random length variation in pixels
	
	# Create fan points with randomness
	for i in range(segments + 1):
		var t = float(i) / float(segments)
		
		# Angle offset for the fan spread
		var angle_offset = lerp(-half_fan, half_fan, t)
		
		# Rotate the base direction by the angle
		var rotated_dir = base_direction.rotated(angle_offset)
		
		# Point extends from start position by randomized distance
		var point = start_pos + rotated_dir * slash_size
		points.append(point)
	
	return points

func _disable_all_sword_hitboxes() -> void:
	var hitbox_container := $SwordHbox
	if not is_instance_valid(hitbox_container):
		return

	for child in hitbox_container.get_children():
		if child is CollisionShape2D:
			child.disabled = true

	clear_slashes()

func show_ui() -> void:
	if $UI/Defense.visible:
		$UI/Defense/Markers.visible = true
		$UI/Defense/HealthBar.visible = true
		$UI/Defense/OverhealBar.visible = true
		$"UI/Defense/Health Label".visible = true
		$UI/Defense/SprintBar.visible = true
		$UI/Defense/Inventory.visible = true
		$UI/Defense/HBoxContainer.visible = true
	else:
		$UI/Dungeon/HBoxContainer.visible = true 
		$UI/Dungeon/HealthBar.visible = true
		$UI/Dungeon/OverhealBar.visible = true
		
		$UI/Dungeon/SprintBar.visible = true
		$UI/Dungeon/Inventory.visible = true
		$"UI/Dungeon/Health Label".visible = true

func hide_ui() -> void:
	if $UI/Defense.visible:
		$UI/Defense/HealthBar.visible = false
		$UI/Defense/OverhealBar.visible = false
		$"UI/Defense/Health Label".visible = false
		$UI/Defense/Markers.visible = false
		$UI/Defense/SprintBar.visible = false
		$UI/Defense/Inventory.visible = false
		$UI/Defense/HBoxContainer.visible = false
		$UI/Defense/Tab.visible = false
		$UI/Defense/Shop.visible = false
	else:
		$UI/Dungeon/HealthBar.visible = false
		$UI/Dungeon/OverhealBar.visible = false
		$"UI/Dungeon/Health Label".visible = false
		$UI/Dungeon/HBoxContainer.visible = false 
		$UI/Dungeon/HealthBar.visible = false
		$UI/Dungeon/SprintBar.visible = false
		$UI/Dungeon/Inventory.visible = false 
		$UI/Dungeon/Shop.visible = false

func _is_mouse_over_chat_bar() -> bool:
	if not $UI/Global/ChatBar.visible:
		return false
	var local_mouse_pos = $UI/Global/ChatBar.get_local_mouse_position()
	return $UI/Global/ChatBar.get_rect().has_point(local_mouse_pos)

func get_blended_effect_color() -> Color:
	if active_effects.is_empty():
		return Color.WHITE
	
	var total_red := 0.0
	var total_green := 0.0
	var total_blue := 0.0
	var count := 0
	
	for effect in active_effects:
		if effect != null and is_instance_valid(effect):
			var color = effect.color
			total_red += color.r
			total_green += color.g
			total_blue += color.b
			count += 1
	
	if count == 0:
		return Color.WHITE
	
	return Color(
		total_red / count,
		total_green / count,
		total_blue / count,
		1.0
	)

func _physics_process(delta: float) -> void:
	#position = clamp_player_position(position)
	#print($AudioListener2D.is_current())
	if multiplayer.has_multiplayer_peer() and not is_multiplayer_authority():
		return
	if lifesteal_cooldown > 0.0:
		lifesteal_cooldown -= delta
	if active_effects.size() > 0:
		$Potion.emitting = true
		$Potion.process_material.color = get_blended_effect_color()
	else:
		$Potion.emitting = false
	if Man.selected_map == "Lysawood" and Man.selected_mode == "Defense":
		if global_position.x < (-30.5 * 16):
			global_position.x = 30.15 * 16
		elif global_position.x > (30.15 * 16):
			global_position.x = (-30.5 * 16)

		if global_position.y < (-485.1):
			global_position.y = 29.55 * 16
		elif global_position.y > (477.0):
			global_position.y = (-485.1)

	if Man.equipped_weapon.type == "THROWABLE":
		$Clip.value = float(clip) / float(Man.equipped_weapon.data["clip"]) * 100.0
		if clip <= 0:
			reload_time -= delta
			$Clip.value = float(reload_time) / Man.equipped_weapon.data["reload_time"] * 100.0
			if reload_time <= 0.0:
				clip = Man.equipped_weapon.data["clip"]
				Toast.add("Reloaded your " + Man.equipped_weapon.name + ".")

	elif Man.equipped_weapon.type == "BLUNDERBUSS":
		$Clip.value = float(clip) / float(Man.equipped_weapon.data["clip"]) * 100.0
		if clip < Man.equipped_weapon.data["clip"]:  
			reload_time -= delta
			if reload_time <= 0.0:
				clip += 1 
				play_ui_sfx(preload("res://assets/sounds/load.wav"))
				reload_time = Man.equipped_weapon.data["reload_time"]
				if clip >= Man.equipped_weapon.data["clip"]:
					play_ui_sfx(preload("res://assets/sounds/pump.wav"))
					Toast.add("Reloaded your " + Man.equipped_weapon.name + ".")
	if alive:
		for effect in active_effects.duplicate():
			if effect != null and is_instance_valid(effect):
				if effect.update(delta, self):
					active_effects.erase(effect)
			else:
				active_effects.erase(effect)
	var focused = $UI/Global/ChatBar.has_focus()
	var hovered := _is_mouse_over_chat_bar()
	if focused or hovered:
		$UI/Global/ChatBar.modulate.a = lerp($UI/Global/ChatBar.modulate.a, 1.0, FADE_SPEED * delta)
	else:
		$UI/Global/ChatBar.modulate.a = lerp($UI/Global/ChatBar.modulate.a, 0.0, FADE_SPEED * delta)
	if $UI/Defense.visible:
		if not multiplayer.has_multiplayer_peer() or is_multiplayer_authority():
			$UI/Defense/HealthBar.max_value = get_max_health()
			$UI/Defense/OverhealBar.max_value = get_max_health()
			$UI/Defense/HealthBar.value = health
			$UI/Defense/OverhealBar.value = overheal
			$UI/Defense/SprintBar.value = sprint
			if sprint >= 220:
				exhausted = false
				$UI/Defense/SprintBar.visible = false
			else:
				$UI/Defense/SprintBar.visible = true
			$"UI/Defense/Health Label".text = str(roundi(health + overheal)) + "/" + str(roundi(get_max_health()))
	hit_cooldown = max(hit_cooldown - delta, 0.0)
	if $"UI/Defense/Death".visible:
		$"UI/Defense/Death/Panel/Respawn Timer".text = "You will respawn in " + str(roundi(revival_time)) + " seconds..."
	if $UI/Dungeon/Death.visible:
		$"UI/Dungeon/Death/Panel/Respawn Timer".text = "You will respawn in " + str(roundi(revival_time)) + " seconds..."
	if $UI/Dungeon.visible and (not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()):
		$UI/Dungeon/HBoxContainer/Room/Label.text = "Room: " + str(get_parent().completed_rooms + 1)
		$UI/Dungeon/HBoxContainer/Lives/Label.text = "Lives: " + str(lives)
		$UI/Dungeon/HBoxContainer/Progress/Label.text = str(get_parent().progress)
		$UI/Dungeon/HBoxContainer/Gold/HBoxContainer/Label.text = str(gold)

		if added_gold_timeout > 0.0:
			added_gold_timeout -= delta
			if added_gold_timeout <= 0.0:
				# Timeout finished - start transferring gold
				pass

		if added_gold_timeout <= 0.0 and added_gold > 0:
			# Transfer gold smoothly from added_gold to actual gold
			var increment = max(1, ceil(added_gold * delta * 5.0))
			increment = min(increment, added_gold)
			
			gold += increment
			added_gold -= increment

		# Show the added gold in the same label
		if added_gold > 0:
			$UI/Dungeon/HBoxContainer/Gold/HBoxContainer/Label.text = str(gold) + " (+" + str(added_gold) + ")"
		else:
			$UI/Dungeon/HBoxContainer/Gold/HBoxContainer/Label.text = str(gold)
					
		$UI/Dungeon/HealthBar.max_value = get_max_health()
		$UI/Dungeon/HealthBar.value = health
		$UI/Dungeon/SprintBar.value = sprint
		$UI/Defense/OverhealBar.max_value = get_max_health()
		$UI/Dungeon/OverhealBar.value = overheal
		
		if sprint >= 220:
			exhausted = false
			$UI/Dungeon/SprintBar.visible = false
		else:
			$UI/Dungeon/SprintBar.visible = true
		$"UI/Dungeon/Health Label".text = str(roundi(health + overheal)) + "/" + str(roundi(get_max_health()))
		
		
	if $UI/Defense/Shop.visible:
		$UI/Defense/Shop/Panel/HBoxContainer/Gold.text = str(gold)
	if $UI/Dungeon/Shop.visible:
		$UI/Dungeon/Shop/Panel/HBoxContainer/Gold.text = str(gold)
		
	if not alive and revival_time != -1:
		revival_time -= delta
		
		if revival_time <= 0.0:
			revival_time = 0.0
			damage_dealt = 0.0
			damage_healed = 0.0
			damage_taken = 0.0
			gold_collected = 0
			kills = 0
			if type == "Defense":
				$"UI/Defense/Death".visible = false
			if type == "Dungeon":
				$UI/Dungeon/Death.visible = false
			health = get_max_health()
			gold = max(roundi(gold / 2), 0)
			hit_cooldown = max_hit_cooldown
			if type == "Defense":
				if multiplayer.has_multiplayer_peer():
					Toast.add.rpc_id(int(name), "You respawned! You lost half your gold.")
				else:
					Toast.add("You respawned! You lost half your gold.")
			elif type == "Dungeon":
				lives -= 1
				if multiplayer.has_multiplayer_peer():
					Toast.add.rpc_id(int(name), "You respawned! You have " + str(lives) + " lives left.")
				else:
					Toast.add("You respawned! You have " + str(lives) + " lives left.")
			play_idle_animation()
			$AnimatedSprite2D.material = null
			if type == "Defense":
				global_position = Vector2.ZERO
				if $UI/Defense/Shop.visible:
					$UI/Defense/Shop/Panel/HBoxContainer/Gold.text = str(gold)
					
			elif type == "Dungeon":
				if $UI/Dungeon/Shop.visible:
					$UI/Dungeon/Shop/Panel/HBoxContainer/Gold.text = str(gold)
					
				var safe_position = Vector2.ZERO

				if not get_parent().room_ids_in_order.is_empty():
					var latest_room_id = get_parent().room_ids_in_order[-1]
					safe_position = get_parent().find_room_exit_position(latest_room_id, "south")  # Prefer south exit (entrance)
					
					# If no exit found in latest room, try other active rooms
					if safe_position == Vector2.ZERO:
						for i in range(get_parent().room_ids_in_order.size() - 1, -1, -1):  # Go backwards through rooms
							var room_id = get_parent().room_ids_in_order[i]
							safe_position = get_parent().find_room_exit_position(room_id)
							if safe_position != Vector2.ZERO:
								break
				
				# Fallback: use the old nearest safe position method
				if safe_position == Vector2.ZERO:
					safe_position = get_parent().find_nearest_safe_position(global_position)
				
				if safe_position != Vector2.ZERO:
					global_position = safe_position
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
	
	if type == "Defense":
		var found_shop = false
		for area in $Area2D.get_overlapping_areas():
			if (area as Area2D).is_in_group("gem"):
				found_shop = true
		$Key.visible = found_shop
			
		var slots = $UI/Defense/Inventory.get_children()
		var max_slots = get_slots()  # Get the number of slots player should have

		for i in max_slots:  # Only iterate through available slots
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
				slot.set_item(null)
				icon.visible = false
				amount_label.visible = false
				progress_bar.visible = false

		# Hide any remaining slots beyond max_slots
		for i in range(max_slots, slots.size()):
			var slot = slots[i]
			slot.visible = false
	elif type == "Dungeon":
		var found_shop = false
		for area in $Area2D.get_overlapping_areas():
			if (area as Area2D).is_in_group("gem"):
				found_shop = true
		$Key.visible = found_shop
		
		var slots = $UI/Dungeon/Inventory.get_children()
		var max_slots = get_slots()  # Get the number of slots player should have

		for i in max_slots:  # Only iterate through available slots
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
				slot.set_item(null)
				icon.visible = false
				amount_label.visible = false
				progress_bar.visible = false

		# Hide any remaining slots beyond max_slots
		for i in range(max_slots, slots.size()):
			var slot = slots[i]
			slot.visible = false

	if sword_hitbox_active:
		for body in $SwordHbox.get_overlapping_bodies():
			if body.is_in_group("enemies") and body not in hit_enemies:
				_process_hit(body, Man.equipped_weapon.damage + get_bonus_damage())
				hit_enemies.append(body)
			if body.is_in_group("players") and body.alive and body != self:
				if multiplayer.has_multiplayer_peer():
					body.knockback.rpc_id(body.name.to_int(), name)
				else:
					body.knockback(name)
		
		sword_hitbox_timer -= delta
		if sword_hitbox_timer <= 0.0:
			sword_hitbox_active = false
			hit_enemies.clear()
			_disable_all_sword_hitboxes()
	var count := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.id == 1 or enemy.id == 4:
			count += 1
	if count > 0:
		bombrat_counter.text = "%d" % count

	if type == "Defense" and $UI/Defense.visible and (not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()):
		$UI/Defense/HBoxContainer/Wave/Label.text = "Wave: " + str(get_parent().wave)
		$UI/Defense/HBoxContainer/Gold/HBoxContainer/Label.text = str(gold)

		if added_gold_timeout > 0.0:
			added_gold_timeout -= delta
			if added_gold_timeout <= 0.0:
				# Timeout finished - start transferring gold
				pass

		if added_gold_timeout <= 0.0 and added_gold > 0:
			# Transfer gold smoothly from added_gold to actual gold
			var increment = max(1, ceil(added_gold * delta * 5.0))
			increment = min(increment, added_gold)
			
			gold += increment
			added_gold -= increment

		# Show the added gold in the same label
		if added_gold > 0:
			$UI/Defense/HBoxContainer/Gold/HBoxContainer/Label.text = str(gold) + " (+" + str(added_gold) + ")"
		else:
			$UI/Defense/HBoxContainer/Gold/HBoxContainer/Label.text = str(gold)
					
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
	if $AnimatedSprite2D.animation.begins_with("sword_") or $AnimatedSprite2D.animation.begins_with("throw_"):
		play_idle_animation()

func get_boomerang_back() -> void:
	has_boomerang = true

@rpc("any_peer", "call_local")
func add_hit_particles(position: Vector2, angle: float):
	var hitting_particles = hitting_particles_instance
	var particles = hitting_particles.instantiate()
	get_parent().add_child(particles, true)
	particles.global_position = position
	particles.rotation = angle
	particles.emitting = true

var lifesteal_cooldown: float = 0.0
const LIFESTEAL_COOLDOWN_DURATION: float = 2.0

# Add this at the top of your player script with other variables
var chain_hit_target = null
var chain_hit_count = 0

func _process_hit(body, damage: float):
	if body.is_in_group("enemies"):
		if multiplayer.has_multiplayer_peer():
			play_sfx.rpc("swoosh2louder", global_position, -8.0, randf_range(0.95, 1.15))
		else:
			play_sfx("swoosh2louder", global_position, -8.0, randf_range(0.95, 1.15))
		
		# Apply separate Strength buff multiplier if active
		var strength_multiplier = 2.5 if has_effect("Strength") else 1.0

		# Apply crit damage
		var s = strength
		var crit_multiplier = 2.5 if (randf() * 100.0) <= get_crit_chance() else 1.0
		if guaranteed_crit:
			crit_multiplier = 2.5
			guaranteed_crit = false
		var crit = true if crit_multiplier == 2.5 else false
		if upgrade_bag.has_item(Catalog.get_by_id(32)) and (health / get_max_health()) <= 0.4:
			crit_multiplier += 0.05 * upgrade_bag.get_item_stack(Catalog.get_by_id(32)).data["level"]
			s += 5 * upgrade_bag.get_item_stack(Catalog.get_by_id(32)).data["level"]
		
		# Overdrive increases damage at full health
		if upgrade_bag.has_item(Catalog.get_by_id(40)):
			if health >= get_max_health():
				s += 25  # +25 strength at full health
			
		# Damage before defense, using normal strength stat scaling
		var damage_before_defense = ((damage * (1.0 + s / 100.0)) * strength_multiplier) * crit_multiplier 

		# Defense reduction formula with Piercing and Chain Hits
		var defense = body.defense

		# Check for Piercing upgrade
		if upgrade_bag.has_item(Catalog.get_by_id(27)):
			var piercing_level = upgrade_bag.get_item_stack(Catalog.get_by_id(27)).data["level"]
			# Each level ignores 15% of defense
			var defense_ignored = piercing_level * 0.15
			defense = defense * (1.0 - defense_ignored)

		# Check for Chain Hits upgrade
		if upgrade_bag.has_item(Catalog.get_by_id(39)):
			var chain_level = upgrade_bag.get_item_stack(Catalog.get_by_id(39)).data["level"]
			
			# Check if we're hitting the same target
			if chain_hit_target == body:
				chain_hit_count += 1
			else:
				# Reset chain on new target
				chain_hit_target = body
				chain_hit_count = 0
			
			# Reduce defense based on chain count (5 defense reduction per hit, capped by upgrade level)
			var max_chain_hits = chain_level * 3  # Level 1 = 3 hits, Level 4 = 12 hits
			var effective_chain = min(chain_hit_count, max_chain_hits)
			var defense_reduction = effective_chain * 5
			defense = max(defense - defense_reduction, 0)

		var defense_factor = 1.0 - (defense / (defense + 100.0))

		# Final damage after defense
		var total_damage = damage_before_defense * defense_factor

		# Positioning and visuals
		var direction = body.global_position - global_position
		var midpoint = global_position + direction * 0.5
		var angle = direction.angle()

		damage_dealt += total_damage
		total_damage_dealt += total_damage

		var heal_amount = 0.0
		if Man.equipped_armor.id == 14 and lifesteal_cooldown <= 0.0:
			heal_amount += total_damage * 0.1
		if upgrade_bag.has_item(Catalog.get_by_id(26)):
			heal_amount += (0.1 * upgrade_bag.get_item_stack(Catalog.get_by_id(26)).data["level"])
		
		if heal_amount > 0.0:	
			heal(heal_amount)
			lifesteal_cooldown = LIFESTEAL_COOLDOWN_DURATION

		if upgrade_bag.has_item(Catalog.get_by_id(28)):
			var slow_chance = 0.1 * upgrade_bag.get_item_stack(Catalog.get_by_id(28)).data["level"]
			if slow_chance > randf() and not body.has_effect("Gunked"):
				var gunked = Effect.new("Gunked", Color.from_rgba8(0, 150, 255, 255), 8.0, 0, 0)
				body.add_status_effect(gunked)

		if upgrade_bag.has_item(Catalog.get_by_id(38)) and total_damage > body.health:
			guaranteed_crit = true
			
		# Multiplayer-safe damage + particles
		if multiplayer.has_multiplayer_peer():
			body.take_damage.rpc(total_damage, global_position, name, crit)
			add_hit_particles.rpc(midpoint, angle)
		else:
			body.take_damage(total_damage, global_position, name, crit)
			add_hit_particles(midpoint, angle)

func _on_shop_close_button_pressed() -> void:
	$UI/Defense/Shop.visible = false
	$UI/Dungeon/Shop.visible = false
	

func add_message(message: String, player_name: String) -> void:
	if multiplayer.has_multiplayer_peer():
		print("[" + str(multiplayer.get_unique_id()) + "] Received message: ", message)
	var chat_message = load("res://scenes/chat_message.tscn").instantiate()
	chat_message.text = player_name + ": " + message
	chat_message.visible = true
	chat_message.modulate = Color(1, 1, 1, 1)
	$UI/Global/Chat/VBoxContainer.add_child(chat_message, true)
	_write_chat_log(player_name, message)
	await get_tree().process_frame
	$UI/Global/Chat.scroll_vertical = $UI/Global/Chat.get_v_scroll_bar().max_value

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
	$UI/Global/ChatBar.text = ""
	$UI/Global/ChatBar.release_focus()
	if new_text == "":
		return

	var player_name = NetworkManager.player_name if NetworkManager.player_name != "" else "Player"
	if multiplayer.has_multiplayer_peer():
		NetworkManager.send_message.rpc(new_text, player_name)
	else:
		add_message(new_text, player_name)

func _on_chat_bar_focus_entered() -> void:
	for child in $UI/Global/Chat/VBoxContainer.get_children():
		child.visible = true
		child.modulate = Color(1, 1, 1, 1)
		for node in child.get_children():
			if node is Timer:
				node.stop()
	await get_tree().process_frame
	$UI/Global/Chat.scroll_vertical = $UI/Global/Chat.get_v_scroll_bar().max_value

func _on_chat_bar_focus_exited() -> void:
	for child in $UI/Global/Chat/VBoxContainer.get_children():
		if child.should_fade:
			child.visible = true
			child.modulate = Color(1, 1, 1, 1)
			for node in child.get_children():
				if node is Timer:
					node.start()
		else:
			child.visible = false

func _on_play_again_pressed() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		get_parent().end.rpc()
		get_parent().reset.rpc()
	elif not multiplayer.has_multiplayer_peer():
		get_parent().end()
		get_parent().reset()

func _on_main_menu_pressed() -> void:
	if multiplayer.has_multiplayer_peer():
		Man.end_game.rpc()
	else:
		Man.end_game()

func _on_chatbar_gui_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if $UI/Global/ChatBar.has_focus():
			$UI/Global/ChatBar.text = ""
			$UI/Global/ChatBar.release_focus()
			get_viewport().set_input_as_handled()

func _on_quit_game_pressed() -> void:
	Man.save_game("quit")
	get_tree().quit()

func _on_resume_pressed() -> void:
	$UI/Global/Pause.visible = false
	
func _on_quit_to_main_menu_pressed() -> void:
	Man.end_game()

func _on_reroll_pressed() -> void:
	reroll_shop()
