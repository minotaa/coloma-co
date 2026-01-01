extends Node2D

var rng = RandomNumberGenerator.new()
var wave: int = 0
var bombrats_left: int = 0
var started: bool = false
var spawning_wave: bool = false
var kills = {}

# Boss wave variables
var boss_wave_mode: bool = false
var boss_wave_spawn_timer: float = 0.0
const BOSS_WAVE_SPAWN_DELAY: float = 2.5  # Delay between bombrat spawns during boss wave

var smoke_scene = preload("res://scenes/smoke.tscn")

var rapid_bauble = preload("res://scenes/rapid_bauble.tscn")
var angry_bauble = preload("res://scenes/angry_bauble.tscn")
var bombrat = preload("res://scenes/bombrat.tscn")
var big_bombrat = preload("res://scenes/big_bombrat.tscn")
var slime = preload("res://scenes/slime.tscn")
var mother_slime = preload("res://scenes/mother_slime.tscn")
var poison_slime = preload("res://scenes/poison_slime.tscn")
var bauble = preload("res://scenes/bauble.tscn")
var crabman = preload("res://scenes/crabman.tscn")
var player_scene = preload("res://scenes/player.tscn")
var ghost = preload("res://scenes/ghost.tscn")
var gunk_slime = preload("res://scenes/gunk_slime.tscn")
var explosive_bauble = preload("res://scenes/explosive_bauble.tscn")
var bombrat_king = preload("res://scenes/bombrat_king.tscn")

@onready var spawner_layer = $Spawner

func set_boss_wave_mode(enabled: bool) -> void:
	boss_wave_mode = enabled
	boss_wave_spawn_timer = 0.0

func play_music(stream: AudioStream, looping: bool = false) -> AudioStreamPlayer:
	var sfx = AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.bus = "Music"
	sfx.volume_db = -10.0
	add_child(sfx)

	sfx.play()

	if looping:
		sfx.finished.connect(func():
			sfx.play()
		)
	else:
		sfx.finished.connect(func():
			sfx.queue_free()
		)
	
	return sfx

func add_kill(player_id: String, enemy_type: String) -> void:
	if not kills.has(player_id):
		kills[player_id] = {}
	if not kills[player_id].has(enemy_type):
		kills[player_id][enemy_type] = 0
	kills[player_id][enemy_type] += 1
	get_node(str(player_id)).kills += 1
	get_node(str(player_id)).total_kills += 1
	if multiplayer.has_multiplayer_peer():
		update_kills.rpc(kills)

func end() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		player.end_game()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	started = false
	wave = 0
	kills = {}
	boss_wave_mode = false

@rpc("authority", "call_local")
func reset() -> void:
	for player in get_tree().get_nodes_in_group("players"):
		player.reset_game()
	spawn_wave()
	Toast.add("Wave started!")
	started = true
	$Gem.alive = true
	$Gem.entity.health = $Gem.entity.max_health
	boss_wave_mode = false
	
func _ready() -> void:
	play_music(preload("res://assets/sounds/MO_ingame_v2.wav"), true)
	if not multiplayer.has_multiplayer_peer():
		# Singleplayer: spawn one player normally
		var p = player_scene.instantiate()
		p.name = "Player"
		p.type = "Defense"
		call_deferred("add_child", p, true)
		spawn_wave()
		Toast.add("Wave started!")
		started = true
		var smoke = smoke_scene.instantiate()
		smoke.global_position = p.global_position
		smoke.emitting = true
		add_child(smoke, true)
		p.setup_ui("Defense")
		p.refresh_shop(randi())
		return
		
	

	# Multiplayer: spawn players from the current list
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		var radius = 20  # Radius of the spawn circle
		for player_data in NetworkManager.players:
			var peer_id = player_data["id"]
			var p = player_scene.instantiate()
			p.name = str(peer_id)
			p.type = "Defense"
			p.get_node("Username").text = player_data["username"]

			# Random angle around the circle
			var angle = rng.randf_range(0.0, TAU)
			var offset = Vector2(cos(angle), sin(angle)) * radius
			p.global_position = offset  # Spawn relative to (0,0); adjust if needed
			call_deferred("add_child", p, true)
			
			var smoke = smoke_scene.instantiate()
			smoke.global_position = p.global_position
			smoke.emitting = true
			add_child(smoke, true)
		
		await get_tree().create_timer(0.2).timeout
		var chosen_seed = randi()
		for player in get_tree().get_nodes_in_group("players"):
			player.setup_ui.rpc("Defense")
			player.refresh_shop.rpc(chosen_seed)
			print("Refreshing shop for " + player.name)
			print("Setting Defense UI for " + player.name + ".")

		# Connect signals for player joins and quits
		NetworkManager.player_joined.connect(player_joined)
		NetworkManager.player_quit.connect(player_quit)

		# Only the server spawns waves
		spawn_wave()
		Toast.add.rpc("Wave started!")
		started = true

func _process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	if not started:
		return

	# Boss wave spawning logic
	if boss_wave_mode:
		boss_wave_spawn_timer -= delta
		if boss_wave_spawn_timer <= 0.0:
			var directions = ["north", "south", "west", "east"]
			spawn_bombrat(directions.pick_random())
			boss_wave_spawn_timer = BOSS_WAVE_SPAWN_DELAY
		
		# Check if boss is still alive
		var boss_alive = false
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if enemy.id == 13:  # Bombrat King ID
				boss_alive = true
				break
		
		if not boss_alive:
			# Boss defeated, end boss wave mode
			boss_wave_mode = false
			if multiplayer.has_multiplayer_peer():
				Toast.add.rpc("Boss defeated! Wave complete!")
				play_sfx.rpc("wavefinished")
			else:
				Toast.add("Boss defeated! Wave complete!")
				play_sfx("wavefinished")
			spawn_wave()
		return
	
	if spawning_wave:
		return

	var bombrats_left := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.id == 1 or enemy.id == 4:
			bombrats_left += 1

	if bombrats_left <= 0:
		if multiplayer.has_multiplayer_peer():
			Toast.add.rpc("Wave complete!")
			play_sfx.rpc("wavefinished")
		else:
			Toast.add("Wave complete!")
			play_sfx("wavefinished")
		spawn_wave()

@rpc("authority", "call_local")
func play_sfx(stream_name: String, volume: float = 0.0, pitch_scale: float = 1.0) -> void:
	var sfx = AudioStreamPlayer.new()
	var path = "res://assets/sounds/" + stream_name + ".wav"
	sfx.stream = load(path)
	sfx.volume_db = volume
	sfx.pitch_scale = pitch_scale
	sfx.bus = "SFX"
	add_child(sfx)

	sfx.play()
	sfx.finished.connect(func():
		sfx.queue_free()
	)

@rpc("authority", "call_remote")
func update_kills(kills: Dictionary) -> void:
	self.kills = kills

@rpc("authority", "call_remote")
func update_wave(wave: int) -> void:
	self.wave = wave
	
var equipment = {}
@rpc("any_peer", "call_local", "reliable") 
func send_equipment(name: String, equipped_weapon: int, equipped_armor: int) -> void:
	equipment[str(name)] = {}
	equipment[str(name)]["equipped_weapon"] = equipped_weapon
	equipment[str(name)]["equipped_armor"] = equipped_armor
	
@rpc("authority", "call_local")
func add_gold(id: String, amount: int) -> void:
	if equipment[id]["equipped_armor"] == 13:
		amount *= 2
	if multiplayer.has_multiplayer_peer():
		get_node(id).add_gold_notification.rpc_id(int(id), amount)
	else:
		get_node(id).add_gold_notification(amount)
	get_node(id).gold_collected += amount
	get_node(id).total_gold_collected += amount

const MAX_RETRIES := 10

func player_joined(id: int) -> void:
	if not multiplayer.is_server():
		return
	print("Player", id, "joined late — kicking silently.")
	multiplayer.disconnect_peer(id)

func _finalize_player_join(p: Node, id: int) -> void:
	add_child(p, true)
	p.setup_ui.rpc("Defense")

func player_quit(id) -> void:
	if not multiplayer.is_server():
		return
		
	print("this fired")

	print("[" + str(multiplayer.multiplayer_peer.get_unique_id()) + "] removing " + str(id) + " from the game")
	for child in get_children():
		if child.name == str(id):
			child.call_deferred("queue_free")

func spawn_wave() -> void:
	spawning_wave = true
	wave += 1

	if wave >= 5:
		if multiplayer.has_multiplayer_peer():
			update_wave.rpc(wave)
			Man.add_xp.rpc(25)
		else:
			Man.add_xp(25)

	var chosen_seed = randi()
	for player in get_tree().get_nodes_in_group("players"):
		if player.alive:
			if multiplayer.has_multiplayer_peer():
				player.heal.rpc(10)
			else:
				player.heal(10)	
		if wave % 5 == 0:
			print("Refreshing players' shops.")
			if multiplayer.has_multiplayer_peer():
				player.refresh_shop.rpc(chosen_seed)
			else:
				player.refresh_shop(chosen_seed)

	# Check for boss wave (every 20 waves)
	if wave % 20 == 0:
		spawn_boss_wave()
		spawning_wave = false
		return

	match wave:
		1:
			spawn_bombrat("north")
			spawn_bombrat("south")
		2:
			spawn_bombrat("north")
			spawn_bombrat("south")
			spawn_bombrat("west")
			spawn_bombrat("east")
		3:
			spawn_bombrat("north")
			spawn_bombrat("south")
			spawn_bombrat("west")
			spawn_bombrat("east")
			await spawn_bombrats(2)
		4:
			spawn_bombrat("north")
			spawn_bombrat("south")
			spawn_bombrat("west")
			spawn_bombrat("east")
			await spawn_bombrats(3)
			spawn_slime("north")
			spawn_slime("south")
		5:
			await spawn_bombrats(5)
			await spawn_slimes(3)
		6:
			await spawn_bombrats(5)
			await spawn_slimes(4)
		7:
			await spawn_bombrats(4)
			await spawn_slimes(4)
			spawn_bauble("north")
		8:
			await spawn_bombrats(4)
			await spawn_slimes(5)
			await spawn_baubles(2)
		9:
			await spawn_bombrats(5)
			await spawn_slimes(5)
			await spawn_baubles(3)
		10:
			await spawn_bombrats(5)
			await spawn_slimes(5)
			await spawn_baubles(4)
			spawn_crabman("north")
		_:
			if wave % 5 == 0:
				var num_crabmen = min(4, 1 + wave / 5)
				for i in range(num_crabmen):
					spawn_crabman("north")

			await spawn_bombrats(4 + wave)
			await spawn_slimes(4 + int(wave / 2))

			var bauble_chance := clampf(0.25 + float(wave) / 30.0, 0.25, 0.75)
			var baubles_to_spawn := 0

			if wave >= 20:
				var ghost_chance := clampf(0.50 + float(wave) / 30.0, 0.50, 0.85)
				if randf() < ghost_chance:
					await spawn_ghosts(randi_range(3, 5))

			for i in range(5):
				if randf() < bauble_chance:
					baubles_to_spawn += 1
					
			if baubles_to_spawn > 0:
				await spawn_baubles(baubles_to_spawn)
	spawning_wave = false

func spawn_boss_wave() -> void:
	if multiplayer.has_multiplayer_peer():
		Toast.add.rpc("BOSS WAVE! A Bombrat King has spawned!")
	else:
		Toast.add("BOSS WAVE! A Bombrat King has spawned!")
	
	# Spawn the Bombrat King
	var matching_cells: Array[Vector2i] = []
	var cells = spawner_layer.get_used_cells()
	
	# Find corner spawn points
	for cell_loc in cells:
		var data = spawner_layer.get_cell_tile_data(cell_loc)
		if not data:
			continue
		if data.get_custom_data("spawner_type") == "corner":
			matching_cells.append(cell_loc)
	
	if matching_cells.is_empty():
		matching_cells = cells.filter(func(c):
			var d = spawner_layer.get_cell_tile_data(c)
			return d and d.get_custom_data("spawner_type") == "main"
		)
	
	if matching_cells:
		var selected_cell = matching_cells.pick_random()
		var spawn_pos = spawner_layer.map_to_local(selected_cell) + Vector2(spawner_layer.tile_set.tile_size) / 2
		var king = bombrat_king.instantiate()
		king.global_position = spawn_pos
		add_child(king, true)
		var smoke = smoke_scene.instantiate()
		smoke.global_position = spawn_pos
		smoke.emitting = true
		add_child(smoke, true)

func spawn_bombrats(count: int) -> void:
	for i in count:
		var delay = randf_range(0.75, 2.25)
		await get_tree().create_timer(delay).timeout
		var directions = ["north", "south", "west", "east"]
		spawn_bombrat(directions.pick_random())

func spawn_crabmen(count: int) -> void:
	for i in count:
		var delay = randf_range(0.75, 2.25)
		await get_tree().create_timer(delay).timeout
		var directions = ["north", "south", "west", "east"]
		spawn_crabman(directions.pick_random())

func spawn_slimes(count: int) -> void:
	for i in count:
		var delay = randf_range(0.75, 2.25)
		await get_tree().create_timer(delay).timeout
		var directions = ["north", "south", "west", "east"]
		spawn_slime(directions.pick_random())

func spawn_ghosts(count: int) -> void:
	for i in count:
		var delay = randf_range(0.75, 2.25)
		await get_tree().create_timer(delay).timeout
		var directions = ["north", "south", "west", "east"]
		spawn_ghost(directions.pick_random())

func spawn_baubles(count: int) -> void:
	for i in count:
		var delay = randf_range(0.75, 2.25)
		await get_tree().create_timer(delay).timeout
		var directions = ["north", "south", "west", "east"]
		spawn_bauble(directions.pick_random())

func spawn_crabman(direction: String) -> void:
	var matching_cells: Array[Vector2i] = []
	var cells = spawner_layer.get_used_cells()

	for cell_loc in cells:
		var data = spawner_layer.get_cell_tile_data(cell_loc)
		if not data:
			continue
		if data.get_custom_data("spawner_type") != "corner":
			continue

		match direction:
			"north":
				if cell_loc.y < 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"south":
				if cell_loc.y > 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"west":
				if cell_loc.x < 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)
			"east":
				if cell_loc.x > 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)

	if matching_cells.is_empty():
		matching_cells = cells.filter(func(c):
			var d = spawner_layer.get_cell_tile_data(c)
			return d and d.get_custom_data("spawner_type") == "main"
		)

	if matching_cells:
		var selected_cell = matching_cells.pick_random()
		var spawn_pos = spawner_layer.map_to_local(selected_cell) + Vector2(spawner_layer.tile_set.tile_size) / 2
		var crabthing = crabman.instantiate()
		crabthing.global_position = spawn_pos
		add_child(crabthing, true)
		var smoke = smoke_scene.instantiate()
		smoke.global_position = spawn_pos
		smoke.emitting = true
		add_child(smoke, true)

func spawn_slime(direction: String) -> void:
	var matching_cells: Array[Vector2i] = []
	var cells = spawner_layer.get_used_cells()

	for cell_loc in cells:
		var data = spawner_layer.get_cell_tile_data(cell_loc)
		if not data:
			continue
		if data.get_custom_data("spawner_type") != "corner":
			continue

		match direction:
			"north":
				if cell_loc.y < 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"south":
				if cell_loc.y > 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"west":
				if cell_loc.x < 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)
			"east":
				if cell_loc.x > 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)

	if matching_cells.is_empty():
		matching_cells = cells.filter(func(c):
			var d = spawner_layer.get_cell_tile_data(c)
			return d and d.get_custom_data("spawner_type") == "main"
		)		
		
	if matching_cells:
		var selected_cell = matching_cells.pick_random()
		var spawn_pos = spawner_layer.map_to_local(selected_cell) + Vector2(spawner_layer.tile_set.tile_size) / 2
		var s: CharacterBody2D
		if wave >= 15 and randf() <= 0.1: 
			var rand = randf()
			if rand <= 0.33:
				s = mother_slime.instantiate()
			elif rand <= 0.66:
				s = poison_slime.instantiate()
			else:
				s = gunk_slime.instantiate()
		else: 
			s = slime.instantiate()
		s.global_position = spawn_pos
		add_child(s, true)
		var smoke = smoke_scene.instantiate()
		smoke.global_position = spawn_pos
		smoke.emitting = true
		add_child(smoke, true)

func spawn_ghost(direction: String) -> void:
	var matching_cells: Array[Vector2i] = []
	var cells = spawner_layer.get_used_cells()

	for cell_loc in cells:
		var data = spawner_layer.get_cell_tile_data(cell_loc)
		if not data:
			continue
		if data.get_custom_data("spawner_type") != "sewer":
			continue

		match direction:
			"north":
				if cell_loc.y < 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"south":
				if cell_loc.y > 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"west":
				if cell_loc.x < 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)
			"east":
				if cell_loc.x > 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)

	if matching_cells.is_empty():
		matching_cells = cells.filter(func(c):
			var d = spawner_layer.get_cell_tile_data(c)
			return d and d.get_custom_data("spawner_type") == "main"
		)
		
	if matching_cells:
		var selected_cell = matching_cells.pick_random()
		var spawn_pos = spawner_layer.map_to_local(selected_cell) + Vector2(spawner_layer.tile_set.tile_size) / 2
		var g = ghost.instantiate()
		g.global_position = spawn_pos
		add_child(g, true)
		var smoke = smoke_scene.instantiate()
		smoke.global_position = spawn_pos
		smoke.emitting = true
		add_child(smoke, true)

func spawn_bombrat(direction: String) -> void:
	var matching_cells: Array[Vector2i] = []
	var cells = spawner_layer.get_used_cells()

	for cell_loc in cells:
		var data = spawner_layer.get_cell_tile_data(cell_loc)
		if not data:
			continue
		if data.get_custom_data("spawner_type") != "main":
			continue

		match direction:
			"north":
				if cell_loc.y < 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"south":
				if cell_loc.y > 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"west":
				if cell_loc.x < 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)
			"east":
				if cell_loc.x > 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)

	if matching_cells.is_empty():
		matching_cells = cells.filter(func(c):
			var d = spawner_layer.get_cell_tile_data(c)
			return d and d.get_custom_data("spawner_type") == "main"
		)
		
	if matching_cells:
		var selected_cell = matching_cells.pick_random()
		var spawn_pos = spawner_layer.map_to_local(selected_cell) + Vector2(spawner_layer.tile_set.tile_size) / 2
		if wave >= 10 and randf() <= 0.3 and not boss_wave_mode:
			var bomb = big_bombrat.instantiate()
			bomb.global_position = spawn_pos
			add_child(bomb, true)
		else:
			var bomb = bombrat.instantiate()
			bomb.global_position = spawn_pos
			add_child(bomb, true)
		var smoke = smoke_scene.instantiate()
		smoke.global_position = spawn_pos
		smoke.emitting = true
		add_child(smoke, true)

func spawn_bauble(direction: String) -> void:
	var matching_cells: Array[Vector2i] = []
	var cells = spawner_layer.get_used_cells()

	for cell_loc in cells:
		var data = spawner_layer.get_cell_tile_data(cell_loc)
		if not data:
			continue
		if data.get_custom_data("spawner_type") != "corner":
			continue

		match direction:
			"north":
				if cell_loc.y < 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"south":
				if cell_loc.y > 0 and abs(cell_loc.y) > abs(cell_loc.x):
					matching_cells.append(cell_loc)
			"west":
				if cell_loc.x < 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)
			"east":
				if cell_loc.x > 0 and abs(cell_loc.x) > abs(cell_loc.y):
					matching_cells.append(cell_loc)

	if matching_cells.is_empty():
		matching_cells = cells.filter(func(c):
			var d = spawner_layer.get_cell_tile_data(c)
			return d and d.get_custom_data("spawner_type") == "main"
		)

	if matching_cells:
		var selected_cell = matching_cells.pick_random()
		var spawn_pos = spawner_layer.map_to_local(selected_cell) + Vector2(spawner_layer.tile_set.tile_size) / 2
		var baub: Node
		if wave >= 20 and randf() <= 0.25: 
			if randf() <= 0.33:
				baub = angry_bauble.instantiate()
			elif randf() <= 0.66:
				baub = rapid_bauble.instantiate()
			else:
				baub = explosive_bauble.instantiate()
		else: 
			baub = bauble.instantiate()
		baub.global_position = spawn_pos
		add_child(baub, true)
		var smoke = smoke_scene.instantiate()
		smoke.global_position = spawn_pos
		smoke.emitting = true
		add_child(smoke, true)
