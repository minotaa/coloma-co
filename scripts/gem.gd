extends Area2D

const FLOAT_AMPLITUDE := 8.0  # How far up/down it floats (pixels)
const FLOAT_SPEED := 2.0      # How fast it floats

@onready var sprite: Sprite2D = $Gem

var float_timer := 0.0

var entity = Entity.new()

func _ready() -> void:
	entity.health = 100.0
	entity.max_health = 100.0
	entity.defense = 0.0
	entity.name = "Gem"
	entity.id = 2
	Entities.add_entity(entity)

func take_damage(amount: float) -> void:
	entity.health -= amount
	Toast.add("The Gem cracked! It has " + str(roundi(entity.health)) + " HP left!" )
	if entity.health <= 0.0:
		die()
		
func die() -> void:
	Toast.add("The Gem has been broken!")
	for player in get_tree().get_nodes_in_group("players"):
		player.send_title("GAME OVER!", 3.0)
	get_parent().started = false 
	await get_tree().create_timer(3.0).timeout
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		Man.end_game.rpc()
	else:
		Man.end_game()

func _process(delta):
	if entity != null:
		$ProgressBar.value = entity.health
		$ProgressBar.max_value = entity.max_health 
		if entity.health == entity.max_health:
			$ProgressBar.visible = false
		else:
			$ProgressBar.visible = true
	float_timer += delta * FLOAT_SPEED
	var offset_y = FLOAT_AMPLITUDE * sin(float_timer)
	sprite.position.y = offset_y
