extends ItemType
class_name Tossable

var cooldown: bool = false
var cooldown_seconds: float = 5.0 
var duration: float = 0.0 # Total lifetime (0 = permanent)
var update_interval: float = 0.0 # How often on_update is called (0 = every frame)
var elapsed_time: float = 0.0
var current_time: float = 0.0
var infinite: bool = false

var on_toss: Callable = func (_target, _location): pass
var on_update: Callable = func (_target, _location): pass
var on_end: Callable = func (_target, _location): pass
