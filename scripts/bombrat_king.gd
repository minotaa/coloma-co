extends Entity

const WANDER_SPEED := 25.0
const CHARGE_SPEED := 80.0
const SHOCKWAVE_INTERVAL := 12.0
const TIMER_DURATION := 120.0  # Time before enrage/charge
const KING_EXPLOSION_RADIUS := 30.0  # Big explosions for the king
const KING_EXPLOSION_TIME := 3.0  # Slower, more dramatic expansion

var wander_target: Vector2
var wander_timer: float = 0.0
var shockwave_timer: float = 0.0
var enrage_timer: float = TIMER_DURATION
var is_enraged: bool = false
var is_charging: bool = false
var game_node: Node = null  # Reference to the Defense game node

func initialize_entity() -> void:
	var boost = 250 * NetworkManager.players.size()
	entity_name = "Bombrat King"
	health = 2250.0 + boost
	max_health = 2250.0 + boost
	defense = 25.0
	id = 13  # Unique ID for boss
	speed = WANDER_SPEED
	
	sprite.play("bombrat-down")  # Assuming you'll scale this up in the scene
	
	# Get reference to game node
	game_node = get_parent()
	
	# Override wave spawning logic
	if game_node and game_node.has_method("set_boss_wave_mode"):
		game_node.set_boss_wave_mode(true)
	
	# Announce boss spawn
	if multiplayer.has_multiplayer_peer():
		announce_spawn.rpc()
	else:
		announce_spawn()
	
	# Set initial wander target
	choose_new_wander_target()

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
	
	# Update timers
	enrage_timer -= delta
	shockwave_timer -= delta
	wander_timer -= delta
	
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
	else:
		wander_around(delta, movement_multiplier)

func wander_around(delta: float, movement_multiplier: float) -> void:
	# Choose new target if timer expired or reached destination
	if wander_timer <= 0 or global_position.distance_to(wander_target) < 10.0:
		choose_new_wander_target()
		wander_timer = randf_range(2.0, 4.0)
	
	# Move toward wander target
	var dir = (wander_target - global_position).normalized()
	velocity = dir * speed * movement_multiplier
	update_sprite_direction(dir)

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

func choose_new_wander_target() -> void:
	# Pick a random point within reasonable distance
	var random_offset = Vector2(
		randf_range(-2000, 2000),
		randf_range(-2000, 2000)
	)
	wander_target = global_position + random_offset

func spawn_shockwave() -> void:
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
	
	get_parent().add_child(explosion)
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
		
		get_parent().add_child(explosion)
		
		await get_tree().create_timer(0.5).timeout
	
	play_sfx("better5", global_position, 5.0, 0.7)  # Louder, lower pitch
