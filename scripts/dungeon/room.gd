class_name Room
extends Object

@export var size: Vector2i
@export var exits: Array[RoomExit]
@export var type: String # "start", "boss", "normal", "special"
@export var weight: int