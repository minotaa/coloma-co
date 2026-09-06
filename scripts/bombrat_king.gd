extends Entity

const WANDER_SPEED := 25.0
const CHARGE_SPEED := 80.0
const SHOCKWAVE_INTERVAL := 12.0
const TIMER_DURATION := 120.0  # Time before enrage/charge
const KING_EXPLOSION_RADIUS := 30.0  # Big explosions for the king
const KING_EXPLOSION_TIME := 3.0  # Slower, more dramatic expansion

const MORTAR_COOLDOWN_MIN := 2.5
const MORTAR_COOLDOWN_MAX := 8.0
const MORTAR_RANGE := 600.0
const MORTAR_SCENE := preload("res://scenes/bombrat_mortar.tscn")

const LUNGE_RANGE := 150.0
const LUNGE_TELEGRAPH_TIME := 1.2
const LUNGE_SPEED := 400.0
const LUNGE_DURATION := 0.35
const LUNGE_DAMAGE := 30.0
const LUNGE_COOLDOWN := 4.0

var stored_collision_mask: int = 0
const DECOR_LAYER_BIT := 2

var lunge_cooldown_timer: float = 0.0
var is_lunging: bool = false
var is_telegraphing_lunge: bool = false
var lunge_direction: Vector2 = Vector2.ZERO
var lunge_timer: float = 0.0

var mortar_cooldown_timer: float = 0.0
var shockwave_timer: float = 0.0
var enrage_timer: float = TIMER_DURATION
var is_enraged: bool = false
var is_charging: bool = false
var game_node: Node = null  # Reference to the Defense game node

func get_mortar_cooldown() -> float:
	var health_pct = clamp(health / max_health, 0.0, 1.0)
	return lerp(MORTAR_COOLDOWN_MIN, MORTAR_COOLDOWN_MAX, health_pct)

func initialize_entity() -> void:
	var boost = 250 * NetworkManager.players.size()
	entity_name = "Bombrat King"
	bestiary_description = "The king of most bombrats, has a timer when spawning that requires you to defeat it within a certain amount of time. Spawns shockwaves every so often."
	developer_commentary = "Hey it's like the Bob-omb King! I just noticed that, the similarity was not intended, I'll give you that much. I just didn't wanna call it a Mother or a Father like the Mother Slime."
	dev_commentary_requirement = 2
	health = 2250.0 + boost
	max_health = 2250.0 + boost
	defense = 20.0
	id = 13  # Unique ID for boss
	speed = WANDER_SPEED
	
	sprite.play("bombrat-down")  # Assuming you'll scale this up in the scene
	
	game_node = get_parent()
	if game_node and game_node.has_method("set_boss_wave_mode"):
		game_node.set_boss_wave_mode(true)
		# Announce boss spawn
		if multiplayer.has_multiplayer_peer():
			announce_spawn.rpc()
		else:
			announce_spawn()

@rpc("any_peer", "call_local")
func announce_spawn() -> void:
	print("⚠️ BOMBRAT KING HAS SPAWNED! ⚠️")
	# You can add visual/audio feedback here

func get_gold_reward() -> int:
	return 1000

func get_kill_type() -> String:
	return "bombrat_king"

func on_player_contact(player: Node) -> void:
	# Boss doesn't damage on contact, only through shockwaves
	pass

func custom_physics_process(delta: float, movement_multiplier: float) -> void:
	if not alive:
		return
	if not game_node or not game_node.has_method("set_boss_wave_mode"):
		return 
		
	lunge_cooldown_timer -= delta

	lunge_cooldown_timer -= delta
	mortar_cooldown_timer -= delta

	if is_telegraphing_lunge or is_lunging:
		process_lunge(delta)
		return

	if not is_charging:
		var target_player = get_nearest_player()
		if target_player:
			var dist = global_position.distance_to(target_player.global_position)

			if dist <= LUNGE_RANGE and lunge_cooldown_timer <= 0:
				start_lunge(target_player)
				return
			elif dist <= MORTAR_RANGE and mortar_cooldown_timer <= 0:
				fire_mortar(target_player)
				mortar_cooldown_timer = get_mortar_cooldown()
		
	# Update timers
	enrage_timer -= delta
	
	# Check for enrage
	if enrage_timer <= 0 and not is_enraged:
		trigger_enrage()
	
	# Spawn shockwaves periodically while wandering
	if shockwave_timer <= 0 and not is_charging:
		spawn_shockwave()
		shockwave_timer = SHOCKWAVE_INTERVAL
	
	# Handle movement
	if is_charging:
		charge_to_gem(delta)
		
func fire_mortar(target_player: Node2D) -> void:
	if multiplayer.has_multiplayer_peer():
		if multiplayer.is_server():
			spawn_mortar.rpc(target_player.global_position)
	else:
		spawn_mortar(target_player.global_position)

@rpc("any_peer", "call_local", "reliable")
func spawn_mortar(target_pos: Vector2) -> void:
	var mortar = MORTAR_SCENE.instantiate()
	get_parent().add_child(mortar, true)
	mortar.target_position = target_pos

func start_lunge(target_player: Node2D) -> void:
	is_telegraphing_lunge = true
	lunge_timer = LUNGE_TELEGRAPH_TIME
	lunge_direction = (target_player.global_position - global_position).normalized()
	velocity = Vector2.ZERO
	update_sprite_direction(lunge_direction)

	stored_collision_mask = collision_mask
	set_collision_mask_value(DECOR_LAYER_BIT, false)

	if multiplayer.has_multiplayer_peer():
		announce_lunge_telegraph.rpc()
	else:
		announce_lunge_telegraph()

@rpc("any_peer", "call_local")
func _flash():
	if sprite:
		sprite.material = preload("res://scenes/flash.tres")
		await get_tree().create_timer(0.1).timeout
		sprite.material = normal_material

@rpc("any_peer", "call_local")
func announce_lunge_telegraph() -> void:
	for i in range(12):
		if multiplayer.has_multiplayer_peer():
			_flash.rpc()
		else:
			_flash()
		await get_tree().create_timer(0.1).timeout
	pass

func process_lunge(delta: float) -> void:
	if is_telegraphing_lunge:
		lunge_timer -= delta
		velocity = Vector2.ZERO
		if lunge_timer <= 0:
			is_telegraphing_lunge = false
			is_lunging = true
			lunge_timer = LUNGE_DURATION
		return

	if is_lunging:
		velocity = lunge_direction * LUNGE_SPEED
		lunge_timer -= delta

		for body in hurtbox.get_overlapping_bodies():
			if body.is_in_group("players") and body.alive: 
				if body and body.has_method("take_damage"):
					body.take_damage(LUNGE_DAMAGE, name, global_position)
				end_lunge()
				return

		if lunge_timer <= 0:
			end_lunge()

func end_lunge() -> void:
	is_lunging = false
	is_telegraphing_lunge = false
	velocity = Vector2.ZERO
	lunge_cooldown_timer = LUNGE_COOLDOWN
	set_collision_mask(stored_collision_mask)

func charge_to_gem(delta: float) -> void:
	var target = get_nearest_gem()
	if not target:
		velocity = Vector2.ZERO
		return
	
	# Check if touching gem
	for area in hurtbox.get_overlapping_areas():
		if area.is_in_group("gem"):
			alive = false
			explode_at_gem(area)
			return
	
	# Navigate to gem
	agent.target_position = target.global_position
	var next_pos = agent.get_next_path_position()
	
	if next_pos != Vector2.ZERO:
		var dir = (next_pos - global_position).normalized()
		velocity = dir * CHARGE_SPEED
		update_sprite_direction(dir)
	else:
		velocity = Vector2.ZERO

func spawn_shockwave() -> void:
	if game_node and game_node.has_method("set_boss_wave_mode"):
		if multiplayer.has_multiplayer_peer():
			create_shockwave.rpc(global_position)
		else:
			create_shockwave(global_position)

@rpc("any_peer", "call_local", "reliable")
func create_shockwave(pos: Vector2) -> void:
	var explosion_scene = preload("res://scenes/lethal_explosion.tscn")
	var explosion = explosion_scene.instantiate()
	explosion.global_position = pos
	explosion.emitting = true
	
	# Limit damage for this specific explosion
	explosion.MIN_DAMAGE = 10.0
	explosion.MAX_DAMAGE = 25.0
	explosion.process_material.scale_min = 10.0
	explosion.process_material.scale_max = 20.0
	
	# Make it bigger and slower for the king
	explosion.lifetime = KING_EXPLOSION_TIME + 0.3
	explosion.MAX_RADIUS = KING_EXPLOSION_RADIUS
	explosion.EXPANSION_TIME = KING_EXPLOSION_TIME
	
	get_parent().add_child(explosion, true)
	play_sfx("better5", pos, -5.0)

func trigger_enrage() -> void:
	is_enraged = true
	is_charging = true
	
	# Buff all bombrats with Speed effect
	buff_all_bombrats()
	
	if multiplayer.has_multiplayer_peer():
		announce_enrage.rpc()
	else:
		announce_enrage()

@rpc("any_peer", "call_local")
func announce_enrage() -> void:
	print("🔥 BOMBRAT KING IS ENRAGED! ALL BOMBRATS ACCELERATED! 🔥")

func buff_all_bombrats() -> void:
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in all_enemies:
		# Check if it's a bombrat (id 1) or big bombrat (id 4)
		if enemy.has_method("add_status_effect") and (enemy.id == 1 or enemy.id == 4):
			var speed_effect = Effect.new("Speed", Color.from_rgba8(41, 145, 255, 255), INF)  # Permanent blue speed buff
			
			if multiplayer.has_multiplayer_peer():
				apply_buff_to_bombrat.rpc(enemy.get_path())
			else:
				enemy.add_status_effect(speed_effect)

@rpc("any_peer", "call_local")
func apply_buff_to_bombrat(enemy_path: NodePath) -> void:
	var enemy = get_node_or_null(enemy_path)
	if enemy and enemy.has_method("add_status_effect"):
		var speed_effect = Effect.new("Speed", Color.from_rgba8(41, 145, 255, 255), INF)
		enemy.add_status_effect(speed_effect)

@rpc("any_peer", "call_local", "reliable")
func explode_at_gem(gem_area: Area2D) -> void:
	var explosion_scene = preload("res://scenes/lethal_explosion.tscn")
	var explosion = explosion_scene.instantiate()
	explosion.global_position = global_position
	explosion.emitting = true
	get_parent().add_child(explosion)
	
	# Deal 50 damage to the gem
	if gem_area.has_method("take_damage"):
		gem_area.take_damage(50.0)
	
	play_sfx("better5", global_position)
	die()

func get_nearest_gem() -> Node2D:
	var gems = get_tree().get_nodes_in_group("gem")
	var nearest: Node2D = null
	var best_dist := INF
	
	for gem in gems:
		if gem is Node2D:
			var d = global_position.distance_squared_to(gem.global_position)
			if d < best_dist:
				best_dist = d
				nearest = gem
	
	return nearest

func update_sprite_direction(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			sprite.play("bombrat-right")
		else:
			sprite.play("bombrat-left")
	else:
		if dir.y > 0:
			sprite.play("bombrat-down")
		else:
			sprite.play("bombrat-up")

func on_death(killer_name: String) -> void:
	# Restore normal wave spawning
	if game_node and game_node.has_method("set_boss_wave_mode"):
		game_node.set_boss_wave_mode(false)
	
	# Custom death for boss - big explosion
	if multiplayer.has_multiplayer_peer():
		final_explosion.rpc()
	else:
		final_explosion()
		
	if multiplayer.has_multiplayer_peer():
		Toast.add.rpc("The Bombrat King has died!")
	else:
		Toast.add("The Bombrat King has died!")
	
	# Call parent death logic for rewards
	super.on_death(killer_name)

@rpc("any_peer", "call_local")
func final_explosion() -> void:
	var spawn_parent = get_parent()
	if spawn_parent == null:
		return
	
	# Spawn multiple BIG explosions for dramatic effect
	for i in range(5):
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		var explosion_scene = preload("res://scenes/lethal_explosion.tscn")
		var explosion = explosion_scene.instantiate()
		explosion.global_position = global_position + offset
		explosion.emitting = true
		
		# Make death explosions even bigger
		explosion.MAX_RADIUS = KING_EXPLOSION_RADIUS * 1.5
		explosion.EXPANSION_TIME = KING_EXPLOSION_TIME
		
		get_parent().add_child(explosion, true)
		
		await get_tree().create_timer(0.5).timeout
	
	play_sfx("better5", global_position, 5.0, 0.7)  # Louder, lower pitch
