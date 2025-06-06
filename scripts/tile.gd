extends Object
class_name Tile

var name: String
var id: int 
var description: String

var on_break: Callable = func(location: Vector2): 
	pass

func _init(name: String, id: int, description: String = "") -> void:
	self.name = name
	self.id = id
	self.description = description
