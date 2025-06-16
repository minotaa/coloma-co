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
	Toast.add("The Gem took damage! It has " + str(roundi(entity.health)) + " HP left!" )
	if entity.health <= 0.0:
		Toast.add("The Gem has been broken!")
	
func die() -> void:
	pass

func _process(delta):
	float_timer += delta * FLOAT_SPEED
	var offset_y = FLOAT_AMPLITUDE * sin(float_timer)
	sprite.position.y = offset_y
