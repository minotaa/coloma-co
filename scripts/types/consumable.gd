extends ItemType
class_name Consumable

var cooldown: bool = false
var cooldown_seconds: float = 5.0 
#var magic_consumption: float = 100
var infinite: bool = false

var on_consume: Callable
